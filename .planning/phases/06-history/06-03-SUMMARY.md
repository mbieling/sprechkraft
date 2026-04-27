---
phase: "06-history"
plan: "03"
subsystem: "History / SwiftUI-View"
tags: ["swiftui", "historyview", "fts5", "copy-flash", "accessibility", "wave-2"]
dependency_graph:
  requires: ["06-02 (HistoryEntry + HistoryStore GRDB-Datenbankschicht)"]
  provides: ["HistoryView SwiftUI-View", "HistoryRowView", "Copy-Flash D-10", "T6-DELETE Confirm-Alert"]
  affects:
    - "SPRECHKRAFT/History/HistoryView.swift"
    - "SPRECHKRAFT.xcodeproj/project.pbxproj"
tech_stack:
  added: []
  patterns:
    - "Task.sleep-Debounce (200ms) statt Combine für Suchfeld-Verzögerung (D-06)"
    - ".task(id:) für ValueObservation ohne Task-Leak (Pitfall 7)"
    - "flashingEntryID: Int64? + withAnimation(.easeOut) für Copy-Flash (D-10)"
    - "SwiftUI .alert für Confirm-Dialog (T6-DELETE Mitigation)"
    - "Unicode-Escape-Sequenzen für typografische Anführungszeichen in Swift-String-Literals"
key_files:
  created:
    - "SPRECHKRAFT/History/HistoryView.swift"
  modified:
    - "SPRECHKRAFT.xcodeproj/project.pbxproj"
decisions:
  - "Unicode-Escape statt direkter U+201C/U+201E Zeichen in Swift-String-Literal — Swift-Compiler interpretiert U+201C als String-Delimiter (Rule 1 Bug-Fix)"
metrics:
  duration_minutes: 3
  tasks_completed: 1
  files_changed: 2
  completed_date: "2026-04-21"
---

# Phase 6 Plan 3: HistoryView SwiftUI-View Summary

**One-liner:** HistoryView.swift vollständig implementiert — Datum-Sektionen, 200ms-Debounce-Suche, grüner Copy-Flash (0.4s), T6-DELETE Confirm-Alert, .task(id:)-ValueObservation ohne Task-Leak, Accessibility-Labels nach UI-SPEC §12.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | HistoryView.swift — vollständige SwiftUI-View | 143b8d9 | SPRECHKRAFT/History/HistoryView.swift, SPRECHKRAFT.xcodeproj/project.pbxproj |

## Erstellte Dateien

### SPRECHKRAFT/History/HistoryView.swift (251 Zeilen)

**HistoryView (Haupt-View):**
- `@State searchText`, `entries`, `flashingEntryID`, `showClearConfirm`, `debounceTask`
- Toolbar: Suchfeld + "Verlauf leeren…"-Button mit Accessibility-Label
- Listenansicht mit `groupedEntries` in Datum-Sektionen (HEUTE / GESTERN / DD.MM.YYYY)
- Kontextmenü pro Zeile: "Eintrag löschen" (role: .destructive)
- `.alert("Verlauf leeren?")` mit destructive "Löschen"-Button (T6-DELETE)
- `.task(id: searchText.isEmpty)` für ValueObservation-Lifecycle
- `.onChange(of: searchText)` mit 200ms Task.sleep-Debounce

**groupedEntries computed property (D-05):**
- Dictionary-Gruppierung nach `Calendar.isDateInToday/Yesterday`
- Sektions-Schlüssel: "HEUTE" / "GESTERN" / "DD.MM.YYYY"
- Sortierung: `first?.createdAt DESC` (neueste Sektion oben)

**copyEntry(_:) (D-09, D-10):**
- `NSPasteboard.general.setString(entry.copyText, forType: .string)`
- `withAnimation(.easeOut(duration: 0.4)) { flashingEntryID = entry.id }`
- `AccessibilityNotification.Announcement("Kopiert").post()`
- Nach 400ms: `flashingEntryID = nil`

