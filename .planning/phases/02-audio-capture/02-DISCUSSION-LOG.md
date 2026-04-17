# Phase 2: Audio Capture - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-17
**Phase:** 02-audio-capture
**Areas discussed:** Level-Meter im Icon, Audio-Cue Design, Stille-Erkennung & Auto-Stopp, Mikrofon-Auswahl UI

---

## Level-Meter im Icon

| Option | Description | Selected |
|--------|-------------|----------|
| Mehrere Balken (Equalizer) | 3–5 schmale senkrechte Bars, heben/senken sich mit dem Pegel | |
| Pulse-Skalierung | Bestehende Pulse wird pegel-responsiv (schneller/größer bei hohem Pegel) | |
| Waveform-Linie | Dünne Linie unterhalb des Mic-Symbols, oscilliert als Mini-Waveform | ✓ |

**User's choice:** Waveform-Linie

---

### Position der Waveform

| Option | Description | Selected |
|--------|-------------|----------|
| Unterhalb des Icons | Linie direkt unter dem Mic-Symbol | ✓ |
| Über dem Icon | Linie oben, Mic darunter | |
| Überlagernd im Hintergrund | Transparent hinter Mic-Symbol | |

**User's choice:** Unterhalb des Icons

---

## Audio-Cue Design

| Option | Description | Selected |
|--------|-------------|----------|
| NSSound System-Töne | macOS-eigene Töne (Tink, Pop, etc.), kein Bundle-Overhead | ✓ |
| Eigene Töne (WAV/AIFF) | Gebündelte Audiodateien, mehr Kontrolle | |
| AVAudioEngine-generiert | Sinustöne per Code, kein Asset nötig | |

**User's choice:** NSSound System-Töne

---

### Start vs. Stopp Ton

| Option | Description | Selected |
|--------|-------------|----------|
| Unterschiedliche Töne | Heller Ton für Start, tieferer für Stopp | ✓ |
| Gleicher Ton | Derselbe NSSound für Start und Stopp | |

**User's choice:** Unterschiedliche Töne

---

## Stille-Erkennung & Auto-Stopp

### Standard-Stille-Dauer

| Option | Description | Selected |
|--------|-------------|----------|
| 1.5 Sekunden | Kurze Pause, rasches Reagieren | ✓ |
| 2.5 Sekunden | Mehr Spielraum bei Denkpausen | |
| 3 Sekunden | Für langsames Sprechen | |

**User's choice:** 1.5 Sekunden

---

### Auto-Stopp Cue

| Option | Description | Selected |
|--------|-------------|----------|
| Gleicher Stopp-Ton | Auto-Stopp und manueller Stopp klingen gleich | ✓ |
| Kein Ton bei Auto-Stopp | Lautloser Auto-Stopp, Icon-Änderung zeigt es | |

**User's choice:** Gleicher Stopp-Ton

---

## Mikrofon-Auswahl UI

### Platzierung

| Option | Description | Selected |
|--------|-------------|----------|
| Nur im Settings-Fenster | Dropdown im bestehenden Einstellungs-Fenster | ✓ |
| Nur im Menü | Direktzugriff ohne Settings zu öffnen | |
| Beides | Settings-Fenster + Schnellzugriff im Menü | |

**User's choice:** Nur im Settings-Fenster

---

### Mikrofonberechtigung fehlt

| Option | Description | Selected |
|--------|-------------|----------|
| Banner in Settings + System-Einstellungen öffnen | Roter Hinweis mit Button | ✓ |
| Fehlermeldung im Menü | Menüpunkt statt normaler Aufnahme | |
| Beim Hotkey-Drücken anzeigen | Alert erst beim Aufnahme-Versuch | |

**User's choice:** Banner im Settings-Fenster + Button öffnet macOS Datenschutz-Einstellungen

---

## Claude's Discretion

- Genaue NSSound-Namen für Start und Stopp
- AVAudioEngine Tap-Puffer-Größe und Samplerate
- RMS-Schwellwert-Wert für Stille-Erkennung
- Waveform-Linien-Rendering: Sample-Anzahl und Canvas-Größe

## Deferred Ideas

Keine — Diskussion blieb im Phase-Scope.
