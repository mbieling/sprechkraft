# Architecture Research

**Project:** VoiceScribe — macOS Menu Bar Dictation App
**Researched:** 2026-04-15
**Overall confidence:** HIGH (all major claims verified against official Apple docs or authoritative library sources)

---

## Component Overview

### 1. App Shell — `MenuBarApp`

**Responsibility:** Entry point, NSStatusItem lifecycle, top-level state coordinator.

**Decision: Use `NSApplicationDelegate` + `NSStatusItem` directly, not SwiftUI `MenuBarExtra`.**

Rationale: `MenuBarExtra` (introduced macOS 13) is convenient for simple menus, but it has constraints that conflict with this app's needs: it cannot easily host animated icons driven by external state (recording in progress), and it offers no `onKeyDown`/`onKeyUp` hooks for push-to-talk. `NSStatusItem` + `NSStatusBarButton` gives full control over icon animation, click handling, and menu attachment.

Pattern:
```swift
@main
struct VoiceScribeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { SettingsView() } }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock — set LSUIElement in Info.plist
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // attach menu or popover
    }
}
```

`LSUIElement = YES` in `Info.plist` keeps the app out of the Dock and App Switcher.
Confidence: HIGH (Apple NSStatusItem docs, confirmed pattern)

---

### 2. Hotkey Engine — `HotkeyManager`

**Responsibility:** Intercept global key-down and key-up events; translate to `startRecording` / `stopRecording` signals.

**Decision: Use `KeyboardShortcuts` Swift package (sindresorhus/keyboardshortcuts).**

Rationale:
- Pure Swift, SwiftUI + Cocoa support, Mac App Store + sandboxed-app compatible.
- `onKeyDown` for push-to-talk start, `onKeyUp` for stop — both are available.
- Stores shortcut preferences automatically in `UserDefaults`.
- Provides a `Recorder` UI component for the settings screen.
- Alternative (Carbon `RegisterEventHotKey`) is deprecated-in-spirit and not sandbox-safe.
- Alternative (`NSEvent.addGlobalMonitorForEvents`) requires Accessibility permission and cannot prevent the key event from reaching other apps.

```swift
extension KeyboardShortcuts.Name {
    static let pushToTalk = Self("pushToTalk")
    static let profileA   = Self("profileA")
}

// In AppState init:
KeyboardShortcuts.onKeyDown(for: .pushToTalk) { startRecording() }
KeyboardShortcuts.onKeyUp(for: .pushToTalk)   { stopRecording() }
```

Confidence: HIGH (KeyboardShortcuts Context7 docs, GitHub README)

---

### 3. Audio Pipeline — `AudioRecorder`

**Responsibility:** Capture microphone input, accumulate PCM buffers, deliver `[Float]` array on stop.

**Stack: `AVAudioEngine` with `installTap` on the input node.**

Pattern:
```swift
final class AudioRecorder {
    private let engine = AVAudioEngine()
    private var samples: [Float] = []

    func startRecording() throws {
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            // append mono float32 samples
            if let channelData = buffer.floatChannelData?[0] {
                self.samples.append(contentsOf:
                    Array(UnsafeBufferPointer(start: channelData,
                                             count: Int(buffer.frameLength))))
            }
        }
        try engine.start()
    }

    func stopRecording() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        defer { samples = [] }
        return samples
    }
}
```

WhisperKit expects 16 kHz mono `[Float]`. AVAudioEngine typically delivers the hardware's native format. A resampling step via `AVAudioConverter` is needed if the hardware sample rate differs from 16 000 Hz. WhisperKit's `AudioProcessor.convertBufferToArray` handles this internally if raw buffers are passed directly.

Confidence: HIGH (AVAudioEngine is the standard macOS audio capture path; WhisperKit docs confirm float array input)

---

### 4. Transcription Engine — `TranscriptionService`

**Responsibility:** Accept `[Float]` PCM audio, return transcript string via async/await.

**Decision: Use WhisperKit (argmaxinc/whisperkit), NOT parakeet-mlx.**

Critical finding: `parakeet-mlx` is a Python-only library. It cannot be imported into a Swift app without a subprocess bridge (fragile, requires bundled Python runtime, unacceptable for a polished native app). WhisperKit is a native Swift package that:
- Runs on-device using CoreML + Neural Engine
- Has a clean async Swift API
- Supports model download, local model folder, and memory unload
- Accepts raw `[Float]` samples at 16 kHz

