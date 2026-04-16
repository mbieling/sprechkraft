// VoiceScribe/SettingsView.swift
// Zweck: Leeres Einstellungsfenster — Placeholder für Phase 1.
// Spätere Phasen ergänzen Tabs und Inhalte (Profile, Audio, Hotkeys).
// Implementiert UI-SPEC D-07 (echtes leeres Fenster, nicht greyed out).

import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack {
            Text("Einstellungen folgen in weiteren Phasen.")
                .font(.system(size: 13))
                .foregroundStyle(Color(.labelColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.xl)
    }
}

#Preview {
    SettingsView()
        .frame(width: 400, height: 300)
}
