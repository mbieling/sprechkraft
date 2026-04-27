---
phase: 06-history
reviewed: 2026-04-21T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - SPRECHKRAFT/AppDelegate.swift
  - SPRECHKRAFT/History/HistoryEntry.swift
  - SPRECHKRAFT/History/HistoryStore.swift
  - SPRECHKRAFT/History/HistoryView.swift
  - SPRECHKRAFT/SPRECHKRAFTApp.swift
  - SPRECHKRAFTTests/HistoryStoreTests.swift
findings:
  critical: 1
  warning: 5
  info: 5
  total: 11
status: issues_found
---

# Phase 6: Code Review Report

**Reviewed:** 2026-04-21
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Phase 6 introduces GRDB/FTS5-backed transcription history with a `HistoryStore` singleton,
`HistoryEntry` model, `HistoryView` SwiftUI list with live search, and AppDelegate wiring for
inserts. The core design decisions are sound: FTS5Pattern binding prevents injection, the
schema migration uses GRDB idioms correctly, and Swift 6 `@MainActor` isolation is consistently
applied. Five issues require attention before shipping: one critical startup crash risk from
`try!`, three warnings around main-thread blocking DB calls, silent insert error swallowing,
an unretained strong-capture in a nested fire-and-forget Task, and missing delete test coverage.
`DateFormatter` allocation in a hot render path is the most visible performance concern.

---

## Critical Issues

### CR-01: `try!` in HistoryStore singleton crashes on DB init failure

**File:** `SPRECHKRAFT/History/HistoryStore.swift:17`

**Issue:** `HistoryStore.shared` is initialized with `try!`. If `FileManager` cannot create the
Application Support directory (sandboxing denial, disk full, permission error) or `DatabaseQueue`
fails (corrupt file, filesystem error), the app crashes with an unhandled exception at startup.
This is a production crash vector: users with unusual sandbox configurations or full disks will
see an immediate crash with no diagnostic information.

**Fix:**
```swift
// Replace the try! singleton with a lazy var that logs and degrades gracefully.
static let shared: HistoryStore = {
    do {
        return try HistoryStore(productionDB: true)
    } catch {
        // Log to Console.app so crash reports are actionable.
        // Return a fallback in-memory store so the app continues running
        // (history will not persist, but transcription still works).
        print("[HistoryStore] Fatal: could not open production DB: \(error)")
        // Fallback: in-memory store (history lost on restart, but no crash)
        return (try? HistoryStore(inMemory: true))!
        // If even in-memory fails, let it crash — that is a programming error.
    }
}()
```

Alternatively, surface the error through `AppState` so a banner can inform the user that history
is unavailable. The key fix is replacing `try!` with structured error handling.

---

## Warnings

### WR-01: Synchronous DatabaseQueue calls block the main thread

**File:** `SPRECHKRAFT/History/HistoryStore.swift:78-97` and `HistoryStore.swift:104-126`

**Issue:** `HistoryStore` is `@MainActor`. Every `dbQueue.write { }` and `dbQueue.read { }` call
is a synchronous blocking operation that GRDB dispatches on a serial writer/reader queue but
returns only after the operation completes. Called from `@MainActor`, these block the main thread
for the duration of every insert, delete, and search. With 1000+ entries the `search()` call
blocks the main thread for multiple milliseconds — measurable as input lag.

**Fix:**
Mark `insert`, `delete`, `deleteAll`, and `search` as `async` and use `dbQueue.asyncWrite` /
`dbQueue.asyncRead` (GRDB async variants) so they suspend rather than block:

```swift
// Example for insert:
func insert(_ entry: HistoryEntry) async throws {
    try await dbQueue.write { db in
        try entry.insert(db)
    }
}
```

Call sites in AppDelegate become `try? await HistoryStore.shared.insert(historyEntry)` — already
inside a `Task { await MainActor.run { } }` context, so this is a straightforward change.

The `search()` call in `HistoryView.onChange` runs inside a `Task` already, so adding `await` is
equally straightforward.

### WR-02: Silent swallowing of DB insert errors with no diagnostics

