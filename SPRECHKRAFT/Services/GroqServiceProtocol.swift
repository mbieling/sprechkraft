import Foundation

protocol GroqServiceProtocol: Sendable {
    func process(transcript: String, profile: PromptProfile, apiKey: String) async throws -> String
}
