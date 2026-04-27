# Architecture Research

**Project:** SPRECHKRAFT — macOS Menu Bar Dictation App
**Researched:** 2026-04-15 (urspruenglich) / 2026-04-21 (aktualisiert fuer Milestone v0.19.0)
**Overall confidence:** HIGH (alle wesentlichen Befunde aus Context7, GitHub-Quellen und Codebase-Analyse)

---

## UPDATE: Milestone v0.19.0 — Integration Architecture

Dieser Abschnitt erweitert die urspruengliche Architektur-Research (unten) um spezifische
Integrationsentscheidungen fuer die zwei neuen Funktionen von Milestone v0.19.0:

1. Parakeet v3 als Python/MLX-Subprocess, der WhisperKit ersetzt
2. Konsolidiertes Einstellungsfenster

---

## Frage 1: Python Subprocess Bridge -- Architekturoptionen

### Uebersicht der IPC-Methoden

Drei Mechanismen stehen zur Wahl fuer die Kommunikation zwischen Swift-Host und Python-Kindprozess:

| Kriterium | stdin/stdout Pipes | Unix Domain Socket | Temp-Datei |
|-----------|-------------------|-------------------|------------|
| **Latenz** | ~0ms Overhead, kernel-gepuffert | ~0ms, etwas hoeher bei Setup | 10-100ms (Disk-I/O) |
| **Throughput fuer Audio** | Gut fuer <100 MB | Sehr gut, bidirektional | Schlecht (WAV-Roundtrip) |
| **Prozess-Lifecycle** | Eng gekoppelt -- Pipe-EOF beendet Kind | Entkoppelt moeglich | Vollstaendig entkoppelt |
| **Fehlerbehandlung** | EOF-Signal bei Crash ist deterministisch | TCP-aehnliches Reconnect moeglich | Race conditions moeglich |
| **Komplexitaet** | Gering (Swift `Process`, Foundation Pipe) | Mittel (POSIX socket API) | Gering, aber unzuverlaessig |
| **Eignung fuer Push-to-Talk** | HOCH -- eine Transkription pro Aufruf | MITTEL -- Overhead lohnt nicht | NIEDRIG |

**Empfehlung: stdin/stdout Pipe mit JSON-Envelopes und binaeren Audio-Daten.**

Begruendung:
- Push-to-talk produziert eine Aufnahme, die einmal transkribiert wird; kein dauerhafter
  bidirektionaler Stream noetig
- Unix Domain Sockets haben keinen Latenz-Vorteil fuer diesen Ein-Anfrage-pro-Aufnahme-Modus
- stdin/stdout-EOF ist das natuerlichste Crash-Signal: Kindprozess stirbt -> Pipe bricht -> Swift
  erkennt sofort; kein Zombie-Socket
- Implementierung mit Foundation `Process` + `Pipe` ist in Swift direkt verfuegbar, ohne
  Drittbibliotheken
- Das neue `swift-subprocess`-Paket (September 2025, swiftlang/swift-subprocess) loest das
  bekannte Deadlock-Problem bei grossen Daten, ist aber optional -- Foundation `Process` mit
  asynchronem Drain reicht fuer diesen Anwendungsfall

**Achtung (HIGH-confidence Pitfall): Naives Lesen von `pipe.fileHandleForReading.readDataToEndOfFile()`
blockiert den Main Thread und deadlockt sobald der Pipe-Buffer voll ist (typisch 64 KB auf macOS).
Stattdessen: `readabilityHandler` oder `AsyncBytes`-Drain verwenden.**

### Protokolldesign: JSON-Envelope + Raw PCM

```
Swift -> Python (stdin):
{
  "cmd": "transcribe",
  "sample_rate": 16000,
  "samples_count": 48000,
  "audio_follows_bytes": 192000
}
\n
<192000 raw bytes: Float32 LE PCM, 16 kHz mono>

Python -> Swift (stdout):
{
  "status": "ok",
  "text": "Transkribierter Text hier",
  "duration_ms": 340
}
\n
```

Alternativ: WAV-Header voranstellen und Parakeet `model.transcribe(file)` mit tempfile nutzen --
aber das erzeugt einen Datei-Roundtrip. Die Raw-PCM-Route mit direktem `model.transcribe(samples)`
ist sauberer und schneller.

### Prozess-Lifecycle-Strategie

