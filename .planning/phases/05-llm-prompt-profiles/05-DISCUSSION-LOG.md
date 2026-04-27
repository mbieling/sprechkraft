# Phase 5: LLM + Prompt Profiles - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-19
**Phase:** 05-llm-prompt-profiles
**Areas discussed:** Profil-Aktivierung, Profil-Persistenz, Groq API Design, Settings-UI Struktur

---

## Profil-Aktivierung

| Option | Description | Selected |
|--------|-------------|----------|
| Gleichzeitig halten | Profil-Hotkey + ⌥⌘R gleichzeitig halten | ✓ |
| Profil-Hotkey zuerst | Profil-Hotkey einmal drücken, dann normal ⌥⌘R | |
| Nur über Menü/UI | Kein Hotkey, Profil im Menü wählen | |

**User's choice:** Gleichzeitig halten

| Option | Description | Selected |
|--------|-------------|----------|
| Erster gewinnt | Zuerst gedrücktes Profil gilt für diese Aufnahme | ✓ |
| Letzter gewinnt | Zuletzt gedrücktes Profil überschreibt | |

**User's choice:** Erster gewinnt

| Option | Description | Selected |
|--------|-------------|----------|
| Menü-Häkchen genügt | Aktives Profil im Menü-Dropdown markiert | ✓ |
| StatusBar-Title zeigen | Profil-Name kurz im NSStatusItem.title | |

**User's choice:** Menü-Häkchen genügt

---

## Profil-Persistenz

| Option | Description | Selected |
|--------|-------------|----------|
| Defaults.Keys Codable Array | `[PromptProfile]` in UserDefaults via Defaults-Library | ✓ |
| JSON-Datei AppSupport | JSON in ~/Library/Application Support/SPRECHKRAFT/ | |
| GRDB jetzt einführen | SQLite schon in Phase 5, Phase 6 baut darauf | |

**User's choice:** Defaults.Keys Codable Array

| Option | Description | Selected |
|--------|-------------|----------|
| Vorgefertigtes Default-Profil | App startet mit „Rohe Transkription"-Profil | ✓ |
| Keine Profile, Liste leer | Nutzer legt erstes Profil selbst an | |

**User's choice:** Vorgefertigtes Default-Profil

---

## Groq API Design

| Option | Description | Selected |
|--------|-------------|----------|
| /no_think Standard | Kein Thinking-Mode, direkter Output | |
| Denken erlaubt | qwen3 Chain-of-Thought vor Antwort | ✓ |

**User's choice:** Denken erlaubt (Thinking-Mode)

| Option | Description | Selected |
|--------|-------------|----------|
| Global aktiviert | Alle LLM-Profile nutzen Thinking | |
| Pro Profil konfigurierbar | Jedes Profil hat eigenen Thinking-Toggle | ✓ |

**User's choice:** Pro Profil konfigurierbar

| Option | Description | Selected |
|--------|-------------|----------|
| Stille Fallback zu Raw | Bei Fehler → Raw-Transkript ausgeben | ✓ |
| Fehler-Toast zeigen | Fehlermeldung im StatusBar-Title oder Notification | |

**User's choice:** Stille Fallback zu Raw

---

## Settings-UI Struktur

| Option | Description | Selected |
|--------|-------------|----------|
| Sheet-Modal pro Profil | Liste + SwiftUI .sheet() für Bearbeitung | ✓ |
| Inline-Edit in der Liste | Accordion-Expand direkt in der Liste | |

**User's choice:** Sheet-Modal pro Profil

| Option | Description | Selected |
|--------|-------------|----------|
| Löschbar wenn anderes als Standard | Profil löschbar solange Letztes nicht | ✓ |
| Nicht löschbar (initiales Profil) | Initial-Profil permanent, nur editierbar | |

**Notes:** Initial als „Nicht löschbar" gewählt, dann im Review auf „Löschbar" geändert.
Entschieden: Jedes Profil ist löschbar, aber Löschen-Button wird ausgegraut wenn nur noch
ein Profil verbleibt (letztes Profil bleibt immer erhalten).

---

## Claude's Discretion

- Exakte PromptProfile-Struct-Felder und Codable-Implementierung
- KeyboardShortcuts.Name-Generierung für dynamische Profile (UUID vs. Index)
- Timeout-Wert für Groq-URLSession
- Reihenfolge der Felder im Sheet-Modal
- llmProcessing-State während Groq-Aufruf (empfohlen: ja)

## Deferred Ideas

- Streaming-Output — v2
- Multi-Provider LLM — Out of Scope
- Profil-Import/-Export — v2
- Drag & Drop Profil-Reihenfolge — v2 UX-Polish
