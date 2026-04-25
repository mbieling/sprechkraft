# Phase 7: Parakeet Backend - Research

**Researched:** 2026-04-24
**Domain:** FluidAudio SPM integration, TranscriptionBackend protocol, Swift 6 actor isolation
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** `WhisperKitBackend.swift` als auskommentierte Datei im Repo erhalten. Dokumentiert den Fallback-Pfad ohne Build-Overhead.
- **D-02:** WhisperKit SPM-Dependency vollständig aus dem Projekt entfernen (Package.resolved, pbxproj). Reaktivieren = Dependency readden + Datei uncommenten.
- **D-03:** `RecordingState` bekommt neuen Case `.warmingUp` — zwischen `.modelLoading` und `.idle`. Tritt auf nach erfolgreichem Model-Load, bleibt aktiv während Dummy-Audio-Inferenz läuft.
- **D-04:** Hotkey während `.warmingUp` wird silent ignoriert (bestehender `isModelReady`-Guard in AppDelegate greift). Kein User-Feedback nötig — Icon kommuniziert den Zustand.
- **D-05:** `StatusBarIconView` wird um `.warmingUp` und `.modelError` Cases erweitert.
- **D-06:** Kein Fortschrittsbalken — stattdessen Spinner (animiertes Icon im `.modelLoading`-State) mit Größen-Hinweis im Menü-Titel: "Parakeet-Modell wird geladen (~1.2 GB)…".
- **D-07:** Cache-Pfad `~/Library/Application Support/FluidAudio/Models` explizit prüfen bevor Download-UI gezeigt wird. Wenn Modell-Datei existiert: direkt `downloadAndLoad` (FluidAudio handled cache intern), kein Spinner.
- **D-08:** `AppState` bekommt `isModelError: Bool` (analog zu `isModelReady`). Wird bei Download-Fehler auf `true` gesetzt.
- **D-09:** `RecordingState` bekommt `.modelError` — `StatusBarIconView` zeigt Fehler-Symbol.
- **D-10:** Retry-Logik kommt in Phase 8. Phase 7 liefert nur State + Icon.
- **D-11:** `TranscriptionBackend`-Protokoll: `func downloadAndLoad(progressHandler: @MainActor @escaping (Double) -> Void) async` + `func transcribeWithResampling(_ samples: [Float], sampleRate: Double) async -> String?` + `var isModelReady: Bool { get }`.
- **D-12:** `@preconcurrency import FluidAudio` wenn nötig.
- **D-13:** `resampleTo16kHz` bleibt in `TranscriptionService`. Backends bekommen 16-kHz-Samples.
- FluidAudio v0.12.4 via SPM.

### Claude's Discretion

- Genaue SF-Symbol-Wahl für `.warmingUp` (z.B. `hourglass`, `clock`) und `.modelError` (z.B. `exclamationmark.triangle`).
- Interne Struktur von `ParakeetBackend` (Actor-Properties, Task-Management).
- Ob `AsrModels.downloadAndLoad` tatsächlich einen Progress-Handler hat: beim ersten Build prüfen. Falls ja: echter Progress statt Fake-Double.

### Deferred Ideas (OUT OF SCOPE)

- Retry-Button im Menü bei `.modelError` → Phase 8
- Transkriptions-Engine-Status-Sektion in Settings → Phase 8
- Qualitätsvergleich WhisperKit vs. Parakeet auf Deutsch → Phase 9
- Echter Progress-Handler falls FluidAudio v3 API ihn hat → Phase 9
- Quantisiertes 8-Bit-Modell als Alternative (~909 MB) → v2
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RECORD-04 | Parakeet v3 transkribiert Aufnahme lokal via FluidAudio | FluidAudio `AsrManager.transcribe(_ samples: [Float])` nimmt 16kHz-Float-Array; `ASRResult.text` liefert String. Direkter API-Pfad verified. |
| RECORD-05 | Parakeet-Modell wird beim Erststart heruntergeladen (mit Fortschrittsanzeige) | `AsrModels.downloadAndLoad(version: .v3)` cached automatisch; kein Progress-Handler in der Basis-Signatur. Fortschrittsanzeige via Spinner + Titel-Text (.modelLoading-State). |
</phase_requirements>

---

## Summary

Phase 7 ersetzt die bestehende `TranscriptionService`-Monolith-Implementierung (WhisperKit) durch ein Facade-Pattern mit einem `TranscriptionBackend`-Protokoll und einer `ParakeetBackend`-Implementierung via FluidAudio v0.12.4.

