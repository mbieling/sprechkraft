# Phase 2: Audio Capture — Research

**Researched:** 2026-04-17
**Domain:** AVAudioEngine, AVCaptureDevice, NSSound, SwiftUI Canvas, Swift 6 Strict Concurrency
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Visualisierungsform: Waveform-Linie unterhalb des mic.fill-Symbols
- **D-02:** Position: direkt unterhalb des Mic-Icons (Mic bleibt oben und zentriert sichtbar)
- **D-03:** Linie oszilliert in Echtzeit entsprechend dem RMS-Pegel (0.0–1.0)
- **D-04:** Bestehendes Pulse-System (Phase 1) bleibt für .recording aktiv; Waveform ergänzt es als zweites Layer
- **D-05:** Tonquelle: NSSound System-Töne (kein Bundle-Asset, kein AVAudioEngine-Ton)
- **D-06:** Start und Stopp erhalten unterschiedliche Töne (z.B. „Tink" für Start, „Pop" für Stopp)
- **D-07:** Auto-Stopp durch Stille spielt denselben Stopp-Ton wie manueller Stopp
- **D-08:** Stille-Erkennung via RMS-Schwellwert — wenn Energie unter Schwellwert für N Sekunden → Auto-Stopp
- **D-09:** Standard-Stille-Dauer: 1.5 Sekunden
- **D-10:** Stille-Dauer konfigurierbar (SET-03); wirkt ab nächster Aufnahme
- **D-11:** Mikrofon-Auswahl ausschließlich im Settings-Fenster als Dropdown
- **D-12:** Kein Schnellzugriff im Menü nötig
- **D-13:** Fehlerpfad Berechtigung: Roter Banner in Settings + Button öffnet macOS Datenschutz-Einstellungen
- **D-14:** Kein Crash oder stille Fehler — Permission-State wird vor AVAudioEngine-Start geprüft

### Claude's Discretion
- Genaue NSSound-Namen für Start und Stopp
- AVAudioEngine Tap-Puffer-Größe und Samplerate
- RMS-Schwellwert-Wert für Stille-Erkennung (default)
- Waveform-Linien-Rendering: Anzahl der dargestellten Samples und Canvas-Größe

### Deferred Ideas (OUT OF SCOPE)
Keine — Diskussion blieb im Phase-Scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RECORD-01 | Hotkey startet und stoppt Aufnahme (Toggle) | AVAudioEngine start/stop; AppState.toggleRecording() ersetzt Demo-Cycle durch echte Logik |
| RECORD-02 | Automatischer Stopp nach konfigurierbarer Stille-Dauer | RMS-Pegel aus installTap-Callback; Timer-basierter Silence-Detector im AudioController |
| RECORD-03 | Mikrofon-Eingabegerät in Einstellungen wählbar | AVCaptureDevice.DiscoverySession für Geräteliste; inputNode.auAudioUnit.setDeviceID() zum Wechseln |
| SET-03 | Stille-Erkennungs-Schwellwert konfigurierbar (Sekunden bis Auto-Stopp) | Defaults-Key `silenceDuration: Double` (Standard 1.5); Slider in SettingsView |
| SET-04 | Mikrofon-Eingabegerät in Einstellungen wählbar | Picker mit AVCaptureDevice.DiscoverySession; Defaults-Key `selectedMicUID: String` |
| FEED-02 | Kurze Töne beim Starten und Stoppen | NSSound(named:) mit diskreten System-Tönen; play() auf Main Thread |
| FEED-03 | Waveform / Level-Meter im Menüleisten-Icon | Canvas-basierte Waveform in StatusBarIconView; RMS-Pegel aus installTap via updateIcon() |
</phase_requirements>

---

## Summary

Phase 2 verbindet drei technische Domänen: (1) Echtzeit-Mikrofon-Aufnahme via `AVAudioEngine`, (2) Geräteauswahl via `AVCaptureDevice.DiscoverySession` mit Core-Audio-Bridge für Gerätewechsel, (3) SwiftUI-Canvas-Rendering des Live-Pegels im 18×18-Icon-Canvas. Die grösste Komplexität liegt im Swift-6-Concurrency-Grenzgebiet: `installTap`-Callbacks laufen auf dem Audio-Render-Thread (nicht `@MainActor`), müssen aber `AppState` (der `@MainActor` ist) aktualisieren. Das etablierte Pattern ist ein dedizierter `AudioController` als `nonisolated class: @unchecked Sendable`, der über `Task { @MainActor in }` zu AppState brückt.

Eine kritische Einschränkung auf macOS 26 (Xcode 26.4, das auf dem Entwicklungsrechner installiert ist): `AVAudioEngine.inputNode.installTap()` funktioniert nicht zuverlässig mit Bluetooth-Geräten — der Tap-Callback wird nie aufgerufen. Als Workaround für Phase 2 reicht es aus, den bekannten Fallback zu dokumentieren und in Settings einen Hinweis vorzusehen; die Kernfunktionalität mit Built-in-Mikrofon ist verlässlich und deckt den primären Anwendungsfall ab.

Der Gerätewechsel auf macOS erfordert `inputNode.auAudioUnit.setDeviceID()` mit einem `AudioObjectID` (Core Audio), da `AVAudioSession.setPreferredInput()` auf macOS nicht existiert. Nach dem Gerätewechsel muss das Format manuell neu abgefragt werden, da `outputFormat(forBus:)` nicht automatisch aktualisiert wird.

