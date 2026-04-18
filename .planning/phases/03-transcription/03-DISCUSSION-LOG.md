# Phase 3: Transcription - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-18
**Phase:** 03-transcription
**Areas discussed:** Engine-Wahl, Audio-Buffer-Übergabe, Download-Fortschritt UX, Fehlerbehandlung

---

## Engine-Wahl (Blocker)

| Option | Description | Selected |
|--------|-------------|----------|
| WhisperKit | Pure Swift SPM-Package, MLX/CoreML-beschleunigt, kein Python-Subprocess | ✓ |
| Parakeet v3 | Python/MLX-Subprocess, höchste Englisch-Genauigkeit, Projektbrief-Vorgabe | |

**User's choice:** WhisperKit

---

## WhisperKit-Modell

| Option | Description | Selected |
|--------|-------------|----------|
| distil-large-v3 (~600MB) | Schnell, kompakt, destilliert | |
| large-v3-turbo (~800MB) | Beste Balance Genauigkeit/Geschwindigkeit | ✓ |
| large-v3 (~1.5GB) | Höchste Genauigkeit, größtes Modell | |

**User's choice:** large-v3-turbo (~800MB)

---

## Sprache

| Option | Description | Selected |
|--------|-------------|----------|
| Deutsch (fest) | `language: "de"`, keine Auto-Erkennung | ✓ |
| Automatisch erkennen | WhisperKit erkennt Sprache aus Audio | |
| Einstellbar (Settings) | Sprache als konfigurierbarer Parameter | |

**User's choice:** Deutsch, fest

---

## Audio-Buffer-Übergabe

| Option | Description | Selected |
|--------|-------------|----------|
| In-Memory [Float]-Array | Kein Disk-I/O, WhisperKit-nativ, kein Temp-File | ✓ |
| Temp-WAV-Datei | Disk-basiert, simpler für manche Libraries | |

**User's choice:** In-Memory [Float]-Array

---

## Pipeline-Stub

| Option | Description | Selected |
|--------|-------------|----------|
| Konsolenausgabe, dann Idle | print() + resetToIdle(), minimaler Scope | ✓ |
| Text ins Clipboard | Nützlicher aber überschneidet Phase-4-Scope | |

**User's choice:** Konsolenausgabe, dann Idle

---

## Download-Fortschritt UX

| Option | Description | Selected |
|--------|-------------|----------|
| Menüleisten-Icon + Text | NSStatusItem title "↓ 42%", immer sichtbar | ✓ |
| Menüpunkt-Text | Nur im Dropdown sichtbar | |
| Separates Fenster / HUD | Aufdringlich, mehr Code-Aufwand | |

**User's choice:** Menüleisten-Icon + Text

---

## Download-Start-Zeitpunkt

| Option | Description | Selected |
|--------|-------------|----------|
| Beim App-Start | Sofort beim Launch, Modell bereit vor erster Aufnahme | ✓ |
| Beim ersten Aufnahme-Versuch | Lazy, aber unerwartet für Nutzer | |

**User's choice:** Beim App-Start

---

## Fehler: Transkriptionsfehler

| Option | Description | Selected |
|--------|-------------|----------|
| Stille Rückkehr zu Idle | resetToIdle(), print() auf Konsole | ✓ |
| Fehlertext im Menü | Mehr Aufwand, disabled Menüpunkt | |

**User's choice:** Stille Rückkehr zu Idle

---

## Fehler: Aufnahme während Download

| Option | Description | Selected |
|--------|-------------|----------|
| Aufnahme blockieren | Hotkey/Klick ignoriert bis Modell bereit | ✓ |
| Aufnahme erlauben, dann warnen | Komplizierter Zustandsgraph | |

**User's choice:** Aufnahme blockieren

---

## Claude's Discretion

- WhisperKit-Konfigurationsparameter (computeUnits, chunkingStrategy)
- Mindestsampleanzahl vor Transkriptionsaufruf
- Download-Caching-Pfad
- Debounce für Title-Update-Häufigkeit

## Deferred Ideas

- Sprachauswahl als Settings-Option
- Retry-Logik bei Download-Fehlern
- Parakeet-Integration als Genauigkeits-Option (Backlog)
