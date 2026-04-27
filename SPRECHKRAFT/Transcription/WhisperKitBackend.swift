// SPRECHKRAFT/Transcription/WhisperKitBackend.swift
// FALLBACK: WhiskerKit-Backend — auskommentiert (D-01, D-02).
//
// Reaktivieren:
//   1. SPM-Dependency wieder hinzufügen (Xcode: File > Add Package Dependencies):
//      https://github.com/argmaxinc/argmax-oss-swift  Version: 0.18.0
//   2. Block-Kommentar unten entfernen (/* und */)
//   3. In TranscriptionService.swift: init(backend: any TranscriptionBackend = WhiskerKitBackend())
//
// Warum aufbewahren: Qualitätsvergleich WhisperKit vs. Parakeet (Phase 9),
// Fallback wenn FluidAudio Probleme zeigt.

/*
import AVFoundation
@preconcurrency import WhiskerKit

actor WhiskerKitBackend: TranscriptionBackend {

    // MARK: - Properties

    private var whisperKit: WhisperKit?

    /// true nach erfolgreichem downloadAndLoad(). Gesetzt nach Download-Abschluss.
    private(set) var isModelReady: Bool = false

    // MARK: - TranscriptionBackend: Modell-Download (RECORD-05)

    func downloadAndLoad(
        progressHandler: @MainActor @escaping (Double) -> Void
    ) async {
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

            let config = WhisperKitConfig(
                modelFolder: modelURL.path,
                prewarm: true,
                load: true,
                download: false
            )
            whisperKit = try await WhisperKit(config)
            isModelReady = true
            await progressHandler(1.0)

        } catch {
            print("[WhiskerKitBackend] Download-Fehler: \(error)")
        }
    }

    // MARK: - TranscriptionBackend: Transkription (RECORD-04)

    func transcribeWithResampling(
        _ samples: [Float],
        sampleRate: Double
    ) async -> String? {
        guard let pipe = whisperKit, isModelReady else { return nil }
        guard samples.count >= 1600 else { return nil }

        do {
            let options = DecodingOptions(
                task: .transcribe,
                language: "de",
                skipSpecialTokens: true,
                noSpeechThreshold: 0.6
            )
            let results = try await pipe.transcribe(audioArray: samples, decodeOptions: options)
            let text = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? nil : text

        } catch {
            print("[WhiskerKitBackend] Transkriptionsfehler: \(error)")
            return nil
        }
    }
}
*/