**Kernbefund zur FluidAudio API** (VERIFIED via Context7): `AsrModels.downloadAndLoad(version: .v3)` hat **keinen Progress-Handler** in der Basis-Signatur — die Funktion ist `async throws` und gibt `AsrModels` zurück. Fortschrittsanzeige muss daher über einen `.modelLoading`-State mit Spinner + Titel-Text realisiert werden (D-06 ist bereits korrekt spezifiziert). `AsrManager.transcribe(_ samples: [Float], source: AudioSource)` nimmt ein `[Float]`-Array bei 16 kHz mono — exakt das Format, das `TranscriptionService.resampleTo16kHz` bereits liefert. Der `source`-Parameter ist optional mit Default `.file`; für Mikrofon-Aufnahmen sollte `.microphone` übergeben werden.

Die bestehende Codebase ist gut vorbereitet: `AppState` hat bereits das `isModelReady`-Pattern, `AppDelegate.setupTranscription()` ist API-stabil, und `resampleTo16kHz` muss nicht angefasst werden. Die größten Änderungen sind strukturell: neues Protokoll, neuer Actor, neue RecordingState-Cases, und das vollständige Entfernen von WhisperKit aus pbxproj (3 Stellen).

**Primary recommendation:** FluidAudio v0.12.4 via SPM hinzufügen, `TranscriptionBackend`-Protokoll einführen, `ParakeetBackend` actor implementieren, `TranscriptionService` zur Facade machen, WhisperKit aus pbxproj entfernen und als auskommentierte Datei behalten.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Transkriptions-Protokoll | TranscriptionService (actor/facade) | — | AppDelegate-API bleibt stabil; Backends sind austauschbar |
| Model Download + Cache | ParakeetBackend (actor) | FluidAudio (intern) | Backend kapselt Download-Lifecycle; AppState spiegelt Status |
| Resampling (48kHz → 16kHz) | TranscriptionService | — | D-13: backend-unabhängig; einmal implementieren, von beiden Backends nutzbar |
| Warmup-Inferenz | ParakeetBackend (actor) | AppState (.warmingUp) | Metal-Shader-Warmup gehört zum Backend-Lifecycle, nicht zur Aufnahme-Logik |
| App-State-Signaling (modelLoading, warmingUp, modelError) | AppState (@MainActor) | AppDelegate (Caller) | @Observable-Pattern; AppDelegate setzt States nach Backend-Callbacks |
| Icon-Rendering der neuen States | StatusBarIconView | AppState | SwiftUI-Komponente konsumiert RecordingState — nur neue Case-Zweige nötig |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| FluidAudio | 0.12.4 | Parakeet TDT v3 via CoreML/ANE | [VERIFIED: Context7 /fluidinference/fluidaudio] Score 89.75, 1500+ Stars, in VoiceInk produktiv |

### SPM-URL (VERIFIED)
```
https://github.com/FluidInference/FluidAudio.git, from: "0.12.4"
```

### Zu entfernende Dependency
| Library | URL in pbxproj | Identifier | Zeilen |
|---------|----------------|------------|--------|
| WhisperKit (via argmax-oss-swift) | `https://github.com/argmaxinc/argmax-oss-swift` | `DEAD0103` (XCRemoteSwiftPackageReference), `BEEF0028` (XCSwiftPackageProductDependency), `CAFE0028` (PBXBuildFile) | L22, L41, L89, L250, L308, L641-648, L683-687 |

**Installation:**
```bash
# Im Xcode: File > Add Package Dependencies
# URL: https://github.com/FluidInference/FluidAudio.git
# Version: 0.12.4 (Exact) oder upToNextMinorVersion
```

## Architecture Patterns

### System Architecture Diagram

```
AppDelegate.setupTranscription()
         |
         v
TranscriptionService.downloadAndLoad(progressHandler:)   [facade]
         |
         v
ParakeetBackend.downloadAndLoad(progressHandler:)        [new actor]
         |
         +-- AsrModels.downloadAndLoad(version: .v3)     [FluidAudio, async throws]
         |       |
         |       +-- HuggingFace Download (einmalig)
         |       +-- CoreML Compilation
         |       +-- Cache: ~/Library/Application Support/FluidAudio/Models
         |
         +-- asrManager.loadModels(models)
         |
         +-- Warmup: asrManager.transcribe(dummySamples)  [Metal Shader warm]
         |
         v
AppState.recordingState = .idle  (via AppDelegate, @MainActor)
AppState.isModelReady = true

------- AUFNAHME -------

AudioController.onRecordingComplete(samples, sampleRate)
         |
         v
TranscriptionService.transcribeWithResampling(samples, sampleRate:)   [facade]
         |
         +-- resampleTo16kHz(samples, fromSampleRate: sampleRate)      [bleibt in TranscriptionService]
         |
         v
ParakeetBackend.transcribeWithResampling(samples16k, sampleRate: 16000)  [delegates to]
         |
         v
asrManager.transcribe(samples16k, source: .microphone)   [FluidAudio]
         |
         v
ASRResult.text  -> String?
```

