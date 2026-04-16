---
phase: 01-app-shell
plan: "03"
subsystem: app-integration
tags: [swift6, appkit, nsstatusitem, split-click, nsmenu, hotkey, login-toggle, swiftui-scenes]
dependency_graph:
  requires:
    - 01-01 (Xcode-Projektgerüst, pbxproj, SPM-Dependencies)
    - 01-02 (AppState, RecordingState, StatusBarIconView, KeyboardShortcuts+Names, DesignTokens)
  provides:
    - AppDelegate (NSStatusItem, Split-Click, NSMenu, Hotkey, Login-Toggle)
    - VoiceScribeApp (@main, NSApplicationDelegateAdaptor, Window-Scenes)
    - SettingsView (Placeholder-Fenster)
    - Notification.Name.openSettings (AppDelegate → VoiceScribeApp Brücke)
  affects:
    - 01-04 (Human-Verify-Checkpoint — visuelles Testen der lauffähigen App)
tech_stack:
  added:
    - AppKit NSStatusItem (Split-Click via sendAction(on:))
    - AppKit NSMenu (temporäres Pattern: menu = menu → performClick → menu = nil)
    - SwiftUI Window-Scene (verstecktes Aktivierungsfenster + Einstellungsfenster)
    - NSHostingView für SwiftUI-Embedding in NSStatusItem.button
    - NotificationCenter-Brücke (AppKit → SwiftUI)
    - NSApp.setActivationPolicy(.regular/.accessory) für Settings-Öffnung
  patterns:
    - "Variante B: manueller updateIcon()-Aufruf nach toggleRecording() — robust für Swift 6"
    - "NSMenu temporäres Pattern: menu nil-Reset nach performClick() (Pitfall 1)"
    - "Activation-Policy-Switch: .accessory → .regular → Fenster → .accessory"
    - "Guard in updateIcon() gegen nil-statusItem bei Test-Host-Startup"
key_files:
  created:
    - VoiceScribe/AppDelegate.swift
    - VoiceScribe/SettingsView.swift
  modified:
    - VoiceScribe/VoiceScribeApp.swift (Placeholder aus Plan 01 überschrieben)
    - VoiceScribe.xcodeproj/project.pbxproj (AppDelegate + SettingsView registriert)
decisions:
  - "Observation-Strategie B (manueller updateIcon()-Aufruf) statt withObservationTracking — robuster für Swift 6 strict concurrency"
  - "Guard statusItem != nil in updateIcon() — verhindert Crash wenn onAppear vor applicationDidFinishLaunching feuert"
  - "Task 1 (KeyboardShortcuts+Names.swift) bereits in Plan 02 vorgezogen — nur Verifikation in Plan 03"
metrics:
  duration_minutes: 20
  completed_date: "2026-04-16"
  tasks_total: 4
  tasks_completed: 4
  files_created: 2
  files_modified: 2
requirements_satisfied:
  - SET-02
  - SET-05
  - SET-06
---

# Phase 01 Plan 03: Integration — AppDelegate, VoiceScribeApp und SettingsView Summary

Integrationsschicht, die alle Plan-02-Bausteine zu einer lauffähigen macOS-Menu-Bar-App verbindet: NSStatusItem mit Split-Click, NSMenu mit 4 Einträgen, globaler Hotkey ⌥⌘R via KeyboardShortcuts, LaunchAtLogin-Toggle, SwiftUI Window-Scenes für Einstellungsfenster und Notification-Brücke für Settings-Aktivierung — alle 12 Tests grün, Build erfolgreich.

## Completed Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | KeyboardShortcuts.Name-Extension mit ⌥⌘R | (in Plan 02 vorgezogen: e5d542b) | VoiceScribe/Extensions/KeyboardShortcuts+Names.swift |
| 2 | SettingsView als leerer SwiftUI-Placeholder | 1888302 | VoiceScribe/SettingsView.swift, project.pbxproj |
| 3 | AppDelegate mit NSStatusItem, Split-Click, NSMenu, Hotkey, Login-Toggle | f737087 | VoiceScribe/AppDelegate.swift |
| 4 | VoiceScribeApp @main mit Window-Scenes und Settings-Aktivierung | 1b5bef9 | VoiceScribe/VoiceScribeApp.swift |

