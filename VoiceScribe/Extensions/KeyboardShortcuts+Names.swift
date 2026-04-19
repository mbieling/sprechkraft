// VoiceScribe/Extensions/KeyboardShortcuts+Names.swift
// Zweck: Registriert den globalen Hotkey-Namen für VoiceScribe.
// Quelle: https://github.com/sindresorhus/keyboardshortcuts/blob/main/readme.md
// Hinweis: initial: Parameter ist nur für nicht-App-Store-Apps erlaubt (Pitfall 6)
// VoiceScribe ist kein App-Store-Release (Sandbox inkompatibel mit globalem Hotkey + AX)
// Wird von Plan 02 vorgezogen, da HotkeyTests.swift (RED-Phase) sonst das Test-Target blockiert.
// Plan 03 integriert diesen Namen in AppDelegate.setupHotkey().

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
}