### Recommended Project Structure
```
VoiceScribe/
├── Transcription/
│   ├── TranscriptionBackend.swift    [NEU: Protokoll]
│   ├── TranscriptionService.swift    [UMBAU: Facade, behält resampleTo16kHz]
│   ├── ParakeetBackend.swift         [NEU: FluidAudio actor]
│   └── WhisperKitBackend.swift       [NEU: auskommentierter Fallback]
```

### Pattern 1: TranscriptionBackend Protokoll

```swift
// Source: Context7 /fluidinference/fluidaudio + D-11 aus CONTEXT.md
protocol TranscriptionBackend: Sendable {
    func downloadAndLoad(
        progressHandler: @MainActor @escaping (Double) -> Void
    ) async

    func transcribeWithResampling(
        _ samples: [Float],
        sampleRate: Double
    ) async -> String?

    var isModelReady: Bool { get async }
}
```

**Anmerkung:** Da `TranscriptionBackend` von einem `actor` (TranscriptionService) verwendet wird, und `ParakeetBackend` selbst ein `actor` ist, muss das Protokoll `Sendable` erfüllen. Actors sind per Default `Sendable` — kein `@unchecked Sendable` nötig. [VERIFIED: Context7 FluidAudio CLAUDE.md — `@unchecked Sendable` verboten]

### Pattern 2: ParakeetBackend Actor

```swift
// Source: Context7 /fluidinference/fluidaudio API-Docs
import FluidAudio   // @preconcurrency wenn Swift-6-Warnung erscheint (D-12)

actor ParakeetBackend: TranscriptionBackend {
    private var asrManager: AsrManager?
    private(set) var isModelReady: Bool = false

    func downloadAndLoad(
        progressHandler: @MainActor @escaping (Double) -> Void
    ) async {
        guard !isModelReady else { return }
        do {
            // Kein nativer Progress-Handler in downloadAndLoad(version:) [VERIFIED: Context7]
            // Signal: Download läuft (0%) — AppDelegate zeigt .modelLoading-State
            await progressHandler(0.0)

            let models = try await AsrModels.downloadAndLoad(version: .v3)
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)

            // Warmup: Metal Shader warm halten (I8 — 5-15s Latenz vermeiden)
            let dummySamples = [Float](repeating: 0.0, count: 16000) // 1s Stille
            _ = try? await manager.transcribe(dummySamples, source: .microphone)

            self.asrManager = manager
            self.isModelReady = true
            await progressHandler(1.0)
        } catch {
            // Stille Rückkehr; AppDelegate setzt isModelError via isModelReady-Check
            print("[ParakeetBackend] Download/Load error: \(error)")
        }
    }

    func transcribeWithResampling(
        _ samples: [Float],
        sampleRate: Double
    ) async -> String? {
        guard let manager = asrManager, isModelReady else { return nil }
        guard samples.count >= 1600 else { return nil }  // < 0.1s @ 16kHz
        do {
            let result = try await manager.transcribe(samples, source: .microphone)
            return result.text.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : result.text.trimmingCharacters(in: .whitespaces)
        } catch {
            print("[ParakeetBackend] Transcription error: \(error)")
            return nil
        }
    }
}
```

### Pattern 3: TranscriptionService als Facade

```swift
// UMBAU — nur Backend-Delegation, resampleTo16kHz bleibt
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

    // resampleTo16kHz bleibt VOLLSTÄNDIG unverändert hier (D-13)
}
```

**Wichtig:** `transcribeWithResampling` im Backend hat `sampleRate: Double` als Parameter laut D-11, aber da TranscriptionService das Resampling übernimmt (D-13), übergibt er `16000.0` an das Backend. Das Backend kann den Parameter ignorieren oder für Guard-Checks nutzen.

### Pattern 4: RecordingState neue Cases

```swift
// In AppState.swift — neue Cases ergänzen
enum RecordingState: Equatable {
    case idle
    case recording
    case transcribing
    case llmProcessing
    case error          // bestehend — Groq-Fehler
    case modelLoading   // NEU: während AsrModels.downloadAndLoad läuft
    case warmingUp      // NEU: nach Model-Load, während Dummy-Inferenz (D-03)
    case modelError     // NEU: wenn Download/Load fehlschlägt (D-09)
}
```