**Primäre Empfehlung:** AudioController als eigenständige `nonisolated` Klasse mit `@unchecked Sendable`-Konformität; kein `@MainActor` auf AudioController selbst. Alle UI-Updates über `Task { @MainActor in appState.audioLevel = rmsValue; updateIcon() }`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Mikrofon-Aufnahme (PCM-Buffer) | AudioController (Background) | — | installTap läuft auf Audio-Render-Thread; niemals auf Main Thread |
| RMS-Berechnung | AudioController (Background) | — | Rechenintensiv; direkt im Tap-Callback auf Render-Thread |
| Silence-Detection-Timer | AudioController (Background) | — | Läuft kontinuierlich während Aufnahme; nicht UI-abhängig |
| Zustandsübergabe an AppState | Main Thread (via Task) | — | AppState ist @MainActor; Bridge aus AudioController |
| Waveform-Rendering | StatusBarIconView (SwiftUI) | AppDelegate.updateIcon() | Canvas-Drawing ist UI; getriggert durch Observation-B-Pattern |
| Gerätewahl (UI) | SettingsView (SwiftUI Main) | — | Picker ist reines UI; liest Geräteliste von AudioController |
| Gerätewechsel (Engine) | AudioController (Background) | — | setDeviceID() auf Audio Unit; muss vor/nach Engine-Start erfolgen |
| Audio-Cues (NSSound) | Main Thread | — | NSSound.play() muss auf Main Thread aufgerufen werden |
| Mikrofon-Permission | Main Thread | — | AVAudioApplication.requestRecordPermission ist UI-Flow |

---

## Standard Stack

### Core

| Library / API | Version / Plattform | Purpose | Why Standard |
|---------------|---------------------|---------|--------------|
| `AVAudioEngine` | macOS 10.10+ | Mikrofon-Tap, PCM-Buffer-Zugriff | Erste Wahl für Echtzeit-Audio auf Apple-Plattformen; Higher-Level als Core Audio, Swift-native API |
| `AVAudioInputNode.installTap(onBus:bufferSize:format:block:)` | macOS 10.10+ | Push-to-Talk Buffer-Accumulation | Einzige saubere API für Echtzeit-PCM-Zugriff ohne Schreiben auf Disk |
| `AVCaptureDevice.DiscoverySession` | macOS 10.15+ | Mikrofon-Geräteliste enumerieren | Ersetzt deprecated `AVCaptureDevice.devices(for:)`; korrekte moderne API |
| `inputNode.auAudioUnit.setDeviceID(_:)` | macOS | Mikrofon-Gerät wechseln | Einziger zuverlässiger Weg auf macOS (kein AVAudioSession wie iOS) |
| `AVAudioApplication.recordPermission` | macOS 14+ | Berechtigung prüfen | Moderne Ersatz-API für die ältere AVAudioSession-basierte Variante |
| `AVAudioApplication.requestRecordPermission(completionHandler:)` | macOS 14+ | Berechtigung anfordern | Systemdialog; ersetzt AVAudioSession.requestRecordPermission auf macOS |
| `NSSound(named:)` | macOS | Diskrete Audio-Cues | Zero Dependencies; einzige Anforderung aus D-05 |
| SwiftUI `Canvas` | macOS 12+ | Waveform-Linie zeichnen | Direktes 2D-Drawing ohne Shapes-Overhead; geeignet für 18×18-Canvas |

### Supporting

| Library / API | Version | Purpose | When to Use |
|---------------|---------|---------|-------------|
| `Defaults` (sindresorhus) | latest (SPM, bereits integriert) | Type-safe UserDefaults für `silenceDuration` und `selectedMicUID` | Neue Settings-Keys in Phase 2 |
| `Accelerate.vDSP` | macOS (systemseitig) | Vektorisierte RMS-Berechnung | Optional: Performance-Optimierung wenn naive RMS-Berechnung messbar langsam ist; für 1024-Frame-Buffer nicht nötig |
| `CoreAudio` (`kAudioHardwarePropertyTranslateUIDToDevice`) | macOS | UID → AudioObjectID Konvertierung für setDeviceID | Benötigt wenn Gerätewechsel implementiert wird |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `installTap` (AVAudioEngine) | `AVCaptureSession` mit `AVCaptureAudioDataOutput` | AVCaptureSession umgeht den Bluetooth-Tap-Bug; liefert CMSampleBuffer statt AVAudioPCMBuffer (Konvertierung nötig). Für Phase 2 nicht nötig — built-in Mikrofon ist Haupt-Use-Case |
| `AVCaptureDevice.DiscoverySession` | Core Audio `kAudioHardwarePropertyDevices` | Core Audio gibt mehr Kontrolle, aber komplexere Swift-Bindings; DiscoverySession ist ausreichend und idiomatisch |
| SwiftUI `Canvas` für Waveform | `CAShapeLayer` / `NSBezierPath` | CA-Layer wäre schneller bei sehr hoher Update-Rate, aber für ~30 Hz in 18×18px ist Canvas ausreichend und bleibt im SwiftUI-Stack |
| `Defaults` für Settings | `@AppStorage` | `@AppStorage` fehlt Codable-Support und type-safe Keys; Defaults ist bereits im Projekt integriert |

**Installation:** Alle Abhängigkeiten bereits per SPM integriert (Phase 1). CoreAudio ist Teil des macOS SDK.

---

## Architecture Patterns

### System Architecture Diagram