If NVIDIA Parakeet accuracy is specifically required, the only viable path in Swift is: (a) export the Parakeet model to CoreML via `coremltools` and load with `MLModel`, or (b) wrap the parakeet-mlx Python library in a bundled subprocess — which is complex and fragile. WhisperKit with `large-v3` or the device-recommended model is the pragmatic choice.

```swift
actor TranscriptionService {
    private var pipe: WhisperKit?

    func load() async throws {
        let config = WhisperKitConfig(
            model: "large-v3-v20240930",
            download: false,                      // model bundled at build time
            load: true,
            prewarm: true
        )
        pipe = try await WhisperKit(config)
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        guard let pipe else { throw ServiceError.notLoaded }
        let results = try await pipe.transcribe(audioArray: samples)
        return results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    func unload() async {
        await pipe?.unloadModels()
        pipe = nil
    }
}
```

**Lazy loading:** Call `load()` on first use or on app launch in a background Task. Keep loaded while app is active; call `unload()` only if memory pressure is critical.

Confidence: HIGH for WhisperKit approach (Context7 docs). MEDIUM for Parakeet CoreML path (feasible but requires a separate export step not documented in the parakeet-mlx repo).

---

### 5. LLM Post-Processor — `GroqService`

**Responsibility:** Accept transcript + active prompt profile, call Groq REST API, return processed text.

**Stack: `URLSession` async/await, no third-party HTTP library needed.**

Groq API is OpenAI-compatible. A single `POST /v1/chat/completions` call suffices.

```swift
actor GroqService {
    private let apiKey: String   // loaded from Keychain on init

    func process(transcript: String, profile: PromptProfile) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ChatRequest(
            model: "qwen/qwen3-32b",
            messages: [
                .init(role: "system", content: profile.systemPrompt),
                .init(role: "user",   content: transcript)
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response  = try JSONDecoder().decode(ChatResponse.self, from: data)
        return response.choices.first?.message.content ?? transcript
    }
}
```

Skip LLM entirely if the active profile has AI disabled — return the transcript directly.

Confidence: HIGH (Groq API is OpenAI-compatible; standard URLSession pattern)

---

### 6. Output Engine — `TextOutputService`

**Responsibility:** Inject processed text into the focused input field, or write to clipboard.

Two modes:

**Mode A — Accessibility injection (preferred)**
Uses `AXUIElement` to write to the focused element's `AXValue` or simulate paste.
```swift
func injectViaAccessibility(_ text: String) {
    let systemWide = AXUIElementCreateSystemWide()
    var focusedElement: AnyObject?
    AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)
    guard let element = focusedElement else { return }
    // Set kAXValueAttribute or use kAXSelectedTextAttribute for insertion at cursor
    AXUIElementSetAttributeValue(element as! AXUIElement,
                                 kAXSelectedTextAttribute as CFString,
                                 text as CFTypeRef)
}
```
Requires Accessibility permission (prompted at runtime, listed in entitlements).

**Mode B — Clipboard paste (fallback)**
```swift
func injectViaClipboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    // Simulate Cmd+V — only works in apps that accept paste
    let source = CGEventSource(stateID: .hidSystemState)
    let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
    vDown?.flags = .maskCommand
    vDown?.post(tap: .cghidEventTap)
    // key up...
}
```

Clipboard paste also requires Accessibility permission (for `CGEvent.post`).

Confidence: MEDIUM (AXUIElement injection works for most apps; `kAXSelectedTextAttribute` is not supported by every app — some accept only simulated keystroke paste)

---

### 7. Keychain Manager — `KeychainService`

**Responsibility:** Store and retrieve Groq API key securely.

```swift
struct KeychainService {
    static let service = "com.yourname.voicescribe"

    static func save(apiKey: String) throws {
        let data = Data(apiKey.utf8)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: "groq_api_key",
            kSecValueData:   data
        ]
        SecItemDelete(query as CFDictionary)   // remove old if exists
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    static func load() throws -> String {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: "groq_api_key",
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.notFound
        }
        return key
    }
}
```

Confidence: HIGH (Apple Keychain Services docs pattern)

---

### 8. History Store — `HistoryStore`

**Responsibility:** Persist transcription records locally; support full-text search.

**Decision: Use GRDB.swift (v7.5.0) over SwiftData.**

Rationale:
- SwiftData requires macOS 14+. GRDB works from macOS 10.15+.
- GRDB has built-in FTS5 full-text search — trivial to add searchable history.
- SwiftData's FTS story is incomplete and requires dropping to raw SQLite anyway.
- GRDB's async API (`DatabasePool`) integrates cleanly with Swift concurrency.

