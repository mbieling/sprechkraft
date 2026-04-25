# Phase 7: Parakeet Backend - Pattern Map

**Mapped:** 2026-04-24
**Files analyzed:** 7 (3 new, 4 modified)
**Analogs found:** 7 / 7

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `VoiceScribe/Transcription/TranscriptionBackend.swift` | protocol | request-response | `VoiceScribe/Transcription/TranscriptionService.swift` | role-match (defines contract that service implements) |
| `VoiceScribe/Transcription/ParakeetBackend.swift` | service/actor | request-response | `VoiceScribe/Transcription/TranscriptionService.swift` | exact (same role: ML actor, same data flow: download + transcribe) |
| `VoiceScribe/Transcription/WhisperKitBackend.swift` | service/actor | request-response | `VoiceScribe/Transcription/TranscriptionService.swift` | exact (same structure, fully commented-out) |
| `VoiceScribe/Transcription/TranscriptionService.swift` | service/actor (facade) | request-response | `VoiceScribe/Transcription/TranscriptionService.swift` | self (modify in-place, strip WhisperKit, add delegation) |
| `VoiceScribe/AppState.swift` | model/state | event-driven | `VoiceScribe/AppState.swift` | self (extend RecordingState enum, add isModelError property) |
| `VoiceScribe/StatusBarIconView.swift` | component | event-driven | `VoiceScribe/StatusBarIconView.swift` | self (extend switch on RecordingState, add previews) |
| `VoiceScribe.xcodeproj/project.pbxproj` | config | — | `VoiceScribe.xcodeproj/project.pbxproj` | self (remove WhisperKit refs, add FluidAudio) |

---

## Pattern Assignments

### `VoiceScribe/Transcription/TranscriptionBackend.swift` (protocol, request-response)

**Analog:** `VoiceScribe/Transcription/TranscriptionService.swift`

The protocol mirrors the three public-facing methods already declared in `TranscriptionService`. The planner should define a protocol that `TranscriptionService` forwards to and `ParakeetBackend` implements.

**Imports pattern** — copy from TranscriptionService.swift (file header only; protocol file needs no framework imports):
```swift
// No framework imports needed for a pure protocol file.
// Foundation is available implicitly in Swift modules.
```

**Core protocol pattern** — derived from TranscriptionService.swift lines 20, 27-29, 92-95 and D-11:
```swift
protocol TranscriptionBackend: Sendable {
    /// true after a successful downloadAndLoad() call.
    var isModelReady: Bool { get async }

    /// Downloads and loads the model. progressHandler: 0.0 = start, 1.0 = done.
    /// Silent return on error — caller checks isModelReady afterward.
    func downloadAndLoad(
        progressHandler: @MainActor @escaping (Double) -> Void
    ) async

    /// Transcribes pre-resampled 16 kHz Float samples.
    /// Returns nil on error or if model is not loaded.
    func transcribeWithResampling(
        _ samples: [Float],
        sampleRate: Double
    ) async -> String?
}
```

**Sendable note:** Actors are `Sendable` by default. Do NOT add `@unchecked Sendable` (FluidAudio CLAUDE.md forbids it; existing project has no precedent for it either).

---

### `VoiceScribe/Transcription/ParakeetBackend.swift` (actor, request-response)

**Analog:** `VoiceScribe/Transcription/TranscriptionService.swift`

**Imports pattern** — modeled after TranscriptionService.swift lines 9-10:
```swift
// TranscriptionService.swift (current, lines 9-10):
import AVFoundation
@preconcurrency import WhisperKit
```
For ParakeetBackend, replace WhisperKit with FluidAudio:
```swift
import FluidAudio   // @preconcurrency import FluidAudio  if Swift-6 Sendable warning appears (D-12)
```
AVFoundation is NOT needed in the backend (resampling stays in TranscriptionService per D-13).