```
Hotkey-Ereignis (KeyboardShortcuts)
         │
         ▼
AppDelegate.handleToggle()
         │
         ├─── AppState.recordingState == .idle?
         │         │ YES
         │         ▼
         │    AudioController.startRecording()
         │         │
         │         ├─ Permission prüfen (AVAudioApplication)
         │         │       └─ denied → AppState.micPermissionDenied = true → [END]
         │         │
         │         ├─ AVAudioEngine.start()
         │         ├─ installTap(onBus: 0, bufferSize: 1024, format: nil)
         │         │       │
         │         │       │  [Audio Render Thread — läuft kontinuierlich]
         │         │       ▼
         │         │  Tap-Callback: AVAudioPCMBuffer
         │         │       ├─ RMS berechnen (Float → 0.0–1.0)
         │         │       ├─ Silence-Timer aktualisieren
         │         │       └─ Task { @MainActor }
         │         │               ├─ AppState.audioLevel = rmsValue
         │         │               └─ AppDelegate.updateIcon()  [Observation-B]
         │         │
         │         └─ NSSound("Tink").play()  [Main Thread]
         │
         └─── AppState.recordingState == .recording?
                   │ YES
                   ▼
              AudioController.stopRecording()
                   ├─ AVAudioEngine.inputNode.removeTap(onBus: 0)
                   ├─ AVAudioEngine.stop()
                   ├─ NSSound("Pop").play()  [Main Thread]
                   └─ AppState.recordingState = .transcribing

         [Silence Timer — parallel im Audio Render Thread]
              ├─ Stille ≥ silenceDuration?
              │       YES → AudioController.stopRecording()  [wie manuell]
              └─ Weiter messen

Settings-Fenster (parallel, unabhängig)
         ├─ AVCaptureDevice.DiscoverySession → Geräteliste → Picker
         └─ Gerätewahl → AudioController.setInputDevice(uid:)
                   ├─ uniqueUID → AudioObjectID (Core Audio)
                   └─ inputNode.auAudioUnit.setDeviceID(AudioObjectID)
```

### Recommended Project Structure

```
VoiceScribe/
├── Audio/
│   ├── AudioController.swift         # AVAudioEngine-Wrapper, Tap, RMS, Silence
│   └── AudioDeviceManager.swift      # AVCaptureDevice-Enumeration + setDeviceID
├── AppState.swift                    # +audioLevel: CGFloat, +micPermissionDenied: Bool
├── AppDelegate.swift                 # updateIcon() erweitert für audioLevel-Parameter
├── StatusBarIconView.swift           # +WaveformView-Subview (Canvas)
└── SettingsView.swift                # +Mikrofon-Picker, +Stille-Slider, +Permission-Banner
```

### Pattern 1: AudioController als nonisolated @unchecked Sendable

**Was:** Dedizierte Klasse für AVAudioEngine-Lifecycle, isoliert vom Main Actor.
**Wann:** Immer wenn Audio-Callbacks (Render-Thread) auf @MainActor-State zugreifen müssen.

```swift
// Source: Swift 6 concurrency community pattern (developer.apple.com/forums)
// AudioController muss NICHT @MainActor sein — Tap-Callback läuft auf Render-Thread
final class AudioController: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var silenceTimer: TimeInterval = 0
    private weak var appState: AppState?  // @MainActor, aber nur via Task zugegriffen

    init(appState: AppState) {
        self.appState = appState
    }

    func startRecording() throws {
        let inputNode = engine.inputNode
        // format: nil → AVAudioEngine wählt nativen Format des Eingabegeräts
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            // RENDER THREAD — kein @MainActor hier
            guard let self else { return }
            let rms = self.calculateRMS(buffer: buffer)
            let issilent = rms < 0.01  // Claude's Discretion: RMS-Schwellwert

            Task { @MainActor [weak self] in
                guard let self, let state = self.appState else { return }
                state.audioLevel = CGFloat(rms)
                // Silence-Logik: Timer-Aktualisierung auf Main Thread ist OK
                // (niedrige Frequenz, kein Timing-kritischer Pfad)
                // Observation-B: updateIcon() direkt aufrufen
            }
        }
        try engine.start()
    }

    func stopRecording() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    private func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }
        // Naive RMS — ausreichend für 1024-Frame-Buffer; kein Accelerate nötig
        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        return sqrt(sum / Float(frameLength))
    }
}
```

### Pattern 2: Waveform-Canvas in StatusBarIconView

**Was:** SwiftUI `Canvas` im unteren 18×4pt-Streifen des Icons zeichnet amplitudenmodulierte Kurve.
**Wann:** Zustand `.recording` + `audioLevel > 0`.

```swift
// Source: [ASSUMED] basierend auf SwiftUI Canvas + holyswift.app Waveform-Tutorial
struct WaveformView: View {
    let level: CGFloat  // 0.0 – 1.0, normierter RMS

    var body: some View {
        Canvas { context, size in
            // UI-SPEC: Waveform-Bereich 18×4pt, lineWidth 1pt, systemRed
            let amplitude = max(1, level * size.height)  // Minimalamplitude: 1pt
            var path = Path()
            let segments = 8  // Claude's Discretion
            for i in 0...segments {
                let x = size.width * CGFloat(i) / CGFloat(segments)
                let phase = CGFloat(i) / CGFloat(segments) * .pi * 2
                let y = size.height / 2 + sin(phase) * amplitude / 2
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(Color(.systemRed)), lineWidth: 1)
        }
        .frame(width: 18, height: 4)
    }
}

// In StatusBarIconView.body — zweites Layer unterhalb mic.fill
struct StatusBarIconView: View {
    let state: RecordingState
    let audioLevel: CGFloat  // NEU in Phase 2, default 0.0

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "mic.fill")
                .renderingMode(.original)
                .foregroundStyle(state.color)
                .font(.system(size: 13, weight: .medium))  // angepasst für VStack-Layout
            if state == .recording {
                WaveformView(level: audioLevel)
            }
        }
        .frame(width: 18, height: 18)
        // ... Pulse-Animation bleibt unverändert
    }
}
```

