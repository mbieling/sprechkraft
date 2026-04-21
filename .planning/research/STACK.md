# Stack Research

**Project:** VoiceScribe — macOS Menu Bar Dictation App
**Researched:** 2026-04-15 (updated 2026-04-21: Parakeet + Settings Additions)
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

Bundle a minimal Python 3.12 environment (via `uv` + `python-build-standalone`) alongside `parakeet-mlx`. Swift spawns a long-lived child process and communicates via stdin/stdout.

Architecture:
```
VoiceScribeApp (Swift)
    ├─ writes raw PCM audio to temp WAV file
    ├─ writes WAV path as text line to subprocess stdin
    │      └─ bundled Python process (persistent daemon):
    │             - loads parakeet-mlx model once at startup
    │             - reads path from stdin, transcribes, prints JSON to stdout
    └─ reads JSON transcript from subprocess stdout
```

**WhisperKit as a fallback/comparison:** `argmaxinc/whisperkit` is a fully native Swift framework for Whisper models on Apple Silicon (CoreML + Metal). It is drop-in usable from Swift. If Parakeet integration proves brittle, WhisperKit is the best native Swift alternative, accepting the model change. Keep this in your back pocket.

**Confidence: MEDIUM** — parakeet-mlx confirmed Python/MLX-only (Context7). Subprocess pattern is standard macOS practice but exact bundling mechanics need hands-on validation.

---

#### Python Environment Bundling (Milestone v0.19.0 Addition)

**Kein System-Python. Kein Homebrew-Python. Alles im .app-Bundle.**

**Empfohlener Bundling-Ansatz: `uv` + `py-app-standalone`**

| Tool | Rolle | Version |
|------|-------|---------|
| `uv` (Astral) | Build-Zeit-Tool; laedt CPython 3.12 aus `python-build-standalone` runter, erstellt relocatable venv | >= 0.6 (nicht mitliefern) |
| `py-app-standalone` | Wrapper-Script; automatisiert `install_name_tool`-Fix fuer macOS `.dylib`-absolute-Pfade | aktuell (GitHub: jlevy/py-app-standalone) |
| `python-build-standalone` (CPython) | Selbststaendige, portable CPython-Distribution ohne externe Abhaengigkeiten | Python 3.12.x (via uv python install) |

**Warum nicht direkt `uv venv --relocatable` allein:** uv's `--relocatable`-Flag loest venv-interne Symlinks auf, behebt aber NICHT die absoluten Pfade, die `install_name_tool` in den `.dylib`-Shared-Libraries eincodiert. `py-app-standalone` uebernimmt diesen Fix automatisch und erzeugt ein Bundle-Verzeichnis ohne absolute Pfade.

**Ziel-Layout im .app-Bundle:**

```
VoiceScribe.app/
  Contents/
    Resources/
      py-runtime/                  <- kopierte venv (Python-Binary + site-packages)
        bin/
          python3
        lib/
          python3.12/
            site-packages/
              parakeet_mlx/
              mlx/
              numpy/
              ...
      transcribe.py                <- Bridge-Script
```

**Python-Abhaengigkeiten in der gebundelten venv:**

| Paket | Zweck | Hinweis |
|-------|-------|---------|
| `parakeet-mlx` (latest) | Parakeet v3 Inferenz auf MLX | Zieht mlx, numpy, soundfile transitiv |
| `mlx` (via parakeet-mlx) | Apple Silicon Metal-Backend | Transitive Abhaengigkeit |
| `numpy` (via parakeet-mlx) | Array-Verarbeitung | Transitive Abhaengigkeit |

**Nicht explizit installieren:** `ffmpeg` (nur fuer parakeet-mlx CLI), `sounddevice`, `pyaudio` (Audio-Capture passiert in Swift).

**Modell-Gewichte:**

