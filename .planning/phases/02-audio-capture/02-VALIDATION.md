---
phase: 2
slug: audio-capture
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-17
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (import Testing) |
| **Config file** | SPRECHKRAFTTests/ (Wave 0 legt Struktur an) |
| **Quick run command** | `xcodebuild test -scheme SPRECHKRAFT -destination 'platform=macOS' -testPlan AudioCaptureQuick 2>&1 \| grep -E "PASS\|FAIL\|error:"` |
| **Full suite command** | `xcodebuild test -scheme SPRECHKRAFT -destination 'platform=macOS' 2>&1 \| grep -E "PASS\|FAIL\|error:"` |
| **Estimated runtime** | ~8 seconds (unit tests only; AVAudioEngine-Integration manuell) |

---

## Sampling Rate

- **After every task commit:** Run Quick-Run (unit tests AudioController-Logik)
- **After every plan wave:** Run Full suite
- **Before `/gsd-verify-work`:** Full suite muss gruen sein + manuelle Verifikationen abgehakt
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 0 | — | — | Info.plist enthaelt NSMicrophoneUsageDescription | manual | `grep -r "NSMicrophoneUsageDescription" SPRECHKRAFT/Info.plist` | W0 | pending |
| 02-01-02 | 01 | 1 | RECORD-01 | T-02-01 | AudioController startet/stoppt AVAudioEngine | unit | `xcodebuild test -scheme SPRECHKRAFT -only-testing:SPRECHKRAFTTests/AudioControllerTests/testStartStop` | W0 | pending |
| 02-02-01 | 01 | 1 | RECORD-02 | — | RMS-Berechnung: stille Buffer -> ~0.0, lauter Buffer -> > 0.1 | unit | `xcodebuild test -scheme SPRECHKRAFT -only-testing:SPRECHKRAFTTests/AudioControllerTests/testRMSCalculation` | W0 | pending |
| 02-02-02 | 01 | 1 | RECORD-02 | — | Silence-Timer loest Auto-Stopp nach konfigurierter Dauer aus | unit | `xcodebuild test -scheme SPRECHKRAFT -only-testing:SPRECHKRAFTTests/AudioControllerTests/testSilenceDetection` | W0 | pending |
| 02-03-01 | 02 | 1 | FEED-02 | — | NSSound-Cue wird bei Start und Stopp abgespielt | manual | Manuell verifizieren: Ton bei Hotkey-Start/Stopp hoerbar | — | pending |
| 02-04-01 | 02 | 1 | FEED-03 | — | Waveform-View existiert und rendert bei audioLevel > 0 | unit | `xcodebuild test -scheme SPRECHKRAFT -only-testing:SPRECHKRAFTTests/WaveformViewTests/testRendersWhenActive` | W0 | pending |
| 02-05-01 | 01 | 1 | SET-03 | — | silenceDuration-Defaults-Key hat Standardwert 1.5 | unit | `xcodebuild test -scheme SPRECHKRAFT -only-testing:SPRECHKRAFTTests/DefaultsKeysTests/testSilenceDurationDefault` | W0 | pending |
| 02-05-02 | 01 | 1 | SET-04 | — | selectedMicUID-Defaults-Key hat Standardwert nil | unit | `xcodebuild test -scheme SPRECHKRAFT -only-testing:SPRECHKRAFTTests/DefaultsKeysTests/testSelectedMicUIDDefault` | W0 | pending |
| 02-06-01 | 03 | 1 | RECORD-03 | — | Geraetesliste enthaelt mindestens Built-in-Mikrofon | manual | Manuell: Mikrofon-Dropdown in Settings zeigt Geraete | — | pending |
| 02-07-01 | 03 | 1 | — | T-02-02 | Mikrofon-Permission-Banner erscheint in Settings wenn denied | manual | Berechtigung in macOS entziehen, App starten, Settings oeffnen | — | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] `SPRECHKRAFTTests/AudioControllerTests.swift` — Stubs fuer RECORD-01, RECORD-02 (testStartStop, testRMSCalculation, testSilenceDetection)
- [ ] `SPRECHKRAFTTests/WaveformViewTests.swift` — Stub fuer FEED-03 (testRendersWhenActive)
- [ ] `SPRECHKRAFTTests/DefaultsKeysTests.swift` — Tests fuer SET-03, SET-04 (testSilenceDurationDefault, testSelectedMicUIDDefault)
- [ ] Swift Testing Target in Xcode-Projekt eingerichtet (falls nicht bereits aus Phase 1 vorhanden)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Audio-Cue bei Start hoerbar | FEED-02 | AVAudioEngine + NSSound brauchen reale Hardware; kein AVAudioEngine-Mock im CI | Hotkey druecken, Ton "Tink" hoeren |
| Audio-Cue bei Stopp hoerbar | FEED-02 | Wie oben | Hotkey loslassen/druecken, Ton "Pop" hoeren |
| Waveform-Animation im Icon sichtbar | FEED-03 | SwiftUI-Rendering nicht testbar ohne Display-Server | In Mikrofon sprechen, Linie im Icon beobachten |
| Mikrofon-Dropdown zeigt verfuegbare Geraete | RECORD-03 | AVCaptureDevice.DiscoverySession braucht echte Hardware | Settings oeffnen, Dropdown pruefen |
| Geraetewechsel wirkt ab naechster Aufnahme | RECORD-03 | Hardwareabhaengig | Anderes Geraet waehlen, neue Aufnahme starten |
| Permission-Banner erscheint wenn denied | D-13 | Systemzustand schwer zu mocken | Berechtigung in macOS Datenschutz entziehen, Settings oeffnen |
| Silence Auto-Stopp stoppt Aufnahme | RECORD-02 | Timing-Verhalten braucht echtes Mikrofon | In Mikrofon sprechen, aufhoeren, warten |

---

## Validation Sign-Off

- [ ] Alle Tasks haben `<automated>` verify oder Wave-0-Dependencies
- [ ] Sampling-Kontinuitaet: keine 3 aufeinanderfolgenden Tasks ohne automated verify
- [ ] Wave 0 deckt alle MISSING-Referenzen ab
- [ ] Keine watch-mode Flags
- [ ] Feedback-Latenz < 15s
- [ ] `nyquist_compliant: true` in Frontmatter gesetzt

**Approval:** pending
