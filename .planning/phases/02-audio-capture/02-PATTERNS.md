# Phase 2: Audio Capture — Pattern Map

**Mapped:** 2026-04-17
**Files analyzed:** 7 (2 neu, 5 modifiziert)
**Analogs found:** 7 / 7

---

## File Classification

| Neue / Modifizierte Datei | Rolle | Data Flow | Nächster Analog | Match-Qualität |
|---------------------------|-------|-----------|-----------------|----------------|
| `SPRECHKRAFT/Audio/AudioController.swift` | service | event-driven | `SPRECHKRAFT/AppDelegate.swift` | partial (Background-Lifecycle, Task-Dispatch) |
| `SPRECHKRAFT/Audio/AudioDeviceManager.swift` | utility | request-response | `SPRECHKRAFT/Extensions/KeyboardShortcuts+Names.swift` | partial (Extension-Pattern, keine echte Logik-Analog) |
| `SPRECHKRAFT/AppState.swift` | model | — | `SPRECHKRAFT/AppState.swift` | exact (eigene Datei, Erweiterung bestehender Klasse) |
| `SPRECHKRAFT/AppDelegate.swift` | controller | request-response | `SPRECHKRAFT/AppDelegate.swift` | exact (eigene Datei, Erweiterung) |
| `SPRECHKRAFT/StatusBarIconView.swift` | component | event-driven | `SPRECHKRAFT/StatusBarIconView.swift` | exact (eigene Datei, Erweiterung um zweites Layer) |
| `SPRECHKRAFT/SettingsView.swift` | component | request-response | `SPRECHKRAFT/SettingsView.swift` | exact (eigene Datei, Erweiterung um Controls) |
| `SPRECHKRAFT/Info.plist` | config | — | `SPRECHKRAFT/Info.plist` | exact (eigene Datei, Ergänzung eines Keys) |

---

## Pattern Assignments

### `SPRECHKRAFT/Audio/AudioController.swift` (service, event-driven)

**Analog:** `SPRECHKRAFT/AppDelegate.swift` — enthält das einzige existierende Beispiel
für Background→MainActor-Dispatch via `Task { @MainActor in }`.

**Imports-Pattern** (AppDelegate.swift, Zeilen 1–10):
```swift
// SPRECHKRAFT/Audio/AudioController.swift
import AVFoundation
import CoreAudio
import Defaults
```

**Klassen-Deklaration — Swift 6 nonisolated @unchecked Sendable** (kein Analog in Codebase,
Pattern aus RESEARCH.md):
```swift
// AudioController ist NICHT @MainActor — installTap läuft auf Audio Render Thread.
// @unchecked Sendable: interne Mutation (silenceAccumulator, engine) ist single-thread
// auf dem Render-Thread; AppState-Zugriff ausschließlich via Task { @MainActor in }.
final class AudioController: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var silenceAccumulator: TimeInterval = 0
    private let silenceThresholdRMS: Float = 0.01  // ~-40 dBFS; Claude's Discretion
    private weak var appState: AppState?

    init(appState: AppState) {
        self.appState = appState
    }
}
```

**Task { @MainActor in }-Bridge-Pattern** (AppDelegate.swift, Zeilen 141–147 — nächste Analog):
```swift
// Bestehender Präzedenzfall in AppDelegate.setupHotkey():
KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
    Task { @MainActor [weak self] in
        self?.appState?.toggleRecording()
        self?.updateIcon()
    }
}

// AudioController.startRecording() Tap-Callback kopiert dieses Pattern:
inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
    // RENDER THREAD — kein @MainActor hier
    guard let self else { return }
    let rms = self.calculateRMS(buffer: buffer)
    self.updateSilenceDetection(rms: rms, bufferDuration: Double(buffer.frameLength) / buffer.format.sampleRate)
    Task { @MainActor [weak self] in
        guard let self, let state = self.appState else { return }
        state.audioLevel = CGFloat(min(1.0, rms * 4.0))
        // Observation-B: updateIcon() wird von AppDelegate aufgerufen
        // AppDelegate muss auf audioLevel-Änderung reagieren
    }
}
```