- Modell-ID: `mlx-community/parakeet-tdt-0.6b-v3`
- Groesse: **~2.5 GB** (MLX quantisiertes Format; bestaetigt via Hugging Face Model Card)
- 8-Bit-Variante: `animaslabs/parakeet-tdt-0.6b-v3-mlx-8bit` (kleiner, Qualitaet ungetestet)
- Download-Strategie: **NICHT im .app-Bundle** — beim Erststart via `from_pretrained(..., cache_dir=...)` in `~/Library/Application Support/VoiceScribe/models/` laden
- `cache_dir`-Parameter von parakeet-mlx unterstuetzt (Context7 bestaetigt)

**Build-Phase-Script (Xcode Shell Script Build Phase):**

```bash
#!/bin/bash
RUNTIME_DIR="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/py-runtime"
if [ ! -d "$RUNTIME_DIR" ]; then
  # py-app-standalone kapselt uv + install_name_tool-Fix
  py-app-standalone create --python 3.12 --output "$RUNTIME_DIR"
  uv pip install --python "${RUNTIME_DIR}/bin/python3" parakeet-mlx
fi
```

**Confidence: MEDIUM** — Grundprinzip gut belegt; `install_name_tool`-Schritt benoetigt hands-on-Validierung im ersten Build.

---

#### Python-Bridge: Swift → Subprocess-Kommunikation

**Empfehlung: Foundation `Process` + `Pipe` (kein externes Swift-Paket noetig)**

| Option | Bewertung | Begruendung |
|--------|-----------|-------------|
| Foundation `Process` + `Pipe` | **EMPFOHLEN** | In Foundation enthalten; async/await via `Task`/`withCheckedContinuation`; fuer Push-to-Talk (ein Request, eine Response) voellig ausreichend |
| `swiftlang/swift-subprocess` | Optionale Verbesserung | Neu (Sept 2025), async-native, Context7 verifiziert; Mehrwert gegenueber Foundation fuer dieses simple Pattern minimal — vermeidet zusaetzliche Abhaengigkeit |
| Unix Domain Socket | Overkill | Benoetigt persistenten Daemon mit Socket-Verwaltung; fuer batchweise Transkription nicht noetig |

**Kommunikationsprotokoll:**

Das Python-Script laeuft als Daemon-Prozess (einmal starten, Modell laden, dann auf Anfragen warten).

- **Swift schreibt:** Pfad zur temporaeren WAV-Datei als UTF-8-Zeile + `\n` auf stdin
- **Python antwortet:** JSON-Zeile `{"text": "..."}` auf stdout
- **Warum WAV-Datei statt Raw-Bytes:** `parakeet_mlx.audio.load_audio()` erwartet einen Dateipfad (Context7-Docs bestaetigt); Serialisierung von numpy-Arrays via stdin ist fragiler; WAV-Datei in `NSTemporaryDirectory()` ist einfach zu debuggen

**Bridge-Script (`Resources/transcribe.py`):**

```python
import sys, json
from parakeet_mlx import from_pretrained

# cache_dir = erstes Argument (~/Library/Application Support/VoiceScribe/models/)
model = from_pretrained("mlx-community/parakeet-tdt-0.6b-v3",
                        cache_dir=sys.argv[1])

for line in sys.stdin:
    wav_path = line.strip()
    if not wav_path:
        continue
    result = model.transcribe(wav_path)
    print(json.dumps({"text": result.text}), flush=True)
```

**Swift-Seite (Foundation Process, vereinfacht):**

```swift
class TranscriptionBridge {
    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()

    func start() throws {
        let pythonURL = Bundle.main.url(
            forResource: "py-runtime/bin/python3", withExtension: nil)!
        let scriptURL = Bundle.main.url(
            forResource: "transcribe", withExtension: "py")!
        let modelCacheDir = /* ~/Library/Application Support/VoiceScribe/models */

        process.executableURL = pythonURL
        process.arguments = [scriptURL.path, modelCacheDir]
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        try process.run()
    }

    func transcribe(wavPath: String) async throws -> String {
        // WAV-Pfad an Python schreiben
        let line = (wavPath + "\n").data(using: .utf8)!
        stdinPipe.fileHandleForWriting.write(line)
        // JSON-Antwort lesen (eine Zeile)
        let data = stdoutPipe.fileHandleForReading.availableData
        let response = try JSONDecoder().decode(TranscriptResponse.self, from: data)
        return response.text
    }
}
```