### Pattern 3: Gerätewechsel (Core Audio Bridge)

**Was:** `uniqueID` (String aus AVCaptureDevice) → `AudioObjectID` (UInt32 für setDeviceID).
**Wann:** Nutzer wählt neues Gerät im Picker.

```swift
// Source: VERIFIED via medium.com/@itsuki.enjoy/swiftui-macos-manage-configure-audio-device-microphone-inputs
func uniqueIDToAudioObjectID(_ uid: String) -> AudioObjectID? {
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var deviceID: AudioObjectID = kAudioObjectUnknown
    var uid = uid as CFString
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    let status = AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        UInt32(MemoryLayout<CFString>.size),
        &uid,
        &size,
        &deviceID
    )
    return status == noErr ? deviceID : nil
}

// Gerät wechseln — MUSS vor engine.prepare() / engine.start() aufgerufen werden
// oder engine temporär stoppen
func setInputDevice(uid: String) throws {
    guard let deviceID = uniqueIDToAudioObjectID(uid) else { return }
    try engine.inputNode.auAudioUnit.setDeviceID(deviceID)
    // WICHTIG: outputFormat(forBus:) danach neu abfragen — nicht gecacht
}
```

### Pattern 4: Mikrofon-Berechtigung (D-13, D-14)

```swift
// Source: VERIFIED via developer.apple.com/documentation/avfaudio/avaudioapplication
// Info.plist Key erforderlich: NSMicrophoneUsageDescription
func checkAndRequestPermission() async -> Bool {
    switch AVAudioApplication.shared.recordPermission {
    case .granted:
        return true
    case .denied:
        return false  // Banner in Settings; Button öffnet Privacy URL
    case .undetermined:
        return await AVAudioApplication.requestRecordPermission()
    @unknown default:
        return false
    }
}

// In SettingsView — Permission-Banner
// URL für macOS Datenschutz-Einstellungen Mikrofon:
let privacyURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
NSWorkspace.shared.open(privacyURL)
```

### Pattern 5: NSSound Audio-Cues

```swift
// Source: VERIFIED via developer.apple.com/documentation/appkit/nssound
// Verfügbare diskrete System-Töne: Tink, Pop, Blow, Ping, Purr, Bottle
// Muss auf Main Thread aufgerufen werden
NSSound(named: NSSound.Name("Tink"))?.play()  // Start (hell, kurz ~150ms)
NSSound(named: NSSound.Name("Pop"))?.play()   // Stopp (tiefer, kurz ~150ms)
```

### Anti-Patterns to Avoid

- **@MainActor auf AudioController:** installTap-Callback läuft NICHT auf dem Main Thread. Wenn AudioController `@MainActor` ist, blockiert oder crasht der Render-Thread. Lösung: `nonisolated` + `@unchecked Sendable`.
- **AVAudioRecorder statt AVAudioEngine:** Schreibt auf Disk; erzeugt File-Roundtrip vor ML-Inference. Laut CLAUDE.md explizit verboten.
- **AVAudioSession.setPreferredInput() auf macOS:** API existiert auf macOS nicht — nur iOS. Führt zu Compile-Fehler.
- **outputFormat(forBus:) nach setDeviceID cachen:** Nach Gerätewechsel veraltet das Format. Immer neu abfragen oder `nil` an installTap übergeben.
- **installTap vor engine.start():** Die Engine muss gestartet sein bevor Tap-Callbacks feuern.
- **removeTap vergessen beim Stopp:** Führt zu mehrfach installierten Taps und Double-Callbacks bei nächster Aufnahme.
- **NSSound.play() von Render-Thread:** Muss auf Main Thread. Immer via `Task { @MainActor in }` aufrufen.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Geräteliste | Eigene Core-Audio-Device-Enumeration | `AVCaptureDevice.DiscoverySession` | DiscoverySession handhabt hotplug, Berechtigungen und Device-Types korrekt |
| Berechtigung | Eigene TCC-Prüfung | `AVAudioApplication.shared.recordPermission` | Einzige korrekte API; kein direktes TCC-Reading |
| Audio-Cues | AVAudioEngine-Player für System-Sounds | `NSSound(named:)` | D-05 sagt explizit: NSSound. Kein Bundle-Asset, kein AVAudioEngine-Ton |
| RMS-Normierung | Komplexe dB-Skala | Einfaches `sqrt(sumSquares / frameLength)` | Für Level-Meter-Zwecke (0.0–1.0) ist lineare RMS ausreichend; dB-Skala nur für Profi-Audio |
| Waveform-Bibliothek | DSWaveformImage oder ähnliches | SwiftUI `Canvas` + `Path` | Bibliothek wäre Overkill für 18×4pt statische Kurve; Canvas ist frameworknativ |

**Key insight:** macOS bietet keine High-Level-API für Gerätewechsel bei AVAudioEngine (anders als iOS mit AVAudioSession). Der Core-Audio-Bridge-Layer ist unvermeidlich, aber auf ~20 Zeilen reduzierbar.

