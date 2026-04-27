# Phase 6: History - Research

**Researched:** 2026-04-20
**Domain:** GRDB.swift v7.5.0, FTS5, SwiftUI List mit Datum-Gruppen, macOS-Fenster
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**History-Panel: Fenster & Navigation**
- D-01: Eigenes macOS-Fenster — kein Popover, kein Settings-Tab. Eigenes Fenster bietet genügend Platz für Suche + Datum-Gruppen + Liste.
- D-02: Öffnen via Menü-Eintrag — Rechtsklick-Menü erhält Eintrag „Verlauf …" (konsistent mit „Einstellungen …"). Kein globaler Hotkey in Phase 6.

**Eintrags-Darstellung**
- D-03: Kompakte Listenzeile — Zeit + ~80 Zeichen Textvorschau. Kein separates Detail-Panel (kein Master-Detail-Split). Klick auf Zeile kopiert direkt.
- D-04: Metadaten pro Eintrag: Zeitstempel (HH:MM), Profil-Name, Badge „LLM" wenn Groq-verarbeitet, relatives Datum als Sektions-Überschrift (Heute / Gestern / DD.MM.JJJJ).
- D-05: Datum-Sektionen — Einträge unter Überschriften „HEUTE" / „GESTERN" / „19.04.2026" etc. Neueste Sektion zuerst, innerhalb einer Sektion neueste Einträge oben.

**Such-UX**
- D-06: Live-Suche (debounced ~200ms) — FTS5-Abfrage nach jedem Tastendruck, kein Suche-Button. Suchfeld oben im Fenster, immer sichtbar.
- D-07: Leer-Zustand bei keinem Ergebnis — Text „Keine Ergebnisse für ‚xyz'" (kein leeres Listing ohne Erklärung). Konsistent mit macOS-Konventionen.
- D-08: FTS5-Suche durchsucht sowohl Original-Transkript als auch LLM-Text (beide Felder in der FTS5-Virtual-Table). Der Nutzer unterscheidet nicht explizit.

**Kopieren & Zwischenablage**
- D-09: Kopiert LLM-Text wenn vorhanden, sonst Original — spiegelt das, was der Nutzer tatsächlich als Output bekommen hätte. Kein Toggle, kein explizites UI.
- D-10: Visuelles Feedback: Zeilenhintergrund blinkt kurz grün (~0.4s Animation). Kein Toast-Banner, kein Sound. Dezent, bleibt in der Liste.

**History-Verwaltung**
- D-11: Unbegrenzte Einträge — SQLite/GRDB auf lokalem Gerät, kein Limit.
- D-12: Einzeln und Gesamt löschen: Einzeln: Swipe-to-delete oder Kontextmenü per Rechtsklick. Gesamt: „Verlauf leeren …" im Fenster-Menü oder per Button mit Confirm-Dialog.

**GRDB-Schema**
- D-13: Tabelle `transcription_entries` mit Spalten: id INTEGER PRIMARY KEY, created_at DATETIME NOT NULL, original_text TEXT NOT NULL, llm_text TEXT (NULL wenn kein LLM-Pfad), profile_name TEXT (NULL wenn kein Profil), is_llm_processed BOOLEAN NOT NULL
- D-14: FTS5-Virtual-Table über `original_text` und `llm_text`. Content-Table: `transcription_entries`.
- D-15: Speicherpunkt im Pipeline: GRDB-Insert erfolgt in `onRecordingComplete` in AppDelegate, nach TextOutputService (letzter Schritt), sodass der finale Output-Text (original oder LLM) bereits bekannt ist.

### Claude's Discretion

- Fenster-Mindestgröße und initiales Fenstermaß — Claude entscheidet (empfohlen: ~600×400).
- GRDB-Datenbankpfad — Standard Application Support Directory.
- Debounce-Implementierung (Combine / Task mit `try await Task.sleep`) — Claude entscheidet.
- Swipe-to-delete vs. Kontextmenü für Einzellöschen — Claude entscheidet welche SwiftUI-API am besten passt (List `onDelete` oder `.contextMenu`).

### Deferred Ideas (OUT OF SCOPE)