**Confidence: HIGH** fuer das Grundmuster; **MEDIUM** fuer Daemon-Lebensdauer-Management (Crash-Recovery, App-Termination-Handler).

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

### Settings-Window (Milestone v0.19.0 Addition)

**Keine neuen SPM-Pakete benoetigt.** Alle benoetigten Libraries sind bereits im Stack.

| Bestandteil | Implementierung | Details |
|-------------|----------------|---------|
| Settings-Scene | `Settings { SettingsView() }` in `@main App` | SwiftUI-nativ seit macOS 13; oeffnet via Cmd+, aus dem App-Menue |
| Sidebar-Navigation | `NavigationSplitView` mit `columnVisibility` | Zweispaltig: Sidebar (Icons + Label) + Detail; macOS-konventes Look-and-Feel; bestaetigt via Apple Docs |
| Hotkey-Recorder | `KeyboardShortcuts.Recorder("Label:", name: .myShortcut)` | Bereits im Stack; Conflict-Detection eingebaut (Context7 bestaetigt) |
| Mikrofon-Auswahl | `Picker` mit `AVCaptureDevice.DiscoverySession` | Listet alle Audio-Input-Geraete auf; kein externes Paket |
| API-Key-Eingabe | `SecureField` + `KeychainAccess` | Bereits im Stack |
| Profil-Verwaltung | bestehende GRDB-Implementierung | Kein neues Paket; Profile-Editor wie in Phase 05 |
| Ausgabemodus-Toggle | `Defaults` + `Picker` | Bereits im Stack |
| Silence-Threshold | `Slider` + `Defaults` | Standard SwiftUI |
| Autostart | `LaunchAtLogin.Toggle()` | Bereits im Stack |

**Settings-Fenster-Sizing:** `.frame(minWidth: 520, idealWidth: 580)` auf dem Settings-RootView + `windowResizability(.contentSize)` auf der Settings-Scene.

**Sidebar-Sidebar-Toggle ausblenden:** `.toolbar(removing: .sidebarToggle)` auf dem List-View, da Settings-Fenster keine collapsible Sidebar braucht.

**Confidence: HIGH** — alles Standard-SwiftUI; `KeyboardShortcuts.Recorder` vollstaendig in Context7 dokumentiert.

---

## Was NICHT hinzufuegen (Milestone v0.19.0)

| Kandidat | Warum nicht |
|----------|-------------|
| `PythonKit` | Bindet Python-Interpreter via C-API ein; unnoetige Komplexitaet wenn nur ein Script ausgefuehrt wird. Foundation `Process` ist leichter. |
| `swiftlang/swift-subprocess` | Bringt nichts Wesentliches gegenueber Foundation `Process` fuer dieses einfache Request/Response-Pattern |
| `Caerbannog` (Swift Package) | Veroeffentlichungsstatus unklar; fuer Subprocess-Kommunikation ueberdimensioniert |
| `py2app` | Erzeugt Python-.app-Bundles — hilft nicht wenn Python ein Subprocess in einer Swift-.app ist |
| `ffmpeg` (systemweit/gebundelt) | Nicht benoetigt fuer parakeet-mlx Python API; nur fuer CLI-Modus |
| `sounddevice` / `pyaudio` Python-Pakete | Audio-Capture passiert in Swift via AVAudioEngine; Python bekommt fertige WAV-Datei |
| `Electron / web tech` | Mentioned for completeness: no reason to consider it |
| **CoreML for Parakeet** | Conversion from NeMo weights to CoreML loses model-specific optimizations |
| **Cloud transcription** | Explicitly out of scope per PROJECT.md; privacy requirement |
| **SwiftData for history** | Weak full-text search; GRDB has FTS5 built in |
| **Third-party OpenAI Swift SDK** | Only 2 API calls needed; URLSession is sufficient |
| **AVAudioRecorder** | Writes to disk; AVAudioEngine tap pattern is cleaner |

---

## Confidence-Uebersicht

