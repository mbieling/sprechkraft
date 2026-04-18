# Phase 4: Text Output — Research

**Researched:** 2026-04-18
**Domain:** macOS Accessibility API (AXUIElement), NSPasteboard, Swift 6 strict concurrency
**Confidence:** HIGH (AX API call sequence), HIGH (Clipboard), HIGH (Entitlements), MEDIUM (per-app behavior)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Primärmethode: `AXUIElement` setValue — `AXUIElementCopyAttributeValue` liest das fokussierte Element, dann `AXUIElementSetAttributeValue` schreibt `kAXValueAttribute`. Kein simuliertes Tippen, kein Clipboard-Overhead.
- **D-02:** Ziel-Apps (Phase-4-Minimum): TextEdit, Notes, Safari (Textfelder), Mail, Xcode
- **D-03:** Cursor-Position: Text wird am aktuellen Cursor eingesetzt via `kAXSelectedTextRangeAttribute` + setValue
- **D-04:** Automatischer Clipboard-Fallback: **nur bei fehlender AX-Permission** — `AXIsProcessTrusted()` → false → direkt Clipboard, kein Injektion-Versuch
- **D-05:** AX-Fehler bei vorhandener Permission: stille Rückkehr zu `.idle`
- **D-06:** Standard-Modus beim ersten Start: Textfeld-Injektion
- **D-07:** Persistenz: `Defaults.Key<OutputMode>` — neuer Enum `OutputMode { case field, clipboard }`
- **D-08:** Modus-Anzeige: Menü-Häkchen im Dropdown
- **D-09:** Wechsel-Hotkey: ⇧⌘V (`KeyboardShortcuts.Name.toggleOutputMode`)
- **D-10:** Permission-Check beim App-Start via `AXIsProcessTrusted()` → `AppState.axPermissionDenied: Bool`
- **D-11:** Fehlende Permission UX: Banner in SettingsView, analog zu `micPermissionDenied`
- **D-12:** Clipboard-Fallback auto-aktiviert wenn Permission fehlt; Banner bleibt sichtbar

### Claude's Discretion
- Genaue AX-API-Aufrufsequenz (welche Attribute, Fehlerbehandlung im Detail)
- OutputMode-Enum-Struktur und Defaults-Key-Name
- Wie der Text bei leerem Fokus-Element behandelt wird (kein fokussiertes Textfeld)
- Debounce oder Retry-Logik beim AX-Aufruf

### Deferred Ideas (OUT OF SCOPE)
- App-spezifischer AX-Fallback (VS Code, Terminal, Electron-Apps) — v2
- Cursor-Position-Awareness wenn kein Textfeld fokussiert ist (Toast) — v2 UX-Polish
- Automatic Retry wenn AX-Injektion scheitert — v2
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OUT-01 | Transkription wird ins aktive Textfeld an Cursor-Position eingefügt (via macOS Accessibility API) | AX-Aufrufsequenz vollständig dokumentiert; Cursor-Insertion via kAXSelectedTextRangeAttribute + kAXValueAttribute bestätigt |
| OUT-02 | Alternativ: Transkription in Clipboard kopieren | NSPasteboard.clearContents() + setString() — einfach, keine offenen Fragen |
| OUT-03 | Ausgabemodus (Textfeld vs. Clipboard) per dediziertem Hotkey umschaltbar | Defaults.Key<OutputMode> + KeyboardShortcuts.Name.toggleOutputMode — identisch zum bestehenden toggleRecording-Pattern |
</phase_requirements>

---

## Summary

Phase 4 ersetzt den `print("Transkription: \(text)")`-Stub in `AppDelegate.swift:75` durch echte Textausgabe. Die zwei Ausgabewege — AX-Injektion in das aktive Textfeld und NSPasteboard/Clipboard — sind gut verstandene macOS-APIs ohne externe Abhängigkeiten.

**Kritischer Befund:** Entgegen der Erwartung aus D-01 und D-03 nutzt VoiceInk (die Referenz-App) **nicht** `kAXValueAttribute` für die Textinjektion, sondern Clipboard + simuliertes Cmd+V via CGEvent. Der Grund: `AXUIElementSetAttributeValue` mit `kAXValueAttribute` hat eine undokumentierte Harte Grenze von ~2040 Zeichen, bei deren Überschreitung `EXC_BAD_ACCESS` entsteht. [VERIFIED: Apple Developer Forums 2020, bestätigt durch Hammerspoon-Community]

