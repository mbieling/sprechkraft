// VoiceScribe/Transcription/TranscriptionService.swift
// Zweck: Facade-Actor für austauschbare Transkriptions-Backends.
// RECORD-04: transcribeWithResampling delegiert an das aktive Backend (ParakeetBackend)
// RECORD-05: downloadAndLoad delegiert an das aktive Backend
// D-11: TranscriptionBackend-Protokoll kapselt Backend-Wechsel von AppDelegate und AppState.
// D-13: resampleTo16kHz bleibt hier — backend-unabhängig, wird mit 16kHz-Samples aufgerufen.
//
// AppDelegate-API unverändert:
//   - TranscriptionService()                       → benutzt ParakeetBackend (Standard)
//   - transcriptionService.downloadAndLoad(...)    → delegiert an Backend
//   - transcriptionService.isModelReady            → delegiert an Backend
//   - transcriptionService.transcribeWithResampling(...)  → resampelt, delegiert an Backend
//
// Swift 6 Concurrency: actor — serialisiert Backend-Zugriff, verhindert parallele Inference-Calls.

import AVFoundation

actor TranscriptionService {

    // MARK: - Properties

    private let backend: any TranscriptionBackend

    /// Injizierter Initializer — Standard: ParakeetBackend.
    /// Testbar: TranscriptionService(backend: MockTranscriptionBackend())
    init(backend: any TranscriptionBackend = ParakeetBackend()) {
        self.backend = backend
    }

    /// true nach erfolgreichem downloadAndLoad() im Backend.
    /// Wird von AppDelegate.setupTranscription() nach Download-Abschluss gelesen (D-11).
    var isModelReady: Bool {
        get async { await backend.isModelReady }
    }

    // MARK: - Modell-Download (RECORD-05)

    /// Startet Modell-Download im Backend (einmalig, beim App-Start).
    /// Fortschritts-Updates via progressHandler auf @MainActor.
    /// Bei Fehler: stille Rückkehr, isModelReady bleibt false (D-13).
    func downloadAndLoad(
        progressHandler: @MainActor @escaping (Double) -> Void
    ) async {
        await backend.downloadAndLoad(progressHandler: progressHandler)
    }

    // MARK: - Transkription (RECORD-04)

    /// Resampelt auf 16 kHz und delegiert Transkription an Backend.
    /// Wird von AppDelegate.onRecordingComplete-Callback genutzt.
    /// - Parameters:
    ///   - samples: Float-Array bei Hardware-Samplerate
    ///   - sampleRate: Hardware-Samplerate aus AVAudioEngine (z.B. 44100, 48000)
    func transcribeWithResampling(_ samples: [Float], sampleRate: Double) async -> String? {
        let samples16k = resampleTo16kHz(samples, fromSampleRate: sampleRate)
        return await backend.transcribeWithResampling(samples16k, sampleRate: 16000.0)
    }

    // MARK: - Resampling (RECORD-04, D-13)

    /// Konvertiert [Float]-Array von inputRate auf 16 kHz mono via AVAudioConverter.
    /// Gibt inputSamples unveraendert zurueck wenn inputRate bereits 16 kHz.
    /// Bei Converter-Fehler: Fallback auf unveraenderte Samples (stille Rueckkehr, kein Crash).
    /// Source: Apple TN3136 AVAudioConverter Sample Rate Conversion Pattern
    func resampleTo16kHz(_ inputSamples: [Float], fromSampleRate inputRate: Double) -> [Float] {
        let targetRate: Double = 16000

        // Kein Resampling noetig wenn bereits 16kHz (Toleranz 1 Hz fuer Floating-Point)
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
            guard let baseAddress = ptr.baseAddress else { return }
            inputBuffer.floatChannelData?[0].initialize(from: baseAddress, count: inputSamples.count)
        }

        let outputFrameCount = AVAudioFrameCount(Double(inputSamples.count) * targetRate / inputRate)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCount),
              let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            return inputSamples
        }

        var inputConsumed = false
        var conversionError: NSError?
        converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if inputConsumed {
                // .endOfStream signalisiert dem Converter dass alle Eingabedaten erschoepft sind.
                // .noDataNow wuerde einen erneuten Callback ausloesen → nil-Buffer → paramErr -50.
                outStatus.pointee = .endOfStream
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
}