**`color`-Erweiterungen:**
```swift
// SF-Symbol Empfehlungen (Claude's Discretion):
// .modelLoading / .warmingUp → "mic.fill" mit systemOrange + spin-Animation (oder hourglass.fill)
// .modelError → "exclamationmark.triangle.fill" mit systemRed (bereits für .error)
case .modelLoading, .warmingUp: return Color(.systemOrange)
case .modelError: return Color(.systemRed)
```

**`systemImage`-Erweiterungen:**
```swift
case .modelLoading: return "arrow.down.circle"         // Download-Indikator
case .warmingUp:    return "hourglass"                 // Warmup-Indikator
case .modelError:   return "exclamationmark.triangle.fill"
```

**`accessibilityLabel`-Erweiterungen:**
```swift
case .modelLoading: return "VoiceScribe — Modell wird geladen"
case .warmingUp:    return "VoiceScribe — Modell wird vorbereitet"
case .modelError:   return "VoiceScribe — Modellfehler"
```

### Pattern 5: AppDelegate setupTranscription (minimale Änderungen)

```swift
// ÄNDERUNG: modelLoading-State setzen + isModelError auswerten
private func setupTranscription() {
    // Modell-Cache prüfen (D-07): Wenn vorhanden, kein Spinner
    let cacheURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/FluidAudio/Models")
    let modelCached = FileManager.default.fileExists(atPath: cacheURL.path)

    if !modelCached {
        appState?.recordingState = .modelLoading   // Spinner anzeigen
        updateIcon()
    }

    Task {
        await transcriptionService.downloadAndLoad { [weak self] fraction in
            // fraction: 0.0 = Start, 1.0 = Ende (keine Zwischenwerte von FluidAudio)
            if fraction < 1.0 {
                self?.statusItem.button?.title = "Parakeet-Modell wird geladen (~1.2 GB)…"
            } else {
                self?.statusItem.button?.title = ""
            }
        }

        let ready = await transcriptionService.isModelReady
        appState?.isModelReady = ready
        if !ready {
            appState?.isModelError = true         // D-08
            appState?.recordingState = .modelError // D-09
        } else {
            // Warmup läuft bereits im Backend — State für UI
            appState?.recordingState = .warmingUp  // D-03: wird in Backend nach Warmup zu .idle
            // Nach Warmup wird isModelReady=true gesetzt; .warmingUp → .idle in next updateIcon call
            appState?.recordingState = .idle
        }
        updateIcon()
    }
}
```

**Anmerkung:** Da das Warmup synchron im `downloadAndLoad` des Backends läuft (Dummy-Inferenz nach `loadModels`), wird `.warmingUp` nur kurz angezeigt. Das Backend kann die Warmup-Phase nicht direkt in AppState setzen (kein AppState-Zugriff aus ParakeetBackend). Optionen: (a) `.warmingUp` vor `downloadAndLoad` setzen und in der progressHandler-Closure mit `fraction >= 1.0` zu `.idle` wechseln, oder (b) warmupState als zweites Bool in progressHandler kodieren. Empfehlung: Option (a) — `.warmingUp` setzen bevor `downloadAndLoad` aufgerufen wird, da das Warmup im Backend-Call enthalten ist.

### Anti-Patterns to Avoid

- **@unchecked Sendable:** FluidAudio-Docs verbieten dies explizit. Stattdessen `actor`-Isolation nutzen. [VERIFIED: Context7 FluidAudio CLAUDE.md]
- **Synchroner Model-Load auf Main Thread (C4):** `AsrModels.downloadAndLoad` ist `async throws` — immer aus Background-Task, nie direkt aus `@MainActor`-Kontext aufrufen. [VERIFIED: Context7]
- **Ohne Warmup deployen (I8):** Metal Shader brauchen 5–15s beim ersten echten Inference-Aufruf. Warmup-Inferenz mit Dummy-Samples nach `loadModels` ist Pflicht. [CITED: .planning/research/SUMMARY.md]
- **`transcribeWithResampling` in Backend mit Hardware-Rate aufrufen:** D-13 legt fest, dass `resampleTo16kHz` in `TranscriptionService` bleibt. Backends bekommen 16kHz-Samples. Pattern-Verletzung würde Resampling-Code duplizieren.
- **WhisperKit-Import stehen lassen:** `@preconcurrency import WhisperKit` in TranscriptionService.swift muss entfernt werden. Datei komplett ersetzen durch Facade.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CoreML-Inferenz für Parakeet | Eigener RNNT/TDT-Decoder in Swift | `AsrManager.transcribe(_:source:)` | Chunk-Verarbeitung, Overlap-Merging, Detokenization sind komplex. [VERIFIED: Context7] |
| Audio-Format-Konvertierung im Backend | Eigener Resampler in ParakeetBackend | `resampleTo16kHz` in TranscriptionService (bereits implementiert) | AVAudioConverter-Pattern ist bewährt und getestet |
| Model-Cache-Management | Eigene Verzeichnis-Logik | `AsrModels.downloadAndLoad(version:)` cached intern | FluidAudio handled Cache in `~/Library/Application Support/FluidAudio/Models` [CITED: Context7] |
| HuggingFace-Download | Eigener URLSession-Download | `AsrModels.downloadAndLoad` | Retry, Atomic-Write, CoreML-Compilation sind eingebaut |

