// SPRECHKRAFT/Constants/DesignTokens.swift
// Zweck: Zentrale Design-Token-Konstanten.
// Quelle: UI-SPEC Spacing Scale (Vielfache von 4).

import Foundation
import SwiftUI

/// Design-Tokens für SPRECHKRAFT — ausschließlich Swift-Konstanten, kein CSS.
/// Accent-Farben für Icon-Zustände sind in RecordingState.color (AppState.swift) deklariert,
/// NICHT hier — Icon-State ist Domain, nicht Design.
enum DesignTokens {
    /// Spacing-Skala laut UI-SPEC: Vielfache von 4.
    enum Spacing {
        /// 4 pt — Icon-interne Abstände
        static let xs: CGFloat = 4
        /// 8 pt — Menüpunkt-Innenabstand (vertikal)
        static let sm: CGFloat = 8
        /// 16 pt — Standard-Element-Abstand
        static let md: CGFloat = 16
        /// 24 pt — Abschnittstrennungen im Menü
        static let lg: CGFloat = 24
        /// 32 pt — Fensterkanten-Padding (Einstellungsfenster)
        static let xl: CGFloat = 32
    }
}
