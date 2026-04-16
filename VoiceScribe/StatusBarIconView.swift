// VoiceScribe/StatusBarIconView.swift
// Zweck: SwiftUI-Darstellung des Menu-Bar-Icons. Wird via NSHostingView
// (in Plan 03 / AppDelegate) in NSStatusItem.button eingebettet.
// Implementiert UI-SPEC Icon-Design Contract (D-01 bis D-04) und FEED-01.

import SwiftUI

/// Darstellung des Menu-Bar-Icons mit Zustandsfarbe und optionaler Pulse-Animation.
/// - Note: Die tatsächliche Einbettung in NSStatusItem übernimmt AppDelegate (Plan 03)
///         via NSHostingView.
struct StatusBarIconView: View {
    let state: RecordingState
    @State private var opacity: Double = 1.0

    var body: some View {
        Image(systemName: "mic.fill")
            // D-03: .original — Farben bleiben sichtbar auch auf
            // macOS 26 Tahoe mit transparentem Menu-Bar (Liquid Glass).
            // Hinweis: SwiftUI Image.TemplateRenderingMode nutzt .original (nicht .alwaysOriginal,
            // welches der UIImage/NSImage-API entstammt).
            .renderingMode(.original)
            .foregroundStyle(state.color)
            .font(.system(size: 16, weight: .medium))
            .frame(width: 18, height: 18)
            .opacity(opacity)
            .onAppear { applyAnimation(for: state) }
            .onChange(of: state) { _, newState in
                applyAnimation(for: newState)
            }
    }

    /// Wendet die Pulse-Animation an (D-04):
    /// - .recording → easeInOut 0.8s, opacity 1.0 ↔ 0.5, repeatForever
    /// - .llmProcessing → easeInOut 1.2s, opacity 1.0 ↔ 0.5, repeatForever
    /// - .idle / .transcribing → keine Animation, opacity 1.0
    private func applyAnimation(for state: RecordingState) {
        if state.isPulsing {
            withAnimation(
                .easeInOut(duration: state.pulseSpeed)
                    .repeatForever(autoreverses: true)
            ) {
                opacity = 0.5
            }
        } else {
            withAnimation(nil) {
                opacity = 1.0
            }
        }
    }
}

#Preview("Idle") {
    StatusBarIconView(state: .idle).padding()
}

#Preview("Recording") {
    StatusBarIconView(state: .recording).padding()
}

#Preview("Transcribing") {
    StatusBarIconView(state: .transcribing).padding()
}

#Preview("LLM") {
    StatusBarIconView(state: .llmProcessing).padding()
}
