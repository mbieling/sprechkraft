# Phase 3: Transcription - Research

**Researched:** 2026-04-18
**Domain:** WhisperKit / CoreML / AVFoundation Resampling / Swift 6 Concurrency
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Engine: WhisperKit (argmaxinc/whisperkit) — pure Swift SPM, keine Python-Subprocess.
- **D-02:** Modell: `openai_whisper-large-v3-v20240930_turbo` (~632 MB) — optimale Balance.
- **D-03:** Sprache: `"de"` fest in `DecodingOptions(language: "de")`.
- **D-04:** In-Memory `[Float]`-Array, kein Disk-I/O.
- **D-05:** Buffer-Ownership: `AudioController` akkumuliert, übergibt Kopie an `TranscriptionService` nach `stopRecording()`.
- **D-06:** Samplerate-Normierung via `AVAudioConverter` oder `AudioProcessor.convertBufferToArray`.
- **D-07:** Ausgabe: `print("Transkription: \(text)")` — kein Clipboard, keine Injection.
- **D-08:** Zustandsübergang: `.transcribing → .idle` nach Abschluss oder Fehler.
- **D-09:** Download beim App-Start in `applicationDidFinishLaunching`.
- **D-10:** Fortschrittsanzeige: `statusItem.button?.title = "↓ 42%"`.
- **D-11:** Aufnahme während Download blockiert — `startRecordingWithCue()` prüft `appState.isModelReady`.
- **D-12:** Transkriptionsfehler → stilles `resetToIdle()`, kein User-Feedback.
- **D-13:** Download-Fehler → stilles Beenden, Retry beim nächsten App-Start.

### Claude's Discretion

- Exakte `WhisperKitConfig`-Parameter (`computeUnits`, `chunkingStrategy` etc.)
- Mindestsampleanzahl vor Transkriptionsaufruf
- Download-Caching-Pfad (WhisperKit-Standard vs. Custom)
- Debounce-Schwelle für Title-Update-Häufigkeit

### Deferred Ideas (OUT OF SCOPE)

- Sprachauswahl als Settings-Option
- Retry-Logik bei Download-Fehlern
- Parakeet-Integration

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| RECORD-04 | Aufnahme lokal transkribieren (ursprünglich: Parakeet; entschieden: WhisperKit) | WhisperKit `transcribe(audioArray:decodeOptions:)` mit `[Float]` nativ; D-06 Resampling-Pattern dokumentiert |
| RECORD-05 | Modell wird beim Erststart heruntergeladen mit Fortschrittsanzeige | `WhisperKit.download(variant:from:progressCallback:)` liefert `Progress`-Objekt mit `fractionCompleted`; NSStatusItem Title-Pattern in existierendem `updateIcon()` |

</phase_requirements>

---

## Summary

Phase 3 verdrahtet den bereits funktionierenden Audio-Capture-Stack (Phase 2) mit WhisperKit für lokale On-Device-Transkription. Die zentrale Komplexität liegt in drei Bereichen: (1) korrektes Resampling des nativen Hardware-Formats (44.1 kHz oder 48 kHz) auf die von WhisperKit erwarteten 16 kHz, (2) das Download-Flow beim App-Start mit sichtbarem Fortschritt im NSStatusItem-Title, und (3) Swift-6-konforme Concurrency-Isolation des `TranscriptionService` als `actor`.

Die verifizierte WhisperKit-API (Context7, v0.18.0, April 2025) zeigt, dass `transcribe(audioArray:[Float], decodeOptions:)` direkt ein `[Float]`-Array bei 16 kHz entgegennimmt. `AudioProcessor.convertBufferToArray(buffer:)` ist eine von WhisperKit mitgelieferte Hilfsfunktion, die ein `AVAudioPCMBuffer` in ein `[Float]`-Array konvertiert — aber sie nimmt **kein Resampling vor**. Das Resampling muss explizit via `AVAudioConverter` erfolgen, bevor das Array an WhisperKit übergeben wird.

Der Download-Flow nutzt `WhisperKit.download(variant:from:progressCallback:)`, das ein `URL` zurückgibt und im `progressCallback` ein `Foundation.Progress`-Objekt liefert. Daraus ergibt sich ein sauberer Pfad: Download-Task in `applicationDidFinishLaunching`, `fractionCompleted`-Updates on `@MainActor` als `statusItem.button?.title`.