**Warm-Start-Modell (empfohlen):** Python-Prozess wird beim App-Start gestartet, haelt das Modell
im Speicher, wartet in einer `while True: ...`-Schleife auf stdin-Requests. Keine Neuladezeit
pro Diktat (~340ms cold load entfaellt).

```
App-Start:
  LaunchPythonBridge() -> Process laeuft, Modell geladen (3-8s)
  -> isModelReady = true

Diktat:
  sendTranscribeRequest([Float], sampleRate) -> JSON + PCM auf stdin
  receiveResponse() -> JSON von stdout
  -> String zurueck (~ 300-500ms Inferenz)

App-Beenden:
  stdin.close() -> Python exit(0) via EOF-Guard -> kein Zombie
```

**Kalt-Start-Modell (Alternative):** Neuer Prozess pro Diktat. Einfacher aber ~3-8s Latenz
pro Aufruf -- inakzeptabel fuer Push-to-Talk. Nicht empfohlen.

---

## Frage 2: TranscriptionService -- Umbau zu pluggablem Backend

### Ist-Zustand (WhisperKit-spezifisch)

```swift
actor TranscriptionService {
    private var whisperKit: WhisperKit?

    func downloadAndLoad(progressHandler: @MainActor @escaping (Double) -> Void) async { ... }
    func transcribeWithResampling(_ samples: [Float], sampleRate: Double) async -> String? { ... }
    func transcribe(_ samples: [Float]) async -> String? { ... }
    func resampleTo16kHz(...) -> [Float] { ... }
}
```

Das WhisperKit-Objekt und alle WhisperKit-spezifischen APIs liegen direkt im Actor.

### Soll-Architektur: Protokoll + zwei Implementierungen

**Schritt 1: Protokoll `TranscriptionBackend` definieren**

```swift
/// Konformitaetsprotokoll fuer austauschbare Transkriptions-Backends.
/// Alle Implementierungen muessen @MainActor-sicher sein (da als actor implementiert).
protocol TranscriptionBackend: Sendable {
    /// Laedt Modell herunter / initialisiert. progressHandler auf @MainActor.
    func downloadAndLoad(progressHandler: @MainActor @escaping (Double) -> Void) async

    /// Transkribiert PCM-Samples. Samples koennen beliebige Samplerate haben.
    func transcribeWithResampling(_ samples: [Float], sampleRate: Double) async -> String?

    /// true nach erfolgreichem downloadAndLoad()
    var isModelReady: Bool { get async }
}
```

**Schritt 2: `ParakeetBackend` actor implementieren**

```swift
actor ParakeetBackend: TranscriptionBackend {
    private var bridge: PythonSubprocessBridge?
    private(set) var isModelReady: Bool = false

    func downloadAndLoad(progressHandler: @MainActor @escaping (Double) -> Void) async {
        // 1. Check ob bundled Python + Modell vorhanden (venv in app bundle)
        // 2. Python-Kindprozess starten
        // 3. Warten auf "ready"-Signal von Python (stdout JSON)
        // 4. progressHandler(1.0), isModelReady = true
    }

    func transcribeWithResampling(_ samples: [Float], sampleRate: Double) async -> String? {
        let samples16k = resampleTo16kHz(samples, fromSampleRate: sampleRate)
        return await bridge?.transcribe(samples16k, sampleRate: 16000)
    }
}
```

**Schritt 3: `WhisperKitBackend` -- bestehender Code refaktoriert**

```swift
actor WhisperKitBackend: TranscriptionBackend {
    // Bisheriger TranscriptionService-Code mit minimalem Renaming
    private var whisperKit: WhisperKit?
    private(set) var isModelReady: Bool = false
    // ... (identisch zum bestehenden TranscriptionService)
}
```

**Schritt 4: `TranscriptionService` als Facade**

```swift
actor TranscriptionService {
    private var backend: any TranscriptionBackend

    /// Wechsel via Defaults[.transcriptionBackend] -- aktuell nur .parakeet
    init(backend: any TranscriptionBackend = ParakeetBackend()) {
        self.backend = backend
    }

    var isModelReady: Bool {
        get async { await backend.isModelReady }
    }

    func downloadAndLoad(progressHandler: @MainActor @escaping (Double) -> Void) async {
        await backend.downloadAndLoad(progressHandler: progressHandler)
    }

    func transcribeWithResampling(_ samples: [Float], sampleRate: Double) async -> String? {
        await backend.transcribeWithResampling(samples, sampleRate: sampleRate)
    }
}
```