Da D-01 locked ist (kAXValueAttribute als Primärmethode), muss die Implementierung diese 2040-Zeichen-Grenze berücksichtigen. Die korrekte Cursor-Insertion-Strategie via `kAXSelectedTextRangeAttribute` ist: (1) aktuelle Text-Range lesen, (2) neuen String in existierenden String am Range-Offset einsetzen, (3) `kAXValueAttribute` mit dem zusammengesetzten String schreiben, (4) Cursor-Position via `kAXSelectedTextRangeAttribute` auf `loc + insertedLength` setzen.

Entitlements: Kein spezielles Entitlement für AX API nötig. `NSAccessibilityUsageDescription` sollte in `Info.plist` ergänzt werden. App ist bereits non-sandboxed (notwendig für globale Hotkeys, bestehend seit Phase 1). [VERIFIED: Apple Developer Forums; Jano.dev 2025]

**Primärempfehlung:** `TextOutputService` als `@MainActor`-Klasse mit einem `TextOutputProvider`-Protokoll für testbare Abhängigkeitsinjektion; AX-Calls immer auf `@MainActor`; Clipboard als direkte Fallback-Implementierung.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| AX-Permission-Check | AppDelegate (App-Start) | AppState (Zustand halten) | applicationDidFinishLaunching ist der einzige sichere Zeitpunkt; AppState hält das Ergebnis für SettingsView |
| Text-Injektion (AX) | TextOutputService (@MainActor) | — | AX API ist nicht threadsafe; muss auf Main Thread laufen |
| Clipboard-Schreiben | TextOutputService (@MainActor) | — | NSPasteboard.general ist @MainActor-safe, kein separater Thread nötig |
| Modus-Persistenz | Defaults+Keys.swift | AppDelegate/SettingsView | Identisches Pattern zu silenceDuration/selectedMicUID |
| Hotkey-Registrierung | KeyboardShortcuts+Names.swift + AppDelegate.setupHotkey() | — | Identisch zu toggleRecording |
| Permission-Banner-UX | SettingsView | AppState.axPermissionDenied | Gleiche Struktur wie micPermissionDenied-Banner |
| Menü-Häkchen | AppDelegate.showMenu() | — | Menu wird bei jedem showMenu() neu aufgebaut; kein separate Observation nötig |

---

## Standard Stack

### Core (keine neuen Abhängigkeiten)

| API / Modul | Version | Zweck | Warum Standard |
|-------------|---------|-------|----------------|
| `ApplicationServices` (AXUIElement) | macOS 14+ | AX Text-Injektion | Einzige systemweite Methode für Text in fremde Apps; kein Third-Party-Wrapper nötig |
| `AppKit.NSPasteboard` | macOS 14+ | Clipboard-Schreiben | Einzige korrekte API für Pasteboard-Operationen |
| `Defaults` (bestehend) | bereits installiert | OutputMode-Persistenz | Bereits im Projekt; konsistentes Pattern |
| `KeyboardShortcuts` (bestehend) | bereits installiert | Hotkey ⇧⌘V | Bereits im Projekt; identisches Pattern zu toggleRecording |

**Keine neuen SPM-Dependencies in Phase 4.** [VERIFIED: Codebase-Analyse]

### Alternativen erwogen

| Statt | Könnte man nutzen | Abwägung |
|-------|-------------------|----------|
| `kAXValueAttribute` write | Clipboard + CGEvent Cmd+V (VoiceInk-Ansatz) | VoiceInk wählt CGEvent weil es mit allen Apps funktioniert inkl. Electron; D-01 ist aber locked — kAXValueAttribute bleibt Primärmethode |
| `AXIsProcessTrusted()` | `AXIsProcessTrustedWithOptions()` | `WithOptions` zeigt OS-Dialog; für VoiceScribe unerwünscht (D-11 sagt: Banner in SettingsView statt Dialog). Einfaches `AXIsProcessTrusted()` ohne Optionen ist korrekt. |

---

## Architecture Patterns

### System Architecture Diagram

