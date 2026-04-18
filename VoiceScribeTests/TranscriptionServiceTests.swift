// VoiceScribeTests/TranscriptionServiceTests.swift
// Zweck: Unit-Tests fuer TranscriptionService — Resampling, MinSample-Guard, Model-Ready-State.
// RECORD-04: Resampling korrekte Laenge, Guard gegen zu kurze Aufnahmen
// RECORD-05: isModelReady-Initialzustand

import Testing
import AVFoundation
@testable import VoiceScribe

@Suite("TranscriptionService (RECORD-04, RECORD-05)")
struct TranscriptionServiceTests {

    // MARK: - Hilfsmethoden

    private func makeSamples(count: Int, value: Float = 0.5) -> [Float] {
        Array(repeating: value, count: count)
    }

    // MARK: - RECORD-05: Model-Ready-State

    @Test("isModelReady ist false nach Initialisierung (RECORD-05)")
    func testInitialStateNotReady() async {
        let service = TranscriptionService()
        let ready = await service.isModelReady
        #expect(ready == false, "isModelReady muss false sein bevor downloadAndLoad() aufgerufen wurde")
    }

    // MARK: - RECORD-04: Resampling

    @Test("resampleTo16kHz: 48kHz Input liefert korrekte Ausgangslaenge (RECORD-04)")
    func testResamplingProducesCorrectLength() async {
        let service = TranscriptionService()
        let input = makeSamples(count: 48000)  // 1s @ 48kHz
        let output = await service.resampleTo16kHz(input, fromSampleRate: 48000.0)
        // Erwartete Laenge: 16000 +/- 1% (160 Samples Toleranz fuer Converter-Rundung)
        #expect(abs(output.count - 16000) <= 160,
                "Resampling 48kHz->16kHz: erwartet ~16000, bekommen \(output.count)")
    }

    @Test("resampleTo16kHz: Identitaet wenn sampleRate bereits 16kHz (RECORD-04)")
    func testResamplingIdentityAt16kHz() async {
        let service = TranscriptionService()
        let input = makeSamples(count: 16000)
        let output = await service.resampleTo16kHz(input, fromSampleRate: 16000.0)
        #expect(output.count == 16000, "Kein Resampling noetig bei 16kHz — Laenge unveraendert")
    }

    // MARK: - RECORD-04: Minimum-Sample-Guard

    @Test("transcribe gibt nil fuer Audio < 1600 Samples zurueck (RECORD-04)")
    func testMinimumSampleGuardReturnsNil() async {
        let service = TranscriptionService()
        let shortAudio = makeSamples(count: 800)  // 0.05s @ 16kHz — zu kurz
        let result = await service.transcribe(shortAudio)
        #expect(result == nil, "transcribe() muss nil zurueckgeben fuer Arrays < 1600 Samples")
    }

    @Test("transcribe gibt nil zurueck wenn Modell nicht geladen (RECORD-04)")
    func testTranscribeReturnsNilWhenNotReady() async {
        let service = TranscriptionService()
        let audio = makeSamples(count: 16000)  // Laenge OK, aber Modell nicht geladen
        let result = await service.transcribe(audio)
        #expect(result == nil, "transcribe() muss nil zurueckgeben wenn isModelReady == false")
    }
}
