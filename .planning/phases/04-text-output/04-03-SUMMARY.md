---
phase: 04-text-output
plan: "03"
subsystem: ui
tags: [AppDelegate, SettingsView, TextOutputService, AXIsProcessTrusted, Defaults, KeyboardShortcuts, OutputMode]

dependency_graph:
  requires:
    - plan: "04-01"
      provides: "OutputMode enum, Defaults.Keys.outputMode, KeyboardShortcuts.Name.toggleOutputMode, AppState.axPermissionDenied"
    - plan: "04-02"
      provides: "TextOutputService.shared.output() — @MainActor Singleton fuer AX-Injektion + Clipboard"
  provides:
    - "AppDelegate: TextOutputService.shared.output() ersetzt print()-Stub (OUT-01/OUT-02)"
    - "AppDelegate: AXIsProcessTrusted() in setupAudioController() setzt appState.axPermissionDenied (D-10)"
    - "AppDelegate: setupOutputModeHotkey() mit KeyboardShortcuts.onKeyUp(.toggleOutputMode) (OUT-03, D-09)"
    - "AppDelegate: showMenu() mit Ausgabemodus-Häkchen (D-08)"
    - "SettingsView: Textausgabe-Section mit AX-Permission-Banner + Picker + Hotkey-Recorder (D-08 bis D-12)"
  affects:
    - "Phase 5+ — vollständige Text-Ausgabe-Pipeline ist ab jetzt aktiv"

tech-stack:
  added:
    - "ApplicationServices framework (AXIsProcessTrusted — bereits in Entitlements, neu in AppDelegate)"
  patterns:
    - "AXIsProcessTrusted() in setupAudioController() aufgerufen (appState garantiert nicht nil)"
    - "KeyboardShortcuts.onKeyUp(for:) Pattern fuer zweiten Hotkey analog zu toggleRecording"
    - "showMenu() baut Menü neu bei jedem Öffnen — Häkchen immer aktuell ohne explizites Update"
    - "axPermissionDenied-Banner in SettingsView analog zu micPermissionDenied-Banner (Phase 2)"

key-files:
  created: []
  modified:
    - VoiceScribe/AppDelegate.swift
    - VoiceScribe/SettingsView.swift

key-decisions:
  - "AXIsProcessTrusted() in setupAudioController() aufgerufen statt applicationDidFinishLaunching — appState ist in setupAudioController() garantiert nicht nil (guard let appState else { return })"
  - "setupOutputModeHotkey() in applicationDidFinishLaunching registriert — Hotkey soll ab App-Start verfügbar sein, auch bevor AppState injiziert wird"
  - "showMenu() baut Menü bei jedem Öffnen neu — kein explizites Update-Mechanismus nötig, Häkchen immer korrekt"

patterns-established:
  - "Zweiter Hotkey-Pattern: setupOutputModeHotkey() analog zu setupHotkey() — beide in applicationDidFinishLaunching registriert"
  - "Menü-Häkchen durch Neuaufbau bei jedem showMenu()-Aufruf — kein Beobachtungs-Overhead"

requirements-completed: [OUT-01, OUT-02, OUT-03]

duration: "~15 min"
completed: "2026-04-19"
---

# Phase 04 Plan 03: AppDelegate-Wiring + SettingsView-Erweiterung Summary

**TextOutputService.shared.output() verdrahtet, AXIsProcessTrusted()-Check integriert, toggleOutputMode-Hotkey (⇧⌘V) und Menü-Häkchen in AppDelegate, AX-Permission-Banner + OutputMode-Picker + Hotkey-Recorder in SettingsView — Phase 4 Code-Implementierung vollständig.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-19T06:10:00Z
- **Completed:** 2026-04-19T06:23:08Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- print()-Stub aus AppDelegate entfernt; TextOutputService.shared.output() mit korrektem Modus-Routing verdrahtet (OUT-01/OUT-02)
- AXIsProcessTrusted() in setupAudioController() (appState sicher nicht nil) setzt axPermissionDenied für SettingsView-Banner und TextOutputService-Routing (D-10)
- toggleOutputMode-Hotkey (⇧⌘V) über KeyboardShortcuts.onKeyUp registriert, schaltet Defaults[.outputMode] um (OUT-03, D-09)
- showMenu() zeigt Ausgabemodus-Häkchen mit setOutputModeField/@objc-Actions (D-08)
- SettingsView: Neue Section "Textausgabe" mit rotem AX-Permission-Banner (D-11), segmented Picker (D-08), konfigurierbarem KeyboardShortcuts.Recorder (D-09)

