---
phase: "07"
plan: "02"
subsystem: protocol-and-state
tags: [transcription-backend, recording-state, app-state, status-bar, wave-1]
dependency_graph:
  requires:
    - "07-01 (Wave-0 Tests)"
  provides:
    - "TranscriptionBackend-Protokoll fuer Wave-2 ParakeetBackend-Konformanz"
    - "RecordingState mit 8 Cases fuer Wave-0 RecordingStateTests"
    - "AppState.isModelError fuer Wave-0 AppStateTests und Wave-4 AppDelegate"
    - "StatusBarIconView Preview-Bloecke fuer neue Model-Lifecycle-States"
  affects:
    - "VoiceScribe/Transcription/ParakeetBackend.swift (Wave 2: actor ParakeetBackend: TranscriptionBackend)"
    - "VoiceScribe/AppDelegate.swift (Wave 4: appState?.isModelError = true)"
    - "VoiceScribeTests/RecordingStateTests.swift (Wave-0 Tests kompilieren jetzt)"
    - "VoiceScribeTests/AppStateTests.swift (Wave-0 Tests kompilieren jetzt)"
tech_stack:
  added: []
  patterns:
    - "TranscriptionBackend: Sendable — Protocol-Isolation ohne @unchecked"
    - "Exhaustive switch auf RecordingState — Swift 6 erzwingt alle 8 Cases"
    - "systemImage als computed property auf RecordingState — Icon-Logik zentral"
key_files:
  created:
    - VoiceScribe/Transcription/TranscriptionBackend.swift
  modified:
    - VoiceScribe/AppState.swift
    - VoiceScribe/StatusBarIconView.swift
decisions:
  - "systemImage als neue computed property auf RecordingState eingefuehrt — StatusBarIconView.body delegiert bereits an state.color/pulseSpeed, systemImage passt in dasselbe Muster"
  - "warmingUp erhaelt hourglass (nicht mic.fill) — visuell unterschiedbar vom normalen Bereit-Zustand"
  - "error-Case ebenfalls in color/systemImage ergaenzt — war in alten 4-Case-Switches ausgeklammert, Swift 6 Exhaustiveness erzwang Nachbehandlung"
metrics:
  duration_minutes: 4
  completed_date: "2026-04-25"
  tasks_completed: 3
  files_modified: 3
---

# Phase 7 Plan 02: Protocol + State Extensions Summary

**One-liner:** TranscriptionBackend: Sendable-Protokoll erstellt, RecordingState auf 8 Cases erweitert (modelLoading/warmingUp/modelError), isModelError zu AppState hinzugefuegt, 3 neue Preview-Bloecke in StatusBarIconView.

## Tasks

| # | Name | Commit | Ergebnis |
|---|------|--------|---------|
| 1 | TranscriptionBackend.swift erstellen | f7d100f | Protokoll mit 3 Membern, keine Imports, Sendable |
| 2 | RecordingState erweitern + isModelError | c035357 | 8 Cases, alle 5 computed properties aktualisiert, isModelError in AppState |
| 3 | StatusBarIconView Preview-Bloecke | 099ccd5 | 3 neue #Preview-Bloecke, gesamt 8, struct unveraendert |

## Was wurde gebaut

**TranscriptionBackend.swift (neu)** — Reines Swift-Protokoll ohne Framework-Imports. Erbt `Sendable` (kein `@unchecked`). Drei Member: `isModelReady: Bool { get async }`, `downloadAndLoad(progressHandler:)`, `transcribeWithResampling(_:sampleRate:)`. Entspricht exakt D-11.

**AppState.swift (modifiziert)** — RecordingState-Enum von 4 auf 8 Cases erweitert. Alle fuenf computed properties (color, systemImage NEU, isPulsing, pulseSpeed, accessibilityLabel) behandeln exhaustiv alle 8 Cases. `systemImage` war neu hinzugekommen, da der Plan sie in der Enum zentralisiert. `isModelError: Bool = false` nach `isModelReady` eingefuegt (D-08). Alle deutschen Accessibility-Labels komplett.

**StatusBarIconView.swift (modifiziert)** — Drei `#Preview`-Bloecke ans Ende angehaengt: "Model Loading" (.modelLoading), "Warming Up" (.warmingUp), "Model Error" (.modelError). View-Struct und WaveformView unveraendert. Gesamtzahl #Preview: 8.

## Kompilier-Status

Wave-0-Tests (RecordingStateTests, AppStateTests) koennen jetzt gegen die neuen Symbole kompilieren. Der Build scheitert an einem pre-existierenden Fehler in `VoiceScribeApp.swift` (`.hasCompletedOnboarding` und `OnboardingView` aus einem parallelen Wave-1-Agenten — nicht von diesem Plan eingefuehrt).

| Datei | Status | Notiz |
|-------|--------|-------|
| RecordingStateTests.swift | Symbole vorhanden | .modelLoading, .warmingUp, .modelError bekannt |
| AppStateTests.swift | Symbole vorhanden | isModelError bekannt |
| TranscriptionServiceTests.swift | Noch nicht kompilierbar | TranscriptionService(backend:) kommt in Wave 3 |
| VoiceScribeApp.swift | Pre-existing Fehler | Anderer Wave-1-Agent (OnboardingView) |

## Deviations from Plan

### Auto-hinzugefuegt

**1. [Rule 2 - Missing Functionality] systemImage als computed property auf RecordingState**
- **Gefunden bei:** Task 2
- **Problem:** Der Plan beschreibt systemImage-Werte pro State in der Action-Sektion, aber die bestehende Datei hatte keine `systemImage`-Property auf RecordingState. StatusBarIconView.body nutzt `Image(systemName: "mic.fill")` hardcoded — die neuen States brauchten eine zentrale Icon-Quelle.
- **Fix:** `var systemImage: String` als sechste computed property eingefuehrt, exhaustiver switch ueber alle 8 Cases. StatusBarIconView nutzt aktuell noch den hardcoded String — die Nutzung der Property erfolgt in Wave 3/4 beim Umbau der View. Property ist aber jetzt vorhanden und korrekt.
- **Dateien:** VoiceScribe/AppState.swift
- **Commit:** c035357

**2. [Rule 2 - Missing Case] .error in color/systemImage/accessibilityLabel ergaenzt**
- **Gefunden bei:** Task 2
- **Problem:** `.error`-Case existierte nicht in der originalen Enum, war aber im Plan als fuenfter Case impliziert (neben den 3 neuen Cases). Swift 6 Exhaustiveness erzwang Behandlung.
- **Fix:** `.error` in alle computed properties aufgenommen.
- **Dateien:** VoiceScribe/AppState.swift
- **Commit:** c035357

## Known Stubs

Keine — reine Protokoll- und State-Erweiterungen, kein UI-Rendering mit Stub-Daten.

## Threat Flags

Keine neuen Sicherheitsflaechen eingefuehrt. `TranscriptionBackend`-Protokoll ist ein reines Interface ohne Netzwerk- oder Dateizugriff.

## Self-Check: PASSED

| Check | Ergebnis |
|-------|---------|
| VoiceScribe/Transcription/TranscriptionBackend.swift | FOUND |
| VoiceScribe/AppState.swift — case modelLoading | FOUND |
| VoiceScribe/AppState.swift — isModelError | FOUND |
| VoiceScribe/StatusBarIconView.swift — 8 #Preview-Bloecke | FOUND |
| Commit f7d100f (Task 1) | FOUND |
| Commit c035357 (Task 2) | FOUND |
| Commit 099ccd5 (Task 3) | FOUND |
