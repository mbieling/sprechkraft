# VoiceScribe: Lokale Diktat-App für macOS

## What This Is

Eine native macOS Menu-Bar-App für systemweites Diktat. Der Nutzer hält einen globalen Hotkey gedrückt, spricht, lässt los — und der Text erscheint entweder direkt im aktiven Textfeld oder im Clipboard. Transkription läuft vollständig lokal via Parakeet v3 (gebundelt in der App). Optional durchläuft das Transkript eines von mehreren KI-Prompt-Profilen via Groq API (qwen/qwen3-32b), bevor der Text ausgegeben wird.

Inspiration: https://tryvoiceink.com

## Core Value

Text per Sprache eingeben, genau wie tippen — schnell, systemweit, ohne Fenster wechseln zu müssen.

## Target User

Der Entwickler selbst (Power-User, Mac-Nutzer, der schnelles qualitatives Diktat mit KI-Nachbearbeitung will).

## Context

- Greenfield macOS-Projekt, Native Swift/SwiftUI
- Lokale Transkription: Parakeet v3 (NVIDIA ASR), in der App gebundelt
- LLM Post-Processing: Groq API mit qwen/qwen3-32b
- Kein Cloud-Transkriptions-Dienst, maximale Privatsphäre

## How It Works

1. **Hotkey halten** → Aufnahme startet, Menüleisten-Icon animiert
2. **Sprechen**
3. **Loslassen** → Parakeet transkribiert lokal
4. **KI optional** → Aktives Prompt-Profil geht an Groq (qwen3-32b)
5. **Ausgabe** → ins aktive Textfeld (via Accessibility) oder Clipboard
6. **Gespeichert** → Transkription in lokaler, durchsuchbarer Historie

## Requirements

### Validated

(None yet — ship to validate)

### Active

**Aufnahme & Transkription**
- [ ] Globaler Hotkey startet/stoppt Aufnahme (konfigurierbar)
- [ ] Parakeet v3 läuft lokal, gebundelt in der App
- [ ] Menüleisten-Icon ändert Farbe/Animation während Aufnahme und Verarbeitung

**Ausgabe**
- [ ] Text erscheint im aktiven Textfeld (via Accessibility API)
- [ ] Alternativ: Text in Clipboard — Modus einstellbar
- [ ] Ausgabemodus per Einstellung oder Hotkey wechselbar

**KI-Prompt-Profile**
- [ ] Mehrere editierbare Prompt-Profile (Name, Prompt-Text, Hotkey)
- [ ] Groq API (qwen/qwen3-32b) verarbeitet Transkript via aktivem Profil
- [ ] KI-Verarbeitung pro Profil aktivierbar/deaktivierbar
- [ ] Groq API-Key sicher speicherbar (macOS Keychain)

**Geschichte & Einstellungen**
- [ ] Alle Transkriptionen lokal gespeichert
- [ ] Durchsuchbare Historie im Einstellungsfenster
- [ ] Einstellungsfenster: API-Key, Profile, Hotkeys, Ausgabemodus

**App-Verhalten**
- [ ] Menu Bar App (kein Dock-Icon, läuft im Hintergrund)
- [ ] Autostart beim Login konfigurierbar

### Out of Scope

- Cloud-basierte Transkription — Parakeet lokal ist ausreichend und privater
- iOS / iPadOS — macOS only
- Team-Features, Sync, Benutzerkonten — Solo-Tool
- Echtzeit-Streaming-Transkription — Push-to-talk reicht

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Parakeet v3 lokal gebundelt | Privatsphäre, offline-fähig, keine Latenz durch Netzwerk | — Pending |
| Groq API für LLM-Post-Processing | Geschwindigkeit (niedrige Latenz), qwen3-32b verfügbar | — Pending |
| Menu Bar App ohne Dock-Icon | Immer verfügbar, nicht ablenkend, System-App-Charakter | — Pending |
| Swift/SwiftUI | Native macOS, beste Accessibility-Integration, kein Electron-Overhead | — Pending |
| Mehrere Prompt-Profile mit eigenen Hotkeys | Flexibel für verschiedene Kontexte (Korrektur, E-Mail-Stil, etc.) | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-15 after initialization*