**stopRecording()-Muster** (kein Codebase-Analog; Pattern aus RESEARCH.md Anti-Patterns):
```swift
// KRITISCH: removeTap IMMER vor engine.stop() — sonst doppelte Taps beim nächsten Start.
// Pitfall 5 aus RESEARCH.md.
func stopRecording() {
    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    // NSSound auf Main Thread — Caller muss sicherstellen (AppDelegate/AppState)
}
```

**RMS-Berechnung** (keine Codebase-Analog; aus RESEARCH.md Code Examples):
```swift
private func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
    guard let channelData = buffer.floatChannelData?[0] else { return 0 }
    let frameLength = Int(buffer.frameLength)
    guard frameLength > 0 else { return 0 }
    var sum: Float = 0
    for i in 0..<frameLength {
        let sample = channelData[i]
        sum += sample * sample
    }
    return sqrt(sum / Float(frameLength))
}
```

**Silence-Detection** (Pattern aus RESEARCH.md; keine Codebase-Analog):
```swift
// Läuft im Tap-Callback auf Render-Thread.
// silenceAccumulator ist nonisolated — Write nur vom Render-Thread; kein Mutex nötig (A3).
private func updateSilenceDetection(rms: Float, bufferDuration: TimeInterval) {
    if rms < silenceThresholdRMS {
        silenceAccumulator += bufferDuration
        if silenceAccumulator >= Defaults[.silenceDuration] {
            Task { @MainActor [weak self] in
                self?.triggerAutoStop()  // Stopp-Ton + State-Wechsel auf Main Thread
            }
        }
    } else {
        silenceAccumulator = 0  // Reset bei Sprache
    }
}
```

**Audio-Cue-Pattern** (NSSound, Main Thread — kein Codebase-Analog):
```swift
// D-05: NSSound System-Töne, kein Bundle-Asset.
// D-06: Unterschiedliche Töne für Start/Stopp.
// Muss auf Main Thread aufgerufen werden (aus RESEARCH.md Pattern 5).
@MainActor
func playStartCue() { NSSound(named: NSSound.Name("Tink"))?.play() }

@MainActor
func playStopCue()  { NSSound(named: NSSound.Name("Pop"))?.play() }
```

---

### `SPRECHKRAFT/Audio/AudioDeviceManager.swift` (utility, request-response)

**Analog:** `SPRECHKRAFT/Extensions/KeyboardShortcuts+Names.swift` — einzige Utility-Datei
im Projekt (Extension-Pattern); strukturell ähnlich (reiner Namespace, keine Klasse).

**Datei-Struktur-Pattern** (KeyboardShortcuts+Names.swift — Konvention):
```swift
// SPRECHKRAFT/Audio/AudioDeviceManager.swift
// Zweck: AVCaptureDevice-Enumeration + Core-Audio-Bridge für Gerätewechsel.
// Kein eigener Lifecycle — wird von AudioController und SettingsView genutzt.

import AVFoundation
import CoreAudio
```

**Geräteliste-Enumeration** (kein Codebase-Analog; aus RESEARCH.md Code Examples):
```swift
// AVCaptureDevice.DiscoverySession ersetzt deprecated devices(for:) (State of the Art).
// uniqueID: stabil über Neustarts — als Defaults-Key verwenden.
func availableMicrophones() -> [AVCaptureDevice] {
    let session = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.microphone, .external],
        mediaType: .audio,
        position: .unspecified
    )
    return session.devices
}
```

**Core-Audio-Bridge** (kein Codebase-Analog; aus RESEARCH.md Pattern 3):
```swift
// UID (String aus AVCaptureDevice) → AudioObjectID (UInt32 für setDeviceID).
// Pitfall 2: outputFormat nach setDeviceID NICHT cachen — immer nil an installTap.
func uniqueIDToAudioObjectID(_ uid: String) -> AudioObjectID? {
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    var deviceID: AudioObjectID = kAudioObjectUnknown
    var cfUID = uid as CFString
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    let status = AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        UInt32(MemoryLayout<CFString>.size),
        &cfUID,
        &size,
        &deviceID
    )
    return status == noErr ? deviceID : nil
}
```

---

### `SPRECHKRAFT/AppState.swift` (model, Erweiterung)