- History-Export (CSV, JSON, Text-Datei) — eigene Phase wenn gewünscht
- Profil-Filter in der History (nur Einträge von Profil X zeigen) — kann in Phase 7 oder später
- Migration von Profiles (Defaults → GRDB) — explizit NICHT in Phase 6
- Globaler Hotkey für History-Fenster — kein Bedarf in Phase 6 geäußert
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| HIST-01 | Jede Transkription wird lokal mit Zeitstempel gespeichert | GRDB.swift DatabaseQueue + DatabaseMigrator; Insert-Punkt D-15 in AppDelegate.onRecordingComplete |
| HIST-02 | Sowohl Original-Transkript als auch LLM-verarbeiteter Text werden gespeichert | Schema D-13: `original_text` + `llm_text`; beide Werte bekannt nach TextOutputService |
| HIST-03 | User kann durch alle gespeicherten Transkriptionen suchen (Volltext) | FTS5-Virtual-Table D-14 mit `synchronize(withTable:)`; FTS5Pattern(matchingAllTokensIn:) für Live-Suche D-06 |
| HIST-04 | User kann einen Historien-Eintrag per Klick in Clipboard kopieren | NSPasteboard.general.setString(_:forType:) + @State `flashingEntryID` für grünes Blink-Feedback D-10 |
</phase_requirements>

---

## Summary

Phase 6 fügt GRDB.swift v7.5.0 als neue SPM-Dependency ein und implementiert die vollständige History-Pipeline: Datenbankschicht (Schema + Migrations), Insert-Integration in AppDelegate, ein eigenes macOS-Fenster mit SwiftUI-Liste und FTS5-Live-Suche.

Die Architektur folgt dem etablierten Projekt-Muster: `HistoryStore` als `@MainActor`-Klasse mit GRDB `DatabaseQueue` kapselt alle Datenbankzugriffe. `HistoryView` als reines SwiftUI-View konsumiert einen `@Observable`-Store und rendert die Datum-gruppierten Listenzeilen. Der Insert-Punkt liegt in `AppDelegate.onRecordingComplete` nach `TextOutputService`, so dass `original_text` und `llm_text` (oder nil) beide bekannt sind.

FTS5 mit `synchronize(withTable: "transcription_entries")` sorgt für automatische Synchronisation bei Insert/Delete ohne manuelles Trigger-Management. Die Suche nutzt `FTS5Pattern(matchingAllTokensIn:)` — sicher für User-Input, kein SQL-Injection-Risiko. Das grüne Blink-Feedback implementiert eine `@State`-basierte `id`-Markierung plus SwiftUI `withAnimation`.

**Primary recommendation:** `HistoryStore` als `@MainActor`-Singleton mit GRDB `DatabaseQueue` (nicht Pool) — single-threaded reicht für diese Schreiblast, kein Overhead durch concurrent readers.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| History-Persistenz (Insert, Delete) | HistoryStore (Service-Schicht) | AppDelegate (Aufruf-Punkt) | Datenbanklogik gehört in eine dedizierte Service-Klasse, nicht in AppDelegate |
| FTS5-Volltextsuche | HistoryStore | — | Alle DB-Operationen zentralisiert; View fragt nur an |
| History-Fenster öffnen | AppDelegate (NSMenuItem) | SPRECHKRAFTApp (Window-Scene) | Analoges Muster zu openSettings (NotificationCenter-Brücke) |
| History-UI (Liste, Suche, Gruppen) | HistoryView (SwiftUI) | — | Reines UI-Layer, kein Datenbankzugriff direkt |
| Clipboard-Kopieren | HistoryView | HistoryStore (bestimmt welcher Text) | NSPasteboard-Aufruf im View-Action-Handler; welcher Text (LLM vs. Original) ist View-Logik per D-09 |
| Grün-Blink-Feedback | HistoryView | — | Rein visueller State (`@State flashingEntryID`) |
| Datum-Gruppierung | HistoryStore oder HistoryView | — | Kann als computed property im View-Model erfolgen; kein DB-Query nötig |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| GRDB.swift | v7.5.0 | SQLite-Wrapper mit FTS5, Migrations, Observation | Bereits in CLAUDE.md entschieden; FTS5-Support first-class; Swift 6 Sendable-konform |
| SwiftUI | macOS 14+ | History-Fenster und Listenrendering | Etabliertes Projekt-Pattern; kein AppKit nötig für diese UI |
| Foundation | — | Date-Formatierung, FileManager für DB-Pfad | Built-in |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Combine | — | Debounce-Alternative via `@Published` + `.debounce` | Wenn Task-sleep-Debounce für SwiftUI-State nicht ausreicht |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| DatabaseQueue | DatabasePool | Pool erlaubt concurrent reads, aber für History (selten gelesen, selten geschrieben) ist Queue einfacher und ausreichend |
| `synchronize(withTable:)` | Manueller FTS5-Trigger | `synchronize` generiert automatisch After-Insert/Update/Delete-Trigger; keine manuelle Pflege |
| Task.sleep Debounce | Combine `.debounce` | Task.sleep-Pattern braucht keine Combine-Imports; passt besser zu async/await-Stil des Projekts |