---

## Common Pitfalls

### Pitfall 1: installTap-Callback auf Bluetooth-Gerät schweigt (macOS 26)
**Was schief geht:** Der Tap-Callback wird bei aktiver Bluetooth-Mikrofon-Auswahl nie aufgerufen — die Engine läuft, produziert aber keine Buffer.
**Warum:** macOS 26 hat eine bekannte Regression mit AVAudioEngine installTap + Bluetooth-Eingabegeräten (gemeldet auf developer.apple.com/forums/thread/819555).
**Wie vermeiden:** In Phase 2 dokumentieren (Hinweis im Picker wenn Bluetooth-Gerät ausgewählt) und als bekannte Einschränkung im Code kommentieren. Workaround für v2: AVCaptureSession mit AVCaptureAudioDataOutput. Built-in-Mikrofon funktioniert zuverlässig.
**Warnsignale:** Tap-Callback feuert nie; `engine.isRunning == true` aber keine Buffer-Updates.

### Pitfall 2: outputFormat(forBus:) nach setDeviceID ist veraltet
**Was schief geht:** Nach `setDeviceID()` hat `inputNode.outputFormat(forBus: 0)` noch das alte Format. installTap mit diesem veralteten Format kann zu Assertions oder fehlerhaften Buffer-Konvertierungen führen.
**Warum:** Der Audio-Unit-Verhandlungsprozess wird nicht automatisch ausgelöst.
**Wie vermeiden:** `nil` als Format-Parameter an installTap übergeben (Engine wählt selbst) oder nach setDeviceID via Core Audio das aktuelle Device-Format abfragen.
**Warnsignale:** Assertion-Fehler in AVAudioEngine bei Format-Mismatch; falsche Samplerate.

### Pitfall 3: Swift 6 — Tap-Callback von Render-Thread auf @MainActor-State
**Was schief geht:** Direkter Zugriff auf `appState.audioLevel = x` vom Tap-Callback aus triggert Swift-6-Concurrency-Fehler (Sendability-Violation).
**Warum:** installTap-Block läuft auf dem privaten Render-Thread der Audio-Engine, nicht auf MainActor.
**Wie vermeiden:** `Task { @MainActor in }` im Tap-Callback verwenden. AudioController selbst als `nonisolated class: @unchecked Sendable` deklarieren.
**Warnsignale:** Compile-Fehler "Sending ... risks causing data races"; Runtime-Crash auf Non-Main-Thread.

### Pitfall 4: Ad-hoc-Signierung setzt TCC-Berechtigungen zurück
**Was schief geht:** Jeder Build mit ad-hoc-Signierung (`codesign --sign -`) generiert einen anderen Code-Directory-Hash. macOS TCC betrachtet die App als "neue" App und entzieht alle Berechtigungen.
**Warum:** TCC bindet Berechtigungen an den Code-Signing-Hash, nicht an den Bundle-Identifier.
**Wie vermeiden:** App immer via `open -a VoiceScribe.app` starten (nicht direktes Binary). Mikrofon-Berechtigung einmalig im Dialog erteilen. Bekannte Einschränkung der ad-hoc-Entwicklungsphase (aus STATE.md).
**Warnsignale:** `AVAudioApplication.recordPermission` ist `.denied` obwohl Nutzer noch nie gefragt wurde; kein System-Dialog erscheint.

### Pitfall 5: engine.start() ohne installTap vorher / doppeltes installTap
**Was schief geht:** Wenn die Engine neugestartet wird ohne vorher `removeTap(onBus: 0)` aufzurufen, wird ein zweiter Tap installiert. Beides kommt zu Callback-Verdoppelung.
**Warum:** `installTap` akkumuliert Taps; jeder Call fügt einen hinzu.
**Wie vermeiden:** Stopp-Pfad muss IMMER `removeTap(onBus: 0)` aufrufen, bevor `engine.stop()`. Sicherheitshalber in `startRecording()` auch `removeTap()` aufrufen bevor neu installiert wird.
**Warnsignale:** RMS-Werte werden doppelt gemeldet; Waveform pulsiert doppelt so schnell.

### Pitfall 6: NSMicrophoneUsageDescription fehlt in Info.plist
**Was schief geht:** AVAudioApplication.requestRecordPermission() zeigt keinen Dialog — App wird direkt als "denied" behandelt oder crasht.
**Warum:** macOS erzwingt Privacy-Usage-Description im Info.plist für Mikrofon-Zugriff.
**Wie vermeiden:** `NSMicrophoneUsageDescription` in `VoiceScribe/Info.plist` eintragen.
**Warnsignale:** Permission-Anfrage schlägt sofort fehl ohne Dialog.

### Pitfall 7: setDeviceID muss vor engine.prepare()/start() oder nach engine.stop() aufgerufen werden
**Was schief geht:** setDeviceID während laufender Engine kann zu inkonsistentem Zustand führen.
**Warum:** Audio-Unit-Initialisierung muss bei Gerätewechsel neu verhandeln.
**Wie vermeiden:** Bei laufender Aufnahme: `stopRecording()` → `setDeviceID()` → `startRecording()`. Der Nutzer erwartet dass die nächste Aufnahme das neue Gerät verwendet — kein Mid-Recording-Switch nötig.
**Warnsignale:** Engine-Assertion-Fehler; kein Audio-Input nach Gerätewechsel.

---

## Code Examples

### RMS-Berechnung aus AVAudioPCMBuffer

