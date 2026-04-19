# Phase 5: LLM + Prompt Profiles — Research

**Researched:** 2026-04-19
**Domain:** Groq REST API, KeyboardShortcuts dynamic names, KeychainAccess, Defaults Codable arrays, Swift 6 strict concurrency
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Aktivierungsmechanismus: Profil-Hotkey + ⌥⌘R gleichzeitig halten — beide Tasten
  müssen während der Aufnahme gedrückt sein. Loslassen des Aufnahme-Hotkeys stoppt die Aufnahme
  und startet die Verarbeitungs-Pipeline (Transkription → optional Groq → TextOutputService).
- **D-02:** Konflikt bei mehreren Profil-Hotkeys: Erster gewinnt — das zuerst gedrückte Profil
  gilt für diese Aufnahme, spätere Hotkey-Inputs werden für diese Aufnahme ignoriert.
- **D-03:** Visuelles Feedback: Menü-Häkchen genügt — kein StatusBar-Title, kein Toast.
  Konsistent mit OutputMode-Häkchen (Phase 4 D-08). Aktives Profil im Menü markiert.
- **D-04:** Speicherung: `Defaults.Keys` mit Codable Array — `[PromptProfile]` als
  `Defaults.Serializable`-Struct in UserDefaults via Defaults-Library.
- **D-05:** Initialer Zustand beim ersten App-Start: ein vorgefertigtes Default-Profil
  namens „Rohe Transkription" (LLM disabled, kein Prompt, kein Hotkey).
- **D-06:** Das zuletzt verbleibende Profil ist nicht löschbar — Löschen-Button ausgegraut
  wenn Profilliste nur noch ein Element enthält.
- **D-07:** HTTP-Client: URLSession direkt — kein Third-Party-SDK.
- **D-08:** Modell: qwen/qwen3-32b — fest kodiert, kein Modell-Picker.
- **D-09:** Thinking-Mode: pro Profil konfigurierbar (Toggle in Profil-Bearbeitung).
  Ohne Thinking: `reasoning_effort: "none"` im Request (nicht `/no_think` Prefix — see research below).
- **D-10:** Fehlerbehandlung: stille Fallback zu Raw-Transkript — bei fehlendem Key,
  Timeout oder API-Fehler wird der unverarbeitete Transkriptions-Text ausgegeben.
- **D-11:** API-Key-Speicherung: macOS Keychain via KeychainAccess (SET-01).
- **D-12:** Profil-Verwaltung: Sheet-Modal pro Profil — `.sheet(item:)` mit NavigationStack + Form.
- **D-13:** Standard-Profil-Markierung: ⭐-Symbol (U+2B50) in der Liste.

### Claude's Discretion

- Exakte `PromptProfile`-Struct-Felder und Codable-Implementierung
- KeyboardShortcuts.Name-Generierung für dynamische Profile (UUID-basiert vs. Index-basiert)
- Timeout-Wert für Groq-URLSession-Request
- Reihenfolge der Felder im Sheet-Modal (festgelegt im UI-SPEC)
- Ob `llmProcessing`-State im Icon während Groq-Aufruf gesetzt wird (empfohlen: ja, laut FEED-01)

### Deferred Ideas (OUT OF SCOPE)

- Streaming-Output
- Multi-Provider LLM
- Profil-Import/-Export
- Profil-Reihenfolge per Drag & Drop
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PROF-01 | User kann mehrere benannte Prompt-Profile anlegen, bearbeiten und löschen | Defaults Codable Array Pattern; SwiftUI `.sheet(item:)` für CRUD |
| PROF-02 | Jedes Profil enthält: Name, Prompt-Text, eigenen Aktivierungs-Hotkey | `KeyboardShortcuts.Name` dynamisch zur Laufzeit erstellt via String-Initializer |
| PROF-03 | Jedes Profil hat einen LLM-Toggle (mit LLM-Verarbeitung vs. nur Transkription) | Toggle-Field in PromptProfile Struct; bedingte Groq-Verzweigung in AppDelegate |
| PROF-04 | Ein Profil kann als Standard markiert werden | `isDefault: Bool` Flag in Struct; NSMenu-Häkchen analog OutputMode-Pattern |
| PROF-05 | Groq API (qwen/qwen3-32b) verarbeitet Transkript mit Prompt des aktiven Profils | URLSession POST an `https://api.groq.com/openai/v1/chat/completions`; `reasoning_effort: "none"` für non-Thinking |
| SET-01 | Groq API-Key wird sicher im macOS Keychain gespeichert | KeychainAccess Subscript-API `keychain["groqApiKey"]` |
</phase_requirements>

---

## Summary

