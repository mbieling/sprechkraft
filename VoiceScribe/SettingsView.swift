// VoiceScribe/SettingsView.swift
// Zweck: Einstellungsfenster mit Mikrofon-Picker, Stille-Erkennungs-Slider,
//        Permission-Bannern und Prompt-Profile-Verwaltung.
// Implementiert: RECORD-03 (Mikrofon-Auswahl), SET-03 (Stille-Konfiguration),
//                SET-04 (Geraetewahl), D-09 bis D-14, FEED-03 (Permission-Anzeige),
//                PROF-01 (Profilliste), SET-01 (Groq-API-Key + Banner).
// Quellen: 02-UI-SPEC.md, 05-UI-SPEC.md (Interaction Contract, Copywriting Contract)
//          02-PATTERNS.md, 05-PATTERNS.md (Defaults.binding-Pattern, SettingsView-Erweiterung)

import SwiftUI
import Defaults
import AVFoundation
import KeyboardShortcuts
import KeychainAccess

struct SettingsView: View {
    /// Wird via VoiceScribeApp injiziert; benoetigt fuer micPermissionDenied-Banner (D-13).
    var appState: AppState?

    @Default(.silenceDuration) private var silenceDuration
    @Default(.selectedMicUID) private var selectedMicUID
    @Default(.outputMode) private var outputMode

    /// Verfuegbare Mikrofone — wird in onAppear via AudioDeviceManager befuellt (RECORD-03).
    @State private var availableMics: [AVCaptureDevice] = []

    // Phase 5: Profil-Sheet State (PROF-01, SET-01)
    @State private var editingProfile: PromptProfile? = nil
    @FocusState private var apiKeyFocused: Bool
    @State private var groqApiKeyInput: String = ""

    /// Eigene Keychain-Instanz fuer Lese-/Schreibzugriff auf den Groq API-Key (T-5-01).
    /// Service-Name identisch mit AppDelegate.keychain — gleicher Keychain-Eintrag.
    private let keychain = Keychain(service: Bundle.main.bundleIdentifier ?? "com.voicescribe")

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

