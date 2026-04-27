---
phase: "06-history"
plan: "04"
subsystem: "History / AppDelegate-Wiring"
tags: ["appdelegate", "swiftui", "grdb", "notification", "window-scene", "wave-3"]
dependency_graph:
  requires:
    - phase: "06-03"
      provides: "HistoryView SwiftUI-View (vollständig implementiert)"
    - phase: "06-02"
      provides: "HistoryStore.shared.insert() API"
  provides:
    - "NSMenuItem 'Verlauf…' im Rechtsklick-Menü (D-02)"
    - "Notification.Name .openHistory als AppDelegate→SwiftUI-Brücke"
    - "Window-Scene 'history' (640×480 / min 480×320) in SPRECHKRAFTApp"
    - "GRDB-Insert in onRecordingComplete (LLM-Pfad + Direkt-Pfad) — D-15"
    - "Vollständige Pipeline: Diktat → TranscriptionService → TextOutputService → HistoryStore → HistoryView"
  affects:
    - "06-05 (Human-Verify Wave 4)"
tech-stack:
  added: []
  patterns:
    - "NotificationCenter-Brücke AppDelegate → SwiftUI Window-Scene (identisches Muster für settings + history)"
    - "try? HistoryStore.shared.insert() nach TextOutputService.output() — Insert-Fehler blockiert nie Transkription"
    - "if let activeProfile (non-optional) vs. activeProfile? (optional outer scope) — sorgfältig unterscheiden"

key-files:
  created: []
  modified:
    - "SPRECHKRAFT/AppDelegate.swift"
    - "SPRECHKRAFT/SPRECHKRAFTApp.swift"

key-decisions:
  - "activeProfile.name (non-optional) im LLM-Pfad innerhalb if let activeProfile Binding — activeProfile?.name wäre Compiler-Fehler"
  - "try? für HistoryStore.insert() — Insert-Fehler darf Transkription nicht unterbrechen (RESEARCH.md Open Questions #2)"
  - "llmText = outputText != text ? outputText : nil — nil wenn Groq-Fallback zum Original zurückfiel"

patterns-established:
  - "Window-Öffnung via NotificationCenter: AppDelegate postet, HiddenActivationView empfängt, .regular Policy → openWindow → .accessory (300ms Workaround)"

requirements-completed:
  - HIST-01
  - HIST-02
  - HIST-04

duration: 8min
completed: "2026-04-21"
---

# Phase 6 Plan 4: AppDelegate + SPRECHKRAFTApp Wiring Summary

**Vollständige History-Pipeline verdrahtet: NSMenuItem 'Verlauf…' → NotificationCenter → Window-Scene 'history' + GRDB-Insert nach jedem Diktat in beiden onRecordingComplete-Pfaden (LLM + Direkt).**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-21T03:34:00Z
- **Completed:** 2026-04-21T03:42:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- AppDelegate.swift: 4 Änderungen — Notification.Name .openHistory, NSMenuItem "Verlauf…" vor "Einstellungen…", @objc openHistoryMenu(), GRDB-Insert in beiden onRecordingComplete-Pfaden
- SPRECHKRAFTApp.swift: 2 Änderungen — Window-Scene "history" (640×480, min 480×320) + onReceive(.openHistory) mit Activation-Policy-Workaround
- Alle 5 HistoryStoreTests grün nach Wiring (keine Regression)

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | AppDelegate — openHistory + GRDB-Insert | d011b1b | SPRECHKRAFT/AppDelegate.swift |
| 2 | SPRECHKRAFTApp — Window-Scene history + onReceive | 312eb3d | SPRECHKRAFT/SPRECHKRAFTApp.swift |

## Files Created/Modified

- `SPRECHKRAFT/AppDelegate.swift` — Notification.Name .openHistory, NSMenuItem "Verlauf…", @objc openHistoryMenu(), HistoryStore.shared.insert() in LLM- und Direkt-Pfad
- `SPRECHKRAFT/SPRECHKRAFTApp.swift` — Window("SPRECHKRAFT — Verlauf", id: "history") + onReceive(.openHistory) Handler

## Entscheidungen