**Actor declaration pattern** — modeled after TranscriptionService.swift line 12 and RESEARCH.md Pattern 2:
```swift
// TranscriptionService.swift line 12:
actor TranscriptionService {

// ParakeetBackend follows same pattern:
actor ParakeetBackend: TranscriptionBackend {
    private var asrManager: AsrManager?
    private(set) var isModelReady: Bool = false
}
```

**downloadAndLoad pattern** — modeled after TranscriptionService.swift lines 27-58 (guard, do/catch, silent return):
```swift
// TranscriptionService.swift lines 31-58 (structure to copy):
func downloadAndLoad(
    progressHandler: @MainActor @escaping (Double) -> Void
) async {
    guard !isModelReady else { return }      // ← same guard
    do {
        // ... download logic ...
        isModelReady = true
    } catch {
        print("Download-Fehler: \(error)")   // ← same silent-return pattern (D-13)
        // isModelReady stays false
    }
}
```

**FluidAudio-specific download body** (RESEARCH.md Pattern 2 — no native progress, send 0.0 + 1.0 only):
```swift
await progressHandler(0.0)   // signal: download started

let models = try await AsrModels.downloadAndLoad(version: .v3)
let manager = AsrManager(config: .default)
try await manager.loadModels(models)

// Warmup: Metal Shader JIT (Pitfall I8 — 5-15s ohne Warmup)
let dummySamples = [Float](repeating: 0.0, count: 16000) // 1s silence @ 16kHz
_ = try? await manager.transcribe(dummySamples, source: .microphone)

self.asrManager = manager
self.isModelReady = true
await progressHandler(1.0)
```

**transcribeWithResampling pattern** — modeled after TranscriptionService.swift lines 62-85 (guard, do/catch, nil return, trimming):
```swift
// TranscriptionService.swift lines 66-85 (structure to copy):
func transcribe(_ samples: [Float]) async -> String? {
    guard let pipe = whisperKit, isModelReady else { return nil }
    guard samples.count >= 1600 else { return nil }   // ← same minimum-sample guard
    do {
        // ... inference ...
        return results...trimmingCharacters(in: .whitespaces)
    } catch {
        print("Transkriptionsfehler: \(error)")       // ← same silent-return pattern
        return nil
    }
}
```

FluidAudio-specific transcription body (RESEARCH.md Code Examples):
```swift
func transcribeWithResampling(_ samples: [Float], sampleRate: Double) async -> String? {
    guard let manager = asrManager, isModelReady else { return nil }
    guard samples.count >= 1600 else { return nil }
    do {
        let result = try await manager.transcribe(samples, source: .microphone)
        let text = result.text.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    } catch {
        print("[ParakeetBackend] Transkriptionsfehler: \(error)")
        return nil
    }
}
```

---

### `VoiceScribe/Transcription/WhisperKitBackend.swift` (actor, request-response — commented out)

**Analog:** `VoiceScribe/Transcription/TranscriptionService.swift` (full file)

This file is the CURRENT `TranscriptionService.swift` content wrapped in a new actor name and fully wrapped in block comments (`/* ... */`). The planner should:
1. Copy the entire content of the current `TranscriptionService.swift`
2. Rename the actor from `TranscriptionService` to `WhisperKitBackend`
3. Add `: TranscriptionBackend` conformance declaration
4. Wrap everything in `/* ... */` block comment
5. Add a header comment explaining: "Reaktivieren: SPM-Dependency https://github.com/argmaxinc/argmax-oss-swift hinzufügen + Block-Kommentar entfernen"

The full source to copy from is `VoiceScribe/Transcription/TranscriptionService.swift` lines 1-158.

---

### `VoiceScribe/Transcription/TranscriptionService.swift` (actor facade, request-response — MODIFY)

**Analog:** `VoiceScribe/Transcription/TranscriptionService.swift` (self — rewrite keeping resampleTo16kHz)