Phase 5 fügt dem bestehenden Aufnahme-Pipeline-Stack eine LLM-Nachverarbeitungsschicht hinzu. Die drei Hauptkomponenten sind: (1) ein Profil-Datenschema (`PromptProfile`), das in UserDefaults via Defaults persistiert wird, (2) ein `GroqService`, der per URLSession einen single-shot POST an Groqs OpenAI-kompatiblen Endpoint schickt, und (3) ein dynamisches Hotkey-Registrierungsmuster, das `KeyboardShortcuts.Name`-Instanzen zur Laufzeit (nicht compile-time) erzeugt.

Das Schlüsselproblem der Phase ist die simultane Hotkey-Erkennung: Der Nutzer hält den Profil-Hotkey **während** der Aufnahme. Da `KeyboardShortcuts.onKeyDown` unabhängig vom aufnahme-State feuert, genügt ein einfaches Flag-Muster: Beim `onKeyDown`-Event eines Profil-Hotkeys während `.recording`-State wird `appState.activeProfileID` gesetzt (erster gewinnt via Guard). Der bestehende `onRecordingComplete`-Callback liest dieses Flag und routet entsprechend.

Die Groq-API-Integration ist straightforward: OpenAI-kompatibler Endpoint, JSON POST, `reasoning_effort: "none"` für non-Thinking-Mode (bevorzugt gegenüber dem unstabilen `/no_think` Präfix), `reasoning_effort: "default"` (oder weglassen) für Thinking. KeychainAccess bietet eine einfache Subscript-API ohne SPM-Komplexität.

**Primary recommendation:** `PromptProfile` als `Codable & Defaults.Serializable & Identifiable`-Struct mit UUID-ID; dynamische `KeyboardShortcuts.Name`-Instanzen durch String-Konkatenation der UUID; `GroqService` als `@MainActor`-Klasse (oder freie async-Funktion) die `URLSession.shared` nutzt; 30s Timeout.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Profil-Persistenz | App State (UserDefaults) | — | Defaults-Library ist etabliertes Pattern für leichtgewichtige Settings |
| Groq API-Call | AppDelegate (Orchestration) | GroqService (isoliert) | AppDelegate hält onRecordingComplete, routet an GroqService |
| Profil-Hotkey-Registrierung | AppDelegate (Setup) | — | AppDelegate verwaltet alle Hotkeys zentralisiert |
| Profil-Hotkey-Erkennung während Aufnahme | AppDelegate (onKeyDown Handler) | AppState (activeProfileID Flag) | Flag-Pattern analog zu bestehenden State-Übergängen |
| API-Key-Verwaltung | Keychain (KeychainAccess) | SettingsView (Eingabe) | Sicherheit: nie im AppState oder UserDefaults |
| Settings-UI (Profil-CRUD) | SettingsView + ProfileEditorSheet | — | Bestehendes SettingsView-Erweiterungsmuster |
| Icon-Zustand während LLM | AppState.recordingState | AppDelegate (setzt/resettet) | `.llmProcessing` bereits in RecordingState definiert und verdrahtet |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `KeyboardShortcuts` (sindresorhus) | latest (bereits im Projekt) | Dynamische Profil-Hotkey-Namen | Bereits installiert, `Name`-Initializer akzeptiert String zur Laufzeit |
| `KeychainAccess` (kishikawakatsuki) | latest (bereits im Projekt) | Groq API-Key im Keychain | Bereits installiert, Subscript-API für einfachen get/set |
| `Defaults` (sindresorhus) | latest (bereits im Projekt) | `[PromptProfile]` in UserDefaults | Bereits installiert, Codable-Serializable-Pattern dokumentiert |
| `URLSession` (Foundation) | built-in | Groq REST API Call | Kein Third-Party SDK (D-07), async/await in Swift 6 native |

Alle vier Abhängigkeiten sind bereits im Projekt vorhanden — keine neuen SPM-Packages erforderlich.

### Version Verification

[VERIFIED: project codebase — alle drei SPM-Libraries bereits in Package.resolved / Project-Referenzen]

---

## Architecture Patterns

### System Architecture Diagram

```
User hält Profil-Hotkey (z.B. ⌥1)
        ↓
KeyboardShortcuts.onKeyDown(for: profileName)
        ↓ (nur wenn recordingState == .recording)
AppState.activeProfileID = profile.id   ← Erster gewinnt (D-02)
        |
        | (User lässt ⌥⌘R los)
        ↓
AudioController.onRecordingComplete([Float], sampleRate)
        ↓
TranscriptionService.transcribeWithResampling(...)
        ↓ text: String
AppDelegate.onRecordingComplete handler:
    activeProfile = profiles.first { $0.id == activeProfileID }
        ├── LLM disabled → TextOutputService.output(text)
        └── LLM enabled  → appState.recordingState = .llmProcessing
                                ↓
                           GroqService.process(text, profile)
                           URLSession POST → api.groq.com
                                ↓ result: String
                           TextOutputService.output(result)
                           appState.resetToIdle()
```

### Recommended Project Structure

