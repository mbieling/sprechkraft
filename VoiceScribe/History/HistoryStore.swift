// VoiceScribe/History/HistoryStore.swift
// Service-Klasse für GRDB-Datenbankzugriffe (History-Persistenz).
// Implementiert HIST-01 (Insert mit Zeitstempel), HIST-02 (original + LLM),
// HIST-03 (FTS5-Volltextsuche mit FTS5Pattern-Binding — T6-FTS5).
// @MainActor: alle Aufrufer (AppDelegate, HistoryView) laufen auf dem Main Thread.
// Quellen: RESEARCH.md Pattern 1, 3, 5; PATTERNS.md HistoryStore; D-13, D-14, D-15.

import Foundation
import GRDB

@MainActor
final class HistoryStore {

    // MARK: - Singleton (Produktion)

    static let shared: HistoryStore = {
        try! HistoryStore(productionDB: true)
    }()

    private let dbQueue: DatabaseQueue

    // MARK: - Init

    /// Produktions-Initialisierung: Application Support Directory.
    private init(productionDB: Bool) throws {
        let fileManager = FileManager.default
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("VoiceScribe", isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("history.sqlite")
        dbQueue = try DatabaseQueue(path: dbURL.path)
        try migrate()
    }

    /// Test-Initialisierung: In-Memory-DatabaseQueue (kein Filesystem-Zustand).
    /// Wird ausschließlich in HistoryStoreTests verwendet.
    init(inMemory: Bool) throws {
        dbQueue = try DatabaseQueue()  // ohne Pfad = In-Memory (RESEARCH.md Validation Architecture)
        try migrate()
    }

    // MARK: - Migration

    private func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_transcription_entries") { db in
            // D-13: Haupt-Tabelle
            try db.create(table: "transcription_entries") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("created_at", .datetime).notNull()
                t.column("original_text", .text).notNull()
                t.column("llm_text", .text)            // NULL wenn kein LLM-Pfad
                t.column("profile_name", .text)         // NULL wenn kein Profil
                t.column("is_llm_processed", .boolean).notNull()
            }
            // D-14: FTS5-Virtual-Table mit automatischer Trigger-Synchronisation.
            // synchronize(withTable:) erzeugt After-Insert/Update/Delete-Trigger automatisch.
            // Niemals manuell schreiben — GRDB kennt das korrekte FTS5-Trigger-Format (RESEARCH.md Anti-Patterns).
            try db.create(virtualTable: "transcription_entries_fts", using: FTS5()) { t in
                t.synchronize(withTable: "transcription_entries")
                t.tokenizer = .unicode61()  // Unicode-Support für deutsche Umlaute (RESEARCH.md OQ1)
                t.column("original_text")
                t.column("llm_text")
            }
        }
        try migrator.migrate(dbQueue)
    }

    // MARK: - CRUD

    /// Speichert einen neuen HistoryEntry in der Datenbank.
    /// D-15: Wird nach TextOutputService.output() aufgerufen (in AppDelegate.onRecordingComplete).
    func insert(_ entry: HistoryEntry) throws {
        try dbQueue.write { db in
            try entry.insert(db)
        }
    }

    /// Löscht einen einzelnen Eintrag.
    /// FTS5-Index wird automatisch via synchronize-Trigger aktualisiert (Pitfall 2).
    func delete(_ entry: HistoryEntry) throws {
        try dbQueue.write { db in
            try entry.delete(db)
        }
    }

    /// Löscht alle Einträge (D-12: Gesamt-Löschen mit vorhergehendem Confirm-Dialog in HistoryView).
    func deleteAll() throws {
        try dbQueue.write { db in
            try HistoryEntry.deleteAll(db)
        }
    }

    // MARK: - Suche

    /// Sucht Einträge via FTS5.
    /// Leerer Query → alle Einträge ORDER BY created_at DESC.
    /// T6-FTS5-Mitigation: FTS5Pattern(matchingAllTokensIn:) als Binding — kein String-Interpolation.
    func search(query: String) throws -> [HistoryEntry] {
        try dbQueue.read { db in
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                return try HistoryEntry.order(Column("created_at").desc).fetchAll(db)
            }
            // T6-FTS5: FTS5Pattern ist safe für User-Input — nil bei ungültigem Pattern (Pitfall 6)
            guard let pattern = FTS5Pattern(matchingAllTokensIn: query) else {
                return []  // Sicherer Fallback: kein Absturz bei ungültigem FTS5-Token
            }
            // Explizite SQL-Variante für Content-Table Setup (RESEARCH.md Pattern 3)
            return try HistoryEntry.fetchAll(db,
                sql: """
                    SELECT transcription_entries.*
                    FROM transcription_entries
                    WHERE transcription_entries.rowid IN (
                        SELECT rowid FROM transcription_entries_fts
                        WHERE transcription_entries_fts MATCH ?
                    )
                    ORDER BY created_at DESC
                """,
                arguments: [pattern])
        }
    }

    // MARK: - Observation

    /// AsyncValueObservation-Sequenz für automatisches List-Update bei neuen Einträgen.
    /// In HistoryView mit task(id:) Modifier konsumieren — verhindert Task-Leak (Pitfall 7).
    /// Rückgabetyp: AsyncValueObservation<[HistoryEntry]> — GRDB-nativer Async-Sequence-Typ.
    func observeAll() -> AsyncThrowingStream<[HistoryEntry], Error> {
        let observation = ValueObservation
            .tracking { db in
                try HistoryEntry.order(Column("created_at").desc).fetchAll(db)
            }
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await entries in observation.values(in: self.dbQueue) {
                        continuation.yield(entries)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