**HistoryRowView:**
- Zeitstempel: 11pt monospacedDigit, minWidth 32pt
- Vorschautext: 13pt, lineLimit(1)
- KI-Badge: 10pt semibold, systemPurple, cornerRadius 4, Padding xs
- Grün-Flash: `Color(.systemGreen).opacity(0.3)` wenn `isFlashing`

## T6-DELETE-Mitigation bestätigt

```swift
.alert("Verlauf leeren?", isPresented: $showClearConfirm) {
    Button("Löschen", role: .destructive) {
        try? historyStore.deleteAll()
        entries = []
    }
    Button("Abbrechen", role: .cancel) {}
} message: {
    Text("Alle Einträge werden unwiderruflich gelöscht.")
}
```

- Confirm-Dialog via `showClearConfirm: Bool` State
- Einzel-Löschen via `.contextMenu` (kein `onDelete` — macOS Pitfall 5)

## Debounce-Implementierung bestätigt

```swift
debounceTask = Task {
    try? await Task.sleep(for: .milliseconds(200))
    guard !Task.isCancelled else { return }
    entries = (try? historyStore.search(query: newValue)) ?? []
}
```

## ValueObservation bestätigt

```swift
.task(id: searchText.isEmpty) {
    if searchText.isEmpty {
        for try await updated in historyStore.observeAll() {
            entries = updated
        }
    }
}
```

## pbxproj-Änderungen

| ID | Typ | Beschreibung |
|----|-----|-------------|
| HT060612 | PBXFileReference | HistoryView.swift |
| HT060613 | PBXBuildFile | HistoryView.swift in Sources (App-Target) |

HistoryView.swift in HT060620-Gruppe (History/) und AA000070 (Sources-Phase) eingetragen.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Typografische Anführungszeichen via Unicode-Escape**
- **Found during:** Task 1 (erster Build — BUILD FAILED)
- **Issue:** `Text("Keine Einträge für „\(searchText)" gefunden.")` — Swift-Compiler (6.x) interpretiert U+201C (`"` — LINKES DOPPELTES ANFÜHRUNGSZEICHEN) als String-Delimiter; erzeugt 3 Compiler-Fehler: "expected ',' separator", "unterminated string literal", "expected member name following '.'"
- **Fix:** Unicode-Escape-Sequenzen: `\u{201E}` (öffnendes „) und `\u{201C}` (schließendes ") statt direkter Unicode-Zeichen im String-Literal. Außerdem `\u{00E4}` (ä) und `\u{00FC}` (ü) für maximale Robustheit.
- **Files modified:** SPRECHKRAFT/History/HistoryView.swift
- **Commit:** 143b8d9

## Known Stubs

Keine. HistoryView ist vollständig implementiert und mit HistoryStore.shared verdrahtet. Alle UI-Zustände (Liste, Leer A, Leer B) sind funktional. Die View wird erst in Wave 4 (06-04) in den Menüpunkt eingehängt.

## Threat Flags

Keine neuen Threat-Surfaces — alle Boundaries (T6-FTS5, T6-DELETE) waren im Plan-Threat-Model erfasst und sind mitigiert.

## Self-Check: PASSED

- FOUND: SPRECHKRAFT/History/HistoryView.swift (251 Zeilen)
- FOUND: HT060612 + HT060613 in SPRECHKRAFT.xcodeproj/project.pbxproj
- FOUND: commit 143b8d9 (feat(06-03): HistoryView.swift)
- VERIFIED: BUILD SUCCEEDED (xcodebuild build -scheme SPRECHKRAFT)
- VERIFIED: showClearConfirm vorhanden (T6-DELETE)
- VERIFIED: Task.sleep(for: .milliseconds(200)) vorhanden (D-06)
- VERIFIED: observeAll() + task(id:) vorhanden (Pitfall 7)
- VERIFIED: NSPasteboard.setString(entry.copyText) vorhanden (D-09)
- VERIFIED: flashingEntryID + milliseconds(400) vorhanden (D-10)
- VERIFIED: "KI-verarbeitet" Accessibility-Label vorhanden
- VERIFIED: "Eintrag löschen" Kontextmenü-Item vorhanden