```
VoiceScribe/
├── Models/
│   └── PromptProfile.swift          # Codable & Defaults.Serializable & Identifiable
├── Services/
│   └── GroqService.swift            # URLSession-basierter LLM-Client
├── Extensions/
│   ├── Defaults+Keys.swift          # + profiles Key [PromptProfile]
│   └── KeyboardShortcuts+Names.swift # + dynamicProfileName(for:) Hilfsfunktion
├── Views/
│   ├── SettingsView.swift           # + Section("Prompt-Profile")
│   └── ProfileEditorSheet.swift     # Sheet-Modal für CRUD (D-12)
└── AppDelegate.swift                # + setupProfileHotkeys(), LLM-Routing in onRecordingComplete
```

### Pattern 1: Dynamische KeyboardShortcuts.Name zur Laufzeit

**Was:** `KeyboardShortcuts.Name` wird NICHT als static Extension-Property definiert, sondern zur Laufzeit mit einem String-Identifier instanziiert.

**Offiziell dokumentiert:** Die Library sagt explizit: "Normally, you would statically register the keyboard shortcuts upfront in `extension KeyboardShortcuts.Name {}`. However, **this is not a requirement.**" und "You can create `KeyboardShortcuts.Name`'s dynamically and store them yourself."

```swift
// Source: https://github.com/sindresorhus/KeyboardShortcuts/blob/main/readme.md
// + verified via WebFetch 2026-04-19

extension KeyboardShortcuts.Name {
    /// Erzeugt einen stabilen Namen für ein Profil anhand seiner UUID.
    /// Der String "profile-\(id)" ist der Persistence-Key in UserDefaults.
    static func profile(_ id: UUID) -> Self {
        Self("profile-\(id.uuidString)")
    }
}

// Registrierung in AppDelegate.setupProfileHotkeys():
for profile in Defaults[.profiles] {
    let name = KeyboardShortcuts.Name.profile(profile.id)
    KeyboardShortcuts.onKeyDown(for: name) { [weak self] in
        Task { @MainActor [weak self] in
            guard let self,
                  self.appState?.recordingState == .recording,
                  self.appState?.activeProfileID == nil   // Erster gewinnt (D-02)
            else { return }
            self.appState?.activeProfileID = profile.id
        }
    }
}
```

**Wichtig:** `onKeyDown` statt `onKeyUp` für Profil-Hotkeys — der Nutzer hält den Hotkey während der Aufnahme. `onKeyUp` würde erst beim Loslassen feuern (zu spät, nach stopRecordingWithCue wenn ⌥⌘R zuerst losgelassen wird).

**Neuregistrierung nach Profil-Änderung:** Wenn Profile hinzugefügt/gelöscht/geändert werden, muss `setupProfileHotkeys()` erneut aufgerufen werden. Vorher alle alten Handler deregistrieren via `KeyboardShortcuts.disable(for:)` oder die Handler mit einer Version-Variable schützen.

[VERIFIED: github.com/sindresorhus/KeyboardShortcuts readme.md — explizit dokumentiertes Feature]

### Pattern 2: PromptProfile Struct als Defaults.Serializable

```swift
// Source: https://github.com/sindresorhus/defaults/blob/main/readme.md (verified via ctx7)
// + Codebase Pattern: Defaults+Keys.swift, OutputMode: Codable & Defaults.Serializable

struct PromptProfile: Codable, Defaults.Serializable, Identifiable {
    var id: UUID
    var name: String
    var prompt: String            // Leer wenn LLM disabled
    var isLLMEnabled: Bool
    var isThinkingEnabled: Bool   // D-09: pro Profil konfigurierbar
    var isDefault: Bool

    // Kein Hotkey-Feld in der Struct — Hotkey wird separat in
    // KeyboardShortcuts UserDefaults Storage unter "profile-\(id.uuidString)" gespeichert.
    // KeychainAccess und KeyboardShortcuts verwalten ihren eigenen Persistent Storage.
}

extension Defaults.Keys {
    // [PromptProfile] ist Codable → Defaults.Serializable via automatischer Conformance
    static let profiles = Key<[PromptProfile]>(
        "profiles",
        default: [PromptProfile.defaultProfile]
    )
    // activeProfileID: nil = kein Profil-Hotkey gedrückt (Standard-Profil greift)
    static let activeProfileID = Key<UUID?>("activeProfileID", default: nil)
}
```

**Hinweis zu Hotkeys:** `KeyboardShortcuts` speichert Hotkey-Bindings selbst in UserDefaults unter dem Name-String als Key. Der Hotkey ist NICHT in `PromptProfile` gespeichert — er wird automatisch durch `KeyboardShortcuts.Name.profile(id)` persistiert. Damit muss bei Profil-Löschung auch `KeyboardShortcuts.reset(for: .profile(deletedID))` aufgerufen werden.

[VERIFIED: Defaults docs via ctx7 /sindresorhus/defaults — Codable+Serializable Pattern]
[VERIFIED: KeyboardShortcuts behavior — Shortcuts werden intern in UserDefaults gespeichert]

