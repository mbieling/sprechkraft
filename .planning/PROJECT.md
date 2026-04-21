# VoiceScribe: Lokale Diktat-App für macOS

## Current Milestone: v0.19.0 Parakeet + Settings

**Ziel:** Parakeet v3 ersetzt WhisperKit als lokale Transkriptions-Engine, und ein vollständiges Einstellungsfenster konsolidiert alle App-Konfiguration.

**Target Features:**
- Parakeet v3 via gebundeltem Python/MLX-venv (kein System-Python, kein Cloud-Zugriff)
- Modell-Download beim Erststart mit Fortschrittsanzeige
- Konsolidiertes Einstellungsfenster (API-Key, Profile, Ausgabemodus)
- Hotkey-Konfiguration UI mit Konflikt-Erkennung
- Mikrofon-Auswahl (Dropdown für Eingabegerät)
- Silence Detection Threshold (einstellbar)

---

## What This Is

Eine native macOS Menu-Bar-App für systemweites Diktat. Der Nutzer hält einen globalen Hotkey gedrückt, spricht, lässt los — und der Text erscheint entweder direkt im aktiven Textfeld oder im Clipboard. Transkription läuft vollständig lokal via Parakeet v3 (gebundelt in der App). Optional durchläuft das Transkript eines von mehreren KI-Prompt-Profilen via Groq API (qwen/qwen3-32b), bevor der Text ausgegeben wird.

Inspiration: https://tryvoiceink.com

## Core Value

Text per Sprache eingeben, genau wie tippen — schnell, systemweit, ohne Fenster wechseln zu müssen.

## Target User

Der Entwickler selbst (Power-User, Mac-Nutzer, der schnelles qualitatives Diktat mit KI-Nachbearbeitung will).

## Context

- Greenfield macOS-Projekt, Native Swift/SwiftUI
- Lokale Transkription: Parakeet v3 (NVIDIA ASR), via Python/MLX-Subprocess, Modell-Download beim Erststart
- LLM Post-Processing: Groq API mit qwen/qwen3-32b
- Kein Cloud-Transkriptions-Dienst, maximale Privatsphäre
- Vertrieb: Nur lokal (kein App Store, kein Signing/Notarisierung nötig)

## How It Works

1. **Hotkey halten** → Aufnahme startet, Menüleisten-Icon animiert
2. **Sprechen**
3. **Loslassen** → Parakeet transkribiert lokal
4. **KI optional** → Aktives Prompt-Profil geht an Groq (qwen3-32b)
5. **Ausgabe** → ins aktive Textfeld (via Accessibility) oder Clipboard
6. **Gespeichert** → Transkription in lokaler, durchsuchbarer Historie

## Requirements

### Validated

- Menu Bar App ohne Dock-Icon (LSUIElement=YES, .accessory activation policy) — Validated in Phase 01: app-shell
- 4 Icon-Zustände (idle/recording/transcribing/llmProcessing) mit Farbe und Pulse-Animation — Validated in Phase 01: app-shell
- Globaler Hotkey ⌥⌘R systemweit via KeyboardShortcuts — Validated in Phase 01: app-shell
- Autostart beim Login via LaunchAtLogin-modern — Validated in Phase 01: app-shell

### Active

**Aufnahme & Transkription**
- [ ] Globaler Hotkey startet/stoppt Aufnahme (konfigurierbar)
- [ ] Parakeet v3 läuft lokal via Python/MLX-Subprocess (Modell-Download beim Erststart)
- [ ] Menüleisten-Icon ändert Farbe/Animation während Aufnahme und Verarbeitung

**Ausgabe**
- [ ] Text erscheint im aktiven Textfeld (via Accessibility API)
- [ ] Alternativ: Text in Clipboard — Modus einstellbar
- [ ] Ausgabemodus per Einstellung oder Hotkey wechselbar

**KI-Prompt-Profile**
- [x] Mehrere editierbare Prompt-Profile (Name, Prompt-Text, Hotkey) — Validated in Phase 05: llm-prompt-profiles
- [x] Groq API (qwen/qwen3-32b) verarbeitet Transkript via aktivem Profil — Validated in Phase 05: llm-prompt-profiles
- [x] KI-Verarbeitung pro Profil aktivierbar/deaktivierbar — Validated in Phase 05: llm-prompt-profiles
- [x] Groq API-Key sicher speicherbar (macOS Keychain) — Validated in Phase 05: llm-prompt-profiles

**Geschichte & Einstellungen**
- [x] Alle Transkriptionen lokal gespeichert — Validated in Phase 06: history
- [x] Durchsuchbare Historie (FTS5, Copy-Flash, Löschen) — Validated in Phase 06: history
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
| Parakeet v3 via Python/MLX-Subprocess | Beste ASR-Genauigkeit; Python-Bridge akzeptabel da nur lokaler Einsatz | ✓ Entschieden |
| Modell-Download beim Erststart | App-Download klein, Modell (~1.5GB) lädt beim ersten Start | ✓ Entschieden |
| Nur lokale Distribution (kein App Store) | Kein Signing/Notarisierung nötig; globale Hotkeys + Text-Injektion uneingeschränkt | ✓ Entschieden |
| Groq API für LLM-Post-Processing | Geschwindigkeit (niedrige Latenz), qwen3-32b verfügbar | ✓ Entschieden |
| Menu Bar App ohne Dock-Icon | Immer verfügbar, nicht ablenkend, System-App-Charakter | ✓ Entschieden |
| Swift/SwiftUI + AppKit (NSStatusItem) | Native macOS, NSStatusItem für Icon-Animation, SwiftUI für Settings | ✓ Entschieden |
| Mehrere Prompt-Profile mit eigenen Hotkeys | Flexibel für verschiedene Kontexte (Korrektur, E-Mail-Stil, etc.) | ✓ Entschieden |

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
*Last updated: 2026-04-21 — Milestone v0.19.0 gestartet*
