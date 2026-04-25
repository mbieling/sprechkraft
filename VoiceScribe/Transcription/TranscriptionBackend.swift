// VoiceScribe/Transcription/TranscriptionBackend.swift
// Zweck: Protokoll für austauschbare Transkriptions-Backends (D-11).
// Implementierungen: ParakeetBackend (aktiv), WhiskerKitBackend (auskommentiert).
// Swift 6: Sendable-Konformanz erzwungen — Actors sind per Default Sendable (kein @unchecked nötig).
// API-stabiles Interface: AppDelegate ruft downloadAndLoad + transcribeWithResampling auf
// und darf sich nicht ändern wenn das Backend ausgetauscht wird.

/// Protokoll für Transkriptions-Backends.
/// Jede Implementierung kapselt Download, Initialisierung und Inferenz einer ML-Engine.
/// TranscriptionService (Facade) delegiert alle Aufrufe an ein Backend.
protocol TranscriptionBackend: Sendable {

    /// true nach erfolgreichem downloadAndLoad().
    /// Wird von TranscriptionService.isModelReady weitergereicht an AppDelegate.
    var isModelReady: Bool { get async }

    /// Lädt das Modell herunter (einmalig) und bereitet die Inferenz-Engine vor.
    /// progressHandler: 0.0 = Beginn, 1.0 = abgeschlossen (keine Zwischenwerte bei FluidAudio).
    /// Stille Rückkehr bei Fehler — Caller prüft isModelReady danach.
    func downloadAndLoad(
        progressHandler: @MainActor @escaping (Double) -> Void
    ) async

    /// Transkribiert ein bereits auf 16 kHz resampeltes Float-Array.
    /// Gibt nil zurück bei Fehler, zu kurzen Samples (< 1600), oder wenn Modell nicht geladen.
    /// sampleRate: wird übergeben, Backends erwarten 16000.0 (D-13: Resampling in TranscriptionService).
    func transcribeWithResampling(
        _ samples: [Float],
        sampleRate: Double
    ) async -> String?
}
