---
phase: 1
slug: app-shell
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (Xcode built-in) |
| **Config file** | VoiceScribeTests/ — Wave 0 erstellt |
| **Quick run command** | `swift test` |
| **Full suite command** | `swift test --parallel` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `swift build`
- **After every plan wave:** Run `swift test --parallel`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 1 | SET-06 | — | N/A | build | `swift build` | ❌ W0 | ⬜ pending |
| 1-01-02 | 01 | 1 | FEED-01 | — | N/A | manual | Visuelle Prüfung Icon-Zustände | ❌ W0 | ⬜ pending |
| 1-02-01 | 02 | 1 | SET-02 | — | N/A | unit | `swift test --filter HotkeyTests` | ❌ W0 | ⬜ pending |
| 1-03-01 | 03 | 2 | SET-05 | — | N/A | manual | Visuelle Prüfung Login-Toggle | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `VoiceScribeTests/HotkeyTests.swift` — stubs für SET-02 (KeyboardShortcuts Integration)
- [ ] `VoiceScribeTests/AppStateTests.swift` — stubs für FEED-01 (Icon-Zustände)
- [ ] Xcode-Projekt mit Test-Target konfigurieren

*Visuelle UI-Verhalten (Icon-Animation, Menu, Login-Toggle) erfordern manuelle Verifikation.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Kein Dock-Icon beim Launch | SET-06 | NSApplication Policy nicht automatisch testbar | App starten, Dock beobachten |
| Icon wechselt 4 Zustände bei Hotkey | FEED-01 | UI-Rendering auf echtem Display | ⌥⌘R halten, loslassen, Zustand verfolgen |
| Menu zeigt App-Name + Quit + Settings | SET-06 | AppKit Menu nur via UI-Test | Rechtsklick auf Menu-Bar-Icon |
| Login-Toggle funktioniert | SET-05 | SMAppService-Verhalten systemspezifisch | Toggle aktivieren, neu starten |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
