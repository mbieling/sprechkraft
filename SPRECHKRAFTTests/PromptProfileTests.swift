// SPRECHKRAFTTests/PromptProfileTests.swift
// Zweck: TDD RED-Stubs fuer PromptProfile — Wave 0 scheitert, Wave 1 gruen.
// PROF-01: CRUD-Shape (defaultProfile, Defaults-Key, Codable Round-Trip)
// PROF-03: LLM-Toggle unabhaengig von isDefault
// PROF-04: isDefault-Invariante (genau 1 Default nach Markierung)

import Foundation
import Testing
import Defaults
@testable import SPRECHKRAFT

@Suite("Prompt Profile (PROF-01, PROF-03, PROF-04)")
struct PromptProfileTests {

    @Test("PromptProfile.defaultProfile hat korrekte Initialwerte (PROF-01)")
    func testDefaultProfileShape() {
        let profile = PromptProfile.defaultProfile
        #expect(profile.name == "Rohe Transkription")
        #expect(profile.isLLMEnabled == false)
        #expect(profile.isThinkingEnabled == false)
        #expect(profile.isDefault == true)
        #expect(profile.prompt == "")
    }

    @Test("Defaults.Keys.profiles hat genau 1 Default-Profil beim ersten Start (PROF-01)")
    func testProfilesDefaultKey() {
        #expect(Defaults.Keys.profiles.defaultValue.count == 1)
        #expect(Defaults.Keys.profiles.defaultValue.first?.isDefault == true)
        #expect(Defaults.Keys.profiles.defaultValue.first?.name == "Rohe Transkription")
    }

    @Test("PromptProfile Codable Round-Trip: encode dann decode ergibt identische Werte (PROF-01)")
    func testCodableRoundTrip() throws {
        let original = PromptProfile(
            id: UUID(),
            name: "Grammatik-Korrektur",
            prompt: "Korrigiere Grammatikfehler.",
            isLLMEnabled: true,
            isThinkingEnabled: false,
            isDefault: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PromptProfile.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.name == original.name)
        #expect(decoded.prompt == original.prompt)
        #expect(decoded.isLLMEnabled == original.isLLMEnabled)
        #expect(decoded.isThinkingEnabled == original.isThinkingEnabled)
        #expect(decoded.isDefault == original.isDefault)
    }

    @Test("isDefault-Invariante: nach Markierung hat genau 1 Profil isDefault == true (PROF-04)")
    func testIsDefaultInvariante() {
        var profiles = [
            PromptProfile(id: UUID(), name: "A", prompt: "", isLLMEnabled: false,
                         isThinkingEnabled: false, isDefault: true),
            PromptProfile(id: UUID(), name: "B", prompt: "", isLLMEnabled: false,
                         isThinkingEnabled: false, isDefault: false),
            PromptProfile(id: UUID(), name: "C", prompt: "", isLLMEnabled: false,
                         isThinkingEnabled: false, isDefault: false),
        ]
        // Invariante-Enforcement: Profil B als Default markieren
        let targetID = profiles[1].id
        profiles = profiles.map { p in
            var copy = p
            copy.isDefault = (p.id == targetID)
            return copy
        }
        let defaultCount = profiles.filter { $0.isDefault }.count
        #expect(defaultCount == 1)
        #expect(profiles.first { $0.isDefault }?.name == "B")
    }

    @Test("LLM-Toggle und isDefault sind unabhaengige Felder (PROF-03)")
    func testLLMToggleUnabhaengigVonDefault() {
        let profile = PromptProfile(
            id: UUID(),
            name: "Analyse",
            prompt: "Analysiere den Text.",
            isLLMEnabled: true,
            isThinkingEnabled: true,
            isDefault: true
        )
        #expect(profile.isLLMEnabled == true)
        #expect(profile.isDefault == true)
        // Beide Flags sind unabhaengig — ein Profil kann LLM UND Default sein
        var noLLM = profile
        noLLM.isLLMEnabled = false
        #expect(noLLM.isDefault == true)  // isDefault bleibt unberuehrt
    }
}
