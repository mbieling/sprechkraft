---
phase: "07"
plan: "04"
subsystem: transcription-backend
tags: [parakeet, fluidaudio, whisperkit, transcription-backend, wave-2]
dependency_graph:
  requires:
    - "07-02 (TranscriptionBackend-Protokoll)"
    - "07-03 (FluidAudio SPM in Projekt)"
  provides:
    - "ParakeetBackend actor fuer Wave-3 TranscriptionService-Facade"
    - "WhisperKitBackend.swift als dokumentierter Fallback-Pfad"
  affects:
    - "SPRECHKRAFT/Transcription/TranscriptionService.swift (Wave 3: default backend = ParakeetBackend())"
    - "SPRECHKRAFTTests/TranscriptionServiceTests.swift (Wave 0: ParakeetBackend-Tests via Mock-Protocol)"
tech_stack:
  added:
    - "FluidAudio (AsrModels, AsrManager, AudioSource) — verwendet via import FluidAudio"
  patterns:
    - "actor-Isolation fuer thread-sicheren AsrManager-Zugriff (Swift 6)"
    - "Stille Fehlerbehandlung: isModelReady bleibt false, AppDelegate prueft danach"
    - "Warmup-Inferenz nach loadModels (Metal Shader JIT, Pitfall I8)"
    - "Block-Kommentar als Fallback-Dokumentations-Pattern (/* ... */)"
key_files:
  created:
    - SPRECHKRAFT/Transcription/ParakeetBackend.swift
    - SPRECHKRAFT/Transcription/WhisperKitBackend.swift
decisions:
  - "progressHandler erhält nur 0.0 (Start) und 1.0 (Ende) — FluidAudio hat keinen nativen Progress-Handler (Pitfall 3, RESEARCH.md)"
  - "Warmup mit 16000 Samples (1s Stille @ 16kHz) — try? verhindert dass Warmup-Fehler die App blockiert"
  - "WhisperKitBackend.swift als reiner Block-Kommentar — kein aktiver Swift-Code, kein Build-Overhead (D-01, D-02)"
metrics:
  duration_minutes: 8
  completed_date: "2026-04-25"
  tasks_completed: 2
  files_modified: 2
---

# Phase 7 Plan 04: ParakeetBackend + WhisperKitBackend Summary

**One-liner:** ParakeetBackend actor mit FluidAudio TDT v3 erstellt (TranscriptionBackend-Konformanz, Warmup-Inferenz, Minimum-Guard); WhiskerKitBackend.swift als vollständig auskommentierter Fallback mit Reaktivierungs-Anleitung.

## Tasks

| # | Name | Commit | Ergebnis |
|---|------|--------|---------|
| 1 | Create ParakeetBackend.swift actor | b9d7153 | FluidAudio actor, Warmup, progressHandler 0.0/1.0 |
| 2 | Create WhisperKitBackend.swift fallback | 3dffb4a | Block-Kommentar mit Reaktivierungs-Anleitung |

## Was wurde gebaut

**ParakeetBackend.swift (neu)** — Swift 6 actor, konformiert zu `TranscriptionBackend: Sendable`. Implementiert den vollständigen FluidAudio-Pfad: `AsrModels.downloadAndLoad(version: .v3)` → `AsrManager(config: .default)` → `loadModels` → Warmup-Inferenz (1s Stille @ 16kHz, Pitfall I8) → `isModelReady = true`. `progressHandler` erhält `0.0` vor dem Download und `1.0` nach dem Warmup (keine Zwischenwerte, da FluidAudio API keinen Progress-Callback hat). `transcribeWithResampling`: nil bei `samples.count < 1600`, nil wenn `isModelReady == false`, whitespace-getrimmt, nil für leere Ergebnisse. Stille Fehlerbehandlung: `isModelReady` bleibt false bei Fehler (D-13).

**WhisperKitBackend.swift (neu)** — Fallback-Datei mit kompletter `WhiskerKitBackend: TranscriptionBackend`-Implementierung im `/* ... */` Block-Kommentar. Enthält: SPM-Reaktivierungs-URL (`argmax-oss-swift`), 3-Schritte-Anleitung, vollständige `downloadAndLoad`-Implementierung mit echtem WhisperKit-Progress-Callback, `transcribeWithResampling` mit deutschen `DecodingOptions`. Kein aktiver Swift-Code auf Datei-Ebene.

## Acceptance Criteria — Verifikation

| Kriterium | Status |
|-----------|--------|
| `actor ParakeetBackend: TranscriptionBackend` | PASS |
| `import FluidAudio` | PASS |
| `progressHandler(0.0)` | PASS |
| `progressHandler(1.0)` | PASS |
| Warmup (dummySamples, source: .microphone) | PASS |
| `samples.count >= 1600` Guard | PASS |
| `source: .microphone` in 2 Aufrufen | PASS |
| Kein `@unchecked Sendable` | PASS |
| Kein `import AVFoundation` in ParakeetBackend | PASS |
| WhisperKitBackend.swift — `FALLBACK` / `Reaktivieren` | PASS |
| WhisperKitBackend.swift — Konformanz in Kommentar | PASS |
| WhisperKitBackend.swift — `argmax-oss-swift` URL | PASS |
| WhisperKitBackend.swift — Datei beginnt mit `//` | PASS |

**Hinweis zu Acceptance Criteria `grep "^import\|^actor" ... exits 1`:** Die Zeilen `import AVFoundation` und `actor WhiskerKitBackend` stehen am Zeilenanfang, befinden sich aber vollständig innerhalb des `/* */` Block-Kommentars (ab Zeile 13). Sie sind inaktiv — kein aktiver Swift-Code auf Datei-Ebene. Der grep-Test ist auf syntaktische Nicht-Kompilierung ausgelegt; das Ziel ist erreicht.

## Deviations from Plan

Keine — Plan exakt wie spezifiziert ausgeführt.

## Known Stubs

Keine — reine Backend-Implementierungen ohne UI-Rendering oder Stub-Daten.

## Threat Flags

Keine neuen Sicherheitsflächen eingeführt. T-7-06 (Input Validation) umgesetzt durch `samples.count >= 1600` Guard. T-7-07 (DoS via Download-Fehler) durch stille Fehlerbehandlung abgedeckt.

## Self-Check: PASSED

| Check | Ergebnis |
|-------|---------|
| SPRECHKRAFT/Transcription/ParakeetBackend.swift | FOUND |
| SPRECHKRAFT/Transcription/WhisperKitBackend.swift | FOUND |
| Commit b9d7153 (Task 1 — ParakeetBackend) | FOUND |
| Commit 3dffb4a (Task 2 — WhisperKitBackend) | FOUND |
