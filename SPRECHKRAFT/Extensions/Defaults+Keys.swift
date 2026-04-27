// SPRECHKRAFT/Extensions/Defaults+Keys.swift
// Zweck: Type-safe Defaults-Keys fuer Phase 2 Audio-Subsystem und Phase 4 Text-Ausgabe.
// SET-03: silenceDuration — konfigurierbare Stille-Erkennungs-Dauer (D-09: Standard 1.5s)
// SET-04: selectedMicUID — uniqueID des gewaehlten Mikrofons (nil = System-Standard)
// OUT-02: outputMode — Ausgabemodus (.field = Standard per D-06, .clipboard = Fallback)
// OUT-03: toggleOutputMode-Hotkey wird in KeyboardShortcuts+Names.swift definiert

import Defaults

/// Ausgabemodus: Textfeld-Injektion via AX (Standard) oder Clipboard.
/// D-06: .field ist Standard beim ersten App-Start.
/// D-07: Persistiert via Defaults unter dem Key "outputMode".
enum OutputMode: String, Defaults.Serializable {
    case field      // Textfeld-Injektion via AXUIElement (Standard)
    case clipboard  // Clipboard-Kopie via NSPasteboard
}

extension Defaults.Keys {
    /// Stille-Erkennungs-Dauer in Sekunden. Nach Ablauf loest AudioController Auto-Stopp aus.
    /// Standard 1.5s gemaess D-09. Konfigurierbar via Slider in SettingsView (D-10).
    static let silenceDuration = Key<Double>("silenceDuration", default: 1.5)

    /// UniqueID des vom Nutzer gewaehlten Mikrofons. nil bedeutet System-Standard.
    /// Wird beim naechsten startRecording() angewendet (lazy, kein Mid-Recording-Switch).
    static let selectedMicUID = Key<String?>("selectedMicUID", default: nil)

    /// Ausgabemodus: Textfeld-Injektion (.field) oder Clipboard (.clipboard).
    /// Standard .field gemaess D-06 (Core Value: Tippen-Ersatz).
    static let outputMode = Key<OutputMode>("outputMode", default: .field)

    // Phase 5: PROF-01 — [PromptProfile] Persistenz via Defaults.
    // D-04: Codable Array; D-05: ein Default-Profil "Rohe Transkription" beim ersten Start.
    // activeProfileID ist NICHT hier gespeichert — das ist reiner Laufzeit-State in AppState.
    static let profiles = Key<[PromptProfile]>(
        "profiles",
        default: [PromptProfile.defaultProfile]
    )

    /// ONB-01: true nach dem ersten App-Start-Durchlauf des Onboarding-Flows.
    static let hasCompletedOnboarding = Key<Bool>("hasCompletedOnboarding", default: false)
}
