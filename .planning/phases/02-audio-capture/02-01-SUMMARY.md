---
phase: 02-audio-capture
plan: 01
subsystem: audio
tags: [avfoundation, core-audio, swift6-concurrency, silence-detection, unit-tests]
dependency_graph:
  requires: [01-app-shell]
  provides: [AudioController, AudioDeviceManager, Defaults+Keys-Phase2, AppState-audioLevel]
  affects: [AppState.swift, SPRECHKRAFT.xcodeproj/project.pbxproj]
tech_stack:
  added: [AVFoundation, CoreAudio]
  patterns: [nonisolated-@unchecked-Sendable, Task-@MainActor-Bridge, Observation-B, Lazy-Device-Switch]
key_files:
  created:
    - SPRECHKRAFT/Audio/AudioController.swift
    - SPRECHKRAFT/Audio/AudioDeviceManager.swift
    - SPRECHKRAFT/Extensions/Defaults+Keys.swift
    - SPRECHKRAFTTests/AudioControllerTests.swift
    - SPRECHKRAFTTests/DefaultsKeysTests.swift
  modified:
    - SPRECHKRAFT/AppState.swift
    - SPRECHKRAFT/Info.plist
    - SPRECHKRAFT.xcodeproj/project.pbxproj
decisions:
  - "AudioController als nonisolated @unchecked Sendable — installTap-Callbacks laufen auf Audio-Render-Thread, kein @MainActor moeglich"
  - "startRecording() ist synchron throws (nicht async) — Permission-Request bei .undetermined wird via Task{} dispatched, naechster Aufruf erhaelt .granted"
  - "CFString-Qualifier in AudioObjectGetPropertyData via withUnsafePointer — vermeidet UnsafeRawPointer-Warning"
  - "AudioControllerTests als async — MainActor.run fuer AppState-Erstellung benoetigt async-Kontext"
metrics:
  duration_seconds: 375
  completed_date: "2026-04-17"
  tasks_completed: 2
  tasks_total: 2
  files_created: 5
  files_modified: 3
---

# Phase 02 Plan 01: Audio-Subsystem Core Summary

**One-liner:** AVAudioEngine-Wrapper (AudioController) mit RMS-Berechnung, Silence-Detection und Core-Audio-Bridge (AudioDeviceManager) fuer konfigurierbare Mikrofonauswahl — vollstaendig testbar ohne echtes Mikrofon.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Config + Model-Foundation | 4eb8537 | Defaults+Keys.swift, Info.plist, AppState.swift, pbxproj |
| 2 | AudioController + AudioDeviceManager + Unit-Tests | f8fffc0 | AudioController.swift, AudioDeviceManager.swift, AudioControllerTests.swift, DefaultsKeysTests.swift, pbxproj |

## What Was Built

### AudioController (`SPRECHKRAFT/Audio/AudioController.swift`)
- `final class AudioController: @unchecked Sendable` — bewusst NICHT @MainActor
- `startRecording() throws`: Permission-Check (D-14, T-02-01) → Geraet setzen (lazy) → removeTap (Pitfall 5) → Format abfragen → installTap → engine.start()
- `stopRecording()`: removeTap ZUERST (Pitfall 5) → engine.stop() → Akkumulator-Reset
- `calculateRMS(buffer:) -> Float`: Naive Summe der Quadrate, kein Accelerate (1024 Frames ausreichend)
- `updateSilenceDetection(rms:bufferDuration:)`: Akkumulator-basiert, Auto-Stopp via `Task { @MainActor in onAutoStop?() }`
- `onAutoStop: (() -> Void)?`: Callback fuer AppDelegate (wird in Plan 02 verdrahtet)
- RMS clampen auf 0.0-1.0 via `min(1.0, rms * 4.0)` (T-02-03)

### AudioDeviceManager (`SPRECHKRAFT/Audio/AudioDeviceManager.swift`)
- `enum AudioDeviceManager` (stateless Namespace, kein Lifecycle)
- `availableMicrophones() -> [AVCaptureDevice]`: AVCaptureDevice.DiscoverySession (RECORD-03)
- `uniqueIDToAudioObjectID(_ uid:) -> AudioObjectID?`: Core-Audio-Bridge via kAudioHardwarePropertyTranslateUIDToDevice
- `setInputDevice(uid:engine:) throws`: Graceful return bei unbekannter UID (T-02-02)