**What to keep unchanged:**
- The entire `resampleTo16kHz` method (lines 103-157) — copy verbatim, D-13
- The `actor TranscriptionService` declaration (actor isolation pattern)
- The `downloadAndLoad(progressHandler:)` signature (AppDelegate calls this — API-stable)
- The `transcribeWithResampling(_:sampleRate:)` signature (AppDelegate calls this — API-stable)
- The `isModelReady: Bool` property (AppDelegate reads this after setup)

**What to replace:**
- Lines 9-10: Remove `import AVFoundation` and `@preconcurrency import WhisperKit`; add nothing (backend handles its own imports)
- Lines 16-58: Replace WhisperKit-specific properties and downloadAndLoad body with backend delegation
- Lines 62-95: Replace `transcribe(_:)` and old `transcribeWithResampling` body with facade delegation

**New facade pattern** (RESEARCH.md Pattern 3):
```swift
// New imports — only AVFoundation for resampleTo16kHz
import AVFoundation

actor TranscriptionService {
    private let backend: any TranscriptionBackend

    init(backend: any TranscriptionBackend = ParakeetBackend()) {
        self.backend = backend
    }

    var isModelReady: Bool {
        get async { await backend.isModelReady }
    }

    func downloadAndLoad(
        progressHandler: @MainActor @escaping (Double) -> Void
    ) async {
        await backend.downloadAndLoad(progressHandler: progressHandler)
    }

    func transcribeWithResampling(_ samples: [Float], sampleRate: Double) async -> String? {
        let samples16k = resampleTo16kHz(samples, fromSampleRate: sampleRate)
        return await backend.transcribeWithResampling(samples16k, sampleRate: 16000.0)
    }

    // resampleTo16kHz — UNCHANGED (copy verbatim from current file lines 103-157)
}
```

**AppDelegate call sites stay untouched** — the facade preserves all three method signatures exactly as called in `AppDelegate.swift` lines 444, 451, and 102.

---

### `VoiceScribe/AppState.swift` (model/state — MODIFY)

**Analog:** `VoiceScribe/AppState.swift` (self — extend in-place)

**RecordingState enum extension** — copy the existing switch pattern from lines 23-66 and add three new cases. The pattern for each computed property is exhaustive switch — all cases must be added or the build fails.

**New cases to add after `.error` (line 17):**
```swift
// AppState.swift lines 12-17 (existing enum head — copy pattern):
enum RecordingState: Equatable {
    case idle
    case recording
    case transcribing
    case llmProcessing
    case error          // existing
    case modelLoading   // NEW (D-06)
    case warmingUp      // NEW (D-03)
    case modelError     // NEW (D-09)
}
```

**`color` extension** — add after `.error` case in the switch (lines 23-29, copy pattern):
```swift
// Existing pattern to copy from lines 24-29:
var color: Color {
    switch self {
    case .idle:          return Color(red: 0.557, green: 0.557, blue: 0.576)
    case .recording, .error: return Color(.systemRed)
    // ... add:
    case .modelLoading, .warmingUp: return Color(.systemOrange)
    case .modelError:               return Color(.systemRed)
    }
}
```

**`systemImage` extension** — add after `default: return "mic.fill"` (lines 33-39, copy pattern):
```swift
// Existing pattern to copy from lines 32-40:
var systemImage: String {
    switch self {
    case .error:  return "exclamationmark.triangle.fill"
    // ... add:
    case .modelLoading: return "arrow.down.circle"
    case .warmingUp:    return "hourglass"
    case .modelError:   return "exclamationmark.triangle.fill"
    default:            return "mic.fill"
    }
}
```

**`isPulsing` extension** — extend condition (line 44):
```swift
// Current (line 44):
var isPulsing: Bool {
    self == .recording || self == .llmProcessing
}
// New — add .modelLoading (spinner effect):
var isPulsing: Bool {
    self == .recording || self == .llmProcessing || self == .modelLoading
}
```

