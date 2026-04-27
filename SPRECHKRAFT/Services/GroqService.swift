// SPRECHKRAFT/Services/GroqService.swift
// Zweck: URLSession-basierter Groq-LLM-Client fuer qwen3-32b (PROF-05).
// D-07: URLSession direkt — kein Third-Party-SDK.
// D-08: Modell qwen/qwen3-32b fest kodiert — kein Modell-Picker.
// D-09: isThinkingEnabled=false → reasoning_effort: "none"; true → Feld fehlt im JSON.
// D-10: Stille Fallback — Aufrufer (AppDelegate) faengt Fehler ab und gibt Raw-Text aus.
// T-5-03: HTTPS erzwungen via fest kodierter URL (kein HTTP-Fallback).
// T-5-01/T-5-02: API-Key wird als Parameter uebergeben — nie gecacht im actor selbst.

import Foundation

actor GroqService: GroqServiceProtocol {
    static let shared = GroqService()

    // T-5-03: HTTPS erzwungen — URL ist literal, kein Fallback auf http://
    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!

    // Timeout: 30s (RESEARCH.md Open Questions #2)
    // Groq hat typisch <3s Latenz; 30s gibt Buffer fuer hohe Last bei langen Transkripten.
    private let timeoutSeconds: TimeInterval = 30

    // MARK: - Request/Response Typen (internal: @testable import braucht Zugriff)

    struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let top_p: Double
        let reasoning_effort: String?   // nil = Thinking (Feld fehlt im JSON); "none" = non-thinking

        struct Message: Encodable {
            let role: String
            let content: String
        }

        // KRITISCH: Custom encode um encodeIfPresent fuer reasoning_effort zu verwenden.
        // Standard-JSONEncoder wuerde nil als "reasoning_effort":null kodieren —
        // Groq-API erwartet das Feld bei Thinking-Mode gaenzlich wegzulassen (Pitfall 5).
        private enum CodingKeys: String, CodingKey {
            case model, messages, temperature, top_p, reasoning_effort
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(model, forKey: .model)
            try container.encode(messages, forKey: .messages)
            try container.encode(temperature, forKey: .temperature)
            try container.encode(top_p, forKey: .top_p)
            try container.encodeIfPresent(reasoning_effort, forKey: .reasoning_effort)
        }
    }

    struct ChatResponse: Decodable {
        let choices: [Choice]

        struct Choice: Decodable {
            let message: Message

            struct Message: Decodable {
                let content: String
            }
        }
    }

    enum GroqError: Error {
        case emptyResponse
    }

    // MARK: - API-Call

    /// Sendet Transkript mit Profil-Prompt an Groq qwen3-32b und gibt verarbeiteten Text zurueck.
    /// D-10: Stille Fallback liegt beim Aufrufer (AppDelegate) — dieser Service wirft Fehler,
    ///       AppDelegate faengt ab und gibt rawText zurueck.
    /// T-5-01/T-5-02: apiKey wird als Parameter empfangen, nie als Property gecacht.
    ///                  Aufrufer liest Key unmittelbar vor dem Aufruf aus Keychain.
    func process(transcript: String, profile: PromptProfile, apiKey: String) async throws -> String {
        // System-Prompt optional: nur senden wenn Profil einen nicht-leeren Prompt hat
        var messages: [ChatRequest.Message] = []
        if !profile.prompt.isEmpty {
            messages.append(.init(role: "system", content: profile.prompt))
        }
        messages.append(.init(role: "user", content: transcript))

        // D-09: Thinking via reasoning_effort (nicht /no_think Prefix — instabil, RESEARCH.md)
        let request = ChatRequest(
            model: "qwen/qwen3-32b",
            messages: messages,
            temperature: profile.isThinkingEnabled ? 0.6 : 0.7,
            top_p: profile.isThinkingEnabled ? 0.95 : 0.8,
            reasoning_effort: profile.isThinkingEnabled ? nil : "none"
        )

        var urlRequest = URLRequest(url: endpoint, timeoutInterval: timeoutSeconds)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // T-5-01: API-Key als Bearer-Token — nie in Log-Output schreiben
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)

        guard let content = response.choices.first?.message.content else {
            throw GroqError.emptyResponse
        }
        return content
    }
}
