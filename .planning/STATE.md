---
gsd_state_version: 1.0
milestone: v0.18.0
milestone_name: milestone
status: Ready to plan
stopped_at: Phase 5 UI-SPEC approved (2026-04-19)
last_updated: "2026-04-19T08:30:00.000Z"
last_activity: 2026-04-19
progress:
  total_phases: 6
  completed_phases: 3
  total_plans: 16
  completed_plans: 15
  percent: 94
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-15)

**Core value:** Text per Sprache eingeben, genau wie tippen — schnell, systemweit, ohne Fenster wechseln zu müssen.
**Current focus:** Phase 05 — LLM + Prompt Profiles

## Current Position

Phase: 5
Plan: Not started
Status: Ready to discuss
Last activity: 2026-04-19

Progress: [██████░░░░] 67%

## Performance Metrics

**Velocity:**

- Total plans completed: 7
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 4 | - | - |
| 02 | 3 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 01-app-shell P01 | 25 | 4 tasks | 9 files |
| Phase 01-app-shell P02 | 15 | 3 tasks | 5 files |
| Phase 01-app-shell P03 | 20 | 4 tasks | 4 files |
| Phase 02-audio-capture P01 | 375 | 2 tasks | 8 files |
| Phase 02-audio-capture P02 | 333 | 3 tasks | 9 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Init: WhisperKit recommended over Parakeet Python bridge for v1 (see SUMMARY.md) — project brief says Parakeet; confirm before Phase 3
- Init: No App Sandbox — global hotkeys + AX text injection are incompatible with sandbox; decide in Phase 1, never revisit
- Init: macOS minimum version not yet pinned — stack targets 14+; confirm before writing entitlements
- [Phase 01-app-shell]: pbxproj manuell erstellt (xcodegen nicht vorhanden) — vollständig valide Struktur
- [Phase 01-app-shell]: ad-hoc signing für Phase 1 lokale Entwicklung (kein Apple Developer Team)
- [Phase 01-app-shell]: SWIFT_STRICT_CONCURRENCY = complete aktiviert ab Plan 01-01
- [Phase 01-app-shell]: SwiftUI renderingMode(.original) statt .alwaysOriginal — Image.TemplateRenderingMode kennt kein .alwaysOriginal (NSImage-API); Verhalten äquivalent
- [Phase 01-app-shell]: KeyboardShortcuts+Names.swift aus Plan 03 vorgezogen — HotkeyTests blockierte Test-Target-Build; Plan 03 konsumiert Extension nur noch in AppDelegate
- [Phase 01-app-shell]: Observation-Strategie B (manueller updateIcon-Aufruf) statt withObservationTracking — robuster für Swift 6 strict concurrency
- [Phase 01-app-shell]: Guard statusItem != nil in updateIcon() verhindert Crash wenn onAppear vor applicationDidFinishLaunching feuert (Test-Host-Umgebung)
- [Phase 02-audio-capture]: AudioController als nonisolated @unchecked Sendable — installTap-Callbacks laufen auf Audio-Render-Thread, kein @MainActor moeglich
- [Phase 02-audio-capture]: startRecording() synchron throws — Permission-Request bei .undetermined via Task{} dispatched, Caller nutzt requestPermissionIfNeeded() separat
- [Phase 02-audio-capture]: CFString-Qualifier in AudioObjectGetPropertyData via withUnsafePointer — vermeidet UnsafeRawPointer-Warning
- [Phase 02-audio-capture]: onLevelUpdate-Callback in AudioController statt withObservationTracking — konsistent mit Observation-B-Pattern
- [Phase 02-audio-capture]: AppState.toggleRecording() bricht Demo-Cycle: idle->recording, recording->transcribing; Phase 3 fuellt .transcribing
- [Phase 04-text-output]: TextOutputService @MainActor, AX-Injektion mit Unicode-Scalar-replaceSubrange, 2040-Zeichen-Guard gegen EXC_BAD_ACCESS
- [Phase 04-text-output]: OutputMode.field ist Standard (D-06), persistiert via Defaults.Keys.outputMode; toggleOutputMode-Hotkey ⇧⌘V (D-09)
- [Phase 04-text-output]: AVAudioConverter-Callback muss .endOfStream (nicht .noDataNow) setzen wenn alle Samples übergeben — behebt paramErr -50 / -10877

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 03 RESOLVED] WhisperKit gewählt (D-01 in 03-CONTEXT.md) — Parakeet Python-Subprocess für v1 verworfen.
- [Pre-Phase 1] macOS minimum deployment target not set — affects AVAudioEngine API availability and LaunchAtLogin-modern compatibility.

## Deferred Items

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| v2 | Push-to-Talk hold mode | Deferred | Init |
| v2 | AX → clipboard automatic fallback | Deferred | Init |
| v2 | Language selection for transcription | Deferred | Init |
| v2 | History export (CSV/JSON) | Deferred | Init |
| v2 | Onboarding assistant | Deferred | Init |

## Session Continuity

Last session: 2026-04-19T07:39:17.632Z
Stopped at: context exhaustion at 90% (2026-04-19)
Resume file: None
