// VoiceScribe/Transcription/TranscriptionService.swift
// Zweck: Stub fuer RED-Phase (03-01). Wave 1 (03-02) ersetzt diesen Stub mit echter Implementierung.
// RECORD-04: Resampling, Minimum-Sample-Guard
// RECORD-05: isModelReady, downloadAndLoad()

import AVFoundation

/// Stub-Deklaration fuer die RED-Phase. Alle Methoden liefern Fallback-Werte ohne echte Logik.
/// Wave 1 implementiert WhisperKit-Integration, Resampling und Download-Flow.
actor TranscriptionService {

    // RECORD-05: Initialzustand — false, bis downloadAndLoad() abgeschlossen ist
    private(set) var isModelReady: Bool = false

    // MARK: - Download (Wave 1 implementiert)

    func downloadAndLoad(progressHandler: @MainActor @escaping (Double) -> Void) async {
        // Wave 1: WhisperKit.download() + WhisperKit(config) hier
    }

    // MARK: - Resampling (Wave 1 implementiert)

    /// Resamplet ein Float-Array von inputRate auf 16 kHz via AVAudioConverter.
    /// Stub: gibt Input unveraendert zurueck (korrekte Implementierung in Wave 1).
    func resampleTo16kHz(_ samples: [Float], fromSampleRate inputRate: Double) -> [Float] {
        // Wave 1: AVAudioConverter-Implementierung hier
        return samples
    }

    // MARK: - Transcription (Wave 1 implementiert)

    /// Transkribiert ein [Float]-Array (16 kHz). Gibt nil zurueck wenn Modell nicht geladen
    /// oder Audio zu kurz (< 1600 Samples).
    /// Stub: gibt immer nil zurueck (korrekt fuer RED-Tests).
    func transcribe(_ samples: [Float]) async -> String? {
        guard isModelReady else { return nil }
        guard samples.count >= 1600 else { return nil }
        // Wave 1: WhisperKit.transcribe() hier
        return nil
    }
}
