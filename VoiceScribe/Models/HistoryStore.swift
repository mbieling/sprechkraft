// VoiceScribe/Models/HistoryStore.swift
// Wave-0 Stub — minimal compilation scaffold für HistoryStoreTests RED-Phase.
// Wave 1 (06-02-PLAN) implementiert vollständig mit GRDB/FTS5.

import Foundation

/// Wave-0 Stub: Compile-Scaffold für HistoryStoreTests.
/// Alle Methoden werfen einen Fehler — Tests sind RED bis Wave 1 implementiert.
final class HistoryStore {
    init(inMemory: Bool) throws {
        throw HistoryStoreError.notImplemented
    }

    func insert(_ entry: HistoryEntry) throws {
        throw HistoryStoreError.notImplemented
    }

    func search(query: String) throws -> [HistoryEntry] {
        throw HistoryStoreError.notImplemented
    }

    enum HistoryStoreError: Error {
        case notImplemented
    }
}

/// Wave-0 Stub: Compile-Scaffold für HistoryStoreTests.
/// Wave 1 implementiert als GRDB Record mit FTS5-Content-Table (D-13, D-14).
struct HistoryEntry {
    var id: Int64?
    var createdAt: Date
    var originalText: String
    var llmText: String?
    var profileName: String?
    var isLLMProcessed: Bool

    /// D-09: Kopiert LLM-Text wenn vorhanden, sonst Original.
    var copyText: String {
        llmText ?? originalText
    }
}
