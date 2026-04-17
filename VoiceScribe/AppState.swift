// VoiceScribe/AppState.swift
// Zweck: Source of Truth für den Aufnahme-Zustand der App.
// Phase 1: Demo-Cycle durch alle 4 Zustände — echte Audio-Logik folgt Phase 2.
// Implementiert Requirement FEED-01 (4 Icon-Zustände) und UI-SPEC D-02/D-04.

import Foundation
import Observation
import SwiftUI

/// 4-Zustands-Modell für das Menu-Bar-Icon.
/// Quelle: CONTEXT.md D-01 bis D-04, UI-SPEC State Machine Contract
enum RecordingState: Equatable {
    case idle          // Icon: grau (#8E8E93), statisch
    case recording     // Icon: systemRed,     pulsierend 0.8s
    case transcribing  // Icon: systemBlue,    statisch
    case llmProcessing // Icon: systemPurple,  pulsierend 1.2s

    /// Farbe laut UI-SPEC Color Contract (D-02).
    /// Hinweis: idle verwendet exakte sRGB-Komponenten #8E8E93 = (0.557, 0.557, 0.576),
    /// die anderen Zustände nutzen System-Accent-Farben (Dark/Light-Mode-aware).
    var color: Color {
        switch self {
        case .idle:          return Color(red: 0.557, green: 0.557, blue: 0.576)
        case .recording:     return Color(.systemRed)
        case .transcribing:  return Color(.systemBlue)
        case .llmProcessing: return Color(.systemPurple)
        }
    }

    /// Pulse-Animation Contract (D-04): aktiv für Recording und LLM.
    var isPulsing: Bool {
        self == .recording || self == .llmProcessing
    }

    /// Pulse-Geschwindigkeit (D-04): 0.8s Recording, 1.2s LLM.
    /// Gibt nil zurück, wenn der Zustand keine Pulse-Animation hat (.idle, .transcribing).
    var pulseSpeed: Double? {
        switch self {
        case .recording:     return 0.8
        case .llmProcessing: return 1.2
        default:             return nil
        }
    }

    /// Accessibility Contract laut UI-SPEC: deutscher Text pro Zustand.
    var accessibilityLabel: String {
        switch self {
        case .idle:          return "VoiceScribe — Bereit"
        case .recording:     return "VoiceScribe — Aufnahme läuft"
        case .transcribing:  return "VoiceScribe — Transkribiert"
        case .llmProcessing: return "VoiceScribe — KI verarbeitet"
        }
    }
}

/// Zentrale Source of Truth. Swift 6: @MainActor, damit alle UI-Zugriffe
/// auf dem Main Thread erfolgen. @Observable ermöglicht SwiftUI-Reaktivität.
@MainActor
@Observable
final class AppState {
    var recordingState: RecordingState = .idle

    init() {}

    /// Phase 1 Demo: cycelt zyklisch durch alle 4 Zustände.
    /// Phase 2 ersetzt dies durch echte Audio-Capture-Events.
    func toggleRecording() {
        switch recordingState {
        case .idle:          recordingState = .recording
        case .recording:     recordingState = .transcribing
        case .transcribing:  recordingState = .llmProcessing
        case .llmProcessing: recordingState = .idle
        }
    }
}
