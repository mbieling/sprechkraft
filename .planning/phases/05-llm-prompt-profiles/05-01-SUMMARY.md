---
phase: 05-llm-prompt-profiles
plan: "01"
subsystem: testing
tags: [tdd, prompt-profile, red-phase, tests]
dependency_graph:
  requires: []
  provides: [PROF-01-tests, PROF-03-tests, PROF-04-tests]
  affects: [SPRECHKRAFTTests]
tech_stack:
  added: []
  patterns: [Swift Testing framework (@Suite/@Test/#expect), TDD RED-GREEN cycle]
key_files:
  created:
    - SPRECHKRAFTTests/PromptProfileTests.swift
  modified:
    - SPRECHKRAFT.xcodeproj/project.pbxproj
decisions:
  - "RED-Phase: Build schlaegt fehl weil PromptProfile.swift fehlt — korrekter und gewollter Zustand in Wave 0"
  - "5 @Test-Stubs statt @Suite-Level-Stubs: jeder Test hat eigene, nicht-trivialen Assertions"
metrics:
  duration: "~5 min"
  completed: "2026-04-19"
  tasks_completed: 1
  files_changed: 2
---

# Phase 05 Plan 01: PromptProfile TDD RED Summary

TDD RED-Phase: 5 Test-Stubs in `PromptProfileTests.swift` definieren den Verhaltensvertrag fuer `PromptProfile` (PROF-01, PROF-03, PROF-04). Build schlaegt in Wave 0 fehl — korrekt, da `PromptProfile.swift` erst in Wave 1 (Plan 05-02) existiert.

## What Was Built

`SPRECHKRAFTTests/PromptProfileTests.swift` mit 5 failing @Test-Stubs:

1. **testDefaultProfileShape** (PROF-01) — prueft `PromptProfile.defaultProfile` Initialwerte (name, isLLMEnabled, isThinkingEnabled, isDefault, prompt)
2. **testProfilesDefaultKey** (PROF-01) — prueft `Defaults.Keys.profiles.defaultValue` hat genau 1 Eintrag mit isDefault==true und name=="Rohe Transkription"
3. **testCodableRoundTrip** (PROF-01) — encode + decode via JSONEncoder/JSONDecoder, alle 6 Felder verglichen
4. **testIsDefaultInvariante** (PROF-04) — 3-Profil-Array, Profil B als Default markieren, danach genau 1 isDefault==true
5. **testLLMToggleUnabhaengigVonDefault** (PROF-03) — isLLMEnabled und isDefault sind unabhaengige Flags

`SPRECHKRAFT.xcodeproj/project.pbxproj` wurde erweitert um:
- PBXFileReference fuer PromptProfileTests.swift (PP050101)
- SPRECHKRAFTTests Group-Eintrag (PP050101)
- PBXSourcesBuildPhase Eintrag (PP050100)

## RED-Phase Verification

Build-Ergebnis (erwartet):
```
Cannot find 'PromptProfile' in scope
Type 'Defaults.Keys' has no member 'profiles'
Testing cancelled because the build failed.
** TEST FAILED **
```

Dieser Fehler bestaetigt die korrekte RED-Phase: Tests koennen nicht kompilieren solange `PromptProfile.swift` fehlt. Kein False Positive moeglich.

## Deviations from Plan

Keine — Plan wurde exakt ausgefuehrt. pbxproj-Eintraege wurden vom Orchestrator vor Ausfuehrung ergaenzt.

## Acceptance Criteria Check

| Criterion | Status |
|-----------|--------|
| PromptProfileTests.swift existiert | PASS |
| 5x `@Test(` im File | PASS (grep liefert 5) |
| `import Testing` vorhanden | PASS |
| `@testable import SPRECHKRAFT` vorhanden | PASS |
| PROF-01 mind. 2x referenziert | PASS (3x) |
| PROF-04 mind. 1x referenziert | PASS |
| PROF-03 mind. 1x referenziert | PASS |
| "Rohe Transkription" mind. 1x | PASS |

## Known Stubs

Keine produktiven Stubs — dies ist ausschliesslich ein Testfile. `PromptProfile` selbst wird in Plan 05-02 implementiert.

## Threat Flags

Keine neuen Sicherheits-relevanten Flaechen eingefuehrt. Tests enthalten keinen API-Key (T-5-01 eingehalten). isDefault-Invariante in Test 4 verifiziert (T-5-04 mitigiert).

## Next Step

Plan 05-02: `PromptProfile.swift` implementieren (GREEN-Phase) — alle 5 Tests muessen dann gruen werden.

## Self-Check

- SPRECHKRAFTTests/PromptProfileTests.swift: FOUND
- Commit e36c3a3: FOUND
