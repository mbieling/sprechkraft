<!-- GSD:project-start source:PROJECT.md -->
## Project

**VoiceScribe: Lokale Diktat-App für macOS**

Eine native macOS Menu-Bar-App für systemweites Diktat. Der Nutzer hält einen globalen Hotkey gedrückt, spricht, lässt los — und der Text erscheint entweder direkt im aktiven Textfeld oder im Clipboard. Transkription läuft vollständig lokal via Parakeet v3 (gebundelt in der App). Optional durchläuft das Transkript eines von mehreren KI-Prompt-Profilen via Groq API (qwen/qwen3-32b), bevor der Text ausgegeben wird.

Inspiration: https://tryvoiceink.com

**Core Value:** Text per Sprache eingeben, genau wie tippen — schnell, systemweit, ohne Fenster wechseln zu müssen.
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### Core Framework
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Swift | 6.x (swift-6.1.2-RELEASE) | Primary language | Native macOS, first-class Accessibility API access, best performance on Apple Silicon, no bridging overhead |
| SwiftUI | macOS 14+ | UI layer | `MenuBarExtra` scene type (macOS 13+) handles menu-bar-only apps natively; LSUIElement=true hides dock icon |
| AppKit (NSStatusItem) | — | Menu bar icon animation | SwiftUI `MenuBarExtra` is backed by AppKit; drop to AppKit for fine-grained icon animation control if needed |
### Audio Capture
| Technology | Purpose | Why |
|------------|---------|-----|
| AVFoundation (`AVAudioEngine`) | Microphone capture, push-to-talk buffer accumulation | Higher-level than Core Audio, Swift-native API, supports `installTap(onBus:bufferSize:format:block:)` for real-time PCM buffer access |
| `AVAudioSession` | (macOS: no-op / implicit) | On macOS the session is managed automatically; no explicit `AVAudioSession` activation needed unlike iOS |
### Local ML / Parakeet Integration
| Approach | Verdict | Notes |
|----------|---------|-------|
| **Python subprocess via bundled venv** | RECOMMENDED | parakeet-mlx is Python, MLX-accelerated, targets Apple Silicon. Bundle a minimal Python env + weights in the app. |
| MLX Swift (direct port) | POSSIBLE but high effort | MLX Swift exists and shares the same Metal backend. You'd need to port the RNNT/TDT decoder yourself — non-trivial. |
| CoreML conversion | POSSIBLE but lossy | ONNX/CoreML export path exists for Parakeet but loses MLX-specific optimizations; accuracy may differ. |
| ONNX Runtime | POSSIBLE fallback | parakeet-rs (Rust) shows ONNX path works; `onnxruntime-objc` or a C wrapper could bridge to Swift. Higher integration complexity. |
### LLM Integration (Groq)
| Technology | Purpose | Why |
|------------|---------|-----|
| Groq REST API (OpenAI-compatible) | Post-processing transcripts via qwen/qwen3-32b | No official Swift SDK exists; the API is simple HTTP — use URLSession directly |
| `URLSession` (built-in Swift/Foundation) | HTTP client | Zero dependencies, async/await native in Swift 6, sufficient for single-shot chat completions |
### Text Injection (Accessibility)
| Technology | Purpose | Why |
|------------|---------|-----|
| macOS Accessibility API (`AXUIElement`) | Inject text into focused field in any app | Only system-level mechanism for writing into another app's text field. No third-party library needed. |
| `NSPasteboard` + `CGEvent` (fallback) | Clipboard paste when AX injection fails | Some apps (Electron, some web browsers) do not expose writable AX attributes; paste via cmd+v is the universal fallback |
### Supporting Libraries
| Library | Version | Purpose | Source |
|---------|---------|---------|--------|
| `sindresorhus/KeyboardShortcuts` | latest (SPM) | User-configurable global hotkeys, Mac App Store safe, SwiftUI `Recorder` component | Context7 verified |
| `kishikawakatsumi/KeychainAccess` | latest (SPM) | Store Groq API key in system Keychain; simple subscript API | Context7 verified (benchmark 98) |
| `sindresorhus/LaunchAtLogin-modern` | latest (SPM) | Login item management for macOS 13+; one-line SwiftUI toggle | Context7 verified |
| `groue/GRDB.swift` | v7.5.0 | SQLite-backed history of transcriptions; full query/observation support | Context7 verified |
| `sindresorhus/Defaults` | latest (SPM) | Type-safe UserDefaults wrapper for all app preferences (output mode, profile selection, etc.) | Context7 verified |
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
## Installation (Swift Package Manager)
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
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