**File:** `SPRECHKRAFT/AppDelegate.swift:159` and `AppDelegate.swift:176`

**Issue:** `try? HistoryStore.shared.insert(historyEntry)` silently discards all errors. The
comment documents the intent (insert failure must not block transcription output), which is
correct. However, with no logging, persistent DB failures (disk full, schema mismatch after an
interrupted migration) are completely invisible. Users will silently lose history data with no
indication of the problem.

**Fix:**
Add a lightweight log call on failure:
```swift
do {
    try HistoryStore.shared.insert(historyEntry)
} catch {
    // History insert failed — transcription output already delivered, safe to continue.
    // Log for diagnostics (visible in Console.app with subsystem filter).
    print("[HistoryStore] Insert failed: \(error)")
}
```

This preserves the fire-and-forget semantics while making errors diagnosable.

### WR-03: Strong `self` capture in inner fire-and-forget Task (LLM path)

**File:** `SPRECHKRAFT/AppDelegate.swift:126-163`

**Issue:** The LLM path creates an inner unstructured `Task` (line 126) inside
`await MainActor.run`. This inner Task captures `self` (the AppDelegate) strongly via
`self.keychain` (line 129), `self.appState` (lines 147–161), etc., with no `[weak self]`
guard. The reference chain is:

```
audioController.onRecordingComplete  →  outer Task  →  MainActor.run block  →  inner Task  →  self (strong)
```

`audioController` itself is owned by `self` (AppDelegate). This creates a retain cycle:
`self → audioController → (closure retaining) → Task retaining → self`.

While AppDelegate is effectively a singleton for the app lifetime (so the cycle never causes a
leak in practice), it is a latent correctness risk if the architecture changes, and it is
inconsistent with the outer callback which correctly uses `[weak self]`.

**Fix:**
```swift
Task { [weak self] in
    guard let self else { return }
    let apiKey = self.keychain["groqApiKey"]
    // ... rest of LLM path
}
```

### WR-04: `DateFormatter` allocated on every SwiftUI render pass

**File:** `SPRECHKRAFT/History/HistoryView.swift:152-154` and `HistoryView.swift:247-249`

**Issue:** `groupedEntries` creates a new `DateFormatter` inside its `Dictionary(grouping:)`
closure on every render — one allocation per entry per render cycle for all non-today/non-yesterday
entries. `HistoryRowView.timeString` and `HistoryView.accessibilityLabel(for:)` each create a
new `DateFormatter` per call. `DateFormatter` is an expensive Objective-C object
(locale/calendar/timezone setup on init). With 50+ visible rows this causes measurable render
latency on every list scroll.

**Fix:**
Use a file-scope or view-scope cached formatter:

```swift
// At file scope or as a private static:
private let historyDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "dd.MM.yyyy"
    return f
}()

private let historyTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f
}()
```

Reference these from `groupedEntries`, `timeString`, and `accessibilityLabel(for:)`.

### WR-05: Missing test coverage for `delete()` and `deleteAll()`

**File:** `SPRECHKRAFTTests/HistoryStoreTests.swift` (absent)

**Issue:** `HistoryStore.delete(_:)` and `HistoryStore.deleteAll()` have no tests. The FTS5
virtual table uses `synchronize(withTable:)` triggers — a trigger synchronization bug on delete
would silently corrupt the FTS index, causing searches to return stale or phantom results. This
is the highest-risk GRDB code path (FTS triggers on DELETE are distinct from INSERT triggers) and
it has zero coverage.

**Fix:**
Add two tests:

```swift
@Test func testDeleteRemovesEntry() throws {
    let store = try makeStore()
    let entry = HistoryEntry(id: nil, createdAt: Date(),
        originalText: "Zu löschen", llmText: nil,
        profileName: nil, isLLMProcessed: false)
    try store.insert(entry)
    let inserted = try store.search(query: "")
    guard let toDelete = inserted.first else { Issue.record("Insert failed"); return }
    try store.delete(toDelete)
    let remaining = try store.search(query: "")
    #expect(remaining.isEmpty)
    // Verify FTS index is also clean
    let ftsResults = try store.search(query: "löschen")
    #expect(ftsResults.isEmpty)
}

@Test func testDeleteAllClearsStore() throws {
    let store = try makeStore()
    for i in 0..<5 {
        try store.insert(HistoryEntry(id: nil, createdAt: Date(),
            originalText: "Eintrag \(i)", llmText: nil,
            profileName: nil, isLLMProcessed: false))
    }
    try store.deleteAll()
    let remaining = try store.search(query: "")
    #expect(remaining.isEmpty)
}
```