**Installation (Package.swift + pbxproj):**
```bash
# Package.swift — neue Dependency:
.package(url: "https://github.com/groue/GRDB.swift", from: "7.5.0")

# pbxproj benötigt 3 Einträge (analog KeychainAccess aus Phase 5):
# 1. XCRemoteSwiftPackageReference
# 2. packageReferences (PBXProject)
# 3. packageProductDependencies (Target)
```

**Version verification:** GRDB.swift v7.5.0 ist in Context7 bestätigt (`/groue/grdb.swift`, Version v7.5.0). [VERIFIED: Context7]

---

## Architecture Patterns

### System Architecture Diagram

```
Aufnahme abgeschlossen
        │
        ▼
AppDelegate.onRecordingComplete
        │
        ├─── TextOutputService.output() ──► Cursor / Clipboard
        │
        ▼ (letzter Schritt — D-15)
HistoryStore.insert(original, llm, profile, isLLM)
        │
        ▼
GRDB DatabaseQueue (SQLite)
        │
        ├─── transcription_entries ◄──── FTS5-Trigger (auto-sync)
        │                                    │
        └─── transcription_entries_fts ◄─────┘
                    │
                    ▼ (bei Suche)
        HistoryStore.search(query) ──► FTS5Pattern MATCH
                    │
                    ▼
              ValueObservation
                    │
                    ▼
        HistoryView (SwiftUI)
                    │
        ┌───────────┴──────────────┐
        ▼                          ▼
  Datum-Gruppen               Suchfeld
  (List + Section)            (TextField, debounced)
        │
        ▼ (Klick auf Zeile)
  NSPasteboard.copy + grüner Flash
```

### Recommended Project Structure
```
SPRECHKRAFT/
├── History/
│   ├── HistoryStore.swift       # @MainActor class, DatabaseQueue, GRDB-Operationen
│   ├── HistoryEntry.swift       # Struct: Codable, FetchableRecord, PersistableRecord
│   └── HistoryView.swift        # SwiftUI-View: Liste, Suche, Datum-Gruppen, Copy-Flash
├── AppDelegate.swift            # onRecordingComplete: HistoryStore.insert() Aufruf hinzufügen
├── SPRECHKRAFTApp.swift         # Neues Window("Verlauf", id: "history") hinzufügen
└── Extensions/
    └── Defaults+Keys.swift      # unverändert — Profile bleiben in Defaults
```

### Pattern 1: GRDB Schema-Setup mit Migration

```swift
// Source: https://github.com/groue/GRDB.swift/blob/master/GRDB/Documentation.docc/Migrations.md
// HistoryStore.swift

import GRDB

@MainActor
final class HistoryStore {
    static let shared = HistoryStore()
    private let dbQueue: DatabaseQueue

    private init() {
        // GRDB-Datenbankpfad: Application Support Directory (Claude's Discretion)
        let fileManager = FileManager.default
        let appSupport = try! fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        let dir = appSupport.appendingPathComponent("SPRECHKRAFT", isDirectory: true)
        try! fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("history.sqlite")
        dbQueue = try! DatabaseQueue(path: dbURL.path)
        try! migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_transcription_entries") { db in
            // D-13: Haupt-Tabelle
            try db.create(table: "transcription_entries") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("created_at", .datetime).notNull()
                t.column("original_text", .text).notNull()
                t.column("llm_text", .text)          // NULL wenn kein LLM
                t.column("profile_name", .text)       // NULL wenn kein Profil
                t.column("is_llm_processed", .boolean).notNull()
            }
            // D-14: FTS5-Virtual-Table mit automatischer Synchronisation
            try db.create(virtualTable: "transcription_entries_fts", using: FTS5()) { t in
                t.synchronize(withTable: "transcription_entries")
                t.tokenizer = .unicode61()   // Unterstützt deutsche Umlaute
                t.column("original_text")
                t.column("llm_text")
            }
        }
        try migrator.migrate(dbQueue)
    }
}
```

