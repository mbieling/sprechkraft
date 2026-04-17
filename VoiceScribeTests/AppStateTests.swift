import Testing
@testable import VoiceScribe

// Phase 2: toggleRecording() ist keine Demo-Cycle mehr, sondern echte Zustandsmaschine.
// .idle -> .recording beim Start, .recording -> .transcribing beim Stopp.
// Phase 3 fuellt .transcribing mit echter Transkription.
@Suite("AppState Zustandsmaschine (Phase 2 Audio-Capture)")
@MainActor
struct AppStateTests {
    @Test("startet im Idle-Zustand")
    func initialState() {
        let state = AppState()
        #expect(state.recordingState == .idle)
    }

    @Test("toggleRecording: idle -> recording beim Start")
    func toggleFromIdle() {
        let state = AppState()
        state.toggleRecording()
        #expect(state.recordingState == .recording)
    }

    @Test("toggleRecording: recording -> transcribing beim Stopp, audioLevel reset")
    func toggleFromRecording() {
        let state = AppState()
        state.recordingState = .recording
        state.audioLevel = 0.8
        state.toggleRecording()
        #expect(state.recordingState == .transcribing)
        #expect(state.audioLevel == 0.0)
    }

    @Test("toggleRecording: transcribing und llmProcessing ignoriert (Phase 3)")
    func toggleFromTranscribingAndLLM() {
        let state = AppState()
        state.recordingState = .transcribing
        state.toggleRecording()
        #expect(state.recordingState == .transcribing)  // unveraendert

        state.recordingState = .llmProcessing
        state.toggleRecording()
        #expect(state.recordingState == .llmProcessing)  // unveraendert
    }

    @Test("resetToIdle: setzt Zustand und audioLevel zurueck")
    func resetToIdle() {
        let state = AppState()
        state.recordingState = .transcribing
        state.audioLevel = 0.5
        state.resetToIdle()
        #expect(state.recordingState == .idle)
        #expect(state.audioLevel == 0.0)
    }

    @Test("audioLevel und micPermissionDenied starten mit 0.0 bzw. false")
    func initialAudioProperties() {
        let state = AppState()
        #expect(state.audioLevel == 0.0)
        #expect(state.micPermissionDenied == false)
    }
}
