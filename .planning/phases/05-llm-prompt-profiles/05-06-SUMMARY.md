---
phase: 05-llm-prompt-profiles
plan: 06
subsystem: ui
tags: [swift, swiftui, settingsview, profileeditorsheet, groq, keychain, promptprofile, crud-ui]

# Dependency graph
requires:
  - phase: 05-03
    provides: PromptProfile model + Defaults.Keys.profiles + KeyboardShortcuts.Name.profile(_:)
  - phase: 05-05
    provides: AppState.groqKeyMissing + AppDelegate.setupProfileHotkeys()
provides:
  - ProfileEditorSheet: Sheet-Modal fuer Profil-CRUD (D-12, PROF-01 bis PROF-04)
  - SettingsView Section("Prompt-Profile"): Groq-Banner + SecureField + Profilliste + Sheet-Integration
  - Notification.Name.refreshProfileHotkeys: Bridge SettingsView -> AppDelegate nach Profil-Aenderung
affects:
  - 05-07 (End-to-End Integration: Settings vollstaendig)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Draft-Pattern: ProfileEditorSheet empfaengt Kopie, Mutations via Callbacks (onSave/onDelete/onSetDefault)
    - T-5-01: SecureField -> onChange -> keychain["groqApiKey"] — kein API-Key in AppState/UserDefaults
    - T-5-04: isDefault-Invariante bei Loeschen (erstes verbleibendes Profil wird Default) und bei onSetDefault (map ueber alle Profile)
    - D-06: Loeschen-Button .disabled(isOnlyProfile) — genau 1 Profil -> deaktiviert
    - D-09: Thinking-Toggle + Prompt-Sektion nur sichtbar wenn draft.isLLMEnabled == true
    - Notification-Bridge: SettingsView postet .refreshProfileHotkeys, AppDelegate registriert Hotkeys neu

key-files:
  created:
    - VoiceScribe/ProfileEditorSheet.swift
  modified:
    - VoiceScribe/SettingsView.swift
    - VoiceScribe/AppDelegate.swift
    - VoiceScribe.xcodeproj/project.pbxproj

key-decisions:
  - "ProfileEditorSheet liegt direkt in VoiceScribe/ (nicht VoiceScribe/Views/) — Projekt hat keine Views/-Unterstruktur, alle View-Dateien direkt im Hauptverzeichnis"
  - ".frame(width:minHeight:) ist kein gueltiger SwiftUI-Modifier — stattdessen .frame(width:height:) auf NavigationStack"
  - "Notification.Name.refreshProfileHotkeys als Bridge statt direktem AppDelegate-Aufruf — SettingsView hat keinen Referenz auf AppDelegate"

# Metrics
duration: ~6min
completed: 2026-04-20
---

# Phase 05 Plan 06: SettingsView Profil-UI + ProfileEditorSheet Summary

**ProfileEditorSheet (5 Sektionen, D-06/D-09/D-12/D-13) + SettingsView Section("Prompt-Profile") mit Groq-Banner, SecureField-Keychain-Integration und .sheet(item:)-gestützter CRUD-UI**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-04-20T09:31:00Z
- **Completed:** 2026-04-20T09:37:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- `ProfileEditorSheet.swift` neu erstellt: NavigationStack + Form mit 5 Sektionen (Name, Aktivierungs-Hotkey, KI-Verarbeitung, Prompt, Aktionen)
- D-06: Löschen-Button `.disabled(isOnlyProfile)` — letztes Profil kann nicht gelöscht werden
- D-09: Thinking-Toggle und Prompt-Sektion nur sichtbar wenn `draft.isLLMEnabled == true`
- D-13: "Als Standard markieren" `.disabled(draft.isDefault)` mit accessibilityHint
- Draft-Pattern: lokale `@State private var draft: PromptProfile` — Mutations erst bei "Profil sichern"
- KeyboardShortcuts.Recorder in Sektion 2 mit `.profile(draft.id)`
- SettingsView erweitert: `import KeychainAccess`, neue State-Properties, private `keychain`-Instanz
- Groq-API-Key-Banner (groqKeyMissing, systemRed) analog axPermissionDenied-Banner
- SecureField → onChange → `keychain["groqApiKey"]` direkt (T-5-01: kein API-Key in AppState)
- Profilliste mit ⭐ (U+2B50) für Standard-Profil (D-13), chevron.right Disclosure-Indikator
- `.sheet(item: $editingProfile)` öffnet ProfileEditorSheet mit vollständigen Callbacks
- isDefault-Invariante beim Löschen (T-5-04) und bei onSetDefault korrekt enforced
- AppDelegate: `Notification.Name.refreshProfileHotkeys` + Observer + `handleRefreshProfileHotkeys()`
- pbxproj: PE050600/PE050601 für ProfileEditorSheet.swift registriert

