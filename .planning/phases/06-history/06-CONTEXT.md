# Phase 6: History - Context

**Gathered:** 2026-04-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Jede abgeschlossene Transkription wird lokal in einer GRDB/FTS5-Datenbank gespeichert.
Der Nutzer öffnet ein dediziertes History-Fenster über das Rechtsklick-Menü, sucht via
Live-FTS5-Suche in allen Einträgen, und kopiert einen Eintrag per Klick in die
Zwischenablage.

Kein Cloud-Sync. Kein Export. Kein Streaming. Keine Profil-Migration zu GRDB in dieser
Phase (Profile bleiben in Defaults).

</domain>

<decisions>
## Implementation Decisions

### History-Panel: Fenster & Navigation

- **D-01:** **Eigenes macOS-Fenster** — kein Popover, kein Settings-Tab. Eigenes Fenster
  bietet genügend Platz für Suche + Datum-Gruppen + Liste.
- **D-02:** **Öffnen via Menü-Eintrag** — Rechtsklick-Menü erhält Eintrag „Verlauf …"
  (konsistent mit „Einstellungen …"). Kein globaler Hotkey in Phase 6.

### Eintrags-Darstellung

- **D-03:** **Kompakte Listenzeile** — Zeit + ~80 Zeichen Textvorschau. Kein separates
  Detail-Panel (kein Master-Detail-Split). Klick auf Zeile kopiert direkt.
- **D-04:** **Metadaten pro Eintrag:** Zeitstempel (HH:MM), Profil-Name, Badge „LLM" wenn
  Groq-verarbeitet, relatives Datum als Sektions-Überschrift (Heute / Gestern / DD.MM.JJJJ).
- **D-05:** **Datum-Sektionen** — Einträge unter Überschriften „HEUTE" / „GESTERN" /
  „19.04.2026" etc. Neueste Sektion zuerst, innerhalb einer Sektion neueste Einträge
  oben.

### Such-UX

- **D-06:** **Live-Suche (debounced ~200ms)** — FTS5-Abfrage nach jedem Tastendruck,
  kein Suche-Button. Suchfeld oben im Fenster, immer sichtbar.
- **D-07:** **Leer-Zustand bei keinem Ergebnis** — Text „Keine Ergebnisse für ‚xyz'"
  (kein leeres Listing ohne Erklärung). Konsistent mit macOS-Konventionen.
- **D-08:** FTS5-Suche durchsucht **sowohl Original-Transkript als auch LLM-Text**
  (beide Felder in der FTS5-Virtual-Table). Der Nutzer unterscheidet nicht explizit.

### Kopieren & Zwischenablage

- **D-09:** **Kopiert LLM-Text wenn vorhanden, sonst Original** — spiegelt das, was der
  Nutzer tatsächlich als Output bekommen hätte. Kein Toggle, kein explizites UI.
- **D-10:** **Visuelles Feedback: Zeilenhintergrund blinkt kurz grün** (~0.4s Animation).
  Kein Toast-Banner, kein Sound. Dezent, bleibt in der Liste.

### History-Verwaltung

- **D-11:** **Unbegrenzte Einträge** — SQLite/GRDB auf lokalem Gerät, kein Limit.
- **D-12:** **Einzeln und Gesamt löschen:**
  - Einzeln: Swipe-to-delete (NSTableView/List `onDelete`) oder Kontextmenü per Rechtsklick
    auf Eintrag.
  - Gesamt: „Verlauf leeren …" im Fenster-Menü oder per Button im Fenster mit
    Confirm-Dialog (Alert: „Alle Einträge löschen?" / „Löschen" + „Abbrechen").

### GRDB-Schema

- **D-13:** **Tabelle `transcription_entries`** mit Spalten:
  - `id` INTEGER PRIMARY KEY
  - `created_at` DATETIME NOT NULL
  - `original_text` TEXT NOT NULL
  - `llm_text` TEXT (NULL wenn kein LLM-Pfad)
  - `profile_name` TEXT (NULL wenn kein Profil)
  - `is_llm_processed` BOOLEAN NOT NULL
- **D-14:** **FTS5-Virtual-Table** über `original_text` und `llm_text`.
  Content-Table: `transcription_entries`.
- **D-15:** **Speicherpunkt im Pipeline:** GRDB-Insert erfolgt in `onRecordingComplete`
  in AppDelegate, **nach** TextOutputService (letzter Schritt), sodass der finale
  Output-Text (original oder LLM) bereits bekannt ist.

### Claude's Discretion

- Fenster-Mindestgröße und initiales Fenstermaß — Claude entscheidet (empfohlen: ~600×400).
- GRDB-Datenbankpfad — Standard Application Support Directory.
- Debounce-Implementierung (Combine / Task mit `try await Task.sleep`) — Claude entscheidet.
- Swipe-to-delete vs. Kontextmenü für Einzellöschen — Claude entscheidet welche SwiftUI-API
  am besten passt (List `onDelete` oder `.contextMenu`).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Stack & Architektur
- `CLAUDE.md` — Technology Stack: GRDB.swift v7.5.0, Defaults, KeyboardShortcuts, SwiftUI
- `VoiceScribe/Extensions/Defaults+Keys.swift` — bestehende Persistence-Pattern (Vorlage für GRDB-Integration)
- `VoiceScribe/AppDelegate.swift` — onRecordingComplete-Pipeline: hier wird der GRDB-Insert-Punkt sein (D-15)

### Prior Phase Context
- `.planning/phases/05-llm-prompt-profiles/05-CONTEXT.md` — D-04: "Einfache Migration zu GRDB in Phase 6"
  (Profile bleiben in Defaults, nur neue History-Tabelle in GRDB)

### Requirements
- `.planning/REQUIREMENTS.md` §HIST-01 bis HIST-04 — Acceptance Criteria für History

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `VoiceScribe/AppDelegate.swift` `onRecordingComplete`: Insert-Punkt für GRDB (nach TextOutputService, D-15)
- `VoiceScribe/Extensions/Defaults+Keys.swift`: Pattern für type-safe Keys, als Vorlage für GRDB-Keys
- `VoiceScribe/Models/PromptProfile.swift`: Codable-Struct-Pattern; HistoryEntry analog modellieren
- `VoiceScribe/AppDelegate.swift` `openSettingsMenu()`: Vorlage für neuen „openHistory()"-Menüpunkt (D-02)
- `VoiceScribe/Constants/DesignTokens.swift`: Spacing/Color-Token für History-UI

### Established Patterns
- Menü-Einträge: NSMenuItem mit `@objc`-Selektoren in AppDelegate (D-02: „Verlauf …" analog zu „Einstellungen …")
- Zustandsübergänge: @Observable AppState + @MainActor (History-Fenster folgt demselben Muster)
- Defaults.binding-Pattern aus SettingsView für etwaige History-Settings

### Integration Points
- `AppDelegate.onRecordingComplete`: Hier GRDB-Insert einfügen (letzter Schritt nach TextOutputService)
- AppDelegate Menü-Aufbau: Neuen Menüpunkt „Verlauf …" vor „Einstellungen …" einfügen
- Package.swift: GRDB.swift v7.5.0 als SPM-Dependency hinzufügen (noch nicht vorhanden)

</code_context>

<specifics>
## Specific Ideas

- Sektions-Überschriften: „HEUTE", „GESTERN", „19.04.2026" — analoges Muster zu Messages.app
- LLM-Badge: kleines Chip-Label „KI" (systemPurple, passend zur llmProcessing-Farbe aus AppState)
- Grün-Blink bei Kopieren: ~0.4s, nicht länger — dezent, kein Aufmerksamkeits-Dieb
- Confirm-Dialog beim Leeren: nativer SwiftUI Alert mit destructive Button-Style

</specifics>

<deferred>
## Deferred Ideas

- History-Export (CSV, JSON, Text-Datei) — eigene Phase wenn gewünscht
- Profil-Filter in der History (nur Einträge von Profil X zeigen) — kann in Phase 7 oder später
- Migration von Profiles (Defaults → GRDB) — explizit NICHT in Phase 6 (D-04 Phase 5 bestätigt)
- Globaler Hotkey für History-Fenster — kein Bedarf in Phase 6 geäußert

</deferred>

---

*Phase: 06-history*
*Context gathered: 2026-04-20*