**Key insight:** FluidAudio ist kein dünner Wrapper — `AsrManager` handled Chunk-Processing, Overlap-Merging und Detokenization intern. Custom-Implementierung dieser Pipeline wäre mehrere Wochen Arbeit mit schlechterer Genauigkeit.

## Common Pitfalls

### Pitfall 1: C4 — Model Loading blockiert Main Thread
**What goes wrong:** `AsrModels.downloadAndLoad` auf `@MainActor` aufgerufen → App friert ein.
**Why it happens:** CoreML-Compilation ist CPU-intensiv (mehrere Sekunden).
**How to avoid:** Immer aus `Task { }` in `setupTranscription()` aufrufen (bereits so im bestehenden Code). `ParakeetBackend` ist ein `actor` — Methoden sind automatisch off-main-thread.
**Warning signs:** UI reagiert nicht während Download; `@MainActor`-Warnung im Compiler.

### Pitfall 2: I8 — Metal Shader Warmup (5–15 Sekunden)
**What goes wrong:** Erste echte Transkription nach Model-Load dauert 5–15s; User denkt App hängt.
**Why it happens:** Metal-Shader werden beim ersten Inference-Aufruf JIT-kompiliert.
**How to avoid:** Dummy-Inferenz mit `[Float](repeating: 0.0, count: 16000)` nach `loadModels`. Warmup in `downloadAndLoad` des Backends einbauen, nicht separat.
**Warning signs:** Erste Aufnahme nach App-Start dauert unerwartet lang.

### Pitfall 3: AsrModels.downloadAndLoad hat keinen Progress-Handler
**What goes wrong:** Plan versucht `downloadAndLoad(progressHandler:)` zu implementieren mit echten Fortschrittswerten — FluidAudio API hat das nicht.
**Why it happens:** Verwechslung mit WhisperKit's `download(progressCallback:)`.
**How to avoid:** `progressHandler` in `TranscriptionBackend`-Protokoll für Interface-Kompatibilität behalten, aber im `ParakeetBackend` nur 0.0 (Start) und 1.0 (Ende) senden. [VERIFIED: Context7 — Signatur ist `async throws -> AsrModels` ohne Progress-Parameter]
**Warning signs:** Compile-Error bei Versuch, Progress-Callback an `downloadAndLoad` zu übergeben.

### Pitfall 4: WhisperKit Import bleibt in TranscriptionService
**What goes wrong:** `@preconcurrency import WhisperKit` bleibt nach Umbau → Build-Fehler da SPM-Dependency entfernt.
**Why it happens:** Datei wird umgebaut, aber Import vergessen.
**How to avoid:** `TranscriptionService.swift` komplett neu schreiben als Facade. Import durch `import FluidAudio` im Backend ersetzen.

### Pitfall 5: RecordingStateTests schlagen fehl nach neuen Cases
**What goes wrong:** `RecordingStateTests.caseCount()` erwartet genau 4 Cases und schlägt fehl wenn `.warmingUp`, `.modelError`, `.modelLoading` hinzugefügt werden.
**Why it happens:** Test enthält hartkodierte Anzahl `#expect(all.count == 4)`.
**How to avoid:** Test aktualisieren auf neue Anzahl (7) und neue Cases in die `all`-Array aufnehmen. AUCH: alle `switch`-Statements in `RecordingState`-Extension auf Vollständigkeit prüfen (`color`, `systemImage`, `isPulsing`, `pulseSpeed`, `accessibilityLabel`).
**Warning signs:** `RecordingStateTests` Test Suite rot nach Phase 7.

### Pitfall 6: TranscriptionServiceTests referenzieren WhisperKit-interne API
**What goes wrong:** `testMinimumSampleGuardReturnsNil` und `testTranscribeReturnsNilWhenNotReady` rufen `service.transcribe(shortAudio)` auf — diese Methode entfällt in der Facade.
**Why it happens:** Tests testen die alte monolithische `TranscriptionService`-API.
**How to avoid:** Tests auf neues Interface anpassen: `transcribeWithResampling` über Facade testen; für Backend-spezifische Tests ein Mock-Backend verwenden.

