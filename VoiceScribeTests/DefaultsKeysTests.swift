// VoiceScribeTests/DefaultsKeysTests.swift
// Zweck: Unit-Tests fuer Defaults-Keys aus Phase 2.
// SET-03: silenceDuration hat Standardwert 1.5
// SET-04: selectedMicUID hat Standardwert nil

import Testing
import Defaults
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