## Build Status

**App-Target:** BUILD SUCCEEDED
- Xcode 26.4, Swift 6.0, macOS 14.0 Deployment Target
- Keine Swift-6-Warnungen zu Sendable/MainActor/data race

**Test-Target:** TEST SUCCEEDED — alle 12 Tests grün

| Test Suite | Tests | Status |
|-----------|-------|--------|
| RecordingStateTests | 8 | PASSED |
| AppStateTests | 2 | PASSED |
| HotkeyTests | 2 | PASSED |
| **Total** | **12** | **PASSED** |

## Requirements-Status

| Requirement | Beschreibung | Status |
|------------|-------------|--------|
| SET-02 | Globaler Hotkey ⌥⌘R konfigurierbar | DONE — KeyboardShortcuts.onKeyUp(for: .toggleRecording) in AppDelegate.setupHotkey() |
| SET-05 | Login-Toggle konfigurierbar | DONE — LaunchAtLogin.isEnabled.toggle() im NSMenu |
| SET-06 | Kein Dock-Icon | DONE — NSApp.setActivationPolicy(.accessory) + LSUIElement=YES |
| FEED-01 | Icon-Zustände mit Farbe + Animation | DONE — NSHostingView(rootView: StatusBarIconView) + updateIcon() nach jedem Toggle |

## Observation-Strategie: Variante B (manueller updateIcon()-Aufruf)

**Gewählte Variante:** B — manueller `updateIcon()`-Aufruf nach jedem `toggleRecording()`-Aufruf.

**Begründung:** Variante A (`withObservationTracking` mit rekursiver Re-Registrierung) wurde als Implementierungsoption erwogen. Variante B wurde als explizitere und robustere Lösung für Swift 6 strict concurrency gewählt, da sie keine Abhängigkeit vom re-registration-Mechanismus von `withObservationTracking` hat. Das Verhalten ist deterministisch und leicht nachvollziehbar.

**Aufrufstellen von updateIcon() bei Variante B:**
1. `applicationDidFinishLaunching(_:)` — initialer Icon-Zustand beim Start
2. `handleClick(_:)` — nach `appState?.toggleRecording()` bei Linksklick
3. Hotkey-Callback in `setupHotkey()` — nach `self?.appState?.toggleRecording()` in `Task { @MainActor }`
4. `HiddenActivationView.onAppear` — nach AppState-Injection (ruft `appDelegate.updateIcon()` auf)

## Threat Mitigations Applied

| Threat | Mitigation |
|--------|-----------|
| T-01-10 (Hotkey Tampering) | KeyboardShortcuts-Library übernimmt Konflikt-Erkennung; kein eigener CGEventTap |
| T-01-12 (Policy-Wechsel Elevation) | Wechsel zu .regular nur im Settings-Öffnungs-Scope; nach 300ms zurück zu .accessory |
| T-01-13 (statusItem.menu nil) | statusItem.menu = nil direkt nach performClick(nil) in showMenu() |
| T-01-15 (Notification Spoofing) | com.voicescribe.openSettings Bundle-ID-Präfix; NotificationCenter.default ist prozess-lokal |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Crash in Test-Umgebung: updateIcon() vor statusItem-Initialisierung**
- **Gefunden während:** Task 3/4 Verifikation (Tests nach App-Build)
- **Problem:** `updateIcon()` wird von `HiddenActivationView.onAppear` aufgerufen. Wenn die App als Test-Host startet, feuert `onAppear` vor `applicationDidFinishLaunching` abgeschlossen ist — `statusItem` ist noch `nil`. Zugriff auf `NSStatusItem!` mit nil → `Fatal error: Unexpectedly found nil while implicitly unwrapping an Optional value` → Test-Runner-Crash.
- **Fix:** Guard `guard statusItem != nil, let button = statusItem.button else { return }` am Anfang von `updateIcon()`. Außerdem direkte Button-Variable statt wiederholtem `statusItem.button?`-Zugriff.
- **Dateien:** VoiceScribe/AppDelegate.swift
- **Commit:** f737087

