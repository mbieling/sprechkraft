// VoiceScribe/Transcription/ParakeetBackend.swift
// Zweck: FluidAudio/Parakeet TDT v3 Backend (RECORD-04, RECORD-05).
// Implementiert TranscriptionBackend — wird von TranscriptionService(Facade) verwendet.
// Swift 6: actor-Isolierung serialisiert AsrManager-Zugriff. @preconcurrency import wenn nötig (D-12).
// Pitfall I8: Warmup-Inferenz nach loadModels ist Pflicht (Metal Shader JIT, 5-15s ohne Warmup).
// Pitfall C4: downloadAndLoad NIEMALS auf @MainActor aufrufen — actor-Methoden sind automatisch off-thread.

@preconcurrency import FluidAudio

actor ParakeetBackend: TranscriptionBackend {

    // MARK: - Properties

    private var asrManager: AsrManager?

    /// true nach erfolgreichem downloadAndLoad() inklusive Warmup-Inferenz.
    /// Wird von TranscriptionService.isModelReady weitergereicht.
    private(set) var isModelReady: Bool = false

    // MARK: - TranscriptionBackend: Model Download + Load (RECORD-05)

    /// Lädt Parakeet TDT v3 via FluidAudio und führt Warmup-Inferenz durch.
    /// progressHandler: 0.0 = Beginn, 1.0 = bereit (keine Zwischenwerte — D-06, Pitfall 3).
    /// Stille Rückkehr bei Fehler — isModelReady bleibt false (D-13).
    func downloadAndLoad(
        progressHandler: @MainActor @escaping (Double) -> Void
    ) async {
        guard !isModelReady else { return }

        await progressHandler(0.0)   // Signal: Download/Load läuft (AppDelegate zeigt .modelLoading)

        do {
            // 1. Download (intern: HuggingFace → CoreML-Compilation → Cache)
            //    Kein Progress-Parameter in dieser Signatur [VERIFIED: Context7 /fluidinference/fluidaudio]
            let models = try await AsrModels.downloadAndLoad(version: .v3)

            // 2. AsrManager initialisieren und Modell laden
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)

            // 3. Warmup-Inferenz: Metal Shader JIT-Kompilierung triggern (Pitfall I8)
            //    1s Stille @ 16kHz — ausreichend für Shader-Warmup ohne spürbare Wartezeit.
            //    try? — Warmup-Fehler darf App nicht blockieren; erste echte Transkription
            //    hat dann ggf. etwas höhere Latenz, ist aber nicht kritisch.
            let dummySamples = [Float](repeating: 0.0, count: 16000)
            _ = try? await manager.transcribe(dummySamples, source: .microphone)

            self.asrManager = manager
            self.isModelReady = true

            await progressHandler(1.0)  // Signal: Backend bereit
        } catch {
            // D-13: Stille Rückkehr — isModelReady bleibt false
            // AppDelegate wertet isModelReady nach downloadAndLoad aus und setzt isModelError
            print("[ParakeetBackend] Download/Load error: \(error)")
        }
    }

    // MARK: - TranscriptionBackend: Transkription (RECORD-04)

    /// Transkribiert ein bereits auf 16 kHz resampeltes Float-Array.
    /// Erwartet: 16 kHz mono Float32 (D-13: Resampling findet in TranscriptionService statt).
    /// Gibt nil zurück bei Fehler, zu kurzen Samples, oder wenn Modell nicht geladen.
    func transcribeWithResampling(
        _ samples: [Float],
        sampleRate: Double   // Wird vom Backend nicht genutzt — D-13 garantiert 16kHz-Input
    ) async -> String? {
        guard let manager = asrManager, isModelReady else { return nil }

        // Minimum-Guard: < 0.1s @ 16kHz — zu kurz für sinnvolle Transkription
        guard samples.count >= 1600 else { return nil }

        do {
            let result = try await manager.transcribe(samples, source: .microphone)
            let trimmed = result.text.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        } catch {
            print("[ParakeetBackend] Transkriptionsfehler: \(error)")
            return nil
        }
    }
}
