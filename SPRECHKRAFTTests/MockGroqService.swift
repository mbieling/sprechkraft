import Foundation
@testable import SPRECHKRAFT

/// Ein Mock-Dienst für Unit-Tests, der das GroqServiceProtocol implementiert.
/// Ermöglicht die Simulation von Erfolgs- und Fehlerszenarien.
class MockGroqService: GroqServiceProtocol, @unchecked Sendable {
    /// Bestimmt, ob der nächste Aufruf fehlschlagen soll.
    var shouldFail = false
    /// Tracker, um zu prüfen, ob die Methode aufgerufen wurde.
    var processWasCalled = false
    /// Die Fehlermeldung oder der Error, der geworfen werden soll.
    var errorToThrow: Error = NSError(domain: "com.sprechkraft.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "API Timeout"])
    /// Rückgabewert für den Erfolgsfall.
    var mockResponse = "Dies ist ein optimierter Test-Text."

    func process(transcript: String, profile: PromptProfile, apiKey: String) async throws -> String {
        processWasCalled = true
        if shouldFail { throw errorToThrow }
        return mockResponse
    }
}