**Analog:** `SPRECHKRAFT/AppState.swift` selbst (Zeilen 58–75) — exakt; neue Properties
werden nach dem etablierten `var recordingState`-Pattern ergänzt.

**Bestehende Klassen-Signatur** (AppState.swift, Zeilen 57–63):
```swift
@MainActor
@Observable
final class AppState {
    var recordingState: RecordingState = .idle
    // Phase 2 ergänzt hier:
    var audioLevel: CGFloat = 0.0           // Normierter RMS 0.0–1.0 (FEED-03)
    var micPermissionDenied: Bool = false    // true wenn AVAudioApplication.recordPermission == .denied (D-13)
```

**toggleRecording()-Ersatz** (AppState.swift, Zeilen 67–74 — wird ersetzt, nicht ergänzt):
```swift
// Phase 1 Demo-Cycle (wird in Phase 2 durch echte Logik ersetzt):
func toggleRecording() {
    switch recordingState {
    case .idle:      recordingState = .recording     // → AudioController.startRecording()
    case .recording: recordingState = .transcribing  // → AudioController.stopRecording()
    // .transcribing und .llmProcessing bleiben vorerst — Phase 3 füllt sie
    default: break
    }
}
// Phase 2 Ziel: .idle → AudioController.startRecording() → .recording
//               .recording → AudioController.stopRecording() → .transcribing
```

---

### `SPRECHKRAFT/AppDelegate.swift` (controller, Erweiterung)

**Analog:** `SPRECHKRAFT/AppDelegate.swift` selbst — exakt.

**updateIcon()-Signatur erweitern** (AppDelegate.swift, Zeilen 122–136):
```swift
// Bestehende updateIcon()-Implementierung:
func updateIcon() {
    guard let button = statusItem.button else { return }
    let state = appState?.recordingState ?? .idle
    let hostingView = NSHostingView(rootView: StatusBarIconView(state: state))
    // ...
}

// Phase 2: audioLevel als zweiten Parameter hinzufügen:
func updateIcon() {
    guard let button = statusItem.button else { return }
    let state = appState?.recordingState ?? .idle
    let level = appState?.audioLevel ?? 0.0          // NEU
    let hostingView = NSHostingView(rootView: StatusBarIconView(state: state, audioLevel: level))
    hostingView.frame = NSRect(x: 0, y: 0, width: 26, height: 26)
    button.subviews.forEach { $0.removeFromSuperview() }
    button.addSubview(hostingView)
    button.frame = hostingView.frame
    button.setAccessibilityLabel(state.accessibilityLabel)
}
```

**AudioController-Initialisierung** (AppDelegate.swift, Zeile 22 applicationDidFinishLaunching):
```swift
// Bestehende Initialisierungs-Struktur (AppDelegate.swift, Zeilen 22–35):
func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    guard let button = statusItem.button else { return }
    // ...
    updateIcon()
    setupHotkey()
    // Phase 2 ergänzt:
    // audioController wird in SPRECHKRAFTApp als @State gehalten und via Property injiziert,
    // analog zu appState — oder als lazy var in AppDelegate deklariert, initialisiert
    // sobald appState gesetzt ist.
}
```

**handleClick()-Erweiterung** (AppDelegate.swift, Zeilen 40–53):
```swift
// Bestehender handleClick — Linksklick ruft toggleRecording() + updateIcon() auf.
// Phase 2: kein Strukturwandel nötig — toggleRecording() in AppState wird
// durch echte Audio-Logik ersetzt; handleClick bleibt identisch.
@objc private func handleClick(_ sender: NSButton) {
    guard let event = NSApp.currentEvent else { return }
    if event.type == .rightMouseUp {
        showMenu()
    } else {
        appState?.toggleRecording()
        updateIcon()  // Observation-B: bleibt manuell
    }
}
```

---

### `SPRECHKRAFT/StatusBarIconView.swift` (component, Erweiterung)

**Analog:** `SPRECHKRAFT/StatusBarIconView.swift` selbst — exakt.