### Pattern 3: Groq API via URLSession

**Endpoint:** `https://api.groq.com/openai/v1/chat/completions`
**Methode:** POST
**Headers:** `Content-Type: application/json`, `Authorization: Bearer <key>`

```swift
// Source: console.groq.com/docs/api-reference (verified via WebFetch + WebSearch 2026-04-19)

actor GroqService {
    static let shared = GroqService()
    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private let timeoutSeconds: TimeInterval = 30

    struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let top_p: Double
        let reasoning_effort: String?   // "none" = non-thinking, nil = thinking default

        struct Message: Encodable {
            let role: String      // "system" oder "user"
            let content: String
        }
    }

    struct ChatResponse: Decodable {
        let choices: [Choice]
        struct Choice: Decodable {
            let message: Message
            struct Message: Decodable {
                let content: String
            }
        }
    }

    func process(transcript: String, profile: PromptProfile, apiKey: String) async throws -> String {
        var messages: [ChatRequest.Message] = []
        if !profile.prompt.isEmpty {
            messages.append(.init(role: "system", content: profile.prompt))
        }
        messages.append(.init(role: "user", content: transcript))

        // D-09: non-thinking via reasoning_effort: "none" (Groq-empfohlener Weg)
        // /no_think Prefix ist instabil (HuggingFace discussion #16 — single-turn OK aber unsicher)
        let request = ChatRequest(
            model: "qwen/qwen3-32b",
            messages: messages,
            temperature: profile.isThinkingEnabled ? 0.6 : 0.7,
            top_p: profile.isThinkingEnabled ? 0.95 : 0.8,
            reasoning_effort: profile.isThinkingEnabled ? nil : "none"
        )

        var urlRequest = URLRequest(url: endpoint, timeoutInterval: timeoutSeconds)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = response.choices.first?.message.content else {
            throw GroqError.emptyResponse
        }
        return content
    }

    enum GroqError: Error {
        case emptyResponse
    }
}
```

[VERIFIED: console.groq.com/docs/api-reference via WebFetch 2026-04-19]
[VERIFIED: reasoning_effort: "none" für non-thinking via console.groq.com/docs/model/qwen/qwen3-32b + WebSearch 2026-04-19]

### Pattern 4: KeychainAccess Subscript-API

```swift
// Source: https://github.com/kishikawakatsumi/KeychainAccess (verified via WebFetch 2026-04-19)
import KeychainAccess

// Initialisierung mit Bundle Identifier als Service-Name
private let keychain = Keychain(service: Bundle.main.bundleIdentifier ?? "com.voicescribe")

// Lesen (nil wenn nicht gesetzt)
let apiKey: String? = keychain["groqApiKey"]

// Schreiben
keychain["groqApiKey"] = enteredKey    // nil = löschen

// Fehlersicheres Schreiben mit throws
do {
    try keychain.set(enteredKey, key: "groqApiKey")
} catch {
    // Keychain-Fehler loggen; Fallback: kein Key verfügbar (D-10 greift)
}
```

**AppState-Integration:** `AppState.groqKeyMissing: Bool` wird in `applicationDidFinishLaunching` gesetzt:
```swift
appState.groqKeyMissing = (keychain["groqApiKey"] == nil)
```

[VERIFIED: github.com/kishikawakatsuki/KeychainAccess README via WebFetch 2026-04-19]

### Pattern 5: AppDelegate-Integration (D-10 stille Fallback)

```swift
// Integration in bestehenden onRecordingComplete-Callback (AppDelegate.swift)
// Erweiterung von Phase 3 / Phase 4 Pattern

audioController?.onRecordingComplete = { [weak self] samples, sampleRate in
    guard let self else { return }
    Task {
        let rawText = await self.transcriptionService.transcribeWithResampling(samples, sampleRate: sampleRate)
        await MainActor.run {
            guard let text = rawText else {
                self.appState?.resetToIdle()
                self.updateIcon()
                return
            }

            // Aktives Profil ermitteln (D-02: Profil-Hotkey → activeProfileID)
            let profileID = self.appState?.activeProfileID
            self.appState?.activeProfileID = nil   // Reset für nächste Aufnahme

            let profiles = Defaults[.profiles]
            let activeProfile = profiles.first { $0.id == profileID }
                ?? profiles.first { $0.isDefault }
                ?? profiles.first   // Fallback: erstes Profil

            let mode = Defaults[.outputMode]
            let axPermitted = !(self.appState?.axPermissionDenied ?? true)

            if activeProfile.isLLMEnabled {
                // LLM-Pfad: .llmProcessing State setzen (FEED-01)
                self.appState?.recordingState = .llmProcessing
                self.updateIcon()

                Task {
                    // D-10: stille Fallback bei Fehler
                    let apiKey = self.keychain["groqApiKey"]
                    let outputText: String
                    if let key = apiKey, !key.isEmpty {
                        do {
                            outputText = try await GroqService.shared.process(
                                transcript: text, profile: activeProfile, apiKey: key
                            )
                        } catch {
                            outputText = text   // Stille Fallback (D-10)
                        }
                    } else {
                        outputText = text   // Kein Key → Fallback (D-10)
                    }
                    await MainActor.run {
                        TextOutputService.shared.output(outputText, mode: mode, axPermitted: axPermitted)
                        self.appState?.resetToIdle()
                        self.updateIcon()
                    }
                }
            } else {
                // Direkt-Pfad: kein LLM
                TextOutputService.shared.output(text, mode: mode, axPermitted: axPermitted)
                self.appState?.resetToIdle()
                self.updateIcon()
            }
        }
    }
}
```

