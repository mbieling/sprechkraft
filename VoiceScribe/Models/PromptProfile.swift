// VoiceScribe/Models/PromptProfile.swift
// Zweck: Datenmodell fuer Prompt-Profile (PROF-01 bis PROF-04).
// D-04: Persistenz via Defaults.Serializable (Codable Array in UserDefaults).
// D-05: defaultProfile liefert das initiale "Rohe Transkription"-Profil.
// Kein Hotkey-Feld in der Struct — KeyboardShortcuts speichert Bindings selbst
// unter dem Key "profile-{id.uuidString}" in UserDefaults (RESEARCH.md Pattern 2).

import Foundation
import Defaults

struct PromptProfile: Codable, Defaults.Serializable, Identifiable {
    var id: UUID
    var name: String
    var prompt: String
    var isLLMEnabled: Bool
    var isThinkingEnabled: Bool
    var isDefault: Bool

    /// D-05: Initiales Default-Profil beim ersten App-Start.
    /// Name "Rohe Transkription": LLM deaktiviert, kein Prompt, als Standard markiert.
    /// Wird als Default-Wert fuer Defaults.Keys.profiles verwendet.
    static var defaultProfile: PromptProfile {
        PromptProfile(
            id: UUID(),
            name: "Rohe Transkription",
            prompt: "",
            isLLMEnabled: false,
            isThinkingEnabled: false,
            isDefault: true
        )
    }
}