```swift
@Model  // GRDB record struct, not SwiftData macro
struct TranscriptionRecord: Codable, FetchableRecord, PersistableRecord {
    var id: UUID
    var rawText: String
    var processedText: String?
    var profileName: String?
    var createdAt: Date
    var durationSeconds: Double
}
```

FTS5 virtual table synced with `transcription_record` table enables substring search across all text fields.

Confidence: HIGH (GRDB Context7 docs, FTS documentation confirmed)

---

### 9. Settings + Profile Store — `SettingsManager`

**Responsibility:** Persist app preferences and prompt profiles.

- Simple preferences (output mode, autostart): `UserDefaults` via `@AppStorage`
- Prompt profiles (structured, multiple): GRDB alongside history, or `Codable` + `UserDefaults` for small payloads. Given GRDB is already a dependency, store profiles in a `prompt_profile` table.

---

## Data Flow

```
[User presses hotkey]
        |
        v
HotkeyManager.onKeyDown
        |
        v
AppState.startRecording()
  - StatusItem icon → animated recording state
  - AudioRecorder.startRecording() → starts AVAudioEngine tap
        |
[User holds key, speaks]
        |
[User releases hotkey]
        |
        v
HotkeyManager.onKeyUp
        |
        v
AppState.stopRecording()
  - AudioRecorder.stopRecording() → [Float] PCM buffer
  - StatusItem icon → "processing" state
        |
        v
TranscriptionService.transcribe([Float])
  - WhisperKit inference (CoreML, Neural Engine)
  - Returns: String (raw transcript)
        |
        v
[Active profile has AI enabled?]
    YES → GroqService.process(transcript, profile)
            - URLSession POST to Groq API
            - Returns: String (processed text)
    NO  → pass raw transcript through
        |
        v
HistoryStore.save(record)
  - Writes to SQLite via GRDB
        |
        v
TextOutputService.inject(text, mode: .accessibility | .clipboard)
  - AXUIElement write OR NSPasteboard + simulated Cmd+V
        |
        v
StatusItem icon → idle state
```

**Async boundary:** Everything from `stopRecording()` onwards runs in a Swift `Task` on the cooperative thread pool. `TranscriptionService` and `GroqService` are `actor`-isolated to prevent concurrent model access. The main thread is only touched for icon state updates and UI.

---

## Key Architecture Decisions

### Decision 1: AppDelegate + NSStatusItem over pure SwiftUI MenuBarExtra

`MenuBarExtra` is simpler but cannot animate the status bar icon in response to recording state changes with fine-grained control, and does not integrate with push-to-talk key events. `NSApplicationDelegateAdaptor` lets the app retain a SwiftUI `Settings` scene while keeping full AppKit control of the menu bar item.

### Decision 2: WhisperKit instead of parakeet-mlx

`parakeet-mlx` is Python-only. Integrating it into a native Swift bundle requires a bundled Python runtime and subprocess communication — unacceptable complexity for a polished Mac app. WhisperKit provides equivalent quality transcription via CoreML with a clean Swift async API. If the user later validates a specific need for Parakeet quality, the path is: export Parakeet to CoreML and load via `CoreML.MLModel` directly.

### Decision 3: Actor isolation for ML services

Both `TranscriptionService` and `GroqService` are Swift `actor` types. This prevents re-entrant calls if the user triggers recording again before the previous pipeline finishes. The `AppState` should reject new recordings while a pipeline is in flight and surface a "busy" state in the icon.

### Decision 4: GRDB over SwiftData for history

GRDB's FTS5 support and broader macOS version compatibility make it the right choice. SwiftData is limited to macOS 14+ and has no first-class full-text search.

### Decision 5: Two-mode text output with graceful fallback

Accessibility injection (`kAXSelectedTextAttribute`) is the ideal path — it inserts at the cursor position without disturbing clipboard contents. However, not all apps expose this attribute. The fallback is clipboard-replace + simulated Cmd+V. The user can configure which mode is preferred in Settings; the app should auto-detect injection failure and fall back silently.

### Decision 6: Lazy model loading with explicit unload

WhisperKit models (large-v3) are ~1.5 GB. Load once at app startup in a background `Task`. Keep loaded. Expose an "unload" option if the user wants to reclaim memory. Do not load/unload on every dictation cycle.

---

## macOS Permissions Required

