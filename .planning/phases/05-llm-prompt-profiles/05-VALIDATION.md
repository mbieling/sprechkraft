---
phase: 5
slug: llm-prompt-profiles
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-19
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (bereits in Phases 1-4 verwendet) |
| **Config file** | Xcode Test Target `VoiceScribeTests` |
| **Quick run command** | `xcodebuild test -scheme VoiceScribe -destination 'platform=macOS' -only-testing:VoiceScribeTests/PromptProfileTests -only-testing:VoiceScribeTests/GroqServiceTests` |
| **Full suite command** | `xcodebuild test -scheme VoiceScribe -destination 'platform=macOS'` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run Quick run command above
- **After every plan wave:** Run full suite
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 5-??-01 | Data Model | 0 | PROF-01, PROF-03, PROF-04 | T-5-01 | API-Key nie in Struct/Defaults | unit | `...PromptProfileTests` | ❌ Wave 0 | ⬜ pending |
| 5-??-02 | GroqService | 0 | PROF-05, SET-01 | T-5-02 | API-Key nur aus Keychain | unit | `...GroqServiceTests` | ❌ Wave 0 | ⬜ pending |
| 5-??-03 | Hotkey-Namen | 1 | PROF-02 | — | N/A | unit | `...HotkeyTests` (bestehend erweitern) | ✅ erweitern | ⬜ pending |
| 5-??-04 | AppDelegate Routing | 2 | PROF-03, PROF-04, PROF-05 | T-5-03 | Fallback zu Raw-Text bei Fehler | unit | `...PromptProfileTests` | ❌ Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

*Task-IDs werden durch den Planner konkretisiert.*

---

## Wave 0 Requirements

- [ ] `VoiceScribeTests/PromptProfileTests.swift` — PROF-01 (CRUD), PROF-03 (LLM-Toggle-Routing), PROF-04 (isDefault-Invariante, genau 1 Default), Defaults-Codable-Round-Trip
- [ ] `VoiceScribeTests/GroqServiceTests.swift` — PROF-05 (Mock URLSession für Groq-Response), SET-01 (Keychain store/retrieve), D-10 (stille Fallback bei Fehler)

*Hinweis: `VoiceScribeTests/HotkeyTests.swift` existiert bereits (Phase 1) — nur erweitern um dynamische UUID-basierte Namen.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Simultaner Profil-Hotkey + ⌥⌘R während Aufnahme | PROF-02 | Erfordert echte Tastatur-Events; kein Simulator | Profil anlegen, Hotkey setzen, ⌥⌘R + Profil-Hotkey gleichzeitig halten, sprechen, loslassen — korrektes Profil muss aktiv sein |
| Icon-Farbe (lila pulsierend) während `.llmProcessing` | FEED-01 | Visueller State, kein API | LLM-fähiges Profil aktivieren, Aufnahme starten, nach Transkription Icon beobachten |
| SettingsView Profil-Sheet-Modal Flow | PROF-01 | UI-Interaktion (SwiftUI `.sheet()`) | Profil anlegen, Hotkey setzen, LLM-Toggle, speichern, erneut öffnen — alle Werte müssen persistiert sein |
| Echter Groq API-Call mit echtem Key | PROF-05 | Netzwerk-Abhängigkeit | API-Key in Settings eingeben, LLM-Profil diktieren — Groq-Ergebnis muss im aktiven Textfeld erscheinen |
| API-Key Banner in SettingsView | SET-01 | UI-State-Check | Ohne API-Key: roter Banner sichtbar. Nach Key-Eingabe: Banner verschwindet |

---

## Security Threat Model Coverage

| Threat | STRIDE | Mitigation | Test |
|--------|--------|------------|------|
| T-5-01: API-Key in UserDefaults/Logs | Information Disclosure | KeychainAccess — nie in Defaults oder NSLog | unit: Keychain round-trip, greift kein UserDefaults |
| T-5-02: API-Key im Memory sichtbar | Information Disclosure | Key nur kurz vor Request aus Keychain lesen; nicht in AppState cachen | Code review |
| T-5-03: Netzwerk-Interception des API-Keys | Spoofing | HTTPS (URLSession default) — kein HTTP-Fallback | unit: URL-Schema-Check in GroqServiceTests |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