```
onRecordingComplete(samples, sampleRate)
        │
        ▼
TranscriptionService.transcribeWithResampling()
        │
        ▼
    text: String?
        │
        ├─── AXIsProcessTrusted() == false OR outputMode == .clipboard
        │           │
        │           ▼
        │     NSPasteboard.general
        │     .clearContents()
        │     .setString(text, forType: .string)
        │
        └─── AXIsProcessTrusted() == true AND outputMode == .field
                    │
                    ▼
            AXUIElementCreateSystemWide()
                    │
                    ▼
            kAXFocusedUIElementAttribute → focusedElement?
                    │
                    ├─── nil → stille Rückkehr zu .idle (D-05)
                    │
                    ▼
            kAXValueAttribute → existingText: String
            kAXSelectedTextRangeAttribute → CFRange (loc, len)
                    │
                    ▼
            newText = existing.insert(text, at: loc, replacing: len)
            AXUIElementSetAttributeValue(kAXValueAttribute, newText)
            AXUIElementSetAttributeValue(kAXSelectedTextRangeAttribute, 
                                         CFRange(loc + text.count, 0))
                    │
                    ├─── AXError != .success → stille Rückkehr zu .idle (D-05)
                    │
                    ▼
                resetToIdle()
```

### Empfohlene Dateistruktur

```
VoiceScribe/
├── TextOutput/
│   └── TextOutputService.swift      # @MainActor-Klasse mit AX + Clipboard-Logik
├── Extensions/
│   └── Defaults+Keys.swift          # NEU: Key<OutputMode>("outputMode", default: .field)
│   └── KeyboardShortcuts+Names.swift # NEU: toggleOutputMode Name
├── AppState.swift                    # NEU: axPermissionDenied: Bool
├── AppDelegate.swift                 # NEU: AX-Check + TextOutputService.output(), Menü-Häkchen
└── SettingsView.swift                # NEU: axPermissionDenied-Banner + OutputMode-Section
```

### Pattern 1: TextOutputService — AX-Injektion mit Cursor

```swift
// Source: Apple Developer Documentation / AXSwift pattern / Community research
// ACHTUNG: Alle AX-Calls müssen auf @MainActor laufen.

import ApplicationServices

@MainActor
final class TextOutputService {

    func output(_ text: String, mode: OutputMode, axPermitted: Bool) {
        guard !text.isEmpty else { return }

        if mode == .clipboard || !axPermitted {
            writeToClipboard(text)
            return
        }

        injectViaAX(text)
    }

    // --- AX-Injektion ---

    private func injectViaAX(_ text: String) {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let focusErr = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )
        guard focusErr == .success, let focused = focusedRef else {
            // D-05: kein fokussiertes Element — stille Rückkehr
            return
        }
        let focusedElement = focused as! AXUIElement

        // Existierenden Text lesen
        var valueRef: CFTypeRef?
        let valueErr = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXValueAttribute as CFString,
            &valueRef
        )
        guard valueErr == .success, let existingCF = valueRef,
              let existing = existingCF as? String else {
            // D-05: kein lesbarer Text — stille Rückkehr
            return
        }

        // Cursor-Position lesen
        var rangeRef: CFTypeRef?
        var cursorRange = CFRange(location: existing.count, length: 0)  // Fallback: Ende
        if AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeRef
        ) == .success, let rv = rangeRef {
            let axVal = rv as! AXValue
            AXValueGetValue(axVal, .cfRange, &cursorRange)
        }

        // Text am Cursor einsetzen
        let loc = cursorRange.location
        let len = cursorRange.length

        var chars = Array(existing.unicodeScalars)
        let insertChars = Array(text.unicodeScalars)
        // Bounds-Guard — loc/len können bei manchen Apps größer als chars.count sein
        let safeLoc = min(loc, chars.count)
        let safeEnd = min(safeLoc + len, chars.count)
        chars.replaceSubrange(safeLoc..<safeEnd, with: insertChars)
        let newText = String(String.UnicodeScalarView(chars))

        // KRITISCH: 2040-Zeichen-Limit bei kAXValueAttribute (Apple Developer Forums 2020)
        // Crash: EXC_BAD_ACCESS wenn newText.count > ~2040
        // Workaround: Clipboard-Fallback bei langen Texten
        if newText.count > 2000 {
            writeToClipboard(text)
            return
        }

        let setErr = AXUIElementSetAttributeValue(
            focusedElement,
            kAXValueAttribute as CFString,
            newText as CFTypeRef
        )
        guard setErr == .success else {
            // D-05: AX-Fehler bei vorhandener Permission — stille Rückkehr
            return
        }

        // Cursor hinter eingefügten Text setzen
        var newCursorRange = CFRange(location: safeLoc + text.count, length: 0)
        if let axRange = AXValueCreate(.cfRange, &newCursorRange) {
            AXUIElementSetAttributeValue(
                focusedElement,
                kAXSelectedTextRangeAttribute as CFString,
                axRange
            )
        }
    }

    // --- Clipboard ---

    private func writeToClipboard(_ text: String) {
        // Source: Apple Developer Documentation / nilcoalescing.com verified
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
```