### Nicht umgesetzte Punkte (plangemäß)

**Task 1 bereits in Plan 02 vorgezogen:**
- `KeyboardShortcuts+Names.swift` wurde in Plan 02 Task 2 vorgezogen, da HotkeyTests.swift ohne die Extension das Test-Target blockiert hätte.
- In Plan 03 war nur noch die Verifikation der HotkeyTests notwendig (beide grün: `nameIsDeclared()` und `initialShortcut()`).
- Kein zusätzlicher Commit nötig — die Extension existiert bereits mit dem korrekten `default:`-Parameter.

## Öffentliche API-Contracts

### AppDelegate

```swift
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?   // Property Injection durch VoiceScribeApp
    func updateIcon()         // Öffentlich für HiddenActivationView.onAppear
}
```

### Notification.Name

```swift
extension Notification.Name {
    static let openSettings = Notification.Name("com.voicescribe.openSettings")
    // Gepostet von AppDelegate.openSettingsMenu()
    // Empfangen von HiddenActivationView.onReceive(_:)
}
```

### SettingsView

```swift
struct SettingsView: View  // Keine öffentlichen Properties — reiner Placeholder
```

## Screenshot-Hinweise für Plan 04 (Human-Verify-Checkpoint)

Plan 04 wird folgende manuelle Verifikations-Punkte prüfen:

1. **App startet ohne Dock-Icon** — nur Menu-Bar-Icon, kein Eintrag im Dock
2. **Menu-Bar-Icon erscheint** — `mic.fill` in Grau (#8E8E93) in der Menüleiste
3. **Linksklick auf Icon** — Icon wechselt Farbe (grau → rot → blau → lila → grau zyklisch)
4. **Rechtsklick auf Icon** — Menü erscheint mit: "VoiceScribe" (disabled), Trennlinie, "Einstellungen…", "Beim Login starten" (mit/ohne Haken), Trennlinie, "Beenden"
5. **Hotkey ⌥⌘R** — Icon cycelt (gleiche Wirkung wie Linksklick, systemweit)
6. **"Einstellungen…" Klick** — Fenster "VoiceScribe — Einstellungen" öffnet sich, Placeholder-Text sichtbar
7. **"Beenden"** — App beendet sich vollständig

## Known Stubs

Keine — alle implementierten Features sind vollständig verdrahtet. Das Einstellungsfenster ist bewusst als Placeholder konzipiert (D-07); echte Einstellungen folgen in späteren Phasen.

## Self-Check: PASSED

- [x] VoiceScribe/SettingsView.swift: FOUND
- [x] VoiceScribe/AppDelegate.swift: FOUND
- [x] VoiceScribe/VoiceScribeApp.swift: FOUND (überschrieben)
- [x] Commit 1888302: FOUND (feat(01-03): add SettingsView placeholder)
- [x] Commit f737087: FOUND (feat(01-03): add AppDelegate...)
- [x] Commit 1b5bef9: FOUND (feat(01-03): implement VoiceScribeApp @main...)
- [x] BUILD SUCCEEDED (App-Target)
- [x] TEST SUCCEEDED (12/12 Tests grün)
- [x] SET-02 implementiert: KeyboardShortcuts.onKeyUp(for: .toggleRecording) in AppDelegate
- [x] SET-05 implementiert: LaunchAtLogin.isEnabled.toggle() in AppDelegate
- [x] SET-06 implementiert: NSApp.setActivationPolicy(.accessory) + LSUIElement=YES
- [x] FEED-01 implementiert: NSHostingView(rootView: StatusBarIconView) in updateIcon()
