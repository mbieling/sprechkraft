---
phase: 02-audio-capture
plan: 02
subsystem: audio-ui
tags: [swiftui, avfoundation, waveform, canvas, settings, audio-cues, observation-b]
dependency_graph:
  requires: [02-01]
  provides: [WaveformView, SettingsView-Audio, AppDelegate-AudioWiring, AppState-Phase2Toggle]
  affects: [VoiceScribe/StatusBarIconView.swift, VoiceScribe/SettingsView.swift, VoiceScribe/AppDelegate.swift, VoiceScribe/AppState.swift, VoiceScribe/Audio/AudioController.swift, VoiceScribe/VoiceScribeApp.swift]
tech_stack:
  added: [NSSound, AVCaptureDevice-DiscoverySession-UI, SwiftUI-Canvas]
  patterns: [Canvas-Waveform, Observation-B-LevelUpdate, AudioController-Callbacks, Defaults-PropertyWrapper]
key_files:
  created:
    - VoiceScribeTests/WaveformViewTests.swift
  modified:
    - VoiceScribe/StatusBarIconView.swift
    - VoiceScribe/SettingsView.swift
    - VoiceScribe/AppDelegate.swift
    - VoiceScribe/AppState.swift
    - VoiceScribe/Audio/AudioController.swift
    - VoiceScribe/VoiceScribeApp.swift
    - VoiceScribeTests/AppStateTests.swift
    - VoiceScribe.xcodeproj/project.pbxproj
decisions:
  - "WaveformView als eigene struct in StatusBarIconView.swift — saubere Trennung, einfacher testbar"
  - "onLevelUpdate-Callback in AudioController statt withObservationTracking — konsistent mit Observation-B-Pattern aus Plan 01"
  - "AppStateTests aktualisiert: cyclesThroughAllStates entfernt, 5 neue Phase-2-spezifische Tests"
  - "AppState.toggleRecording() bricht Demo-Cycle; Phase 3 fuellt .transcribing mit echter Transkription"
metrics:
  duration_seconds: 333
  completed_date: "2026-04-17"
  tasks_completed: 3
  tasks_total: 3
  files_created: 1
  files_modified: 8
---

# Phase 02 Plan 02: UI + AudioController-Wiring Summary

**One-liner:** Canvas-Waveform im 18x4pt Menu-Bar-Icon, vollstaendige SettingsView (Mikrofon-Picker, Stille-Slider, Permission-Banner) und AppDelegate-Verdrahtung mit echtem AudioController-Toggle via NSSound-Cues (Tink/Pop).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | StatusBarIconView + WaveformView (FEED-03) | 4e5aa5a | StatusBarIconView.swift, WaveformViewTests.swift, project.pbxproj, AppDelegate.swift (Rule-3-Fix) |
| 2 | SettingsView mit Mikrofon-Picker, Stille-Slider, Permission-Banner | c857fba | SettingsView.swift, VoiceScribeApp.swift |
| 3 | AppDelegate-Wiring + Audio-Cues + echtes Toggle | c6adbfd | AppDelegate.swift, AppState.swift, AudioController.swift, VoiceScribeApp.swift, AppStateTests.swift |

## What Was Built

### WaveformView (`VoiceScribe/StatusBarIconView.swift`)
- `struct WaveformView: View` mit `Canvas`-Rendering: sin-Kurve, 8 Segmente, 1pt systemRed-Linie
- Minimalamplitude 1pt (Linie bleibt bei Stille sichtbar), Maximalamplitude 4pt
- `.frame(width: 18, height: 4)` — exakt UI-SPEC-konform
- `.accessibilityHidden(true)` — dekoratives Element
- `struct StatusBarIconView`: VStack-Layout mit `let audioLevel: CGFloat`; mic.fill auf 13pt reduziert
- WaveformView nur bei `state == .recording` sichtbar (UI-SPEC Icon-State Machine)
- Pulse-Animation unveraendert aktiv fuer .recording und .llmProcessing (D-04)

### SettingsView (`VoiceScribe/SettingsView.swift`)
- `Section("Mikrofon")`: AVCaptureDevice-Picker via `@Default(.selectedMicUID)`, pickerStyle(.menu)
- Leerstand-Option "Kein Mikrofon gefunden" wenn `availableMics.isEmpty`
- Roter Permission-Banner (`Color(.systemRed)`) mit mic.slash.fill, Text und "Einstellungen öffnen"-Button
- Button oeffnet `x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone`
- `Section("Stille-Erkennung")`: Slider 0.5–5.0s, step 0.5, `@Default(.silenceDuration)`
- Wertanzeige rechts: `"1.5 s"` (monospacedDigit)
- `.formStyle(.grouped)`, xl-Padding, Copywriting-Contract aus UI-SPEC vollstaendig eingehalten
- Alle Accessibility-Labels: Picker, Slider, Banner gemaess UI-SPEC Accessibility Contract