## Task Commits

1. **Task 1: AppDelegate-Wiring TextOutputService, AX-Check, Hotkey, Menü-Häkchen** — `4a735d1` (feat)
2. **Task 2: SettingsView AX-Permission-Banner + OutputMode-Section + Hotkey-Recorder** — `920ef38` (feat)

## Files Created/Modified

- `VoiceScribe/AppDelegate.swift` — TextOutputService-Wiring, AX-Check, setupOutputModeHotkey(), Menü-Häkchen + @objc-Actions
- `VoiceScribe/SettingsView.swift` — Textausgabe-Section, AX-Permission-Banner, OutputMode-Picker, KeyboardShortcuts.Recorder, Preview

## Decisions Made

- AXIsProcessTrusted() in setupAudioController() platziert statt applicationDidFinishLaunching: Plan 03 sah beide Orte vor; setupAudioController() ist sicherer, da appState dort via guard let gebunden ist. In applicationDidFinishLaunching wird appState erst durch VoiceScribeApp.onAppear injiziert.
- setupOutputModeHotkey() in applicationDidFinishLaunching: Hotkey soll systemweit verfügbar sein ab App-Start — kein appState-Zugriff nötig.

## Deviations from Plan

None — Plan exakt wie beschrieben ausgeführt. Die AXIsProcessTrusted()-Platzierung in setupAudioController() (statt doppelt in beiden Methoden) ist plankonform: Plan 03 beschreibt beide Orte, der Code nutzt nur setupAudioController() für den definitiven Check.

## Issues Encountered

None — Build und volle Test-Suite (** TEST SUCCEEDED **) beim ersten Versuch grün.

## Known Stubs

None — alle Phase-4-Ausgabepfade sind vollständig verdrahtet:
- print()-Stub entfernt
- TextOutputService.shared.output() aufgerufen
- axPermissionDenied gesetzt
- Modus-Wechsel via Hotkey und Menü funktionsfähig
- SettingsView zeigt Banner und Picker

## Threat Flags

Keine neuen Trust-Boundaries jenseits des Plan-Threat-Modells:
- T-04-07 (Defaults[.outputMode] via Hotkey): accept — lokale UserDefaults, kein sicherheitskritischer Effekt
- T-04-08 (AXIsProcessTrusted() in setupAudioController): mitigiert — einfacher Bool-Return, kein blocking call
- T-04-09 (NSWorkspace.shared.open() für Systemeinstellungen): accept — öffnet nur Systemeinstellungen

## Next Phase Readiness

Phase 4 Code-Implementierung vollständig abgeschlossen:
- OUT-01 (AX-Injektion), OUT-02 (Clipboard), OUT-03 (Hotkey) alle implementiert und verdrahtet
- Build grün, volle Test-Suite grün
- Bereit für Phase 5

## Self-Check: PASSED

- FOUND: AppDelegate.swift (TextOutputService.shared.output, AXIsProcessTrusted, toggleOutputMode)
- FOUND: SettingsView.swift (axPermissionDenied, Privacy_Accessibility, Picker, KeyboardShortcuts.Recorder)
- FOUND: 04-03-SUMMARY.md
- FOUND commit: 4a735d1 (Task 1 — AppDelegate-Wiring)
- FOUND commit: 920ef38 (Task 2 — SettingsView-Erweiterung)
- print()-Stub entfernt: bestaetigt
- BUILD SUCCEEDED: bestaetigt
- TEST SUCCEEDED: bestaetigt

---
*Phase: 04-text-output*
*Completed: 2026-04-19*