### Pattern 2: OutputMode Enum + Defaults Key

```swift
// VoiceScribe/Extensions/Defaults+Keys.swift (Erweiterung)
// Source: Bestehendes Pattern aus silenceDuration/selectedMicUID

enum OutputMode: String, Defaults.Serializable {
    case field      // Textfeld-Injektion via AX (Standard)
    case clipboard  // Clipboard-Kopie
}

extension Defaults.Keys {
    static let outputMode = Key<OutputMode>("outputMode", default: .field)
}
```

### Pattern 3: Permission-Check beim App-Start

```swift
// AppDelegate.applicationDidFinishLaunching (Ergänzung)
// Source: jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html [VERIFIED]

// AXIsProcessTrusted() OHNE Optionen — kein OS-Dialog (D-10, D-11)
let axGranted = AXIsProcessTrusted()
appState?.axPermissionDenied = !axGranted
// D-12: Wenn Permission fehlt, bleibt Modus auf .field gespeichert,
//        aber TextOutputService fällt automatisch auf Clipboard zurück.
```

### Pattern 4: Systemeinstellungen-URL für Accessibility

```swift
// Source: Apple Developer Documentation / jano.dev 2025 [VERIFIED]
// URL für Datenschutz → Bedienungshilfen (Privacy_Accessibility)
if let url = URL(string: 
    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
    NSWorkspace.shared.open(url)
}
```

### Pattern 5: Hotkey toggleOutputMode

```swift
// VoiceScribe/Extensions/KeyboardShortcuts+Names.swift (Ergänzung)
// Source: Bestehendes toggleRecording-Pattern [VERIFIED: Codebase]

extension KeyboardShortcuts.Name {
    static let toggleOutputMode = Self(
        "toggleOutputMode",
        default: .init(.v, modifiers: [.shift, .command])  // ⇧⌘V — D-09
    )
}
```

### Pattern 6: Menü-Häkchen (Ausgabemodus-Anzeige)

```swift
// AppDelegate.showMenu() Ergänzung — analoges Pattern zu loginItem.state
// Source: Bestehendes showMenu()-Pattern [VERIFIED: Codebase]

let currentMode = Defaults[.outputMode]

let fieldItem = NSMenuItem(
    title: "Textfeld-Injektion",
    action: #selector(setModeField),
    keyEquivalent: ""
)
fieldItem.target = self
fieldItem.state = currentMode == .field ? .on : .off
menu.addItem(fieldItem)

let clipItem = NSMenuItem(
    title: "Clipboard",
    action: #selector(setModeClipboard),
    keyEquivalent: ""
)
clipItem.target = self
clipItem.state = currentMode == .clipboard ? .on : .off
menu.addItem(clipItem)
```

### Anti-Patterns vermeiden

- **AX-Calls außerhalb @MainActor:** `AXUIElementCopyAttributeValue` und `AXUIElementSetAttributeValue` sind nicht threadsafe. Niemals in einem `Task { }` ohne `@MainActor`-Annotation aufrufen. Der gesamte `TextOutputService` muss `@MainActor` sein.
- **AXIsProcessTrustedWithOptions mit `kAXTrustedCheckOptionPrompt: true`:** Zeigt einen OS-Dialog. D-11 sagt explizit Banner in SettingsView statt Dialog. Immer `AXIsProcessTrusted()` ohne Optionen verwenden.
- **kAXValueAttribute ohne Längenprüfung:** Strings > ~2040 Zeichen crashen mit `EXC_BAD_ACCESS`. Immer `newText.count > 2000` prüfen und auf Clipboard ausweichen.
- **Casting von `CFTypeRef` zu `String` direkt:** Schlägt fehl für AXValue-Typen (CFRange). Für Range: `AXValueGetValue(axVal, .cfRange, &range)` verwenden. Für String: `as? String` ist korrekt.
- **`com.apple.security.accessibility` Entitlement schreiben:** Dieses Entitlement existiert nicht. Es ist eine häufige Fehlannahme. AX-Access wird nur über System-Einstellungen (Privacy_Accessibility) gewährt, nicht per Entitlement. [VERIFIED: Apple Developer Forums]

---

## Don't Hand-Roll

