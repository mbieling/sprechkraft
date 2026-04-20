# UI-SPEC — Phase 6: History

**Phase:** 06 — History
**Status:** draft
**Erstellt:** 2026-04-20
**Design System:** Native SwiftUI macOS / kein shadcn (macOS-App)

---

## 0. Überblick

Phase 6 führt ein dediziertes History-Fenster ein, das über den Menüeintrag „Verlauf …" geöffnet
wird. Der Nutzer sieht alle Transkriptionen chronologisch nach Datum gruppiert, sucht via
Live-FTS5-Suche und kopiert Einträge per Klick. Das Fenster ist eigenständig (kein Tab in
Einstellungen) und folgt dem etablierten Muster des Einstellungsfensters aus Phase 2/5.

---

## 1. Spacing Scale

Bestehende DesignTokens.swift wird ohne Änderung übernommen. Alle neuen Abstände folgen
ausschließlich der bestehenden Skala:

| Token | Wert | Verwendung in dieser Phase |
|-------|------|---------------------------|
| `DesignTokens.Spacing.xs` | 4 pt | Abstand innerhalb der Listenzeile (Zeit↔Badge, Badge↔Badge) |
| `DesignTokens.Spacing.sm` | 8 pt | Padding innerhalb der Listenzeile (vertikal), Suchfeld-Innenabstand |
| `DesignTokens.Spacing.md` | 16 pt | Horizontales Padding der Listenzeile, Abstand Sektionsheader |
| `DesignTokens.Spacing.lg` | 24 pt | Abstand zwischen Sektionen |
| `DesignTokens.Spacing.xl` | 32 pt | Fensterkanten-Padding (identisch mit SettingsView) |

Kein neuer Spacing-Token wird eingeführt.

Quelle: `VoiceScribe/Constants/DesignTokens.swift` (codebase, bestehend).

---

## 2. Typography

Exakt die gleichen Schriftgrößen wie SettingsView — kein neuer Token.

| Rolle | Größe | Gewicht | Line-Height | Verwendung |
|-------|-------|---------|-------------|------------|
| Body | 13 pt | regular (400) | 1.4 | Vorschautext der Listenzeile (~80 Zeichen) |
| Meta | 11 pt | regular (400) | 1.3 | Zeitstempel (HH:MM) und Profilname in der Zeile |
| Badge | 10 pt | semibold (600) | 1.0 | „KI"-Badge (LLM-verarbeiteter Eintrag) |
| Section Header | 11 pt | semibold (600) | 1.2 | Datum-Sektionsüberschriften (HEUTE / GESTERN / DD.MM.JJJJ) |

Schriftfamilie: `.system(size:weight:)` — System-Schrift, kein Custom-Font.
Monospaced-Ziffern für Zeitstempel: `.monospacedDigit()` (konsistent mit Slider-Wert in
SettingsView).

Quelle: CONTEXT.md D-03, D-04; SettingsView.swift bestehende Muster (codebase).

---

## 3. Color Contract

### 60 % — Dominante Oberfläche
`Color(.windowBackground)` — systemseitig vom macOS-Fensterhintergrund bestimmt.
Die List-Zeilen verwenden `.listStyle(.inset)` ohne zusätzliche Hintergrundfärbung.

### 30 % — Sekundär (Struktur)
`Color(.separatorColor)` für horizontale Trennlinien (automatisch in SwiftUI List).
Sektions-Überschriften: `.secondary` Vordergrundfarbe über dem Fensterhintergrund.

### 10 % — Accent (reserviert für)

| Element | Farbe | Token / Wert |
|---------|-------|-------------|
| KI-Badge Hintergrund | systemPurple | `Color(.systemPurple)` — konsistent mit `RecordingState.llmProcessing.color` |
| KI-Badge Text | white | `Color.white` |
| Kopier-Flash (Zeilenhintergrund) | systemGreen, 30 % opacity | `Color(.systemGreen).opacity(0.3)` |
| Suchfeld-Fokusring | System-Accent (Systemfarbe) | automatisch via SwiftUI `.searchable` |

