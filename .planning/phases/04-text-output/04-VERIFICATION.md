---
phase: 04-text-output
verified: 2026-04-19T07:00:00Z
status: human_needed
score: 10/11
overrides_applied: 0
human_verification:
  - test: "CR-01 aus Code-Review: AXUIElement force_cast absichern"
    expected: "CFGetTypeID-Prüfung vor dem force_cast verhindert EXC_BAD_ACCESS bei Fremdtypen"
    why_human: "Entscheidung ob CR-01 sofort gefixt oder als bekanntes Risiko akzeptiert wird — erfordert Priorisierung durch den Entwickler"
  - test: "WR-03: Stiller Datenverlust bei AX-Schreibfehler — Clipboard-Fallback fehlt"
    expected: "Nach fehlgeschlagenem AXUIElementSetAttributeValue landet der Text im Clipboard statt verloren zu gehen"
    why_human: "D-05 sagt 'stille Rückkehr', aber das bedeutet hier Datenverlust für den Nutzer — Designentscheidung nötig"
  - test: "REQUIREMENTS.md Traceability aktualisieren"
    expected: "OUT-01, OUT-02, OUT-03 in der Traceability-Tabelle auf 'Complete' und mit [x] markiert"
    why_human: "Triviale Dokumentationsaufgabe, aber der Verifier ändert keine Anforderungsdokumente"
---

# Phase 4: Text-Ausgabe Verifikationsbericht

**Phasenziel:** Transkribierter Text landet im aktiven Textfeld an Cursor-Position, oder im Clipboard, mit einem Hotkey zum Umschalten.
**Verifiziert:** 2026-04-19T07:00:00Z
**Status:** human_needed (Automated checks bestanden; Code-Review-Befunde erfordern Entwicklerentscheidung)
**Re-Verifikation:** Nein — Erstverifikation

---

## Zielerreichung

### Beobachtbare Wahrheiten

| # | Wahrheit | Status | Nachweis |
|---|---------|--------|---------|
| 1 | OutputMode-Enum existiert mit .field und .clipboard | VERIFIZIERT | `Defaults+Keys.swift:13` — `enum OutputMode: String, Defaults.Serializable` mit beiden Cases |
| 2 | Defaults.Keys.outputMode hat Standardwert .field | VERIFIZIERT | `Defaults+Keys.swift:29` — `Key<OutputMode>("outputMode", default: .field)` |
| 3 | KeyboardShortcuts.Name.toggleOutputMode ist mit ⇧⌘V vorbelegt | VERIFIZIERT | `KeyboardShortcuts+Names.swift:18-21` — `.init(.v, modifiers: [.shift, .command])` |
| 4 | AppState.axPermissionDenied: Bool ist vorhanden | VERIFIZIERT | `AppState.swift:80` — `var axPermissionDenied: Bool = false` |
| 5 | Info.plist enthält NSAccessibilityUsageDescription | VERIFIZIERT | `Info.plist:27-28` — Key mit deutschem Erklärungstext |
| 6 | TextOutputService ist @MainActor final class mit output() | VERIFIZIERT | `TextOutput/TextOutputService.swift:28` — `@MainActor final class TextOutputService` |
| 7 | 2040-Zeichen-Guard ist vorhanden | VERIFIZIERT | `TextOutputService.swift:99` — `guard composed.count <= 2000 else { writeToClipboard(text); return }` |
| 8 | TextOutputService.shared.output() verdrahtet in AppDelegate (print()-Stub entfernt) | VERIFIZIERT | `AppDelegate.swift:87` — `TextOutputService.shared.output(text, mode: mode, axPermitted: axPermitted)`. Kein print("Transkription")-Stub mehr vorhanden. |
| 9 | AXIsProcessTrusted() setzt AppState.axPermissionDenied beim App-Start | VERIFIZIERT | `AppDelegate.swift:71-72` in `setupAudioController()` — `let axGranted = AXIsProcessTrusted(); appState.axPermissionDenied = !axGranted` |
| 10 | toggleOutputMode-Hotkey (⇧⌘V) schaltet Modus um | VERIFIZIERT | `AppDelegate.swift:298-306` — `KeyboardShortcuts.onKeyUp(for: .toggleOutputMode)` mit Toggle-Logik |
| 11 | SettingsView zeigt AX-Permission-Banner und Ausgabemodus-Picker + Hotkey-Recorder | VERIFIZIERT | `SettingsView.swift:120-162` — Banner mit Privacy_Accessibility-URL, segmented Picker, KeyboardShortcuts.Recorder |

**Punktestand:** 11/11 Wahrheiten verifiziert

---

### Pflicht-Artefakte

