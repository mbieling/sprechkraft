# Phase 3: Transcription - Pattern Map

**Mapped:** 2026-04-18
**Files analyzed:** 5 (1 neu, 4 modifiziert)
**Analogs found:** 5 / 5

---

## File Classification

| Neue / Modifizierte Datei | Rolle | Data Flow | Naechster Analog | Match-Qualitaet |
|---------------------------|-------|-----------|------------------|-----------------|
| `SPRECHKRAFT/Transcription/TranscriptionService.swift` | service (actor) | request-response (async ML inference) | `SPRECHKRAFT/Audio/AudioController.swift` | role-match (service, @unchecked Sendable → actor) |
| `SPRECHKRAFT/Audio/AudioController.swift` | service | event-driven (render thread tap) | sich selbst (Erweiterung) | exact |
| `SPRECHKRAFT/AppState.swift` | model / state | — | sich selbst (Erweiterung) | exact |
| `SPRECHKRAFT/AppDelegate.swift` | controller / orchestration | request-response | sich selbst (Erweiterung) | exact |
| `SPRECHKRAFTTests/TranscriptionServiceTests.swift` | test | — | `SPRECHKRAFTTests/AudioControllerTests.swift` | exact |

---

## Pattern Assignments

### `SPRECHKRAFT/Transcription/TranscriptionService.swift` (actor, request-response)

**Analog:** `SPRECHKRAFT/Audio/AudioController.swift`

**Imports-Pattern** (AudioController.swift Zeilen 16–19 — adaptieren):
```swift
import AVFoundation
import WhisperKit
```
Kein `Defaults`-Import noetig. `AVFoundation` fuer `AVAudioConverter`, `WhisperKit` fuer ASR.

**Actor-Isolation-Pattern** (Analog: AudioController.swift Zeile 20 — `@unchecked Sendable`; TranscriptionService verwendet staerkeres `actor`):
```swift
// AudioController.swift:20 — Referenz-Pattern fuer Thread-Isolation
final class AudioController: @unchecked Sendable {

// TranscriptionService: actor statt @unchecked Sendable (staerkere Garantie moeglich da keine Render-Thread-Mutation)
actor TranscriptionService {
    private var whisperKit: WhisperKit?
    private(set) var isModelReady: Bool = false
}
```

**Weak-Referenz-Pattern auf AppState** (AudioController.swift Zeilen 37–38):
```swift
private weak var appState: AppState?
```
TranscriptionService braucht keine AppState-Referenz — Fortschritts-Callback wird vom Caller (AppDelegate) verwaltet (siehe AppDelegate-Pattern unten).

**Callback-Pattern fuer asynchrone Completion** (AudioController.swift Zeilen 41–45):
```swift
// AudioController.swift:41-45 — Vorbild fuer onRecordingComplete in AudioController
var onAutoStop: (() -> Void)?
var onLevelUpdate: (() -> Void)?

// Neuer Callback in AudioController (Erweiterung Phase 3) — gleiches Muster:
var onRecordingComplete: (([Float], Double) -> Void)?  // samples + sampleRate
```

**Main-Thread-Dispatch-Pattern fuer Callbacks** (AudioController.swift Zeilen 114–117):
```swift
// AudioController.swift:114-117 — exakt fuer progressHandler in downloadAndLoad() kopieren
Task { @MainActor [weak self] in
    self?.appState?.audioLevel = clampedLevel
    self?.onLevelUpdate?()
}
```
Im TranscriptionService wird `progressHandler` als `@MainActor @escaping (Double) -> Void` deklariert — gleicher Dispatch-Ansatz.

**Fehlerbehandlung-Pattern — stille Rueckkehr** (AudioController.swift Zeilen 66–70):
```swift
// AudioController.swift:66-70 — Fehler wird nicht propagiert, State wird zurueckgesetzt
case .denied:
    Task { @MainActor [weak self] in
        self?.appState?.micPermissionDenied = true
    }
    return
```
In TranscriptionService: `catch { print("Download-Fehler: \(error)"); return }` — gleiche stille-Rueckkehr-Semantik (D-12, D-13).

**Guard-Pattern vor kritischen Operationen** (AudioController.swift Zeilen 99, 129):
```swift
// AudioController.swift:99
guard let self else { return }

// AudioController.swift:150-152 — Defensive Guard vor Buffer-Verarbeitung
guard let channelData = buffer.floatChannelData?[0] else { return 0 }
let frameLength = Int(buffer.frameLength)
guard frameLength > 0 else { return 0 }
```
In TranscriptionService `transcribe()`: `guard let pipe = whisperKit, isModelReady else { return nil }` und `guard samples.count > 1600 else { return nil }`.