- **activeProfile.name vs. activeProfile?.name:** Im LLM-Pfad ist `activeProfile` durch `if let activeProfile` non-optional gebunden — `?.` wäre ein Swift-6-Compiler-Fehler. Im Direkt-Pfad (`else`-Zweig) referenziert `activeProfile` die äußere optionale Variable — dort bleibt `?.` korrekt.
- **llmText Nulling-Logik:** `outputText != text ? outputText : nil` — wenn Groq fehlschlug und zum Original-Text zurückgefallen ist, wird kein redundanter llmText gespeichert. Klar und minimal.
- **try? für HistoryStore.insert():** Insert-Fehler (z.B. Disk voll) sollen nie die Transkriptionsausgabe blockieren. Konsistent mit RESEARCH.md Open Questions #2.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] activeProfile?.name → activeProfile.name im LLM-Pfad**
- **Found during:** Task 1 (erster Build nach GRDB-Insert-Einbau)
- **Issue:** `activeProfile?.name` im inneren `Task {}` Block (Zeile 156) — aber `activeProfile` war durch `if let activeProfile` bereits auf non-optional gebunden; Swift 6 Compiler: "cannot use optional chaining on non-optional value of type 'PromptProfile'"
- **Fix:** `activeProfile?.name` → `activeProfile.name`
- **Files modified:** SPRECHKRAFT/AppDelegate.swift
- **Verification:** BUILD SUCCEEDED nach Fix
- **Committed in:** d011b1b (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Minimal — Swift-6-Typkorrektheit. Kein Scope-Creep.

## Issues Encountered

- Pre-existierender Fehler `AudioControllerTests/testSilenceDetection_triggersAfterDuration()` schlägt weiterhin fehl — war bereits vor Phase 6 fehlgeschlagen (dokumentiert in 06-02-SUMMARY.md); nicht durch diese Änderungen verursacht.

## Known Stubs

Keine. Die vollständige Pipeline ist aktiv:
- Diktat → TranscriptionService → TextOutputService → HistoryStore.shared.insert() → HistoryView (via ValueObservation)
- NSMenuItem "Verlauf…" → NotificationCenter.openHistory → Window-Scene "history" → HistoryView

## Threat Flags

Keine neuen Threat-Surfaces. T6-FTS5 (FTS5Pattern-Binding in HistoryStore.search) und T6-DELETE (Confirm-Alert in HistoryView) wurden in vorherigen Plans mitigiert.

## Requirements-Status

| Requirement | Status |
|-------------|--------|
| HIST-01 (Insert mit Zeitstempel) | Erfüllt — HistoryStore.insert() mit createdAt: Date() |
| HIST-02 (original + LLM Text) | Erfüllt — originalText + llmText (nullable) korrekt befüllt |
| HIST-03 (FTS5-Suche) | Erfüllt — HistoryStore.search() + HistoryView Suchfeld (Wave 1+2) |
| HIST-04 (Clipboard-Kopieren) | Erfüllt — HistoryView.copyEntry() via NSPasteboard (Wave 2) |

## Next Phase Readiness

Bereit für Wave 4 (06-05: Human-Verify). Die Pipeline ist vollständig verdrahtet:
1. Rechtsklick → "Verlauf…" → History-Fenster öffnet sich korrekt
2. Nach Diktat erscheint neuer Eintrag automatisch in HistoryView (via ValueObservation)
3. LLM-verarbeiteter Text und Original werden korrekt in DB gespeichert

---

## Self-Check: PASSED

- FOUND: SPRECHKRAFT/AppDelegate.swift (modifiziert)
- FOUND: SPRECHKRAFT/SPRECHKRAFTApp.swift (modifiziert)
- FOUND: commit d011b1b (feat(06-04): AppDelegate)
- FOUND: commit 312eb3d (feat(06-04): SPRECHKRAFTApp)
- VERIFIED: grep "openHistory" AppDelegate.swift | wc -l = 4 (>= 3 erwartet)
- VERIFIED: grep "HistoryStore.shared.insert" AppDelegate.swift | wc -l = 2
- VERIFIED: grep '"SPRECHKRAFT — Verlauf"' SPRECHKRAFTApp.swift = vorhanden
- VERIFIED: 5/5 HistoryStoreTests grün
- VERIFIED: BUILD SUCCEEDED

*Phase: 06-history*
*Completed: 2026-04-21*
