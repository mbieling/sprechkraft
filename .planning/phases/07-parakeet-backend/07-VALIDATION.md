---
phase: 7
slug: parakeet-backend
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-24
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (import Testing) |
| **Config file** | Xcode Project — SPRECHKRAFTTests Target |
| **Quick run command** | `xcodebuild test -scheme SPRECHKRAFT -destination 'platform=macOS' -only-testing:SPRECHKRAFTTests/TranscriptionServiceTests -only-testing:SPRECHKRAFTTests/RecordingStateTests 2>&1 | tail -20` |
| **Full suite command** | `xcodebuild test -scheme SPRECHKRAFT -destination 'platform=macOS' 2>&1 | tail -30` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command (TranscriptionServiceTests + RecordingStateTests)
- **After every plan wave:** Run full suite
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | 0 | RECORD-04 | — | N/A | unit | `xcodebuild test ... -only-testing:SPRECHKRAFTTests/TranscriptionServiceTests` | ✅ (update) | ⬜ pending |
| 07-01-02 | 01 | 0 | RECORD-04 | — | N/A | unit | `xcodebuild test ... -only-testing:SPRECHKRAFTTests/RecordingStateTests` | ✅ (update) | ⬜ pending |
| 07-01-03 | 01 | 0 | — | — | N/A | unit | `xcodebuild test ... -only-testing:SPRECHKRAFTTests/AppStateTests` | ❌ W0 (add test) | ⬜ pending |
| 07-02-01 | 02 | 1 | RECORD-04 | — | N/A | build | `xcodebuild build -scheme SPRECHKRAFT 2>&1 | tail -5` | ❌ W0 | ⬜ pending |
| 07-02-02 | 02 | 1 | — | — | N/A | unit | `xcodebuild test ... -only-testing:SPRECHKRAFTTests/AppStateTests` | ❌ W0 | ⬜ pending |
| 07-02-03 | 02 | 1 | — | — | N/A | build | `xcodebuild build -scheme SPRECHKRAFT 2>&1 | tail -5` | N/A | ⬜ pending |
| 07-03-01 | 03 | 1 | — | — | N/A | build | `xcodebuild build -scheme SPRECHKRAFT 2>&1 | tail -5` | N/A | ⬜ pending |
| 07-04-01 | 04 | 2 | RECORD-04, RECORD-05 | — | Minimum 1600-sample guard | unit | `xcodebuild test ... -only-testing:SPRECHKRAFTTests/TranscriptionServiceTests` | ❌ W0 | ⬜ pending |
| 07-04-02 | 04 | 2 | RECORD-04 | — | N/A | build | `xcodebuild build -scheme SPRECHKRAFT 2>&1 | tail -5` | N/A | ⬜ pending |
| 07-05-01 | 05 | 3 | RECORD-04 | — | N/A | unit | `xcodebuild test ... -only-testing:SPRECHKRAFTTests/TranscriptionServiceTests` | ❌ W0 | ⬜ pending |
| 07-06-01 | 06 | 4 | RECORD-05 | — | N/A | build | `xcodebuild build -scheme SPRECHKRAFT 2>&1 | tail -5` | N/A | ⬜ pending |
| 07-07-* | 07 | 5 | RECORD-04, RECORD-05 | — | N/A | manual | See Manual-Only Verifications | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `SPRECHKRAFTTests/TranscriptionServiceTests.swift` — Anpassen auf neue Facade-API: mock TranscriptionBackend, `transcribe()` → `transcribeWithResampling()` via Facade; REQ RECORD-04
- [ ] `SPRECHKRAFTTests/RecordingStateTests.swift` — `caseCount()` von 4 auf 7 aktualisieren; `.modelLoading`, `.warmingUp`, `.modelError` hinzufügen
- [ ] `SPRECHKRAFTTests/AppStateTests.swift` — Neuer Test: `isModelError` initial false

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Parakeet-Modell wird beim Erststart heruntergeladen mit Spinner-Anzeige | RECORD-05 | CoreML-Download dauert Minuten; benötigt echte Netzwerk-Verbindung und HuggingFace | App kalt starten, Icon auf .modelLoading-Spinner prüfen, Menü-Titel "Parakeet-Modell wird geladen (~1.2 GB)…" verifizieren |
| Warmup-State sichtbar nach Download | RECORD-05 | Benötigt echten Model-Load | Nach Download: .warmingUp-Icon erscheint kurz, dann .idle |
| Diktat → Parakeet-Transkription → TextOutput | RECORD-04 | End-to-End braucht Mikrofon, echtes Audio, laufende App | ⌥⌘R drücken, kurzen Satz sprechen, Text in TextEdit erscheint korrekt |
| isModelReady=true nach erfolgreichem Download | RECORD-05 | Zustandsänderung nur beim echten Download sichtbar | Xcode-Debug-Log: "isModelReady = true" nach Download-Abschluss |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