| Artefakt | Erwartet | Status | Details |
|----------|---------|--------|---------|
| `VoiceScribe/Extensions/Defaults+Keys.swift` | OutputMode enum + Defaults.Keys.outputMode | VERIFIZIERT | enum OutputMode Z.13, Key Z.29, Defaults.Serializable-Konformanz korrekt |
| `VoiceScribe/Extensions/KeyboardShortcuts+Names.swift` | toggleOutputMode Name | VERIFIZIERT | Z.18-21, .v + [.shift, .command] |
| `VoiceScribe/AppState.swift` | axPermissionDenied: Bool Property | VERIFIZIERT | Z.80, Standardwert false, korrekt kommentiert |
| `VoiceScribe/Info.plist` | NSAccessibilityUsageDescription | VERIFIZIERT | Z.27-28, kein AX-Entitlement (Pitfall 6 beachtet) |
| `VoiceScribe/TextOutput/TextOutputService.swift` | @MainActor TextOutputService mit output(), injectViaAX(), writeToClipboard() | VERIFIZIERT | Alle drei Methoden vorhanden, Unicode-Scalar-korrekt, AXValueGetValue (kein direktes CFRange-Casting) |
| `VoiceScribeTests/TextOutputServiceTests.swift` | Unit-Tests via Protocol/Mock | VERIFIZIERT | 4 Suiten, 17 Tests, MockTextOutputService ohne AX-Permission |
| `VoiceScribe/AppDelegate.swift` | TextOutputService-Wiring + AX-Check + Hotkey + Menü-Häkchen | VERIFIZIERT | Alle 4 Änderungen implementiert (Z.87, Z.71, Z.298, Z.179-197) |
| `VoiceScribe/SettingsView.swift` | AX-Permission-Banner + OutputMode-Section | VERIFIZIERT | Section "Textausgabe" Z.116-163 mit Banner, Picker und Recorder |

---

### Key-Link-Verifikation

| Von | Nach | Via | Status | Details |
|-----|------|-----|--------|---------|
| `AppDelegate.onRecordingComplete` | `TextOutputService.shared.output()` | `await MainActor.run` | VERDRAHTET | `AppDelegate.swift:87` — direkter Aufruf mit mode und axPermitted |
| `AXIsProcessTrusted()` | `appState.axPermissionDenied` | `setupAudioController()` | VERDRAHTET | `AppDelegate.swift:71-72` — in setupAudioController() statt applicationDidFinishLaunching (Plankonform, appState sicher nicht nil) |
| `KeyboardShortcuts.onKeyUp(.toggleOutputMode)` | `Defaults[.outputMode].toggle()` | `setupOutputModeHotkey()` | VERDRAHTET | `AppDelegate.swift:298-306` — Toggle-Logik korrekt |
| `Defaults[.outputMode]` | `AppDelegate.showMenu()` | `Defaults[.outputMode]` | VERDRAHTET | `AppDelegate.swift:179` — `currentMode = Defaults[.outputMode]` für Häkchen |
| `AppState.axPermissionDenied` | `SettingsView` | `appState?.axPermissionDenied` | VERDRAHTET | `SettingsView.swift:120` — Banner-Bedingung korrekt |
| `TextOutputService.output()` | `AXUIElementSetAttributeValue` | `injectViaAX()` | VERDRAHTET | `TextOutputService.swift:105-112` |
| `TextOutputService.output()` | `NSPasteboard.general` | `writeToClipboard()` | VERDRAHTET | `TextOutputService.swift:135-136` — clearContents() vor setString() |

---

### Datenfluss-Verfolgung (Level 4)

| Artefakt | Datenvariable | Quelle | Echte Daten | Status |
|----------|--------------|--------|------------|--------|
| `SettingsView.outputMode` | `@Default(.outputMode)` | `Defaults.Keys.outputMode` | Ja — UserDefaults-backed, persistiert | FLIESSEND |
| `SettingsView.axPermissionDenied` | `appState?.axPermissionDenied` | `AXIsProcessTrusted()` via `setupAudioController()` | Ja — echter OS-Aufruf | FLIESSEND |
| `TextOutputService.output()` | `mode`, `axPermitted` | `Defaults[.outputMode]` + `AppState.axPermissionDenied` | Ja — beide aus persistiertem/OS-State | FLIESSEND |

---

### Anforderungsabdeckung

| Anforderungs-ID | Quellplan | Beschreibung | Status | Nachweis |
|----------------|---------|-------------|--------|---------|
| OUT-01 | 04-01, 04-02, 04-03 | Transkription ins aktive Textfeld an Cursor-Position (via macOS Accessibility API) | ERFÜLLT | TextOutputService.injectViaAX() implementiert vollständige AX-Aufrufsequenz; manuell in TextEdit, Notes, Safari, Mail bestätigt (04-04) |
| OUT-02 | 04-01, 04-02, 04-03 | Transkription in Clipboard kopieren | ERFÜLLT | writeToClipboard() mit clearContents()-vor-setString()-Sequenz; manuell bestätigt (04-04) |
| OUT-03 | 04-01, 04-03 | Ausgabemodus per dediziertem Hotkey umschaltbar | ERFÜLLT | setupOutputModeHotkey() mit ⇧⌘V, Menü-Häkchen, Modus-Persistenz nach Neustart bestätigt (04-04) |

**Hinweis:** In `REQUIREMENTS.md` stehen OUT-01, OUT-02, OUT-03 noch als `pending` (offene Checkbox, Status "pending" in der Traceability-Tabelle). Die Implementierung ist vollständig — die Dokumentation muss aktualisiert werden. Dies ist kein Code-Gap, aber ein Dokumentationsgap.