**Primary recommendation:** `TranscriptionService` als Swift `actor`, `WhisperKit.download` mit `progressCallback` in einem `Task` beim App-Start, Resampling per `AVAudioConverter` vor der Übergabe an WhisperKit.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Modell-Download & Caching | TranscriptionService (actor) | AppDelegate (kickoff) | Download ist async, braucht actor-Isolation gegen re-entrant calls |
| Fortschrittsanzeige | AppDelegate / NSStatusItem | AppState.isModelReady | UI-Update auf @MainActor; AppDelegate kennt statusItem direkt |
| Sample-Akkumulation | AudioController (render thread) | — | Läuft auf Audio-Render-Thread; @unchecked Sendable Pattern aus Phase 2 |
| Resampling (→ 16 kHz) | TranscriptionService | AudioController (alternativ) | Gehört zum Transcription-Concern; AudioController bleibt rein auf Capture fokussiert |
| Transkription | TranscriptionService (actor) | — | Actor verhindert parallele WhisperKit-Calls |
| State-Transition | AppDelegate → AppState | — | @MainActor, konsistent mit bestehendem Pattern |

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|-------------|
| WhisperKit | v0.18.0 (April 2025) | On-Device ASR via CoreML / Neural Engine | Einzige native Swift ASR-Library mit First-Class Apple Silicon Support; saubere async API; D-01 |
| AVFoundation (`AVAudioConverter`) | macOS 14+ (built-in) | Resampling von Hardware-Format auf 16 kHz | Eingebaut in macOS; kein Extra-Dependency; bewährtes Muster für Sample-Rate-Konvertierung |

### SPM-Installation

WhisperKit ist **noch nicht** im `Package.swift` des Projekts eingetragen. Die Pakete werden derzeit über Xcode direkt verwaltet (XCRemoteSwiftPackageReference in pbxproj), analog zu den bestehenden Paketen (KeyboardShortcuts, LaunchAtLogin, Defaults).

**SPM URL:** `https://github.com/argmaxinc/argmax-oss-swift` [VERIFIED: GitHub redirect von argmaxinc/WhisperKit]
**Version:** `from: "0.18.0"` [VERIFIED: GitHub Releases]

**Wichtig:** Das GitHub-Repo wurde von `argmaxinc/WhisperKit` nach `argmaxinc/argmax-oss-swift` umgezogen. Die SPM-URL muss die neue Adresse verwenden.

```
File > Add Package Dependencies…
https://github.com/argmaxinc/argmax-oss-swift
Minimum Version: 0.18.0
Product: WhisperKit
```

---

## Architecture Patterns

### System Architecture Diagram

```
[applicationDidFinishLaunching]
        |
        v
TranscriptionService.downloadModelIfNeeded()   ← async Task
        |
        | progressCallback → fractionCompleted
        v
AppDelegate: statusItem.button?.title = "↓ \(pct)%"
AppState.isModelReady = false (während Download)
        |
        v (Download abgeschlossen)
AppState.isModelReady = true
statusItem.button?.title = ""          ← Title entfernen
        |
[Hotkey / Klick → startRecordingWithCue()]
        |
        | guard appState.isModelReady else { return }    ← D-11
        v
AudioController.startRecording()        ← Phase 2 unverändert
AVAudioEngine installTap akkumuliert [Float]  ← Phase 2 + NEU: Sample-Akkumulation
        |
[Hotkey / Stille → stopRecordingWithCue()]
        |
        v
AudioController.stopRecording() → akkumuliertes [Float]-Array
        |
        v (Kopie des Arrays)
AppState: .recording → .transcribing
        |
        v
TranscriptionService.transcribe([Float])   ← actor-isoliert
AVAudioConverter: hardware_sampleRate → 16000 Hz   ← falls nötig
WhisperKit.transcribe(audioArray: samples16k, decodeOptions: DecodingOptions(language:"de"))
        |
        v (Result)
        | → Erfolg: print("Transkription: \(text)")
        | → Fehler: print("Transkriptionsfehler: \(error)")
        v
AppState: .transcribing → .idle       ← @MainActor, D-08
AppDelegate: updateIcon()
```

### Empfohlene Projektstruktur (Erweiterung)