**AppDelegate-Aenderungen: minimal.** Der bestehende Code in `AppDelegate.swift` ruft
`transcriptionService.downloadAndLoad(...)` und `transcriptionService.transcribeWithResampling(...)`
auf -- diese Signaturen bleiben identisch. AppDelegate muss nicht veraendert werden.

### Wichtige Anmerkung: FluidAudio als Alternative zu Python-Bridge

**HIGH-confidence Neuentdeckung (2025):** FluidInference hat Parakeet TDT v3 in CoreML portiert
und als Swift Package veroeffentlicht: `FluidInference/FluidAudio` (v0.12.4, 1500+ GitHub Stars,
bereits in VoiceInk und 20+ Production-Apps im Einsatz).

```swift
// FluidAudio API (aus Context7-Dokumentation):
let models = try await AsrModels.downloadAndLoad(version: .v3) // auto-HuggingFace-Download
let asrManager = AsrManager(config: .default)
try await asrManager.loadModels(models)
let result = try await asrManager.transcribe(samples) // samples: [Float] 16kHz mono
print(result.text)
```

FluidAudio-Vorteile gegenueber Python-Bridge:
- Natives Swift, kein Python-Prozess, kein venv-Bundling
- Neural Engine statt MLX/GPU: 66 MB Arbeitsspeicher vs. ~2 GB MLX
- ~110x RTF auf M4 Pro (1 Minute Audio = 0,5 Sekunden)
- SPM-Integration: `https://github.com/FluidInference/FluidAudio.git`
- Progress-Handler bei Download (`progressHandler: { progress in }`)

**Empfehlung fuer Milestone v0.19.0:** FluidAudio als `ParakeetBackend`-Implementierung
statt Python-Bridge verwenden. Das Protokoll-Design bleibt identisch -- nur die Implementierung
von `ParakeetBackend` aendert sich.

```swift
actor ParakeetBackend: TranscriptionBackend {
    private var asrManager: AsrManager?
    private(set) var isModelReady: Bool = false

    func downloadAndLoad(progressHandler: @MainActor @escaping (Double) -> Void) async {
        do {
            // FluidAudio: Modell-Download mit optionalem progressHandler
            let models = try await AsrModels.downloadAndLoad(version: .v3)
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            self.asrManager = manager
            self.isModelReady = true
            await progressHandler(1.0)
        } catch {
            print("[ParakeetBackend] Download/Load fehlgeschlagen: \(error)")
        }
    }

    func transcribeWithResampling(_ samples: [Float], sampleRate: Double) async -> String? {
        guard let manager = asrManager, isModelReady else { return nil }
        let samples16k = resampleTo16kHz(samples, fromSampleRate: sampleRate)
        guard samples16k.count >= 1600 else { return nil }
        do {
            let result = try await manager.transcribe(samples16k)
            return result.text.trimmingCharacters(in: .whitespaces)
        } catch {
            return nil
        }
    }
}
```

Falls FluidAudio nicht ausreicht (z.B. Sprachunterstuetzung, Lizenz), ist die Python-Bridge-Option
mit identischer Backend-Protokoll-Schnittstelle als Fallback weiterhin realisierbar.

---

## Frage 3: Modell-Download beim Erststart

### Integration in den App-Lifecycle

**Wo:** `AppDelegate.setupTranscription()` -- bereits vorhanden, handhabt WhisperKit-Download.
Kein neues Konzept noetig, nur Austausch der Backend-Implementierung.

**Aktueller Code:**
```swift
private func setupTranscription() {
    Task {
        await transcriptionService.downloadAndLoad { [weak self] fraction in
            let pct = Int(fraction * 100)
            self?.statusItem.button?.title = pct < 100 ? "down \(pct)%" : ""
        }
        statusItem.button?.title = ""
        appState?.isModelReady = await transcriptionService.isModelReady
        updateIcon()
    }
}
```

Dieser Code funktioniert unveraendert fuer FluidAudio/ParakeetBackend, sofern `downloadAndLoad`
regelmaessige `progressHandler`-Aufrufe liefert.

**Fortschrittsanzeige:** Aktuell NSStatusItem-Title mit Prozentwert. Fuer FluidAudio muss der
Progress-Callback aus der `AsrModels.downloadAndLoad`-API gemappt werden. Die FluidAudio-Doku
zeigt `progressHandler: { progress in }` in `LSEENDModelDescriptor.loadFromHuggingFace` --
fuer `AsrModels.downloadAndLoad` muss geprueft werden ob ein vergleichbarer Handler existiert.

