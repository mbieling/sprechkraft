---
phase: 05-llm-prompt-profiles
plan: "03"
subsystem: data-model
tags: [tdd, green-phase, prompt-profile, defaults, keyboard-shortcuts, data-model]
dependency_graph:
  requires: [05-01, 05-02]
  provides: [PROF-01, PROF-02, PROF-03, PROF-04, PromptProfile-type, profiles-defaults-key, profile-hotkey-names]
  affects: [SPRECHKRAFT/Models, SPRECHKRAFT/Extensions, SPRECHKRAFTTests]
tech_stack:
  added: []
  patterns:
    - "Defaults.Serializable via Codable-Konformanz (automatisch)"
    - "UUID-basierte dynamische KeyboardShortcuts.Name-Instanzen (static func statt static let)"
    - "Models/-Unterverzeichnis fuer Datenstrukturen"
key_files:
  created:
    - SPRECHKRAFT/Models/PromptProfile.swift
  modified:
    - SPRECHKRAFT/Extensions/Defaults+Keys.swift
    - SPRECHKRAFT/Extensions/KeyboardShortcuts+Names.swift
    - SPRECHKRAFTTests/PromptProfileTests.swift
    - SPRECHKRAFT.xcodeproj/project.pbxproj
decisions:
  - "Foundation-Import explizit in KeyboardShortcuts+Names.swift und PromptProfileTests.swift — UUID ist kein impliziter Import in allen Swift-Modulen"
  - "static var defaultProfile (nicht let) — UUID() wird einmalig beim ersten Defaults-Zugriff materialisiert"
  - "Kein API-Key-Feld in PromptProfile — T-5-01 eingehalten"
metrics:
  duration: "~10 min"
  completed: "2026-04-19T17:16:36Z"
  tasks_completed: 2
  files_changed: 5
---

# Phase 05 Plan 03: PromptProfile Datenmodell + Persistenz + Hotkey-Namen Summary

Wave-1-Plan A: PromptProfile.swift, Defaults profiles-Key und KeyboardShortcuts profile(_:) implementiert. Alle 5 PromptProfileTests gruen — TDD GREEN-Phase fuer PROF-01/03/04 abgeschlossen.

## What Was Built

**Task 1 — PromptProfile struct (PROF-01 bis PROF-04)**

`SPRECHKRAFT/Models/PromptProfile.swift` erstellt:
- `struct PromptProfile: Codable, Defaults.Serializable, Identifiable` mit 6 Feldern: `id`, `name`, `prompt`, `isLLMEnabled`, `isThinkingEnabled`, `isDefault`
- `static var defaultProfile`: "Rohe Transkription", LLM aus, isDefault=true (D-05)
- `Models/`-Gruppe in `project.pbxproj` eingetragen (PP050300/PP050301/PP050302)

**Task 2 — Extensions erweitert (PROF-01, D-02, D-04)**

`SPRECHKRAFT/Extensions/Defaults+Keys.swift`:
- `static let profiles = Key<[PromptProfile]>("profiles", default: [PromptProfile.defaultProfile])` — Persistenz des gesamten Profil-Arrays via UserDefaults (D-04)

`SPRECHKRAFT/Extensions/KeyboardShortcuts+Names.swift`:
- `static func profile(_ id: UUID) -> Self` — UUID-basierte dynamische Hotkey-Namen (D-02); `"profile-\(id.uuidString)"` als Persistence-Key

## TDD Gate Compliance

| Gate | Commit | Status |
|------|--------|--------|
| RED (Plan 05-01) | e36c3a3 | PASS — 5 Stubs schlugen fehl |
| GREEN (Plan 05-03) | 830aad1 | PASS — alle 5 Tests gruen |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Foundation-Import fehlend in KeyboardShortcuts+Names.swift**
- **Found during:** Task 2 — erste Testrun
- **Issue:** `UUID` nicht im Scope; `KeyboardShortcuts`-Modul importiert Foundation nicht transitiv
- **Fix:** `import Foundation` vor `import KeyboardShortcuts` ergaenzt
- **Files modified:** SPRECHKRAFT/Extensions/KeyboardShortcuts+Names.swift
- **Commit:** 830aad1

**2. [Rule 1 - Bug] Foundation-Import fehlend in PromptProfileTests.swift**
- **Found during:** Task 2 — erste Testrun
- **Issue:** `UUID`, `JSONEncoder`, `JSONDecoder` nicht im Scope; Test-Stub aus Plan 05-01 hatte Foundation nicht importiert
- **Fix:** `import Foundation` als ersten Import ergaenzt
- **Files modified:** SPRECHKRAFTTests/PromptProfileTests.swift
- **Commit:** 830aad1

## Acceptance Criteria Check

| Criterion | Status |
|-----------|--------|
| SPRECHKRAFT/Models/PromptProfile.swift existiert | PASS |
| struct PromptProfile: Codable, Defaults.Serializable, Identifiable | PASS |
| 6 Felder: id, name, prompt, isLLMEnabled, isThinkingEnabled, isDefault | PASS |
| static var defaultProfile vorhanden | PASS |
| Defaults.Keys.profiles = Key<[PromptProfile]> | PASS |
| PromptProfile.defaultProfile als Default-Wert | PASS |
| static func profile(_ id: UUID) -> Self | PASS |
| "profile-\(id.uuidString)" als Persistence-Key | PASS |
| Alle 5 PromptProfileTests GRUEN | PASS |
| BUILD SUCCEEDED | PASS |
| Kein API-Key-Feld in PromptProfile (T-5-01) | PASS |

## Known Stubs

Keine — alle Felder sind vollstaendig implementiert und von Tests verifiziert.

## Threat Flags

Keine neuen sicherheitsrelevanten Flaechen. T-5-01 (kein API-Key in PromptProfile) und T-5-04 (isDefault-Invariante via testIsDefaultInvariante) eingehalten.

## Self-Check

- SPRECHKRAFT/Models/PromptProfile.swift: FOUND
- SPRECHKRAFT/Extensions/Defaults+Keys.swift (profiles Key): FOUND
- SPRECHKRAFT/Extensions/KeyboardShortcuts+Names.swift (profile func): FOUND
- Commit 3cb039d: FOUND
- Commit 830aad1: FOUND

## Self-Check: PASSED