**`pulseSpeed` extension** — add new cases to switch (lines 48-55):
```swift
// Existing pattern (lines 49-55):
var pulseSpeed: Double? {
    switch self {
    case .recording:     return 0.8
    case .llmProcessing: return 1.2
    // ... add:
    case .modelLoading:  return 1.0   // medium pace for download spinner
    default:             return nil
    }
}
```

**`accessibilityLabel` extension** — add new cases (lines 58-66):
```swift
// Existing pattern (lines 59-66):
var accessibilityLabel: String {
    switch self {
    // ... add:
    case .modelLoading: return "VoiceScribe — Modell wird geladen"
    case .warmingUp:    return "VoiceScribe — Modell wird vorbereitet"
    case .modelError:   return "VoiceScribe — Modellfehler"
    }
}
```

**New AppState property** — add after `isModelReady` (lines 84-87, copy same Bool pattern):
```swift
// Existing pattern to copy (lines 84-87):
/// true nach erfolgreichem Modell-Download via TranscriptionService.
var isModelReady: Bool = false

// New property (D-08):
/// true wenn Download oder Load von ParakeetBackend fehlschlägt.
/// Analog zu isModelReady. Wird in AppDelegate.setupTranscription() gesetzt.
var isModelError: Bool = false
```

---

### `VoiceScribe/StatusBarIconView.swift` (component — MODIFY)

**Analog:** `VoiceScribe/StatusBarIconView.swift` (self — add previews for new states)

The view body itself requires NO changes — it already uses `state.systemImage`, `state.color`, `state.pulseSpeed`, and the `applyAnimation(for:)` pattern which all delegate to the RecordingState computed properties extended above.

**Only add `#Preview` blocks** at the end of the file (lines 96-114 show existing preview pattern to copy):
```swift
// Existing preview pattern (lines 96-114):
#Preview("Idle") {
    StatusBarIconView(state: .idle, audioLevel: 0.0).padding()
}

// Add new previews following same pattern:
#Preview("Model Loading") {
    StatusBarIconView(state: .modelLoading, audioLevel: 0.0).padding()
}

#Preview("Warming Up") {
    StatusBarIconView(state: .warmingUp, audioLevel: 0.0).padding()
}

#Preview("Model Error") {
    StatusBarIconView(state: .modelError, audioLevel: 0.0).padding()
}
```

---

### `VoiceScribe.xcodeproj/project.pbxproj` (config — MODIFY)

**No code analog** — mechanical surgery per RESEARCH.md Pitfall 7.

**Identifiers to remove** (5 locations — ALL must be removed or build fails):
| Identifier | Section | Line range |
|---|---|---|
| `CAFE0028` | `PBXBuildFile` | L41 |
| `CAFE0028` | `PBXFrameworksBuildPhase` | L89 |
| `BEEF0028` | `XCSwiftPackageProductDependency` | L683-687 |
| `DEAD0103` | `XCRemoteSwiftPackageReference` | L641-648 |
| `DEAD0103` | `packageReferences` array | L308 |

**FluidAudio to add** (SPM URL from RESEARCH.md):
```
https://github.com/FluidInference/FluidAudio.git, from: "0.12.4"
```
Preferred approach: add via Xcode UI (File > Add Package Dependencies) — Xcode auto-generates all 5 pbxproj sections with correct UUIDs. Manual pbxproj editing for addition is error-prone.

---

## Shared Patterns

### Actor isolation for ML services
**Source:** `VoiceScribe/Transcription/TranscriptionService.swift` line 12
**Apply to:** `ParakeetBackend.swift`, facade `TranscriptionService.swift`
```swift
actor TranscriptionService {   // ← pattern: ML services are actors
```
All public methods on these actors are implicitly async and serialized. No manual locking needed.

