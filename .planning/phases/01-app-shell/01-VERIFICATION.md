---
phase: 01-app-shell
verified: 2026-04-16T12:00:00Z
status: passed
score: 4/4
overrides_applied: 0
re_verification: null
gaps: []
human_verification: []
---

# Phase 1: App Shell — Verifikationsbericht

**Phasenziel:** Native macOS Menu-Bar-App Shell — App startet als Menu-Bar-only-Prozess (kein Dock-Icon), zeigt ein zustandsbasiertes Mikrofon-Icon mit 4 visuell unterscheidbaren Zuständen (idle/recording/transcribing/llmProcessing), reagiert auf einen globalen Hotkey und einen LaunchAtLogin-Toggle.
**Verifiziert:** 2026-04-16T12:00:00Z
**Status:** PASSED
**Re-Verifikation:** Nein — initiale Verifikation

---

## Schritt 0: Vorherige Verifikation

Keine frühere VERIFICATION.md im Verzeichnis gefunden. Initiale Verifikation.

---

## Schritt 1: Roadmap Success Criteria

Aus ROADMAP.md Phase 1:

1. App startet ohne Dock-Icon; nur das Menu-Bar-Icon ist sichtbar
2. Drücken des Standard-Hotkeys (⌥⌘R) cycelt das Icon durch Idle, Recording, Transcribing und LLM-Zustände visuell
3. Ein Menü-Dropdown zeigt App-Name, eine Beenden-Option und einen Placeholder für Einstellungen
4. Die App kann so konfiguriert werden, dass sie beim Login automatisch startet — via Toggle im Menü

---

## Ziel-Erreichung

### Beobachtbare Wahrheiten (Observable Truths)

| # | Wahrheit | Status | Evidenz |
|---|----------|--------|---------|
| 1 | App startet ohne Dock-Icon; nur Menu-Bar-Icon sichtbar (SET-06) | VERIFIED | `LSUIElement=<true/>` in Info.plist; `NSApp.setActivationPolicy(.accessory)` in AppDelegate.applicationDidFinishLaunching; manuell bestätigt (Plan 04 Task 1, approved) |
| 2 | ⌥⌘R cycelt Icon durch alle 4 Zustände (SET-02, FEED-01) | VERIFIED | `KeyboardShortcuts.Name.toggleRecording` mit `default: .init(.r, modifiers: [.option, .command])`; `KeyboardShortcuts.onKeyUp(for: .toggleRecording)` in AppDelegate.setupHotkey(); toggleRecording() cycelt idle→recording→transcribing→llmProcessing→idle; manuell bestätigt (Plan 04 Task 2, approved) |
| 3 | Menü-Dropdown zeigt App-Name, Beenden-Option und Einstellungen-Placeholder (D-05) | VERIFIED | AppDelegate.showMenu() baut NSMenu mit "SPRECHKRAFT" (disabled), Trennlinie, "Einstellungen…", "Beim Login starten", Trennlinie, "Beenden"; manuell bestätigt (Plan 04 Task 3, approved) |
| 4 | LaunchAtLogin-Toggle im Menü konfigurierbar und persistent (SET-05) | VERIFIED | `LaunchAtLogin.isEnabled.toggle()` in AppDelegate.toggleLoginItem(); Menü-Item-State reflektiert `LaunchAtLogin.isEnabled`; manuell bestätigt mit Persistenz über App-Neustart (Plan 04 Task 4, approved) |

**Score: 4/4 Wahrheiten verifiziert**

---

### Aufgeschobene Elemente

Keine aufgeschobenen Elemente — alle Success Criteria dieser Phase sind erfüllt.

---

### Notwendige Artefakte

