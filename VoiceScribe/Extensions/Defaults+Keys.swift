// VoiceScribe/Extensions/Defaults+Keys.swift
// Zweck: Type-safe Defaults-Keys fuer Phase 2 Audio-Subsystem.
// SET-03: silenceDuration — konfigurierbare Stille-Erkennungs-Dauer (D-09: Standard 1.5s)
// SET-04: selectedMicUID — uniqueID des gewaehlten Mikrofons (nil = System-Standard)

import Defaults

extension Defaults.Keys {
    /// Stille-Erkennungs-Dauer in Sekunden. Nach Ablauf loest AudioController Auto-Stopp aus.
    /// Standard 1.5s gemaess D-09. Konfigurierbar via Slider in SettingsView (D-10).
    static let silenceDuration = Key<Double>("silenceDuration", default: 1.5)

    /// UniqueID des vom Nutzer gewaehlten Mikrofons. nil bedeutet System-Standard.
    /// Wird beim naechsten startRecording() angewendet (lazy, kein Mid-Recording-Switch).
    static let selectedMicUID = Key<String?>("selectedMicUID", default: nil)
}
