# Stack Research

**Project:** VoiceScribe — macOS Menu Bar Dictation App
**Researched:** 2026-04-15
**Overall confidence:** HIGH (most claims verified via Context7 official docs)

---

## Recommended Stack

### Core Framework

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Swift | 6.x (swift-6.1.2-RELEASE) | Primary language | Native macOS, first-class Accessibility API access, best performance on Apple Silicon, no bridging overhead |
| SwiftUI | macOS 14+ | UI layer | `MenuBarExtra` scene type (macOS 13+) handles menu-bar-only apps natively; LSUIElement=true hides dock icon |
| AppKit (NSStatusItem) | — | Menu bar icon animation | SwiftUI `MenuBarExtra` is backed by AppKit; drop to AppKit for fine-grained icon animation control if needed |

**Menu bar setup (confirmed via Apple SwiftUI docs):**

```swift
@main
struct VoiceScribeApp: App {
    var body: some Scene {
        MenuBarExtra("VoiceScribe", systemImage: "mic.fill") {
            AppMenu()
        }
    }
}
```

Plus in `Info.plist`:
```xml
<key>LSUIElement</key>
<true/>
```

This removes the app from the Dock and Cmd+Tab switcher. Apps using only `MenuBarExtra` are automatically terminated if the user removes the extra — expected behavior here.

**Confidence: HIGH** — Verified via Apple SwiftUI developer documentation.

---

### Audio Capture

| Technology | Purpose | Why |
|------------|---------|-----|
| AVFoundation (`AVAudioEngine`) | Microphone capture, push-to-talk buffer accumulation | Higher-level than Core Audio, Swift-native API, supports `installTap(onBus:bufferSize:format:block:)` for real-time PCM buffer access |
| `AVAudioSession` | (macOS: no-op / implicit) | On macOS the session is managed automatically; no explicit `AVAudioSession` activation needed unlike iOS |

**Recommended pattern — push-to-talk with buffer accumulation:**

```swift
let engine = AVAudioEngine()
let inputNode = engine.inputNode
let format = inputNode.outputFormat(forBus: 0)
var audioBuffers: [AVAudioPCMBuffer] = []

inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
    audioBuffers.append(buffer)  // accumulate while key held
}
try engine.start()
// On key release: stop, concatenate buffers, pass to Parakeet
inputNode.removeTap(onBus: 0)
```

**Why not Core Audio directly:** Core Audio is C-based, requires manual AudioUnit graph setup, and offers no meaningful performance advantage for a push-to-talk use case. AVFoundation is the correct abstraction level.

**Why not `AVAudioRecorder`:** It writes to disk; for short push-to-talk clips you want in-memory PCM buffers to pass directly to the ML model without a file roundtrip.

**Required entitlement:** `com.apple.security.device.audio-input` (microphone permission). Also add `NSMicrophoneUsageDescription` to `Info.plist`.

**Confidence: HIGH** — Standard macOS audio capture pattern; AVFoundation is Apple's recommended framework.

---

### Local ML / Parakeet Integration

This is the most critical architectural decision in the stack.

**Parakeet v3 is a Python/MLX model — it has no native Swift binary.** Integration options ranked by recommendation:

| Approach | Verdict | Notes |
|----------|---------|-------|
| **Python subprocess via bundled venv** | RECOMMENDED | parakeet-mlx is Python, MLX-accelerated, targets Apple Silicon. Bundle a minimal Python env + weights in the app. |
| MLX Swift (direct port) | POSSIBLE but high effort | MLX Swift exists and shares the same Metal backend. You'd need to port the RNNT/TDT decoder yourself — non-trivial. |
| CoreML conversion | POSSIBLE but lossy | ONNX/CoreML export path exists for Parakeet but loses MLX-specific optimizations; accuracy may differ. |
| ONNX Runtime | POSSIBLE fallback | parakeet-rs (Rust) shows ONNX path works; `onnxruntime-objc` or a C wrapper could bridge to Swift. Higher integration complexity. |

**Recommended: Python subprocess approach**

Bundle a minimal Python 3.11+ environment (via `python-build-standalone` or embed via PyInstaller/Briefcase) alongside `parakeet-mlx` and model weights. Swift spawns a child process over stdin/stdout or a Unix domain socket.

Architecture:
```
VoiceScribeApp (Swift)
    ├─ writes raw PCM audio to temp file or pipe
    ├─ spawns bundled Python process
    │      └─ parakeet-mlx: loads model, transcribes, prints JSON to stdout
    └─ reads JSON transcript from stdout
```

**Model sizes (parakeet-tdt-0.6b-v3):** ~1.2 GB on disk (bfloat16 weights). The 1.1B variant is ~2.2 GB. Recommend shipping `parakeet-tdt-0.6b-v3` as the default; it is fast enough for short push-to-talk clips on M1+.

**MLX-Swift path (alternative, future):**
`/ml-explore/mlx-swift` (confirmed in Context7) provides a full Swift ML framework using Metal. The `parakeet-mlx` Python library is ~2000 lines — porting the TDT decoder to MLX Swift is feasible but is a Phase 2+ effort. For a first ship, use the subprocess bridge.