```
VoiceScribe/
├── Audio/
│   ├── AudioController.swift      # Phase 2 — Tap + RMS (ERWEITERUNG: Float-Akkumulation)
│   └── AudioDeviceManager.swift   # Phase 2 — unverändert
├── Transcription/                 # NEU in Phase 3
│   └── TranscriptionService.swift # actor — WhisperKit wrapper, Download + Transcription
├── AppState.swift                 # ERWEITERUNG: isModelReady: Bool
├── AppDelegate.swift              # ERWEITERUNG: stopRecordingWithCue() kickoff + Download-UX
└── ...
```

### Pattern 1: TranscriptionService als actor

**Was:** Swift `actor` isoliert WhisperKit-Zugriff — verhindert parallele Transcription-Calls.

**Wann:** Immer wenn ein geteiltes ML-Modell von mehreren async Kontexten aufgerufen werden könnte.

```swift
// Source: Context7 /argmaxinc/whisperkit — adaptiert für Swift 6 strict concurrency
actor TranscriptionService {
    private var whisperKit: WhisperKit?
    private(set) var isModelReady: Bool = false

    // MARK: - Download

    /// Lädt das Modell herunter (einmalig). Fortschritt via progressHandler auf @MainActor.
    func downloadAndLoad(
        progressHandler: @MainActor @escaping (Double) -> Void
    ) async {
        do {
            let modelURL = try await WhisperKit.download(
                variant: "openai_whisper-large-v3-v20240930_turbo",
                from: "argmaxinc/whisperkit-coreml",
                progressCallback: { progress in
                    let fraction = progress.fractionCompleted
                    Task { @MainActor in
                        progressHandler(fraction)
                    }
                }
            )
            let config = WhisperKitConfig(
                modelFolder: modelURL.path,
                download: false,
                load: true,
                prewarm: true
            )
            whisperKit = try await WhisperKit(config)
            isModelReady = true
        } catch {
            print("Download-Fehler: \(error)")   // D-13: stille Rückkehr
        }
    }

    // MARK: - Transcription

    /// Transkribiert ein [Float]-Array (bereits bei 16 kHz).
    /// Gibt nil zurück bei Fehler (D-12: stille Rückkehr).
    func transcribe(_ samples: [Float]) async -> String? {
        guard let pipe = whisperKit, isModelReady else { return nil }
        guard samples.count > 1600 else { return nil }  // < 0.1s bei 16kHz — zu kurz
        do {
            let options = DecodingOptions(
                task: .transcribe,
                language: "de",           // D-03: fest Deutsch
                skipSpecialTokens: true
            )
            let results = try await pipe.transcribe(audioArray: samples, decodeOptions: options)
            return results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        } catch {
            print("Transkriptionsfehler: \(error)")   // D-12
            return nil
        }
    }
}
```

### Pattern 2: Resampling mit AVAudioConverter

**Was:** Hardware liefert typischerweise 44.1 kHz oder 48 kHz. WhisperKit erwartet 16 kHz mono.

**Wann:** Immer — Hardware-Samplerate ist nicht garantiert 16 kHz.

```swift
// Source: Apple AVFoundation Docs + TN3136 Pattern [CITED: developer.apple.com/documentation/technotes/tn3136-avaudioconverter-performing-sample-rate-conversions]
func resampleTo16kHz(_ inputSamples: [Float], fromSampleRate inputRate: Double) -> [Float] {
    let targetRate: Double = 16000

    // Kein Resampling nötig wenn bereits 16kHz
    guard abs(inputRate - targetRate) > 1.0 else { return inputSamples }

    guard let inputFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: inputRate,
        channels: 1,
        interleaved: false
    ),
    let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: targetRate,
        channels: 1,
        interleaved: false
    ) else { return inputSamples }

    let frameCount = AVAudioFrameCount(inputSamples.count)
    guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frameCount) else {
        return inputSamples
    }
    inputBuffer.frameLength = frameCount
    inputSamples.withUnsafeBufferPointer { ptr in
        inputBuffer.floatChannelData?[0].initialize(from: ptr.baseAddress!, count: inputSamples.count)
    }

    let outputFrameCount = AVAudioFrameCount(
        Double(inputSamples.count) * targetRate / inputRate
    )
    guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCount),
          let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
        return inputSamples
    }

    var inputConsumed = false
    var conversionError: NSError?
    converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
        if inputConsumed {
            outStatus.pointee = .noDataNow
            return nil
        }
        outStatus.pointee = .haveData
        inputConsumed = true
        return inputBuffer
    }

    guard conversionError == nil,
          let channelData = outputBuffer.floatChannelData?[0] else {
        return inputSamples
    }
    return Array(UnsafeBufferPointer(start: channelData, count: Int(outputBuffer.frameLength)))
}
```

