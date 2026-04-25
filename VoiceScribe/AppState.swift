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
    case error         // Icon: systemRed,     statisch (Transkriptionsfehler)
    case modelLoading  // NEU (D-06): AsrModels.downloadAndLoad läuft, Spinner aktiv
    case warmingUp     // NEU (D-03): nach Model-Load, Dummy-Inferenz für Metal-Warmup
    case modelError    // NEU (D-09): Download oder Load fehlgeschlagen

    /// Farbe laut UI-SPEC Color Contract (D-02).
    /// Hinweis: idle verwendet exakte sRGB-Komponenten #8E8E93 = (0.557, 0.557, 0.576),
    /// die anderen Zustände nutzen System-Accent-Farben (Dark/Light-Mode-aware).
    var color: Color {
        switch self {
        case .idle:                    return Color(red: 0.557, green: 0.557, blue: 0.576)
        case .recording:               return Color(.systemRed)
        case .transcribing:            return Color(.systemBlue)
        case .llmProcessing:           return Color(.systemPurple)
        case .error:                   return Color(.systemRed)
        case .modelLoading, .warmingUp: return Color(.systemOrange)
        case .modelError:              return Color(.systemRed)
        }
    }

    /// SF Symbol pro Zustand (D-05, D-09).
    var systemImage: String {
        switch self {
        case .idle, .recording, .transcribing, .llmProcessing: return "mic.fill"
        case .warmingUp:          return "hourglass"
        case .error, .modelError: return "exclamationmark.triangle.fill"
        case .modelLoading:       return "arrow.down.circle"
        }
    }

    /// Pulse-Animation Contract (D-04): aktiv für Recording, LLM und Model-Loading.
    var isPulsing: Bool {
        self == .recording || self == .llmProcessing || self == .modelLoading
    }

    /// Pulse-Geschwindigkeit (D-04): 0.8s Recording, 1.2s LLM, 1.0s Model-Loading.
    /// Gibt nil zurück, wenn der Zustand keine Pulse-Animation hat.
    var pulseSpeed: Double? {
        switch self {
        case .recording:    return 0.8
        case .llmProcessing: return 1.2
        case .modelLoading: return 1.0   // mittleres Tempo für Download-Spinner
        default:            return nil
        }
    }

    /// Accessibility Contract laut UI-SPEC: deutscher Text pro Zustand.
    var accessibilityLabel: String {
        switch self {
        case .idle:          return "VoiceScribe — Bereit"
        case .recording:     return "VoiceScribe — Aufnahme läuft"
        case .transcribing:  return "VoiceScribe — Transkribiert"
        case .llmProcessing: return "VoiceScribe — KI verarbeitet"
        case .error:         return "VoiceScribe — Fehler"
        case .modelLoading:  return "VoiceScribe — Modell wird geladen"
        case .warmingUp:     return "VoiceScribe — Modell wird vorbereitet"
        case .modelError:    return "VoiceScribe — Modellfehler"
        }
    }
}

/// Zentrale Source of Truth. Swift 6: @MainActor, damit alle UI-Zugriffe
/// auf dem Main Thread erfolgen. @Observable ermöglicht SwiftUI-Reaktivität.
@MainActor
@Observable
final class AppState {
    var recordingState: RecordingState = .idle

    /// Normierter RMS-Pegel 0.0-1.0, aktualisiert vom AudioController via Task { @MainActor in }.
    /// Wird von StatusBarIconView (FEED-03) fuer die Waveform-Anzeige konsumiert.
    var audioLevel: CGFloat = 0.0

    /// true wenn AVAudioApplication.recordPermission == .denied.
    /// Wird in SettingsView (D-13) fuer den roten Permission-Banner konsumiert.
    var micPermissionDenied: Bool = false

    /// true nach erfolgreichem Modell-Download via TranscriptionService.
    /// Wird von AppDelegate.setupTranscription() gesetzt (D-11).
    /// Blockiert Aufnahme-Start waehrend Download laeuft (T-03-09).
    var isModelReady: Bool = false

    /// true wenn Download oder Load von ParakeetBackend fehlschlaegt (D-08).
    /// Analog zu isModelReady. Wird in AppDelegate.setupTranscription() gesetzt.
    /// Bleibt true bis naechster App-Start — Retry kommt in Phase 8.
    var isModelError: Bool = false

    /// true wenn AXIsProcessTrusted() false zurueckgibt (kein AX-Permission).
    /// Wird in applicationDidFinishLaunching gesetzt (D-10).
    /// Konsumiert von SettingsView fuer den roten AX-Permission-Banner (D-11).
    /// Bei true faellt TextOutputService automatisch auf Clipboard zurueck (D-12).
    var axPermissionDenied: Bool = false

    /// ID des waehrend der laufenden Aufnahme aktivierten Profils via Profil-Hotkey.
    /// nil = kein Profil-Hotkey gedrueckt → Standard-Profil greift in onRecordingComplete.
    /// D-02: Erster gewinnt — wird in setupProfileHotkeys() onKeyDown gesetzt,
    ///        spaetere Hotkey-Events waehrend derselben Aufnahme werden ignoriert.
    /// Wird in onRecordingComplete gelesen und sofort auf nil zurueckgesetzt.
    var activeProfileID: UUID? = nil

    /// true wenn kein Groq API-Key im macOS Keychain vorhanden ist.
    /// Wird in applicationDidFinishLaunching geprueft (analog axPermissionDenied).
    /// Konsumiert von SettingsView fuer den roten Groq-API-Key-Banner (SET-01).
    /// T-5-01: AppState cached NIE den Key selbst — nur dieses Bool-Flag.
    var groqKeyMissing: Bool = false

    init() {}

    /// Phase 2: Echte Zustandsuebergaenge fuer Audio-Capture.
    /// Aufgerufen von AppDelegate nach startRecording()/stopRecording().
    /// .idle -> .recording beim Start; .recording -> .transcribing beim Stopp.
    /// Phase 3 fuellt .transcribing mit echter Transkription.
    func toggleRecording() {
        switch recordingState {
        case .idle:
            recordingState = .recording
        case .recording:
            recordingState = .transcribing
            audioLevel = 0.0  // Waveform zuruecksetzen beim Stopp
        default:
            break  // .transcribing und .llmProcessing werden von spaeteren Phasen behandelt
        }
    }

    /// Setzt Zustand nach Stopp zurueck auf .idle (bis Phase 3 Transkription einfuegt).
    /// Wird von AppDelegate aufgerufen, nachdem .transcribing-State gesetzt wurde.
    func resetToIdle() {
        recordingState = .idle
        audioLevel = 0.0
    }
}
