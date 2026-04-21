// VoiceScribeTests/HistoryStoreTests.swift
// RED-Stubs für Phase 6 History (HIST-01, HIST-02, HIST-03, HIST-04)
// Wave 0: Tests MÜSSEN fehlschlagen bis Wave 1 HistoryStore implementiert.

import Testing
import Foundation
@testable import VoiceScribe

@MainActor
struct HistoryStoreTests {

    // In-Memory-Instanz für Tests — kein Filesystem-Zustand (RESEARCH.md Validation Architecture)
    private func makeStore() throws -> HistoryStore {
        try HistoryStore(inMemory: true)
    }

    // HIST-01: Insert speichert Eintrag mit created_at
    @Test func testInsertPersists() throws {
        let store = try makeStore()
        let entry = HistoryEntry(
            id: nil,
            createdAt: Date(),
            originalText: "Hallo Welt",
            llmText: nil,
            profileName: nil,
            isLLMProcessed: false
        )
        try store.insert(entry)
        let all = try store.search(query: "")
        #expect(all.count == 1)
        #expect(all.first?.originalText == "Hallo Welt")
    }

    // HIST-02: Beide Texte (original + LLM) werden gespeichert
    @Test func testBothTextsStored() throws {
        let store = try makeStore()
        let entry = HistoryEntry(
            id: nil,
            createdAt: Date(),
            originalText: "Rohtext",
            llmText: "Verarbeiteter Text",
            profileName: "Notizen",
            isLLMProcessed: true
        )
        try store.insert(entry)
        let all = try store.search(query: "")
        #expect(all.first?.llmText == "Verarbeiteter Text")
        #expect(all.first?.profileName == "Notizen")
        #expect(all.first?.isLLMProcessed == true)
    }

    // HIST-03: FTS5-Suche findet Eintrag der den Term enthält
    @Test func testFTS5SearchFindsMatch() throws {
        let store = try makeStore()
        let entry = HistoryEntry(
            id: nil,
            createdAt: Date(),
            originalText: "Besprechungsnotizen Quartalsbericht",
            llmText: nil,
            profileName: nil,
            isLLMProcessed: false
        )
        try store.insert(entry)
        let results = try store.search(query: "Quartalsbericht")
        #expect(results.count == 1)
        #expect(results.first?.originalText == "Besprechungsnotizen Quartalsbericht")
    }

    // HIST-03: FTS5-Suche liefert Ergebnis unter 200ms bei 1000 Einträgen
    @Test func testSearchPerformance() throws {
        let store = try makeStore()
        for i in 0..<1000 {
            let entry = HistoryEntry(
                id: nil,
                createdAt: Date().addingTimeInterval(TimeInterval(-i * 60)),
                originalText: "Eintrag Nummer \(i) mit verschiedenem Inhalt",
                llmText: i % 2 == 0 ? "LLM Text \(i)" : nil,
                profileName: nil,
                isLLMProcessed: i % 2 == 0
            )
            try store.insert(entry)
        }
        let start = Date()
        let results = try store.search(query: "Inhalt")
        let elapsed = Date().timeIntervalSince(start)
        #expect(results.count > 0)
        #expect(elapsed < 0.2, "FTS5-Suche dauerte \(elapsed)s — Limit: 200ms")
    }

    // HIST-04: copyText liefert LLM-Text wenn vorhanden, sonst Original (D-09)
    @Test func testCopyPreference() throws {
        let withLLM = HistoryEntry(
            id: nil, createdAt: Date(),
            originalText: "Original", llmText: "LLM",
            profileName: nil, isLLMProcessed: true
        )
        #expect(withLLM.copyText == "LLM")

        let withoutLLM = HistoryEntry(
            id: nil, createdAt: Date(),
            originalText: "Original", llmText: nil,
            profileName: nil, isLLMProcessed: false
        )
        #expect(withoutLLM.copyText == "Original")
    }
}
