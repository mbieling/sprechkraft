// SPRECHKRAFT/Extensions/KeyboardShortcuts+Names.swift
// Zweck: Registriert den globalen Hotkey-Namen für SPRECHKRAFT.
// Quelle: https://github.com/sindresorhus/keyboardshortcuts/blob/main/readme.md
// Hinweis: initial: Parameter ist nur für nicht-App-Store-Apps erlaubt (Pitfall 6)
// SPRECHKRAFT ist kein App-Store-Release (Sandbox inkompatibel mit globalem Hotkey + AX)
// Wird von Plan 02 vorgezogen, da HotkeyTests.swift (RED-Phase) sonst das Test-Target blockiert.
// Plan 03 integriert diesen Namen in AppDelegate.setupHotkey().

import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self(
        "toggleRecording",
        default: .init(.r, modifiers: [.option, .command])  // ⌥⌘R — SET-02
    )

    /// Wechsel-Hotkey fuer Ausgabemodus (D-09): ⇧⌘V — Mnemonik: V fuer Voice-Paste.
    static let toggleOutputMode = Self(
        "toggleOutputMode",
        default: .init(.v, modifiers: [.shift, .command])
    )

    /// Erzeugt einen stabilen Hotkey-Namen fuer ein Profil anhand seiner UUID.
    /// D-02: UUID-basiert (nicht Index-basiert) — stabil bei Profil-Umsortierung (Phase 6).
    /// RESEARCH.md Pattern 1: dynamische Name-Instanziierung ohne initial: Parameter.
    /// Kein initial: Parameter — Profil-Hotkeys haben keinen vordefinierten Default-Shortcut.
    /// Der String "profile-\(id.uuidString)" ist der Persistence-Key in KeyboardShortcuts UserDefaults.
    static func profile(_ id: UUID) -> Self {
        Self("profile-\(id.uuidString)")
    }
}