| Problem | Nicht bauen | Stattdessen | Warum |
|---------|-------------|-------------|-------|
| AXValue → CFRange konvertieren | Eigener Cast | `AXValueGetValue(axVal, .cfRange, &range)` | Direktes `as? CFRange` kompiliert nicht; AXValueGetValue ist die korrekte C-API |
| String in String an Index einsetzen | `String.insert()` | `String.unicodeScalars`-Array mit `replaceSubrange()` | AX-Ranges sind Unicode-Scalar-Indizes, nicht `String.Index`; Byte-Offsets führen zu falschen Positionen bei Nicht-ASCII-Zeichen |
| Clipboard schreiben | Eigene Implementierung | `NSPasteboard.general.clearContents()` + `setString()` | Ohne `clearContents()` wird die alte Version ID nicht inkrementiert; andere Apps sehen keine Änderung |

**Kernaussage:** AX API ist eine reine C-API. Swift-Casting-Konventionen gelten nicht für CFTypeRef-Rückgaben von AX-Funktionen. Für Range-Typen immer die typisierte AXValueGetValue-Variante verwenden.

---

## Common Pitfalls

### Pitfall 1: 2040-Zeichen-Crash in kAXValueAttribute

**Was schief geht:** `AXUIElementSetAttributeValue(element, kAXValueAttribute, text)` crasht mit `EXC_BAD_ACCESS` wenn der zu schreibende String (bestehender Text + eingefügter Text) länger als ~2040 Zeichen ist.
**Warum:** Undokumentiertes internes Limit im macOS Accessibility Framework. Kein `AXError` wird returned; die App crasht.
**Wie vermeiden:** Vor dem Schreiben `newText.count > 2000` prüfen und auf Clipboard ausweichen.
**Warnzeichen:** EXC_BAD_ACCESS genau an `AXUIElementSetAttributeValue`-Zeile; keine AXError-Rückmeldung.
**Quelle:** [VERIFIED: Apple Developer Forums thread 658733, 2020]

### Pitfall 2: AX-Calls außerhalb des Main Thread

**Was schief geht:** AXUIElement-Calls aus einem Background-Thread oder non-isolated `Task {}` führen zu sporadischen Crashes oder falschen Ergebnissen.
**Warum:** ApplicationServices / HIServices sind nicht thread-safe. Alle AX-Calls müssen auf dem Main Thread erfolgen.
**Wie vermeiden:** `TextOutputService` als `@MainActor final class` deklarieren. Im `onRecordingComplete`-Callback bereits via `await MainActor.run { }` aufgerufen (wie im bestehenden Code).
**Warnzeichen:** Thread Sanitizer Reports; "CATransaction" Warnings in Logs.

### Pitfall 3: Kein fokussiertes Textfeld

**Was schief geht:** `kAXFocusedUIElementAttribute` liefert nil wenn der User zuletzt auf Desktop oder Menüleiste geklickt hat. Crash wenn focusedElement-Force-Unwrap verwendet wird.
**Warum:** System-weites `kAXFocusedUIElement` kann nil sein; z.B. direkt nach Dictation-Hotkey.
**Wie vermeiden:** `guard let focused = focusedRef` mit stiller Rückkehr zu `.idle` (D-05).
**Warnzeichen:** Crash mit nil-Unwrap in AXUIElement-Cast-Zeile.

### Pitfall 4: kAXSelectedTextRangeAttribute schlägt bei manchen Apps fehl

**Was schief geht:** Manche Textfelder (auch native Apps) exponieren kAXSelectedTextRangeAttribute nicht als schreibbares Attribut — `AXUIElementSetAttributeValue` gibt `kAXErrorAttributeUnsupported` zurück.
**Warum:** Apps implementieren AX-Protokoll unterschiedlich vollständig.
**Wie vermeiden:** Fehler aus `kAXSelectedTextRangeAttribute`-Set ignorieren (Cursor-Position-Set ist best-effort); Text wurde bereits via `kAXValueAttribute` korrekt gesetzt.
**Warnzeichen:** Text wird korrekt eingefügt, Cursor bleibt aber an falscher Position.

### Pitfall 5: CFTypeRef-Casting für AXValue-Typen

**Was schief geht:** `let range = rangeRef as? CFRange` kompiliert nicht oder liefert nil. CFRange ist ein Struct, kein Objekt.
**Warum:** AXUIElementCopyAttributeValue liefert AXValue-opaque Typen für Ranges; diese sind nicht direkt castbar.
**Wie vermeiden:** `let axVal = rv as! AXValue; AXValueGetValue(axVal, .cfRange, &range)`.
**Warnzeichen:** Compiler-Fehler "Cannot convert value of type 'CFTypeRef' to type 'CFRange'" oder Runtime-nil.

