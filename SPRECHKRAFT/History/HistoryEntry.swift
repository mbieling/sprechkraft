// SPRECHKRAFT/History/HistoryEntry.swift
// Datenmodell für einen Transkriptions-Verlaufseintrag.
// Implementiert HIST-01 (Zeitstempel), HIST-02 (original + LLM Text),
// HIST-04 (copyText: D-09 LLM > Original).
// Quellen: RESEARCH.md Pattern 2; PATTERNS.md HistoryEntry; D-13, D-09, D-03.

import Foundation
import GRDB

/// Ein gespeicherter Transkriptionseintrag.
/// struct (nicht class) — GRDB v7 erzwingt Sendable für Record-Typen in async-Kontexten (Pitfall 3).
struct HistoryEntry: Codable, Identifiable, Sendable {
    // GRDB autoIncrementedPrimaryKey → Int64? (nil vor dem ersten Insert)
    var id: Int64?
    /// Zeitpunkt der Transkription (D-13: created_at DATETIME NOT NULL)
    var createdAt: Date
    /// Rohtext direkt vom Transcription-Service (D-13: original_text TEXT NOT NULL)
    var originalText: String
    /// LLM-verarbeiteter Text; nil wenn LLM nicht aktiv war (D-13: llm_text TEXT nullable)
    var llmText: String?
    /// Name des aktiven Prompt-Profils; nil wenn kein Profil (D-13: profile_name TEXT nullable)
    var profileName: String?
    /// true wenn der Eintrag durch Groq LLM verarbeitet wurde (D-13: is_llm_processed BOOLEAN NOT NULL)
    var isLLMProcessed: Bool

    // MARK: - Computed Properties

    /// D-09: LLM-Text hat Vorrang beim Kopieren — spiegelt tatsächlichen Output.
    var copyText: String {
        llmText ?? originalText
    }

    /// D-03: ~80-Zeichen-Vorschau für die Listenzeile.
    var preview: String {
        let base = copyText
        guard base.count > 80 else { return base }
        return String(base.prefix(80)) + "…"
    }
}

// MARK: - GRDB Conformances

extension HistoryEntry: FetchableRecord, PersistableRecord {
    /// Datenbankname (D-13: Tabelle transcription_entries)
    static var databaseTableName: String { "transcription_entries" }

    /// CodingKeys für snake_case ↔ camelCase Mapping.
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case originalText = "original_text"
        case llmText = "llm_text"
        case profileName = "profile_name"
        case isLLMProcessed = "is_llm_processed"
    }
}
