---
phase: "06-history"
plan: "02"
subsystem: "History / GRDB-Datenbankschicht"
tags: ["grdb", "fts5", "tdd", "wave-1", "database", "migration"]
dependency_graph:
  requires: ["06-01 (GRDB SPM-Dependency, HistoryStore Wave-0-Stub)"]
  provides: ["HistoryEntry GRDB-Record", "HistoryStore DatabaseQueue", "FTS5-Volltextsuche", "Migration v1"]
  affects:
    - "SPRECHKRAFT/History/HistoryEntry.swift"
    - "SPRECHKRAFT/History/HistoryStore.swift"
    - "SPRECHKRAFT.xcodeproj/project.pbxproj"
tech_stack:
  added: []
  patterns:
    - "GRDB FetchableRecord + PersistableRecord mit CodingKeys snake_case Mapping"
    - "FTS5 synchronize(withTable:) fuer automatische Trigger-Synchronisation"
    - "FTS5Pattern(matchingAllTokensIn:) als sicheres Binding (T6-FTS5-Mitigation)"
    - "AsyncThrowingStream ueber ValueObservation via Task-Wrapper"
key_files:
  created:
    - "SPRECHKRAFT/History/HistoryEntry.swift"
    - "SPRECHKRAFT/History/HistoryStore.swift"
  modified:
    - "SPRECHKRAFT.xcodeproj/project.pbxproj"
  deleted:
    - "SPRECHKRAFT/Models/HistoryStore.swift (Wave-0-Stub ersetzt)"
decisions:
  - "observeAll() gibt AsyncThrowingStream via Task-Wrapper zurueck statt AsyncValueObservation — Konsistenz mit bestehenden Swift-Concurrency-Patterns im Projekt"
  - "HistoryEntry und HistoryStore in separates History/-Verzeichnis statt Models/ — klarere Modul-Abgrenzung fuer Wave 2 (HistoryView)"
  - "Wave-0-Stub SPRECHKRAFT/Models/HistoryStore.swift geloescht — pbxproj-Referenz auf History/HistoryStore.swift umgeleitet"
metrics:
  duration_minutes: 6
  tasks_completed: 2
  files_changed: 3
  completed_date: "2026-04-21"
---

# Phase 6 Plan 2: HistoryEntry + HistoryStore GRDB-Datenbankschicht Summary

**One-liner:** GRDB-Datenbankschicht vollstaendig implementiert — HistoryEntry als Sendable FetchableRecord, HistoryStore mit Migration v1, FTS5-Virtual-Table (synchronize), unicode61-Tokenizer und FTS5Pattern-Binding (T6-FTS5); alle 5 RED-Tests gruen.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | HistoryEntry.swift — GRDB Datenmodell | e8f65a9 | SPRECHKRAFT/History/HistoryEntry.swift, SPRECHKRAFT.xcodeproj/project.pbxproj, (loescht SPRECHKRAFT/Models/HistoryStore.swift) |
| 2 | HistoryStore.swift — Datenbankschicht | c6aa444 | SPRECHKRAFT/History/HistoryStore.swift |

## Erstellte Dateien

### SPRECHKRAFT/History/HistoryEntry.swift (56 Zeilen)

- `struct HistoryEntry: Codable, Identifiable, Sendable`
- `FetchableRecord, PersistableRecord` mit `databaseTableName = "transcription_entries"`
- `CodingKeys`: `id`, `created_at`, `original_text`, `llm_text`, `profile_name`, `is_llm_processed`
- `copyText`: `llmText ?? originalText` (D-09)
- `preview`: `prefix(80) + "…"` wenn Text laenger als 80 Zeichen (D-03)

### SPRECHKRAFT/History/HistoryStore.swift (152 Zeilen)

- `@MainActor final class HistoryStore`
- `static let shared` Produktions-Singleton (Application Support)
- `init(inMemory: Bool) throws` fuer Tests (In-Memory-DatabaseQueue)
- Migration `v1_transcription_entries`: Haupt-Tabelle + FTS5-Virtual-Table
- `t.synchronize(withTable: "transcription_entries")` — automatische Trigger (D-14)
- `t.tokenizer = .unicode61()` — Unicode-Support fuer deutsche Umlaute
- `insert`, `delete`, `deleteAll` via `dbQueue.write`
- `search(query:)`: leerer Query → alle Eintraege DESC; FTS5Pattern-Binding (T6-FTS5)
- `observeAll()`: `AsyncThrowingStream<[HistoryEntry], Error>` via ValueObservation-Task-Wrapper