| Artefakt | Erwartet | Status | Details |
|----------|----------|--------|---------|
| `SPRECHKRAFT/AppState.swift` | RecordingState-Enum + AppState @Observable Source of Truth | VERIFIED | Existiert, 71 Zeilen, enthält `enum RecordingState: Equatable` mit 4 Fällen, Farben, isPulsing, pulseSpeed, accessibilityLabel; `@MainActor @Observable final class AppState` mit toggleRecording() |
| `SPRECHKRAFT/StatusBarIconView.swift` | SwiftUI View für Menu-Bar-Icon mit Pulse-Animation | VERIFIED | Existiert, 67 Zeilen, enthält `mic.fill`, `.renderingMode(.original)`, `repeatForever(autoreverses: true)`, `let state: RecordingState` |
| `SPRECHKRAFT/Constants/DesignTokens.swift` | Design-Token-Konstanten (Spacing) | VERIFIED | Existiert, 26 Zeilen, enthält `enum DesignTokens` mit `enum Spacing` (xs/sm/md/lg/xl) |
| `SPRECHKRAFT/Extensions/KeyboardShortcuts+Names.swift` | KeyboardShortcuts.Name.toggleRecording mit ⌥⌘R | VERIFIED | Existiert, 17 Zeilen, enthält `extension KeyboardShortcuts.Name` + `toggleRecording` + `default: .init(.r, modifiers: [.option, .command])` |
| `SPRECHKRAFT/AppDelegate.swift` | NSStatusItem-Setup, Split-Click-Handler, NSMenu, Hotkey-Callback | VERIFIED | Existiert, 152 Zeilen, enthält NSStatusItem, sendAction(on: [.leftMouseUp, .rightMouseUp]), handleClick, showMenu, NSHostingView, KeyboardShortcuts.onKeyUp, LaunchAtLogin.isEnabled, Notification.Name.openSettings |
| `SPRECHKRAFT/SettingsView.swift` | Leeres SwiftUI-Fenster mit Placeholder-Text | VERIFIED | Existiert, 24 Zeilen, enthält "Einstellungen folgen in weiteren Phasen.", DesignTokens.Spacing.xl, Color(.labelColor) |
| `SPRECHKRAFT/SPRECHKRAFTApp.swift` | @main SwiftUI App mit NSApplicationDelegateAdaptor und Window-Scenes | VERIFIED | Existiert, 74 Zeilen, enthält `@main`, `@NSApplicationDelegateAdaptor(AppDelegate.self)`, `Window("SPRECHKRAFT — Einstellungen", id: "settings")`, `Window("Hidden", id: "hidden")`, NSApp.setActivationPolicy(.regular/.accessory), NotificationCenter-Empfänger, appDelegate.appState = appState |
| `SPRECHKRAFT/Info.plist` | LSUIElement=YES für Menu-Bar-Only-App | VERIFIED | Enthält `<key>LSUIElement</key><true/>` |
| `SPRECHKRAFT/SPRECHKRAFT.entitlements` | Entitlements-Datei OHNE com.apple.security.app-sandbox | VERIFIED | Leeres dict-Plist, kein Sandbox-Entitlement (grep gibt exit code 1) |
| `SPRECHKRAFTTests/RecordingStateTests.swift` | Test-Scaffold für RecordingState (FEED-01) | VERIFIED | Existiert, 54 Zeilen, Swift Testing (@Suite, @Test), 8 Tests für 4 Fälle, Farben, isPulsing, pulseSpeed, accessibilityLabel |
| `SPRECHKRAFTTests/AppStateTests.swift` | Test-Scaffold für AppState.toggleRecording | VERIFIED | Existiert, 25 Zeilen, Swift Testing, 2 Tests für Initialzustand und Demo-Cycle |
| `SPRECHKRAFTTests/HotkeyTests.swift` | Test-Scaffold für KeyboardShortcuts-Integration | VERIFIED | Existiert, 24 Zeilen, Swift Testing, 2 Tests für Name-Deklaration und Shortcut ⌥⌘R |

---

### Key Link Verifikation