            // --- Textausgabe-Sektion (OUT-01, OUT-02, OUT-03, D-08 bis D-12) ---
            Section("Textausgabe") {
                // D-11: Roter AX-Permission-Banner — nur sichtbar wenn axPermissionDenied == true
                // Analoges Pattern zum micPermissionDenied-Banner (Phase 2)
                if appState?.axPermissionDenied == true {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "hand.raised.slash.fill")
                            .foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bedienungshilfen-Zugriff erforderlich")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                            Text("VoiceScribe benötigt Zugriff, um Text direkt einzufügen. Stattdessen wird Clipboard verwendet.")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        Spacer()
                        Button("Einstellungen öffnen") {
                            // D-11/RESEARCH.md Pattern 4: URL für Privacy → Accessibility
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(Color(.systemRed))
                    .cornerRadius(8)
                    .accessibilityLabel("Bedienungshilfen-Zugriff verweigert. Öffne Einstellungen.")
                }

                // D-08: Ausgabemodus-Picker — Häkchen-analog zum Menü
                // D-07: Persistiert via Defaults.Key<OutputMode>
                Picker("Ausgabemodus", selection: $outputMode) {
                    Text("Textfeld-Injektion").tag(OutputMode.field)
                    Text("Clipboard").tag(OutputMode.clipboard)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Ausgabemodus")

                Text("Textfeld: Text wird direkt an der Cursorposition eingefügt. Clipboard: Text wird kopiert, zum Einfügen ⌘V drücken.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                // D-09: toggleOutputMode-Hotkey konfigurierbar (⇧⌘V Standard)
                KeyboardShortcuts.Recorder("Modus-Wechsel-Hotkey", name: .toggleOutputMode)
                    .accessibilityLabel("Modus-Wechsel-Hotkey konfigurieren")
            }
            // MARK: - Prompt-Profile (PROF-01 bis PROF-04, SET-01)
            Section("Prompt-Profile") {
                // SET-01: Groq API-Key-Banner — analog axPermissionDenied-Banner (T-5-01)
                if appState?.groqKeyMissing == true {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "key.slash")
                            .foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Groq API-Schlüssel fehlt")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Ohne API-Schlüssel ist LLM-Verarbeitung nicht möglich. Füge deinen Schlüssel ein.")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        Spacer()
                        Button("Schlüssel eingeben") {
                            apiKeyFocused = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(Color(.systemRed))
                    .cornerRadius(8)
                    .accessibilityLabel("Groq API-Schlüssel fehlt. Füge deinen Schlüssel in das Eingabefeld ein.")
                }

                // SET-01: API-Key-Eingabe (T-5-01: sofort bei onChange in Keychain schreiben)
                SecureField("API-Schlüssel", text: $groqApiKeyInput)
                    .textContentType(.password)
                    .focused($apiKeyFocused)
                    .onChange(of: groqApiKeyInput) { _, newValue in
                        // T-5-01: Key sofort in Keychain schreiben — nie in UserDefaults/AppState
                        keychain["groqApiKey"] = newValue.isEmpty ? nil : newValue
                        appState?.groqKeyMissing = newValue.isEmpty
                    }
                Text("Schlüssel wird sicher im macOS Keychain gespeichert.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                // Profilliste (PROF-01, PROF-02, PROF-03, PROF-04)
                ForEach(Defaults[.profiles]) { profile in
                    HStack {
                        Text(profile.name)
                            .font(.system(size: 13))
                            .lineLimit(1)
                        Spacer()
                        if profile.isDefault {
                            Text("⭐")
                                .font(.system(size: 13))
                                .accessibilityLabel("Standard-Profil")
                        }
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingProfile = profile }
                }

                // Neues Profil anlegen
                Button {
                    let newProfile = PromptProfile(
                        id: UUID(),
                        name: "",
                        prompt: "",
                        isLLMEnabled: false,
                        isThinkingEnabled: false,
                        isDefault: false
                    )
                    editingProfile = newProfile
                } label: {
                    Label("Profil hinzufügen", systemImage: "plus")
                        .font(.system(size: 13))
                }
                .buttonStyle(.borderless)
            }
        }
        .formStyle(.grouped)
        .padding(DesignTokens.Spacing.xl)
        .onAppear {
            // Mikrofon-Liste beim Oeffnen des Settings-Fensters befuellen (RECORD-03)
            availableMics = AudioDeviceManager.availableMicrophones()
            // SET-01: Groq API-Key aus Keychain laden (nur zum Befuellen des SecureField)
            groqApiKeyInput = keychain["groqApiKey"] ?? ""
        }
        .sheet(item: $editingProfile) { profile in
            let profiles = Defaults[.profiles]
            let isOnlyProfile = profiles.count <= 1

            ProfileEditorSheet(
                profile: profile,
                isOnlyProfile: isOnlyProfile,
                onSave: { updatedProfile in
                    var current = Defaults[.profiles]
                    if let idx = current.firstIndex(where: { $0.id == updatedProfile.id }) {
                        current[idx] = updatedProfile
                    } else {
                        // Neues Profil — hinzufuegen
                        current.append(updatedProfile)
                    }
                    Defaults[.profiles] = current
                    // Profil-Hotkeys neu registrieren nach Aenderung (Pitfall 2)
                    NotificationCenter.default.post(name: .refreshProfileHotkeys, object: nil)
                },
                onDelete: {
                    var current = Defaults[.profiles]
                    current.removeAll { $0.id == profile.id }
                    // T-5-04: Wenn geloeschtes Profil das Default war → erstes verbleibendes als Default
                    if profile.isDefault, let firstIdx = current.indices.first {
                        current[firstIdx].isDefault = true
                    }
                    Defaults[.profiles] = current
                    // Profil-Hotkey-Binding loeschen
                    KeyboardShortcuts.reset(.profile(profile.id))
                    NotificationCenter.default.post(name: .refreshProfileHotkeys, object: nil)
                },
                onSetDefault: {
                    // PROF-04 isDefault-Invariante: alle anderen auf false, dieses auf true
                    var current = Defaults[.profiles]
                    current = current.map { p in
                        var copy = p; copy.isDefault = (p.id == profile.id); return copy
                    }
                    Defaults[.profiles] = current
                }
            )
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

#Preview("Settings mit AX-Permission-Fehler") {
    let state = AppState()
    Task { @MainActor in
        state.axPermissionDenied = true
    }
    return SettingsView(appState: state)
        .frame(width: 450, height: 500)
}