### Pattern 3: Float-Sample-Akkumulation in AudioController (Erweiterung)

**Was:** Phase 2 AudioController akkumuliert derzeit nur RMS für Waveform. Phase 3 erweitert den Tap-Callback um Sample-Akkumulation und fügt `onRecordingComplete`-Callback hinzu.

**Konsistenz mit Phase 2:** Gleicher `@unchecked Sendable`-Ansatz, Mutation nur auf Audio-Render-Thread.

```swift
// Erweiterung AudioController.swift — NICHT vollständig ersetzen, ergänzen
// NEU: Sample-Array und Callback
private var recordedSamples: [Float] = []
var onRecordingComplete: (([Float], Double) -> Void)?  // samples + sampleRate

// In installTap-Closure (ergänzen nach RMS-Berechnung):
if let channelData = buffer.floatChannelData?[0] {
    let count = Int(buffer.frameLength)
    let newSamples = Array(UnsafeBufferPointer(start: channelData, count: count))
    self.recordedSamples.append(contentsOf: newSamples)
}

// In stopRecording() — VOR engine.stop():
let samples = recordedSamples
let sampleRate = engine.inputNode.outputFormat(forBus: 0).sampleRate
recordedSamples = []
Task { @MainActor [weak self] in
    self?.onRecordingComplete?(samples, sampleRate)
}
```

### Pattern 4: AppDelegate-Integration (Download-Kickoff + stopRecordingWithCue)

```swift
// In applicationDidFinishLaunching — NACH setupAudioController():
Task {
    await transcriptionService.downloadAndLoad { [weak self] fraction in
        // @MainActor-Closure (deklariert in downloadAndLoad)
        let pct = Int(fraction * 100)
        self?.statusItem.button?.title = "↓ \(pct)%"
        self?.appState?.isModelReady = false
    }
    // Download abgeschlossen
    statusItem.button?.title = ""
    appState?.isModelReady = true
    updateIcon()
}

// Ersetze stopRecordingWithCue() — bisheriger resetToIdle()-Platzhalter:
private func stopRecordingWithCue() {
    guard appState?.recordingState == .recording else { return }
    audioController?.stopRecording()
    appState?.toggleRecording()   // .recording → .transcribing
    NSSound(named: NSSound.Name("Pop"))?.play()
    updateIcon()
    // Phase 3: Transkription starten (onRecordingComplete Callback liefert samples)
    // Kein direkter Aufruf hier — AudioController ruft onRecordingComplete auf
}

// onRecordingComplete Callback in setupAudioController():
audioController?.onRecordingComplete = { [weak self] samples, sampleRate in
    // @MainActor (Task { @MainActor in } in stopRecording())
    guard let self else { return }
    Task {
        let samples16k = await self.transcriptionService.resampleIfNeeded(samples, sampleRate: sampleRate)
        let text = await self.transcriptionService.transcribe(samples16k)
        await MainActor.run {
            if let text {
                print("Transkription: \(text)")   // D-07
            }
            self.appState?.resetToIdle()          // D-08
            self.updateIcon()
        }
    }
}
```

### Anti-Patterns to Avoid