---

### `SPRECHKRAFT/Audio/AudioController.swift` — Erweiterung (event-driven, render thread)

**Analog:** sich selbst — additive Erweiterung, kein Pattern-Bruch

**Neue Properties** (analog zu bestehenden privaten Properties Zeilen 27–45):
```swift
// AudioController.swift:27-45 — Pattern fuer neue Properties
private var silenceAccumulator: TimeInterval = 0
private var lastDispatchedLevel: CGFloat = -1
var onAutoStop: (() -> Void)?
var onLevelUpdate: (() -> Void)?

// NEU in Phase 3 — gleiches Muster:
private var recordedSamples: [Float] = []
var onRecordingComplete: (([Float], Double) -> Void)?
```

**installTap-Erweiterung** (AudioController.swift Zeilen 97–118 — gleicher Render-Thread-Block):
```swift
// AudioController.swift:97-118 — bestehende Tap-Closure
engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
    guard let self else { return }
    let rms = self.calculateRMS(buffer: buffer)
    // ...RMS-Logik...

    // NEU: Sample-Akkumulation (nach RMS-Block einfuegen, vor lastDispatchedLevel-Guard)
    // Render-Thread-safe: recordedSamples nur hier geschrieben (@unchecked Sendable garantiert)
    if let channelData = buffer.floatChannelData?[0] {
        let count = Int(buffer.frameLength)
        let newSamples = Array(UnsafeBufferPointer(start: channelData, count: count))
        self.recordedSamples.append(contentsOf: newSamples)
    }
}
```

**stopRecording()-Erweiterung** (AudioController.swift Zeilen 127–133):
```swift
// AudioController.swift:127-133 — bisheriges stopRecording()
func stopRecording() {
    engine.inputNode.removeTap(onBus: 0)  // Pitfall 5: removeTap zuerst
    engine.stop()
    silenceAccumulator = 0
    lastDispatchedLevel = -1
}

// NEU: vor engine.stop() — Array-Kopie extrahieren, dann freigeben (Pitfall 5 RESEARCH.md)
let samples = recordedSamples                                    // Kopie (Value Type)
let sampleRate = engine.inputNode.outputFormat(forBus: 0).sampleRate
recordedSamples = []                                             // Original freigeben VOR Task-Dispatch
Task { @MainActor [weak self] in
    self?.onRecordingComplete?(samples, sampleRate)
}
```
Das `Task { @MainActor [weak self] in }` ist identisch mit dem `onAutoStop`-Dispatch-Pattern (Zeile 171–173).

---

### `SPRECHKRAFT/AppState.swift` — Erweiterung (model/state)

**Analog:** sich selbst — eine neue Property

**Bestehende Property-Deklarationen** (AppState.swift Zeilen 61–69 — Pattern fuer neue Property):
```swift
// AppState.swift:61-69
var recordingState: RecordingState = .idle
var audioLevel: CGFloat = 0.0
var micPermissionDenied: Bool = false

// NEU in Phase 3 — gleiches Deklarations-Muster:
var isModelReady: Bool = false
```
`@MainActor` gilt fuer die gesamte Klasse (Zeile 58) — keine zusaetzliche Annotation noetig.

---

### `SPRECHKRAFT/AppDelegate.swift` — Erweiterung (controller, request-response)

**Analog:** sich selbst — drei Erweiterungspunkte

**Neue Instance-Variable** (analog zu AppDelegate.swift Zeile 24):
```swift
// AppDelegate.swift:24 — bestehende Controller-Property
private var audioController: AudioController?

// NEU in Phase 3 — gleiches Muster:
private var transcriptionService = TranscriptionService()
```

**Download-Kickoff in applicationDidFinishLaunching** (AppDelegate.swift Zeilen 26–40 — nach `setupHotkey()`):
```swift
// AppDelegate.swift:38-40 — Ende von applicationDidFinishLaunching:
updateIcon()
setupHotkey()
// NEU: Download starten (D-09)
setupTranscription()

// Neue private Methode — Naming-Konvention analog zu setupHotkey() (Zeile 196):
private func setupTranscription() {
    Task {
        await transcriptionService.downloadAndLoad { [weak self] fraction in
            // @MainActor (Closure-Deklaration in downloadAndLoad)
            let pct = Int(fraction * 100)
            self?.statusItem.button?.title = pct < 100 ? "↓ \(pct)%" : ""
        }
        // Download abgeschlossen — isModelReady setzen, Title entfernen
        statusItem.button?.title = ""
        appState?.isModelReady = true
        updateIcon()
    }
}
```