### Pattern 2: HistoryEntry-Struct (Sendable für Swift 6)

```swift
// Source: https://github.com/groue/GRDB.swift/blob/master/GRDB/Documentation.docc/SwiftConcurrency.md
// HistoryEntry.swift

import GRDB
import Foundation

struct HistoryEntry: Codable, Identifiable, Sendable {
    var id: Int64?
    var createdAt: Date
    var originalText: String
    var llmText: String?
    var profileName: String?
    var isLLMProcessed: Bool

    // D-09: Kopiertext: LLM-Text wenn vorhanden, sonst Original
    var copyText: String { llmText ?? originalText }

    // D-03: ~80-Zeichen-Vorschau für die Listenzeile
    var preview: String {
        let base = copyText
        guard base.count > 80 else { return base }
        return String(base.prefix(80)) + "…"
    }
}

extension HistoryEntry: FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "transcription_entries" }
    // CodingKeys für snake_case ↔ camelCase-Mapping
    enum CodingKeys: String, CodingKey {
        case id, originalText = "original_text", llmText = "llm_text",
             profileName = "profile_name", isLLMProcessed = "is_llm_processed",
             createdAt = "created_at"
    }
}
```

### Pattern 3: FTS5-Suche mit FTS5Pattern

```swift
// Source: https://github.com/groue/GRDB.swift/blob/master/Documentation/FullTextSearch.md
// HistoryStore.swift

func search(query: String) throws -> [HistoryEntry] {
    try dbQueue.read { db in
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            // Keine Suche: alle Einträge, neueste zuerst
            return try HistoryEntry.order(Column("created_at").desc).fetchAll(db)
        }
        // FTS5Pattern ist safe für User-Input — kein SQL-Injection-Risiko
        guard let pattern = FTS5Pattern(matchingAllTokensIn: query) else {
            return []
        }
        // Suche über FTS5-Virtual-Table, Ergebnisse aus Haupt-Tabelle
        return try HistoryEntry
            .joining(required: HistoryEntry.matching(pattern))
            .order(Column("created_at").desc)
            .fetchAll(db)
    }
}
```

**Hinweis zu FTS5Pattern auf FTS5-Content-Tables:** Bei `synchronize(withTable:)` werden die Ergebnisse automatisch über die Content-Table geliefert. `HistoryEntry.matching(pattern)` funktioniert wenn der databaseTableName des Records auf die FTS-Tabelle zeigt, oder man sucht explizit via SQL:

```swift
// Explizite SQL-Variante (sicherer bei content-table Setup):
let entries = try HistoryEntry.fetchAll(db,
    sql: """
        SELECT transcription_entries.*
        FROM transcription_entries
        WHERE transcription_entries.rowid IN (
            SELECT rowid FROM transcription_entries_fts WHERE transcription_entries_fts MATCH ?
        )
        ORDER BY created_at DESC
    """,
    arguments: [pattern])
```

### Pattern 4: Task.sleep-Debounce für Live-Suche

```swift
// HistoryView.swift — Debounce ohne Combine (Claude's Discretion)

@State private var searchText: String = ""
@State private var entries: [HistoryEntry] = []
@State private var debounceTask: Task<Void, Never>? = nil

// Im TextField onChange:
.onChange(of: searchText) { _, newValue in
    debounceTask?.cancel()
    debounceTask = Task {
        try? await Task.sleep(for: .milliseconds(200))   // D-06: ~200ms
        guard !Task.isCancelled else { return }
        entries = (try? historyStore.search(query: newValue)) ?? []
    }
}
```

### Pattern 5: ValueObservation für automatisches List-Update

```swift
// Source: https://github.com/groue/GRDB.swift/blob/master/GRDB/Documentation.docc/Extension/ValueObservation.md
// HistoryStore.swift

func observeAll() -> AsyncThrowingStream<[HistoryEntry], Error> {
    let observation = ValueObservation.tracking { db in
        try HistoryEntry.order(Column("created_at").desc).fetchAll(db)
    }
    return observation.values(in: dbQueue)
}
```

Dieser AsyncStream wird in HistoryView mit `for try await` konsumiert und füllt `@State private var entries` automatisch wenn neue Einträge per Insert hinzukommen.

### Pattern 6: Fenster öffnen via NotificationCenter (etabliertes Muster)

