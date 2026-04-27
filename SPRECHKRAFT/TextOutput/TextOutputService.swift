// SPRECHKRAFT/TextOutput/TextOutputService.swift
// Zweck: Text-Ausgabe nach Transkription — AX-Injektion (D-01) oder Clipboard (D-04).
// Implementiert: OUT-01 (AX-Injektion an Cursor-Position), OUT-02 (Clipboard-Fallback).
// Quellen: 04-RESEARCH.md Pattern 1-3; Apple Developer Forums thread 658733 (2040-Limit).

import AppKit
import ApplicationServices

// MARK: - Protocol (fuer Unit-Tests via Mock)

/// Testbares Interface fuer Text-Ausgabe.
/// Echter Code: TextOutputService.shared
/// Tests: MockTextOutputService
protocol TextOutputServiceProtocol: AnyObject {
    /// Gibt text aus — entweder via AX-Injektion oder Clipboard.
    /// - Parameters:
    ///   - text: Der auszugebende Text (leer → wird ignoriert).
    ///   - mode: Ausgabemodus aus Defaults (D-07).
    ///   - axPermitted: Ergebnis von AXIsProcessTrusted() (D-10).
    @MainActor func output(_ text: String, mode: OutputMode, axPermitted: Bool)
}

// MARK: - Service

/// Text-Ausgabe-Service. @MainActor: alle AX-Calls muessen auf dem Main Thread laufen.
/// Pitfall: AXUIElement*-Funktionen sind nicht thread-safe (RESEARCH.md Pitfall 2).
@MainActor
final class TextOutputService: TextOutputServiceProtocol {

    static let shared = TextOutputService()
    private init() {}

    // MARK: - Public Entry Point

    func output(_ text: String, mode: OutputMode, axPermitted: Bool) {
        guard !text.isEmpty else { return }

        // D-04: Kein AX-Versuch wenn Permission fehlt
        // D-07: .clipboard-Modus uebersteuert immer AX-Versuch
        if mode == .clipboard || !axPermitted {
            writeToClipboard(text)
            return
        }

        injectViaAX(text)
    }

    // MARK: - AX-Injektion (OUT-01, D-01, D-03)

    private func injectViaAX(_ text: String) {
        // Schritt 1: System-weites fokussiertes Element holen
        let sysWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            sysWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success, let focusedRef else {
            // D-05: Kein fokussiertes Element — stille Rueckkehr (Pitfall 3)
            return
        }
        // CFTypeID-Pruefung vor dem Cast — garantiert korrekte Laufzeit-Typsicherheit (REVIEW CR-01).
        // Hinweis: `as? AXUIElement` wuerde einen Compiler-Fehler erzeugen ("conditional downcast
        // to CoreFoundation type will always succeed"), daher bleibt force_cast nach der Pruefung.
        guard CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else {
            return
        }
        // swiftlint:disable:next force_cast
        let focused = focusedRef as! AXUIElement  // sicher: Typ durch CFTypeID-Guard verifiziert

        // Schritt 2: Existierenden Text lesen
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focused,
            kAXValueAttribute as CFString,
            &valueRef
        ) == .success, let existingCF = valueRef,
              let existing = existingCF as? String else {
            // D-05: kein lesbarer kAXValueAttribute — stille Rueckkehr
            return
        }

