// VoiceScribe/Audio/AudioController.swift
// Zweck: AVAudioEngine-Wrapper mit installTap, RMS-Berechnung und Silence-Detection.
// RECORD-01: Aufnahme starten/stoppen
// RECORD-02: Auto-Stopp nach konfigurierbarer Stille-Dauer (D-08, D-09)
// D-14: Permission-Check vor jedem startRecording()
//
// Swift 6 Concurrency-Strategie:
//   AudioController ist NICHT @MainActor — installTap-Callbacks laufen auf dem Audio-Render-Thread.
//   @unchecked Sendable: interne Mutation (silenceAccumulator) erfolgt ausschliesslich
//   auf dem Render-Thread; AppState-Zugriffe nur via Task { @MainActor in }.
//
// BEKANNTE EINSCHRAENKUNG (macOS 26 Bluetooth-Bug):
//   installTap feuert keine Callbacks bei aktiven Bluetooth-Mikrofonen auf macOS 26
//   (developer.apple.com/forums/thread/819555). Built-in-Mikrofon funktioniert zuverlaessig.

import AVFoundation
import CoreAudio
import Defaults

final class AudioController: @unchecked Sendable {

    // MARK: - Private Properties

    private let engine = AVAudioEngine()

    /// Akkumulierte Stille-Dauer in Sekunden. Nur auf dem Audio-Render-Thread geschrieben.
    private var silenceAccumulator: TimeInterval = 0

    /// RMS-Schwellwert fuer Stille-Erkennung. ~-40 dBFS (Claude's Discretion, D-08).
    private let silenceThresholdRMS: Float = 0.01

    /// Schwache Referenz auf AppState — Zugriff ausschliesslich via Task { @MainActor in }.
    private weak var appState: AppState?

    /// Callback fuer Auto-Stopp; wird von AppDelegate/VoiceScribeApp gesetzt.
    /// Wird auf dem Main Thread via Task { @MainActor in } aufgerufen.
    var onAutoStop: (() -> Void)?

    /// Callback nach jedem audioLevel-Update; signalisiert AppDelegate, updateIcon() aufzurufen.
    /// Wird auf dem Main Thread via Task { @MainActor in } aufgerufen (FEED-03, Observation-B).
    var onLevelUpdate: (() -> Void)?

    // MARK: - Initializer

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Public API

    /// Startet die Mikrofon-Aufnahme.
    /// - Prueft Mikrofon-Berechtigung (D-14). Bei .denied: micPermissionDenied = true, kein Start.
    /// - Liest selectedMicUID aus Defaults und setzt Eingabegeraet (lazy, kein Mid-Recording-Switch).
    /// - Installiert AVAudioEngine-Tap fuer RMS + Silence-Detection.
    /// - throws: Falls AVAudioEngine nicht gestartet werden kann.
    func startRecording() throws {
        // D-14: Permission-Check VOR engine.start()
        // T-02-01 (Threat Register): Information Disclosure — kein Mikrofon-Zugriff ohne Permission
        let permission = AVAudioApplication.shared.recordPermission
        switch permission {
        case .denied:
            Task { @MainActor [weak self] in
                self?.appState?.micPermissionDenied = true
            }
            return
        case .undetermined:
            // Systemdialog asynchron anfordern — naechster startRecording()-Aufruf wird granted sein.
            // Permission-Request kann nicht synchron abgewartet werden in throws-Kontext;
            // Caller muss sicherstellen dass Permission vorher erteilt wurde oder
            // requestPermissionIfNeeded() separat aufrufen.
            Task {
                _ = await AVAudioApplication.requestRecordPermission()
            }
            return
        case .granted:
            break
        @unknown default:
            return
        }

        // Sicherheits-removeTap vor neuem installTap (Pitfall 5 aus RESEARCH.md)
        // T-02-04: Verhindert doppelte Taps bei wiederholtem startRecording()
        engine.inputNode.removeTap(onBus: 0)

        // Geraet setzen bevor Format abgefragt wird (Pitfall 2)
        if let uid = Defaults[.selectedMicUID] {
            try AudioDeviceManager.setInputDevice(uid: uid, engine: engine)
        }

        // Format NACH setDeviceID abfragen — nicht davor cachen (Pitfall 2 aus RESEARCH.md)
        let format = engine.inputNode.outputFormat(forBus: 0)

        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            // AUDIO RENDER THREAD — kein @MainActor hier
            guard let self else { return }

            let rms = self.calculateRMS(buffer: buffer)
            let bufferDuration = Double(buffer.frameLength) / buffer.format.sampleRate
            self.updateSilenceDetection(rms: rms, bufferDuration: bufferDuration)

            // T-02-03: RMS clampen auf 0.0-1.0 — verhindert Out-of-Bounds fuer Waveform-Rendering
            let clampedLevel = CGFloat(min(1.0, rms * 4.0))

            // Observation-B: AppState auf Main Thread aktualisieren + Icon-Update signalisieren
            Task { @MainActor [weak self] in
                self?.appState?.audioLevel = clampedLevel
                self?.onLevelUpdate?()
            }
        }

        try engine.start()
        silenceAccumulator = 0
    }

    /// Stoppt die Mikrofon-Aufnahme und setzt den Tap zurueck.
    /// removeTap wird IMMER als erstes aufgerufen (Pitfall 5).
    func stopRecording() {
        // Pitfall 5: removeTap zuerst, dann stop — verhindert doppelte Callbacks
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        silenceAccumulator = 0
    }

    /// Fordert Mikrofon-Berechtigung an, falls noch nicht erteilt.
    /// Asynchron — nach Abschluss kann startRecording() aufgerufen werden.
    func requestPermissionIfNeeded() async {
        if AVAudioApplication.shared.recordPermission == .undetermined {
            _ = await AVAudioApplication.requestRecordPermission()
        }
    }

    // MARK: - Internal (testbar ohne echtes Mikrofon)

    /// Berechnet den RMS-Pegel eines PCM-Buffers.
    /// Gibt 0.0 zurueck fuer stille Buffer, >0.0 fuer aktive Signale.
    /// - Parameter buffer: AVAudioPCMBuffer vom installTap-Callback
    /// - Returns: Linearer RMS-Wert (nicht normiert, nicht geclampet)
    func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
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

    /// Aktualisiert den Silence-Akkumulator und loest Auto-Stopp aus wenn noetig.
    /// - Parameters:
    ///   - rms: Aktueller RMS-Wert des Buffers
    ///   - bufferDuration: Dauer des Buffers in Sekunden (frameLength / sampleRate)
    func updateSilenceDetection(rms: Float, bufferDuration: TimeInterval) {
        if rms < silenceThresholdRMS {
            silenceAccumulator += bufferDuration
            if silenceAccumulator >= Defaults[.silenceDuration] {
                // Auto-Stopp auf Main Thread ausloesen (D-07)
                Task { @MainActor [weak self] in
                    self?.onAutoStop?()
                }
            }
        } else {
            // Sprache erkannt — Akkumulator zuruecksetzen (D-08)
            silenceAccumulator = 0
        }
    }
}