Destruktive Farbe: `Color(.systemRed)` — ausschließlich für den Bestätigungs-Dialog-Button
„Löschen" (`.destructive`-Rolle in SwiftUI Alert). Kein manuelles Setzen notwendig; SwiftUI
setzt die Farbe automatisch bei `role: .destructive`.

Quelle: CONTEXT.md D-10 (grüner Flash), Specifics (systemPurple-Badge); AppState.swift
`RecordingState.color` (codebase, bestehend).

---

## 4. Fenster-Contract

### Fenstermaß

| Eigenschaft | Wert | Begründung |
|-------------|------|------------|
| Initiales Maß | 640 × 480 pt | Ausreichend für Suchfeld + 6–8 sichtbare Listenzeilen; Daumen-Empfehlung aus CONTEXT.md ~600×400 mit etwas Reserve |
| Mindestbreite | 480 pt | Verhindert abgeschnittene Vorschautexte bei 80-Zeichen-Zeilen |
| Mindesthöhe | 320 pt | Mindestens Suchfeld + 3 Zeilen sichtbar |
| Resizeable | ja | `.windowResizability(.contentSize)` mit Min-Constraint |

### Fenstertitel
`"VoiceScribe — Verlauf"` — konsistentes Muster zu `"VoiceScribe — Einstellungen"`.

### Menüpunkt
Text: `"Verlauf…"` (Ellipsis-Zeichen U+2026, nicht drei Punkte) — einheitlich mit
`"Einstellungen…"`.

Position im Kontextmenü: vor „Einstellungen…", nach App-spezifischen Aktionseinträgen.

Quelle: CONTEXT.md D-01, D-02; VoiceScribeApp.swift/AppDelegate.swift Muster (codebase).

---

## 5. Layout-Struktur

```
┌─────────────────────────────────────────────┐
│  [Verlauf löschen…]              [Suchen  ] │  ← Toolbar-Bereich (keine native Toolbar nötig)
│─────────────────────────────────────────────│
│  Suchfeld: [                             ]  │  ← TextField, immer sichtbar, volle Breite
│─────────────────────────────────────────────│
│                                             │
│  HEUTE                                      │  ← Section Header (11pt semibold, secondary)
│  ┌─────────────────────────────────────┐   │
│  │ 14:32  Dieses Transkript wird als…  │   │  ← Listenzeile (Klick → Kopieren)
│  │        Profil: Notizen  [KI]        │   │
│  └─────────────────────────────────────┘   │
│  ┌─────────────────────────────────────┐   │
│  │ 13:17  Weiterer Eintrag der heute…  │   │
│  │        kein Profil                  │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  GESTERN                                    │
│  ┌─────────────────────────────────────┐   │
│  │ 17:05  Eintrag von gestern, der…    │   │
│  └─────────────────────────────────────┘   │
│                                             │
└─────────────────────────────────────────────┘
```

Hinweis: Der „Verlauf löschen"-Button liegt außerhalb der Liste, z.B. als `toolbar`-Item oder
als Button unterhalb des Suchfelds. Er ist in der Liste nicht sichtbar und lenkt nicht vom
Hauptinhalt ab. Empfohlen: `HStack` über der Liste mit Suchfeld (links/flex) und Button rechts.

---

## 6. Listenzeilen-Anatomie

Jede Zeile in `HistoryView` folgt diesem Layout:

```
┌──────────────────────────────────────────────────┐
│  14:32   Dieses Transkript wird als Vorschau …   │  ← Row height: variabel (~44–56 pt)
│          Profil: Notizen  [KI]                   │
└──────────────────────────────────────────────────┘
```