**AppState.isModelReady** bleibt die einzige Guard-Variable: Aufnahme-Start in
`startRecordingWithCue()` prueft bereits `appState?.isModelReady == true`. Keine weiteren
UI-Aenderungen noetig.

**Fehlerfall:** Wenn Download scheitert, bleibt `isModelReady = false`. Aufnahmen sind blockiert.
Bestehender Kommentar "D-13: stille Rueckkehr" bleibt die Strategie. Fuer Milestone v0.19.0
empfiehlt sich ein einmaliger Retry-Button in der SettingsView (neues UI-Element).

---

## Frage 4: Settings-Fenster Integration

### Ist-Zustand

Das Settings-Fenster existiert bereits:
- `Window("SPRECHKRAFT -- Einstellungen", id: "settings")` in `SPRECHKRAFTApp.swift`
- Oeffnung via `NotificationCenter.post(.openSettings)` -> `HiddenActivationView.onReceive` ->
  `openWindow(id: "settings")` mit Activation-Policy-Workaround (300ms)
- `SettingsView.swift` enthaelt vollstaendige SwiftUI-Form mit Mikrofon, Stille-Erkennung,
  Textausgabe, Groq-API-Key und Prompt-Profile-Sektionen

### Neue Sektionen fuer Milestone v0.19.0

Folgende Einstellungen muessen hinzugefuegt werden (aus PROJECT.md):
- Hotkey-Konfiguration UI mit Konflikt-Erkennung (bereits teilweise via KeyboardShortcuts.Recorder)
- Mikrofon-Auswahl (bereits vorhanden via `AudioDeviceManager.availableMicrophones()`)
- Silence Detection Threshold (bereits vorhanden)

Noch fehlend in SettingsView:
- **Transkriptions-Engine Auswahl** (wenn mehrere Backends unterstuetzt): `Picker`
- **Modell-Status / Retry-Button** wenn Download fehlschlug
- **Hotkey-Sektion** fuer Haupthotkey (`.toggleRecording`) -- fehlt noch

### Empfehlung: Keine Architektur-Aenderung an Settings-Oeffnung

Das bestehende `Window`-Scene-Pattern mit NotificationCenter-Bruecke funktioniert stabil und
ist bereits fuer History und Settings validiert. Kein Wechsel zu:
- `NSWindowController` (mehr AppKit-Boilerplate, kein Vorteil gegenueber bestehendem Pattern)
- `sindresorhus/Settings` (zusaetzliche Abhaengigkeit, nicht noetig da native SwiftUI Form ausreicht)
- `.settings` SwiftUI Scene (bekanntes Problem mit `.accessory`-Policy auf macOS -- bereits
  dokumentiert in SPRECHKRAFTApp.swift Kommentar)

**Bestehende Architektur beibehalten:** `Window(id: "settings")` + NotificationCenter-Bruecke
+ `SettingsView` als SwiftUI Form. Neue Einstellungs-Sektionen als zusaetzliche `Section()`-Bloecke
in die bestehende `SettingsView.swift` einfuegen.

### SettingsView-Erweiterungen konkret

```swift
// Neue Sektion in SettingsView (Reihenfolge nach bestehenden Sektionen):
Section("Transkription") {
    // Modell-Status
    HStack {
        if appState?.isModelReady == true {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text("Parakeet-Modell bereit")
        } else {
            Image(systemName: "arrow.down.circle").foregroundStyle(.secondary)
            Text("Modell wird geladen...")
        }
    }
    // Ggf. Retry-Button wenn isModelReady == false nach x Minuten
}

Section("Hotkeys") {
    KeyboardShortcuts.Recorder("Diktat-Hotkey", name: .toggleRecording)
    // Profil-Hotkeys werden im Profil-Editor konfiguriert (bereits vorhanden)
}
```

---

## Neue Komponenten: Uebersicht

| Komponente | Status | Prioritaet | Abhaengigkeiten |
|------------|--------|------------|----------------|
| `TranscriptionBackend` Protokoll | Neu | P0 | -- |
| `WhisperKitBackend` | Refaktor (aus TranscriptionService) | P0 | WhisperKit |
| `ParakeetBackend` (FluidAudio) | Neu | P0 | FluidAudio SPM |
| `TranscriptionService` als Facade | Refaktor | P0 | TranscriptionBackend |
| SettingsView neue Sektionen | Erweiterung | P1 | TranscriptionService.isModelReady |
| Python Subprocess Bridge | Alternativ-Option | Optional | Nur wenn FluidAudio nicht ausreicht |