**WhisperKit as a fallback/comparison:** `argmaxinc/whisperkit` is a fully native Swift framework for Whisper models on Apple Silicon (CoreML + Metal). It is drop-in usable from Swift. If Parakeet integration proves brittle, WhisperKit is the best native Swift alternative, accepting the model change. Keep this in your back pocket.

**Confidence: MEDIUM** — parakeet-mlx confirmed Python/MLX-only (Context7). Subprocess pattern is standard macOS practice but exact bundling mechanics need hands-on validation.

---

### LLM Integration (Groq)

| Technology | Purpose | Why |
|------------|---------|-----|
| Groq REST API (OpenAI-compatible) | Post-processing transcripts via qwen/qwen3-32b | No official Swift SDK exists; the API is simple HTTP — use URLSession directly |
| `URLSession` (built-in Swift/Foundation) | HTTP client | Zero dependencies, async/await native in Swift 6, sufficient for single-shot chat completions |

**Groq has no official Swift SDK.** The API is OpenAI-compatible (`POST https://api.groq.com/openai/v1/chat/completions`). One-shot URLSession call is all that's needed:

```swift
var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
request.httpMethod = "POST"
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.httpBody = try JSONEncoder().encode(payload)
let (data, _) = try await URLSession.shared.data(for: request)
```

**Do not add a third-party OpenAI Swift SDK** for this. The overhead of an extra dependency for two API calls is not justified. If the feature grows, `MacPaw/OpenAI` (a popular community Swift SDK) is the closest option, but it is unnecessary here.

**Confidence: HIGH** — Groq API verified as OpenAI-compatible REST; confirmed no official Swift SDK exists.

---

### Text Injection (Accessibility)

| Technology | Purpose | Why |
|------------|---------|-----|
| macOS Accessibility API (`AXUIElement`) | Inject text into focused field in any app | Only system-level mechanism for writing into another app's text field. No third-party library needed. |
| `NSPasteboard` + `CGEvent` (fallback) | Clipboard paste when AX injection fails | Some apps (Electron, some web browsers) do not expose writable AX attributes; paste via cmd+v is the universal fallback |

**Accessibility injection pattern:**

```swift
// Get the focused element
var focusedElement: AnyObject?
AXUIElementCopyAttributeValue(
    AXUIElementCreateSystemWide(),
    kAXFocusedUIElementAttribute as CFString,
    &focusedElement
)

// Set value or insert text
if let element = focusedElement as! AXUIElement? {
    AXUIElementSetAttributeValue(
        element,
        kAXSelectedTextAttribute as CFString,  // replaces selection
        insertedText as CFTypeRef
    )
}
```

**Required entitlement/permission:** Accessibility must be granted by the user via System Settings > Privacy & Security > Accessibility. The app must request this at first launch with a clear explanation. This is a hard requirement — without it the AX API silently fails.

**Note on `kAXValueAttribute` vs `kAXSelectedTextAttribute`:** Use `kAXSelectedTextAttribute` to insert at cursor (replaces current selection or inserts at caret). Using `kAXValueAttribute` overwrites the entire field content — almost never what you want.

**Paste fallback implementation:**

```swift
// Write to pasteboard, then simulate Cmd+V
NSPasteboard.general.setString(text, forType: .string)
let src = CGEventSource(stateID: .hidSystemState)
CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)?
    .post(tap: .cgAnnotatedSessionEventTap)
```

**Confidence: HIGH** — AXUIElement is a stable, documented macOS framework (no external library). Patterns are well-established in the macOS dictation tool ecosystem.

---

### Supporting Libraries

| Library | Version | Purpose | Source |
|---------|---------|---------|--------|
| `sindresorhus/KeyboardShortcuts` | latest (SPM) | User-configurable global hotkeys, Mac App Store safe, SwiftUI `Recorder` component | Context7 verified |
| `kishikawakatsumi/KeychainAccess` | latest (SPM) | Store Groq API key in system Keychain; simple subscript API | Context7 verified (benchmark 98) |
| `sindresorhus/LaunchAtLogin-modern` | latest (SPM) | Login item management for macOS 13+; one-line SwiftUI toggle | Context7 verified |
| `groue/GRDB.swift` | v7.5.0 | SQLite-backed history of transcriptions; full query/observation support | Context7 verified |
| `sindresorhus/Defaults` | latest (SPM) | Type-safe UserDefaults wrapper for all app preferences (output mode, profile selection, etc.) | Context7 verified |

**KeyboardShortcuts is the definitive choice** for global hotkeys on macOS. It is sandbox-compatible, supports SwiftUI and AppKit, and provides a ready-made `Recorder` UI. The `onKeyDown` / `onKeyUp` distinction is important for push-to-talk: use `onKeyDown` to start recording and `onKeyUp` to stop.