- **WhisperKit mehrfach initialisieren:** Jeder `WhisperKit(config)` Aufruf lädt das Modell neu (~3-5s, ~800MB). Einmal in `TranscriptionService.downloadAndLoad()` initialisieren, danach als Property halten.
- **`download: true` im normalen Init-Pfad:** `WhisperKitConfig(download: true)` lädt bei jedem App-Start neu herunter. Stattdessen `WhisperKit.download()` einmalig aufrufen und `modelFolder` setzen.
- **`AudioProcessor.convertBufferToArray` als Resampler missbrauchen:** Diese Funktion konvertiert Format, resampelt aber **nicht**. Sie nimmt keine Sample-Rate-Conversion vor. Explizites AVAudioConverter-Resampling ist zwingend.
- **Transcription-Task nicht absichern:** Ohne `guard samples.count > 1600` riskiert man WhisperKit-Calls auf nahezu leeren Arrays (z.B. bei versehentlichem 0.05s Tap). WhisperKit gibt dann leeren String oder Halluzinationen zurück.
- **Progress-Callback auf Background-Thread direkt ins UI schreiben:** `progressCallback` in `WhisperKit.download()` läuft auf einem Background-Thread. UI-Updates (statusItem.button?.title) müssen via `Task { @MainActor in }` dispatcht werden.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| ASR-Inferenz | Eigener CoreML-Wrapper für Whisper | WhisperKit | CoreML-Modell-Loading, Tokenizer, Beam Search, Chunking — hunderte Edge Cases |
| Sample-Rate-Konvertierung | Eigene Interpolations-Mathematik | AVAudioConverter | Qualitätsfilter (Anti-Aliasing), korrekte Poly-Phase-Resampling, Hardware-optimiert |
| Model-Download + Caching | Eigener URLSession-Download mit FileManager | WhisperKit.download() | HuggingFace-Auth, Resume, Checksums, Folder-Layout für WhisperKit-Config |
| Minimum-Audio-Guard | Komplexe Energie-Analyse | `samples.count > 1600` (0.1s @ 16kHz) | Einfacher Count reicht; WhisperKit selbst hat `noSpeechThreshold` als zweite Sicherung |

---

## Common Pitfalls

### Pitfall 1: Hardware-Samplerate ist NICHT garantiert 16 kHz

**Was schiefläuft:** Entwickler übergibt direkt die aus dem `installTap`-Callback akkumulierten Samples an `pipe.transcribe(audioArray:)`. Das Audio klingt 3x schneller/langsamer (48 kHz → 16 kHz = Faktor 3).

**Warum:** macOS liefert das native Hardware-Format. Macbooks mit eingebautem Mikrofon liefern typischerweise 44.1 kHz oder 48 kHz, manche USB-Headsets 16 kHz oder 96 kHz.

**Wie vermeiden:** Immer `AVAudioConverter` verwenden. Die aktuelle Hardware-Rate aus `engine.inputNode.outputFormat(forBus: 0).sampleRate` lesen und nur wenn sie ≠ 16000 Hz ist, resampling durchführen. `onRecordingComplete` übergibt deshalb auch die `sampleRate`.

**Warning Signs:** Transkription liefert zufälligen Buchstabensalat oder leeren String bei normalem Sprechen.

### Pitfall 2: WhisperKit.download() vs. WhisperKit(config) mit download:true

**Was schiefläuft:** `WhisperKitConfig(model: "...", download: true, load: true)` initialisiert das Modell und lädt es herunter — aber ohne granularen Fortschritts-Callback. Ein `Progress`-Objekt ist dort nicht einfach einhookbar.

**Wie vermeiden:** Zwei-Phasen-Ansatz: (1) `WhisperKit.download(variant:from:progressCallback:)` für Download-UX, (2) danach `WhisperKit(WhisperKitConfig(modelFolder: url.path, download: false, load: true))` für Initialisierung.

**Warning Signs:** Kein Fortschritt sichtbar während Download läuft.

### Pitfall 3: Actor-Re-Entry bei schnellem Hotkey-Doppelklick

**Was schiefläuft:** User tippt Hotkey zweimal schnell. Erster Transcription-Task läuft noch. Zweiter Task versucht `pipe.transcribe()` auf demselben `WhisperKit`-Objekt aufzurufen → undefined behavior oder Absturz.

**Warum:** Auch wenn `TranscriptionService` ein `actor` ist, serialisiert er Aufrufe — der zweite Aufruf wartet. Aber `AppDelegate` hat den State bereits auf `.transcribing` gesetzt und wird dann zweimal `resetToIdle()` aufrufen.

**Wie vermeiden:** `startRecordingWithCue()` prüft bereits `guard appState.recordingState == .idle`. Da `.transcribing` nicht `.idle` ist, wird ein zweiter Start korrekt geblockt. Der `actor` serialisiert trotzdem für Sicherheit.

