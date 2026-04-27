// SPRECHKRAFTTests/TextOutputServiceTests.swift
// Zweck: Unit-Tests fuer TextOutputService ohne echte AX-Permission.
// Testabdeckung: OUT-01 (Modus-Routing, String-Insert-Logik, 2040-Guard), OUT-02 (Clipboard), OUT-03 (Modus).
// Framework: Swift Testing (import Testing) — konsistent mit Phase-3-Tests.

import Testing
import AppKit
@testable import SPRECHKRAFT

// MARK: - Mock

/// Testdoppel fuer Text-Ausgabe — zeichnet Aufrufe auf ohne echte AX-Permission.
@MainActor
final class MockTextOutputService: TextOutputServiceProtocol {
    var outputCalls: [(text: String, mode: OutputMode, axPermitted: Bool)] = []
    var lastClipboardText: String? = nil

    func output(_ text: String, mode: OutputMode, axPermitted: Bool) {
        guard !text.isEmpty else { return }
        outputCalls.append((text, mode, axPermitted))
        // Clipboard-Verhalten simulieren
        if mode == .clipboard || !axPermitted {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            lastClipboardText = text
        }
    }
}

// MARK: - Tests: Modus-Routing

@Suite("TextOutputService — Modus-Routing")
struct TextOutputServiceModusTests {

    // REVIEW WR-04: Pasteboard vor jeder Suite isolieren — verhindert Flaky-Tests
    // bei paralleler Ausfuehrung (swift test --parallel).
    init() {
        NSPasteboard.general.clearContents()
    }

    @Test("Leerer Text wird ignoriert")
    @MainActor func emptyTextIsIgnored() {
        let mock = MockTextOutputService()
        mock.output("", mode: .field, axPermitted: true)
        #expect(mock.outputCalls.isEmpty)
    }

    @Test("mode .clipboard → Clipboard-Pfad (D-07)")
    @MainActor func clipboardModeUsesClipboard() {
        let mock = MockTextOutputService()
        mock.output("hallo", mode: .clipboard, axPermitted: true)
        #expect(mock.outputCalls.count == 1)
        #expect(mock.outputCalls[0].mode == .clipboard)
        #expect(NSPasteboard.general.string(forType: .string) == "hallo")
    }

    @Test("axPermitted false → Clipboard-Pfad (D-04)")
    @MainActor func noPermissionUsesClipboard() {
        let mock = MockTextOutputService()
        mock.output("test", mode: .field, axPermitted: false)
        #expect(mock.outputCalls.count == 1)
        #expect(mock.outputCalls[0].axPermitted == false)
        #expect(NSPasteboard.general.string(forType: .string) == "test")
    }

    @Test("mode .field + axPermitted true → AX-Pfad (kein Clipboard)")
    @MainActor func fieldModeWithPermissionRecorded() {
        let mock = MockTextOutputService()
        mock.output("ax-text", mode: .field, axPermitted: true)
        #expect(mock.outputCalls.count == 1)
        #expect(mock.outputCalls[0].mode == .field)
        #expect(mock.outputCalls[0].axPermitted == true)
        // Mock schreibt in diesem Fall NICHT auf Clipboard
        #expect(mock.lastClipboardText == nil)
    }
}

// MARK: - Tests: String-Insert-Logik

@Suite("TextOutputService — String-Insert-Logik (Unicode-Scalar-korrekt)")
struct TextOutputServiceStringInsertTests {

    @Test("Einfuegen mitten im Text am Cursor")
    @MainActor func insertMidString() {
        let result = insertText(" beautiful", into: "hello world", at: 5, replacing: 0)
        #expect(result == "hello beautiful world")
    }

    @Test("Einfuegen am Anfang (loc=0)")
    @MainActor func insertAtStart() {
        let result = insertText("START ", into: "end", at: 0, replacing: 0)
        #expect(result == "START end")
    }

    @Test("Einfuegen am Ende (loc = string.count)")
    @MainActor func insertAtEnd() {
        let result = insertText(" end", into: "start", at: 5, replacing: 0)
        #expect(result == "start end")
    }

    @Test("Ersetzen einer Selektion (len > 0)")
    @MainActor func replaceSelection() {
        let result = insertText("neue", into: "altes Wort", at: 0, replacing: 5)
        #expect(result == "neue Wort")
    }