```swift
extension KeyboardShortcuts.Name {
    static let startDictation = Self("startDictation")
}

// In AppState init:
KeyboardShortcuts.onKeyDown(for: .startDictation) { startRecording() }
KeyboardShortcuts.onKeyUp(for: .startDictation) { stopRecordingAndTranscribe() }
```

**GRDB vs SwiftData:** GRDB is preferred over SwiftData for this project. SwiftData (iOS 17/macOS 14) has poor support for full-text search and complex queries. GRDB's FTS5 support makes the "searchable history" feature straightforward.

---

## What NOT to Use

| Technology | Why Avoid |
|------------|-----------|
| **Electron / web tech** | Mentioned for completeness: no reason to consider it; Swift/SwiftUI is the correct choice |
| **CoreML for Parakeet** | Conversion from NeMo weights to CoreML loses model-specific optimizations; NVIDIA does not publish a CoreML export path for Parakeet v3. High conversion effort, uncertain quality. |
| **Cloud transcription** | Explicitly out of scope per PROJECT.md; privacy requirement |
| **SwiftData for history** | Weak full-text search; GRDB has FTS5 built in which is needed for the searchable history feature |
| **Third-party OpenAI Swift SDK** | Only 2 API calls needed; a whole SDK dependency adds complexity for no gain. Use URLSession directly. |
| **AVAudioRecorder** | Writes to disk; adds a file roundtrip before ML inference. AVAudioEngine tap pattern is cleaner. |
| **Python Django/FastAPI server** | Don't run a local HTTP server for the Parakeet bridge. A subprocess with stdin/stdout or a Unix domain socket is lighter and doesn't require port management. |
| **WhisperKit as primary** | Whisper is a different (weaker) model than Parakeet for English. Use WhisperKit only as a fallback if Parakeet integration is blocked. |

---

## Confidence Notes

| Area | Confidence | Basis |
|------|------------|-------|
| SwiftUI MenuBarExtra + LSUIElement | HIGH | Apple SwiftUI official docs (Context7) |
| AVFoundation audio capture | HIGH | Standard macOS pattern; no exotic APIs |
| Parakeet = Python/MLX only (no Swift binary) | HIGH | Context7: parakeet-mlx is Python; MLX Swift is separate |
| Subprocess bridge for Parakeet | MEDIUM | Pattern is sound; exact Python bundling in a signed/notarized app needs hands-on validation |
| MLX Swift direct port feasibility | LOW | Technically possible but effort is unverified; no prior art in Context7 |
| Groq REST API / no official Swift SDK | HIGH | Context7 Groq docs confirm Python + JS only; REST is standard |
| AXUIElement text injection | HIGH | Documented macOS API; widely used by dictation tools (VoiceInk, Whisper transcription apps) |
| KeyboardShortcuts / KeychainAccess / GRDB | HIGH | All verified in Context7 with high benchmark scores |
| LaunchAtLogin-modern | HIGH | Context7 verified; macOS 13+ only which matches target |
| Parakeet-tdt-0.6b-v3 model size ~1.2GB | MEDIUM | Inferred from MLX community model naming; exact size needs verification at download time |

---

## Installation (Swift Package Manager)

```swift
// Package.swift dependencies
.package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
.package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),
.package(url: "https://github.com/sindresorhus/LaunchAtLogin-modern", from: "1.0.0"),
.package(url: "https://github.com/groue/GRDB.swift", from: "7.5.0"),
.package(url: "https://github.com/sindresorhus/Defaults", from: "8.0.0"),
```

Python runtime and parakeet-mlx are NOT Swift packages — they are bundled as a pre-built directory in the app's Resources folder. See ARCHITECTURE.md for the bundling strategy.

---

## Sources

- SwiftUI MenuBarExtra: `https://developer.apple.com/documentation/swiftui/menubarextra` (Context7: `/websites/developer_apple_swiftui`)
- parakeet-mlx Python library: `https://github.com/senstella/parakeet-mlx` (Context7: `/senstella/parakeet-mlx`)
- MLX Swift framework: `https://github.com/ml-explore/mlx-swift` (Context7: `/ml-explore/mlx-swift`)
- KeyboardShortcuts: `https://github.com/sindresorhus/KeyboardShortcuts` (Context7: `/sindresorhus/keyboardshortcuts`)
- KeychainAccess: `https://github.com/kishikawakatsumi/KeychainAccess` (Context7: `/kishikawakatsumi/keychainaccess`)
- LaunchAtLogin-modern: `https://github.com/sindresorhus/LaunchAtLogin-modern` (Context7: `/sindresorhus/launchatlogin-modern`)
- GRDB.swift: `https://github.com/groue/GRDB.swift` (Context7: `/groue/grdb.swift`)
- Defaults: `https://github.com/sindresorhus/defaults` (Context7: `/sindresorhus/defaults`)
- Groq API reference: `https://console.groq.com/docs/api-reference` (Context7: `/websites/console_groq`)
- WhisperKit (noted as alternative): `https://github.com/argmaxinc/whisperkit` (Context7: `/argmaxinc/whisperkit`)