## Task Commits

1. **Task 1: ProfileEditorSheet.swift** — `c9ae049` (feat)
2. **Task 2: SettingsView + AppDelegate** — `8d78e5e` (feat)

## Files Created/Modified

- `/Users/mbieling/claude/voice/VoiceScribe/ProfileEditorSheet.swift` — neu, 112 Zeilen, alle 5 Sektionen
- `/Users/mbieling/claude/voice/VoiceScribe/SettingsView.swift` — Section("Prompt-Profile") + Groq-Banner + Sheet
- `/Users/mbieling/claude/voice/VoiceScribe/AppDelegate.swift` — refreshProfileHotkeys Notification + Observer
- `/Users/mbieling/claude/voice/VoiceScribe.xcodeproj/project.pbxproj` — PE050600/PE050601 registriert

## Decisions Made

- ProfileEditorSheet in `VoiceScribe/` direkt (nicht `VoiceScribe/Views/`) — Projekt hat keine Views-Unterstruktur
- `.frame(width: 420, height: 460)` auf `NavigationStack` statt `.frame(width:minHeight:)` auf `Form` — `minHeight` als Named Parameter in `frame()` existiert nicht in dieser Kombination
- Notification-Bridge für Hotkey-Refresh: SettingsView hat keine Referenz auf AppDelegate → `NotificationCenter.default.post(name: .refreshProfileHotkeys)` als saubere Entkopplung

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `.frame(width: 420, minHeight: 380)` kompiliert nicht**
- **Found during:** Task 1 (Build-Verifikation)
- **Issue:** `frame(width:minHeight:)` ist kein gültiger SwiftUI `View`-Modifier — `minHeight` als benannter Parameter existiert nicht in dieser Overload
- **Fix:** `.frame(width: 420, height: 460)` auf den äußeren `NavigationStack` (nach Toolbar-Modifier) verschoben
- **Files modified:** VoiceScribe/ProfileEditorSheet.swift
- **Committed in:** c9ae049 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Minimale Layout-Abweichung (feste Höhe statt minHeight). Funktional äquivalent.

## Known Stubs

Keine. Alle Daten werden aus `Defaults[.profiles]` gelesen und via Callbacks in `Defaults[.profiles]` geschrieben. API-Key-Anzeige via KeychainAccess live beim Öffnen des Sheets. Keine Hardcoded-Werte in der UI.

## Threat Flags

Keine neuen Trust Boundaries eingeführt. Alle im Plan dokumentierten Mitigationen umgesetzt:
- T-5-01: `keychain["groqApiKey"] = newValue` in `onChange` direkt — kein Zwischenspeichern
- T-5-04: isDefault-Invariante in `onDelete` (map auf verbleibendes Profil) und `onSetDefault` (map über alle Profile)

## Self-Check: PASSED

- `VoiceScribe/ProfileEditorSheet.swift` existiert: FOUND
- `struct ProfileEditorSheet: View` (1 Treffer): FOUND
- `Section("Prompt-Profile")` in SettingsView (1 Treffer): FOUND
- `groqKeyMissing` in SettingsView (2 Treffer): FOUND
- `SecureField` in SettingsView (2 Treffer): FOUND (1x eigentliche Eingabe + 1x SecureField-spezifischer Treffer)
- `editingProfile` in SettingsView (4 Treffer): FOUND
- `ProfileEditorSheet` in SettingsView (1 Treffer im sheet): FOUND
- `⭐` in SettingsView (1 Treffer): FOUND
- `refreshProfileHotkeys` in AppDelegate (2 Treffer): FOUND
- Commits c9ae049 + 8d78e5e: FOUND
- BUILD SUCCEEDED: PASSED
- Alle Tests grün: PASSED

*Phase: 05-llm-prompt-profiles*
*Completed: 2026-04-20*
