---
phase: 05-llm-prompt-profiles
verified: 2026-04-19T12:00:00Z
status: human_needed
score: 5/5 must-haves verified (automatable)
overrides_applied: 0
human_verification:
  - test: "Profil anlegen, umbenennen, Prompt bearbeiten und löschen in der laufenden App"
    expected: "Alle CRUD-Operationen funktionieren über ProfileEditorSheet; Profilliste in SettingsView aktualisiert sich"
    why_human: "UI-Fluss (Sheet öffnen, Felder ausfüllen, Buttons klicken) ist programmatisch nicht testbar ohne laufende App"
  - test: "Profil-Hotkey gleichzeitig mit ⌥⌘R gedrückt halten, dann sprechen und loslassen"
    expected: "Korrektes Profil wird aktiviert; Icon wechselt Rot → Blau → Lila → Grau bei LLM-aktiviertem Profil"
    why_human: "Simultanees Hotkey-Verhalten und Icon-State-Sequenz erfordert laufende App und echte Tastatur-Interaktion"
  - test: "Echter Groq API-Call mit gültigem Key"
    expected: "Verarbeiteter Text erscheint im aktiven Textfeld; Icon zeigt Lila-State während Verarbeitung"
    why_human: "Echter Netzwerk-Call gegen api.groq.com — erfordert gültigen API-Key und laufende App"
  - test: "Stille Fallback: LLM-Profil aktivieren ohne API-Key"
    expected: "Kein Alert, kein Crash — rohe Transkription wird ausgegeben (D-10)"
    why_human: "Verhaltens-Verifikation bei fehlendem Key erfordert laufende App"
  - test: "Keychain-Persistenz: API-Key eingeben, App beenden, App neu starten"
    expected: "API-Key ist nach Neustart noch vorhanden (kein Banner), Groq-Call funktioniert"
    why_human: "App-Neustart-Szenario ist programmatisch nicht simulierbar"
  - test: "Groq API-Key-Banner: erscheint ohne Key, verschwindet nach Eingabe"
    expected: "Roter Banner sichtbar wenn groqKeyMissing==true; verschwindet nach Eingabe im SecureField"
    why_human: "UI-Feedback und visueller Zustand des Banners erfordern laufende App"
---

# Phase 5: LLM + Prompt Profiles — Verifikationsbericht

**Phase-Ziel:** LLM + Prompt Profiles — User kann Prompt-Profile anlegen (Name, Hotkey, LLM-Toggle, System-Prompt), per Hotkey aktivieren und Transkript optional durch Groq (qwen3-32b) schicken; Groq API-Key wird einmalig eingegeben und im Keychain gespeichert.
**Verifiziert:** 2026-04-19T12:00:00Z
**Status:** human_needed
**Re-Verifikation:** Nein — initiale Verifikation

---

## Ziel-Erreichung

### Beobachtbare Wahrheiten (ROADMAP Success Criteria)

| # | Wahrheit | Status | Evidenz |
|---|----------|--------|---------|
| SC-1 | User kann Profil anlegen, umbenennen, Prompt bearbeiten und löschen | ? HUMAN | ProfileEditorSheet.swift implementiert alle CRUD-Callbacks; SettingsView hat `.sheet(item: $editingProfile)` — Funktionalität ist vollständig vorhanden, UI-Fluss muss manuell bestätigt werden |
| SC-2 | Jedes Profil hat eigenen Hotkey; Halten während Aufnahme aktiviert Profil | ? HUMAN | `setupProfileHotkeys()` mit `onKeyDown` implementiert, `D-02 Erster-gewinnt`-Guard vorhanden, `activeProfileID` in AppState — simultaner Hotkey muss in laufender App getestet werden |
| SC-3 | Profil ohne LLM → Raw-Transkription; mit LLM → Groq qwen3-32b | ? HUMAN | LLM-Routing vollständig in `onRecordingComplete` (AppDelegate Zeilen 119–156) — echter Groq-Call muss manuell bestätigt werden |
| SC-4 | Ein Profil als Standard markiert → verwendet wenn kein Hotkey gehalten | ? HUMAN | isDefault-Fallback implementiert (`profiles.first { $0.isDefault } ?? profiles.first`); onSetDefault-Callback mit Invarianz-Enforcement — muss in laufender App bestätigt werden |
| SC-5 | Groq API-Key einmal eingeben, Keychain, überlebt App-Neustart | ? HUMAN | `keychain["groqApiKey"]` via KeychainAccess — Keychain-Persistenz muss mit App-Neustart getestet werden |

