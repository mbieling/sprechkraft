// VoiceScribe/Transcription/TranscriptionService.swift
// Zweck: WhisperKit-Wrapper fuer lokale Transkription.
// RECORD-04: Transkription via WhisperKit, Resampling via AVAudioConverter
// RECORD-05: Modell-Download beim App-Start mit Fortschrittsanzeige
//
// Swift 6 Concurrency: actor — serialisiert WhisperKit-Zugriff, verhindert parallele Transcription-Calls.
// @preconcurrency import WhisperKit: WhisperKit v0.18.0 ist noch nicht vollstaendig Swift-6-clean.

import AVFoundation
@preconcurrency import WhisperKit

actor TranscriptionService {

    // MARK: - Properties

    private var whisperKit: WhisperKit?

    /// true nach erfolgreichem downloadAndLoad(). Gesetzt nach Download-Abschluss.
    /// Wird von transcribe() geprueft — kein Aufruf wenn Modell nicht geladen.
    private(set) var isModelReady: Bool = false

    // MARK: - Modell-Download (RECORD-05)

    /// Laedt das Modell herunter (einmalig, beim App-Start) und initialisiert WhisperKit.
    /// Fortschritts-Updates via progressHandler auf @MainActor.
    /// Bei Fehler: stille Rueckkehr, isModelReady bleibt false (D-13).
    func downloadAndLoad(
        progressHandler: @MainActor @escaping (Double) -> Void
    ) async {
        // Bereits geladen — kein erneuter Download
        guard !isModelReady else { return }

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

            // Zwei-Phasen-Initialisierung: Download-Pfad verwenden, kein erneuter Download (RESEARCH.md Pitfall 2)
            let config = WhisperKitConfig(
                modelFolder: modelURL.path,
                prewarm: true,
                load: true,
                download: false
            )
            whisperKit = try await WhisperKit(config)
            isModelReady = true

        } catch {
            print("Download-Fehler: \(error)")   // D-13: stille Rueckkehr, kein User-Feedback
            // isModelReady bleibt false — naechster Versuch beim naechsten App-Start
        }
    }

    // MARK: - Transkription (RECORD-04)

    /// Transkribiert ein [Float]-Array bei 16 kHz.
    /// Gibt nil zurueck bei Fehler oder wenn Modell nicht geladen (D-12).
    /// - Parameter samples: Float-Array bei 16 kHz mono
    func transcribe(_ samples: [Float]) async -> String? {
        guard let pipe = whisperKit, isModelReady else { return nil }
        // Minimum-Guard: < 0.1s @ 16kHz — zu kurz fuer sinnvolle Transkription (RESEARCH.md)
        guard samples.count >= 1600 else { return nil }

        do {
            let options = DecodingOptions(
                task: .transcribe,
                language: "de",           // D-03: fest Deutsch
                skipSpecialTokens: true,
                noSpeechThreshold: 0.6    // Zweite Sicherung gegen Halluzinationen bei Stille
            )
            let results = try await pipe.transcribe(audioArray: samples, decodeOptions: options)
            return results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)

        } catch {
            print("Transkriptionsfehler: \(error)")  // D-12: stille Rueckkehr
            return nil
        }
    }

    /// Hilfsmethode: Resampelt bei Bedarf und transkribiert in einem Aufruf.
    /// Wird von AppDelegate.onRecordingComplete-Callback genutzt.
    /// - Parameters:
    ///   - samples: Float-Array bei Hardware-Samplerate
    ///   - sampleRate: Hardware-Samplerate aus AVAudioEngine (z.B. 44100, 48000)
    func transcribeWithResampling(_ samples: [Float], sampleRate: Double) async -> String? {
        let samples16k = resampleTo16kHz(samples, fromSampleRate: sampleRate)
        return await transcribe(samples16k)
    }

    // MARK: - Resampling (RECORD-04)

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