```swift
// Source: [VERIFIED pattern — Kodeco AVAudioEngine Tutorial + AudioKit community]
func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
    guard let channelData = buffer.floatChannelData?[0] else { return 0 }
    let frameLength = Int(buffer.frameLength)
    guard frameLength > 0 else { return 0 }
    var sum: Float = 0
    for i in 0..<frameLength {
        let sample = channelData[i]
        sum += sample * sample
    }
    let rms = sqrt(sum / Float(frameLength))
    // Normierung auf 0.0–1.0: RMS liegt typ. zwischen 0.0 und ~0.3 für Sprache
    // Skalierungsfaktor ~3.0–5.0 ergibt gute Waveform-Auslenkung
    return min(1.0, rms * 4.0)
}
```

### AVCaptureDevice.DiscoverySession — Mikrofon-Liste

```swift
// Source: [VERIFIED — developer.apple.com/documentation/avfoundation/avcapturedevice/discoverysession]
import AVFoundation

func availableMicrophones() -> [AVCaptureDevice] {
    let session = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.microphone, .external],
        mediaType: .audio,
        position: .unspecified
    )
    return session.devices
}
// AVCaptureDevice.uniqueID: String — stabil über Neustarts
// AVCaptureDevice.localizedName: String — für UI-Anzeige im Picker
```

### Defaults-Keys für Phase 2

```swift
// Source: [VERIFIED — sindresorhus/defaults readme + Context7]
import Defaults

extension Defaults.Keys {
    // SET-03: Stille-Dauer in Sekunden (Standard D-09: 1.5s)
    static let silenceDuration = Key<Double>("silenceDuration", default: 1.5)
    // SET-04: uniqueID des gewählten Mikrofons; nil = System-Standard
    static let selectedMicUID = Key<String?>("selectedMicUID", default: nil)
}
```

### Silence-Detection-Logic

