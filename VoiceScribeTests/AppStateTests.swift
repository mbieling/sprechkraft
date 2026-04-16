import Testing
@testable import VoiceScribe

@Suite("AppState Zustandsmaschine (Phase 1 Demo-Cycle)")
@MainActor
struct AppStateTests {
    @Test("startet im Idle-Zustand")
    func initialState() {
        let state = AppState()
        #expect(state.recordingState == .idle)
    }

    @Test("toggleRecording cycelt idle → recording → transcribing → llmProcessing → idle")
    func cyclesThroughAllStates() {
        let state = AppState()
        state.toggleRecording()
        #expect(state.recordingState == .recording)
        state.toggleRecording()
        #expect(state.recordingState == .transcribing)
        state.toggleRecording()
        #expect(state.recordingState == .llmProcessing)
        state.toggleRecording()
        #expect(state.recordingState == .idle)
    }
}