### Pitfall 7: pbxproj — 3 Stellen für WhisperKit-Removal
**What goes wrong:** Nur 2 von 3 Stellen entfernt → Build-Fehler oder unresolved package.
**Why it happens:** pbxproj hat separate Sektionen für Package-Reference, Product-Dependency, und Build-File.
**How to avoid:** Alle drei Stellen entfernen:
1. `CAFE0028` in `PBXBuildFile` Section (L41)
2. `CAFE0028` in `PBXFrameworksBuildPhase` (L89)
3. `BEEF0028` in `XCSwiftPackageProductDependency` Section (L683-687)
4. `DEAD0103` in `XCRemoteSwiftPackageReference` Section (L641-648)
5. `DEAD0103` Referenz in `packageReferences` Array (L308)

Danach Package.resolved neu generieren (Xcode macht das automatisch beim nächsten Resolve).

## Code Examples

### Vollständiger FluidAudio-Transkriptions-Pfad

```swift
// Source: Context7 /fluidinference/fluidaudio — README.md + API.md
import FluidAudio

// 1. Download und Load (einmalig beim Start)
let models = try await AsrModels.downloadAndLoad(version: .v3)
let asrManager = AsrManager(config: .default)
try await asrManager.loadModels(models)

// 2. Warmup (nach loadModels, vor erster echter Transkription)
let warmupSamples = [Float](repeating: 0.0, count: 16000) // 1s Stille @ 16kHz
_ = try? await asrManager.transcribe(warmupSamples, source: .microphone)

// 3. Transkription (bei jeder Aufnahme)
let result = try await asrManager.transcribe(samples16kHz, source: .microphone)
print(result.text)   // String
```

### AsrManager.transcribe Signatur
```swift
// Source: Context7 /fluidinference/fluidaudio — Documentation/ASR/TDT-CTC-110M.md
public func transcribe(_ samples: [Float], source: AudioSource = .file) async throws -> ASRResult
```

### ASRResult Struktur
```swift
// Source: Context7 /fluidinference/fluidaudio — API.md
result.text        // String — vollständiges Transkript
result.confidence  // Double — Konfidenzwert (0.0-1.0)
result.tokens      // [Token]? — Word-level timings (optional)
// token.text, token.startTime — wenn tokens != nil
```

### AudioSource Enum (relevante Cases)
```swift
// Source: Context7 /fluidinference/fluidaudio — API.md
.microphone   // Für Mikrofon-Aufnahmen
.file         // Default — für File-basierte Transkription
.system       // Für System-Audio
```