[ASSUMED: Die genaue Methode zum Deregistrieren alter Hotkey-Handler ist nicht in der offiziellen Dokumentation beschrieben — `KeyboardShortcuts.disable(for:)` und `KeyboardShortcuts.reset(for:)` sind plausibel aus der API-Struktur, müssen im Xcode verifiziert werden]

### Anti-Patterns to Avoid

- **`/no_think` als Prompt-Präfix:** Laut HuggingFace-Diskussion #16 instabil bei qwen3-32b — die Soft-Switch-Kontrolle kann in Folge-Turns ThinkIng wieder aktivieren. Stattdessen `reasoning_effort: "none"` verwenden (Groq-empfohlener Weg, API-First-Class-Unterstützung).
- **Hotkey-ID per Index statt UUID:** Wenn Profile umsortiert werden (Phase 6 Drag & Drop), würden Index-basierte Namen auf falsche Profile zeigen. UUID-basierte Namen sind stabil.
- **API-Key in AppState oder UserDefaults:** Niemals — immer Keychain. AppState hält nur `groqKeyMissing: Bool`.
- **GroqService auf Main Thread blockieren:** URLSession async/await immer in einem `Task {}` wrappen; Ergebnis via `await MainActor.run {}` zurück.
- **Profile ohne isDefault Guard:** Immer sicherstellen, dass genau ein Profil `isDefault == true` hat. Beim Markieren als Standard: alle anderen auf false setzen.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Keychain Storage | Eigene Security-Framework-Wrapper | KeychainAccess Subscript-API | Security-Framework C-API ist fehleranfällig; KeychainAccess ist Context7-verifiziert und bereits installiert |
| UserDefaults Codable | Eigene Serialisierung mit `PropertyListEncoder` | `Defaults` Library | Bereits installiert; type-safe; Observability via `@Default` |
| HTTP Client | Eigene Retry-Logik, Header-Management | URLSession mit `timeoutInterval` | Für single-shot Request genügt URLSession; kein SDK nötig (D-07) |
| Hotkey-Persistence | Eigene UserDefaults-Speicherung für Hotkeys | `KeyboardShortcuts.Name` intern | Library speichert Bindings selbst; Recorder-UI synchronisiert automatisch |

**Key insight:** Alle benötigten Libraries sind bereits installiert. Phase 5 fügt keine neuen SPM-Dependencies hinzu.

---

## Runtime State Inventory

> Phase 5 ist kein Rename/Refactor — dieser Abschnitt ist nicht zutreffend.
> Kein existierender Runtime-State muss migriert werden.

