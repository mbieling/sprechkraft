---
phase: 05-llm-prompt-profiles
plan: 05
subsystem: ui
tags: [swift, appstate, appdelegate, keychainaccess, groqservice, promptprofile, llm-routing, hotkeys]

# Dependency graph
requires:
  - phase: 05-03
    provides: PromptProfile model + Defaults.Keys.profiles + KeyboardShortcuts.Name.profile(_:)
  - phase: 05-04
    provides: GroqService.shared.process(transcript:profile:apiKey:)
provides:
  - AppState.activeProfileID: UUID? — per Hotkey gewähltes Profil (D-02 Erster-gewinnt)
  - AppState.groqKeyMissing: Bool — Keychain-Status Flag (T-5-01 kein API-Key in AppState)
  - AppDelegate.setupProfileHotkeys() — onKeyDown Handler für alle Profile
  - AppDelegate.onRecordingComplete — vollständiges LLM-Routing (Hotkey → Default → Fallback)
  - AppDelegate.showMenu() — Profil-Häkchen analog OutputMode-Pattern
  - KeychainAccess 4.2.2 als SPM-Dependency registriert
affects:
  - 05-06 (SettingsView: groqKeyMissing Banner + Profil-Editor)
  - 05-07 (End-to-End Integration)

# Tech tracking
tech-stack:
  added:
    - KeychainAccess 4.2.2 (kishikawakatsumi) — Keychain read/write via subscript API
  patterns:
    - T-5-01/T-5-02: API-Key ausschließlich als lokale Variable, nie in AppState oder gecacht
    - D-02 Erster-gewinnt: activeProfileID wird in onKeyDown gesetzt, sofort nach Nutzung auf nil zurückgesetzt
    - D-10 Stille Fallback: Groq-Fehler → Raw-Text ausgeben (kein Crash, kein UI-Feedback)
    - Observation-B: updateIcon() sofort nach State-Mutation (.llmProcessing setzen + zurücksetzen)

key-files:
  created: []
  modified:
    - VoiceScribe/AppState.swift
    - VoiceScribe/AppDelegate.swift
    - VoiceScribe.xcodeproj/project.pbxproj
    - VoiceScribe.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

key-decisions:
  - "KeyboardShortcuts.removeHandler(for:) statt disable(_:) zum Entfernen von onKeyDown-Callbacks — disable() deregistriert nur den Shortcut, entfernt aber nicht den Handler"
  - "KeychainAccess in packageReferences (PBXProject) UND packageProductDependencies (PBXNativeTarget) eintragen — fehlender packageReferences-Eintrag verhindert originHash-Berechnung durch Xcode"
  - "Package.resolved manuell mit keychainaccess-Pin ergänzt + originHash auf leer gesetzt damit Xcode neu berechnet"

patterns-established:
  - "Profil-Hotkey-Registrierung: for-loop über Defaults[.profiles] mit removeHandler + onKeyDown — bei Profil-Änderungen erneut aufrufen"
  - "LLM-Routing: profiles.first { $0.id == profileID } ?? profiles.first { $0.isDefault } ?? profiles.first — dreistufiger defensiver Fallback"

requirements-completed: [PROF-02, PROF-03, PROF-04, PROF-05, SET-01]

# Metrics
duration: 45min
completed: 2026-04-20
---

# Phase 05 Plan 05: AppState + AppDelegate Integration Summary

**Ende-zu-Ende LLM-Routing verdrahtet: Aufnahme → Transkription → aktives Profil (via Hotkey/Default) → optional Groq API → TextOutputService, mit .llmProcessing Icon-State und Keychain-basiertem API-Key-Zugriff**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-04-20T08:00:00Z
- **Completed:** 2026-04-20T08:45:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- AppState um `activeProfileID: UUID?` und `groqKeyMissing: Bool` erweitert — API-Key nie in AppState (T-5-01/T-5-02)
- AppDelegate verdrahtet: setupProfileHotkeys() mit onKeyDown (nicht onKeyUp, Pitfall 1 vermieden), D-02 Erster-gewinnt-Guard
- onRecordingComplete mit vollständigem LLM-Routing: Profil-Hotkey → Default-Profil → erstes Profil → LLM oder Direkt-Pfad
- .llmProcessing State + updateIcon() korrekt gesetzt während Groq-Call und zurückgesetzt nach Ausgabe (Observation-B)
- NSMenu Profil-Häkchen analog OutputMode-Pattern (D-03)
- KeychainAccess 4.2.2 als SPM-Dependency vollständig in pbxproj registriert (packageReferences + packageProductDependencies)

