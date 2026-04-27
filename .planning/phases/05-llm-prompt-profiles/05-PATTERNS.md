# Phase 5: LLM + Prompt Profiles - Pattern Map

**Mapped:** 2026-04-19
**Files analyzed:** 10 (6 neu, 4 modifizieren)
**Analogs found:** 10 / 10

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `SPRECHKRAFT/Models/PromptProfile.swift` | model | CRUD | `SPRECHKRAFT/Extensions/Defaults+Keys.swift` (OutputMode-Enum) | role-match |
| `SPRECHKRAFT/Services/GroqService.swift` | service | request-response | `SPRECHKRAFT/Transcription/TranscriptionService.swift` | role-match |
| `SPRECHKRAFT/Extensions/Defaults+Keys.swift` | config | — | sich selbst (Erweiterung) | exact |
| `SPRECHKRAFT/Extensions/KeyboardShortcuts+Names.swift` | config | event-driven | sich selbst (Erweiterung) | exact |
| `SPRECHKRAFT/Views/SettingsView.swift` | component | request-response | sich selbst (Erweiterung) | exact |
| `SPRECHKRAFT/Views/ProfileEditorSheet.swift` | component | CRUD | `SPRECHKRAFT/Views/SettingsView.swift` | role-match |
| `SPRECHKRAFT/AppDelegate.swift` | controller | event-driven | sich selbst (Erweiterung) | exact |
| `SPRECHKRAFT/AppState.swift` | store | — | sich selbst (Erweiterung) | exact |
| `SPRECHKRAFTTests/PromptProfileTests.swift` | test | — | `SPRECHKRAFTTests/DefaultsKeysTests.swift` | exact |
| `SPRECHKRAFTTests/GroqServiceTests.swift` | test | — | `SPRECHKRAFTTests/TranscriptionServiceTests.swift` | role-match |

---

## Pattern Assignments

### `SPRECHKRAFT/Models/PromptProfile.swift` (model, CRUD)

**Analog:** `SPRECHKRAFT/Extensions/Defaults+Keys.swift` — OutputMode als `Defaults.Serializable`

**Imports-Pattern** (Defaults+Keys.swift Zeilen 1–8):
```swift
// SPRECHKRAFT/Extensions/Defaults+Keys.swift
import Defaults
```
Neue Datei braucht zusätzlich `Foundation` (für UUID).

**Core-Pattern — Defaults.Serializable Struct** (abgeleitet aus OutputMode, Zeilen 13–16, und RESEARCH.md):

OutputMode zeigt das minimale `Defaults.Serializable`-Pattern via RawRepresentable:
```swift
// Analog aus Defaults+Keys.swift Zeilen 13-16:
enum OutputMode: String, Defaults.Serializable {
    case field
    case clipboard
}
```
PromptProfile ist komplexer (Struct statt Enum), folgt aber demselben Konformanz-Muster.
Da `PromptProfile: Codable`, erhält es `Defaults.Serializable` automatisch (Codable-Arrays
sind von Defaults automatisch serialisierbar).

