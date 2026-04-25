// VoiceScribe/StatusBarIconView.swift
// Zweck: SwiftUI-Darstellung des Menu-Bar-Icons. Wird via NSHostingView
// (in AppDelegate) in NSStatusItem.button eingebettet.
// Implementiert UI-SPEC Icon-Design Contract (D-01 bis D-04) und FEED-01, FEED-03.

import SwiftUI

/// Darstellung des Menu-Bar-Icons mit Zustandsfarbe, optionaler Pulse-Animation
/// und Waveform-Linie bei aktivem Recording (FEED-03).
/// - Note: Die tatsächliche Einbettung in NSStatusItem übernimmt AppDelegate
///         via NSHostingView.
struct StatusBarIconView: View {
    let state: RecordingState
    /// Normierter RMS-Pegel 0.0–1.0; steuert WaveformView-Amplitude (FEED-03).
    let audioLevel: CGFloat
    @State private var opacity: Double = 1.0

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "mic.fill")
                // D-03: .original — Farben bleiben sichtbar auch auf
                // macOS 26 Tahoe mit transparentem Menu-Bar (Liquid Glass).
                // Hinweis: SwiftUI Image.TemplateRenderingMode nutzt .original (nicht .alwaysOriginal,
                // welches der UIImage/NSImage-API entstammt).
                .renderingMode(.original)
                .foregroundStyle(state.color)
                // Von 16 auf 13 reduziert, da VStack mehr vertikalen Raum beansprucht.
                // Waveform (4 pt) + mic.fill (13 pt) passt in 18 pt Gesamthöhe.
                .font(.system(size: 13, weight: .medium))
                .opacity(opacity)
                .onAppear { applyAnimation(for: state) }
                .onChange(of: state) { _, newState in
                    applyAnimation(for: newState)
                }
            // FEED-03: Waveform nur bei .recording sichtbar (UI-SPEC Icon-State Machine)
            if state == .recording {
                WaveformView(level: audioLevel)
            }
        }
        .frame(width: 18, height: 18)
    }

    /// Wendet die Pulse-Animation an (D-04):
    /// - .recording → easeInOut 0.8s, opacity 1.0 ↔ 0.5, repeatForever
    /// - .llmProcessing → easeInOut 1.2s, opacity 1.0 ↔ 0.5, repeatForever
    /// - .idle / .transcribing → keine Animation, opacity 1.0
    private func applyAnimation(for state: RecordingState) {
        if let speed = state.pulseSpeed {
            withAnimation(
                .easeInOut(duration: speed)
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

/// Canvas-basierte Waveform-Linie für das Menu-Bar-Icon im Recording-Zustand.
/// Positioniert unterhalb des mic.fill-Symbols im 18×4 pt-Canvas (D-01, D-02).
/// - accessibilityHidden: true — rein dekorativ, kein Informationsgehalt (UI-SPEC Accessibility)
struct WaveformView: View {
    /// Normierter RMS-Pegel 0.0–1.0. Steuert Amplitude der Wellenform.
    let level: CGFloat

    var body: some View {
        Canvas { context, size in
            // Minimalamplitude 1 pt — Linie bleibt auch bei Stille sichtbar (UI-SPEC)
            let amplitude = max(1, level * size.height)
            var path = Path()
            let segments = 8
            for i in 0...segments {
                let x = size.width * CGFloat(i) / CGFloat(segments)
                let phase = CGFloat(i) / CGFloat(segments) * .pi * 2
                let y = size.height / 2 + sin(phase) * amplitude / 2
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            // Waveform-Linie: systemRed (identisch mit Recording-Zustandsfarbe, UI-SPEC Color)
            context.stroke(path, with: .color(Color(.systemRed)), lineWidth: 1)
        }
        // UI-SPEC Waveform-Spezifikation: 18 pt breit × 4 pt hoch
        .frame(width: 18, height: 4)
        // UI-SPEC Accessibility Contract: dekoratives Element, kein eigener Label
        .accessibilityHidden(true)
    }
}

#Preview("Idle") {
    StatusBarIconView(state: .idle, audioLevel: 0.0).padding()
}

#Preview("Recording + Level") {
    StatusBarIconView(state: .recording, audioLevel: 0.6).padding()
}

#Preview("Recording Silent") {
    StatusBarIconView(state: .recording, audioLevel: 0.0).padding()
}

#Preview("Transcribing") {
    StatusBarIconView(state: .transcribing, audioLevel: 0.0).padding()
}

#Preview("LLM") {
    StatusBarIconView(state: .llmProcessing, audioLevel: 0.0).padding()
}

#Preview("Model Loading") {
    StatusBarIconView(state: .modelLoading, audioLevel: 0.0).padding()
}

#Preview("Warming Up") {
    StatusBarIconView(state: .warmingUp, audioLevel: 0.0).padding()
}

#Preview("Model Error") {
    StatusBarIconView(state: .modelError, audioLevel: 0.0).padding()
}