## Task Commits

1. **Task 1: AppState erweitern** — `b478cc0` (feat)
2. **Task 2: AppDelegate verdrahten + KeychainAccess SPM** — `04288f7` (feat)

**Plan metadata:** _(wird nach SUMMARY-Commit ergänzt)_

## Files Created/Modified

- `/Users/mbieling/claude/voice/VoiceScribe/AppState.swift` — activeProfileID + groqKeyMissing Properties hinzugefügt
- `/Users/mbieling/claude/voice/VoiceScribe/AppDelegate.swift` — import KeychainAccess, keychain property, setupProfileHotkeys(), LLM-Routing in onRecordingComplete, Profil-Häkchen in showMenu(), setActiveProfileFromMenu Action
- `/Users/mbieling/claude/voice/VoiceScribe.xcodeproj/project.pbxproj` — KeychainAccess als XCRemoteSwiftPackageReference (KC050500) + XCSwiftPackageProductDependency (KC050501) + packageReferences-Eintrag
- `/Users/mbieling/claude/voice/VoiceScribe.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` — keychainaccess@4.2.2 Pin hinzugefügt

## Decisions Made

- `KeyboardShortcuts.removeHandler(for:)` statt `disable(_:)` für Handler-Entfernung — `disable()` deregistriert nur den Shortcut, entfernt aber nicht den `onKeyDown`-Callback; nur `removeHandler()` entfernt beide (`legacyKeyDownHandlers` + `legacyKeyUpHandlers`)
- pbxproj benötigt KeychainAccess in ZWEI Stellen: `packageReferences` im `PBXProject` (damit Xcode das Package überhaupt auflöst) UND `packageProductDependencies` im `PBXNativeTarget` (damit das Target das Produkt linkt) — fehlender `packageReferences`-Eintrag war der Grund warum Xcode das Package ignorierte

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] KeychainAccess fehlte vollständig als Xcode SPM-Dependency**
- **Found during:** Task 2 (AppDelegate Build)
- **Issue:** `import KeychainAccess` compilierte nicht — Package war nicht in `packageReferences` (PBXProject) registriert, obwohl `XCRemoteSwiftPackageReference` und `XCSwiftPackageProductDependency` korrekt angelegt wurden
- **Fix:** KC050500 zu `packageReferences` im PBXProject hinzugefügt + Package.resolved mit keychainaccess@4.2.2 Pin ergänzt + originHash auf leer gesetzt damit Xcode neu berechnet
- **Files modified:** VoiceScribe.xcodeproj/project.pbxproj, Package.resolved
- **Verification:** `xcodebuild -resolvePackageDependencies` zeigt KeychainAccess in resolved source packages; BUILD SUCCEEDED
- **Committed in:** 04288f7 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 3 - Blocking)
**Impact on plan:** Notwendige Xcode-Projektstruktur-Korrektur. Kein Scope Creep.

## Issues Encountered

- Xcode ignoriert `XCSwiftPackageProductDependency` wenn das zugehörige Package nicht in `packageReferences` des PBXProject-Objekts steht — pbxproj braucht drei Einträge für eine SPM-Dependency: packageReferences (Project), XCSwiftPackageProductDependency (Produkt), packageProductDependencies (Target)
- `originHash` in Package.resolved wird von Xcode aus den packageReferences berechnet — nach manueller Ergänzung muss der Hash geleert werden damit Xcode ihn neu berechnet

## User Setup Required

None — Groq API-Key wird zur Laufzeit über SettingsView (Phase 5 Plan 06) eingegeben und im Keychain gespeichert. Kein manuelles Setup erforderlich.

## Next Phase Readiness

- LLM-Pipeline vollständig verdrahtet und bereit für Plan 06 (SettingsView: Groq API-Key Banner + Profil-Editor)
- groqKeyMissing Flag in AppState bereit für SettingsView-Banner (SET-01)
- setupProfileHotkeys() public — kann von ProfileEditorSheet nach Profil-Änderungen erneut aufgerufen werden

---
## Self-Check: PASSED

- AppState.swift: activeProfileID + groqKeyMissing vorhanden, kein API-Key-Field
- AppDelegate.swift: setupProfileHotkeys (x2), GroqService.shared.process (x1), activeProfileID = nil (x1), recordingState = .llmProcessing (x1)
- Commits b478cc0 + 04288f7 vorhanden
- BUILD SUCCEEDED, alle Tests grün

*Phase: 05-llm-prompt-profiles*
*Completed: 2026-04-20*