**Vollständige Struct-Vorlage** (RESEARCH.md Zeilen 501–525 — direkt übernehmen):
```swift
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

**Keine Hotkey-Property in der Struct** — KeyboardShortcuts speichert Bindings selbst
unter dem Key `"profile-\(id.uuidString)"` in UserDefaults (RESEARCH.md Zeile 230).

---

### `SPRECHKRAFT/Services/GroqService.swift` (service, request-response)

**Analog:** `SPRECHKRAFT/Transcription/TranscriptionService.swift` — async actor für
externe Verarbeitung (Netzwerk statt Python-Subprocess; gleiches Concurrency-Muster)

**Imports-Pattern** (TranscriptionService — actor-Deklaration, Concurrency):
```swift
// Muster: actor-Typ, Foundation für URLSession/JSONEncoder/JSONDecoder
import Foundation
```

**Core-Pattern — actor + async throws + URLSession** (RESEARCH.md Zeilen 244–306):
```swift
actor GroqService {
    static let shared = GroqService()
    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private let timeoutSeconds: TimeInterval = 30

    struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let top_p: Double
        let reasoning_effort: String?   // nil = Thinking; "none" = non-thinking (D-09)

        struct Message: Encodable {
            let role: String
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

**Pitfall `reasoning_effort: nil`** (RESEARCH.md Zeilen 486–494): Swift kodiert `nil`
Optional-Felder als JSON `null`. Da Groq das Feld einfach weggelassen haben möchte,
muss `ChatRequest.encode(to:)` custom implementiert werden mit `encodeIfPresent`:
```swift
// In ChatRequest: Entweder CodingKeys + encodeIfPresent, oder
// separate Structs für thinking vs. non-thinking Request.
func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(model, forKey: .model)
    try container.encode(messages, forKey: .messages)
    try container.encode(temperature, forKey: .temperature)
    try container.encode(top_p, forKey: .top_p)
    try container.encodeIfPresent(reasoning_effort, forKey: .reasoning_effort)
}
```

**Concurrency-Rückgabe-Pattern** (AppDelegate.swift Zeilen 78–93 — Vorlage für Aufrufer):
```swift
// Actor-Aufruf in Task {}, Ergebnis via await MainActor.run {}
Task {
    let result: String
    do {
        result = try await GroqService.shared.process(...)
    } catch {
        result = fallbackText  // D-10: stille Fallback
    }
    await MainActor.run {
        // UI-Updates, TextOutputService, resetToIdle()
    }
}
```

---

### `SPRECHKRAFT/Extensions/Defaults+Keys.swift` (config, Erweiterung)

**Analog:** sich selbst — neuer Key nach demselben Schema

**Bestehendes Pattern** (Defaults+Keys.swift Zeilen 18–30):
```swift
extension Defaults.Keys {
    static let silenceDuration = Key<Double>("silenceDuration", default: 1.5)
    static let selectedMicUID = Key<String?>("selectedMicUID", default: nil)
    static let outputMode = Key<OutputMode>("outputMode", default: .field)
}
```

**Neuer Key — Vorlage** (RESEARCH.md Zeilen 219–227):
```swift
// Hinzufügen nach den bestehenden Keys:
extension Defaults.Keys {
    // [PromptProfile] ist Codable → automatisch Defaults.Serializable
    static let profiles = Key<[PromptProfile]>(
        "profiles",
        default: [PromptProfile.defaultProfile]  // D-05: ein Profil beim ersten Start
    )
}
```
`activeProfileID` wird NICHT in Defaults gespeichert — es ist reiner Laufzeit-State
in `AppState` (nie zwischen App-Starts persistent, immer nil beim Start).

---

### `SPRECHKRAFT/Extensions/KeyboardShortcuts+Names.swift` (config, Erweiterung)

**Analog:** sich selbst — neue dynamische Name-Hilfsfunktion nach demselben Schema

**Bestehendes Pattern** (KeyboardShortcuts+Names.swift Zeilen 9–22):
```swift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self(
        "toggleRecording",
        default: .init(.r, modifiers: [.option, .command])
    )
    static let toggleOutputMode = Self(
        "toggleOutputMode",
        default: .init(.v, modifiers: [.shift, .command])
    )
}
```

**Neue dynamische Name-Hilfsfunktion** (RESEARCH.md Zeilen 171–177):
```swift
extension KeyboardShortcuts.Name {
    /// Erzeugt einen stabilen Namen für ein Profil anhand seiner UUID.
    /// Kein `initial:`-Parameter — Profil-Hotkeys haben keinen Default-Shortcut.
    /// Der String "profile-\(id)" ist der Persistence-Key in KeyboardShortcuts UserDefaults.
    static func profile(_ id: UUID) -> Self {
        Self("profile-\(id.uuidString)")
    }
}
```

**Wichtig:** `static func` statt `static let` — jeder Aufruf mit derselben UUID liefert
denselben internen Storage-Key. Kein `initial:`-Parameter (kein vordefinierter Hotkey
für benutzer-erstellte Profile).

---

### `SPRECHKRAFT/Views/SettingsView.swift` (component, Erweiterung)

**Analog:** sich selbst — neue Section nach dem Form-Section-Pattern

**Bestehendes Section-Pattern** (SettingsView.swift Zeilen 88–114):
```swift
Section("Stille-Erkennung") {
    HStack { ... }
    Text("Beschreibungstext")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
}
```

**Permission-Banner-Pattern** (SettingsView.swift Zeilen 119–145 — direkt als Vorlage
für den Groq-API-Key-Banner mit `groqKeyMissing`):
```swift
// Vorlage: axPermissionDenied-Banner (Zeilen 120-145)
if appState?.axPermissionDenied == true {
    HStack(spacing: DesignTokens.Spacing.sm) {
        Image(systemName: "hand.raised.slash.fill")
            .foregroundStyle(.white)
        VStack(alignment: .leading, spacing: 2) {
            Text("Bedienungshilfen-Zugriff erforderlich")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
            Text("Beschreibung...")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.9))
        }
        Spacer()
        Button("Einstellungen öffnen") { ... }
            .buttonStyle(.bordered)
    }
    .padding(DesignTokens.Spacing.sm)
    .background(Color(.systemRed))
    .cornerRadius(8)
    .accessibilityLabel("...")
}
```
Für `groqKeyMissing`: Symbol `"key.slash"`, kein "Einstellungen öffnen"-Button
(Key wird direkt im SecureField darunter eingegeben).

**Neue Profil-Liste-Row** — `KeyboardShortcuts.Recorder`-Pattern aus Zeile 161:
```swift
// Zeile 161: Bestehendes Recorder-Pattern für statische Names:
KeyboardShortcuts.Recorder("Modus-Wechsel-Hotkey", name: .toggleOutputMode)

// Für dynamische Profile-Names:
KeyboardShortcuts.Recorder("Aktivierungs-Hotkey", name: .profile(profile.id))
```

**State für Sheet** — `@State private var`-Pattern (Zeilen 23–24):
```swift
@State private var availableMics: [AVCaptureDevice] = []
// → Vorlage für:
@State private var editingProfile: PromptProfile? = nil  // .sheet(item:) Binding
```

---

### `SPRECHKRAFT/Views/ProfileEditorSheet.swift` (component, CRUD)

**Analog:** `SPRECHKRAFT/Views/SettingsView.swift` — SwiftUI Form mit Sections,
@Default Bindings, KeyboardShortcuts.Recorder, Permission-Banner-Struktur

**Imports-Pattern** (SettingsView.swift Zeilen 9–13 — identisch):
```swift
import SwiftUI
import Defaults
import KeyboardShortcuts
```

**Form-Grundstruktur** (SettingsView.swift Zeilen 25–27 und 164–166):
```swift
var body: some View {
    Form {
        Section("...") { ... }
    }
    .formStyle(.grouped)
    .padding(DesignTokens.Spacing.xl)
}
```

**Sheet wird via `.sheet(item:)` von SettingsView geöffnet**:
```swift
// In SettingsView (Aufrufer-Seite):
.sheet(item: $editingProfile) { profile in
    ProfileEditorSheet(profile: profile, onSave: { updated in
        // Defaults[.profiles] updaten
    }, onDelete: { ... })
}
```

**ProfileEditorSheet empfängt Binding oder Value + Callbacks:**
```swift
struct ProfileEditorSheet: View {
    @State private var draft: PromptProfile
    var onSave: (PromptProfile) -> Void
    var onDelete: (() -> Void)?    // nil wenn letztes Profil (D-06)

    init(profile: PromptProfile, onSave: @escaping (PromptProfile) -> Void, onDelete: (() -> Void)?) {
        _draft = State(initialValue: profile)
        self.onSave = onSave
        self.onDelete = onDelete
    }
}
```

**Löschen-Button ausgegraut** (D-06) — analog zu `.disabled`-Pattern in SwiftUI:
```swift
Button("Profil löschen", role: .destructive) { onDelete?() }
    .disabled(onDelete == nil)  // nil wenn letztes Profil
```

---

### `SPRECHKRAFT/AppDelegate.swift` (controller, Erweiterung)

**Analog:** sich selbst — neue MARK-Sections nach dem Muster der bestehenden Sections

**setupHotkey-Pattern** (AppDelegate.swift Zeilen 280–291 — Vorlage für setupProfileHotkeys()):
```swift
// Bestehendes onKeyUp-Pattern (toggleRecording):
private func setupHotkey() {
    KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.appState?.recordingState == .idle {
                self.startRecordingWithCue()
            } else if self.appState?.recordingState == .recording {
                self.stopRecordingWithCue()
            }
        }
    }
}
```
Für Profil-Hotkeys: `onKeyDown` statt `onKeyUp` (RESEARCH.md Pitfall 1, Zeilen 447–454).

**Neue setupProfileHotkeys()-Methode** (RESEARCH.md Zeilen 179–192):
```swift
private func setupProfileHotkeys() {
    for profile in Defaults[.profiles] {
        let name = KeyboardShortcuts.Name.profile(profile.id)
        KeyboardShortcuts.onKeyDown(for: name) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self,
                      self.appState?.recordingState == .recording,
                      self.appState?.activeProfileID == nil   // D-02: Erster gewinnt
                else { return }
                self.appState?.activeProfileID = profile.id
            }
        }
    }
}
```

**onRecordingComplete-Erweiterung** (AppDelegate.swift Zeilen 76–93 — bestehender Callback,
wird durch LLM-Routing erweitert, RESEARCH.md Zeilen 348–405):
```swift
// Bestehendes Pattern (Zeilen 76-93):
audioController?.onRecordingComplete = { [weak self] samples, sampleRate in
    guard let self else { return }
    Task {
        let text = await self.transcriptionService.transcribeWithResampling(samples, sampleRate: sampleRate)
        await MainActor.run {
            if let text {
                let mode = Defaults[.outputMode]
                let axPermitted = !(self.appState?.axPermissionDenied ?? true)
                TextOutputService.shared.output(text, mode: mode, axPermitted: axPermitted)
            }
            self.appState?.resetToIdle()
            self.updateIcon()
        }
    }
}
// → Wird ersetzt durch LLM-Routing-Block aus RESEARCH.md Pattern 5
```

**applicationDidFinishLaunching-Erweiterung** (AppDelegate.swift Zeilen 32–48):
```swift
// Bestehende Zeilen 44-47:
updateIcon()
setupHotkey()
setupTranscription()
setupOutputModeHotkey()
// → Ergänzen um:
setupProfileHotkeys()
// → groqKeyMissing prüfen (KeychainAccess):
// appState?.groqKeyMissing = (keychain["groqApiKey"] == nil)
```

---

### `SPRECHKRAFT/AppState.swift` (store, Erweiterung)

**Analog:** sich selbst — neue Properties nach dem Muster der bestehenden bool-Properties

**Bestehendes Property-Pattern** (AppState.swift Zeilen 69–81):
```swift
// Muster für neue Bool-Properties:
/// true wenn AXIsProcessTrusted() false zurueckgibt (kein AX-Permission).
/// Wird in applicationDidFinishLaunching gesetzt (D-10).
/// Konsumiert von SettingsView fuer den roten AX-Permission-Banner (D-11).
var axPermissionDenied: Bool = false

// Muster für neue Optional-Properties:
/// UniqueID des vom Nutzer gewaehlten Mikrofons. nil = System-Standard.
// (analog in Defaults, nicht AppState — aber zeigt nil-Semantik)
```

**Neue Properties für Phase 5**:
```swift
// Nach axPermissionDenied (Zeile 81) einfügen:

/// ID des während der laufenden Aufnahme aktivierten Profils via Profil-Hotkey.
/// nil = kein Profil-Hotkey gedrückt → Standard-Profil greift.
/// D-02: Erster gewinnt — wird in setupProfileHotkeys() onKeyDown gesetzt.
/// Wird in onRecordingComplete-Callback gelesen und sofort auf nil zurückgesetzt.
var activeProfileID: UUID? = nil

/// true wenn kein Groq API-Key im Keychain vorhanden ist.
/// Wird in applicationDidFinishLaunching gesetzt (analog axPermissionDenied, D-10).
/// Konsumiert von SettingsView für den roten Groq-API-Key-Banner (SET-01).
var groqKeyMissing: Bool = false
```

---

### `SPRECHKRAFTTests/PromptProfileTests.swift` (test, CRUD)

**Analog:** `SPRECHKRAFTTests/DefaultsKeysTests.swift` — Swift Testing @Suite/@Test,
Defaults-Key-Prüfungen, @testable import

**Test-Datei-Grundstruktur** (DefaultsKeysTests.swift Zeilen 1–12):
```swift
import Testing
import Defaults
import KeyboardShortcuts    // falls Hotkey-Tests enthalten
@testable import SPRECHKRAFT

@Suite("Prompt Profile (PROF-01, PROF-03, PROF-04)")
struct PromptProfileTests {
    // ...
}
```

**@MainActor-Decorator** für State-Tests (AppStateTests.swift Zeile 9):
```swift
@Suite("...")
@MainActor
struct AppStateTests {
```
PromptProfileTests benötigt `@MainActor` nur wenn AppState direkt getestet wird.

**Test-Stub-Pattern** — Wave 0 stubs (RED-Phase, wie in Phase 2/3/4 etabliert):
```swift
@Test("PromptProfile hat korrekte Default-Werte (PROF-01)")
func testDefaultProfile() {
    let profile = PromptProfile.defaultProfile
    #expect(profile.name == "Rohe Transkription")
    #expect(profile.isLLMEnabled == false)
    #expect(profile.isDefault == true)
}

@Test("Genau ein Profil hat isDefault == true nach Markierung (PROF-04)")
func testIsDefaultInvariante() {
    // Invariante: immer genau 1 isDefault == true
}

@Test("profiles-Key hat ein Default-Profil beim ersten Start (PROF-01)")
func testProfilesDefaultKey() {
    #expect(Defaults.Keys.profiles.defaultValue.count == 1)
    #expect(Defaults.Keys.profiles.defaultValue.first?.isDefault == true)
}
```

---

### `SPRECHKRAFTTests/GroqServiceTests.swift` (test, request-response)

**Analog:** `SPRECHKRAFTTests/TranscriptionServiceTests.swift` — async Tests für
Service-Actor, Guard-Logik, Nil-Rückgaben

**Test-Datei-Grundstruktur** (TranscriptionServiceTests.swift Zeilen 1–11):
```swift
import Testing
import AVFoundation     // → stattdessen: keine Extra-Imports nötig außer Foundation implizit
@testable import SPRECHKRAFT

@Suite("GroqService (PROF-05, SET-01)")
struct GroqServiceTests {
```

**async Test-Pattern** (TranscriptionServiceTests.swift Zeilen 21–26):
```swift
@Test("GroqService gibt Fallback zurück wenn kein API-Key (D-10)")
func testFallbackWhenNoKey() async {
    // Test ohne echten Netzwerk-Call — Mock-Strategie nötig
}
```

**Wave-0-Stubs** für Mock-URLSession (PROF-05):
```swift
@Test("GroqService.process wirft GroqError.emptyResponse bei leerer choices-Liste (PROF-05)")
func testEmptyResponseThrows() async throws {
    // Stub: URLSession mit leerem choices-Array mocken
}

@Test("ChatRequest kodiert reasoning_effort: none für non-thinking (D-09)")
func testNonThinkingRequest() throws {
    // Unit-Test ohne Netzwerk: JSONEncoder-Output prüfen
    let profile = PromptProfile(id: UUID(), name: "Test", prompt: "p",
                                isLLMEnabled: true, isThinkingEnabled: false, isDefault: false)
    // ChatRequest kodieren und JSON-Output inspizieren
}
```

---

## Shared Patterns

### Permission-Banner (rot, systemRed)

**Quelle:** `SPRECHKRAFT/SettingsView.swift` Zeilen 119–145 (axPermissionDenied-Banner)
**Anwenden auf:** Groq-API-Key-Banner in SettingsView (groqKeyMissing)

```swift
// Vorlage: axPermissionDenied-Banner aus SettingsView.swift Zeilen 120-145
if appState?.axPermissionDenied == true {
    HStack(spacing: DesignTokens.Spacing.sm) {
        Image(systemName: "hand.raised.slash.fill")
            .foregroundStyle(.white)
        VStack(alignment: .leading, spacing: 2) {
            Text("Titel")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
            Text("Beschreibung")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.9))
        }
        Spacer()
        Button("Aktion") { ... }
            .buttonStyle(.bordered)
    }
    .padding(DesignTokens.Spacing.sm)
    .background(Color(.systemRed))
    .cornerRadius(8)
    .accessibilityLabel("...")
}
```

### Swift 6 Strict Concurrency: Task + MainActor.run

**Quelle:** `SPRECHKRAFT/AppDelegate.swift` Zeilen 76–93 (onRecordingComplete)
**Anwenden auf:** GroqService-Aufruf in AppDelegate, alle AppState-Mutationen aus Tasks

```swift
// Muster aus AppDelegate.swift Zeilen 78-93:
Task {
    let text = await self.transcriptionService.transcribeWithResampling(...)
    await MainActor.run {
        // State-Mutationen nur hier
        self.appState?.resetToIdle()
        self.updateIcon()
    }
}
```

### Defaults.Key Extension

**Quelle:** `SPRECHKRAFT/Extensions/Defaults+Keys.swift` Zeilen 18–30
**Anwenden auf:** `profiles`-Key in derselben Datei

```swift
extension Defaults.Keys {
    static let neuKey = Key<Typ>("neuKey", default: defaultWert)
}
```

### KeyboardShortcuts.onKeyUp / onKeyDown mit [weak self]

**Quelle:** `SPRECHKRAFT/AppDelegate.swift` Zeilen 281–291
**Anwenden auf:** `setupProfileHotkeys()` — gleiche Struktur, aber `onKeyDown` statt `onKeyUp`

```swift
KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
    Task { @MainActor [weak self] in
        guard let self else { return }
        // ...
    }
}
```

### Observation-B: manuelle updateIcon() nach State-Mutation

**Quelle:** `SPRECHKRAFT/AppDelegate.swift` Zeilen 108–113, 122–126
**Anwenden auf:** Jede Stelle in Phase 5 wo `appState?.recordingState` geändert wird

```swift
// Muster: State setzen → updateIcon() sofort danach
appState?.toggleRecording()
updateIcon()
// und nach llmProcessing:
appState?.recordingState = .llmProcessing
updateIcon()
```

### Swift Testing @Suite / @Test / #expect

**Quelle:** `SPRECHKRAFTTests/DefaultsKeysTests.swift` Zeilen 13–60
**Anwenden auf:** Alle neuen Test-Dateien — identischer Import-Block, @Suite-Struktur

```swift
import Testing
import Defaults
@testable import SPRECHKRAFT

@Suite("Thema (REQ-ID)")
struct XyzTests {
    @Test("Beschreibung (REQ-ID)")
    func testXyz() {
        #expect(...)
    }
}
```

---

## No Analog Found

Alle zehn Dateien haben einen Analog. Keine Datei ohne Vorlage.

---

## Metadata

**Analog search scope:** `SPRECHKRAFT/`, `SPRECHKRAFTTests/`
**Files scanned:** 12 Quelldateien + 8 Testdateien
**Pattern extraction date:** 2026-04-19