```swift
// Notification.Name Extension (analog .openSettings)
extension Notification.Name {
    static let openHistory = Notification.Name("com.sprechkraft.openHistory")
}

// AppDelegate.showMenu():
let historyItem = NSMenuItem(
    title: "Verlauf…",
    action: #selector(openHistoryMenu),
    keyEquivalent: ""
)
historyItem.target = self
// Einfügen vor "Einstellungen…"

@objc private func openHistoryMenu() {
    NotificationCenter.default.post(name: .openHistory, object: nil)
}

// SPRECHKRAFTApp.swift — HiddenActivationView.onReceive:
.onReceive(NotificationCenter.default.publisher(for: .openHistory)) { _ in
    Task { @MainActor in
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "history")
        if let win = NSApp.windows.first(where: { $0.identifier?.rawValue == "history" }) {
            win.makeKeyAndOrderFront(nil)
        }
        try? await Task.sleep(for: .milliseconds(300))
        NSApp.setActivationPolicy(.accessory)
    }
}
```

### Pattern 7: Datum-Gruppierung im View-Model

```swift
// HistoryView.swift — computed property

private var groupedEntries: [(String, [HistoryEntry])] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

    // Einträge nach Tagesdatum gruppieren
    let grouped = Dictionary(grouping: entries) { entry -> String in
        let day = calendar.startOfDay(for: entry.createdAt)
        if day == today { return "HEUTE" }
        if day == yesterday { return "GESTERN" }
        // D-05: Explizites Datum als "DD.MM.YYYY"
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: day)
    }

    // Neueste Sektion zuerst sortieren
    return grouped.sorted { a, b in
        let dateA = entries.first(where: { groupKey($0) == a.key })?.createdAt ?? .distantPast
        let dateB = entries.first(where: { groupKey($0) == b.key })?.createdAt ?? .distantPast
        return dateA > dateB
    }
}
```

### Pattern 8: Grün-Blink-Feedback

