# Phase 1: App Shell - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-15
**Phase:** 01-app-shell
**Areas discussed:** Icon-Design (4 Zustände), Menü-Struktur, Einstellungen-Placeholder

---

## Icon-Design (4 Zustände)

### Symbol-Strategie

| Option | Description | Selected |
|--------|-------------|----------|
| Gleiches Symbol, verschiedene Farben | mic.fill immer — grau/rot/blau/lila je Zustand | ✓ |
| Verschiedene SF Symbols | mic, mic.fill, waveform, sparkles pro Zustand | |

**User's choice:** Gleiches Symbol (mic.fill), verschiedene Farben  
**Notes:** Konsistentes visuelles Vokabular, einfacher zu animieren

### Animations-Scope Phase 1

| Option | Description | Selected |
|--------|-------------|----------|
| Ja, statisch reicht für Phase 1 | Nur Farbwechsel, Animation erst Phase 2 | |
| Schon jetzt einfache Pulse-Animation | Aufnahme + LLM pulsen sanft | ✓ |

**User's choice:** Pulse-Animation bereits in Phase 1  
**Notes:** Waveform/Level-Meter bleibt Phase 2 (FEED-03)

### Welche Zustände pulsen

| Option | Description | Selected |
|--------|-------------|----------|
| Aufnahme + LLM | Beide aktiven Zustände pulsieren | ✓ |
| Nur Aufnahme | Nur Rot pulsiert | |
| Alle nicht-Idle | Alle 3 aktiven Zustände pulsieren | |

**User's choice:** Aufnahme + LLM  
**Notes:** Transkribieren bleibt statisch blau

---

## Menü-Struktur

### Menü-Inhalt

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal: nur das Nötigste | VoiceScribe / Einstellungen / Login-Toggle / Beenden | ✓ |
| Mit Statuszeile oben | Zusätzlich Status-Zeile (z.B. "Bereit") unter App-Namen | |

**User's choice:** Minimal  
**Notes:** Erweiterbar für spätere Phasen (z.B. aktives Profil)

### Click-Verhalten

| Option | Description | Selected |
|--------|-------------|----------|
| Klick öffnet Menü, Hotkey steuert App | Standard macOS — Linksklick = Menü | |
| Rechtsklick = Menü, Linksklick = Direkte Aktion | Unkonventionell aber power-user-freundlich | ✓ |

**User's choice:** Rechtsklick = Menü, Linksklick = direkte Aktion  
**Notes:** Erfordert AppKit NSStatusItem statt reinem SwiftUI MenuBarExtra

---

## Einstellungen-Placeholder

| Option | Description | Selected |
|--------|-------------|----------|
| Leeres Fenster (Shell für spätere Phasen) | Echtes SwiftUI-Fenster öffnet sich — leer | ✓ |
| Nur deaktivierter Menüpunkt | Ausgegraut, öffnet nichts | |

**User's choice:** Leeres SwiftUI-Fenster  
**Notes:** Verhindert späteren Umbau; spätere Phasen ergänzen Tabs/Inhalte

---

## Claude's Discretion

- Xcode-Projektstruktur und Package-Layout
- SwiftUI @main App vs. AppDelegate pattern
- Konkrete Animationsimplementierung (Timer-basiert, SwiftUI Animation, Core Animation)

## Deferred Ideas

Keine — Diskussion blieb im Phase-Scope.