| Von | Nach | Via | Status | Details |
|-----|------|-----|--------|---------|
| AppDelegate.swift | AppState.swift | appState Property Injection durch SPRECHKRAFTApp | VERIFIED | `var appState: AppState?` in AppDelegate; `appDelegate.appState = appState` in HiddenActivationView.onAppear |
| AppDelegate.swift | StatusBarIconView.swift | NSHostingView(rootView: StatusBarIconView(state:)) | VERIFIED | `NSHostingView(rootView: StatusBarIconView(state: state))` in updateIcon() |
| AppDelegate.swift | KeyboardShortcuts.Name.toggleRecording | KeyboardShortcuts.onKeyUp(for:) Registrierung | VERIFIED | `KeyboardShortcuts.onKeyUp(for: .toggleRecording)` in setupHotkey() |
| AppDelegate.swift | LaunchAtLogin.isEnabled | LaunchAtLogin-modern-API im Menu-Item-State und -Action | VERIFIED | `loginItem.state = LaunchAtLogin.isEnabled ? .on : .off` und `LaunchAtLogin.isEnabled.toggle()` |
| SPRECHKRAFTApp.swift | SettingsView.swift | Window('settings'-ID) Scene | VERIFIED | `Window("SPRECHKRAFT — Einstellungen", id: "settings") { SettingsView() }` |
| AppDelegate.swift | SPRECHKRAFTApp.swift | NotificationCenter.default.post(name: .openSettings) | VERIFIED | `NotificationCenter.default.post(name: .openSettings, object: nil)` in openSettingsMenu(); empfangen via `.onReceive(NotificationCenter.default.publisher(for: .openSettings))` in HiddenActivationView |
| SPRECHKRAFT.xcodeproj | SPRECHKRAFT/Info.plist | INFOPLIST_FILE Build Setting | VERIFIED | `INFOPLIST_FILE = SPRECHKRAFT/Info.plist` + `GENERATE_INFOPLIST_FILE = NO` in pbxproj |
| SPRECHKRAFT.xcodeproj | Package.swift / SPM | SPM Package Dependency | VERIFIED | KeyboardShortcuts, LaunchAtLogin, Defaults als `XCRemoteSwiftPackageReference` im pbxproj registriert |
| SPRECHKRAFTTests/*.swift | SPRECHKRAFT.xcodeproj | PBXBuildFile am SPRECHKRAFTTests-Target | VERIFIED | RecordingStateTests.swift, AppStateTests.swift, HotkeyTests.swift je als PBXBuildFile mit PBXFileReference im pbxproj eingetragen |

---

### Data-Flow Trace (Level 4)

| Artefakt | Datenvariable | Quelle | Liefert reale Daten | Status |
|----------|---------------|--------|---------------------|--------|
| StatusBarIconView | `state: RecordingState` | AppDelegate.updateIcon() → AppState.recordingState | Ja — AppState.recordingState wird per toggleRecording() mutiert | FLOWING |
| AppDelegate.updateIcon() | `appState?.recordingState` | AppState (injiziert via SPRECHKRAFTApp.HiddenActivationView.onAppear) | Ja — AppState ist @Observable, Zustandswechsel trigggert updateIcon() via Variante B | FLOWING |

---

### Verhaltens-Spot-Checks (Step 7b)

Verhaltens-Spot-Checks für laufende App sind nicht automatisiert ausführbar (kein Server/laufende App-Instanz im CI-Kontext). Alle 4 Checkpoints wurden manuell durch den Nutzer in Plan 04 verifiziert (approved):

| Verhalten | Ergebnis | Status |
|-----------|----------|--------|
| App startet ohne Dock-Icon | approved (Plan 04 Task 1) | PASS |
| 4 Icon-Zustände per Linksklick + ⌥⌘R | approved (Plan 04 Task 2) | PASS |
| Menü-Struktur + Einstellungsfenster | approved (Plan 04 Task 3) | PASS |
| LaunchAtLogin persistent über App-Neustart | approved (Plan 04 Task 4) | PASS |

---

### Requirements-Abdeckung

| Requirement | Quellplan | Beschreibung | Status | Evidenz |
|-------------|-----------|--------------|--------|---------|
| SET-06 | 01-01, 01-03 | App läuft als Menu Bar App ohne Dock-Icon (LSUIElement = YES) | SATISFIED | LSUIElement=true in Info.plist; NSApp.setActivationPolicy(.accessory) in AppDelegate; manuell bestätigt |
| SET-02 | 01-03 | Globaler Aufnahme-Hotkey konfigurierbar (Standard: ⌥⌘R) | SATISFIED | KeyboardShortcuts.Name.toggleRecording mit default ⌥⌘R; onKeyUp-Registrierung in AppDelegate; HotkeyTests grün; manuell bestätigt |
| SET-05 | 01-03 | App startet automatisch beim Mac-Login (konfigurierbar) | SATISFIED | LaunchAtLogin.isEnabled.toggle() im NSMenu; Persistenz über App-Neustart manuell bestätigt |
| FEED-01 | 01-02 | Menüleisten-Icon zeigt 4 Zustände: Idle / Aufnahme / Transkribieren / LLM-Verarbeitung | SATISFIED | RecordingState-Enum mit 4 Fällen, Farben, Pulse-Animation; StatusBarIconView; NSHostingView-Integration; alle RecordingStateTests grün; manuell bestätigt |

**Keine verwaisten Requirements** — alle für Phase 1 in REQUIREMENTS.md notierten IDs (SET-06, SET-02, SET-05, FEED-01) sind in Plans deklariert und verifiziert.

---

### Anti-Pattern-Scan

| Datei | Zeile | Muster | Schwere | Auswirkung |
|-------|-------|--------|---------|------------|
| — | — | — | — | Keine Anti-Patterns gefunden |

**Scan-Ergebnis:** Kein TODO/FIXME/PLACEHOLDER, keine leeren Implementierungen, keine hartkodierten leeren Arrays/Dicts in rendering-relevanten Pfaden. SettingsView zeigt absichtlich einen Placeholder-Text ("Einstellungen folgen in weiteren Phasen.") — dieser ist kein Stub, sondern der vollständig implementierte Phase-1-Inhalt gemäß UI-SPEC D-07.

---

### Besondere technische Abweichungen (dokumentiert, kein Fehler)

Zwei Abweichungen vom ursprünglichen Plan wurden korrekt dokumentiert und sind fachlich unbedenklich:

1. **SwiftUI `.renderingMode(.original)` statt `.alwaysOriginal`**: SwiftUI's `Image.TemplateRenderingMode` kennt kein `.alwaysOriginal` (das ist die NSImage/UIImage-API). `.original` ist die korrekte SwiftUI-Entsprechung mit identischem Verhalten.

2. **Observation-Strategie Variante B**: Manueller `updateIcon()`-Aufruf nach jedem `toggleRecording()` statt `withObservationTracking`. Diese Variante ist expliziter, für Swift 6 strict concurrency robuster und erzielt dasselbe Ergebnis. Dokumentiert in 01-03-SUMMARY.md.

---

### Menschliche Verifikation erforderlich

Alle manuell verifizierbaren Aspekte wurden durch den Nutzer in Plan 04 (2026-04-16) abgenommen:

- Task 1 (SET-06): Kein Dock-Icon, Menu-Bar-Icon sichtbar — **approved**
- Task 2 (FEED-01, SET-02): 4 Icon-Zustände mit Animation, Hotkey systemweit aktiv — **approved**
- Task 3 (D-05, D-06, D-07): Menü-Struktur korrekt, Einstellungsfenster öffnet und schließt — **approved**
- Task 4 (SET-05): LaunchAtLogin-Toggle persistent über App-Neustart — **approved**

Keine weiteren menschlichen Verifikations-Punkte offen.

---

### Lücken-Zusammenfassung

**Keine Lücken.** Alle 4 Roadmap Success Criteria sind vollständig implementiert und verifiziert:

1. Kein Dock-Icon beim Start — durch LSUIElement + .accessory Policy — manuell bestätigt
2. Hotkey ⌥⌘R cycelt 4 Icon-Zustände — durch KeyboardShortcuts + RecordingState-Maschine — manuell bestätigt
3. Menü-Dropdown mit App-Name, Beenden, Einstellungen-Placeholder — implementiert — manuell bestätigt
4. LaunchAtLogin-Toggle im Menü, persistent — durch LaunchAtLogin-modern — manuell bestätigt

Alle 12 Unit-Tests (RecordingStateTests 8/8, AppStateTests 2/2, HotkeyTests 2/2) laufen grün. Build erfolgreich ohne Swift-6-Warnungen.

---

_Verifiziert: 2026-04-16T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