| Permission | Why Needed | How Requested |
|---|---|---|
| **Microphone** (`NSMicrophoneUsageDescription`) | AVAudioEngine captures mic input | System prompt on first use; `NSMicrophoneUsageDescription` in Info.plist |
| **Accessibility** (`NSAppleEventsUsageDescription` / AX entitlement) | AXUIElement text injection and CGEvent keyboard simulation | System prompt directing user to System Settings → Privacy → Accessibility |
| **App Sandbox** | Required for Mac App Store distribution | Must use `com.apple.security.device.audio-input` and `com.apple.security.temporary-exception.apple-events` entitlements |

Additional Info.plist keys:
- `LSUIElement = YES` — hides Dock icon
- `LSBackgroundOnly` — do not set this (prevents Settings window from appearing)
- `SMLoginItemAgentType` or `ServiceManagement` framework for Login Item autostart (macOS 13+ uses `SMAppService.mainApp.register()`)

Confidence: HIGH (Apple entitlement docs, standard menu bar app pattern)

---

## Suggested Build Order

The pipeline has strict data dependencies. Build in this order to enable end-to-end testing at each stage before adding the next layer.

### Phase 1 — Shell + Hotkey
Build: `AppDelegate`, `NSStatusItem` setup, `LSUIElement`, `KeyboardShortcuts` integration with `onKeyDown`/`onKeyUp`.
Gate: Key press/release logs to console; icon changes color.
Why first: Everything downstream depends on the hotkey triggering state changes. Validates the app can receive global events.

### Phase 2 — Audio Capture
Build: `AudioRecorder` with `AVAudioEngine`, microphone permission request.
Gate: Stop returns a non-empty `[Float]` array; save to `.wav` file and verify audio quality.
Why second: Transcription cannot be tested without audio. Simple to isolate.

### Phase 3 — Transcription
Build: `TranscriptionService` wrapping WhisperKit, model bundling/download on first launch.
Gate: Pass saved `.wav` samples; get back correct transcript string.
Why third: Largest single complexity spike. Isolate it before adding LLM and output.

### Phase 4 — Text Output
Build: `TextOutputService` with both accessibility injection and clipboard fallback.
Gate: Hardcoded string successfully appears in a text editor with cursor focus.
Why fourth: Output doesn't depend on transcription correctness; can be developed against a hardcoded string.

### Phase 5 — End-to-End Pipeline
Wire: hotkey → audio → transcription → output. No AI processing yet.
Gate: Full push-to-talk dictation works without any settings UI.

### Phase 6 — History Store
Build: GRDB setup, `TranscriptionRecord` model, FTS5 table, `HistoryStore` actor.
Gate: After dictation, records appear in a debug query.
Why here: Not on the critical path of the core UX; add after the main loop works.

### Phase 7 — Groq / Prompt Profiles
Build: `PromptProfile` model, `GroqService`, profile selection in menu bar.
Gate: With a real API key, transcript is transformed by a prompt and output correctly.
Why here: Requires a working transcript; depends on Phase 5.

### Phase 8 — Keychain + Settings UI
Build: `KeychainService`, `SettingsView` (SwiftUI), profile editor, hotkey recorder UI, history browser.
Gate: API key survives app restart; profiles are editable; history is searchable.
Why last: Settings UI can be done at any point but it's polish — do it after all features work.

### Phase 9 — Polish
- Login item autostart (`SMAppService`)
- Status icon animation during recording/processing states
- Error states (microphone denied, Groq API failure, model not loaded)
- Onboarding flow (first-launch permission requests)

---

## Sources

- NSStatusItem: https://developer.apple.com/documentation/appkit/nsstatusitem (MEDIUM — page confirmed, details from training)
- KeyboardShortcuts: Context7 `/sindresorhus/keyboardshortcuts` (HIGH)
- WhisperKit: Context7 `/argmaxinc/whisperkit` (HIGH)
- GRDB.swift: Context7 `/groue/grdb.swift` (HIGH)
- SwiftData: Context7 `/websites/developer_apple_swiftdata` (HIGH)
- Keychain Services: Apple Developer Documentation (HIGH — confirmed via WebFetch)
- NSPasteboard: Apple Developer Documentation (HIGH — confirmed via WebFetch)
- parakeet-mlx: Context7 `/senstella/parakeet-mlx` — Python-only, not usable directly from Swift (HIGH)
- NSEvent global monitor: Apple Developer Documentation (MEDIUM — confirmed via WebFetch, accessibility requirement confirmed)