**Score (automatable):** 5/5 Wahrheiten haben vollständige Code-Evidenz. Human-Tests ausstehend.

---

### Erforderliche Artefakte

| Artefakt | Erwartet | Status | Details |
|----------|---------|--------|---------|
| `SPRECHKRAFT/Models/PromptProfile.swift` | Codable & Defaults.Serializable & Identifiable Struct | VERIFIED | 6 Felder: id, name, prompt, isLLMEnabled, isThinkingEnabled, isDefault; `defaultProfile` mit "Rohe Transkription" |
| `SPRECHKRAFT/Extensions/Defaults+Keys.swift` | profiles Key für UserDefaults-Persistenz | VERIFIED | `static let profiles = Key<[PromptProfile]>("profiles", default: [PromptProfile.defaultProfile])` vorhanden |
| `SPRECHKRAFT/Extensions/KeyboardShortcuts+Names.swift` | Dynamische UUID-basierte Profil-Hotkey-Namen | VERIFIED | `static func profile(_ id: UUID) -> Self` mit `"profile-\(id.uuidString)"` |
| `SPRECHKRAFT/Services/GroqService.swift` | URLSession-basierter Groq-LLM-Client | VERIFIED | `actor GroqService` mit `process(transcript:profile:apiKey:)`, custom `encode(to:)` mit `encodeIfPresent` |
| `SPRECHKRAFT/AppState.swift` | activeProfileID + groqKeyMissing Properties | VERIFIED | Beide Properties vorhanden (Zeilen 87+93), kein API-Key gecacht (T-5-01/T-5-02) |
| `SPRECHKRAFT/AppDelegate.swift` | setupProfileHotkeys + LLM-Routing + Keychain-Init | VERIFIED | `setupProfileHotkeys()` mit `onKeyDown`, vollständiges LLM-Routing in `onRecordingComplete`, Keychain-Check in `applicationDidFinishLaunching` |
| `SPRECHKRAFT/ProfileEditorSheet.swift` | Sheet-Modal für Profil-CRUD | VERIFIED | 5 Sektionen (Name, Hotkey, KI, Prompt, Aktionen), D-06/D-09/D-13 implementiert |
| `SPRECHKRAFT/SettingsView.swift` | Section("Prompt-Profile") + Groq-Banner + Sheet | VERIFIED | Section "Prompt-Profile" mit Groq-Banner (groqKeyMissing), SecureField → Keychain onChange, Profilliste mit ⭐, `.sheet(item:)` |
| `SPRECHKRAFTTests/PromptProfileTests.swift` | 5 TDD-Tests für PROF-01/03/04 | VERIFIED | 5 `@Test`-Stubs vorhanden; laut SUMMARY alle grün nach Wave 1 |
| `SPRECHKRAFTTests/GroqServiceTests.swift` | 4 TDD-Tests für PROF-05 | VERIFIED | 4 `@Test`-Stubs vorhanden; laut SUMMARY alle grün nach Wave 1 |

---

### Key Link Verifikation

| Von | Nach | Via | Status | Details |
|-----|------|-----|--------|---------|
| `AppDelegate.swift` | `AppState.swift` | `appState?.activeProfileID = profile.id` | WIRED | Zeile 431: `self.appState?.activeProfileID = profile.id`; Zeile 107: Reset auf `nil` nach Nutzung |
| `AppDelegate.swift` | `GroqService.swift` | `GroqService.shared.process(transcript:profile:apiKey:)` | WIRED | Zeile 131–135: vollständiger Aufruf mit allen Parametern |
| `AppDelegate.swift` | Keychain | `keychain["groqApiKey"]` | WIRED | Zeile 126: Key unmittelbar vor Request gelesen (T-5-02); Zeile 37: `private let keychain` |
| `SettingsView.swift` | `AppState.swift` | `appState?.groqKeyMissing` | WIRED | Zeile 178: Banner-Bedingung; Zeile 209: `appState?.groqKeyMissing = newValue.isEmpty` |
| `SettingsView.swift` | `ProfileEditorSheet.swift` | `.sheet(item: $editingProfile)` | WIRED | Zeile 261–301: vollständige Sheet-Integration mit Callbacks |
| `ProfileEditorSheet.swift` | `Defaults+Keys.swift` | `Defaults[.profiles]` | WIRED | In `onSave`/`onDelete`/`onSetDefault`-Callbacks in SettingsView |
| `SettingsView.swift` | `AppDelegate.setupProfileHotkeys()` | `Notification.Name.refreshProfileHotkeys` | WIRED | Zeile 278: Post nach onSave; Zeile 290: Post nach onDelete; AppDelegate Zeile 63: Observer registriert |
| `GroqService.ChatRequest` | JSON-Encoding | `encodeIfPresent(reasoning_effort)` | WIRED | Zeile 49 in GroqService.swift — nil-Felder fehlen im JSON (Pitfall 5 geschlossen) |

