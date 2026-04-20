# Phase 6: History - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-20
**Phase:** 06-history
**Areas discussed:** History-Panel-Ort, Eintrags-Darstellung, Such-UX, Kopieren & Limits

---

## History-Panel-Ort

| Option | Description | Selected |
|--------|-------------|----------|
| Eigenes Fenster | Separates macOS-Fenster, öffnet per Menü-Eintrag | ✓ |
| Settings-Tab | Neuer Tab „Verlauf" in SettingsView | |
| Popover vom Icon | Klick auf Menu-Bar-Icon zeigt Popover | |

**User's choice:** Eigenes Fenster

| Option | Description | Selected |
|--------|-------------|----------|
| Menü-Eintrag | Rechtsklick-Menü erhält „Verlauf …" | ✓ |
| Globaler Hotkey | Konfigurierbarer Shortcut | |
| Menü + Hotkey | Beides kombiniert | |

**User's choice:** Nur Menü-Eintrag

---

## Eintrags-Darstellung

| Option | Description | Selected |
|--------|-------------|----------|
| Kompakt: Zeit + Vorschau | Zeitstempel + ~80 Zeichen, dichte Liste, Klick kopiert | ✓ |
| Master-Detail | Linke Spalte Liste, rechte Spalte Volltext | |
| Expandierbar | Expand-Pfeil pro Eintrag | |

**User's choice:** Kompakt (Zeit + Vorschau)

**Metadaten (Mehrfachauswahl):**

| Option | Selected |
|--------|----------|
| Profil-Name | ✓ |
| Original vs. LLM-Badge | ✓ |
| Datum (Heute/Gestern/Datum) | ✓ |
| Nichts zusätzlich | |

| Option | Description | Selected |
|--------|-------------|----------|
| Datum-Sektionen | Überschriften „HEUTE" / „GESTERN" / „19.04." | ✓ |
| Chronologische Liste | Flache Liste mit Datum pro Eintrag | |

**User's choice:** Datum-Sektionen

---

## Such-UX

| Option | Description | Selected |
|--------|-------------|----------|
| Live-Suche | Filtert sofort beim Tippen, debounced ~200ms | ✓ |
| Suche per Enter | Expliziter, weniger GRDB-Aufrufe | |

**User's choice:** Live-Suche

| Option | Description | Selected |
|--------|-------------|----------|
| Leerer Zustand mit Text | „Keine Ergebnisse für ‚xyz'" | ✓ |
| Leere Liste, kein Text | Schlicht, minimal | |

**User's choice:** Leerer Zustand mit erklärendem Text

---

## Kopieren & Limits

| Option | Description | Selected |
|--------|-------------|----------|
| LLM-Text wenn vorhanden, sonst Original | Spiegelt tatsächlichen Output | ✓ |
| Original-Transkript immer | Konsistent, ignoriert LLM | |
| Nutzer wählt per Toggle | Mehr Kontrolle, mehr Komplexität | |

**User's choice:** LLM-Text wenn vorhanden, sonst Original

| Option | Description | Selected |
|--------|-------------|----------|
| Zeile blinkt kurz grün | ~0.4s, dezent in der Liste | ✓ |
| Toast-Banner oben | Deutlicher, aber abrupt | |
| Kein Feedback | Minimal | |

**User's choice:** Zeile blinkt kurz grün

| Option | Description | Selected |
|--------|-------------|----------|
| Unbegrenzt | SQLite verwaltet 10.000+ problemlos | ✓ |
| Maximum 500 Einträge (FIFO) | Bounded storage | |
| Konfigurierbar in Settings | Slider/Zahlenfeld | |

**User's choice:** Unbegrenzt

| Option | Description | Selected |
|--------|-------------|----------|
| Beide: Einzeln + Alles löschen | Swipe-to-delete + „Verlauf leeren…" | ✓ |
| Nur Alles löschen | Simpler | |
| Kein Löschen in Phase 6 | Später | |

**User's choice:** Beide (Einzeln via Swipe/Kontextmenü + Gesamt mit Confirm-Dialog)

---

## Claude's Discretion

- Fenster-Mindestgröße und initiales Fenstermaß
- GRDB-Datenbankpfad (Standard Application Support Directory)
- Debounce-Implementierung (Combine vs. async/await)
- Swipe-to-delete vs. Kontextmenü für Einzellöschen

## Deferred Ideas

- History-Export (CSV, JSON)
- Profil-Filter in der History
- Globaler Hotkey für History-Fenster
- Migration Profiles von Defaults zu GRDB
