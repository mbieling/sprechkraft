---
phase: 01-app-shell
plan: "01"
subsystem: project-scaffold
tags: [xcode, spm, swift6, menu-bar, tdd-red]
dependency_graph:
  requires: []
  provides:
    - VoiceScribe.xcodeproj (App + Test Target)
    - VoiceScribe/Info.plist (LSUIElement=YES)
    - VoiceScribe/VoiceScribe.entitlements (no sandbox)
    - Package.swift (SPM CLI compatibility)
    - VoiceScribeTests/*.swift (RED phase scaffolds)
    - .gitignore
  affects: []
tech_stack:
  added:
    - Xcode 26.4 (Build 17E192)
    - Swift 6.0 (strict concurrency)
    - KeyboardShortcuts 2.4.0 (sindresorhus/KeyboardShortcuts)
    - LaunchAtLogin 1.1.0 (sindresorhus/LaunchAtLogin-modern)
    - Defaults 8.2.0 (sindresorhus/Defaults)
  patterns:
    - Hand-crafted project.pbxproj (no xcodegen — not installed)
    - XCRemoteSwiftPackageReference in pbxproj for SPM
    - Swift Testing (@Test, @Suite) for unit tests
key_files:
  created:
    - VoiceScribe.xcodeproj/project.pbxproj
    - VoiceScribe/Info.plist
    - VoiceScribe/VoiceScribe.entitlements
    - VoiceScribe/VoiceScribeApp.swift
    - VoiceScribeTests/RecordingStateTests.swift
    - VoiceScribeTests/AppStateTests.swift
    - VoiceScribeTests/HotkeyTests.swift
    - Package.swift
    - .gitignore
    - .planning/phases/01-app-shell/01-VALIDATION.md (updated)
  modified: []
decisions:
  - "xcodegen nicht installiert — pbxproj manuell erstellt (vollständig valide Struktur)"
  - "Bundle Identifier: com.voicescribe.app (lokal, kein Developer Team)"
  - "Ad-hoc signing (CODE_SIGN_IDENTITY = -) für Phase 1 ohne Distribution"
  - "SWIFT_STRICT_CONCURRENCY = complete aktiviert für Swift 6 correctness"
metrics:
  duration_minutes: 25
  completed_date: "2026-04-16"
  tasks_total: 5
  tasks_completed: 4
  files_created: 9
  files_modified: 1
requirements_satisfied:
  - SET-06
---

# Phase 01 Plan 01: Xcode-Projektgerüst und SPM-Dependencies Summary

Xcode-Projektgerüst mit manuell erstellter project.pbxproj, LSUIElement=YES in Info.plist, drei SPM-Dependencies (KeyboardShortcuts 2.4.0, LaunchAtLogin 1.1.0, Defaults 8.2.0) und drei RED-Phase-Test-Scaffolds für RecordingState, AppState und Hotkey-Integration.

## Completed Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Xcode-Verfügbarkeit prüfen | (checkpoint — vorab vom Orchestrator gelöst) | — |
| 2 | Xcode-Projekt anlegen | d88a86c | project.pbxproj, Info.plist, VoiceScribe.entitlements, VoiceScribeApp.swift, .gitignore |
| 3 | SPM-Dependencies anbinden | 6f4acb3 | Package.swift |
| 4 | Test-Scaffolds anlegen (RED) | df6baf8 | RecordingStateTests.swift, AppStateTests.swift, HotkeyTests.swift |
| 5 | Build verifizieren + Nyquist-Sign-Off | e0ec071 | 01-VALIDATION.md |

## Build Status

**App-Target:** BUILD SUCCEEDED
- Xcode 26.4, Swift 6.0, macOS 14.0 Deployment Target
- Ad-hoc signing ("Sign to Run Locally")
- SPM aufgelöst: KeyboardShortcuts 2.4.0, LaunchAtLogin 1.1.0, Defaults 8.2.0

**Test-Target:** BUILD FAILED (erwartet — RED Phase)

Fehlermeldungen (Plan 02/03 machen sie grün):
```
VoiceScribeTests/HotkeyTests.swift:9:43: error: type 'KeyboardShortcuts.Name' has no member 'toggleRecording'
VoiceScribeTests/HotkeyTests.swift:15:43: error: type 'KeyboardShortcuts.Name' has no member 'toggleRecording'
VoiceScribeTests/AppStateTests.swift:9:21: error: cannot find 'AppState' in scope
VoiceScribeTests/AppStateTests.swift:10:42: error: cannot infer contextual base in reference to member 'idle'
VoiceScribeTests/AppStateTests.swift:15:21: error: cannot find 'AppState' in scope
(+ weitere fehlende RecordingState-Member)
** TEST BUILD FAILED **
```

Diese Fehler sind die dokumentierte RED-Phase der TDD-Schleife. Plan 02 implementiert RecordingState und AppState (grünt RecordingStateTests + AppStateTests), Plan 03 deklariert KeyboardShortcuts.Name.toggleRecording (grünt HotkeyTests).

## Nyquist-Sign-Off

- `nyquist_compliant: true` — alle Auto-Tasks haben `<automated>` Verify-Blöcke
- `wave_0_complete: true` — alle drei Test-Scaffolds existieren und sind im pbxproj registriert
- Approval: signed off by Plan 01-01 Task 5, 2026-04-16

## Key Decisions

| Entscheidung | Rationale |
|-------------|-----------|
| pbxproj manuell erstellt | xcodegen nicht installiert; direktes Schreiben des pbxproj ist vollständig valide |
| ad-hoc signing | Kein Apple Developer Team für Phase 1; "Sign to Run Locally" reicht für lokale Entwicklung |
| SWIFT_STRICT_CONCURRENCY = complete | Swift 6 strict mode aktiviert; erzwingt korrekte Concurrency-Annotationen ab jetzt |
| Bundle ID com.voicescribe.app | Lokal, nicht registriert; akzeptiertes Risiko für Phase 1 (T-01-05) |
| Kein App Sandbox | Globale Hotkeys + AX-Text-Injektion inkompatibel mit Sandbox; bewusste Entscheidung aus STATE.md |

## SPM-Dependency-Versionen

| Library | Requested | Resolved |
|---------|-----------|---------|
| sindresorhus/KeyboardShortcuts | from: 2.0.0 | 2.4.0 |
| sindresorhus/LaunchAtLogin-modern | from: 1.0.0 | 1.1.0 (product: LaunchAtLogin) |
| sindresorhus/Defaults | from: 8.0.0 | 8.2.0 |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blockierendes Problem] xcodegen nicht installiert**
- **Gefunden während:** Task 2
- **Problem:** Der Plan erwähnt xcodegen als Option (B); Tool ist nicht auf dem System installiert.
- **Fix:** project.pbxproj vollständig manuell erstellt. Ergebnis identisch — `xcodebuild -list` erkennt beide Targets korrekt.
- **Dateien:** VoiceScribe.xcodeproj/project.pbxproj
- **Commit:** d88a86c

## Threat Mitigations Applied

| Threat | Mitigation |
|--------|-----------|
| T-01-01 (SPM Tampering) | Konkrete from:-Versionen in Package.swift und pbxproj; Package.resolved wird nach erstem Resolve commitet |
| T-01-02 (Entitlements) | Leere Entitlements-Datei ohne Sandbox und ohne zusätzliche Berechtigungen |
| T-01-03 (LSUIElement fehlt) | LSUIElement=true in Info.plist; GENERATE_INFOPLIST_FILE=NO verhindert Überschreibung |
| T-01-04 (DerivedData im Repo) | .gitignore listet DerivedData/, build/, xcuserdata/, .swiftpm/ |

## Next Wave

Plan 02 (RecordingState + AppState): Implementiert RecordingState-Enum mit Farben/Animation-Properties und AppState-Observable-Klasse. Macht RecordingStateTests.swift und AppStateTests.swift grün.

## Self-Check: PASSED

- [x] VoiceScribe.xcodeproj/project.pbxproj: FOUND
- [x] VoiceScribe/Info.plist: FOUND
- [x] VoiceScribe/VoiceScribe.entitlements: FOUND
- [x] VoiceScribeTests/RecordingStateTests.swift: FOUND
- [x] VoiceScribeTests/AppStateTests.swift: FOUND
- [x] VoiceScribeTests/HotkeyTests.swift: FOUND
- [x] Package.swift: FOUND
- [x] .gitignore: FOUND
- [x] Commit d88a86c: FOUND (feat: create Xcode project)
- [x] Commit 6f4acb3: FOUND (chore: Package.swift)
- [x] Commit df6baf8: FOUND (test: RED phase scaffolds)
- [x] Commit e0ec071: FOUND (feat: build verification + Nyquist sign-off)
- [x] nyquist_compliant: true in VALIDATION.md: FOUND
- [x] wave_0_complete: true in VALIDATION.md: FOUND
