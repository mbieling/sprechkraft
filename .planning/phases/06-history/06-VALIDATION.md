---
phase: 6
slug: history
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-20
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (bereits im Projekt etabliert) |
| **Config file** | VoiceScribeTests/ Target in project.pbxproj |
| **Quick run command** | `xcodebuild test -scheme VoiceScribe -destination 'platform=macOS'` |
| **Full suite command** | gleich — alle Tests im selben Target |
| **Estimated runtime** | ~30 Sekunden |

---

## Sampling Rate

- **After every task commit:** Kompilierung + Unit-Tests für HistoryStore
- **After every plan wave:** Vollständige Test-Suite (`xcodebuild test ...`)
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 6-01-01 | 01 | 0 | HIST-01, HIST-02, HIST-03 | — | N/A | unit (RED stubs) | `xcodebuild test -scheme VoiceScribe -destination 'platform=macOS'` | ❌ W0 | ⬜ pending |
| 6-02-01 | 02 | 1 | HIST-01, HIST-02 | — | `try?` silent-fail bei DB-Fehler | unit | `xcodebuild test ...` → `testInsertPersists`, `testBothTextsStored` | ❌ W0 | ⬜ pending |
| 6-03-01 | 03 | 1 | HIST-03 | T6-FTS5 | FTS5Pattern-Binding (kein SQL-Injection) | unit + perf | `xcodebuild test ...` → `testFTS5SearchFindsMatch`, `testSearchPerformance` | ❌ W0 | ⬜ pending |
| 6-04-01 | 04 | 2 | HIST-01, HIST-02 | — | N/A | manual (UI) | History-Fenster öffnen, Diktat durchführen, Eintrag sichtbar | — | ⬜ pending |
| 6-05-01 | 05 | 2 | HIST-04 | — | NSPasteboard | unit + manual | `testCopyPreference` + manueller Klick-Test | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `VoiceScribeTests/HistoryStoreTests.swift` — RED-Stubs für HIST-01, HIST-02, HIST-03 (testInsertPersists, testBothTextsStored, testFTS5SearchFindsMatch, testSearchPerformance)
- [ ] In-Memory-DatabaseQueue für Tests (`DatabaseQueue()` ohne Pfad = In-Memory-DB, kein Filesystem-Zustand)

*Bestehende Test-Infrastruktur deckt Phase-6-Tests nicht ab — Wave 0 muss Stubs anlegen.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| History-Fenster öffnet sich via Menü | HIST-01 | AppDelegate NSMenuItem → NotificationCenter → Window-Scene; kein automatischer Test für Fensteröffnung | 1. App starten 2. Rechtsklick Menüleiste 3. „Verlauf…" klicken 4. History-Fenster öffnet sich |
| Datum-Sektionen korrekt | HIST-01 | SwiftUI-Rendering nicht testbar ohne XCTest-UI | 1. Mehrere Einträge von verschiedenen Tagen anlegen 2. Sektionsüberschriften „HEUTE" / „GESTERN" / Datum prüfen |
| Grün-Blink-Feedback sichtbar | HIST-04 | Animation ist visuell, nicht per Test verifizierbar | 1. Auf Eintrag klicken 2. Zeilenhintergrund blinkt ~0.4s grün |
| Confirm-Dialog beim Leeren | HIST-01 | Alert-UI nicht per Unit-Test verifizierbar | 1. „Verlauf leeren…" klicken 2. Alert erscheint mit „Löschen" / „Abbrechen" |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