        // Schritt 3: Cursor-Range lesen (Fallback: Ende des Textes)
        var rangeRef: CFTypeRef?
        var cursorRange = CFRange(location: existing.unicodeScalars.count, length: 0)
        if AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeRef
        ) == .success, let rv = rangeRef {
            // KRITISCH: CFRange ist ein Struct, kein Objekt — nicht via `as?` casten.
            // Korrekte Methode: AXValueGetValue (RESEARCH.md Pitfall 5 / Don't-Hand-Roll)
            // swiftlint:disable:next force_cast
            let axVal = rv as! AXValue
            AXValueGetValue(axVal, .cfRange, &cursorRange)
        }

        // Schritt 4: Text am Cursor einsetzen (Unicode-Scalar-korrekt, D-03)
        // AX-Ranges sind Unicode-Scalar-Indizes, nicht String.Index (RESEARCH.md Don't-Hand-Roll)
        let composed = insertText(text, into: existing, at: cursorRange.location, replacing: cursorRange.length)

        // Schritt 5: 2040-Zeichen-Guard (PFLICHT — EXC_BAD_ACCESS-Schutz)
        // Apple Developer Forums thread 658733: kAXValueAttribute crasht bei >~2040 Zeichen
        // ohne AXError-Rueckmeldung. Guard auf 2000 fuer Puffer.
        guard composed.count <= 2000 else {
            writeToClipboard(text)
            return
        }

        // Schritt 6: Zusammengesetzten Text schreiben
        guard AXUIElementSetAttributeValue(
            focused,
            kAXValueAttribute as CFString,
            composed as CFTypeRef
        ) == .success else {
            // REVIEW WR-03: Clipboard-Fallback statt stiller Rueckkehr.
            // Read-Only-Felder, Browser-Content-Editable u.a. liefern hier einen Fehler —
            // der dikierte Text wuerde sonst ohne Rueckmeldung verloren gehen (stiller Datenverlust).
            writeToClipboard(text)
            return
        }

        // Schritt 7: Cursor hinter eingefuegten Text setzen (best-effort, Pitfall 4)
        // Manche Apps exponieren kAXSelectedTextRangeAttribute nicht als schreibbar — ignorieren
        let insertScalarCount = text.unicodeScalars.count
        let safeLoc = min(cursorRange.location, existing.unicodeScalars.count)
        // REVIEW WR-01: Cursor-Position gegen composed.unicodeScalars.count clamppen.
        // composed hat eine andere Laenge als existing (durch Einfuegen/Ersetzen), daher
        // kann safeLoc + insertScalarCount den zusammengesetzten String ueberschreiten
        // (z.B. bei Selektion: composed.count = existing.count - length + insertCount).
        let composedScalarCount = composed.unicodeScalars.count
        let newCursorLocation = min(safeLoc + insertScalarCount, composedScalarCount)
        var newCursorRange = CFRange(location: newCursorLocation, length: 0)
        if let axRange = AXValueCreate(.cfRange, &newCursorRange) {
            // Fehler von kAXSelectedTextRangeAttribute-Set werden ignoriert (Pitfall 4)
            _ = AXUIElementSetAttributeValue(
                focused,
                kAXSelectedTextRangeAttribute as CFString,
                axRange
            )
        }
    }

    // MARK: - Clipboard (OUT-02)

    func writeToClipboard(_ text: String) {
        // WICHTIG: clearContents() muss VOR setString() kommen.
        // Ohne clearContents() wird die Pasteboard-Version-ID nicht inkrementiert
        // und andere Apps sehen keine Aenderung (RESEARCH.md Don't-Hand-Roll).
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - String-Insert-Hilfsfunktion (intern + testbar via @testable import)

/// Unicode-Scalar-korrekte String-Insertion.
/// AX-Ranges sind Unicode-Scalar-Indizes — String.Index-Offsets wuerden bei Emoji falsch zaehlen.
/// Diese Funktion ist intern (kein public) und via @testable import SPRECHKRAFT in Tests zugreifbar.
func insertText(_ newText: String, into existing: String, at loc: Int, replacing len: Int) -> String {
    var scalars = Array(existing.unicodeScalars)
    let insertScalars = Array(newText.unicodeScalars)
    let safeLoc = min(loc, scalars.count)
    let safeEnd = min(safeLoc + max(len, 0), scalars.count)
    scalars.replaceSubrange(safeLoc..<safeEnd, with: insertScalars)
    return String(String.UnicodeScalarView(scalars))
}