### ManualModelLoading (Fallback)
```swift
// Source: Context7 /fluidinference/fluidaudio — ManualModelLoading.md
// Falls downloadAndLoad nicht funktioniert: manueller Pfad
let repoDirectory = URL(fileURLWithPath: "/opt/models/parakeet-tdt-0.6b-v3-coreml")
let models = try await AsrModels.load(from: repoDirectory, version: .v3)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| WhisperKit (CloudML-konvertiert, ~800MB) | FluidAudio/Parakeet TDT v3 (CoreML, ~66MB RAM) | Phase 7 (dieser Sprint) | 66MB RAM statt ~2GB MLX; ~110x RTF auf M4 Pro; keine Python-Bridge |
| Monolithischer TranscriptionService | TranscriptionBackend-Protokoll + Facade | Phase 7 | Austauschbare Backends; WhisperKit als dokumentierter Fallback |
| Python-Subprocess-Bridge (aus v0.19.0-Planung) | FluidAudio native Swift SPM | Vorab entschieden in SUMMARY.md | Kein venv-Bundling, kein SIP-Problem, kein codesign-Aufwand |

**Deprecated/outdated:**
- `WhisperKit` und `@preconcurrency import WhisperKit`: Wird in Phase 7 aus `TranscriptionService` entfernt. `WhiskerKitBackend.swift` bleibt als auskommentierte Fallback-Datei.
- `TranscriptionService.transcribe(_ samples: [Float])`: Direkte Methode entfällt; nur noch `transcribeWithResampling` als öffentliche API (Facade).
- `WhisperKitConfig`, `DecodingOptions`, `DecodingTask` — alle WhisperKit-spezifischen Typen entfallen.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Warmup mit 1s Null-Samples (16000 Float) ist ausreichend für Metal-Shader-Kompilierung | Code Examples | Warmup zu kurz → erste echte Transkription immer noch langsam. Mitigation: 2–3s Dummy-Audio verwenden (32000–48000 Samples). |
| A2 | `~/Library/Application Support/FluidAudio/Models` ist der tatsächliche Cache-Pfad von FluidAudio v0.12.4 | Architecture Patterns (Pattern 5) | Cache-Check (D-07) schlägt immer fehl → unnötiger Spinner bei jedem Start. Mitigation: Pfad beim ersten Build verifizieren oder Cache-Check ganz weglassen (FluidAudio handled Caching intern). |
| A3 | `AsrManager(config: .default)` ist die korrekte Init-Signatur | Code Examples | Compile-Error. Mitigation: Context7 zeigt `config: .default` in Beispielen [CITED: Context7]. |
| A4 | `AsrModels.downloadAndLoad(version: .v3)` prüft intern ob Modell bereits gecacht ist | Architecture Patterns | Double-Download bei App-Restart. Kontext7-Docs sagen: "checks a cache directory for existing models" [CITED: Context7 /fluidinference/fluidaudio TDT-CTC-110M.md]. Wahrscheinlichkeit gering. |

**Zu A1 kritische Anmerkung:** Falls Metal-Warmup länger als die `.warmingUp`-State-Anzeige dauert, ist das kein Fehler — `isModelReady=true` wird erst nach abgeschlossener `downloadAndLoad` (inklusive Warmup) gesetzt. Der Guard in `startRecordingWithCue` verhindert Aufnahme-Start. [ASSUMED]

## Open Questions (RESOLVED)

1. **Progress-Handler: Zwischenwerte während CoreML-Compilation**
   - What we know: `downloadAndLoad` hat keinen nativen Progress-Parameter.
   - What's unclear: Ob CoreML-Compilation (nach Download) mehrere Sekunden dauert und ebenfalls gezeigt werden sollte.
   - **RESOLVED:** Deferred to first-build validation per CONTEXT.md Claude's Discretion area. Spinner + Größen-Hinweis (D-06) ist ausreichend für Phase 7; Zwischenwert-Feedback kann in Phase 9 nachgerüstet werden wenn Compilation > 5s dauert.

2. **`source: .microphone` vs `source: .file` für Qualität**
   - What we know: `AudioSource` hat `.microphone`, `.file`, `.system`. API-Docs zeigen beide in Beispielen.
   - What's unclear: Ob `source` die Inferenz-Parameter beeinflusst (z.B. stärkere Noise-Reduction für Mikrofon).
   - **RESOLVED:** Deferred to first-build validation per CONTEXT.md Claude's Discretion area. Plan 07-04 verwendet `.microphone` als Default; Qualitätsvergleich in Phase 9 (Integrations-Validierung).

3. **RecordingStateTests.caseCount() und andere bestehende Tests**
   - What we know: Test erwartet `count == 4`; nach Phase 7 gibt es 7 Cases.
   - What's unclear: Ob weitere Tests hard-coded Assumptions über RecordingState-Cases haben.
   - **RESOLVED:** Wave 0 (Plan 07-01) aktualisiert `RecordingStateTests.caseCount()` auf 8 und fügt alle neuen Cases zu allen switch-Statements hinzu. Vollständig geplant.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | SPM FluidAudio hinzufügen, Build | ✓ | macOS 25.4 (Darwin) | — |
| Swift 6.1.2 | FluidAudio erfordert Swift 5.9+ | ✓ | swift-6.1.2-RELEASE | — |
| Internet-Zugang beim ersten Start | `AsrModels.downloadAndLoad` HuggingFace | [ASSUMED: ✓] | — | Manuelles Model-Staging via `AsrModels.load(from:)` |
| macOS 14+ Deployment Target | FluidAudio CoreML-APIs | ✓ | In Package.swift: `.macOS(.v14)` | — |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (import Testing) |
| Config file | Xcode Project — VoiceScribeTests Target |
| Quick run command | `xcodebuild test -scheme VoiceScribe -destination 'platform=macOS' -only-testing:VoiceScribeTests/TranscriptionServiceTests 2>&1 \| tail -20` |
| Full suite command | `xcodebuild test -scheme VoiceScribe -destination 'platform=macOS' 2>&1 \| tail -30` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RECORD-04 | ParakeetBackend.transcribeWithResampling gibt nil bei < 1600 Samples zurück | unit | `xcodebuild test ... -only-testing:VoiceScribeTests/TranscriptionServiceTests` | ❌ Wave 0 (bestehend aber anpassen) |
| RECORD-04 | ParakeetBackend.transcribeWithResampling gibt nil wenn nicht geladen | unit | `xcodebuild test ... -only-testing:VoiceScribeTests/TranscriptionServiceTests` | ❌ Wave 0 (umbenennen/anpassen) |
| RECORD-05 | ParakeetBackend.isModelReady ist false nach Init | unit | `xcodebuild test ... -only-testing:VoiceScribeTests/TranscriptionServiceTests` | ❌ Wave 0 (bereits vorhanden, anpassen) |
| RECORD-04 | resampleTo16kHz bleibt korrekt (48kHz→16kHz) | unit | `xcodebuild test ... -only-testing:VoiceScribeTests/TranscriptionServiceTests` | ✅ (TranscriptionServiceTests bleibt gültig) |
| D-03/D-09 | RecordingState hat .warmingUp und .modelError Cases | unit | `xcodebuild test ... -only-testing:VoiceScribeTests/RecordingStateTests` | ❌ Wave 0 (bestehend, count ändern) |
| D-08 | AppState.isModelError existiert und ist initial false | unit | `xcodebuild test ... -only-testing:VoiceScribeTests/AppStateTests` | ❌ Wave 0 (neuer Test) |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme VoiceScribe -destination 'platform=macOS' -only-testing:VoiceScribeTests/TranscriptionServiceTests -only-testing:VoiceScribeTests/RecordingStateTests 2>&1 | tail -20`
- **Per wave merge:** Full suite
- **Phase gate:** Full suite green vor `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `VoiceScribeTests/TranscriptionServiceTests.swift` — bestehende Tests auf neue Facade-API anpassen (mock Backend), `transcribe()` → `transcribeWithResampling()` via Facade; neuer Test für ParakeetBackend.isModelReady
- [ ] `VoiceScribeTests/RecordingStateTests.swift` — `caseCount()` von 4 auf 7 aktualisieren; neue Cases hinzufügen
- [ ] `VoiceScribeTests/AppStateTests.swift` — Test für `isModelError: Bool` (initital false) hinzufügen

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes (teilweise) | Minimum-Sample-Guard (< 1600 Samples) verhindert Crash-Pfade in AsrManager |
| V6 Cryptography | no | — |

### Known Threat Patterns for FluidAudio/CoreML

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Manipuliertes Modell im Cache | Tampering | FluidAudio cached in App-specific `~/Library/Application Support` — kein user-writable Pfad außerhalb der App-Sandbox (kein Risk da no Sandbox in dieser App) |
| Extrem langes Audio → Memory Pressure | DoS | Minimum-Sample-Guard + bestehende AudioController-Stille-Erkennung begrenzt Länge |

## Sources

### Primary (HIGH confidence)
- Context7 `/fluidinference/fluidaudio` — Score 89.75; `AsrModels.downloadAndLoad`, `AsrManager.transcribe`, `ASRResult`, `AudioSource`, SPM-URL, Swift-6-Concurrency-Anforderungen
- Existing codebase: `VoiceScribe/Transcription/TranscriptionService.swift` — bestehende API-Kontrakte, Resampling-Implementierung
- Existing codebase: `VoiceScribe/AppState.swift` — RecordingState-Enum (5 Cases: idle, recording, transcribing, llmProcessing, error), isModelReady-Pattern
- Existing codebase: `VoiceScribe/AppDelegate.swift` — setupTranscription(), onRecordingComplete-Callback
- Existing codebase: `VoiceScribe.xcodeproj/project.pbxproj` — WhisperKit-Referenzen an 5 Stellen (CAFE0028, BEEF0028, DEAD0103)

### Secondary (MEDIUM confidence)
- `.planning/research/SUMMARY.md` — FluidAudio-Pitfalls C4/I8, Wave-Struktur, Modellgröße ~1.2GB
- `.planning/phases/07-parakeet-backend/07-CONTEXT.md` — alle D-Entscheidungen

### Tertiary (LOW confidence / Hands-on validation needed)
- FluidAudio Cache-Pfad `~/Library/Application Support/FluidAudio/Models` — in SUMMARY.md aus Community-Quellen; beim ersten Build verifizieren
- Warmup-Dauer mit 1s Null-Audio — aus mlx-community Benchmarks [ASSUMED]; beim ersten Build messen

## Metadata

**Confidence breakdown:**
- FluidAudio API (downloadAndLoad, transcribe, ASRResult): HIGH — Context7 verifiziert
- pbxproj WhisperKit-Removal Stellen: HIGH — direkte Codebase-Analyse
- RecordingState neue Cases: HIGH — bestehender Code analysiert, neue Cases klar
- Warmup-Implementierung: MEDIUM — Pattern aus SUMMARY.md; genaue Dummy-Länge ASSUMED
- Cache-Pfad-Check: MEDIUM — in SUMMARY.md dokumentiert, beim Build zu verifizieren

**Research date:** 2026-04-24
**Valid until:** 2026-05-24 (FluidAudio 0.12.x API stabil; prüfen bei neuerer Major Version)