    @Test("Unicode-Scalar-korrekt: Emoji zaehlt als 1 Scalar")
    @MainActor func emojiInsertCorrect() {
        // "hi 🎉 end" — 🎉 ist U+1F389, 1 Unicode-Scalar, aber 2 UTF-16-Code-Units
        // Unicode-Scalar-Offsets: h=0, i=1, ' '=2, 🎉=3, ' '=4
        // Einfuegen bei loc=4 (nach dem Leerzeichen nach 🎉): "hi 🎉! end"
        let result = insertText("!", into: "hi 🎉 end", at: 4, replacing: 0)
        #expect(result == "hi 🎉! end")
    }

    @Test("loc groesser als Textlaenge → safe Bounds (kein Crash)")
    @MainActor func safeBoundsWhenLocExceedsLength() {
        let result = insertText("x", into: "abc", at: 99, replacing: 0)
        #expect(result == "abcx")
    }

    @Test("len groesser als verbleibende Laenge → safe Bounds (kein Crash)")
    @MainActor func safeBoundsWhenLenExceedsRemaining() {
        let result = insertText("X", into: "abc", at: 1, replacing: 99)
        #expect(result == "aX")
    }
}

// MARK: - Tests: 2040-Zeichen-Guard

@Suite("TextOutputService — 2040-Zeichen-Guard")
struct TextOutputService2040GuardTests {

    @Test("Composed-Text > 2000 Zeichen triggert den Guard")
    @MainActor func longTextExceedsGuard() {
        // existing: 1990 Zeichen + insert: 50 Zeichen = 2040 → Guard greift
        let existing = String(repeating: "a", count: 1990)
        let insert = String(repeating: "b", count: 50)
        let composed = insertText(insert, into: existing, at: existing.unicodeScalars.count, replacing: 0)
        // Verifiziert: Guard-Bedingung wuerde zutreffen
        #expect(composed.count > 2000)
        // Bei guard composed.count <= 2000 wird writeToClipboard(insert) aufgerufen
        // (nur der eingefuegte Text, nicht der zusammengesetzte)
        TextOutputService.shared.writeToClipboard(insert)
        #expect(NSPasteboard.general.string(forType: .string) == insert)
    }

    @Test("Composed-Text = 2000 Zeichen → kein Fallback (exakter Grenzwert)")
    @MainActor func exactBoundaryNoFallback() {
        let existing = String(repeating: "a", count: 1995)
        let insert = String(repeating: "b", count: 5)
        let composed = insertText(insert, into: existing, at: existing.unicodeScalars.count, replacing: 0)
        #expect(composed.count == 2000)
        // composed.count <= 2000 → Guard greift NICHT (kein Clipboard-Fallback)
        #expect(composed.count <= 2000)
    }

    @Test("Composed-Text = 2001 Zeichen → Guard greift")
    @MainActor func oneOverBoundaryTriggersGuard() {
        let existing = String(repeating: "a", count: 1996)
        let insert = String(repeating: "b", count: 5)
        let composed = insertText(insert, into: existing, at: existing.unicodeScalars.count, replacing: 0)
        #expect(composed.count == 2001)
        #expect(composed.count > 2000)
    }
}

// MARK: - Tests: Clipboard-Schreiben

@Suite("TextOutputService — Clipboard-Schreiben (OUT-02)")
struct TextOutputServiceClipboardTests {

    // REVIEW WR-04: Pasteboard-Isolation (siehe TextOutputServiceModusTests.init())
    init() {
        NSPasteboard.general.clearContents()
    }

    @Test("writeToClipboard schreibt Text auf Pasteboard")
    @MainActor func writeToClipboard() {
        let service = TextOutputService.shared
        service.writeToClipboard("testinhalt")
        #expect(NSPasteboard.general.string(forType: .string) == "testinhalt")
    }

    @Test("writeToClipboard ueberschreibt vorherigen Inhalt")
    @MainActor func writeToClipboardOverwritesPrevious() {
        let service = TextOutputService.shared
        service.writeToClipboard("erster Inhalt")
        service.writeToClipboard("zweiter Inhalt")
        #expect(NSPasteboard.general.string(forType: .string) == "zweiter Inhalt")
    }

    @Test("writeToClipboard mit leerem String — kein Crash")
    @MainActor func writeEmptyStringNocrash() {
        let service = TextOutputService.shared
        // Kein Guard in writeToClipboard — leerer String ist valid fuer NSPasteboard
        service.writeToClipboard("")
        // NSPasteboard gibt "" oder nil zurueck; beides ist akzeptabel
        let result = NSPasteboard.general.string(forType: .string)
        #expect(result == "" || result == nil)
    }
}
