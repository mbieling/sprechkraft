# Phase 5: LLM + Prompt Profiles - Context

**Gathered:** 2026-04-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Nutzer verwaltet benannte Prompt-Profile (Name, Prompt-Text, eigener Hotkey, LLM-Toggle,
Thinking-Toggle) in den Einstellungen. Während der Aufnahme: Profil-Hotkey + ⌥⌘R gleichzeitig
halten → Transkript wird nach der Aufnahme über Groq qwen3-32b geleitet bevor TextOutputService
aufgerufen wird. Ohne Profil-Hotkey: Standard-Profil greift.

Kein History in dieser Phase. Kein Streaming. Kein Multi-Provider.

</domain>

<decisions>
## Implementation Decisions

### Profil-Aktivierung

- **D-01:** Aktivierungsmechanismus: **Profil-Hotkey + ⌥⌘R gleichzeitig halten** — beide Tasten
  müssen während der Aufnahme gedrückt sein. Loslassen des Aufnahme-Hotkeys stoppt die Aufnahme
  und startet die Verarbeitungs-Pipeline (Transkription → optional Groq → TextOutputService).
- **D-02:** Konflikt bei mehreren Profil-Hotkeys: **Erster gewinnt** — das zuerst gedrückte Profil
  gilt für diese Aufnahme, spätere Hotkey-Inputs werden für diese Aufnahme ignoriert.
- **D-03:** Visuelles Feedback: **Menü-Häkchen genügt** — kein StatusBar-Title, kein Toast.
  Konsistent mit OutputMode-Häkchen (Phase 4 D-08). Aktives Profil im Menü markiert.

### Profil-Persistenz

- **D-04:** Speicherung: **`Defaults.Keys` mit Codable Array** — `[PromptProfile]` als
  `Defaults.Serializable`-Struct in UserDefaults via Defaults-Library. Konsistent mit
  bestehendem `silenceDuration`/`selectedMicUID`/`outputMode`-Pattern. Einfache Migration
  zu GRDB in Phase 6.
- **D-05:** Initialer Zustand beim ersten App-Start: **ein vorgefertigtes Default-Profil**
  namens „Rohe Transkription" (LLM disabled, kein Prompt, kein Hotkey). Kein Sonderfall
  „keine Profile" im gesamten Code-Pfad.
- **D-06:** Das zuletzt verbleibende Profil ist **nicht löschbar** — Löschen-Button wird
  ausgegraut wenn die Profilliste nur noch ein Element enthält. Jedes einzelne Profil
  (inkl. des initialen) darf gelöscht werden solange mindestens eines verbleibt.

### Groq API Design

- **D-07:** HTTP-Client: **URLSession direkt** — kein Third-Party-SDK. OpenAI-kompatibler
  Endpunkt von Groq, einfacher POST mit JSON-Body. Konsistent mit CLAUDE.md-Empfehlung.
- **D-08:** Modell: **qwen/qwen3-32b** — fest kodiert, kein Modell-Picker.
- **D-09:** Thinking-Mode: **pro Profil konfigurierbar** (Toggle in Profil-Bearbeitung).
  Kein globaler Schalter. Profiles mit Thinking aktiv nutzen qwen3's Chain-of-Thought;
  ohne Thinking wird `/no_think` als Prompt-Präfix eingefügt.
- **D-10:** Fehlerbehandlung: **stille Fallback zu Raw-Transkript** — bei fehlendem Key,
  Timeout oder API-Fehler wird der unverarbeitete Transkriptions-Text ausgegeben.
  Konsistent mit Phase-3-Fehlerbehandlung (D-12 dort). Kein Toast, kein Alert.
- **D-11:** API-Key-Speicherung: **macOS Keychain via KeychainAccess** (SET-01) — einmalige
  Eingabe in SettingsView (Passwortfeld), Abruf per KeychainAccess-Subscript-API vor
  jedem Groq-Aufruf.

### Settings-UI Struktur

- **D-12:** Profil-Verwaltung: **Sheet-Modal pro Profil** — SettingsView zeigt Liste mit
  Profil-Namen und ⭐-Marker für Standard. Klick auf Zeile öffnet SwiftUI-`.sheet()`
  mit: Name, Hotkey (KeyboardShortcuts.Recorder), LLM-Toggle, Thinking-Toggle, Prompt-
  Texteditor (mehrzeilig), „Als Standard markieren"-Button, Löschen-Button.
- **D-13:** Standard-Profil-Markierung: **⭐-Symbol** in der Liste, „Als Standard"
  deaktiviert wenn das Profil bereits Standard ist.

### Claude's Discretion