---

### Datenfluss-Trace (Level 4)

| Artefakt | Datenvariable | Quelle | Echte Daten | Status |
|----------|--------------|--------|-------------|--------|
| `SettingsView` Profilliste | `Defaults[.profiles]` | `Defaults+Keys.swift` Key mit Default `[PromptProfile.defaultProfile]` | Ja — aus UserDefaults, persistiert via Codable | FLOWING |
| `AppDelegate.onRecordingComplete` | `activeProfile` | `Defaults[.profiles].first { $0.id == profileID }` | Ja — dreistufiger Fallback, kein leerer Default | FLOWING |
| `GroqService.process` | `apiKey` | `keychain["groqApiKey"]` — direkt vor Request gelesen | Ja — Keychain, nie gecacht | FLOWING |
| `SettingsView.groqApiKeyInput` | `SecureField` | `keychain["groqApiKey"] ?? ""` in `onAppear` | Ja — liest echten Keychain-Wert | FLOWING |

---

### Verhaltens-Spot-Checks

| Verhalten | Check | Ergebnis | Status |
|-----------|-------|----------|--------|
| PromptProfile Codable Round-Trip | Struct hat alle 6 Felder, keine custom encode nötig | Felder: id, name, prompt, isLLMEnabled, isThinkingEnabled, isDefault — alle primitiv, automatisch Codable | PASS |
| GroqService encodeIfPresent | `grep "encodeIfPresent" GroqService.swift` | 1 Treffer in `encode(to:)` | PASS |
| API-Key kein stored property | `grep "var apiKey\|let apiKey" GroqService.swift` | 0 Treffer (nur als Parameter) | PASS |
| HTTPS-Endpoint | `grep "https://api.groq.com" GroqService.swift` | 1 Treffer — literal, kein HTTP-Fallback | PASS |
| Kein API-Key-Logging | `grep "print.*apiKey" AppDelegate.swift GroqService.swift` | 0 Treffer | PASS |
| setupProfileHotkeys aufgerufen | `grep "setupProfileHotkeys()" AppDelegate.swift` | 3 Treffer: Deklaration (Zeile 415), Aufruf in `applicationDidFinishLaunching` (Zeile 55), Aufruf in `handleRefreshProfileHotkeys` (Zeile 406) | PASS |
| isDefault-Invariante Enforcement | `onSetDefault` in SettingsView | `map { copy.isDefault = (p.id == profile.id) }` — alle anderen auf false | PASS |
| Löschen-Schutz letztes Profil | `grep "isOnlyProfile"` in ProfileEditorSheet | `.disabled(isOnlyProfile)` am Löschen-Button | PASS |
| Laufende App nötig für echten Call | Groq API unter `api.groq.com` | Kein Server lokal laufend — Spot-Check nicht möglich | SKIP |

---

### Anforderungs-Coverage

| Anforderung | Plan | Beschreibung | Status | Evidenz |
|------------|------|-------------|--------|---------|
| PROF-01 | 05-01, 05-03, 05-06 | User kann mehrere benannte Prompt-Profile anlegen, bearbeiten und löschen | SATISFIED | PromptProfile struct, Defaults.Keys.profiles, ProfileEditorSheet CRUD, SettingsView Profilliste |
| PROF-02 | 05-03, 05-05, 05-06 | Jedes Profil enthält: Name, Prompt-Text, eigenen Aktivierungs-Hotkey | SATISFIED | KeyboardShortcuts.Name.profile(_:), KeyboardShortcuts.Recorder in ProfileEditorSheet, setupProfileHotkeys in AppDelegate |
| PROF-03 | 05-01, 05-03, 05-05, 05-06 | Jedes Profil hat einen LLM-Toggle | SATISFIED | `isLLMEnabled` in PromptProfile; Toggle in ProfileEditorSheet; LLM-Routing in onRecordingComplete |
| PROF-04 | 05-01, 05-03, 05-05, 05-06 | Ein Profil kann als Standard markiert werden | SATISFIED | `isDefault` Flag; onSetDefault Callback; dreistufiger Fallback in AppDelegate |
| PROF-05 | 05-02, 05-04, 05-05 | Groq API (qwen/qwen3-32b) verarbeitet Transkript mit Prompt | SATISFIED | GroqService actor mit process(transcript:profile:apiKey:); vollständig verdrahtet in AppDelegate |
| SET-01 | 05-02, 05-04, 05-05, 05-06 | Groq API-Key sicher im macOS Keychain gespeichert | SATISFIED | KeychainAccess 4.2.2 integriert; SecureField → onChange → `keychain["groqApiKey"]`; kein Key in AppState/UserDefaults |