## pbxproj-Aenderungen

### Neue Object-IDs

| ID | Typ | Beschreibung |
|----|-----|-------------|
| HT060610 | PBXFileReference | HistoryEntry.swift |
| HT060611 | PBXBuildFile | HistoryEntry.swift in Sources (App-Target) |
| HT060620 | PBXGroup | History/-Verzeichnis-Gruppe |

### Modifizierte Strukturen

- `PP050302 /* Models */`: HT060602 (HistoryStore.swift) entfernt
- `HT060620 /* History */`: HT060610 (HistoryEntry.swift) + HT060602 (HistoryStore.swift) hinzugefuegt
- `AA000040 /* SPRECHKRAFT */`: HT060620-Gruppe hinzugefuegt
- `AA000070 /* Sources */`: HT060611 (HistoryEntry.swift in Sources) hinzugefuegt

## Test-Ergebnisse

**5/5 HistoryStoreTests GREEN:**

| Test | Anforderung | Status |
|------|------------|--------|
| testInsertPersists | HIST-01 | BESTEHT |
| testBothTextsStored | HIST-02 | BESTEHT |
| testFTS5SearchFindsMatch | HIST-03 | BESTEHT |
| testSearchPerformance | HIST-03 | BESTEHT |
| testCopyPreference | HIST-04 | BESTEHT |

**Bekannter pre-existierender Fehler (ausserhalb Scope):**
- `AudioControllerTests/testSilenceDetection_triggersAfterDuration()` — war bereits vor Phase 6 fehlgeschlagen; nicht durch diese Aenderungen verursacht.

## T6-FTS5-Mitigation bestaetigt

```swift
guard let pattern = FTS5Pattern(matchingAllTokensIn: query) else {
    return []  // Sicherer Fallback: kein Absturz bei ungueltigem FTS5-Token
}
return try HistoryEntry.fetchAll(db, sql: "... WHERE transcription_entries_fts MATCH ?", arguments: [pattern])
```

- User-Input wird **niemals** via String-Interpolation in MATCH-Clause eingebaut
- `nil`-Rueckgabe bei ungueltigem Pattern → leere Ergebnisliste (kein Crash)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] observeAll()-Rueckgabetyp inkompatibel**
- **Found during:** Task 2 (erster Build-Versuch)
- **Issue:** `ValueObservation.values(in:)` liefert `AsyncValueObservation<[HistoryEntry]>`, nicht `AsyncThrowingStream<[HistoryEntry], Error>` — Compiler-Fehler
- **Fix:** Task-Wrapper implementiert: `AsyncThrowingStream { continuation in ... }` mit `for try await` ueber `observation.values(in: dbQueue)` und `continuation.onTermination` fuer sauberes Cancellation-Handling
- **Files modified:** SPRECHKRAFT/History/HistoryStore.swift
- **Commit:** c6aa444

## Known Stubs

Keine. Alle implementierten Methoden sind voll funktional und durch Tests verifiziert.

## Threat Flags

Keine neuen Threat-Surfaces — alle relevanten Boundaries waren im Plan-Threat-Model erfasst (T6-FTS5, T6-DELETE).

## Self-Check: PASSED

- FOUND: SPRECHKRAFT/History/HistoryEntry.swift
- FOUND: SPRECHKRAFT/History/HistoryStore.swift
- FOUND: .planning/phases/06-history/06-02-SUMMARY.md
- FOUND: commit e8f65a9 (feat(06-02): HistoryEntry.swift)
- FOUND: commit c6aa444 (feat(06-02): HistoryStore.swift)
- VERIFIED: 5/5 HistoryStoreTests GREEN
- VERIFIED: T6-FTS5-Mitigation (FTS5Pattern-Binding) vorhanden
- VERIFIED: synchronize(withTable:) vorhanden