```swift
// Source: [ASSUMED] — etabliertes Pattern für VAD (Voice Activity Detection)
// Läuft im Tap-Callback (Render Thread); Zustandsvariablen sind auf AudioController
private var silenceAccumulator: TimeInterval = 0
private var lastBufferTime: Date = Date()

func updateSilenceDetection(rms: Float, bufferDuration: TimeInterval) {
    if rms < silenceThresholdRMS {  // Claude's Discretion: z.B. 0.01
        silenceAccumulator += bufferDuration
        if silenceAccumulator >= Defaults[.silenceDuration] {
            Task { @MainActor in
                // Auto-Stopp auslösen
            }
        }
    } else {
        silenceAccumulator = 0  // Reset bei Sprache
    }
}
// bufferDuration = Double(buffer.frameLength) / buffer.format.sampleRate
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `AVCaptureDevice.devices(for:)` | `AVCaptureDevice.DiscoverySession` | macOS 10.15 (2019) | Alte API deprecated; DiscoverySession ist Pflicht |
| `AVAudioSession.requestRecordPermission` | `AVAudioApplication.requestRecordPermission` | macOS 14 / iOS 17 (2023) | AVAudioSession-API gilt für macOS als deprecated für Permission; `AVAudioApplication` ist korrekt |
| `AVAudioSession.setPreferredInput()` | `inputNode.auAudioUnit.setDeviceID()` | macOS (existierte nie) | Kein iOS-Äquivalent auf macOS — Core-Audio-Bridge unvermeidlich |

**Deprecated/outdated:**
- `AVCaptureDevice.devices(for: .audio)`: Deprecated macOS 10.15 — nicht verwenden.
- `AVAudioSession.sharedInstance()` auf macOS: Keine-Op auf macOS 14+ — kein `setCategory`, kein `setActive` nötig oder sinnvoll.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Waveform-Rendering mit SwiftUI `Canvas` + `Path` in 18×4pt ist bei ~30 Hz Update-Rate für `updateIcon()` (NSHostingView-Neuerstelle) performant genug | Architecture Patterns, Pattern 2 | Icon-Rendering ruckelt sichtbar; Fallback: `CAShapeLayer` direkt in NSView |
| A2 | `AVAudioApplication.shared.recordPermission` und `requestRecordPermission(completionHandler:)` sind auf macOS 14+ verfügbar (Target-Deployment-Version noch nicht offiziell gelockt, aber STATE.md sagt 14+) | Pattern 4 | Compile-Fehler wenn Deployment Target < 14; Fallback: `AVAudioSession`-basierte Permission |
| A3 | Silence-Accumulator-Logik im Tap-Callback (Render-Thread) ohne Mutex ist sicher für Float/Double-Writes auf modernem ARM64 | Code Examples | Race-Condition zwischen Tap und Stop; Lösung: `nonisolated(unsafe)` oder OSAllocatedUnfairLock |
| A4 | `NSSound(named: "Tink")` und `NSSound(named: "Pop")` existieren auf macOS 14+ und klingen unterschiedlich genug | Pattern 5 | Ton nicht gefunden (nil-Return) oder klingt ähnlich; andere Namen aus verfügbarer Liste wählen |
| A5 | `installTap` mit bufferSize 1024 bei typischer Samplerate 44100 Hz = ~23 ms pro Callback — ausreichend für 1.5s Silence-Detection-Granularität | Pattern 1 | Granularität zu grob für kurze Silence-Threshold; bufferSize reduzieren |

---

## Open Questions

1. **Waveform-Update-Performance mit NSHostingView-Pattern (Observation-B)**
   - Was wir wissen: Observation-B erstellt bei jedem `updateIcon()`-Aufruf ein neues `NSHostingView` und ersetzt das alte. Das funktioniert für diskrete Zustandsänderungen (Phase 1). Bei ~20-30 Hz Waveform-Updates könnte das teuer werden.
   - Was unklar ist: Ist die Perf-Grenze 10 Hz, 30 Hz oder 60 Hz für NSHostingView-Erstellung?
   - Empfehlung: Erst implementieren, dann messen. Wenn sichtbares Ruckeln: `audioLevel` als `@Published`-Property in `NSHostingView.rootView` direkt aktualisieren statt neues View zu erstellen (Observation-A-Pattern nur für Waveform).

2. **Gerätewechsel während laufender Aufnahme**
   - Was wir wissen: setDeviceID sollte vor engine.start() aufgerufen werden. Nutzer-Erwartung laut D-11: Gerät wählen, nächste Aufnahme verwendet es.
   - Was unklar ist: Ob der Gerätewechsel in der Settings-UI sofort zum AudioController propagiert werden soll oder ob ein "wird ab nächster Aufnahme verwendet"-Pattern genug ist.
   - Empfehlung: Lazy-Anwendung — beim nächsten startRecording() wird selectedMicUID aus Defaults gelesen und gesetzt. Kein Mid-Recording-Switch in Phase 2.

3. **Silence-Detection-Threshold (RMS-Wert)**
   - Was wir wissen: D-08 legt Methode (RMS) und D-09 legt Dauer (1.5s) fest. Den RMS-Schwellwert-Wert lässt CONTEXT.md bei Claude's Discretion.
   - Empfehlung: Start mit `0.01` (ca. -40 dBFS) als silenceThresholdRMS. Das ist konservativ genug für Hintergrundgeräusche aber reagiert auf echte Sprachpausen. Nicht konfigurierbar (nur Dauer ist konfigurierbar laut SET-03).

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Swift 6.3 | SWIFT_STRICT_CONCURRENCY = complete | ✓ | 6.3 (swiftlang-6.3.0.123.5) | — |
| Xcode 26.4 | Build-Umgebung | ✓ | 26.4 (Build 17E192) | — |
| AVFoundation (macOS SDK) | AVAudioEngine, AVCaptureDevice | ✓ | Teil von macOS 26 SDK | — |
| CoreAudio (macOS SDK) | Gerätewechsel via AudioObjectID | ✓ | Teil von macOS 26 SDK | — |
| AppKit (macOS SDK) | NSSound | ✓ | Teil von macOS 26 SDK | — |
| Defaults (SPM) | Settings-Keys | ✓ | Bereits in Phase 1 integriert | — |
| Bluetooth-Mikrofon | Geräteauswahl (erweiterter Test) | EINSCHRÄNKUNG | macOS 26 installTap-Bug | Built-in mic funktioniert zuverlässig |

**Hinweis macOS 26 Bluetooth-Bug:** `installTap` auf Bluetooth-Geräten feuert keine Callbacks auf macOS 26 (Xcode 26.4). Dies ist die aktuelle Entwicklungsumgebung. Primärer Entwicklungstest muss mit Built-in-Mikrofon erfolgen.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (import Testing) — bereits in VoiceScribeTests eingesetzt |
| Config file | Xcode-Testziel (VoiceScribeTests) — kein separates Config-File |
| Quick run command | `xcodebuild test -scheme VoiceScribe -destination 'platform=macOS' -only-testing:VoiceScribeTests/AudioControllerTests 2>&1 \| tail -20` |
| Full suite command | `xcodebuild test -scheme VoiceScribe -destination 'platform=macOS' 2>&1 \| tail -40` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RECORD-01 | toggleRecording() .idle → .recording | unit | Full suite | ❌ Wave 0 (AppStateTests erweitern) |
| RECORD-01 | toggleRecording() .recording → .transcribing | unit | Full suite | ❌ Wave 0 |
| RECORD-02 | Silence nach 1.5s löst Auto-Stopp aus | unit | Full suite | ❌ Wave 0: AudioControllerTests.swift |
| RECORD-02 | Silence-Timer reset bei Sprache | unit | Full suite | ❌ Wave 0 |
| RECORD-03 | availableMicrophones() gibt non-empty List zurück | integration (manualOnly) | — | Nur auf echtem Mac mit Mikrofon testbar |
| SET-03 | silenceDuration-Defaults-Key hat Standardwert 1.5 | unit | Full suite | ❌ Wave 0: DefaultsKeysTests.swift |
| SET-04 | selectedMicUID-Defaults-Key ist initial nil | unit | Full suite | ❌ Wave 0 |
| FEED-02 | NSSound play() wird bei start/stop aufgerufen | unit (mock) | Full suite | ❌ Wave 0 — NSSound schwer mockbar; Smoke-Test via Integration |
| FEED-03 | StatusBarIconView zeigt WaveformView wenn .recording + level > 0 | unit | Full suite | ❌ Wave 0 |
| FEED-03 | WaveformView ist hidden bei .idle | unit | Full suite | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme VoiceScribe -destination 'platform=macOS' -only-testing:VoiceScribeTests 2>&1 | grep -E "(passed|failed|error)"`
- **Per wave merge:** Full suite command (oben)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `VoiceScribeTests/AudioControllerTests.swift` — deckt RECORD-01, RECORD-02 (Silence-Logic unit-testbar ohne echtes Mikrofon durch RMS-Injection)
- [ ] `VoiceScribeTests/DefaultsKeysTests.swift` — deckt SET-03, SET-04 (Defaults-Keys initial values)
- [ ] `VoiceScribeTests/WaveformViewTests.swift` — deckt FEED-03 (SwiftUI View state)
- [ ] AppStateTests.swift erweitern — RECORD-01 Toggle-Logik (echte Audio-Logik statt Demo-Cycle)