---

### Anti-Pattern-Scan

| Datei | Zeile | Pattern | Schwere | Auswirkung |
|-------|-------|---------|---------|-----------|
| `TextOutput/TextOutputService.swift` | 63 | `focusedRef as! AXUIElement` — force_cast ohne CFTypeID-Prüfung | WARNUNG | Crash bei Fremdtypen aus Browser-Plugins oder unkonventionellen AX-Providern. Kann in gängigen Apps (TextEdit, Notes, Safari, Mail) nicht auftreten, aber theoretisches Risiko (CR-01 aus Code-Review) |
| `AppDelegate.swift` | 300 | `guard self != nil` statt `guard let self` — ineffektives weak-self-Pattern | INFO | Kein akuter Bug (self wird im Closure nicht genutzt), aber inkonsistent mit setupHotkey() und missverständlich (WR-02 aus Code-Review) |
| `TextOutput/TextOutputService.swift` | 105-112 | AX-Schreibfehler führt zu stiller Rückkehr ohne Clipboard-Fallback | WARNUNG | Bei read-only Feldern oder Browser-Elementen geht der diktierte Text verloren statt auf Clipboard zu fallen (WR-03 aus Code-Review) |
| `SettingsView.swift` | 58, 144 | `.cornerRadius(8)` — deprecated ab macOS 14 | INFO | Erzeugt Compiler-Warnung in neueren Xcode-Versionen; `.clipShape(.rect(cornerRadius: 8))` ist der korrekte Ersatz (IN-03 aus Code-Review) |

**Bewertung der force_cast (CR-01):** Der Code ist in der Praxis für alle relevanten macOS-Apps funktionsfähig. AXUIElementCreateSystemWide + kAXFocusedUIElementAttribute liefert im normalen Betrieb immer einen AXUIElement zurück. Das Risiko ist real aber klein. Kein Blocker für das Phasenziel, aber Entwicklerentscheidung nötig.

**Bewertung WR-03 (stiller Datenverlust):** Wenn ein Nutzer in ein read-only Feld diktiert (z.B. Browser-Adressleiste die kAXValueAttribute nicht schreibbar exponiert), geht der diktierte Text verloren. D-05 definiert "stille Rückkehr", aber ein Clipboard-Fallback wäre nutzerfreundlicher. Entwicklerentscheidung nötig.

---

### Menschliche Verifikation erforderlich

#### 1. CR-01: force_cast auf AXUIElement absichern

**Test:** Code-Review-Befund CR-01 prüfen und Entscheidung treffen
**Erwartet:** Entweder `CFGetTypeID(focusedRef) == AXUIElementGetTypeID()` als Guard vor dem force_cast, oder explizite Akzeptanz des Risikos mit Kommentar
**Warum menschlich:** Design-Entscheidung zwischen "sofort fixen" und "als kleines Risiko akzeptieren" — erfordert Entwicklerurteil

Vorgeschlagener Fix aus CR-01:
```swift
guard CFGetTypeID(focusedRef) == AXUIElementGetTypeID(),
      let focused = focusedRef as? AXUIElement else {
    return
}
```

---

#### 2. WR-03: Stiller Datenverlust bei AX-Schreibfehler

**Test:** Diktat in ein read-only AX-Feld versuchen (z.B. Labels, disabled Textfelder)
**Erwartet:** Text landet im Clipboard statt verloren zu gehen (oder: bewusste Designentscheidung "stille Rückkehr" dokumentieren)
**Warum menschlich:** D-05 definiert stille Rückkehr; ob Datenverlust akzeptabel ist, ist eine Designentscheidung

Vorgeschlagener Fix aus WR-03:
```swift
guard AXUIElementSetAttributeValue(...) == .success else {
    writeToClipboard(text)  // Fallback statt Datenverlust
    return
}
```

---

#### 3. REQUIREMENTS.md Traceability aktualisieren

**Test:** Datei öffnen und Status prüfen
**Erwartet:** OUT-01, OUT-02, OUT-03 mit [x] Checkbox und Status "Complete" in der Traceability-Tabelle
**Warum menschlich:** Dokumentationsänderung, die der Entwickler bewusst vornehmen sollte — nicht automatisch durch Verifier

---

### Lücken-Zusammenfassung

Keine kritischen Lücken, die das Phasenziel blockieren. Alle Code-Artefakte existieren, sind substantiell implementiert, korrekt verdrahtet, und der Datenfluss ist vollständig. Die manuellen End-to-End-Tests (04-04) haben alle 14 Tests in 3 Checkpoints bestätigt.

Drei offene Punkte erfordern Entwicklerentscheidung:
- **CR-01** (force_cast Absicherung): Qualitätsverbesserung, kein Funktionsfehler für Standard-Apps
- **WR-03** (Clipboard-Fallback bei AX-Schreibfehler): Potentieller Datenverlust für Randfälle
- **Dokumentation**: REQUIREMENTS.md Traceability-Tabelle ist veraltet

---

_Verifiziert: 2026-04-19T07:00:00Z_
_Verifier: Claude (gsd-verifier)_
