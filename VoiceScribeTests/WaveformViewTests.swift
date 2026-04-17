// VoiceScribeTests/WaveformViewTests.swift
// Zweck: Unit-Tests fuer WaveformView-Initialisierung und StatusBarIconView-Signatur.
// Tiefergehende Canvas-Rendering-Tests sind fuer SwiftUI nicht sinnvoll automatisiert;
// visuelle Pruefung erfolgt im Checkpoint.
// Implementiert: FEED-03 (Waveform-Anzeige).

import Testing
import SwiftUI
@testable import VoiceScribe

@Suite("WaveformView (FEED-03)")
struct WaveformViewTests {

    @Test("WaveformView ist mit beliebigem Level initialisierbar")
    func testWaveformView_exists() {
        let view = WaveformView(level: 0.5)
        // Pruefe dass struct mit Level-Parameter initialisierbar ist.
        // Canvas-Rendering ist nicht automatisiert pruefbar — visuelle Inspektion noetig.
        _ = view
    }

    @Test("WaveformView akzeptiert level 0.0 (Stille)")
    func testWaveformView_silentLevel() {
        let view = WaveformView(level: 0.0)
        _ = view
    }

    @Test("WaveformView akzeptiert level 1.0 (Maximalaussteuerung)")
    func testWaveformView_maxLevel() {
        let view = WaveformView(level: 1.0)
        _ = view
    }

    @Test("StatusBarIconView akzeptiert audioLevel-Parameter")
    func testStatusBarIconView_acceptsAudioLevel() {
        // Prueft dass die neue Signatur mit audioLevel-Parameter kompiliert und initialisierbar ist.
        let view = StatusBarIconView(state: .recording, audioLevel: 0.7)
        _ = view
    }

    @Test("StatusBarIconView akzeptiert audioLevel 0.0 fuer idle-Zustand")
    func testStatusBarIconView_idleWithZeroLevel() {
        let view = StatusBarIconView(state: .idle, audioLevel: 0.0)
        _ = view
    }

    @Test("StatusBarIconView akzeptiert alle Zustaende mit audioLevel")
    func testStatusBarIconView_allStatesWithAudioLevel() {
        let states: [RecordingState] = [.idle, .recording, .transcribing, .llmProcessing]
        for state in states {
            let view = StatusBarIconView(state: state, audioLevel: 0.3)
            _ = view
        }
    }
}