---

## Info

### IN-01: `task(id: searchText.isEmpty)` is a fragile observation trigger

**File:** `SPRECHKRAFT/History/HistoryView.swift:84`

**Issue:** `task(id: searchText.isEmpty)` uses a `Bool` as the task identity. The observation
task is only restarted when the `isEmpty` state toggles (twice possible: `true→false`,
`false→true`). If `observeAll()` emits an error and the stream terminates (the `catch` on
line 90 silently drops it), the observation will not restart on subsequent DB activity until
the user types and then clears search text. The catch block's comment "Observation-Fehler still
schlucken" means the failure is invisible.

Consider logging the error and using a retry mechanism:
```swift
} catch {
    print("[HistoryView] Observation error: \(error)")
    // Optionally: set an error state to show a banner
}
```

### IN-02: `HistoryStore.shared` not injectable in HistoryView (no preview support)

**File:** `SPRECHKRAFT/History/HistoryView.swift:19`

**Issue:** `private let historyStore = HistoryStore.shared` hardcodes the singleton. SwiftUI
Previews for `HistoryView` will attempt to open the production SQLite database, which fails in
the Xcode Preview sandbox. Xcode will show a blank or errored preview.

Consider accepting the store as a parameter with a default:
```swift
struct HistoryView: View {
    private let historyStore: HistoryStore
    init(historyStore: HistoryStore = .shared) {
        self.historyStore = historyStore
    }
    // ...
}
```

### IN-03: `debounceTask` stored in `@State` without `.onDisappear` cancellation

**File:** `SPRECHKRAFT/History/HistoryView.swift:18`

**Issue:** `@State private var debounceTask: Task<Void, Never>?` is cancelled via `onChange`
before each new task is created, but is never cancelled when the view disappears. If the view
is dismissed (window closed) while a 200ms debounce sleep is in-flight, the Task continues,
calls `historyStore.search(query:)` (a blocking main-thread call), and then attempts
`entries = updated` on a view that is no longer displayed. SwiftUI handles this safely for
struct views, but the dangling Task wastes CPU and holds the `@MainActor` for the DB read.

```swift
.onDisappear {
    debounceTask?.cancel()
}
```

### IN-04: Performance test uses wall-clock time (fragile in CI)

**File:** `SPRECHKRAFTTests/HistoryStoreTests.swift:83-87`

**Issue:** `testSearchPerformance` asserts `elapsed < 0.2` using `Date().timeIntervalSince(start)`.
Wall-clock measurement includes OS scheduling latency and will produce spurious failures on a
loaded CI runner. The 200ms threshold is also very generous for an in-memory FTS5 query on 1000
rows.

Consider removing the timing assertion (FTS5 correctness is what matters in unit tests) or
using `XCTMeasure` if performance regression detection is important.

### IN-05: No test for invalid FTS5Pattern input returning empty results safely

**File:** `SPRECHKRAFTTests/HistoryStoreTests.swift` (absent)

**Issue:** The `guard let pattern = FTS5Pattern(matchingAllTokensIn: query)` on
`HistoryStore.swift:110` is the safety valve for malformed FTS5 queries (e.g., `"*"`, `"OR OR"`,
bare operators). There is no test verifying that invalid user input returns `[]` rather than
throwing or crashing. This is a quick test to add:

```swift
@Test func testInvalidFTS5QueryReturnsEmpty() throws {
    let store = try makeStore()
    // These are invalid FTS5 patterns — FTS5Pattern should return nil
    let results = try store.search(query: "* OR OR")
    #expect(results.isEmpty)
}
```

---

_Reviewed: 2026-04-21_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
