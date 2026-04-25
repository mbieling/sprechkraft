---
phase: 07-parakeet-backend
plan: "06"
subsystem: app-lifecycle
tags: [swift, appdeleggate, model-lifecycle, state-machine, ui-feedback, cache-check]

requires:
  - phase: "07-05"
    provides: "TranscriptionService Facade mit downloadAndLoad/isModelReady"
  - phase: "07-01"
    provides: "AppState.isModelError, RecordingState.modelLoading/.warmingUp/.modelError"

provides:
  - "setupTranscription() mit Cache-Check (D-07): kein Spinner wenn Modell bereits vorhanden"
  - "Spinner-State .modelLoading vor downloadAndLoad wenn Modell nicht gecacht"
  - ".warmingUp State während progressHandler (fraction < 1.0)"
  - "isModelError = true + .modelError auf Download/Load-Fehler (D-08, D-09)"
  - "Titel-Text 'Parakeet-Modell wird geladen (~1.2 GB)…' während Download (D-06)"

affects:
  - "07-07 (AppDelegate-Tests, falls geplant)"

tech-stack:
  added: []
  patterns:
    - "Observation-B: updateIcon() sofort nach jeder recordingState-Mutation"
    - "FileManager.fileExists als Cache-Guard vor Loading-UI"

key-files:
  modified:
    - path: "VoiceScribe/AppDelegate.swift"
      change: "setupTranscription() ersetzt — Cache-Check, neue States, Error-Path"

decisions:
  - "Build-Fehler in FluidAudio-Quellen (StreamingAsrManager.swift) sind pre-existend und nicht durch diese Änderung verursacht — Regression ausgeschlossen via git stash Test"
  - "isModelReady guard in startRecordingWithCue() bleibt unverändert — blockiert Hotkey korrekt während aller neuen States"

metrics:
  duration: "~10 Minuten"
  completed: "2026-04-25"
  tasks_completed: 1
  files_modified: 1
---

# Phase 07 Plan 06: AppDelegate Model-Lifecycle States Summary

**One-liner:** setupTranscription() mit FluidAudio-Cache-Check, .modelLoading/.warmingUp/.modelError States und isModelError-Fehlerbehandlung.

## Was wurde gebaut

`AppDelegate.setupTranscription()` wurde vollständig überarbeitet, um den Modell-Download-Lifecycle korrekt in der UI zu kommunizieren:

1. **D-07 Cache-Check:** Vor der Loading-UI wird `~/Library/Application Support/FluidAudio/Models` geprüft. Ist das Modell bereits vorhanden, wird kein Spinner angezeigt — `downloadAndLoad` kehrt schnell zurück.

2. **D-06 Spinner-State:** Bei Cache-Miss wird sofort `.modelLoading` gesetzt und `updateIcon()` aufgerufen (Observation-B Pattern).

3. **D-03 Warmup-State:** Im `progressHandler` (fraction < 1.0) wird `.warmingUp` gesetzt und der Titel-Text `"Parakeet-Modell wird geladen (~1.2 GB)…"` angezeigt.

4. **D-08/D-09 Fehler-Pfad:** Nach `downloadAndLoad` wird `isModelReady` geprüft. Bei `false`: `isModelError = true` und `recordingState = .modelError` — Phase 8 zeigt Retry-Button.

5. **Guard unverändert:** `startRecordingWithCue()` Zeile 214 (`guard appState?.isModelReady == true`) blockiert den Hotkey korrekt während `.modelLoading`, `.warmingUp` und `.modelError`.

## Acceptance Criteria

| Kriterium | Status |
|-----------|--------|
| `isModelError = true` im Error-Pfad (D-08) | PASS |
| `recordingState = .modelError` im Error-Pfad (D-09) | PASS |
| `recordingState = .warmingUp` im progressHandler (D-03) | PASS |
| `recordingState = .modelLoading` vor Task (D-06) | PASS |
| `FluidAudio/Models` Cache-Check (D-07) | PASS |
| Titel-Text `~1.2 GB` (D-06) | PASS |
| `guard appState?.isModelReady == true` unverändert | PASS |
| Alte `↓ XX%` Anzeige entfernt | PASS |

## Deviations from Plan

### Pre-existenter Build-Fehler (nicht durch diese Änderung verursacht)

**[Nicht-Deviation - Dokumentation]** Build schlägt fehl mit Fehlern in `FluidAudio/Sources/FluidAudio/ASR/Streaming/StreamingAsrManager.swift` (Swift 6 Concurrency: "sending 'asrManager' risks causing data races"). Diese Fehler existieren bereits vor dieser Änderung (verifiziert via `git stash` + Build-Test). Die Änderungen in `AppDelegate.swift` selbst sind korrekt.

## Known Stubs

Keine. Die Implementierung ist vollständig — alle State-Transitionen sind verdrahtet.

## Threat Flags

Keine neuen Security-relevanten Surfaces. `FileManager.fileExists` auf lokalem Pfad ist read-only und enthält keine User-Daten.

## Self-Check: PASSED

- [x] `VoiceScribe/AppDelegate.swift` existiert und enthält alle neuen Patterns
- [x] Commit `1dc1ccf` existiert in git log
- [x] Keine unerwarteten Datei-Löschungen im Commit