**Bestehende Signatur + View-Aufbau** (StatusBarIconView.swift, Zeilen 11–29):
```swift
// Bestehend:
struct StatusBarIconView: View {
    let state: RecordingState
    @State private var opacity: Double = 1.0

    var body: some View {
        Image(systemName: "mic.fill")
            .renderingMode(.original)
            .foregroundStyle(state.color)
            .font(.system(size: 16, weight: .medium))
            .frame(width: 18, height: 18)
            .opacity(opacity)
            .onAppear { applyAnimation(for: state) }
            .onChange(of: state) { _, newState in applyAnimation(for: newState) }
    }
}
```

**Phase 2 — VStack-Umbau + WaveformView** (D-01 bis D-04):
```swift
// Phase 2: Image wird in VStack eingebettet; audioLevel als neuer Parameter.
// D-02: Mic bleibt oben, Waveform darunter.
// D-04: Pulse-Animation (applyAnimation) bleibt unverändert aktiv.
struct StatusBarIconView: View {
    let state: RecordingState
    let audioLevel: CGFloat         // NEU — default 0.0 in Aufrufer
    @State private var opacity: Double = 1.0

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "mic.fill")
                .renderingMode(.original)
                .foregroundStyle(state.color)
                .font(.system(size: 13, weight: .medium))  // Größe reduziert für VStack
                .opacity(opacity)
                .onAppear { applyAnimation(for: state) }
                .onChange(of: state) { _, newState in applyAnimation(for: newState) }
            if state == .recording {
                WaveformView(level: audioLevel)  // NEU — zweites Layer
            }
        }
        .frame(width: 18, height: 18)
    }
    // applyAnimation bleibt unverändert (Zeilen 36–49)
}
```

**WaveformView — Canvas-Pattern** (kein Analog; aus RESEARCH.md Pattern 2):
```swift
// D-03: Waveform oszilliert in Echtzeit entsprechend RMS-Pegel.
// Canvas-Wahl: nativ SwiftUI, ausreichend für 18×4pt bei ~20-30 Hz (A1).
struct WaveformView: View {
    let level: CGFloat  // 0.0–1.0

    var body: some View {
        Canvas { context, size in
            let amplitude = max(1, level * size.height)
            var path = Path()
            let segments = 8  // Claude's Discretion (CONTEXT.md)
            for i in 0...segments {
                let x = size.width * CGFloat(i) / CGFloat(segments)
                let phase = CGFloat(i) / CGFloat(segments) * .pi * 2
                let y = size.height / 2 + sin(phase) * amplitude / 2
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else       { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(Color(.systemRed)), lineWidth: 1)
        }
        .frame(width: 18, height: 4)
    }
}
```

**Preview-Pattern** (StatusBarIconView.swift, Zeilen 52–66 — kopieren und anpassen):
```swift
// Bestehende Previews als Muster — Phase 2 ergänzt audioLevel-Parameter:
#Preview("Recording + Level") {
    StatusBarIconView(state: .recording, audioLevel: 0.6).padding()
}
```

---

### `SPRECHKRAFT/SettingsView.swift` (component, Erweiterung)

**Analog:** `SPRECHKRAFT/SettingsView.swift` selbst + `SPRECHKRAFT/AppDelegate.swift` für
Notification-Pattern.

**Bestehende SettingsView-Struktur** (SettingsView.swift, Zeilen 8–18):
```swift
// Bestehend — Placeholder-Body wird ersetzt:
struct SettingsView: View {
    var body: some View {
        VStack {
            Text("Einstellungen folgen in weiteren Phasen.")
                .font(.system(size: 13))
                .foregroundStyle(Color(.labelColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.xl)
    }
}
```