**Warning Signs:** State-Anomalien, doppelte Print-Ausgaben.

### Pitfall 4: Modell-Caching-Pfad — WhisperKit Standard vs. Custom

**Was schiefläuft:** Kein `modelFolder` angegeben → WhisperKit lädt nach `~/Library/Caches/huggingface/...` (Standard). Nach App-Löschung bleibt der Cache erhalten. Das ist meist gewünscht, aber unklar.

**Wie vermeiden:** Standard-Pfad verwenden (Claude's Discretion laut CONTEXT.md). WhisperKit verwaltet den Cache eigenständig. Für Phase 3 kein Custom-Pfad nötig.

### Pitfall 5: Memory-Spike beim Akkumulieren langer Aufnahmen

**Was schiefläuft:** 30 Sekunden Audio bei 48 kHz mono Float32 = 30 × 48000 × 4 Bytes = 5.76 MB Akkumulation. Dazu Resample-Output (~1.92 MB). Das ist für sich genommen unkritisch. Problematisch: Array wird kopiert (D-05) → kurzzeitig 2× im Memory.

**Warum:** Array ist ein Swift Value Type — `onRecordingComplete([Float])` übergibt eine Kopie. Original wird in `stopRecording()` sofort freigegeben.

**Wie vermeiden:** Auf die kurze Doppel-Präsenz achten: Original-Freigabe via `recordedSamples = []` **vor** dem Task-Dispatch, damit der GC das Original sofort freigeben kann, bevor der Transcription-Task seine Kopie verarbeitet. Pattern im Code oben zeigt dies korrekt.

---

## Code Examples

### Vollständiger Download-Flow

```swift
// Source: Context7 /argmaxinc/whisperkit — WhisperKit v0.18.0
// TranscriptionService.downloadAndLoad()
let modelURL = try await WhisperKit.download(
    variant: "openai_whisper-large-v3-v20240930_turbo",
    from: "argmaxinc/whisperkit-coreml",
    progressCallback: { progress in
        let fraction = progress.fractionCompleted  // Foundation.Progress
        Task { @MainActor in
            progressHandler(fraction)
        }
    }
)
// Nach Download: mit lokalem Folder initialisieren
let config = WhisperKitConfig(
    modelFolder: modelURL.path,
    download: false,
    load: true,
    prewarm: true
)
whisperKit = try await WhisperKit(config)
```

### Transcription mit DecodingOptions (Deutsch, kein Auto-Detect)

```swift
// Source: Context7 /argmaxinc/whisperkit
let options = DecodingOptions(
    task: .transcribe,
    language: "de",            // D-03: fest
    skipSpecialTokens: true,   // Keine <|startoftranscript|> etc. im Output
    noSpeechThreshold: 0.6     // Stille-Erkennung innerhalb WhisperKit
)
let results = try await pipe.transcribe(audioArray: samples16k, decodeOptions: options)
let text = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)
```

### Minimum-Sample-Guard

```swift
// 1600 Samples = 0.1s bei 16kHz — absolutes Minimum für sinnvolle Transkription
// WhisperKit verarbeitet intern in 30s-Chunks; kürzer als ~0.5s → oft leerer Output
let minimumSamples = 1600  // [ASSUMED] — kein offizieller Mindestwert in WhisperKit-Docs
guard samples.count > minimumSamples else {
    print("Audio zu kurz für Transkription (\(samples.count) Samples)")
    return nil
}
```

### NSStatusItem Title für Download-Fortschritt

```swift
// Source: Existing AppDelegate.swift:175-191 Pattern (Phase 2)
// @MainActor — im progressHandler aufgerufen
let pct = Int(fraction * 100)
statusItem.button?.title = pct < 100 ? "↓ \(pct)%" : ""
// Nach Abschluss:
statusItem.button?.title = ""
appState?.isModelReady = true
updateIcon()
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|-----------------|--------------|--------|
| `WhisperKit(model: "large-v3")` direkt | `WhisperKit.download()` + `WhisperKitConfig(modelFolder:)` | v0.9+ | Granularer Fortschritts-Callback nur via separatem `download()`-Call |
| Parakeet Python Subprocess | WhisperKit Swift-native | D-01 (Phase 3 CONTEXT.md) | Kein Python-Bundling, kein IPC, saubere Swift 6 Integration |
| `argmaxinc/WhisperKit` SPM URL | `argmaxinc/argmax-oss-swift` SPM URL | 2025 (Repo-Umbenennung) | Alte URL funktioniert evtl. noch via Redirect, aber neue URL verwenden |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Minimum-Sample-Count von 1600 (0.1s @ 16kHz) ist ausreichend als Guard | Code Examples, Don't Hand-Roll | Zu kleiner Wert → WhisperKit-Calls auf sehr kurzen Arrays; Halluzinationen möglich. Mitigation: `noSpeechThreshold: 0.6` in DecodingOptions als zweite Sicherung |
| A2 | WhisperKit.download() `progressCallback` liefert Foundation.Progress mit `fractionCompleted` | Standard Stack, Code Examples | Wenn API sich geändert hat → kein Fortschrittsbalken. Mitigation: modelStateCallback als Fallback |
| A3 | Modell `openai_whisper-large-v3-v20240930_turbo` ist ~632 MB | Standard Stack | Tatsächliche Größe könnte abweichen; User-Erwartung stimmt nicht. Kein funktionaler Impact. |

---

## Open Questions

1. **Swift 6-Kompatibilität von WhisperKit v0.18.0**
   - Was wir wissen: WhisperKit hat Anfang 2025 begonnen, Swift 6 Concurrency-Warnungen zu beheben (Sendable-Conformances). Stand April 2025 (v0.18.0) ist der Status unklar.
   - Was unklar ist: Ob `WhisperKit` selbst `@unchecked Sendable` oder `actor`-konform ist, oder ob der Caller Workarounds braucht.
   - Empfehlung: Beim SPM-Add prüfen ob Build-Warnungen auftreten. Falls ja: `nonisolated(unsafe)` oder `@preconcurrency import WhisperKit` als Workaround in Phase 3 akzeptabel.

2. **Modell bereits auf Gerät vorhanden (Cached)**
   - Was wir wissen: `WhisperKit.download()` prüft intern nicht, ob das Modell bereits im Cache liegt (unklar aus Docs).
   - Empfehlung: Vor dem Download-Call prüfen ob der ModelFolder existiert: `FileManager.default.fileExists(atPath: modelPath)`. Wenn ja: direkt `WhisperKit(config)` aufrufen ohne Download. Dies spart Zeit bei jedem App-Start nach dem Erststart.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| WhisperKit (SPM) | TranscriptionService | ✗ (noch nicht eingetragen) | v0.18.0 | — (keine Alternative; muss hinzugefügt werden) |
| Internet-Verbindung (Erststart) | Modell-Download | ✓ (angenommen) | — | — (Download blockiert; isModelReady bleibt false) |
| CoreML / Neural Engine | WhiskerKit Inferenz | ✓ macOS 14+ | System | CPU-Fallback via computeOptions |
| AVAudioConverter | Resampling | ✓ built-in | macOS 14+ | — |

**Missing dependencies with no fallback:**
- WhisperKit SPM-Package ist noch nicht im Xcode-Projekt registriert. Muss als Wave-0-Task vor der eigentlichen Implementierung hinzugefügt werden.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (import Testing) — bereits aktiv in VoiceScribeTests/ |
| Config file | Xcode Test Target (kein separates Config-File) |
| Quick run command | `xcodebuild test -scheme VoiceScribe -destination 'platform=macOS' -only-testing:VoiceScribeTests/TranscriptionServiceTests 2>&1 \| tail -20` |
| Full suite command | `xcodebuild test -scheme VoiceScribe -destination 'platform=macOS' 2>&1 \| tail -40` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RECORD-04 | Resampling: 48 kHz Float-Array → 16 kHz Array korrekte Länge | unit | `xcodebuild test -only-testing:VoiceScribeTests/TranscriptionServiceTests/testResamplingProducesCorrectLength` | ❌ Wave 0 |
| RECORD-04 | Minimum-Sample-Guard gibt nil zurück für zu kurzes Audio | unit | `xcodebuild test -only-testing:VoiceScribeTests/TranscriptionServiceTests/testMinimumSampleGuard` | ❌ Wave 0 |
| RECORD-04 | Transkription gibt nil zurück wenn Modell nicht geladen | unit | `xcodebuild test -only-testing:VoiceScribeTests/TranscriptionServiceTests/testTranscribeReturnNilWhenNotReady` | ❌ Wave 0 |
| RECORD-05 | isModelReady startet als false | unit | `xcodebuild test -only-testing:VoiceScribeTests/TranscriptionServiceTests/testInitialStateNotReady` | ❌ Wave 0 |
| RECORD-05 | AppState.isModelReady existiert und ist @MainActor | unit | `xcodebuild test -only-testing:VoiceScribeTests/AppStateTests/testIsModelReadyInitiallyFalse` | ❌ Wave 0 (AppStateTests.swift existiert, Erweiterung nötig) |

### Sampling Rate

- **Per task commit:** `xcodebuild test -scheme VoiceScribe -destination 'platform=macOS' -only-testing:VoiceScribeTests/TranscriptionServiceTests 2>&1 | tail -20`
- **Per wave merge:** Full suite — alle VoiceScribeTests
- **Phase gate:** Full suite grün vor `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `VoiceScribeTests/TranscriptionServiceTests.swift` — RECORD-04 (Resampling, Guard, not-ready-Guard), RECORD-05 (isModelReady initial state)
- [ ] `VoiceScribe/AppState.swift` Erweiterung — `isModelReady: Bool` Property (für Test in AppStateTests)

*(AppStateTests.swift existiert bereits — Erweiterung um `testIsModelReadyInitiallyFalse`)*

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | nein | — |
| V3 Session Management | nein | — |
| V4 Access Control | nein | — |
| V5 Input Validation | ja (gering) | Minimum-Sample-Guard, samples.count check |
| V6 Cryptography | nein | — |

### Known Threat Patterns for Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Unbounded Array-Akkumulation (sehr lange Aufnahmen) | DoS | Maximale Aufnahmedauer-Guard (optional Phase 3, sonst Phase N) |
| WhisperKit schreibt temporäre Dateien in Caches | Information Disclosure | Standard macOS Caches-Schutz; kein App-Sandbox-Issue (App ist nicht sandboxed per ARCHITECTURE.md) |

---

## Sources

### Primary (HIGH confidence)
- Context7 `/argmaxinc/whisperkit` — Model download, transcribeAudio, DecodingOptions, progressCallback, AudioProcessor.convertBufferToArray [VERIFIED: Context7]
- GitHub `argmaxinc/WhisperKit` → `argmaxinc/argmax-oss-swift` v0.18.0 Releases [VERIFIED: GitHub]
- HuggingFace `argmaxinc/whisperkit-coreml` tree/main — Exakte Modell-Ordnernamen inkl. `openai_whisper-large-v3-v20240930_turbo` (632MB Variante) [VERIFIED: WebFetch]
- Apple AVFoundation `AVAudioConverter` — TN3136 Sample Rate Conversion Pattern [CITED: developer.apple.com/documentation/technotes/tn3136-avaudioconverter-performing-sample-rate-conversions]

### Secondary (MEDIUM confidence)
- helrabelo.dev: WhisperKit on macOS — Download + actor Pattern, @MainActor dispatch für progress [CITED: helrabelo.dev/blog/whisperkit-on-macos-integrating-on-device-ml]
- GitHub Releases Seite: v0.18.0 April 1, 2025 bestätigt [VERIFIED: github.com/argmaxinc/WhisperKit/releases]

### Tertiary (LOW confidence)
- Minimum-Sample-Count 1600 — kein offizieller Wert in WhiskerKit-Docs, abgeleitet aus 0.1s @ 16kHz [ASSUMED]

---

## Metadata

**Confidence breakdown:**
- Standard Stack (WhisperKit API, model name, version): HIGH — Context7 + GitHub + HuggingFace verifiziert
- Architecture (actor pattern, resampling flow): HIGH — WhisperKit-Docs + bewährte AVFoundation-Patterns
- Pitfalls: HIGH (Resampling-Pflicht, Download-Zwei-Phasen) / MEDIUM (Swift 6 Compat) — aus Docs und Codebase-Kontext abgeleitet
- Test-Strategie: HIGH — konsistent mit bestehenden VoiceScribeTests-Patterns

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (WhisperKit ist aktiv entwickelt; API vor Implementierung kurz re-checken)