### AppDelegate Wiring (`VoiceScribe/AppDelegate.swift`)
- `private var audioController: AudioController?`
- `setupAudioController()`: init + `onAutoStop` + `onLevelUpdate` Callbacks
- `startRecordingWithCue()`: idle→recording, `startRecording()`, `NSSound("Tink").play()` (D-05/06)
- `stopRecordingWithCue()`: `stopRecording()`, recording→transcribing→idle, `NSSound("Pop").play()` (D-06/07)
- `handleClick()` und `setupHotkey()` nutzen echte Start/Stopp-Methoden
- `updateIcon()` uebergibt `audioLevel` an `StatusBarIconView` (FEED-03)

### AudioController (`VoiceScribe/Audio/AudioController.swift`)
- `var onLevelUpdate: (() -> Void)?` — Callback nach jedem audioLevel-Update
- Im Tap-Callback: `self?.onLevelUpdate?()` nach `appState?.audioLevel = clampedLevel`

### AppState (`VoiceScribe/AppState.swift`)
- `toggleRecording()`: Demo-Cycle entfernt; .idle→.recording, .recording→.transcribing (audioLevel Reset)
- `resetToIdle()`: setzt recordingState und audioLevel auf Ausgangswerte
- Phase 3 fuellt .transcribing mit echter Transkription

### VoiceScribeApp (`VoiceScribe/VoiceScribeApp.swift`)
- `appDelegate.setupAudioController()` nach AppState-Injection in `HiddenActivationView.onAppear`
- `SettingsView(appState: appState)` — AppState-Injection fuer Permission-Banner

### Tests (25/25 gruen)
- `WaveformViewTests`: 6 Tests — Initialisierung mit verschiedenen Levels, alle Zustaende
- `AppStateTests`: 6 Tests — Phase-2-Zustandsmaschine (toggleFromIdle, toggleFromRecording, resetToIdle, etc.)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] audioLevel-Parameter-Fehler in AppDelegate.updateIcon() nach Task 1**
- **Found during:** Task 1 Build-Verifikation
- **Issue:** `StatusBarIconView(state: state)` ohne `audioLevel`-Parameter — Compile-Fehler nach Erweiterung der Signatur
- **Fix:** `updateIcon()` sofort angepasst: `let level = appState?.audioLevel ?? 0.0` + `StatusBarIconView(state: state, audioLevel: level)`
- **Files modified:** VoiceScribe/AppDelegate.swift
- **Commit:** 4e5aa5a (im Task-1-Commit enthalten)

**2. [Rule 1 - Bug] AppStateTests.cyclesThroughAllStates() nach Demo-Cycle-Entfernung**
- **Found during:** Task 3 Test-Ausfuehrung
- **Issue:** `cyclesThroughAllStates()` testete den 4-Zustands-Demo-Cycle, der in `toggleRecording()` entfernt wurde → Test schlug fehl
- **Fix:** `AppStateTests.swift` vollstaendig aktualisiert auf Phase-2-Zustandsmaschine; 5 neue spezifische Tests statt 1 generischem Cycle-Test
- **Files modified:** VoiceScribeTests/AppStateTests.swift
- **Commit:** c6adbfd (im Task-3-Commit enthalten)

## Threat Surface Scan

Keine neuen Threat-Surfaces ausserhalb des Plans `<threat_model>`. Alle 4 STRIDE-Threats (T-02-06 bis T-02-09) implementiert:
- T-02-06: Guard `recordingState == .idle` in `startRecordingWithCue()` verhindert doppelten Start
- T-02-07: Slider-Range 0.5–5.0 begrenzt `silenceDuration` — kein Sicherheitsrisiko
- T-02-08: Guard `recordingState == .recording` in `stopRecordingWithCue()` + `resetToIdle()` als Safety-Net
- T-02-09: Permission-Banner zeigt nur Boolean-Status; URL oeffnet nur System-Einstellungen

## Known Stubs

- `stopRecordingWithCue()` setzt Zustand sofort auf `.idle` nach `.transcribing` — Phase 3 wird `.transcribing` mit echter Parakeet-Transkription fuellen, bevor `.idle` gesetzt wird
- `AudioController.startRecording()` bei `.undetermined`-Permission: Task{}-Dispatch ohne Rueckmeldung an User — Phase 3 kann Permission-Flow verfeinern

## Self-Check: PASSED

### Created Files Exist
- FOUND: VoiceScribeTests/WaveformViewTests.swift

### Modified Files Exist
- FOUND: VoiceScribe/StatusBarIconView.swift
- FOUND: VoiceScribe/SettingsView.swift
- FOUND: VoiceScribe/AppDelegate.swift
- FOUND: VoiceScribe/AppState.swift
- FOUND: VoiceScribe/Audio/AudioController.swift
- FOUND: VoiceScribe/VoiceScribeApp.swift
- FOUND: VoiceScribeTests/AppStateTests.swift

### Commits Exist
- FOUND: 4e5aa5a — Task 1 (StatusBarIconView, WaveformView, pbxproj, AppDelegate-Fix)
- FOUND: c857fba — Task 2 (SettingsView, VoiceScribeApp)
- FOUND: c6adbfd — Task 3 (AppDelegate, AppState, AudioController, VoiceScribeApp, AppStateTests)

### Test Results
- 25/25 Tests gruen (alle bestehenden Phase-1/2-Tests + 6 neue WaveformView/AppState-Tests)
- Alle Acceptance Criteria: ERFUELLT