### Defaults+Keys (`SPRECHKRAFT/Extensions/Defaults+Keys.swift`)
- `silenceDuration: Key<Double>` — Default 1.5s (D-09, SET-03)
- `selectedMicUID: Key<String?>` — Default nil = System-Standard (SET-04)

### AppState-Erweiterung
- `var audioLevel: CGFloat = 0.0` — normierter RMS, fuer FEED-03 Waveform
- `var micPermissionDenied: Bool = false` — fuer D-13 Permission-Banner in SettingsView

### Info.plist
- `NSMicrophoneUsageDescription` hinzugefuegt (Pitfall 6 — ohne diesen Key kein Permission-Dialog)

### Tests (18/18 gruen)
- `AudioControllerTests`: RMS stiller Buffer (~0.0), lauter Buffer (>0.1), Silence-Trigger nach 1.5s, Silence-Reset bei Sprache
- `DefaultsKeysTests`: silenceDuration Default 1.5, selectedMicUID Default nil

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] RMS-Tests als async markiert**
- **Found during:** Task 2 Test-Ausfuehrung
- **Issue:** `testRMSCalculation_silentBuffer()` und `testRMSCalculation_loudBuffer()` riefen `await MainActor.run` auf, waren aber als `throws` (nicht `async throws`) deklariert — Swift-6-Compile-Fehler
- **Fix:** Beide Testfunktionen als `async throws` deklariert
- **Files modified:** SPRECHKRAFTTests/AudioControllerTests.swift
- **Commit:** f8fffc0

**2. [Rule 2 - Missing Critical] CFString-Pointer-Warning in AudioDeviceManager behoben**
- **Found during:** Task 2 Build
- **Issue:** `&cfUID` als `UnsafeRawPointer` erzeugte Swift-Warning "forming UnsafeRawPointer to CFString may contain object reference"
- **Fix:** `withUnsafePointer(to: cfUID)` statt `&cfUID` — idiomatischer Swift fuer Core-Audio-Bridge
- **Files modified:** SPRECHKRAFT/Audio/AudioDeviceManager.swift
- **Commit:** f8fffc0

**3. [Rule 2 - Missing Critical] startRecording() async-Handling fuer .undetermined**
- **Found during:** Task 2 Implementierung
- **Issue:** Plan spezifizierte `func startRecording() throws` (synchron), aber `AVAudioApplication.requestRecordPermission()` ist async — kein direktes `await` moeglich in throws-Kontext
- **Fix:** Bei `.undetermined`: `Task { _ = await AVAudioApplication.requestRecordPermission() }` dispatch; Caller ruft `requestPermissionIfNeeded()` separat auf bevor startRecording. Verhalten: erster Aufruf fordert Permission an und returned; zweiter Aufruf (nach Dialog) startet Aufnahme.
- **Files modified:** SPRECHKRAFT/Audio/AudioController.swift
- **Commit:** f8fffc0

## Threat Surface Scan

Keine neuen Threat-Surfaces ausserhalb des Plans `<threat_model>`. Alle 5 STRIDE-Threats (T-02-01 bis T-02-05) wurden gemaess Threat Register implementiert:
- T-02-01: Permission-Check vor engine.start() (micPermissionDenied-Flag)
- T-02-02: Guard gegen nil in uniqueIDToAudioObjectID
- T-02-03: RMS clampen via min(1.0, rms * 4.0)
- T-02-04: removeTap vor neuem installTap (Pitfall 5)
- T-02-05: NSMicrophoneUsageDescription mit erklaerenden Text

## Known Stubs

- `onAutoStop` Callback in AudioController ist deklariert aber noch nicht verdrahtet — wird in Plan 02 (UI + Wiring) in AppDelegate/SPRECHKRAFTApp gesetzt.
- `AudioController` wird noch nicht in der App instantiiert — Plan 02 wired AppDelegate.

## Self-Check: PASSED

### Created Files Exist
- FOUND: SPRECHKRAFT/Audio/AudioController.swift
- FOUND: SPRECHKRAFT/Audio/AudioDeviceManager.swift
- FOUND: SPRECHKRAFT/Extensions/Defaults+Keys.swift
- FOUND: SPRECHKRAFTTests/AudioControllerTests.swift
- FOUND: SPRECHKRAFTTests/DefaultsKeysTests.swift

### Commits Exist
- FOUND: 4eb8537 — Task 1 (Defaults+Keys, Info.plist, AppState)
- FOUND: f8fffc0 — Task 2 (AudioController, AudioDeviceManager, Tests)

### Test Results
- 18/18 Tests gruen (alle bestehenden Phase-1-Tests + 4 neue Tests)