**Phase 2 — Form mit Audio-Sektion** (D-11: Dropdown, D-09: Slider, D-13: Banner):
```swift
// Pattern: Form + Section entspricht macOS-Settings-Konventionen.
// Defaults-Zugriff analog zu Phase-1-Pattern (LaunchAtLogin in AppDelegate, Zeile 83).
struct SettingsView: View {
    @State private var appState: AppState  // via Injection oder @Environment

    var body: some View {
        Form {
            // Mikrofon-Sektion (RECORD-03, SET-04)
            Section("Mikrofon") {
                // Permission-Banner (D-13) — nur sichtbar wenn denied
                if appState.micPermissionDenied {
                    HStack {
                        Image(systemName: "mic.slash.fill")
                            .foregroundStyle(.red)
                        Text("Mikrofonzugriff verweigert")
                            .foregroundStyle(.red)
                        Spacer()
                        Button("Berechtigung erteilen") {
                            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(Color(.systemRed).opacity(0.1))
                    .cornerRadius(8)
                }

                // Mikrofon-Picker (D-11, SET-04)
                Picker("Eingabegerät", selection: Defaults.binding(.selectedMicUID)) {
                    Text("System-Standard").tag(Optional<String>.none)
                    ForEach(availableMics, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(Optional(device.uniqueID))
                    }
                }
            }

            // Stille-Erkennung (SET-03, D-09, D-10)
            Section("Stille-Erkennung") {
                Slider(
                    value: Defaults.binding(.silenceDuration),
                    in: 0.5...5.0,
                    step: 0.5
                ) {
                    Text("Auto-Stopp nach \(Defaults[.silenceDuration], specifier: "%.1f") s Stille")
                }
            }
        }
        .formStyle(.grouped)
        .padding(DesignTokens.Spacing.xl)
    }
}
```

**Defaults.binding-Pattern** (aus RESEARCH.md Code Examples — Defaults-Keys):
```swift
// In Extensions/Defaults+Keys.swift (neue Datei Phase 2):
extension Defaults.Keys {
    static let silenceDuration = Key<Double>("silenceDuration", default: 1.5)   // SET-03
    static let selectedMicUID  = Key<String?>("selectedMicUID", default: nil)   // SET-04
}
```

---

### `SPRECHKRAFT/Info.plist` (config, Ergänzung)

**Analog:** `SPRECHKRAFT/Info.plist` selbst — exakt.

**Bestehende Plist-Struktur** (Info.plist, Zeilen 1–28):
```xml
<!-- Bestehend: LSUIElement, LSMinimumSystemVersion 14.0, CFBundleIdentifier etc. -->
<!-- Phase 2 ergänzt nach <key>LSUIElement</key><true/> (Zeile 24): -->
<key>NSMicrophoneUsageDescription</key>
<string>SPRECHKRAFT benötigt Mikrofonzugriff für die lokale Spracherkennung. Die Aufnahme wird ausschließlich lokal verarbeitet und nicht übertragen.</string>
```

**Pitfall 6 aus RESEARCH.md:** Ohne diesen Key zeigt `AVAudioApplication.requestRecordPermission()`
keinen Dialog — die App gilt sofort als "denied".

---

## Shared Patterns

### Swift 6 @MainActor-Bridge (gilt für AudioController, AppDelegate)

**Quelle:** `SPRECHKRAFT/AppDelegate.swift`, Zeilen 141–147
```swift
// Etabliertes Pattern in AppDelegate.setupHotkey():
// Nicht-@MainActor-Kontext → @MainActor via Task { @MainActor [weak self] in }
KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
    Task { @MainActor [weak self] in
        self?.appState?.toggleRecording()
        self?.updateIcon()
    }
}
// AudioController.installTap-Callback MUSS identisches Pattern verwenden.
// [weak self] ist Pflicht — avoid retain cycles mit dem Engine-Lifecycle.
```

### Observation-B: manueller updateIcon()-Aufruf (gilt für AppDelegate, AudioController-Bridge)

**Quelle:** `SPRECHKRAFT/AppDelegate.swift`, Zeilen 45–52 (handleClick) und 141–147 (setupHotkey)
```swift
// Jede State-Änderung endet mit updateIcon().
// AudioController → Task { @MainActor in appState.audioLevel = x; appDelegate?.updateIcon() }
// Kein withObservationTracking — Observation-B ist die einzige akzeptierte Strategie (CONTEXT.md).
appState?.toggleRecording()
updateIcon()
```

### Defaults-Zugriffspattern (gilt für AudioController, SettingsView)

**Quelle:** `SPRECHKRAFT/AppDelegate.swift`, Zeile 83 (LaunchAtLogin als Referenz-Pattern):
```swift
// Bestehend: LaunchAtLogin.isEnabled (ähnlicher globaler State-Zugriff)
loginItem.state = LaunchAtLogin.isEnabled ? .on : .off

// Phase 2: Defaults[.silenceDuration] und Defaults[.selectedMicUID]
// werden analog als globale Property-Zugriffe in AudioController und SettingsView genutzt.
```