Einzige relevante Initialisierung: Beim ersten App-Start nach Phase-5-Deployment existiert
noch kein `profiles`-Key in UserDefaults → `Defaults.Key` Default-Wert greift automatisch
(D-05: ein vorgefertigtes Profil „Rohe Transkription"). Kein manueller Migration-Code nötig.

---

## Common Pitfalls

### Pitfall 1: onKeyDown vs. onKeyUp für Profil-Hotkeys

**What goes wrong:** Bei Verwendung von `onKeyUp` für Profil-Hotkeys feuert der Handler erst beim Loslassen der Taste. Wenn der Nutzer ⌥⌘R (Aufnahme-Hotkey, `onKeyUp`) loslässt, um die Aufnahme zu stoppen, und gleichzeitig den Profil-Hotkey hält, kann die Reihenfolge nicht garantiert werden.

**Why it happens:** `onKeyUp` für beide Hotkeys → Race Condition zwischen Aufnahme-Stopp und Profil-Selektion.

**How to avoid:** Profil-Hotkeys mit `onKeyDown` registrieren (feuert beim Drücken, während Aufnahme noch läuft). Der Aufnahme-Hotkey bleibt bei `onKeyUp`.

**Warning signs:** Profil wird gelegentlich nicht erkannt obwohl Hotkey gedrückt war.

### Pitfall 2: Hotkey-Handler nicht deregistriert bei Profil-Änderung

**What goes wrong:** Wird ein Profil gelöscht und ein neues mit anderer UUID erstellt, bleiben die alten Handler für die gelöschte UUID in KeyboardShortcuts registriert. Das feuert nie, verbraucht aber Ressourcen und kann bei erneutem Aufruf von `setupProfileHotkeys()` zu doppelten Registrierungen führen.

**Why it happens:** `KeyboardShortcuts.onKeyDown` überschreibt keinen vorherigen Handler — es werden akkumuliert.

**How to avoid:** Vor `setupProfileHotkeys()` alle bisherigen Profil-Handler deregistrieren. Pattern: Alle alten Profile-UUIDs tracken, `KeyboardShortcuts.reset(for:)` aufrufen, dann neu registrieren.

**Warning signs:** Mehrfache Aktivierungen eines Profil-Hotkeys bei einer Aufnahme.

### Pitfall 3: isDefault-Invariante gebrochen

**What goes wrong:** Mehrere Profile haben `isDefault == true`, oder kein Profil hat `isDefault == true`.

**Why it happens:** Beim Anlegen eines neuen Profils vergessen, alle anderen auf `isDefault = false` zu setzen; beim Löschen des Default-Profils kein neues als Default markiert.

**How to avoid:** Beim Setzen von `isDefault = true` auf einem Profil immer alle anderen auf false setzen. Beim Löschen: wenn das gelöschte Profil `isDefault` war, erstes verbleibendes Profil als Default markieren.

**Warning signs:** Crash/Force-Unwrap wenn `.first { $0.isDefault }` nil zurückgibt.

### Pitfall 4: Groq API Key im SettingsView unsauber gespeichert

**What goes wrong:** API-Key-Eingabe wird via `@State` in SettingsView gehalten und erst beim Schließen persistiert — bei App-Crash geht der Key verloren.

**Why it happens:** Entwickler behandelt SecureField wie normales TextField mit @Default binding.

**How to avoid:** `SecureField` bindet an eine `@State`-Hilfsvariable. `onChange(of:)` oder `onSubmit` triggert sofort `keychain["groqApiKey"] = newValue` und `appState.groqKeyMissing = false`.

**Warning signs:** Key fehlt nach App-Neustart obwohl eingegeben.

### Pitfall 5: `reasoning_effort` nicht als Optional behandeln

**What goes wrong:** JSON-Serialisierung sendet `"reasoning_effort": null` auch für Thinking-Mode, was Groq-API möglicherweise anders behandelt als Feld-Fehlen.

**Why it happens:** Swift `nil` wird zu `null` in JSON wenn nicht als `Optional` im Encoder ausgeschlossen.

**How to avoid:** `ChatRequest` mit `reasoning_effort: String?` und `JSONEncoder` mit Default-Encoding (nil → Feld fehlt im JSON wenn property ist in einem `encode(to:)` mit `encodeIfPresent` implementiert). Alternativ: separaten Struct für non-thinking vs. thinking Request definieren.

**Warning signs:** API-Fehler 400 bei Thinking-Mode-Requests.

---

## Code Examples

### PromptProfile — vollständige Struct-Definition

```swift
// Empfehlung (Claude's Discretion)
import Foundation
import Defaults

struct PromptProfile: Codable, Defaults.Serializable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var prompt: String = ""
    var isLLMEnabled: Bool = false
    var isThinkingEnabled: Bool = false
    var isDefault: Bool = false

    static var defaultProfile: PromptProfile {
        PromptProfile(
            id: UUID(),
            name: "Rohe Transkription",
            prompt: "",
            isLLMEnabled: false,
            isThinkingEnabled: false,
            isDefault: true
        )
    }
}
```

### Groq Request JSON (Beispiel für non-thinking mode)

```json
{
    "model": "qwen/qwen3-32b",
    "messages": [
        {"role": "system", "content": "Korrigiere Grammatikfehler im folgenden Text."},
        {"role": "user", "content": "Das ist der transkribierte Text vom Nutzer."}
    ],
    "temperature": 0.7,
    "top_p": 0.8,
    "reasoning_effort": "none"
}
```

### Groq Request JSON (Beispiel für thinking mode)

```json
{
    "model": "qwen/qwen3-32b",
    "messages": [
        {"role": "system", "content": "Analysiere und strukturiere den folgenden Text."},
        {"role": "user", "content": "Das ist der transkribierte Text vom Nutzer."}
    ],
    "temperature": 0.6,
    "top_p": 0.95
}
```

### Swift 6 Strict Concurrency — Task-Struktur

```swift
// Pattern: GroqService als actor (thread-safe, kein @MainActor-Erfordernis)
// Ergebnis immer via await MainActor.run {} in AppDelegate zurück

Task {
    let result: String
    do {
        result = try await GroqService.shared.process(...)
    } catch {
        result = fallbackText  // D-10
    }
    await MainActor.run {
        // UI updates, TextOutputService, resetToIdle()
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `/no_think` Prefix in User-Prompt | `reasoning_effort: "none"` API-Parameter | Groq Qwen3 Release 2025 | Zuverlässigere Non-Thinking-Steuerung; kein Prompt-Pollution |
| Statische KeyboardShortcuts.Name Extensions | Dynamische Laufzeit-Instanziierung via String | KeyboardShortcuts v2+ | Ermöglicht benutzer-definierte Profile ohne Compile-Zeit-Wissen |

**Deprecated/outdated:**
- `/no_think` Prefix: Funktioniert, aber instabil bei Multi-Turn (laut HuggingFace Qwen3-32B discussion #16). Für VoiceScribe (Single-Turn) wäre es technisch OK, aber `reasoning_effort: "none"` ist die von Groq dokumentierte First-Class-Lösung.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `KeyboardShortcuts.onKeyDown` vs. `onKeyUp` — Library hat beide Methoden | Pattern 1 | Falls nur `onKeyUp` verfügbar: Hotkey-Detection-Timing muss anders gelöst werden |
| A2 | Deregistrierung alter Profil-Hotkeys via `KeyboardShortcuts.reset(for:)` oder `disable(for:)` | Pitfall 2 | Falls API anders heißt: in Xcode-Autocomplete prüfen |
| A3 | `GroqService as actor` — Swift 6 akzeptiert actor ohne @MainActor für URLSession calls | Pattern 3 | Falls Compiler-Fehler: struct + nonisolated async func als Alternative |
| A4 | `JSONEncoder` lässt `nil`-Optional-Felder aus dem JSON-Output weg (Standard-Swift-Verhalten) | Pitfall 5 | Falls nicht: custom `encode(to:)` implementieren |

---

## Open Questions (RESOLVED)

1. **Hotkey-Handler Deregistrierung API** — RESOLVED: Fallback-Strategie in Plan 05-05 Task 2 implementiert. Handler durch erneutes `onKeyDown`-Registrieren überschreiben (letzter Handler gewinnt). `KeyboardShortcuts.reset(for:)` löscht die gespeicherte Binding — daher nur zur Bereinigung bei Profil-Löschung verwenden.
   - What we know: KeyboardShortcuts speichert Handler intern; neue Aufrufe von `onKeyDown` für dieselbe Name überschreiben oder akkumulieren
   - What's unclear: Exakte API-Methode zum Deregistrieren eines Handlers ohne den Shortcut zu resetten (Shortcut-Binding soll erhalten bleiben, nur der Event-Handler wird neu gesetzt)
   - Recommendation: In Xcode KeyboardShortcuts-Quellcode prüfen: `disable(for:)`, `removeEventHandlers(for:)` o.ä. Falls nicht vorhanden: Handler durch erneutes `onKeyDown`-Registration überschreiben (funktioniert wenn Library letzten Handler gewinnen lässt)

2. **Groq API Timeout-Wert** — RESOLVED: 30s als Claude's Discretion (Plan 05-04 Task 1). Groq-Inferenz typischerweise < 3s für kurze Transkripte; 30s gibt ausreichend Puffer bei Lastspitzen.
   - What we know: 30s ist eine vernünftige Heuristik für LLM-Calls; Groq ist bekannt für sehr schnelle Inferenz (~400 tokens/s)
   - What's unclear: Maximale Latenz bei hoher Last; ob 30s zu lang/kurz ist
   - Recommendation: 30s als initialen Timeout (D-09 Claude's Discretion). Bei kurzen Transkripten ist Groq typischerweise < 3s.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode / Swift 6 | Build | ✓ (bereits Phasen 1-4 gebaut) | swift-6.1.2-RELEASE | — |
| KeyboardShortcuts SPM | PROF-02 | ✓ (bereits installiert) | latest | — |
| KeychainAccess SPM | SET-01 | ✓ (bereits installiert) | latest | — |
| Defaults SPM | PROF-01, D-04 | ✓ (bereits installiert) | latest | — |
| Groq API (Netzwerk) | PROF-05 | ✓ (Internet vorhanden) | — | D-10: stille Fallback zu Raw-Text |
| Groq API Key | PROF-05 | ✗ (noch nicht konfiguriert) | — | D-10: stille Fallback; Banner in Settings |

**Missing dependencies mit Fallback:**
- Groq API Key: Nicht vorhanden bis Nutzer eingibt. D-10 (stille Fallback) greift. `AppState.groqKeyMissing = true` zeigt Banner in SettingsView.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (bereits in Phases 1-4 verwendet) |
| Config file | Xcode Test Target `VoiceScribeTests` |
| Quick run command | `xcodebuild test -scheme VoiceScribe -destination 'platform=macOS' -only-testing:VoiceScribeTests/PromptProfileTests` |
| Full suite command | `xcodebuild test -scheme VoiceScribe -destination 'platform=macOS'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PROF-01 | PromptProfile CRUD in UserDefaults | unit | `...PromptProfileTests` | ❌ Wave 0 |
| PROF-02 | KeyboardShortcuts.Name dynamisch via UUID | unit | `...HotkeyTests` (bestehend erweitern) | ✅ erweitern |
| PROF-03 | LLM-Toggle Routing-Logik | unit | `...PromptProfileTests` | ❌ Wave 0 |
| PROF-04 | isDefault-Invariante (genau 1 Default) | unit | `...PromptProfileTests` | ❌ Wave 0 |
| PROF-05 | GroqService mit Mock URLSession | unit | `...GroqServiceTests` | ❌ Wave 0 |
| SET-01 | Keychain store/retrieve round-trip | integration | `...GroqServiceTests` | ❌ Wave 0 |

**Manual-only (keine Automatisierung möglich):**
- Simultaner Hotkey (Profil-Hotkey + ⌥⌘R) — erfordert echte Tastatur-Events
- Icon-Farbe während `.llmProcessing` — visuell
- SettingsView Sheet-Modal Flow — UI-Interaktion
- Echter Groq API-Call mit echtem Key — Netzwerk

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme VoiceScribe -destination 'platform=macOS' -only-testing:VoiceScribeTests/PromptProfileTests -only-testing:VoiceScribeTests/GroqServiceTests`
- **Per wave merge:** Full suite
- **Phase gate:** Full suite green vor `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `VoiceScribeTests/PromptProfileTests.swift` — PROF-01, PROF-03, PROF-04, Defaults round-trip
- [ ] `VoiceScribeTests/GroqServiceTests.swift` — PROF-05, SET-01, Mock URLSession für Groq-Response

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | nein | — |
| V3 Session Management | nein | — |
| V4 Access Control | nein | — |
| V5 Input Validation | ja | Groq API-Key: Leerstring-Guard vor Request; Prompt-Text: keine Sanitisierung nötig (nur an eigene API gesendet) |
| V6 Cryptography | ja | KeychainAccess (System Keychain) — nie Hand-Roll |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| API-Key in UserDefaults/Logs | Information Disclosure | Keychain (KeychainAccess) — nie in Defaults oder NSLog |
| API-Key im Memory-Dump sichtbar | Information Disclosure | Key nur kurz vor Request aus Keychain lesen; nicht in AppState cachen |
| Prompt Injection via Transkript | Tampering | Low risk — User sendet eigenen Transkript an eigene API; kein Trust-Boundary |
| Netzwerk-Interception des API-Keys | Spoofing | HTTPS (URLSession default) — kein HTTP-Fallback |

---

## Sources

### Primary (HIGH confidence)

- `/sindresorhus/keyboardshortcuts` (Context7) — dynamische Name-Instanziierung explizit dokumentiert
- `github.com/sindresorhus/KeyboardShortcuts/blob/main/readme.md` (WebFetch 2026-04-19) — "this is not a requirement" + "You can create Name's dynamically"
- `console.groq.com/docs/api-reference` (WebFetch 2026-04-19) — Endpoint URL, Headers, Request/Response-Struktur
- `console.groq.com/docs/model/qwen/qwen3-32b` (WebFetch + WebSearch 2026-04-19) — `reasoning_effort: "none"` für non-thinking mode; Temperatur-Empfehlungen
- `/sindresorhus/defaults` (Context7) — `Codable & Defaults.Serializable`-Pattern; `[User]` Array-Key-Beispiel
- `github.com/kishikawakatsumi/KeychainAccess` (WebFetch 2026-04-19) — Subscript-API, Service-Initialisierung
- Projekt-Codebase (VoiceScribe) — AppState.swift, Defaults+Keys.swift, KeyboardShortcuts+Names.swift, AppDelegate.swift, SettingsView.swift

### Secondary (MEDIUM confidence)

- HuggingFace qwen3-32b discussion #16 (WebSearch 2026-04-19) — `/no_think` Instabilität in Multi-Turn; für Single-Turn technisch OK aber reasoning_effort bevorzugt

### Tertiary (LOW confidence)

- Groq Community Base-URL-Thread — bestätigt `https://api.groq.com/openai/v1` als kanonische Base-URL

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — alle Libraries bereits installiert und in vorherigen Phasen verwendet
- Groq API: HIGH — offizielle Docs verifiziert; reasoning_effort Parameter bestätigt
- KeyboardShortcuts dynamic names: HIGH — explizit in README dokumentiert
- KeychainAccess API: HIGH — README verifiziert
- Defaults Codable Array: HIGH — Context7 mit Beispiel-Code verifiziert
- Pitfalls: MEDIUM — teils aus Erfahrungsmustern; Hotkey-Deregistrierung LOW (A2 Assumption)

**Research date:** 2026-04-19
**Valid until:** 2026-05-19 (stabile Libraries; Groq-API-Änderungen möglich aber unwahrscheinlich)
