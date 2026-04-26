---
phase: quick-260426-a1b
plan: "01"
subsystem: transcription
tags: [bug-fix, audio, fluidaudio, nan-sanitization]
dependency_graph:
  requires: []
  provides: [sanitized-audio-samples]
  affects: [TranscriptionService, ParakeetBackend]
tech_stack:
  added: []
  patterns: [isFinite-guard, silence-substitution]
key_files:
  created: []
  modified:
    - VoiceScribe/Transcription/TranscriptionService.swift
decisions:
  - "Replace NaN/Inf with 0.0 (silence) rather than dropping samples or aborting transcription — preserves the rest of the audio"
metrics:
  duration: "3 minutes"
  completed_date: "2026-04-26"
---

# Quick 260426-a1b: Sanitize NaN Samples before FluidAudio Summary

**One-liner:** isFinite guard in transcribeWithResampling() replaces AVAudioEngine render-overload NaN/Inf with 0.0 silence before FluidAudio receives samples.

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | Sanitize non-finite samples after resampling | 9f1e14d | VoiceScribe/Transcription/TranscriptionService.swift |

## What Was Done

Added a single `map` call in `TranscriptionService.transcribeWithResampling(_:sampleRate:)` between the `resampleTo16kHz` call and the backend dispatch:

```swift
let sanitized = samples16k.map { $0.isFinite ? $0 : 0.0 }
return await backend.transcribeWithResampling(sanitized, sampleRate: 16000.0)
```

Root cause: AVAudioEngine occasionally drops render cycles under load (`IOWorkLoop: skipping cycle due to overload`). The resulting NaN values propagate through AVAudioConverter resampling unchanged. FluidAudio's `AsrManager.transcribe()` then throws `invalidAudioData`, crashing the transcription pipeline. Replacing non-finite values with 0.0 silences those samples while preserving the rest of the audio for transcription.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, file access, or schema changes introduced.

## Self-Check: PASSED

- File exists: VoiceScribe/Transcription/TranscriptionService.swift — FOUND
- Commit 9f1e14d — FOUND
- `isFinite` on line 58 — VERIFIED
- `sanitized` passed to backend on line 59 — VERIFIED
- `samples16k` no longer passed directly to backend — VERIFIED
