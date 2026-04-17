// VoiceScribeTests/AudioControllerTests.swift
// Zweck: Unit-Tests fuer AudioController — RMS-Berechnung und Silence-Detection.
// RECORD-01: AVAudioEngine start/stop (indirekt via RMS-Tests)
// RECORD-02: Silence-Akkumulator loest Auto-Stopp nach konfigurierter Dauer aus
//
// Strategie: Tests ohne echtes Mikrofon — RMS und Silence-Logic sind auf AudioController
// isoliert und direkt testbar via interne (non-private) Methoden.

import Testing
import AVFoundation
import Defaults
@testable import VoiceScribe

@Suite("AudioController (RECORD-01, RECORD-02)")
struct AudioControllerTests {

    // MARK: - Hilfsmethoden

    /// Erstellt einen AVAudioPCMBuffer mit allen Samples auf dem gegebenen Wert.
    private func makeBuffer(frameLength: AVAudioFrameCount = 1024, sampleValue: Float) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength)!
        buffer.frameLength = frameLength
        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameLength) {
                channelData[i] = sampleValue
            }
        }
        return buffer
    }

    // MARK: - RMS-Tests

    @Test("calculateRMS gibt ~0.0 fuer stille Buffer (alle Samples 0.0)")
    func testRMSCalculation_silentBuffer() async throws {
        let appState = await MainActor.run { AppState() }
        let controller = AudioController(appState: appState)
        let buffer = makeBuffer(sampleValue: 0.0)

        let rms = controller.calculateRMS(buffer: buffer)

        #expect(rms < 0.001, "Stiller Buffer sollte RMS nahe 0.0 liefern, war: \(rms)")
    }

    @Test("calculateRMS gibt >0.1 fuer laute Buffer (alle Samples 0.5)")
    func testRMSCalculation_loudBuffer() async throws {
        let appState = await MainActor.run { AppState() }
        let controller = AudioController(appState: appState)
        let buffer = makeBuffer(sampleValue: 0.5)

        let rms = controller.calculateRMS(buffer: buffer)

        // RMS bei konstantem Sample 0.5: sqrt(0.5^2) = 0.5
        #expect(rms > 0.1, "Lauter Buffer sollte RMS > 0.1 liefern, war: \(rms)")
        #expect(abs(rms - 0.5) < 0.01, "RMS bei Sample 0.5 sollte ~0.5 sein, war: \(rms)")
    }

    // MARK: - Silence-Detection-Tests

    @Test("Silence-Akkumulator loest Auto-Stopp nach silenceDuration aus (RECORD-02)")
    func testSilenceDetection_triggersAfterDuration() async throws {
        // Setze silenceDuration auf bekannten Wert fuer deterministischen Test
        Defaults[.silenceDuration] = 1.5
        let appState = await MainActor.run { AppState() }
        let controller = AudioController(appState: appState)

        var autoStopCalled = false
        controller.onAutoStop = { autoStopCalled = true }

        // 3x 0.5s Stille = 1.5s — sollte Auto-Stopp ausloesen
        controller.updateSilenceDetection(rms: 0.001, bufferDuration: 0.5)
        controller.updateSilenceDetection(rms: 0.001, bufferDuration: 0.5)
        controller.updateSilenceDetection(rms: 0.001, bufferDuration: 0.5)

        // Task { @MainActor in } asynchron — kurz warten
        try await Task.sleep(for: .milliseconds(50))

        #expect(autoStopCalled, "onAutoStop sollte nach 1.5s Stille aufgerufen worden sein")

        // Aufraumen
        Defaults.reset(.silenceDuration)
    }

    @Test("Silence-Akkumulator wird bei Sprache zurueckgesetzt (RECORD-02)")
    func testSilenceDetection_resetsOnSpeech() async throws {
        Defaults[.silenceDuration] = 1.5
        let appState = await MainActor.run { AppState() }
        let controller = AudioController(appState: appState)

        var autoStopCalled = false
        controller.onAutoStop = { autoStopCalled = true }

        // 1.0s Stille akkumulieren
        controller.updateSilenceDetection(rms: 0.001, bufferDuration: 1.0)
        // Sprache erkannt — Akkumulator wird zurueckgesetzt
        controller.updateSilenceDetection(rms: 0.1, bufferDuration: 0.023)

        // Nun weitere 0.6s Stille — reicht nicht fuer Auto-Stopp weil Reset
        controller.updateSilenceDetection(rms: 0.001, bufferDuration: 0.6)

        try await Task.sleep(for: .milliseconds(50))

        #expect(!autoStopCalled, "onAutoStop sollte NICHT aufgerufen werden nach Sprach-Reset")

        Defaults.reset(.silenceDuration)
    }
}