### Pitfall 6: `com.apple.security.accessibility` Entitlement

**Was schief geht:** Entwickler fügt `com.apple.security.accessibility` zu Entitlements hinzu — dieses Entitlement existiert nicht und bewirkt nichts.
**Warum:** Häufig in Blog-Posts falsch dokumentiert. AX-Permission ist ausschließlich User-gesteuert über System-Einstellungen.
**Wie vermeiden:** Kein AX-Entitlement schreiben. `NSAccessibilityUsageDescription` in `Info.plist` ist die korrekte Deklaration (ohne Entitlement).
**Quelle:** [VERIFIED: Apple Developer Forums 2021/2023]

---

## Code Examples

### Vollständige AX-Cursor-Insertion (verifizierte Teile)

```swift
// Source: AXSwift UIElement.swift + Apple Developer Forums + Community research
// [VERIFIED: AXSwift Pattern für packAXValue/CFRange via GitHub tmandry/AXSwift]
// [VERIFIED: AXValueGetValue-Verwendung via Apple Developer Documentation]

// Schritt 1: System-weites Element
let systemWide = AXUIElementCreateSystemWide()

// Schritt 2: Fokussiertes Element
var focusedRef: CFTypeRef?
guard AXUIElementCopyAttributeValue(
    systemWide,
    kAXFocusedUIElementAttribute as CFString,
    &focusedRef
) == .success, let focusedRef else { return }
let element = focusedRef as! AXUIElement

// Schritt 3: Existierenden Text lesen
var valueRef: CFTypeRef?
guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
      let existing = valueRef as? String else { return }

// Schritt 4: Cursor-Range lesen
var rangeRef: CFTypeRef?
var cursorRange = CFRange(location: existing.unicodeScalars.count, length: 0)
if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
   let rv = rangeRef {
    let axVal = rv as! AXValue
    AXValueGetValue(axVal, .cfRange, &cursorRange)
}

// Schritt 5: Text einsetzen (Unicode-scalar-korrekt)
var scalars = Array(existing.unicodeScalars)
let insertScalars = Array(newText.unicodeScalars)
let loc = min(cursorRange.location, scalars.count)
let end = min(loc + cursorRange.length, scalars.count)
scalars.replaceSubrange(loc..<end, with: insertScalars)
let composed = String(String.UnicodeScalarView(scalars))

// Schritt 6: Längencheck vor Schreiben
guard composed.count <= 2000 else {
    // Fallback auf Clipboard bei sehr langen Texten
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(newText, forType: .string)
    return
}

// Schritt 7: Schreiben
guard AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, composed as CFTypeRef) == .success else {
    return  // D-05: stille Rückkehr
}

// Schritt 8: Cursor-Position setzen (best-effort)
var newRange = CFRange(location: loc + insertScalars.count, length: 0)
if let axRange = AXValueCreate(.cfRange, &newRange) {
    AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, axRange)
}
```

### NSPasteboard Clipboard schreiben

```swift
// Source: Apple Developer Documentation (clearContents, setString)
// [VERIFIED: nilcoalescing.com + Apple Developer Documentation]
NSPasteboard.general.clearContents()
NSPasteboard.general.setString(text, forType: .string)
```

### Defaults.Serializable für OutputMode

```swift
// Source: Defaults-Library Dokumentation (sindersorhus/Defaults)
// [ASSUMED: RawRepresentable-Konformanz genügt für Defaults.Serializable bei String-RawValue]
enum OutputMode: String, Defaults.Serializable {
    case field
    case clipboard
}
```

---

## State of the Art

| Alter Ansatz | Aktueller Ansatz | Geändert | Impact |
|-------------|-----------------|----------|--------|
| `AXIsProcessTrustedWithOptions` mit Prompt | `AXIsProcessTrusted()` + eigene Settings-Verlinkung | macOS 10.9+ | Bessere UX — kein OS-Dialog, eigene Banner-UI |
| `NSDictionary` mit `kAXTrustedCheckOptionPrompt` | Nicht verwendet (D-11) | — | Vermeidet unerwünschten System-Dialog |
| `AXTextMarker`-API | Nicht relevant für Phase 4 | — | Nur bei Rich-Text-Editing-Implementierungen relevant |