**onRecordingComplete-Callback in setupAudioController()** (AppDelegate.swift Zeilen 47–59 — gleiches Callback-Verdrahtungs-Muster):
```swift
// AppDelegate.swift:53-59 — bestehende Callback-Verdrahtung
audioController?.onAutoStop = { [weak self] in
    self?.stopRecordingWithCue()
}
audioController?.onLevelUpdate = { [weak self] in
    self?.updateIcon()
}

// NEU in Phase 3 — gleiches [weak self]-Capture-Pattern:
audioController?.onRecordingComplete = { [weak self] samples, sampleRate in
    // Laeuft auf @MainActor (Task { @MainActor in } in stopRecording())
    guard let self else { return }
    Task {
        let text = await self.transcriptionService.transcribeWithResampling(samples, sampleRate: sampleRate)
        await MainActor.run {
            if let text { print("Transkription: \(text)") }  // D-07
            self.appState?.resetToIdle()                      // D-08
            self.updateIcon()
        }
    }
}
```

**Guard fuer Download-Block** (AppDelegate.swift Zeile 67 — bestehende Guard-Konvention):
```swift
// AppDelegate.swift:67 — bestehende Guard-Konvention in startRecordingWithCue()
guard appState?.recordingState == .idle else { return }

// NEU in Phase 3 — erweiterter Guard (D-11):
guard appState?.recordingState == .idle else { return }
guard appState?.isModelReady == true else { return }  // Hotkey blockiert waehrend Download
```

**stopRecordingWithCue()-Aenderung** (AppDelegate.swift Zeilen 82–93):
```swift
// AppDelegate.swift:82-93 — bisherige Implementierung mit Platzhalter am Ende:
private func stopRecordingWithCue() {
    guard appState?.recordingState == .recording else { return }
    audioController?.stopRecording()
    appState?.toggleRecording()  // .recording → .transcribing
    NSSound(named: NSSound.Name("Pop"))?.play()
    updateIcon()
    // Phase 3 wird hier Transkription starten. Bis dahin: sofort idle.
    appState?.resetToIdle()  // <-- DIESER PLATZHALTER FAELLT WEG
    updateIcon()             // <-- DIESER PLATZHALTER FAELLT WEG
}
```
Nach Phase 3: `audioController?.stopRecording()` loest via `onRecordingComplete`-Callback die Transkription aus. `resetToIdle()` wird am Ende des Callbacks aufgerufen — nicht mehr direkt in `stopRecordingWithCue()`.

---

### `SPRECHKRAFTTests/TranscriptionServiceTests.swift` (test)

**Analog:** `SPRECHKRAFTTests/AudioControllerTests.swift`

**Test-Suite-Deklaration** (AudioControllerTests.swift Zeilen 14–15):
```swift
// AudioControllerTests.swift:14-15
import Testing
import AVFoundation
@testable import SPRECHKRAFT

@Suite("AudioController (RECORD-01, RECORD-02)")
struct AudioControllerTests {

// TranscriptionServiceTests — gleiches Pattern:
import Testing
import AVFoundation
@testable import SPRECHKRAFT

@Suite("TranscriptionService (RECORD-04, RECORD-05)")
struct TranscriptionServiceTests {
```

**Async Test mit MainActor.run** (AudioControllerTests.swift Zeilen 36–40):
```swift
// AudioControllerTests.swift:36-40 — Pattern fuer @MainActor-Objekte in Tests
@Test("calculateRMS gibt ~0.0 fuer stille Buffer")
func testRMSCalculation_silentBuffer() async throws {
    let appState = await MainActor.run { AppState() }
    let controller = AudioController(appState: appState)
```
TranscriptionService ist ein `actor` — kein `MainActor.run` noetig fuer Initialisierung, aber `await` fuer alle Methoden.