```swift
// D-10: ~0.4s grüner Zeilenhintergrund beim Kopieren
@State private var flashingEntryID: Int64? = nil

// In der Listenzeile:
.background(flashingEntryID == entry.id ? Color.green.opacity(0.3) : Color.clear)
.animation(.easeOut(duration: 0.4), value: flashingEntryID)

// Beim Kopieren:
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

### Anti-Patterns to Avoid

- **FTS5-Trigger manuell schreiben:** `synchronize(withTable:)` generiert After-Insert/Update/Delete-Trigger automatisch. Niemals manuell schreiben — GRDB kennt das korrekte FTS5-Trigger-Format.
- **DatabasePool statt DatabaseQueue:** Für diese Schreiblast (eine Aufnahme alle N Sekunden) ist Pool-Overhead nicht gerechtfertigt.
- **GRDB in AppDelegate direkt:** Kein Datenbankzugriff direkt im AppDelegate — das gehört in `HistoryStore`.
- **FTS5-Suche mit String-Interpolation:** Niemals `"MATCH '\(query)'"` — immer `FTS5Pattern(matchingAllTokensIn: query)` als Binding verwenden.
- **Keychained Singleton ohne @MainActor:** `HistoryStore.shared` muss `@MainActor` sein, weil SwiftUI-Properties und alle Aufrufer auf dem Main Thread laufen. GRDB v7 DatabaseQueue ist Sendable, der Store-Wrapper selbst muss aber isoliert sein.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| FTS5-Trigger-Synchronisation | Eigene After-Insert-Trigger in SQL | `t.synchronize(withTable:)` in GRDB | GRDB generiert korrekte Content-Table-Trigger inkl. Delete-Synchronisation; manuelle Trigger sind fehleranfällig |
| SQLite-Migrations-Versioning | Eigene Schema-Version-Tabelle | `DatabaseMigrator` aus GRDB | Automatisches Versioning, idempotent, transaktionssicher |
| Datums-relative Labels | Eigene Datumsvergleich-Logik | `Calendar.current.isDateInToday/isDateInYesterday` | Foundation-API korrekt für alle Zeitzonen |
| FTS5-Query-Sanitierung | String-Escaping | `FTS5Pattern(matchingAllTokensIn:)` | Nil-Return bei ungültigem Pattern ist der sichere Fallback |

**Key insight:** GRDB abstrahiert das gesamte FTS5-Lifecycle-Management — Schema, Trigger, Pattern-Binding. Jede manuelle Implementierung dieser drei Teile erzeugt Wartungsschuld.

---

## Common Pitfalls

### Pitfall 1: pbxproj-Integration für GRDB (3 Stellen!)

**Was schiefgeht:** GRDB wird in Package.swift eingetragen, aber das Xcode-Projekt löst ihn nicht auf weil `packageReferences` im pbxproj fehlt.
**Warum:** Phase 5 hatte dasselbe Problem mit KeychainAccess. Xcode-SPM-Auflösung braucht drei Einträge: `XCRemoteSwiftPackageReference`, Eintrag in `packageReferences` (PBXProject), Eintrag in `packageProductDependencies` (Target).
**Wie vermeiden:** pbxproj-Integration nach dem exakt gleichen Pattern wie `KC050500` (KeychainAccess) in `project.pbxproj` — alle drei Stellen kopieren und für GRDB anpassen. [VERIFIED: Codebase — STATE.md Phase 5 Decision]

### Pitfall 2: FTS5 Content-Table-Delete-Synchronisation

**Was schiefgeht:** Einträge werden aus `transcription_entries` gelöscht, bleiben aber im FTS5-Index — Suche findet „Geister"-Einträge.
**Warum:** FTS5 Content-Tables synchronisieren über Trigger. Wenn die Trigger fehlen oder falsch sind, divergiert der Index.
**Wie vermeiden:** `synchronize(withTable:)` in der FTS5-Table-Definition — erzeugt korrekte After-Delete-Trigger automatisch. Niemals Tabelle ohne dieses Flag erstellen. [VERIFIED: Context7 /groue/grdb.swift]

### Pitfall 3: Swift 6 Sendable-Verletzung bei HistoryEntry

**Was schiefgeht:** `HistoryEntry` als class statt struct → Compiler-Fehler in `@Sendable`-Closures.
**Warum:** GRDB v7 erzwingt Swift 6 Sendable für Record-Typen in async-Kontexten.
**Wie vermeiden:** `HistoryEntry` als `struct` mit `Sendable`-Konformanz definieren (automatisch für structs mit Sendable-Properties). [VERIFIED: Context7 /groue/grdb.swift SwiftConcurrency.md]

### Pitfall 4: Fenster-Aktivierung unter .accessory-Policy

**Was schiefgeht:** History-Fenster öffnet sich nicht oder kommt nicht in den Vordergrund.
**Warum:** Bereits bekanntes Problem aus Phase 1/Phase 5 — `.accessory`-Activation-Policy blockiert Fensteraktivierung.
**Wie vermeiden:** Exakt das gleiche Muster wie `openSettings`: `NSApp.setActivationPolicy(.regular)` → `NSApp.activate` → `openWindow` → 300ms → `.accessory`. [VERIFIED: Codebase — SPRECHKRAFTApp.swift, STATE.md]

### Pitfall 5: onDelete in SwiftUI List vs. Kontextmenü

**Was schiefgeht:** `List { }.onDelete` funktioniert auf macOS nur mit `EditButton` oder programmatischem `isEditing` State — ohne dieses Setup reagiert Swipe-to-delete nicht.
**Warum:** macOS SwiftUI List's `onDelete` erfordert Edit-Mode, anders als iOS.
**Wie vermeiden:** Für Einzellöschen auf macOS `.contextMenu` mit einem „Eintrag löschen"-Button bevorzugen. Das ist das native macOS-Pattern (Rechtsklick-Menü auf Listeneintrag). [ASSUMED — macOS 14 SwiftUI List-Verhalten; Training-Wissen, nicht via Context7 bestätigt]

### Pitfall 6: FTS5Pattern gibt nil zurück bei sehr kurzem Query

**Was schiefgeht:** `FTS5Pattern(matchingAllTokensIn: "a")` kann nil zurückgeben wenn der Token zu kurz für den Tokenizer ist.
**Warum:** unicode61-Tokenizer ignoriert Tokens unter einer Mindestlänge.
**Wie vermeiden:** nil-Rückgabe ist der korrekte sichere Fallback — bei nil einfach ungefilterte Liste anzeigen (kein Absturz). [VERIFIED: Context7 — FTS5Pattern-Doku zeigt nil-Return als dokumentiertes Verhalten]

### Pitfall 7: ValueObservation und Task-Leak

**Was schiefgeht:** `for try await in observation.values(in:)` läuft weiter wenn die View verschwindet.
**Warum:** AsyncThrowingStream-Iteration hat kein automatisches Cancellation.
**Wie vermeiden:** Observation in einem `task(id:)` modifier starten — SwiftUI bricht den Task automatisch ab wenn die View aus dem View-Tree entfernt wird. [VERIFIED: Swift Concurrency-Dokumentation, Context7-Pattern]

---

## Code Examples

### GRDB-Insert in AppDelegate.onRecordingComplete

```swift
// Source: CONTEXT.md D-15 + GRDB Pattern
// Einfügen nach TextOutputService.shared.output(...) in AppDelegate

