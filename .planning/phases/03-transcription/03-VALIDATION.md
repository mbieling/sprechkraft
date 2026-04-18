---
phase: 3
slug: transcription
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing / XCTest (native Xcode) |
| **Config file** | VoiceScribeTests/VoiceScribeTests.swift |
| **Quick run command** | `xcodebuild test -scheme VoiceScribe -destination 'platform=macOS' -only-testing VoiceScribeTests` |
| **Full suite command** | `xcodebuild test -scheme VoiceScribe -destination 'platform=macOS'` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command
- **After every plan wave:** Run full suite command
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 3-SPM | TBD | 0 | RECORD-04 | — | N/A | build | `xcodebuild build -scheme VoiceScribe` | ✅ | ⬜ pending |
| 3-resampling | TBD | 1 | RECORD-04 | — | N/A | unit | `xcodebuild test -only-testing VoiceScribeTests/TranscriptionServiceTests` | ❌ W0 | ⬜ pending |
| 3-download | TBD | 1 | RECORD-05 | — | N/A | manual | See Manual-Only Verifications | — | ⬜ pending |
| 3-transcribe | TBD | 2 | RECORD-04 | — | N/A | integration | `xcodebuild test -only-testing VoiceScribeTests/TranscriptionServiceTests` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `VoiceScribeTests/TranscriptionServiceTests.swift` — stubs for RECORD-04 (TranscriptionService unit tests)
- [ ] Resampling test: AVAudioConverter 44.1kHz → 16kHz output validates length and silence

*Existing infrastructure covers build and basic app-launch tests.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Modell-Download Fortschrittsanzeige im NSStatusItem | RECORD-05 | Erfordert Netzwerk + erste-Start-Zustand, nicht unit-testbar | App starten (Modell-Ordner vorher löschen), "↓ XX%" im Menüleisten-Icon beobachten |
| Transkription korrekter deutscher Text nach 30s Audio | RECORD-04 | Erfordert echtes Mikrofon + WhisperKit-Modell | Aufnahme starten, 30s sprechen, Konsolen-Output prüfen |
| Aufnahme blockiert während Download | RECORD-05 | UI-Verhalten, nicht automatisierbar | Hotkey während laufendem Download drücken — kein State-Wechsel |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