| Element | Spezifikation |
|---------|--------------|
| Zeitstempel | 11 pt, regular, `.monospacedDigit()`, `.secondary`, min-width 32 pt, führende Ausrichtung |
| Vorschautext | 13 pt, regular, max 80 Zeichen + „…", 1 Zeile, `.lineLimit(1)` |
| Profilname | 11 pt, regular, `.secondary`, erscheint nur wenn `profile_name != nil` |
| KI-Badge | 10 pt, semibold, weißer Text, `systemPurple`-Hintergrund, `cornerRadius: 4`, Padding 4×4 pt = `DesignTokens.Spacing.xs` (vertikal × horizontal) — erscheint nur wenn `is_llm_processed == true` |
| Zeilenhöhe | variabel; SwiftUI List bestimmt Höhe nach Inhalt, min ~44 pt (Touch-Target-Konvention) |
| Klick-Verhalten | gesamte Zeile ist tappable via `.contentShape(Rectangle())` und `.onTapGesture` |
| Hover-State | System-Standard (List-Row-Highlight automatisch) |
| Flash-State | `Color(.systemGreen).opacity(0.3)` als `.background`, `animation(.easeOut(duration: 0.4))` |

---

## 7. Sektions-Überschriften

Format nach CONTEXT.md D-05 und CONTEXT.md Specifics:

| Bedingung | Angezeigter Text |
|-----------|-----------------|
| `Calendar.current.isDateInToday(entry.createdAt)` | `"HEUTE"` |
| `Calendar.current.isDateInYesterday(entry.createdAt)` | `"GESTERN"` |
| Ältere Einträge | `"DD.MM.YYYY"` (z.B. `"19.04.2026"`) via `DateFormatter(dateFormat: "dd.MM.yyyy")` |

Sortierung: Neueste Sektion zuerst, innerhalb der Sektion neueste Einträge oben (D-05).

Darstellung: SwiftUI `Section(header:)` mit capitalisation wie oben. Kein Chevron, keine
Expand/Collapse-Funktion.

---

## 8. Suchfeld-Contract

| Eigenschaft | Spezifikation |
|-------------|--------------|
| Komponente | SwiftUI `TextField("Verlauf durchsuchen…", text: $searchText)` mit `.textFieldStyle(.roundedBorder)` |
| Platzierung | Oberer Bereich des Fensters, volle Breite minus horizontalem Padding (`DesignTokens.Spacing.md`) |
| Sichtbarkeit | Immer sichtbar — kein Ausblenden bei leerem State (D-06) |
| Debounce | 200 ms via `Task.sleep`-Pattern (RESEARCH.md Pattern 4) |
| Clear-Button | System-Standardverhalten von `TextField` auf macOS (× erscheint wenn Text vorhanden) |
| Placeholder | `"Verlauf durchsuchen…"` — 13 pt, `.secondary` |
| Fokus bei Fensteröffnung | Suchfeld erhält Fokus automatisch via `.focusedSceneValue` oder manuell via `@FocusState` nach `onAppear` |

---

## 9. Zustands-Verträge (State Machine)

### 9.1 Normaler Zustand (Einträge vorhanden, keine Suche)

Liste zeigt alle Einträge gruppiert nach Datum (D-05). Suchfeld leer.

### 9.2 Suche aktiv (Query vorhanden, Ergebnisse vorhanden)

Liste zeigt FTS5-Treffer. Sektionierung bleibt erhalten (Ergebnisse weiterhin nach Datum
gruppiert). Keine Highlighting der Treffer im Vorschautext (nicht in Scope).

### 9.3 Leer-Zustand A — Keine Einträge insgesamt

```
[zentriert vertikal und horizontal im Fenster]
Symbol: sf.clock.badge.xmark (oder "clock" + opacity)
Text (16 pt, semibold): "Noch keine Einträge"
Untertext (13 pt, secondary): "Transkriptionen werden hier gespeichert, sobald du diktierst."
```

### 9.4 Leer-Zustand B — Suche ohne Ergebnis

Entspricht CONTEXT.md D-07:
```
[zentriert vertikal und horizontal]
Symbol: sf.magnifyingglass (systemName)
Text (16 pt, semibold): "Keine Ergebnisse"
Untertext (13 pt, secondary): "Keine Einträge für „{searchText}" gefunden."
```