**Deprecated / Überholt:**
- `AXMakeAXValue` (Objective-C): Durch `AXValueCreate` ersetzt. Swift nutzt `AXValueCreate(.cfRange, &range)`.
- `com.apple.security.automation.apple-events` Entitlement: Nicht relevant für AXUIElement. Nur für Apple Events / AppleScript nötig.

---

## Assumptions Log

| # | Claim | Section | Risiko wenn falsch |
|---|-------|---------|-------------------|
| A1 | `OutputMode: String, Defaults.Serializable` benötigt nur `RawRepresentable` | Code Examples | Compilerfehler; Workaround: manuell `Defaults.Serializable` implementieren |
| A2 | AX-Calls in `@MainActor`-Kontext lösen keine Swift 6 Compiler-Fehler aus | Architecture | Ggf. `nonisolated` oder `@preconcurrency` Import nötig; Test beim Kompilieren |
| A3 | kAXSelectedTextRangeAttribute gibt Unicode-Scalar-Offsets zurück (nicht UTF-16) | Code Examples | Cursor-Position bei CJK/Emoji-Text falsch; nur manuell testbar |
| A4 | TextEdit, Notes, Safari exponieren alle drei Attribute (kAXValue, kAXSelectedTextRange, Read+Write) | Architecture | Einzelne App scheitert; AX-Inspector-Test erforderlich |

---

## Open Questions

1. **Unicode-Offset-Semantik von kAXSelectedTextRangeAttribute**
   - Was wir wissen: CFRange.location ist ein Integer-Offset in den Text
   - Was unklar: Ob UTF-16-Code-Units oder Unicode-Scalar-Values gemeint sind (bei Emoji / CJK relevant)
   - Empfehlung: In Wave-0-Test mit einem Emoji-Text prüfen (Workaround: `unicodeScalars`-Berechnung ist konservativer)

2. **Verhalten bei Notes.app mit Locked Notes**
   - Was wir wissen: Notes exponiert Standard-AX für normale Notizen
   - Was unklar: Gesperrte Notizen könnten `kAXAttributeUnsupported` für kAXValueAttribute zurückgeben
   - Empfehlung: Manueller Test in Wave 2; D-05 (stille Rückkehr) deckt diesen Fall ab

---

## Environment Availability

Step 2.6: SKIPPED (Phase 4 ist rein code-/config-seitig; keine externen Tool-Dependencies über das bestehende macOS-SDK hinaus)

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (import Testing) |
| Config file | Xcode-Projekt (kein separates pytest.ini/jest.config) |
| Quick run command | `xcodebuild test -scheme VoiceScribe -only-testing VoiceScribeTests/TextOutputServiceTests` |
| Full suite command | `xcodebuild test -scheme VoiceScribe` |

### Phase Requirements → Test Map

| Req ID | Verhalten | Test-Typ | Automatisierter Befehl | Datei vorhanden? |
|--------|-----------|----------|----------------------|-----------------|
| OUT-01 | AX-Injektion schreibt Text in Textfeld | manual | — (AX benötigt echte App, nicht CI) | ❌ Wave 0 |
| OUT-01 | TextOutputService.output() ruft AX-Pfad bei permission=true, mode=.field auf | unit (mock) | `xcodebuild test -only-testing VoiceScribeTests/TextOutputServiceTests` | ❌ Wave 0 |
| OUT-01 | Cursor-Berechnung (String-Insert an Range-Position) | unit (pure logic) | s.o. | ❌ Wave 0 |
| OUT-01 | 2040-Zeichen-Limit: Fallback auf Clipboard wenn composed.count > 2000 | unit (mock) | s.o. | ❌ Wave 0 |
| OUT-02 | Clipboard-Schreiben setzt clearContents() dann setString() | unit (NSPasteboard.general testbar) | s.o. | ❌ Wave 0 |
| OUT-02 | Clipboard-Modus bei axPermitted=false | unit (mock) | s.o. | ❌ Wave 0 |
| OUT-03 | Defaults.Keys.outputMode hat Standardwert .field | unit | `xcodebuild test -only-testing VoiceScribeTests/DefaultsKeysTests` | ❌ Wave 0 (Erweiterung) |
| OUT-03 | toggleOutputMode wechselt field↔clipboard | unit | `xcodebuild test -only-testing VoiceScribeTests/TextOutputServiceTests` | ❌ Wave 0 |
| OUT-03 | Modus persistiert nach App-Neustart | manual | — | Human-Verify |
| AX-Permission | axPermissionDenied in AppState startet false | unit | `xcodebuild test -only-testing VoiceScribeTests/AppStateTests` | ❌ Wave 0 (Erweiterung) |