### DesignTokens-Spacing (gilt für SettingsView)

**Quelle:** `SPRECHKRAFT/Constants/DesignTokens.swift`, Zeilen 11–25
```swift
// Alle Abstände in SettingsView über DesignTokens.Spacing.*
// xl = 32pt für Fensterkanten-Padding (bereits in SettingsView bestehend, Zeile 16)
.padding(DesignTokens.Spacing.xl)
```

### Test-Datei-Struktur — Swift Testing (gilt für alle neuen Test-Dateien)

**Quelle:** `SPRECHKRAFTTests/AppStateTests.swift`, Zeilen 1–25
```swift
import Testing
@testable import SPRECHKRAFT

@Suite("AudioController (RECORD-01, RECORD-02)")
@MainActor  // nur wenn Test @MainActor-Klassen testet
struct AudioControllerTests {
    @Test("Silence-Akkumulator reset bei Sprache")
    func silenceResetOnSpeech() {
        // ...
    }
}
```

**Quelle:** `SPRECHKRAFTTests/RecordingStateTests.swift`, Zeilen 1–10 (für Defaults-Tests):
```swift
import Testing
import SwiftUI
@testable import SPRECHKRAFT

@Suite("Defaults Keys (SET-03, SET-04)")
struct DefaultsKeysTests {
    @Test("silenceDuration hat Standardwert 1.5")
    func silenceDurationDefault() {
        #expect(Defaults[.silenceDuration] == 1.5)
    }
}
```

---

## Kein Analog vorhanden

Dateien, für die kein funktional ähnlicher Präzedenzfall in der Codebase existiert —
Planner muss RESEARCH.md-Patterns direkt verwenden:

| Datei | Rolle | Data Flow | Begründung |
|-------|-------|-----------|-----------|
| `SPRECHKRAFT/Audio/AudioController.swift` | service | event-driven | Kein Background-Service mit Audio-Engine existiert; AppDelegate ist nächste Analog nur für Task-Pattern |
| `SPRECHKRAFT/Audio/AudioDeviceManager.swift` | utility | request-response | Kein Core-Audio-Bridge-Code im Projekt; Pattern vollständig aus RESEARCH.md |
| `SPRECHKRAFT/Extensions/Defaults+Keys.swift` (neu) | config | — | Defaults-Keys existieren noch nicht; Pattern aus RESEARCH.md Code Examples |

---

## Kritische Implementierungshinweise (aus RESEARCH.md Pitfalls)

| Pitfall | Betroffene Datei | Mitigation |
|---------|-----------------|------------|
| installTap auf Bluetooth schweigt (macOS 26) | AudioController | Hinweis-Kommentar im Code; Picker-Label für Bluetooth-Geräte |
| outputFormat nach setDeviceID veraltet | AudioController, AudioDeviceManager | `nil` als format-Parameter an installTap; nach setDeviceID Format neu abfragen |
| Tap-Callback auf Render-Thread → @MainActor-State | AudioController | `nonisolated @unchecked Sendable`; `Task { @MainActor in }` |
| Ad-hoc-Signierung setzt TCC-Berechtigung zurück | Info.plist, AudioController | `open -a SPRECHKRAFT.app`; nicht direkt Binary starten |
| removeTap vergessen beim Stopp | AudioController | `removeTap(onBus: 0)` als erstes in stopRecording(); auch in startRecording() als Sicherheit |
| NSMicrophoneUsageDescription fehlt | Info.plist | Key zwingend vor erstem Permission-Request |
| setDeviceID während laufender Engine | AudioDeviceManager | Lazy-Strategie: Gerätewechsel nur vor nächstem startRecording() anwenden |

---

## Metadata

**Analog-Suchbereich:** `/Users/mbieling/claude/voice/SPRECHKRAFT/`, `/Users/mbieling/claude/voice/SPRECHKRAFTTests/`
**Gescannte Dateien:** 9 (AppState, AppDelegate, StatusBarIconView, SettingsView, SPRECHKRAFTApp, DesignTokens, KeyboardShortcuts+Names, Info.plist + 3 Test-Dateien)
**Pattern-Extraktion:** 2026-04-17