---

### Anti-Pattern-Scan

Keine kritischen Anti-Pattern gefunden. Alle geprüften Dateien:
- Keine TODO/FIXME/PLACEHOLDER-Kommentare in Produktions-Code
- Kein `return null` / leere Implementations-Stubs
- Kein hardcodierter leerer Zustand für Profilliste (Defaults-Key hat echten Default-Wert)
- Kein API-Key im Klartext oder in Logs

---

### Manuelle Verifikation erforderlich

Die folgenden 6 Tests können nur in der laufenden App bestätigt werden:

#### 1. Profil-CRUD-UI (SC-1)

**Test:** App starten → Einstellungen → Section "Prompt-Profile" → Profil anlegen (Name eingeben, LLM-Toggle einschalten, Prompt schreiben, speichern) → Profil umbenennen → Profil löschen (vorher 2. Profil anlegen)
**Erwartet:** Alle Operationen funktionieren, Liste aktualisiert sich sofort, ⭐ erscheint beim Standard-Profil
**Warum manuell:** UI-Fluss, Sheet-Interaktion, visuelles Feedback

#### 2. Simultaner Hotkey (SC-2)

**Test:** Profil mit Hotkey (z.B. ⌥1) und LLM-Toggle anlegen → TextEdit öffnen → ⌥⌘R + ⌥1 gleichzeitig halten → sprechen → loslassen
**Erwartet:** Icon: Rot → Blau → Lila (pulsierend) → Grau; verarbeiteter Text erscheint
**Warum manuell:** Simultane Tastatureingabe und Icon-Sequenz sind programmatisch nicht testbar

#### 3. Echter Groq API-Call (SC-3)

**Test:** Gültigen Groq API-Key eingeben → LLM-Profil mit Übersetzungs-Prompt aktivieren → Aufnahme starten und deutschen Satz sprechen
**Erwartet:** Englisch übersetzter Text erscheint im aktiven Textfeld
**Warum manuell:** Echter Netzwerk-Call mit API-Key erforderlich

#### 4. Stiller Fallback (D-10)

**Test:** API-Key leeren → LLM-Profil-Hotkey halten → sprechen → loslassen
**Erwartet:** Icon: Rot → Blau → Lila → Grau; rohe Transkription erscheint — kein Alert, kein Crash
**Warum manuell:** Kombination aus fehlendem Key + UI-Verhalten

#### 5. Keychain-Persistenz (SC-5)

**Test:** Gültigen Groq API-Key eingeben → App beenden → App neu starten → Settings öffnen
**Erwartet:** API-Key noch vorhanden (SecureField maskiert ausgefüllt), kein roter Banner
**Warum manuell:** App-Neustart-Szenario nicht programmatisch testbar

#### 6. Groq API-Key-Banner (SET-01)

**Test:** Settings öffnen ohne Key → Banner "Groq API-Schlüssel fehlt" sichtbar → Key eingeben → Banner verschwindet → Key leeren → Banner erscheint erneut
**Erwartet:** Banner-Sichtbarkeit reagiert live auf `groqKeyMissing`-State
**Warum manuell:** Visuelle Reaktivität des Banners erfordert laufende App

---

## Zusammenfassung

**Alle 6 Phase-5-Requirements (PROF-01 bis PROF-05, SET-01) sind im Code vollständig implementiert und verdrahtet.**

Die Code-Verifikation (5 Ebenen: Existenz, Substanz, Verdrahtung, Datenfluss, Sicherheit) zeigt keine Lücken:
- TDD-Zyklus (RED → GREEN) abgeschlossen: 5+4 Unit-Tests laut SUMMARY grün
- End-to-End-Pipeline vollständig: Aufnahme → Transkription → Profil-Ermittlung → optional Groq → TextOutputService
- Sicherheits-Constraints eingehalten: API-Key nur im Keychain, nie in AppState, nie in Logs
- isDefault-Invariante in SettingsView korrekt enforced

**6 manuelle Checkpoints ausstehend** (Plan 05-07): simultaner Hotkey, echter Groq-Call, Icon-State-Sequenz, stiller Fallback, Keychain-Persistenz, Banner-Reaktivität.

---

_Verifiziert: 2026-04-19T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