Hinweis: `searchText` in Anführungszeichen (typografische „…", nicht ASCII "…").

### 9.5 Flash-Zustand (Kopieren)

Ausgelöst durch Klick auf Zeile. Ablauf:
1. `NSPasteboard.general.setString(entry.copyText, forType: .string)`
2. `flashingEntryID = entry.id`
3. Zeilenhintergrund wechselt zu `Color(.systemGreen).opacity(0.3)` via `withAnimation(.easeOut(duration: 0.4))`
4. Nach 400 ms: `flashingEntryID = nil` → Hintergrund kehrt transparent zurück

Quelle: CONTEXT.md D-10; RESEARCH.md Pattern 8 (codebase-Muster vorgeschlagen).

---

## 10. Löschen-Contract

### Einzellöschen

Mechanismus: `.contextMenu` auf Listenzeile (Rechtsklick) — kein Swipe-to-Delete (macOS
SwiftUI erfordert Edit-Mode für `onDelete`, `.contextMenu` ist das native macOS-Pattern,
RESEARCH.md Pitfall 5).

Kontextmenü-Item:
```
Text: "Eintrag löschen"
Role: .destructive
```

Kein separater Bestätigungs-Dialog — Kontextmenü-Aktion ist ausreichend explizit.

### Gesamt löschen

Button-Label: `"Verlauf leeren…"` (Ellipsis U+2026 signalisiert nachfolgende Abfrage).
Platzierung: Im Fenster, z.B. als Button oben rechts neben dem Suchfeld oder als Toolbar-Item.

Bestätigungs-Dialog (nativer SwiftUI Alert):
```swift
.alert("Verlauf leeren?", isPresented: $showClearConfirm) {
    Button("Löschen", role: .destructive) { ... }
    Button("Abbrechen", role: .cancel) {}
} message: {
    Text("Alle Einträge werden unwiderruflich gelöscht.")
}
```

Quelle: CONTEXT.md D-12; RESEARCH.md Pattern „Confirm-Dialog beim Leeren".

---

## 11. Copywriting Contract

| Element | Text (DE) | Kontext |
|---------|-----------|---------|
| Menüpunkt | `"Verlauf…"` | NSMenuItem in AppDelegate-Kontextmenü |
| Fenstertitel | `"VoiceScribe — Verlauf"` | Window-Titelbar |
| Suchfeld-Placeholder | `"Verlauf durchsuchen…"` | TextField Placeholder |
| KI-Badge | `"KI"` | Badge-Label wenn is_llm_processed == true |
| Empty State A Titel | `"Noch keine Einträge"` | Kein Eintrag in DB |
| Empty State A Body | `"Transkriptionen werden hier gespeichert, sobald du diktierst."` | Subtext zum Empty State |
| Empty State B Titel | `"Keine Ergebnisse"` | FTS5-Suche ohne Treffer |
| Empty State B Body | `"Keine Einträge für „{query}" gefunden."` | Dynamischer Text mit gesuchtem Begriff |
| Gesamt-Löschen Button | `"Verlauf leeren…"` | Button im Fenster |
| Confirm-Alert Titel | `"Verlauf leeren?"` | SwiftUI Alert |
| Confirm-Alert Nachricht | `"Alle Einträge werden unwiderruflich gelöscht."` | Alert-Message |
| Confirm-Alert Löschen | `"Löschen"` | Destructive Button |
| Confirm-Alert Abbrechen | `"Abbrechen"` | Cancel Button |
| Kontextmenü Einzellöschen | `"Eintrag löschen"` | Contextmenu-Item (destructive) |

Typografische Anführungszeichen in Empty State B: `„…"` (DE-Standard: unten öffnend,
oben schließend). In Swift: `"„\(query)""`.

---

## 12. Accessibility Contract

| Element | Anforderung |
|---------|-------------|
| Listenzeilen | `.accessibilityLabel("\(timeString), \(preview), \(profileLabel)\(llmLabel). Tippen zum Kopieren.")` |
| KI-Badge | `.accessibilityLabel("KI-verarbeitet")` (nicht sichtbares Kürzel erklären) |
| Suchfeld | `.accessibilityLabel("Verlauf durchsuchen")` |
| Gesamt-Löschen | `.accessibilityLabel("Verlauf leeren")` |
| Flash-Feedback | `.accessibilityAnnouncement("Kopiert")` nach erfolgreichem Kopieren via `AccessibilityNotification.announcement` |
| Sektionsüberschriften | SwiftUI Section-Header sind automatisch Accessibility-Gruppen — kein zusätzliches Label nötig |

---

## 13. Animations-Contract

| Interaction | Animation | Dauer | Easing |
|-------------|-----------|-------|--------|
| Kopier-Flash (Hintergrund grün) | `.easeOut` | 0.4 s | easeOut |
| Kopier-Flash (Rückkehr transparent) | `.easeOut` | 0.4 s | easeOut (gleicher Parameter) |
| Listeneintrag erscheint (Insert) | System-Standard (List-Animation) | automatisch | — |
| Listeneintrag verschwindet (Delete) | System-Standard (List-Animation) | automatisch | — |
| Suchfeld-Ergebnisse aktualisieren | keine explizite Animation | — | — |

Quelle: CONTEXT.md D-10 (~0.4s, kein Toast, dezent); RESEARCH.md Pattern 8.

---

## 14. Registry

Kein shadcn-Registry (native macOS SwiftUI App).

**Neue SPM-Dependency:**

| Library | Version | Sicherheits-Gate |
|---------|---------|-----------------|
| `groue/GRDB.swift` | v7.5.0 | view passed — Context7 `/groue/grdb.swift` verifiziert, keine externen Netzwerkanfragen in der Library, kein eval/Function, bekannte Open-Source-Library — 2026-04-20 |

Alle anderen Dependencies (KeyboardShortcuts, KeychainAccess, LaunchAtLogin-modern, Defaults)
sind bereits im Projekt vorhanden und unverändert.

---

## 15. Nicht in Scope (Deferred)

Folgende UI-Elemente werden in Phase 6 NICHT implementiert:

- Profil-Filter in der History (nur Einträge von Profil X anzeigen)
- Export-Button (CSV, JSON, Text)
- Detail-Panel / Master-Detail-Split
- Texttreffer-Highlighting in Suchergebnissen
- Globaler Hotkey für das History-Fenster
- Migration von Profiles (Defaults → GRDB)

Quelle: CONTEXT.md `<deferred>`.

---

## 16. Pre-Population-Quellen

| Entscheidung | Quelle |
|-------------|--------|
| Fenstertyp: eigenständiges Fenster | CONTEXT.md D-01 |
| Öffnen via Menüeintrag „Verlauf…" | CONTEXT.md D-02 |
| Listenzeile: Zeit + 80-Zeichen-Vorschau, Klick = Kopieren | CONTEXT.md D-03 |
| Metadaten-Felder (HH:MM, Profilname, KI-Badge) | CONTEXT.md D-04 |
| Datum-Sektionen HEUTE/GESTERN/DD.MM.JJJJ | CONTEXT.md D-05 |
| Live-Suche 200ms debounced | CONTEXT.md D-06 |
| Leer-Zustand „Keine Ergebnisse für …" | CONTEXT.md D-07 |
| Grün-Flash ~0.4s, kein Toast | CONTEXT.md D-10 |
| Kontextmenü für Einzellöschen (statt onDelete) | RESEARCH.md Pitfall 5 |
| Bestätigungs-Alert bei Gesamt-Löschen | CONTEXT.md D-12 |
| DesignTokens.Spacing (xs/sm/md/lg/xl) | `DesignTokens.swift` (codebase) |
| Schriftgrößen 13/11/10 pt | `SettingsView.swift` (codebase) |
| systemPurple für KI-Badge | CONTEXT.md Specifics; AppState.swift `llmProcessing.color` |
| Fenster-Muster (NotificationCenter-Brücke, .accessory-Workaround) | `VoiceScribeApp.swift` (codebase) |

---

*Phase: 06-history*
*UI-SPEC erstellt: 2026-04-20*
*Verantwortlich: gsd-ui-researcher*
