---
phase: 04-text-output
plan: "01"
subsystem: foundation
tags: [OutputMode, Defaults, KeyboardShortcuts, AppState, Info.plist]
dependency_graph:
  requires: []
  provides:
    - OutputMode enum (Defaults.Serializable)
    - Defaults.Keys.outputMode (default: .field)
    - KeyboardShortcuts.Name.toggleOutputMode (⇧⌘V)
    - AppState.axPermissionDenied: Bool
    - Info.plist NSAccessibilityUsageDescription
  affects:
    - Plan 04-02 (TextOutputService konsumiert OutputMode + axPermissionDenied)
    - Plan 04-03 (AppDelegate wired toggleOutputMode Hotkey)
tech_stack:
  added: []
  patterns:
    - OutputMode als String-backed enum mit Defaults.Serializable (RawRepresentable reicht)
    - axPermissionDenied analog zu micPermissionDenied Pattern in AppState
key_files:
  created: []
  modified:
    - SPRECHKRAFT/Extensions/Defaults+Keys.swift
    - SPRECHKRAFT/Extensions/KeyboardShortcuts+Names.swift
    - SPRECHKRAFT/AppState.swift
    - SPRECHKRAFT/Info.plist
    - SPRECHKRAFTTests/DefaultsKeysTests.swift
decisions:
  - "OutputMode als separate top-level enum vor extension Defaults.Keys, nicht nested"
  - "NSAccessibilityUsageDescription in Info.plist (kein AX-Entitlement laut Pitfall 6)"
metrics:
  duration: "~10 min"
  completed: "2026-04-19"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 5
---

# Phase 04 Plan 01: Foundation-Typen fuer Text-Ausgabe Summary

OutputMode-Enum (String/Defaults.Serializable), outputMode-Key (.field default), toggleOutputMode-Hotkey (⇧⌘V) und axPermissionDenied-Property als Foundation fuer parallele Plan-02-Implementierung hinzugefuegt.

## Was wurde gebaut

Alle Datentypen, Defaults-Keys und AppState-Properties, die Phase 4 benoetigt:

- **OutputMode enum**: `String, Defaults.Serializable` mit `.field` (AX-Injektion) und `.clipboard`
- **Defaults.Keys.outputMode**: Standard `.field` gemaess D-06
- **KeyboardShortcuts.Name.toggleOutputMode**: Default-Shortcut ⇧⌘V (D-09)
- **AppState.axPermissionDenied**: `Bool = false`, konsumiert von SettingsView und TextOutputService
- **Info.plist**: NSAccessibilityUsageDescription mit deutschem Erklarungstext

## TDD Gate Compliance

- RED commit: `3067960` — `test(04-01): add failing tests for OutputMode enum and toggleOutputMode shortcut`
- GREEN commit: `1bee67f` — `feat(04-01): add OutputMode enum, outputMode defaults key, toggleOutputMode hotkey`
- REFACTOR: nicht notwendig (minimale Typ-Definitionen ohne Refactoring-Bedarf)

## Task-Commits

| Task | Name | Commit | Dateien |
|------|------|--------|---------|
| RED | Failing tests fuer OutputMode + toggleOutputMode | 3067960 | SPRECHKRAFTTests/DefaultsKeysTests.swift |
| 1 | OutputMode enum + outputMode Key + toggleOutputMode Name | 1bee67f | Defaults+Keys.swift, KeyboardShortcuts+Names.swift |
| 2 | axPermissionDenied + NSAccessibilityUsageDescription | f7cc344 | AppState.swift, Info.plist |

## Gesamtverifikation

Alle Pruefpunkte bestanden:
- `grep "enum OutputMode" Defaults+Keys.swift` → Treffer (Zeile 13)
- `grep "outputMode" Defaults+Keys.swift` → Key-Definition (Zeile 29)
- `grep "toggleOutputMode" KeyboardShortcuts+Names.swift` → Treffer (Zeile 18-19)
- `grep "axPermissionDenied" AppState.swift` → Treffer (Zeile 80)
- `grep "NSAccessibilityUsageDescription" Info.plist` → Treffer (Zeile 27)
- `xcodebuild build` → BUILD SUCCEEDED

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None — alle neuen Properties und Enums sind vollstaendig definiert. axPermissionDenied wird von Plan 04-02 (TextOutputService) und Plan 04-03 (AppDelegate) konsumiert.

## Threat Flags

Keine neuen Trust-Boundaries jenseits des Plan-Threat-Modells einfuehrt:
- OutputMode-String in UserDefaults: accepted (T-04-01, T-04-02)
- NSAccessibilityUsageDescription: nur Privacy-String, keine neue Sicherheitsflaeche

## Self-Check: PASSED

- FOUND: Defaults+Keys.swift (OutputMode enum + outputMode Key)
- FOUND: KeyboardShortcuts+Names.swift (toggleOutputMode)
- FOUND: AppState.swift (axPermissionDenied)
- FOUND: Info.plist (NSAccessibilityUsageDescription)
- FOUND: commit 3067960 (RED — failing tests)
- FOUND: commit 1bee67f (GREEN — implementation)
- FOUND: commit f7cc344 (Task 2 — AppState + Info.plist)
