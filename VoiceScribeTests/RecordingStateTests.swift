import Testing
import SwiftUI
@testable import VoiceScribe

@Suite("RecordingState (FEED-01)")
struct RecordingStateTests {
    @Test("hat genau 8 Fälle")
    func caseCount() {
        let all: [RecordingState] = [.idle, .recording, .transcribing, .llmProcessing,
                                      .error, .modelLoading, .warmingUp, .modelError]
        #expect(all.count == 8)
    }

    @Test(".idle.color entspricht grau #8E8E93")
    func idleColor() {
        let expected = Color(red: 0.557, green: 0.557, blue: 0.576)
        #expect(RecordingState.idle.color == expected)
    }

    @Test(".recording.color == Color(.systemRed)")
    func recordingColor() {
        #expect(RecordingState.recording.color == Color(.systemRed))
    }

    @Test(".transcribing.color == Color(.systemBlue)")
    func transcribingColor() {
        #expect(RecordingState.transcribing.color == Color(.systemBlue))
    }

    @Test(".llmProcessing.color == Color(.systemPurple)")
    func llmColor() {
        #expect(RecordingState.llmProcessing.color == Color(.systemPurple))
    }

    @Test("isPulsing nur für recording und llmProcessing")
    func isPulsing() {
        #expect(RecordingState.idle.isPulsing == false)
        #expect(RecordingState.recording.isPulsing == true)
        #expect(RecordingState.transcribing.isPulsing == false)
        #expect(RecordingState.llmProcessing.isPulsing == true)
    }

    @Test("pulseSpeed: 0.8s recording, 1.2s llm")
    func pulseSpeed() {
        #expect(RecordingState.recording.pulseSpeed == 0.8)
        #expect(RecordingState.llmProcessing.pulseSpeed == 1.2)
    }

    @Test("accessibilityLabel nicht leer für alle Zustände")
    func accessibilityLabels() {
        for state: RecordingState in [.idle, .recording, .transcribing, .llmProcessing,
                                       .error, .modelLoading, .warmingUp, .modelError] {
            #expect(!state.accessibilityLabel.isEmpty)
        }
    }

    @Test(".modelLoading und .warmingUp haben systemOrange Farbe (D-06)")
    func modelLoadingColor() {
        #expect(RecordingState.modelLoading.color == Color(.systemOrange))
        #expect(RecordingState.warmingUp.color == Color(.systemOrange))
    }

    @Test(".modelError hat systemRed Farbe (D-09)")
    func modelErrorColor() {
        #expect(RecordingState.modelError.color == Color(.systemRed))
    }

    @Test(".modelLoading.isPulsing == true (Spinner-Animation, D-06)")
    func modelLoadingIsPulsing() {
        #expect(RecordingState.modelLoading.isPulsing == true)
        #expect(RecordingState.warmingUp.isPulsing == false)
        #expect(RecordingState.modelError.isPulsing == false)
    }

    @Test("systemImage der neuen States korrekt (D-05)")
    func newStateSystemImages() {
        #expect(RecordingState.modelLoading.systemImage == "arrow.down.circle")
        #expect(RecordingState.warmingUp.systemImage == "hourglass")
        #expect(RecordingState.modelError.systemImage == "exclamationmark.triangle.fill")
    }
}
