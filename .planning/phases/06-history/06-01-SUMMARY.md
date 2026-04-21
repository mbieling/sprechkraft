---
phase: "06-history"
plan: "01"
subsystem: "History / GRDB-Integration"
tags: ["grdb", "spm", "tdd", "wave-0", "pbxproj"]
dependency_graph:
  requires: []
  provides: ["GRDB SPM-Dependency", "HistoryStore Wave-0-Stub", "HistoryStoreTests RED-Contract"]
  affects: ["VoiceScribe.xcodeproj/project.pbxproj", "VoiceScribe/Models/HistoryStore.swift", "VoiceScribeTests/HistoryStoreTests.swift"]
tech_stack:
  added: ["GRDB.swift v7.5.0 (groue/GRDB.swift, SPM)"]
  patterns: ["Wave-0 RED-Stub Pattern: Compile-Scaffold mit notImplemented-Stubs"]
key_files:
  created:
    - "VoiceScribe/Models/HistoryStore.swift"
    - "VoiceScribeTests/HistoryStoreTests.swift"
  modified:
    - "VoiceScribe.xcodeproj/project.pbxproj"
decisions:
  - "Wave-0-Stub statt leerer Klasse: HistoryStore wirft notImplemented um RED-Tests zu erzwingen"
  - "HistoryEntry.copyText bereits im Stub implementiert (kein Datenbank-Zugriff noetig)"
metrics:
  duration_minutes: 35
  tasks_completed: 2
  files_changed: 3
  completed_date: "2026-04-21"
---

# Phase 6 Plan 1: GRDB SPM-Dependency + HistoryStoreTests RED-Stubs Summary

**One-liner:** GRDB.swift v7.5.0 als SPM-Dependency in pbxproj integriert und HistoryStore-Wave-0-Stub mit 5 RED-Tests als TDD-Contract fuer Wave 1 angelegt.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | GRDB SPM-Dependency in project.pbxproj | b5b7938 | VoiceScribe.xcodeproj/project.pbxproj |
| 2 | HistoryStoreTests.swift RED-Stubs + Wave-0-Scaffold | 32e02a4 | VoiceScribeTests/HistoryStoreTests.swift, VoiceScribe/Models/HistoryStore.swift, VoiceScribe.xcodeproj/project.pbxproj |

## pbxproj-Aenderungen

### Task 1: GRDB SPM-Integration (3+1 Stellen)

**Stelle 1 — XCRemoteSwiftPackageReference** (nach Zeile 630, XCRemoteSwiftPackageReference-Section):
```
GR060600 /* XCRemoteSwiftPackageReference "GRDB.swift" */ = {
    isa = XCRemoteSwiftPackageReference;
    repositoryURL = "https://github.com/groue/GRDB.swift";
    requirement = { kind = upToNextMajorVersion; minimumVersion = 7.5.0; };
};
```

**Stelle 2 — packageReferences in PBXProject** (Zeile ~289, nach KC050500):
```
GR060600 /* XCRemoteSwiftPackageReference "GRDB.swift" */,
```

**Stelle 3a — XCSwiftPackageProductDependency** (nach Zeile 658, nach KC050501-Block):
```
GR060601 /* GRDB */ = {
    isa = XCSwiftPackageProductDependency;
    package = GR060600 /* XCRemoteSwiftPackageReference "GRDB.swift" */;
    productName = GRDB;
};
```

**Stelle 3b — packageProductDependencies VoiceScribe-Target** (Zeile ~232, nach KC050501):
```
GR060601 /* GRDB */,
```

**Object-IDs bestaetigt:** GR060600 (XCRemoteSwiftPackageReference) und GR060601 (XCSwiftPackageProductDependency).

### Task 2: HistoryStore-Dateien in pbxproj registriert

Neue Object-IDs:
- `HT060600` — PBXFileReference HistoryStoreTests.swift
- `HT060601` — PBXBuildFile HistoryStoreTests.swift in Sources (Tests-Target)
- `HT060602` — PBXFileReference HistoryStore.swift
- `HT060603` — PBXBuildFile HistoryStore.swift in Sources (App-Target)

## Test-Datei

**Pfad:** `VoiceScribeTests/HistoryStoreTests.swift`
**Anzahl Tests:** 5

| Test | Anforderung | RED-Status |
|------|------------|------------|
| testInsertPersists | HIST-01 | FEHLSCHLAEGT (notImplemented) |
| testBothTextsStored | HIST-02 | FEHLSCHLAEGT (notImplemented) |
| testFTS5SearchFindsMatch | HIST-03 | FEHLSCHLAEGT (notImplemented) |
| testSearchPerformance | HIST-03 | FEHLSCHLAEGT (notImplemented) |
| testCopyPreference | HIST-04 | BESTEHT (copyText im Stub implementiert) |

Erwartete Signaturen fuer Wave 1:
- `HistoryStore(inMemory: Bool) throws`
- `store.insert(_ entry: HistoryEntry) throws`
- `store.search(query: String) throws -> [HistoryEntry]`
- `HistoryEntry.copyText: String`

## Kompilierungs-Status

- App-Target: **BUILD SUCCEEDED** (xcodebuild build)
- Tests: **4/5 RED** (erwarteter Wave-0-Zustand)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] KeychainAccess-URL-Tippfehler behoben**
- **Found during:** Task 1 (erster Build-Versuch)
- **Issue:** `repositoryURL = "https://github.com/kishikawakatsuki/KeychainAccess"` — Tippfehler im GitHub-Nutzernamen (`katsuki` statt `katsumi`), fuehrt zu `Repository not found` bei SPM-Aufloesung
- **Fix:** URL auf `https://github.com/kishikawakatsumi/KeychainAccess` korrigiert
- **Files modified:** VoiceScribe.xcodeproj/project.pbxproj
- **Commit:** b5b7938

**2. [Rule 3 - Blocking] Wave-0-Stub fuer HistoryStore und HistoryEntry angelegt**
- **Found during:** Task 2 (erster Test-Build)
- **Issue:** HistoryStoreTests.swift referenziert `HistoryStore` und `HistoryEntry` die noch nicht existieren — Test-Target kann nicht kompilieren
- **Fix:** `VoiceScribe/Models/HistoryStore.swift` als Wave-0-Stub angelegt (alle Methoden werfen `notImplemented`, `copyText` bereits implementiert)
- **Files modified:** VoiceScribe/Models/HistoryStore.swift (neu), VoiceScribe.xcodeproj/project.pbxproj
- **Commit:** 32e02a4

**3. [Rule 1 - Bug] Doppelte pbxproj-Object-ID korrigiert**
- **Found during:** Task 2 (nach Stub-Anlage — Build-Fehler "project is damaged")
- **Issue:** `HT060600` wurde gleichzeitig als PBXBuildFile und als PBXFileReference verwendet — fuehrt zu "unrecognized selector sent to instance"-Crash
- **Fix:** PBXBuildFile fuer HistoryStore.swift auf neue ID `HT060603` umbenannt
- **Files modified:** VoiceScribe.xcodeproj/project.pbxproj
- **Commit:** 32e02a4

## Self-Check: PASSED

- FOUND: VoiceScribeTests/HistoryStoreTests.swift
- FOUND: VoiceScribe/Models/HistoryStore.swift
- FOUND: .planning/phases/06-history/06-01-SUMMARY.md
- FOUND: commit b5b7938 (chore: GRDB SPM-Dependency)
- FOUND: commit 32e02a4 (test: RED-Stubs)
