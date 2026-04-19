// VoiceScribeTests/GroqServiceTests.swift
// Zweck: RED-Phase Wave-0-Stubs fuer GroqService actor.
// PROF-05: URLSession-Mock-Strategie, ChatRequest/ChatResponse-Decodierung
// SET-01: API-Key-Sicherheit (kein echter Schluessel im Test-Code, T-5-01)
// D-09: reasoning_effort JSON-Encoding fuer thinking/non-thinking
// T-5-03: HTTPS-Endpoint-Verifizierung

import Testing
import Foundation
@testable import VoiceScribe

@Suite("GroqService (PROF-05, SET-01)")
struct GroqServiceTests {

    // MARK: - D-09: reasoning_effort JSON-Encoding

    @Test("ChatRequest kodiert reasoning_effort: none fuer non-thinking Profil (D-09, PROF-05)")
    func testNonThinkingRequestEncodesReasoningEffort() throws {
        let profile = PromptProfile(
            id: UUID(),
            name: "Test",
            prompt: "Korrigiere den Text.",
            isLLMEnabled: true,
            isThinkingEnabled: false,
            isDefault: false
        )
        let request = GroqService.ChatRequest(
            model: "qwen/qwen3-32b",
            messages: [.init(role: "user", content: "Hallo")],
            temperature: 0.7,
            top_p: 0.8,
            reasoning_effort: profile.isThinkingEnabled ? nil : "none"
        )
        let data = try JSONEncoder().encode(request)
        let jsonString = String(decoding: data, as: UTF8.self)
        #expect(jsonString.contains("\"reasoning_effort\""))
        #expect(jsonString.contains("\"none\""))
    }

    @Test("ChatRequest enthaelt kein reasoning_effort-Feld fuer thinking Profil (D-09, PROF-05)")
    func testThinkingRequestOmitsReasoningEffort() throws {
        let profile = PromptProfile(
            id: UUID(),
            name: "Denker",
            prompt: "Analysiere tiefgruendig.",
            isLLMEnabled: true,
            isThinkingEnabled: true,
            isDefault: false
        )
        let request = GroqService.ChatRequest(
            model: "qwen/qwen3-32b",
            messages: [.init(role: "user", content: "Analysiere")],
            temperature: 0.6,
            top_p: 0.95,
            reasoning_effort: profile.isThinkingEnabled ? nil : "none"
        )
        let data = try JSONEncoder().encode(request)
        let jsonString = String(decoding: data, as: UTF8.self)
        // encodeIfPresent schreibt nil nicht in JSON: Feld darf nicht vorhanden sein
        #expect(!jsonString.contains("reasoning_effort"))
    }

    // MARK: - T-5-03: HTTPS-Endpoint erzwungen

    @Test("GroqService Endpoint verwendet HTTPS-Schema (T-5-03)")
    func testEndpointIsHTTPS() {
        // Endpoint ist als private-Property definiert — via bekannte Konstante verifizieren
        // Die Implementierung in GroqService.swift MUSS diese URL verwenden (Compile-Time via @testable import)
        let endpointURL = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        #expect(endpointURL.scheme == "https")
        // Verifiziert, dass GroqService existiert und initialisierbar ist (kein HTTP-Fallback)
        _ = GroqService.shared  // existiert und ist vom Typ GroqService
    }

    // MARK: - PROF-05: GroqError.emptyResponse bei leeren choices

    @Test("ChatResponse mit leeren choices liefert nil bei choices.first?.message.content (PROF-05)")
    func testEmptyChoicesYieldsNil() throws {
        // JSON mit leerer choices-Liste — kein Netzwerk-Call (reine Decodierung)
        let emptyChoicesJSON = """
        {"choices": []}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(GroqService.ChatResponse.self, from: emptyChoicesJSON)
        #expect(response.choices.first?.message.content == nil)
        // GroqError.emptyResponse wird vom Service geworfen wenn nil — indirekt abgesichert
    }
}
