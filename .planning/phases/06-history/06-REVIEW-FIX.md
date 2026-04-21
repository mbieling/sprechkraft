---
phase: 06-history
fixed_at: 2026-04-21T17:44:15Z
review_path: .planning/phases/06-history/06-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 6: Code Review Fix Report

**Fixed at:** 2026-04-21T17:44:15Z
**Source review:** .planning/phases/06-history/06-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6
- Fixed: 6
- Skipped: 0

## Fixed Issues

### CR-01: `try!` in HistoryStore singleton crashes on DB init failure

**Files modified:** `VoiceScribe/History/HistoryStore.swift`
**Commit:** 6d97339
**Applied fix:** `try!` durch ein `do/catch`-Konstrukt in der lazy-Closure ersetzt. Bei Fehler wird ein In-Memory-`HistoryStore` als Fallback erstellt und der Fehler via `print` in Console.app geloggt. Falls auch In-Memory fehlschlägt, ist das ein Programmierfehler und ein Crash korrekt.

---

### WR-01: Synchronous DatabaseQueue calls block the main thread

**Files modified:** `VoiceScribe/History/HistoryStore.swift`, `VoiceScribe/AppDelegate.swift`, `VoiceScribe/History/HistoryView.swift`, `VoiceScribeTests/HistoryStoreTests.swift`
**Commit:** e9532a3
**Applied fix:** `insert`, `delete`, `deleteAll` und `search` auf `async throws` umgestellt; alle verwenden jetzt `try await dbQueue.write`/`read`. Call-Sites in AppDelegate und HistoryView angepasst (Kontextmenü- und Alert-Buttons erhalten `Task { try? await ... }`-Wrapper, Debounce-Task verwendet `try? await`). Alle Testmethoden auf `async throws` umgestellt.

Hinweis: Der LLM-Pfad in AppDelegate wurde refaktoriert — `historyEntry` wird jetzt vor `await MainActor.run` konstruiert und danach außerhalb des MainActor-Blocks async inserted. Der Direkt-Pfad verwendet einen eigenen `Task { }` für den async Insert.

---

### WR-02: Silent swallowing of DB insert errors with no diagnostics

**Files modified:** `VoiceScribe/AppDelegate.swift`
**Commit:** e9532a3 (gemeinsam mit WR-01 gefixt)
**Applied fix:** Beide Insert-Stellen (LLM-Pfad und Direkt-Pfad) verwenden jetzt `do/catch` mit `print("[HistoryStore] Insert failed: \(error)")`. Die Fire-and-Forget-Semantik bleibt erhalten — Fehler blockieren die Transkriptionsausgabe nicht, sind aber in Console.app sichtbar.

---

### WR-03: Strong `self` capture in inner fire-and-forget Task (LLM path)

**Files modified:** `VoiceScribe/AppDelegate.swift`
**Commit:** 1cf9028
**Applied fix:** Innerer LLM-Task auf `Task { [weak self] in guard let self else { return }` umgestellt. Konsistent mit dem äußeren `onRecordingComplete`-Callback der bereits `[weak self]` verwendet.

---

### WR-04: `DateFormatter` allocated on every SwiftUI render pass

**Files modified:** `VoiceScribe/History/HistoryView.swift`
**Commit:** 65c6cea
**Applied fix:** Zwei `private let`-Formatter auf Datei-Scope hinzugefügt: `historyDateFormatter` (dd.MM.yyyy) und `historyTimeFormatter` (HH:mm). Alle drei Allokierungsstellen ersetzt: `groupedEntries`-Closure, `accessibilityLabel(for:)` und `HistoryRowView.timeString`.

---

### WR-05: Missing test coverage for `delete()` and `deleteAll()`

**Files modified:** `VoiceScribeTests/HistoryStoreTests.swift`
**Commit:** dabe6ef
**Applied fix:** Zwei neue `async throws`-Tests hinzugefügt: `testDeleteRemovesEntry()` prüft Einzel-Löschen und verifiziert explizit den FTS5-Index (sucht nach dem gelöschten Term — erwartet leere Ergebnisse); `testDeleteAllClearsStore()` prüft Gesamt-Löschen mit 5 Einträgen.

---

_Fixed: 2026-04-21T17:44:15Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