---

## Build-Reihenfolge fuer Milestone v0.19.0

### Wave 1 -- Protokoll + FluidAudio Backend (Blockiert alles andere)

1. `TranscriptionBackend`-Protokoll definieren (neue Datei `TranscriptionBackend.swift`)
2. Bestehenden `TranscriptionService`-Code zu `WhisperKitBackend` extrahieren
3. `TranscriptionService` als Facade mit Backend-Property
4. `ParakeetBackend` mit FluidAudio `AsrModels.downloadAndLoad` + `AsrManager.transcribe`
5. AppDelegate: `transcriptionService = TranscriptionService(backend: ParakeetBackend())`

Verifikation: `setupTranscription()` in AppDelegate laeuft ohne Aenderungen durch.
WhisperKit als Fallback bleibt ueber `WhisperKitBackend` erreichbar.

### Wave 2 -- Settings-Erweiterungen (Unabhaengig von Wave 1)

6. Neue `Section("Hotkeys")` in SettingsView (toggleRecording Recorder)
7. Neue `Section("Transkription")` mit Modell-Status in SettingsView
8. AppState: Ggf. `downloadProgress: Double` als Observable-Property hinzufuegen
   (fuer ProgressView in Settings statt nur StatusItem-Title)

### Wave 3 -- Integration & Validierung

9. End-to-End-Test: Diktat -> ParakeetBackend -> TextOutput -> HistoryStore
10. Vergleich WhisperKit vs. Parakeet Transkriptionsqualitaet auf Deutsch
11. Download-Fortschritt-UX pruefen (StatusItem-Title bleibt die primaere Anzeige)

---

## Datenfluß-Aenderungen

### Vorher (WhisperKit direkt in TranscriptionService)

```
onRecordingComplete -> transcriptionService.transcribeWithResampling()
                           |
                      WhisperKit.transcribe()
                           |
                      String?
```

### Nachher (Backend-Protokoll)

```
onRecordingComplete -> transcriptionService.transcribeWithResampling()
                           |
                      backend.transcribeWithResampling()  // ParakeetBackend
                           |
                      AsrManager.transcribe()  // FluidAudio
                           |
                      String?
```

AppDelegate `onRecordingComplete` bleibt **unveraendert** -- das ist der entscheidende
Vorteil der Facade-Schicht.

---

## Integrations-Risiken

| Risiko | Wahrscheinlichkeit | Mitigierung |
|--------|-------------------|-------------|
| FluidAudio Download-API hat keinen Progress-Handler fuer `.v3` | MEDIUM | Fake-Progress (0% -> 100%) oder DownloadUtils direkt; akzeptabel da StatusItem-Title nur grob anzeigt |
| FluidAudio Deutsch-Qualitaet schlechter als WhisperKit | LOW | Parakeet TDT v3 trainiert auf 85k Stunden Englisch + 25 EU-Sprachen; Deutsch enthalten |
| FluidAudio API-Aenderungen (v0.12.4, noch nicht 1.0) | MEDIUM | Protokoll-Facade isoliert AppDelegate von API-Aenderungen; nur ParakeetBackend muss angepasst werden |
| Model-Downloadgroesse > erwartet | LOW | FluidAudio cached in ~/Library/Application Support/FluidAudio/Models -- App-Bundle bleibt klein |
| Swift 6 Concurrency-Konformitaet von FluidAudio | MEDIUM | Context7-Doku zeigt actor-basiertes API-Design; bei Problemen `@preconcurrency import FluidAudio` wie bestehend bei WhisperKit |

---

## Komponenten-Grenzen nach Milestone v0.19.0

```
SPRECHKRAFTApp (SwiftUI @main)
+-- AppDelegate (NSStatusItem, Hotkeys, Callbacks)
|   +-- AudioController (AVAudioEngine)
|   +-- TranscriptionService (Facade, actor)
|   |   +-- ParakeetBackend (actor)  <-- NEU
|   |   |   +-- AsrManager (FluidAudio)
|   |   +-- WhisperKitBackend (actor)  <-- Fallback
|   +-- GroqService (URLSession)
|   +-- TextOutputService (AXUIElement + NSPasteboard)
|   +-- HistoryStore (GRDB)
+-- Window Scenes
    +-- "hidden" (HiddenActivationView -- Notifications)
    +-- "settings" (SettingsView -- ERWEITERT)
    +-- "history" (HistoryView)
```