**Hinweis:** `AVAudioEngine`-Tests mit echtem Mikrofon sind keine Unit-Tests — sie sind Integrationstests die nur auf echtem macOS-Hardware mit Mikrofon-Berechtigung laufen. AudioController so designen dass RMS-Calculation und Silence-Logic ohne echten Engine-Start testbar sind (Dependency-Inversion).

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | nein | — |
| V3 Session Management | nein | — |
| V4 Access Control | nein | — |
| V5 Input Validation | ja (minimal) | RMS-Wert clampen auf 0.0–1.0; Geräte-UID validieren |
| V6 Cryptography | nein | — |
| V9 Communications | nein | — |
| Privacy / TCC | ja | NSMicrophoneUsageDescription muss erklärend sein; Permission-State muss UI-sichtbar sein |

### Known Threat Patterns for this Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Mikrofon ohne Nutzerwissen aufnehmen | Disclosure | Permission-Check vor jedem startRecording(); Banner in Settings bei Denial |
| RMS-Wert out-of-bounds (> 1.0 führt zu falscher Waveform) | Tampering | `min(1.0, rms * scaleFactor)` — immer clampen |
| Gerätewechsel auf nicht-vorhandenes Gerät | DoS | setDeviceID-Rückgabe prüfen; error throwing; graceful fallback |

---

## Sources

### Primary (HIGH confidence)
- `developer.apple.com/documentation/avfaudio/avaudioengine` — AVAudioEngine API, installTap-Grundlagen [Context7: /websites/developer_apple_avfaudio_avaudioengine]
- `developer.apple.com/documentation/avfoundation/avcapturedevice/discoverysession` — Geräte-Enumeration [VERIFIED via WebSearch]
- `developer.apple.com/documentation/appkit/nssound` — NSSound System-Töne verfügbare Namen [VERIFIED via WebSearch]
- `developer.apple.com/documentation/avfaudio/avaudioapplication/recordpermission-swift.property` — Permission-API [VERIFIED via WebSearch]
- `github.com/sindresorhus/defaults` — Defaults-Key-Pattern [Context7: /sindresorhus/defaults]

### Secondary (MEDIUM confidence)
- `medium.com/@itsuki.enjoy/swiftui-macos-manage-configure-audio-device-microphone-inputs-0a8f3af39cb4` — setDeviceID + Core Audio Bridge + AVCaptureDevice.DiscoverySession auf macOS (März 2026, sehr aktuell)
- `developer.apple.com/forums/thread/819555` — Bluetooth installTap Bug auf macOS 26 (Building Real-Time Voice Input)
- `holyswift.app/how-to-create-animation-with-swiftui-canvas-timelineview/` — Canvas + TimelineView Waveform-Pattern

### Tertiary (LOW confidence)
- WebSearch community findings zu Swift 6 nonisolated @unchecked Sendable für AudioController — Muster gut beschrieben aber kein einzelner kanonischer Artikel

---

## Project Constraints (from CLAUDE.md)

Direktiven aus `CLAUDE.md` die für Phase 2 relevant und bindend sind:

| Direktive | Auswirkung auf Phase 2 |
|-----------|----------------------|
| `AVAudioEngine` mit `installTap` für Push-to-Talk Buffer — **kein AVAudioRecorder** | Keine Disk-writes; Tap-Pattern ist Pflicht |
| `NSSound` für Audio-Cues — kein AVAudioEngine-Ton | D-05: NSSound(named:) direkt, kein Bundle-Asset |
| Swift 6.x, `SWIFT_STRICT_CONCURRENCY = complete` | AudioController muss `nonisolated @unchecked Sendable` sein; Tap-Callbacks via `Task { @MainActor in }` |
| Observation-Strategie B (manueller `updateIcon()`-Aufruf) | Level-Updates müssen denselben Mechanismus verwenden — kein withObservationTracking |
| `AppState` ist einzige Source of Truth für `RecordingState` | AudioController darf `.recording` nicht selbst setzen — nur AppState |
| macOS 14+ als Ziel-Plattform (aus STATE.md und CLAUDE.md Stack) | `AVAudioApplication.recordPermission` ist verfügbar (macOS 14+) |
| Kein App Sandbox | Kein Einfluss auf Audio-APIs; Mikrofon-TCC-Permission funktioniert auch ohne Sandbox |

---

## Metadata

**Confidence breakdown:**
- AVAudioEngine installTap: HIGH — Apple-Dokumentation + Community-Erfahrung umfangreich
- Gerätewechsel via setDeviceID: MEDIUM — Verifiziert via Medium-Artikel März 2026, aber Core-Audio-Bridge ist komplex
- Bluetooth-Bug auf macOS 26: MEDIUM — Forum-Bericht verifiziert; offizieller Apple-Bug-Status unbekannt
- Waveform-Performance (NSHostingView @ 30Hz): LOW — A1 aus Assumptions Log; muss gemessen werden
- NSSound-Namen (Tink, Pop): HIGH — Dateiliste in /System/Library/Sounds verifizierbar

**Research date:** 2026-04-17
**Valid until:** 2026-05-17 (30 Tage — stabile Apple-APIs, aber macOS-26-spezifische Bugs können sich ändern)