**Task.sleep-Pattern fuer asynchrone Callbacks** (AudioControllerTests.swift Zeilen 76–78):
```swift
// AudioControllerTests.swift:76-78 — async Callback abwarten
try await Task.sleep(for: .milliseconds(50))
#expect(autoStopCalled, "...")
```
Fuer TranscriptionService-Tests nicht benoetigt (actor-Methoden sind direkt `await`-bar).

**Buffer-Hilfsmethode** (AudioControllerTests.swift Zeilen 20–30):
```swift
// AudioControllerTests.swift:20-30 — Buffer-Factory
private func makeBuffer(frameLength: AVAudioFrameCount = 1024, sampleValue: Float) -> AVAudioPCMBuffer {
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength)!
    buffer.frameLength = frameLength
    if let channelData = buffer.floatChannelData?[0] {
        for i in 0..<Int(frameLength) { channelData[i] = sampleValue }
    }
    return buffer
}
```
Fuer TranscriptionService-Tests: Float-Array statt Buffer als Input — simpler Factory:
```swift
private func makeSamples(count: Int, value: Float = 0.5) -> [Float] {
    Array(repeating: value, count: count)
}
```

---

## Shared Patterns

### Swift 6 Strict Concurrency (@unchecked Sendable / actor)
**Quelle:** `SPRECHKRAFT/Audio/AudioController.swift` Zeile 20
**Anwenden auf:** `TranscriptionService.swift`
```swift
// AudioController.swift:20 — Render-Thread macht @unchecked Sendable noetig
final class AudioController: @unchecked Sendable {

// TranscriptionService kann staerkeres `actor` verwenden (kein Render-Thread):
actor TranscriptionService { ... }
```

### Task { @MainActor [weak self] in } Dispatch
**Quelle:** `SPRECHKRAFT/Audio/AudioController.swift` Zeilen 114–117, 171–173
**Anwenden auf:** `TranscriptionService.swift` (progressHandler-Dispatch), `AudioController.swift` (onRecordingComplete-Dispatch)
```swift
// AudioController.swift:114-117
Task { @MainActor [weak self] in
    self?.appState?.audioLevel = clampedLevel
    self?.onLevelUpdate?()
}
```

### guard + return Fehlerbehandlung (keine throws-Propagation)
**Quelle:** `SPRECHKRAFT/Audio/AudioController.swift` Zeilen 62–83, 150–153
**Anwenden auf:** `TranscriptionService.swift` (transcribe, resampleIfNeeded)
```swift
// AudioController.swift:150-152
guard let channelData = buffer.floatChannelData?[0] else { return 0 }
let frameLength = Int(buffer.frameLength)
guard frameLength > 0 else { return 0 }
```

### [weak self] Callback-Closure
**Quelle:** `SPRECHKRAFT/AppDelegate.swift` Zeilen 53–59
**Anwenden auf:** `AppDelegate.swift` (onRecordingComplete), `TranscriptionService.swift` (progressHandler)
```swift
// AppDelegate.swift:53-54
audioController?.onAutoStop = { [weak self] in
    self?.stopRecordingWithCue()
}
```

### @MainActor final class (AppDelegate-Konvention)
**Quelle:** `SPRECHKRAFT/AppDelegate.swift` Zeile 19
**Anwenden auf:** Alle neuen `@MainActor`-Methoden in AppDelegate bleiben im gleichen Kontext
```swift
// AppDelegate.swift:19
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
```

### AppState @Observable @MainActor Property-Deklaration
**Quelle:** `SPRECHKRAFT/AppState.swift` Zeilen 58–69
**Anwenden auf:** Neue `isModelReady: Bool`-Property in AppState
```swift
// AppState.swift:58-62
@MainActor
@Observable
final class AppState {
    var recordingState: RecordingState = .idle
    var audioLevel: CGFloat = 0.0
    // isModelReady: Bool = false  ← hier einfuegen
```

---

## No Analog Found

Alle Dateien haben klare Analogs im bestehenden Codebase.

| Datei | Bemerkung |
|-------|-----------|
| `SPRECHKRAFT/Transcription/TranscriptionService.swift` | Kein exakter actor-Service existiert noch — AudioController ist naechster Analog (Sendable-Service-Pattern), aber `actor`-Schlueesselwort ist neu in Phase 3 |

---

## Metadata

**Analog-Suchbereich:** `SPRECHKRAFT/`, `SPRECHKRAFTTests/`
**Dateien gescannt:** 6 Quelldateien + 2 Context-/Research-Dokumente
**Pattern-Extraktion:** 2026-04-18
```