### Silent error return (D-13)
**Source:** `VoiceScribe/Transcription/TranscriptionService.swift` lines 55-58 and 81-84
**Apply to:** `ParakeetBackend.swift` (both downloadAndLoad and transcribeWithResampling)
```swift
} catch {
    print("Download-Fehler: \(error)")   // print only — no throw, no user alert
    // isModelReady stays false — caller checks the property
}
```

### progressHandler signature
**Source:** `VoiceScribe/Transcription/TranscriptionService.swift` lines 27-29
**Apply to:** `TranscriptionBackend` protocol, `ParakeetBackend.downloadAndLoad`
```swift
func downloadAndLoad(
    progressHandler: @MainActor @escaping (Double) -> Void
) async {
```
This signature is called from `AppDelegate.setupTranscription()` (line 444). Any change breaks the call site.

### Observation-B icon update pattern
**Source:** `VoiceScribe/AppDelegate.swift` lines 421-435
**Apply to:** All new AppState state mutations in `setupTranscription()` modification
```swift
// After every state mutation, call updateIcon() manually:
appState?.recordingState = .modelLoading
updateIcon()
// ... later ...
appState?.recordingState = .idle
updateIcon()
```

### @MainActor Task dispatch in setupTranscription
**Source:** `VoiceScribe/AppDelegate.swift` lines 443-454
**Apply to:** Modified `setupTranscription()` in AppDelegate
```swift
// Existing pattern (lines 443-454):
private func setupTranscription() {
    Task {
        await transcriptionService.downloadAndLoad { [weak self] fraction in
            // @MainActor closure — safe to update UI here
            let pct = Int(fraction * 100)
            self?.statusItem.button?.title = pct < 100 ? "↓ \(pct)%" : ""
        }
        statusItem.button?.title = ""
        appState?.isModelReady = await transcriptionService.isModelReady
        updateIcon()
    }
}
```

### Bool-flag property pattern on AppState
**Source:** `VoiceScribe/AppState.swift` lines 83-88 (`isModelReady`) and lines 92-96 (`axPermissionDenied`)
**Apply to:** New `isModelError: Bool` property
```swift
// Pattern (lines 83-88):
/// One-line doc comment explaining setter.
var isModelReady: Bool = false
// isModelError follows exact same structure: var, Bool, = false, one-line comment.
```

### Swift Testing test structure
**Source:** `VoiceScribeTests/RecordingStateTests.swift` and `VoiceScribeTests/TranscriptionServiceTests.swift`
**Apply to:** All test modifications in Wave 0
```swift
// Import pattern (RecordingStateTests.swift lines 1-3):
import Testing
import SwiftUI
@testable import VoiceScribe

// Suite + Test pattern (lines 5-11):
@Suite("RecordingState (FEED-01)")
struct RecordingStateTests {
    @Test("beschreibung des Tests")
    func testName() {
        #expect(condition)
    }
}
```

---

## No Analog Found

All files have close analogs. No entries.

---

## Metadata

**Analog search scope:** `VoiceScribe/`, `VoiceScribeTests/`
**Files read:** 7 source files + 2 planning files
**Pattern extraction date:** 2026-04-24

**Critical pitfalls for planner to highlight in plans:**
1. Pitfall 5 (RESEARCH.md): `RecordingStateTests.caseCount()` expects `count == 4` — must be updated to 7 and all 5 switch extensions must cover new cases or build fails.
2. Pitfall 6 (RESEARCH.md): `TranscriptionServiceTests` calls `service.transcribe(shortAudio)` — method name changes to `transcribeWithResampling`; tests need mock backend injection.
3. Pitfall 7 (RESEARCH.md): pbxproj has WhisperKit at exactly 5 locations — all must be removed together; partial removal causes unresolved-package build errors.
4. Pitfall 4 (RESEARCH.md): `@preconcurrency import WhisperKit` must be removed from `TranscriptionService.swift` — it becomes a build error once the SPM dependency is gone.