- Exakte `PromptProfile`-Struct-Felder und Codable-Implementierung
- KeyboardShortcuts.Name-Generierung für dynamische Profile (UUID-basiert vs. Index-basiert)
- Timeout-Wert für Groq-URLSession-Request
- Reihenfolge der Felder im Sheet-Modal
- Ob `llmProcessing`-State im Icon während Groq-Aufruf gesetzt wird (empfohlen: ja, laut FEED-01)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Anforderungen
- `.planning/REQUIREMENTS.md` — Phase 5: PROF-01, PROF-02, PROF-03, PROF-04, PROF-05, SET-01
- `.planning/ROADMAP.md` §Phase 5 — Goal, Success Criteria (5 Kriterien)

### Technology Stack
- `CLAUDE.md` §Technology Stack §LLM Integration (Groq) — URLSession direkt, kein SDK, qwen/qwen3-32b
- `CLAUDE.md` §Supporting Libraries — KeychainAccess (kishikawakatsuki), Defaults (sindresorhus), KeyboardShortcuts (sindresorhus)

### Bestehendes Pattern
- `.planning/phases/04-text-output/04-CONTEXT.md` — Defaults.Key-Pattern, OutputMode-Häkchen (D-08), Observation-B, Swift 6 Strict Concurrency
- `.planning/phases/03-transcription/03-CONTEXT.md` — Fehlerbehandlung D-12: stille Rückkehr zu .idle (Vorlage für Groq-Fallback D-10)
- `.planning/phases/02-audio-capture/02-CONTEXT.md` — AudioController-Architektur, Hotkey-Pattern

### Bestehendes Code
- `SPRECHKRAFT/Extensions/Defaults+Keys.swift` — Vorlage für neuen `profiles`-Key (Codable Array)
- `SPRECHKRAFT/Extensions/KeyboardShortcuts+Names.swift` — Vorlage für dynamische Profil-Hotkey-Namen
- `SPRECHKRAFT/AppState.swift` — `llmProcessing`-State bereits vorhanden (RecordingState.llmProcessing)
- `SPRECHKRAFT/AppDelegate.swift` — `onRecordingComplete`-Callback (Integrationspunkt: Groq-Pipeline einklinken)
- `SPRECHKRAFT/Views/SettingsView.swift` — bestehende Struktur, Permission-Banner-Pattern für Groq-API-Key-Feld

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `RecordingState.llmProcessing` in AppState — bereits definiert und im Icon-State-Machine verdrahtet (lila, pulsierend 1.2s). Phase 5 setzt diesen Zustand während Groq-Aufruf.
- `Defaults+Keys.swift` — neuer Key `profiles: [PromptProfile]` nach gleichem Schema
- `KeyboardShortcuts+Names.swift` — neue dynamische Namen für Profile (z.B. UUID-basiert)
- `SettingsView.swift` — `.sheet()`-Pattern und Permission-Banner direkt wiederverwendbar
- `TextOutputService` — bestehender Ausgabe-Service, Groq-Ergebnis wird dort als Input übergeben

### Established Patterns
- **Defaults-Persistenz**: `@Default(.key) var property` in Views/AppDelegate
- **Observation-B**: State-Änderungen → manuelles `updateIcon()` anstoßen
- **Swift 6 Strict Concurrency** (`SWIFT_STRICT_CONCURRENCY = complete`): Groq-URLSession async/await, Ergebnis via `Task { @MainActor in }` zurück
- **Permission-Banner**: roter Banner in SettingsView wenn Key fehlt (analog axPermissionDenied)

### Integration Points
- `AppDelegate.onRecordingComplete([Float]) -> Void` — nach Transkription: aktives Profil prüfen, bei LLM enabled → Groq → TextOutputService; bei LLM disabled → direkt TextOutputService
- `AppState.recordingState` — `.llmProcessing` setzen während Groq-Aufruf (FEED-01: Icon lila pulsierend)
- `AppDelegate.applicationDidFinishLaunching` — Groq API Key aus Keychain laden / prüfen, AppState-Property setzen
- Neues `AppState.groqKeyMissing: Bool` für SettingsView-Banner (analog `axPermissionDenied`)

</code_context>

<specifics>
## Specific Ideas

- Profil-Hotkey + ⌥⌘R gleichzeitig halten: `KeyboardShortcuts` global handler für Profil-Hotkeys registrieren; beim Empfang eines Profil-Hotkey-Events während `.recording`-State → aktives Profil setzen (erster gewinnt via Guard)
- qwen3-32b ohne Thinking: Prompt-Präfix `/no_think` im Body-String, nicht als separate API-Option
- KeychainAccess-Subscript: `try? keychain["groqApiKey"]` vor jedem Groq-Request

</specifics>

<deferred>
## Deferred Ideas

- **Streaming-Output** (Token-für-Token Ausgabe während LLM läuft) — v2, erfordert andere Ausgabe-Architektur
- **Multi-Provider LLM** (OpenAI, lokale Modelle) — explizit Out of Scope laut REQUIREMENTS.md
- **Profil-Import/-Export** — v2
- **Profil-Reihenfolge per Drag & Drop ändern** — v2 UX-Polish

</deferred>

---

*Phase: 05-llm-prompt-profiles*
*Context gathered: 2026-04-19*
