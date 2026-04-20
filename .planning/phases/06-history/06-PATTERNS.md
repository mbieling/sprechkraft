# Phase 6: History — Pattern Map

**Mapped:** 2026-04-20
**Files analyzed:** 7 neue/modifizierte Dateien
**Analogs found:** 7 / 7

---

## File Classification

| Neue/Modifizierte Datei | Role | Data Flow | Nächstes Analog | Match-Qualität |
|-------------------------|------|-----------|-----------------|----------------|
| `VoiceScribe/History/HistoryEntry.swift` | model | CRUD | `VoiceScribe/Models/PromptProfile.swift` | role-match |
| `VoiceScribe/History/HistoryStore.swift` | service | CRUD | `VoiceScribe/Services/GroqService.swift` | role-match |
| `VoiceScribe/History/HistoryView.swift` | component | request-response | `VoiceScribe/SettingsView.swift` | role-match |
| `VoiceScribe/AppDelegate.swift` | controller | event-driven | selbst (onRecordingComplete-Erweiterung) | exact |
| `VoiceScribe/VoiceScribeApp.swift` | config | request-response | selbst (zweites Window analog „settings") | exact |
| `VoiceScribe.xcodeproj/project.pbxproj` | config | — | KeychainAccess-Block KC050500/KC050501 | exact |
| `VoiceScribeTests/HistoryStoreTests.swift` | test | CRUD | (kein Test-Analog vorhanden) | kein Analog |

---

## Pattern Assignments

### `VoiceScribe/History/HistoryEntry.swift` (model, CRUD)

**Analog:** `VoiceScribe/Models/PromptProfile.swift`

**Imports pattern** (PromptProfile.swift Zeilen 1–10):
```swift
// VoiceScribe/Models/PromptProfile.swift
import Foundation
import Defaults
```
Für HistoryEntry: `Defaults` ersetzen durch `GRDB`.

**Core struct pattern** (PromptProfile.swift Zeilen 11–31):
```swift
struct PromptProfile: Codable, Defaults.Serializable, Identifiable {
    var id: UUID
    var name: String
    // ...
    static var defaultProfile: PromptProfile { ... }
}
```
HistoryEntry folgt demselben Struct-Muster, tauscht `Defaults.Serializable` gegen `FetchableRecord, PersistableRecord` aus und verwendet `Int64?` statt `UUID` als ID (GRDB-Convention für autoIncrementedPrimaryKey).

**Konkrete Zielstruktur** (aus RESEARCH.md Pattern 2):
```swift
struct HistoryEntry: Codable, Identifiable, Sendable {
    var id: Int64?
    var createdAt: Date
    var originalText: String
    var llmText: String?
    var profileName: String?
    var isLLMProcessed: Bool

    // D-09: Welcher Text wird kopiert
    var copyText: String { llmText ?? originalText }

    // D-03: ~80-Zeichen-Vorschau
    var preview: String {
        let base = copyText
        guard base.count > 80 else { return base }
        return String(base.prefix(80)) + "…"
    }
}

extension HistoryEntry: FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "transcription_entries" }
    enum CodingKeys: String, CodingKey {
        case id
        case originalText = "original_text"
        case llmText = "llm_text"
        case profileName = "profile_name"
        case isLLMProcessed = "is_llm_processed"
        case createdAt = "created_at"
    }
}
```

**Swift-6-Constraint:** `struct` (nicht `class`) ist Pflicht — GRDB v7 erzwingt `Sendable` für Record-Typen in async-Kontexten. `PromptProfile` ist ebenfalls `struct`.

---

### `VoiceScribe/History/HistoryStore.swift` (service, CRUD)

**Analog:** `VoiceScribe/Services/GroqService.swift`

**Singleton-Pattern** (GroqService.swift Zeilen 12–13):
```swift
actor GroqService {
    static let shared = GroqService()
```
HistoryStore ersetzt `actor` durch `@MainActor final class` — SwiftUI-Properties und alle Aufrufer laufen auf dem Main Thread; GRDB DatabaseQueue ist `Sendable`, der Wrapper muss isoliert sein.

**Imports pattern** (GroqService.swift Zeilen 1–8 als Vorlage, angepasst):
```swift
import Foundation
import GRDB
```

**Init + DatabaseQueue-Setup** (RESEARCH.md Pattern 1):
```swift
@MainActor
final class HistoryStore {
    static let shared = HistoryStore()
    private let dbQueue: DatabaseQueue

    private init() {
        let fileManager = FileManager.default
        let appSupport = try! fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        let dir = appSupport.appendingPathComponent("VoiceScribe", isDirectory: true)
        try! fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("history.sqlite")
        dbQueue = try! DatabaseQueue(path: dbURL.path)
        try! migrate()
    }
```

**Migrations-Pattern** (RESEARCH.md Pattern 1, Zeilen 213–235):
```swift
    private func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_transcription_entries") { db in
            // D-13: Haupt-Tabelle
            try db.create(table: "transcription_entries") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("created_at", .datetime).notNull()
                t.column("original_text", .text).notNull()
                t.column("llm_text", .text)
                t.column("profile_name", .text)
                t.column("is_llm_processed", .boolean).notNull()
            }
            // D-14: FTS5-Virtual-Table mit automatischer Synchronisation
            try db.create(virtualTable: "transcription_entries_fts", using: FTS5()) { t in
                t.synchronize(withTable: "transcription_entries")
                t.tokenizer = .unicode61()
                t.column("original_text")
                t.column("llm_text")
            }
        }
        try migrator.migrate(dbQueue)
    }
```

**CRUD-Methoden** (Muster aus RESEARCH.md Pattern 3 + 5):
```swift
    func insert(_ entry: HistoryEntry) throws {
        try dbQueue.write { db in
            try entry.insert(db)
        }
    }

    func delete(_ entry: HistoryEntry) throws {
        try dbQueue.write { db in
            try entry.delete(db)
        }
    }

    func deleteAll() throws {
        try dbQueue.write { db in
            try HistoryEntry.deleteAll(db)
        }
    }

    func search(query: String) throws -> [HistoryEntry] {
        try dbQueue.read { db in
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                return try HistoryEntry.order(Column("created_at").desc).fetchAll(db)
            }
            guard let pattern = FTS5Pattern(matchingAllTokensIn: query) else {
                return []  // Pitfall 6: nil ist sicherer Fallback, kein Crash
            }
            // Explizite SQL-Variante für content-table Setup (RESEARCH.md Pattern 3):
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

    func observeAll() -> AsyncThrowingStream<[HistoryEntry], Error> {
        ValueObservation
            .tracking { db in try HistoryEntry.order(Column("created_at").desc).fetchAll(db) }
            .values(in: dbQueue)
    }
```

**In-Memory-Variante für Tests** (Validation Architecture aus RESEARCH.md):
```swift
    // Nur für Tests — kein Dateisystem-Zustand
    init(inMemory: Bool) throws {
        dbQueue = try DatabaseQueue()  // ohne Pfad = In-Memory
        try migrate()
    }
```

---

### `VoiceScribe/History/HistoryView.swift` (component, request-response)

**Analog:** `VoiceScribe/SettingsView.swift`

**Imports pattern** (SettingsView.swift Zeilen 1–15):
```swift
import SwiftUI
import AppKit  // für NSPasteboard
```

**State-Deklarationen** (SettingsView.swift Zeilen 21–34 als Vorlage):
```swift
// SettingsView-Muster: @State für lokalen View-State
@State private var availableMics: [AVCaptureDevice] = []

// Analog für HistoryView:
@State private var searchText: String = ""
@State private var entries: [HistoryEntry] = []
@State private var flashingEntryID: Int64? = nil
@State private var showClearConfirm: Bool = false
@State private var debounceTask: Task<Void, Never>? = nil
private let historyStore = HistoryStore.shared
```

**onAppear-Muster** (SettingsView.swift Zeilen 255–260):
```swift
.onAppear {
    availableMics = AudioDeviceManager.availableMicrophones()
    groqApiKeyInput = keychain["groqApiKey"] ?? ""
}

// Analog für HistoryView — task(id:) statt onAppear für Observation (Pitfall 7):
.task {
    for try await updated in historyStore.observeAll() {
        entries = updated
    }
}
```

**List mit Section-Pattern** (SettingsView.swift Zeilen 216–233 als Vorlage):
```swift
// SettingsView: ForEach in Section
ForEach(Defaults[.profiles]) { profile in
    HStack { ... }
        .onTapGesture { editingProfile = profile }
}

// Analog für HistoryView (RESEARCH.md Pattern 7 + Code Examples):
List {
    ForEach(groupedEntries, id: \.0) { (sectionTitle, sectionEntries) in
        Section(sectionTitle) {
            ForEach(sectionEntries) { entry in
                HistoryRowView(entry: entry, isFlashing: flashingEntryID == entry.id)
                    .onTapGesture { copyEntry(entry) }
                    .contextMenu {
                        Button("Eintrag löschen", role: .destructive) {
                            try? historyStore.delete(entry)
                        }
                    }
            }
        }
    }
}
.listStyle(.inset)
```

**Alert-Pattern** (SettingsView.swift Zeilen 261–299 als Vorlage für Sheet/Alert):
```swift
// D-12: Confirm-Dialog (RESEARCH.md Code Examples):
.alert("Verlauf leeren?", isPresented: $showClearConfirm) {
    Button("Löschen", role: .destructive) {
        try? historyStore.deleteAll()
    }
    Button("Abbrechen", role: .cancel) {}
} message: {
    Text("Alle Einträge werden unwiderruflich gelöscht.")
}
```

**Debounce-Pattern** (RESEARCH.md Pattern 4):
```swift
// D-06: Task.sleep-Debounce ohne Combine
.onChange(of: searchText) { _, newValue in
    debounceTask?.cancel()
    debounceTask = Task {
        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled else { return }
        entries = (try? historyStore.search(query: newValue)) ?? []
    }
}
```

**Grün-Blink-Feedback** (RESEARCH.md Pattern 8):
```swift
// In HistoryRowView: Hintergrundfarbe via isFlashing-Parameter
.background(isFlashing ? Color.green.opacity(0.3) : Color.clear)
.animation(.easeOut(duration: 0.4), value: isFlashing)

// copyEntry()-Funktion in HistoryView:
func copyEntry(_ entry: HistoryEntry) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(entry.copyText, forType: .string)
    flashingEntryID = entry.id
    Task {
        try? await Task.sleep(for: .milliseconds(400))
        flashingEntryID = nil
    }
}
```

**Datum-Gruppierung** (RESEARCH.md Pattern 7):
```swift
private var groupedEntries: [(String, [HistoryEntry])] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
    let grouped = Dictionary(grouping: entries) { entry -> String in
        let day = calendar.startOfDay(for: entry.createdAt)
        if calendar.isDateInToday(day) { return "HEUTE" }
        if calendar.isDateInYesterday(day) { return "GESTERN" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: day)
    }
    // Neueste Sektion zuerst — entries ist bereits nach created_at DESC sortiert
    return grouped.sorted { a, b in
        let dateA = entries.first(where: { calendar.startOfDay(for: $0.createdAt) == ... })?.createdAt ?? .distantPast
        let dateB = ...
        return dateA > dateB
    }
}
```
Hinweis: Die Sortierung der Sektionen orientiert sich am ersten Eintrag je Gruppe (neueste `created_at` pro Tag). Exakte Implementierung: ersten Eintrag der Gruppe suchen, da `entries` bereits `ORDER BY created_at DESC` sortiert ist.

**DesignTokens-Nutzung** (SettingsView.swift Zeilen 43, 67, 254):
```swift
// Abstände aus DesignTokens.Spacing — konsistent mit SettingsView
.padding(DesignTokens.Spacing.md)   // 16pt Zeilenabstand
.padding(DesignTokens.Spacing.xl)   // 32pt Fensterkanten
```

**LLM-Badge „KI"** (AppState.swift Zeile 16 — systemPurple analog llmProcessing):
```swift
// Farbe: systemPurple — konsistent mit RecordingState.llmProcessing.color
Text("KI")
    .font(.system(size: 10, weight: .semibold))
    .foregroundStyle(.white)
    .padding(.horizontal, DesignTokens.Spacing.xs)  // 4pt
    .padding(.vertical, DesignTokens.Spacing.xs)    // 4pt (UI-SPEC Korrektur: xs nicht 2pt)
    .background(Color(.systemPurple))
    .clipShape(Capsule())
```

---

### `VoiceScribe/AppDelegate.swift` — Modifikation (controller, event-driven)

**Analog:** AppDelegate.swift selbst — Erweiterung des bestehenden Musters

**Notification.Name-Extension** (AppDelegate.swift Zeilen 18–22):
```swift
extension Notification.Name {
    static let openSettings = Notification.Name("com.voicescribe.openSettings")
    static let refreshProfileHotkeys = Notification.Name("com.voicescribe.refreshProfileHotkeys")
}
// Neues Eintrag analog:
    static let openHistory = Notification.Name("com.voicescribe.openHistory")
```

**Neuer NSMenuItem in showMenu()** (AppDelegate.swift Zeilen 213–300 — genau vor „Einstellungen…"):
```swift
// Analog zu settingsItem (Zeilen 223–230):
let historyItem = NSMenuItem(
    title: "Verlauf…",
    action: #selector(openHistoryMenu),
    keyEquivalent: ""
)
historyItem.target = self
menu.addItem(historyItem)
// Danach kommt das existierende settingsItem
```

**@objc Menu-Action** (AppDelegate.swift Zeile 304–309 als Vorlage):
```swift
@objc private func openSettingsMenu() {
    NotificationCenter.default.post(name: .openSettings, object: nil)
}
// Analog:
@objc private func openHistoryMenu() {
    NotificationCenter.default.post(name: .openHistory, object: nil)
}
```

**GRDB-Insert in onRecordingComplete** (AppDelegate.swift Zeilen 94–159 — Einfügestelle):

Insert nach `TextOutputService.shared.output(...)` einfügen, sowohl im LLM-Pfad (Zeile 146) als auch im Direkt-Pfad (Zeile 153). Muster aus RESEARCH.md Code Examples:
```swift
// Nach TextOutputService.shared.output(outputText, ...) im LLM-Pfad:
let entry = HistoryEntry(
    id: nil,
    createdAt: Date(),
    originalText: text,
    llmText: outputText != text ? outputText : nil,  // nil wenn Fallback = Original
    profileName: activeProfile?.name,
    isLLMProcessed: true
)
try? HistoryStore.shared.insert(entry)  // try? — Insert-Fehler darf Transkription nicht blockieren

// Nach TextOutputService.shared.output(text, ...) im Direkt-Pfad:
let entry = HistoryEntry(
    id: nil,
    createdAt: Date(),
    originalText: text,
    llmText: nil,
    profileName: activeProfile?.name,
    isLLMProcessed: false
)
try? HistoryStore.shared.insert(entry)
```

---

### `VoiceScribe/VoiceScribeApp.swift` — Modifikation (config, request-response)

**Analog:** VoiceScribeApp.swift selbst — zweites Window analog dem bestehenden „settings"-Window

**Window-Scene-Muster** (VoiceScribeApp.swift Zeilen 25–30):
```swift
Window("VoiceScribe — Einstellungen", id: "settings") {
    SettingsView(appState: appState)
        .frame(minWidth: 400, minHeight: 300)
}
.windowResizability(.contentSize)
```
Analog für History:
```swift
Window("VoiceScribe — Verlauf", id: "history") {
    HistoryView()
        .frame(minWidth: 600, minHeight: 400)  // Claude's Discretion: ~600×400
}
.windowResizability(.contentSize)
```

**HiddenActivationView — onReceive-Erweiterung** (VoiceScribeApp.swift Zeilen 53–77):
```swift
// Bestehendes openSettings-Pattern (Zeilen 53–77) 1:1 kopieren für openHistory:
.onReceive(NotificationCenter.default.publisher(for: .openHistory)) { _ in
    Task { @MainActor in
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "history")
        if let win = NSApp.windows.first(where: {
            $0.identifier?.rawValue == "history"
        }) {
            win.makeKeyAndOrderFront(nil)
        }
        try? await Task.sleep(for: .milliseconds(300))
        NSApp.setActivationPolicy(.accessory)
    }
}
```
Dieses Pattern ist aus Phase 1 und Phase 5 bekannt und bewährt (RESEARCH.md Pitfall 4 bestätigt).

---

### `VoiceScribe.xcodeproj/project.pbxproj` — Modifikation (config, —)

**Analog:** KeychainAccess-Block KC050500/KC050501 (project.pbxproj Zeilen 623–658)

**Drei Pflichtstellen** (exaktes Muster aus Codebase — RESEARCH.md Pitfall 1):

**Stelle 1: XCRemoteSwiftPackageReference** (Zeilen 623–630 — nach KC050500 einfügen):
```
GR060600 /* XCRemoteSwiftPackageReference "GRDB.swift" */ = {
    isa = XCRemoteSwiftPackageReference;
    repositoryURL = "https://github.com/groue/GRDB.swift";
    requirement = {
        kind = upToNextMajorVersion;
        minimumVersion = 7.5.0;
    };
};
```

**Stelle 2: packageReferences in PBXProject** (Zeilen 283–288 — in der Liste nach KC050500):
```
GR060600 /* XCRemoteSwiftPackageReference "GRDB.swift" */,
```

**Stelle 3: packageProductDependencies im Target** (Zeilen 226–231 — nach KC050501):
```
GR060601 /* GRDB */,
```
Und entsprechend XCSwiftPackageProductDependency:
```
GR060601 /* GRDB */ = {
    isa = XCSwiftPackageProductDependency;
    package = GR060600 /* XCRemoteSwiftPackageReference "GRDB.swift" */;
    productName = GRDB;
};
```

---

### `VoiceScribeTests/HistoryStoreTests.swift` (test, CRUD)

**Analog:** kein Test-Analog im Projekt vorhanden. Muster aus RESEARCH.md Validation Architecture.

**In-Memory-Setup für Tests:**
```swift
import Testing
@testable import VoiceScribe
import GRDB

@MainActor
struct HistoryStoreTests {
    // In-Memory-Store für jeden Test (kein Filesystem-Zustand)
    let store = try! HistoryStore(inMemory: true)

    @Test func testInsertPersists() throws {
        let entry = HistoryEntry(id: nil, createdAt: Date(),
            originalText: "Test", llmText: nil,
            profileName: nil, isLLMProcessed: false)
        try store.insert(entry)
        let all = try store.search(query: "")
        #expect(all.count == 1)
        #expect(all.first?.originalText == "Test")
    }

    @Test func testFTS5SearchFindsMatch() throws { ... }
    @Test func testBothTextsStored() throws { ... }
    @Test func testCopyPreference() throws { ... }  // LLM-Text hat Vorrang (D-09)
}
```

---

## Shared Patterns

### Shared Pattern 1: @MainActor Singleton
**Quelle:** `VoiceScribe/AppState.swift` Zeilen 58–60, `VoiceScribe/Services/GroqService.swift` Zeilen 12–13
**Gilt für:** `HistoryStore.swift`
```swift
@MainActor
final class HistoryStore {
    static let shared = HistoryStore()
    private init() { ... }
}
```

### Shared Pattern 2: NotificationCenter-Brücke (AppDelegate → VoiceScribeApp)
**Quelle:** `VoiceScribe/AppDelegate.swift` Zeilen 18–22, 304–309; `VoiceScribe/VoiceScribeApp.swift` Zeilen 53–77
**Gilt für:** `AppDelegate.swift` (openHistoryMenu), `VoiceScribeApp.swift` (onReceive openHistory)
```swift
// AppDelegate: post
NotificationCenter.default.post(name: .openHistory, object: nil)
// VoiceScribeApp HiddenActivationView: receive
.onReceive(NotificationCenter.default.publisher(for: .openHistory)) { _ in ... }
```

### Shared Pattern 3: Activation-Policy-Workaround
**Quelle:** `VoiceScribe/VoiceScribeApp.swift` Zeilen 55–76
**Gilt für:** `VoiceScribeApp.swift` — History-Window-Aktivierung
```swift
NSApp.setActivationPolicy(.regular)
NSApp.activate(ignoringOtherApps: true)
openWindow(id: "history")
// ... makeKeyAndOrderFront ...
try? await Task.sleep(for: .milliseconds(300))
NSApp.setActivationPolicy(.accessory)
```

### Shared Pattern 4: try? für nicht-kritische Operationen
**Quelle:** `VoiceScribe/AppDelegate.swift` Zeilen 97 (`try await`), 171 (kein try — Fehler wird catch-gehandelt)
**Gilt für:** GRDB-Insert in AppDelegate (Insert-Fehler darf Transkription nicht blockieren)
```swift
try? HistoryStore.shared.insert(entry)  // Fehler still schlucken ist gewollt (RESEARCH.md Open Questions #2)
```

### Shared Pattern 5: DesignTokens.Spacing
**Quelle:** `VoiceScribe/Constants/DesignTokens.swift` Zeilen 13–24
**Gilt für:** `HistoryView.swift` — alle Abstände
```swift
DesignTokens.Spacing.xs  // 4pt — Badge-Padding
DesignTokens.Spacing.sm  // 8pt — Zeilen-Padding
DesignTokens.Spacing.md  // 16pt — Sektions-Abstände
DesignTokens.Spacing.xl  // 32pt — Fensterkanten
```

### Shared Pattern 6: systemPurple für LLM-Badge
**Quelle:** `VoiceScribe/AppState.swift` Zeile 23 (`Color(.systemPurple)` für `.llmProcessing`)
**Gilt für:** `HistoryView.swift` — KI-Badge auf Listenzeilen mit `isLLMProcessed == true`

---

## Kein Analog gefunden

| Datei | Role | Data Flow | Grund |
|-------|------|-----------|-------|
| `VoiceScribeTests/HistoryStoreTests.swift` | test | CRUD | Keine Tests im Projekt vorhanden; Muster aus RESEARCH.md Validation Architecture |

---

## Metadata

**Analog-Suchscope:** `VoiceScribe/`, `VoiceScribeTests/`, `VoiceScribe.xcodeproj/project.pbxproj`
**Gescannte Dateien:** 9 (AppDelegate, VoiceScribeApp, SettingsView, AppState, PromptProfile, GroqService, Defaults+Keys, DesignTokens, project.pbxproj)
**Pattern-Extraction-Datum:** 2026-04-20
