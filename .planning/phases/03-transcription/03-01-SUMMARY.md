---
phase: 03-transcription
plan: "01"
subsystem: transcription
tags: [whisperkit, spm, tdd, red-phase, xcode, pbxproj]
dependency_graph:
  requires: []
  provides:
    - WhisperKit SPM-Dependency im Xcode-Build
    - TranscriptionService actor (Stub, RED-Phase)
    - TranscriptionServiceTests (5 RED-Tests, RECORD-04/05)
  affects:
    - SPRECHKRAFT.xcodeproj/project.pbxproj
    - SPRECHKRAFTTests/TranscriptionServiceTests.swift
    - SPRECHKRAFT/Transcription/TranscriptionService.swift
tech_stack:
  added:
    - WhisperKit (argmaxinc/argmax-oss-swift v0.18.0+, SPM)
  patterns:
    - Swift actor fuer TranscriptionService (Concurrent-Safety)
    - TDD RED-Phase mit kompilierendem Stub statt fehlender Typdeklaration
key_files:
  created:
    - SPRECHKRAFTTests/TranscriptionServiceTests.swift
    - SPRECHKRAFT/Transcription/TranscriptionService.swift
  modified:
    - SPRECHKRAFT.xcodeproj/project.pbxproj
decisions:
  - "WhisperKit ueber argmaxinc/argmax-oss-swift (umgezogenes Repo) eingetragen, nicht argmaxinc/WhisperKit"
  - "TranscriptionService als minimaler Stub erstellt damit Test-Build kompiliert; Wave 1 implementiert echte Logik"
  - "testResamplingProducesCorrectLength schlaegt erwartungsgemaess fehl (RED) — Stub gibt Input unveraendert zurueck"
metrics:
  duration: "~6 min"
  completed: "2026-04-18"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 1
---

# Phase 03 Plan 01: WhisperKit Build-Fundament und RED-Test-Stubs — Summary

**One-liner:** WhisperKit v0.18.0 als SPM-Dependency eingetragen (argmax-oss-swift), TranscriptionService-Stub als Swift actor erstellt, 5 RED-Tests fuer RECORD-04/05 in TranscriptionServiceTests.swift — Build gruen, testResamplingProducesCorrectLength schlaegt erwartungsgemaess fehl.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | WhisperKit SPM-Dependency im Xcode-Projekt | ee5ed56 | SPRECHKRAFT.xcodeproj/project.pbxproj |
| 2 | TranscriptionServiceTests RED-Stubs | 56428d0 | SPRECHKRAFTTests/TranscriptionServiceTests.swift, SPRECHKRAFT/Transcription/TranscriptionService.swift, project.pbxproj |

## Verification Results

- `xcodebuild -resolvePackageDependencies`: WhisperKit (whisperkit @ 0.18.0) aufgeloest — EXIT 0
- `xcodebuild build -scheme SPRECHKRAFT`: BUILD SUCCEEDED
- `xcodebuild test -only-testing SPRECHKRAFTTests/AudioControllerTests`: alle 4 Tests gruen
- TranscriptionServiceTests: 4/5 Tests gruen (korrekt fuer RED), 1 Test (testResamplingProducesCorrectLength) schlaegt fehl (Resampling-Stub gibt Input unveraendert zurueck — erwartet Wave 1)

## Deviations from Plan

### Auto-added: TranscriptionService-Stub (Rule 2 — Missing critical functionality)

**Found during:** Task 2 (RED-Test-Stubs)

**Issue:** Der Plan sagt explizit "Keinen Dummy-TranscriptionService-Typ erstellen" und gleichzeitig "Bestehende Tests laufen weiterhin gruen". Beides ist nicht gleichzeitig erfuellbar wenn `TranscriptionServiceTests.swift` im selben Test-Target liegt: Ohne `TranscriptionService`-Deklaration kompiliert das gesamte Test-Target nicht, und auch AudioControllerTests schlagen fehl.

**Fix:** Minimaler `actor TranscriptionService`-Stub in `SPRECHKRAFT/Transcription/TranscriptionService.swift` erstellt. Der Stub:
- Kompiliert ohne Fehler (loest Compilation-Conflict auf)
- Gibt `isModelReady = false` zurueck (korrekt fuer RECORD-05)
- Gibt `nil` aus `transcribe()` zurueck (korrekt fuer "not ready"-Tests)
- Gibt Input unveraendert aus `resampleTo16kHz()` zurueck (loest testResamplingProducesCorrectLength zum Scheitern — korrekte RED-Phase)

**Intent des Plans bleibt gewahrt:** Der Stub hat keine echte WhisperKit-Implementierung. Wave 1 (03-02) ersetzt den Stub vollstaendig.

**Files modified:** SPRECHKRAFT/Transcription/TranscriptionService.swift (neu), SPRECHKRAFT.xcodeproj/project.pbxproj

**Commit:** 56428d0

## TDD Gate Compliance

| Gate | Status | Commit |
|------|--------|--------|
| RED (test) | Partiell — `testResamplingProducesCorrectLength` schlaegt fehl wie erwartet | 56428d0 |
| GREEN (feat) | Ausstehend — Wave 1 (03-02) | — |
| REFACTOR | Ausstehend | — |

Der `test(...)`-Commit deckt die RED-Phase ab. Der `feat(...)`-Commit in Wave 1 schliesst GREEN ab.

## Known Stubs

| Stub | File | Reason |
|------|------|--------|
| `resampleTo16kHz` gibt Input unveraendert zurueck | SPRECHKRAFT/Transcription/TranscriptionService.swift | Wave 1 implementiert AVAudioConverter-Resampling |
| `transcribe` gibt immer nil zurueck | SPRECHKRAFT/Transcription/TranscriptionService.swift | Wave 1 implementiert WhisperKit-Transkription |
| `downloadAndLoad` ist leer | SPRECHKRAFT/Transcription/TranscriptionService.swift | Wave 1 implementiert WhisperKit.download() + Initialisierung |

## Threat Surface Scan

Keine neuen Netzwerk-Endpunkte, Auth-Pfade oder Datei-Zugriffsmuster eingefuehrt. WhisperKit SPM-URL explizit auf verifizierten Wert `argmaxinc/argmax-oss-swift` gesetzt (T-03-01 mitigiert). Kein neuer Trust-Boundary-Crossing.

## Self-Check: PASSED

- [x] SPRECHKRAFTTests/TranscriptionServiceTests.swift: FOUND
- [x] SPRECHKRAFT/Transcription/TranscriptionService.swift: FOUND
- [x] Commit ee5ed56: FOUND (feat(03-01): WhisperKit SPM-Dependency)
- [x] Commit 56428d0: FOUND (test(03-01): TranscriptionServiceTests RED-Stubs)
- [x] pbxproj enthaelt `argmaxinc/argmax-oss-swift`: 4 Treffer
- [x] pbxproj enthaelt `WhisperKit`: 5 Treffer
- [x] TranscriptionServiceTests.swift enthaelt 5 @Test-Methoden
- [x] Keine Imports von XCTest in TranscriptionServiceTests.swift
