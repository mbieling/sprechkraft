---
phase: 4
slug: text-output
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Swift Package Manager) |
| **Config file** | VoiceScribeTests/ (existing) |
| **Quick run command** | `xcodebuild test -scheme VoiceScribe -only-testing VoiceScribeTests -destination 'platform=macOS'` |
| **Full suite command** | `xcodebuild test -scheme VoiceScribe -destination 'platform=macOS'` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme VoiceScribe -only-testing VoiceScribeTests -destination 'platform=macOS'`
- **After every plan wave:** Run `xcodebuild test -scheme VoiceScribe -destination 'platform=macOS'`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 4-01-01 | 01 | 1 | OUT-01 | — | AX write only when permitted | unit | `xcodebuild test -scheme VoiceScribe -only-testing TextOutputServiceTests -destination 'platform=macOS'` | ❌ W0 | ⬜ pending |
| 4-01-02 | 01 | 1 | OUT-02 | — | Clipboard write uses NSPasteboard | unit | `xcodebuild test -scheme VoiceScribe -only-testing TextOutputServiceTests/testClipboardOutput -destination 'platform=macOS'` | ❌ W0 | ⬜ pending |
| 4-01-03 | 01 | 1 | OUT-01 | — | 2040-char guard triggers clipboard | unit | `xcodebuild test -scheme VoiceScribe -only-testing TextOutputServiceTests/testLongTextFallback -destination 'platform=macOS'` | ❌ W0 | ⬜ pending |
| 4-02-01 | 02 | 1 | OUT-03 | — | Mode persists via Defaults | unit | `xcodebuild test -scheme VoiceScribe -only-testing OutputModeTests -destination 'platform=macOS'` | ❌ W0 | ⬜ pending |
| 4-03-01 | 03 | 2 | OUT-01 | — | AX injection into TextEdit | manual | — | N/A | ⬜ pending |
| 4-03-02 | 03 | 2 | OUT-01 | — | AX injection into Notes | manual | — | N/A | ⬜ pending |
| 4-03-03 | 03 | 2 | OUT-01 | — | AX injection into Safari | manual | — | N/A | ⬜ pending |
| 4-04-01 | 04 | 2 | OUT-01 | — | Permission check on launch | unit | `xcodebuild test -scheme VoiceScribe -only-testing AppStateTests/testAXPermission -destination 'platform=macOS'` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `VoiceScribeTests/TextOutputServiceTests.swift` — stubs for OUT-01, OUT-02 (protocol-based mock, no real AX)
- [ ] `VoiceScribeTests/OutputModeTests.swift` — stubs for OUT-03 (Defaults round-trip)
- [ ] `VoiceScribeTests/AppStateTests.swift` — AX permission flag test

*Existing XCTest infrastructure covers test runner; Wave 0 adds new test files only.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| AX injection at cursor in TextEdit | OUT-01 | Requires real AX permission + running app | Open TextEdit, place cursor mid-word, trigger dictation, verify text inserted at cursor |
| AX injection in Notes.app | OUT-01 | Requires real AX permission + running app | Same as above in Notes |
| AX injection in Safari address bar | OUT-01 | Requires real AX permission + running app | Focus Safari URL bar, trigger dictation, verify URL bar updated |
| Hotkey ⇧⌘V switches mode visibly | OUT-03 | Requires running app + menu inspection | Press ⇧⌘V, open menu, verify checkmark moved |
| Clipboard fallback when permission denied | OUT-01 | Requires disabling AX permission in System Settings | Revoke permission, trigger dictation, verify text on clipboard |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