**Testbarkeits-Hinweis für AX-Injektion:** Echter AX-Aufruf erfordert laufende App mit AX-Permission — nicht in CI testbar. Lösung: `TextOutputServiceProtocol` für Injektion definieren; Unit-Tests verwenden einen `MockTextOutputService`. Der `TextOutputService` selbst ist ein Wave-2-manueller Human-Verify-Test.

### Sampling Rate

- **Pro Task-Commit:** `xcodebuild test -only-testing VoiceScribeTests/TextOutputServiceTests -only-testing VoiceScribeTests/DefaultsKeysTests -only-testing VoiceScribeTests/AppStateTests`
- **Pro Wave-Merge:** `xcodebuild test -scheme VoiceScribe` (Full Suite)
- **Phase Gate:** Full Suite grün vor `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `VoiceScribeTests/TextOutputServiceTests.swift` — Covers OUT-01 (unit/mock), OUT-02, OUT-03
- [ ] `VoiceScribe/TextOutput/TextOutputService.swift` — Core-Implementierung
- [ ] `OutputMode`-Enum in Defaults+Keys.swift — Prerequisite für Tests

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | yes (AX Permission) | `AXIsProcessTrusted()` — OS-Granted, nicht App-gesteuert |
| V5 Input Validation | yes | Text von TranscriptionService — lokal produziert, keine externe Quelle in Phase 4 |
| V6 Cryptography | no | — |

### Known Threat Patterns

| Pattern | STRIDE | Mitigation |
|---------|--------|-----------|
| Clipboard-Sniffing durch andere Apps | Information Disclosure | Unvermeidbar auf macOS (Pasteboard ist shared); akzeptiertes Risiko für lokale Diktat-App |
| AX-Permission Missbrauch (andere App liest Text via AX) | Information Disclosure | OS-Kontrolle; VoiceScribe ist Sender, nicht Receiver |
| Buffer-Overflow via langen Text (2040-Limit) | Denial of Service | Expliziter Guard `newText.count > 2000` mit Clipboard-Fallback |

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: `AXUIElementSetAttributeValue` — https://developer.apple.com/documentation/applicationservices/1460434-axuielementsetattributevalue
- Apple Developer Documentation: `kAXSelectedTextRangeAttribute` — https://developer.apple.com/documentation/applicationservices/kaxselectedtextrangeattribute
- Apple Developer Documentation: `kAXValueAttribute` — https://developer.apple.com/documentation/applicationservices/kaxvalueattribute
- AXSwift UIElement.swift — CFRange-Packing-Pattern — https://github.com/tmandry/AXSwift/blob/main/Sources/UIElement.swift
- Apple Developer Forums — 2040-Zeichen-Crash — https://developer.apple.com/forums/thread/658733
- Jano.dev (Jan 2025) — AXIsProcessTrusted() Verwendung + URL-Scheme — https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html
- Codebase VoiceScribe — Bestehendes Pattern für Defaults, KeyboardShortcuts, AppState — lokale Analyse

### Secondary (MEDIUM confidence)
- VoiceInk CursorPaster.swift (GitHub Beingpax/VoiceInk) — Clipboard+CGEvent-Ansatz als Gegenbeispiel zu D-01
- Speak2 (GitHub zachswift615/speak2) — Clipboard-Swap-Pattern bestätigt
- nilcoalescing.com — NSPasteboard.clearContents() + setString() Pattern — https://nilcoalescing.com/blog/CopyStringToClipboardInSwiftOnMacOS/

### Tertiary (LOW confidence)
- Diverse WebSearch-Ergebnisse zu kAXSelectedTextRangeAttribute Unicode-Offset-Semantik — nicht offiziell verifiziert

---

## Metadata

**Confidence Breakdown:**
- Standard Stack: HIGH — Keine neuen Dependencies; bestehende APIs gut dokumentiert
- AX Aufrufsequenz: HIGH für Reihenfolge; MEDIUM für Edge-Cases (Unicode-Offsets, per-App-Varianten)
- Pitfalls: HIGH für 2040-Limit und Threading; MEDIUM für per-App-Varianten

**Research Date:** 2026-04-18
**Valid until:** 2026-05-18 (stabile API; kein schneller Wandel erwartet)
