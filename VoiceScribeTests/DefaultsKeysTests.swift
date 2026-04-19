// VoiceScribeTests/DefaultsKeysTests.swift
// Zweck: Unit-Tests fuer Defaults-Keys aus Phase 2 und Phase 4.
// SET-03: silenceDuration hat Standardwert 1.5
// SET-04: selectedMicUID hat Standardwert nil
// OUT-02: outputMode hat Standardwert .field (D-06)
// OUT-03: toggleOutputMode hat Default-Shortcut ⇧⌘V (D-09)

import Testing
import Defaults
import KeyboardShortcuts
@testable import VoiceScribe

@Suite("Defaults Keys (SET-03, SET-04)")
struct DefaultsKeysTests {

    @Test("silenceDuration hat Standardwert 1.5 (D-09)")
    func testSilenceDurationDefault() {
        #expect(Defaults.Keys.silenceDuration.defaultValue == 1.5)
    }

    @Test("selectedMicUID hat Standardwert nil (System-Standard)")
    func testSelectedMicUIDDefault() {
        #expect(Defaults.Keys.selectedMicUID.defaultValue == nil)
    }
}

@Suite("OutputMode Enum (OUT-02)")
struct OutputModeTests {

    @Test("OutputMode.field und .clipboard existieren als Faelle")
    func testOutputModeCases() {
        // Beide Faelle muessen kompilierbar sein
        let field: OutputMode = .field
        let clipboard: OutputMode = .clipboard
        #expect(field != clipboard)
    }

    @Test("OutputMode.field hat RawValue 'field'")
    func testOutputModeRawValues() {
        #expect(OutputMode.field.rawValue == "field")
        #expect(OutputMode.clipboard.rawValue == "clipboard")
    }

    @Test("outputMode Default-Key liefert .field (D-06)")
    func testOutputModeDefaultKey() {
        #expect(Defaults.Keys.outputMode.defaultValue == .field)
    }
}

@Suite("Keyboard Shortcuts (OUT-03)")
struct KeyboardShortcutsOutputTests {

    @Test("toggleOutputMode hat ⇧⌘V als Default-Shortcut (D-09)")
    func testToggleOutputModeShortcut() {
        let shortcut = KeyboardShortcuts.Name.toggleOutputMode.defaultShortcut
        #expect(shortcut?.key == .v)
        #expect(shortcut?.modifiers.contains(.shift) == true)
        #expect(shortcut?.modifiers.contains(.command) == true)
    }
}
