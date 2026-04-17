// VoiceScribe/SettingsView.swift
// Zweck: Einstellungsfenster mit Mikrofon-Picker, Stille-Erkennungs-Slider
//        und Permission-Banner.
// Implementiert: RECORD-03 (Mikrofon-Auswahl), SET-03 (Stille-Konfiguration),
//                SET-04 (Geraetewahl), D-09 bis D-14, FEED-03 (Permission-Anzeige).
// Quellen: 02-UI-SPEC.md (Interaction Contract, Copywriting Contract, Accessibility Contract)
//          02-PATTERNS.md (Defaults.binding-Pattern, SettingsView-Erweiterungsmuster)

import SwiftUI
import Defaults
import AVFoundation

struct SettingsView: View {
    /// Wird via VoiceScribeApp injiziert; benoetigt fuer micPermissionDenied-Banner (D-13).
    var appState: AppState?

    @Default(.silenceDuration) private var silenceDuration
    @Default(.selectedMicUID) private var selectedMicUID

    /// Verfuegbare Mikrofone — wird in onAppear via AudioDeviceManager befuellt (RECORD-03).
    @State private var availableMics: [AVCaptureDevice] = []

    var body: some View {
        Form {
            // --- Mikrofon-Sektion (RECORD-03, SET-04) ---
            Section("Mikrofon") {
                // D-13: Roter Permission-Banner — nur sichtbar wenn micPermissionDenied == true
                // UI-SPEC: Banner am oberen Rand der Sektion, systemRed Hintergrund
                if appState?.micPermissionDenied == true {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "mic.slash.fill")
                            .foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 2) {
                            // UI-SPEC Copywriting: "Mikrofonzugriff verweigert" (Label, weiß)
                            Text("Mikrofonzugriff verweigert")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                            // UI-SPEC Copywriting: Banner-Body (Caption, weiß)
                            Text("Öffne die Datenschutz-Einstellungen, um VoiceScribe Zugriff zu erteilen.")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        Spacer()
                        // UI-SPEC Copywriting: Banner-Button "Einstellungen öffnen"
                        Button("Einstellungen öffnen") {
                            // D-13: Oeffnet Datenschutz-Einstellungen > Mikrofon
                            // T-02-09: URL oeffnet nur System-Einstellungen, keine sensitiven Daten
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(Color(.systemRed))
                    .cornerRadius(8)
                    // UI-SPEC Accessibility Contract: Permission-Banner
                    .accessibilityLabel("Mikrofonzugriff verweigert. Öffne Einstellungen.")
                }

                // D-11: Mikrofon-Picker mit verfuegbaren AVCaptureDevices
                // UI-SPEC Copywriting: "Eingabegerät" (Label), pickerStyle(.menu)
                Picker("Eingabegerät", selection: $selectedMicUID) {
                    // Default-Option: System-Standard (selectedMicUID == nil)
                    Text("System-Standard").tag(Optional<String>.none)
                    if availableMics.isEmpty {
                        // UI-SPEC Copywriting Leerstand: "Kein Mikrofon gefunden"
                        Text("Kein Mikrofon gefunden")
                            .tag(Optional<String>.some("__none__"))
                    } else {
                        ForEach(availableMics, id: \.uniqueID) { device in
                            Text(device.localizedName).tag(Optional(device.uniqueID))
                        }
                    }
                }
                .pickerStyle(.menu)
                // UI-SPEC Accessibility Contract: Picker-Label
                .accessibilityLabel("Eingabegerät")

                // UI-SPEC Copywriting: Picker-Hilftext (Caption, 11pt)
                Text("Wähle das Mikrofon für die Aufnahme.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // --- Stille-Erkennungs-Sektion (SET-03, D-09, D-10) ---
            Section("Stille-Erkennung") {
                HStack {
                    // UI-SPEC Copywriting: Slider-Label "Automatischer Stopp nach"
                    Text("Automatischer Stopp nach")
                        .font(.system(size: 13))
                    // D-09: Stille-Dauer 0.5-5.0s, Schrittweite 0.5s, Default 1.5s
                    // T-02-07: Slider-Range begrenzt auf 0.5-5.0 — kein Sicherheitsrisiko
                    Slider(
                        value: $silenceDuration,
                        in: 0.5...5.0,
                        step: 0.5
                    )
                    // UI-SPEC Copywriting: Wertanzeige "{wert} s"
                    Text(String(format: "%.1f s", silenceDuration))
                        .font(.system(size: 13))
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
                // UI-SPEC Accessibility Contract: Stille-Slider
                .accessibilityLabel("Automatischer Stopp nach \(String(format: "%.1f", silenceDuration)) Sekunden")

                // UI-SPEC Copywriting: Slider-Hilftext (Caption, 11pt)
                Text("Aufnahme stoppt automatisch, wenn für diese Dauer keine Sprache erkannt wird.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(DesignTokens.Spacing.xl)
        .onAppear {
            // Mikrofon-Liste beim Oeffnen des Settings-Fensters befuellen (RECORD-03)
            availableMics = AudioDeviceManager.availableMicrophones()
        }
    }
}

#Preview("Settings") {
    SettingsView()
        .frame(width: 450, height: 350)
}

#Preview("Settings mit Permission-Fehler") {
    let state = AppState()
    Task { @MainActor in
        state.micPermissionDenied = true
    }
    return SettingsView(appState: state)
        .frame(width: 450, height: 400)
}