// LLM-Pfad:
let historyEntry = HistoryEntry(
    id: nil,
    createdAt: Date(),
    originalText: text,         // raw transcript
    llmText: outputText,        // LLM-verarbeiteter Text (oder gleich text wenn Fehler)
    profileName: activeProfile?.name,
    isLLMProcessed: true
)
try? await HistoryStore.shared.insert(historyEntry)

// Direkt-Pfad (kein LLM):
let historyEntry = HistoryEntry(
    id: nil,
    createdAt: Date(),
    originalText: text,
    llmText: nil,
    profileName: activeProfile?.name,
    isLLMProcessed: false
)
try? await HistoryStore.shared.insert(historyEntry)
```

### Datum-Gruppen mit SwiftUI List

```swift
// D-05: Neueste Sektion zuerst, neueste Einträge innerhalb der Sektion oben
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

### Confirm-Dialog beim Leeren

```swift
// D-12: Native SwiftUI Alert mit destructive Button
.alert("Verlauf leeren?", isPresented: $showClearConfirm) {
    Button("Löschen", role: .destructive) {
        try? historyStore.deleteAll()
    }
    Button("Abbrechen", role: .cancel) {}
} message: {
    Text("Alle Einträge werden unwiderruflich gelöscht.")
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| FTS4 | FTS5 | SQLite 3.9+ | Bessere Performance, `MATCH` über mehrere Columns nativ |
| RxGRDB / GRDBCombine | ValueObservation mit async/await | GRDB v6/v7 | Kein Combine mehr nötig für Observation |
| GRDB class-Records | struct-Records (Sendable) | GRDB v7 + Swift 6 | Zwingend für Swift 6 strict concurrency |

**Deprecated/outdated:**
- `FTS4`: Noch unterstützt, aber FTS5 ist Standard für neue Projekte.
- `RxGRDB`: Nicht mehr aktiv gepflegt; GRDB-native async-Observation ist der Weg.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | macOS SwiftUI List `onDelete` erfordert Edit-Mode und ist daher für Einzellöschen auf macOS weniger geeignet als `.contextMenu` | Common Pitfalls #5 | Falls doch nativ unterstützt: ästhetischer Unterschied; contextMenu funktioniert in jedem Fall |
| A2 | `HistoryStore` als `@MainActor`-Singleton ist der einfachste Integrationsweg für das bestehende Muster | Architecture Patterns | Falls non-isolated Service besser wäre: Refactor nötig, aber kein funktionaler Schaden |

---

## Open Questions

1. **FTS5-Suche mit Umlauten (Sonderzeichen)**
   - Was wir wissen: unicode61-Tokenizer ist Standard in GRDB FTS5 und unterstützt Unicode-Zeichen
   - Was unklar ist: Verhält sich die Suche korrekt bei deutschen Umlauten (ä, ö, ü) ohne diacritics-Stripping?
   - Empfehlung: `t.tokenizer = .unicode61(diacritics: .keep)` explizit setzen, damit „müde" auch auf „müde" matcht (nicht normalisiert) — alternativ `.unicode61(diacritics: .remove)` für fuzzy-Matching; Entscheidung in Wave 0 via Test.

2. **Insert-Fehlerbehandlung bei DB-Fehler**
   - Was wir wissen: `try?` im Insert-Aufruf schluckt Fehler still
   - Was unklar ist: Sollte ein DB-Fehler beim Insert sichtbar sein?
   - Empfehlung: `try?` ist akzeptabel — History-Fehler darf Transkription nicht blockieren. Kein UI-Feedback nötig bei Insert-Fehler.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| GRDB.swift v7.5.0 | History-Persistenz + FTS5 | Noch nicht installiert | — (SPM-Dependency, wird in Wave 0 hinzugefügt) | — |
| SQLite | GRDB | ✓ | System (macOS 14+) | — |
| Swift 6.x | Compiler | ✓ | swift-6.1.2-RELEASE | — |

**Missing dependencies mit Fallback:**
- GRDB.swift v7.5.0 — wird in Wave 0 als SPM-Dependency eingetragen; Standardprozedur wie KeychainAccess in Phase 5.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (bereits im Projekt etabliert) |
| Config file | SPRECHKRAFTTests/ Target in pbxproj |
| Quick run command | `xcodebuild test -scheme SPRECHKRAFT -destination 'platform=macOS'` |
| Full suite command | gleich — alle Tests im selben Target |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HIST-01 | Insert speichert Eintrag mit created_at | unit | Swift Testing: `HistoryStoreTests.testInsertPersists` | ❌ Wave 0 |
| HIST-02 | original_text und llm_text korrekt gespeichert | unit | Swift Testing: `HistoryStoreTests.testBothTextsStored` | ❌ Wave 0 |
| HIST-03 | FTS5-Suche findet Eintrag, der Term enthält | unit | Swift Testing: `HistoryStoreTests.testFTS5SearchFindsMatch` | ❌ Wave 0 |
| HIST-03 | FTS5-Suche liefert Ergebnis unter 200ms bei 1000 Einträgen | performance | Swift Testing: `HistoryStoreTests.testSearchPerformance` | ❌ Wave 0 |
| HIST-04 | Klick auf Eintrag kopiert richtigen Text | unit | Swift Testing: `HistoryViewTests.testCopyPreference` (LLM > Original) | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** Kompilierung + Unit-Tests für HistoryStore
- **Per wave merge:** Vollständige Test-Suite
- **Phase gate:** Alle Tests grün vor `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `SPRECHKRAFTTests/HistoryStoreTests.swift` — deckt HIST-01, HIST-02, HIST-03
- [ ] In-Memory-DatabaseQueue für Tests (kein Filesystem-Zustand)