| Bereich | Confidence | Basis |
|---------|------------|-------|
| SwiftUI MenuBarExtra + LSUIElement | HIGH | Apple SwiftUI official docs (Context7) |
| AVFoundation audio capture | HIGH | Standard macOS pattern |
| parakeet-mlx API (`transcribe`, `cache_dir`) | HIGH | Context7-Docs vollstaendig |
| Modell-Groesse ~2.5 GB (MLX quantisiert) | HIGH | Hugging Face mlx-community Model Card bestaetigt |
| Python-Bundling via uv + py-app-standalone | MEDIUM | Prinzip gut belegt; `install_name_tool`-Fix benoetigt hands-on-Validierung |
| Foundation Process + Pipe Bridge | HIGH | Standard macOS Pattern; Apple Developer Docs |
| WAV-Datei als Bridge-Format | HIGH | Direkte Unterstuetzung durch `load_audio()` in parakeet-mlx |
| Daemon-Prozess Lebensdauer-Management | MEDIUM | Pattern bekannt; Fehlerbehandlung / App-Termination braucht Validierung |
| Settings SwiftUI (NavigationSplitView) | HIGH | Apple Docs + KeyboardShortcuts Context7 |
| Groq REST API / kein offizielles Swift SDK | HIGH | Context7 Groq Docs bestaetigt |
| AXUIElement text injection | HIGH | Dokumentiertes macOS-Framework |
| KeyboardShortcuts / KeychainAccess / GRDB | HIGH | Context7-verifiziert |

---

## Installation (Swift Package Manager)

```swift
// Package.swift dependencies — unveraendert
.package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
.package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),
.package(url: "https://github.com/sindresorhus/LaunchAtLogin-modern", from: "1.0.0"),
.package(url: "https://github.com/groue/GRDB.swift", from: "7.5.0"),
.package(url: "https://github.com/sindresorhus/Defaults", from: "8.0.0"),
// Kein neues SPM-Paket fuer Parakeet/Settings benoetigt
```

Python-Runtime und parakeet-mlx sind KEINE Swift Packages — sie werden als vorbereitetes Verzeichnis in `Resources/py-runtime/` des App-Bundles eingebettet.

---

## Sources

- SwiftUI MenuBarExtra: `https://developer.apple.com/documentation/swiftui/menubarextra` (Context7: `/websites/developer_apple_swiftui`)
- parakeet-mlx Python library: `https://github.com/senstella/parakeet-mlx` (Context7: `/senstella/parakeet-mlx`)
- MLX Swift framework: `https://github.com/ml-explore/mlx-swift` (Context7: `/ml-explore/mlx-swift`)
- KeyboardShortcuts: `https://github.com/sindresorhus/KeyboardShortcuts` (Context7: `/sindresorhus/keyboardshortcuts`)
- KeychainAccess: `https://github.com/kishikawakatsuki/KeychainAccess` (Context7: `/kishikawakatsuki/keychainaccess`)
- LaunchAtLogin-modern: `https://github.com/sindresorhus/LaunchAtLogin-modern` (Context7: `/sindresorhus/launchatlogin-modern`)
- GRDB.swift: `https://github.com/groue/GRDB.swift` (Context7: `/groue/grdb.swift`)
- Defaults: `https://github.com/sindresorhus/defaults` (Context7: `/sindresorhus/defaults`)
- Groq API reference: `https://console.groq.com/docs/api-reference` (Context7: `/websites/console_groq`)
- WhisperKit (noted as alternative): `https://github.com/argmaxinc/whisperkit` (Context7: `/argmaxinc/whisperkit`)
- mlx-community/parakeet-tdt-0.6b-v3: `https://huggingface.co/mlx-community/parakeet-tdt-0.6b-v3`
- py-app-standalone: `https://github.com/jlevy/py-app-standalone`
- uv Python versions: `https://docs.astral.sh/uv/concepts/python-versions/`
- Foundation Process Apple Docs: `https://developer.apple.com/documentation/foundation/process/1411576-standardinput`
- SwiftUI NavigationSplitView: `https://developer.apple.com/documentation/swiftui/navigationsplitview`
- swift-subprocess (Swift Forums): `https://github.com/swiftlang/swift-subprocess` (Context7: `/swiftlang/swift-subprocess`)