---

## Quellen

- FluidAudio (Context7): `/fluidinference/fluidaudio` -- HIGH confidence, 89.75 Benchmark Score
- FluidAudio GitHub: https://github.com/FluidInference/FluidAudio (v0.12.4, ~1500 stars, Production-ready)
- parakeet-mlx (Context7): `/senstella/parakeet-mlx` -- Python-only, Swift-Bridge-Option dokumentiert
- swift-subprocess (swiftlang): https://github.com/swiftlang/swift-subprocess -- moderne Alternative zu Process, September 2025
- TypeWhisper pluggable backend pattern: https://github.com/TypeWhisper/typewhisper-mac
- steipete.me Settings from Menu Bar: https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items
- IPC Performance (Baeldung): https://www.baeldung.com/linux/ipc-performance-comparison
- Bestehende Codebase: SPRECHKRAFT/AppDelegate.swift, SPRECHKRAFT/Transcription/TranscriptionService.swift, SPRECHKRAFT/SPRECHKRAFTApp.swift, SPRECHKRAFT/SettingsView.swift

---

## URSPRUENGLICHE ARCHITEKTUR-RESEARCH (Phase 1-6)

*(Bewahrt als Referenz -- gilt weiterhin fuer alle bereits implementierten Komponenten)*

### 1. App Shell -- MenuBarApp

**Responsibility:** Entry point, NSStatusItem lifecycle, top-level state coordinator.

**Decision: Use NSApplicationDelegate + NSStatusItem directly, not SwiftUI MenuBarExtra.**

Rationale: MenuBarExtra (introduced macOS 13) is convenient for simple menus, but it has
constraints that conflict with this app's needs: it cannot easily host animated icons driven
by external state (recording in progress), and it offers no onKeyDown/onKeyUp hooks for
push-to-talk. NSStatusItem + NSStatusBarButton gives full control over icon animation,
click handling, and menu attachment.

LSUIElement = YES in Info.plist keeps the app out of the Dock and App Switcher.
Confidence: HIGH (Apple NSStatusItem docs, confirmed pattern)

### 2. Hotkey Engine

**Decision: Use KeyboardShortcuts Swift package (sindresorhus/keyboardshortcuts).**
Confidence: HIGH (KeyboardShortcuts Context7 docs, GitHub README)

### 3. Audio Pipeline

**Stack: AVAudioEngine with installTap on the input node.**
Confidence: HIGH

### 4. LLM Post-Processor

**Stack: URLSession async/await, no third-party HTTP library needed.**
Confidence: HIGH (Groq API is OpenAI-compatible; standard URLSession pattern)

### 5. Output Engine

Two modes: AXUIElement injection (preferred) + NSPasteboard + CGEvent fallback.
Confidence: MEDIUM (AXUIElement injection works for most apps)

### 6. History Store

**Decision: Use GRDB.swift (v7.5.0) over SwiftData.**
FTS5 full-text search, GRDB async DatabasePool.
Confidence: HIGH (GRDB Context7 docs, FTS documentation confirmed)

### Key Architecture Decisions (original)

1. AppDelegate + NSStatusItem over pure SwiftUI MenuBarExtra
2. WhisperKit initially (now replaced by Parakeet/FluidAudio in v0.19.0)
3. Actor isolation for ML services
4. GRDB over SwiftData for history
5. Two-mode text output with graceful fallback
6. Lazy model loading with explicit unload

### macOS Permissions Required

| Permission | Why Needed |
|---|---|
| Microphone (NSMicrophoneUsageDescription) | AVAudioEngine captures mic input |
| Accessibility | AXUIElement text injection and CGEvent keyboard simulation |

Additional Info.plist keys: LSUIElement = YES, SMAppService.mainApp.register() fuer Login Item.

### Sources (original)

- NSStatusItem: https://developer.apple.com/documentation/appkit/nsstatusitem
- KeyboardShortcuts: Context7 /sindresorhus/keyboardshortcuts (HIGH)
- WhisperKit: Context7 /argmaxinc/whisperkit (HIGH)
- GRDB.swift: Context7 /groue/grdb.swift (HIGH)
- parakeet-mlx: Context7 /senstella/parakeet-mlx -- Python-only (HIGH)