*(Wave 0 muss In-Memory-Variante von HistoryStore für Tests vorbereiten — `DatabaseQueue()` ohne Pfad erzeugt In-Memory-DB)*

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | nein | — |
| V3 Session Management | nein | — |
| V4 Access Control | nein | — |
| V5 Input Validation | ja | FTS5Pattern(matchingAllTokensIn:) — nil bei ungültigem Input, kein SQL-Injection-Risiko |
| V6 Cryptography | nein | Lokale SQLite-DB; keine Verschlüsselung in Scope |

### Known Threat Patterns for GRDB + FTS5

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| FTS5-Query-Injection via Suchfeld | Tampering | FTS5Pattern-Binding — User-Input nie als String in SQL interpolieren |
| Unbeabsichtigtes Löschen (Bulk-Delete) | Tampering | Confirm-Dialog (Alert mit destructive-Button, D-12) |

---

## Sources

### Primary (HIGH confidence)
- `/groue/grdb.swift` (Context7) — FTS5 creation, synchronize, FTS5Pattern, ValueObservation, Swift 6 Sendable, Migrations, DatabaseQueue setup, Application Support path
- `SPRECHKRAFT/AppDelegate.swift` (Codebase) — onRecordingComplete Pipeline, openSettingsMenu-Muster, NotificationCenter-Brücke
- `SPRECHKRAFT/SPRECHKRAFTApp.swift` (Codebase) — Window-Scene-Muster, HiddenActivationView, Activation-Policy-Workaround
- `SPRECHKRAFT/.planning/STATE.md` (Codebase) — Phase 5 pbxproj-Pitfall (3-Stellen-Problem bei SPM)

### Secondary (MEDIUM confidence)
- CLAUDE.md — Technology Stack decisions, GRDB v7.5.0 als Zielversion
- `.planning/phases/06-history/06-CONTEXT.md` — Alle Locked Decisions D-01 bis D-15

### Tertiary (LOW confidence)
- macOS SwiftUI List `onDelete`-Verhalten (Training-Wissen, A1 im Assumptions Log)

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — Context7 + Codebase-Verifikation
- Architecture: HIGH — Codebase-Pattern direkt übertragbar, GRDB-Docs bestätigt
- Pitfalls: HIGH (außer #5 MEDIUM) — 4 von 7 Pitfalls direkt aus STATE.md/Codebase-Mustern

**Research date:** 2026-04-20
**Valid until:** 2026-05-20 (GRDB v7 ist stabil; SwiftUI-macOS-APIs ändern sich nicht schnell)
