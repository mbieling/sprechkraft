# Research Summary — VoiceScribe macOS Dictation App

**Synthesized:** 2026-04-15

## Executive Summary

VoiceScribe ist ein nativer macOS Push-to-Talk-Diktiertool für einen Power-User mit schneller, privater Transkription und LLM-Nachbearbeitung. Der Tech-Stack ist weitgehend klar — **eine Entscheidung blockiert die gesamte Architektur: Parakeet v3 vs. WhisperKit.**

---

## KRITISCHE ENTSCHEIDUNG: Parakeet v3 vs. WhisperKit

Beide Research-Agenten (Stack + Architektur) kamen unabhängig zum gleichen Ergebnis: **Parakeet v3 (`parakeet-mlx`) hat keine Swift-API.** Es ist Python/MLX-only.

| | Path A: Parakeet (Python Bridge) | Path B: WhisperKit (nativ) |
|---|---|---|
| **Modell** | parakeet-tdt-0.6b-v3 (NVIDIA) | Whisper large-v3 (OpenAI) |
| **Integration** | Swift spawnt Python-Subprocess, kommuniziert via stdin/stdout | Swift Package (SPM), sauberes async API |
| **Bundle-Größe** | ~1.5GB+ (Python Runtime + Deps + Modell) | ~1.5GB (nur Modell) |
| **Code Signing** | Komplex — alle Python-Binaries müssen einzeln signiert werden | Standard |
| **Sandbox** | Inkompatibel | Kompatibel |
| **Performance** | MLX auf Apple Silicon = schnell | Neural Engine auf M-Series = schnell |
| **Genauigkeit** | Beste englische ASR verfügbar | Hervorragend, minimal unter Parakeet |
| **Aufwand** | HOCH | NIEDRIG |

**Empfehlung: WhisperKit (Path B) für v1.** Für persönliches Diktat ist der Genauigkeitsunterschied wahrscheinlich nicht wahrnehmbar. Die `TranscriptionService`-Abstraktion ermöglicht später einen sauberen Austausch zu Parakeet, falls nötig.

---

## Recommended Stack

| Layer | Technology | Rationale |
|-------|------------|-----------|
| Language | Swift 6 | Native macOS, Actor-Concurrency |
| UI | SwiftUI + AppKit | SwiftUI für Settings; AppKit `NSStatusItem` für Icon-Animation |
| Audio | AVFoundation `AVAudioEngine` | In-Memory PCM-Buffer, kein Disk-Roundtrip |
| ASR | WhisperKit (oder Parakeet subprocess) | Siehe Entscheidung oben |
| LLM | Groq REST via `URLSession` | Kein Swift SDK; direktes HTTP für 2 API-Calls |
| Text-Injektion | `AXUIElement` + CGEvent Fallback | Einziger systemweiter Mechanismus |
| Hotkeys | `sindresorhus/KeyboardShortcuts` | Sandbox-safe, `onKeyDown`/`onKeyUp` für PTT |
| API-Key | `kishikawakatsumi/KeychainAccess` | `AfterFirstUnlock` für Hintergrund-App |
| Historie | `groue/GRDB.swift` v7.5.0 | FTS5 Volltextsuche; SwiftData hat keine FTS |
| Preferences | `sindresorhus/Defaults` | Type-safe UserDefaults |
| Login Item | `sindresorhus/LaunchAtLogin-modern` | `SMAppService` Wrapper für macOS 13+ |

---

## Table Stakes Features

- Globaler Push-to-Talk-Hotkey (konfigurierbar, Standard `⌥⌘R`)
- Menu Bar only, kein Dock-Icon (`LSUIElement = YES`)
- 4 Icon-Zustände: Idle / Aufnahme / Transkribieren / LLM-Verarbeitung
- Text-Injektion ins aktive Feld via Accessibility API
- Clipboard-Fallback (für Electron-Apps, Terminal, Browser)
- Lokale/Offline-Transkription (Modell gebundelt in App)
- Einstellungsfenster (API-Key, Hotkey, Ausgabemodus, Audio-Gerät)
- Durchsuchbare Transkriptions-Historie (SQLite FTS5)
- Launch at Login

## Differenzierende Features

| Feature | Wert |
|---------|------|
| Mehrere benannte Prompt-Profile mit eigenen Hotkeys | Kein Wettbewerber macht das so sauber |
| LLM-Toggle pro Profil | Rohe Transkription für Notizen, LLM für E-Mails |
| Sofortiger Ausgabemodus-Wechsel (Feld vs. Clipboard) | Ohne Einstellungen öffnen |

---

## Kritische Pitfalls

**C1 — Kein App Sandbox** (in Phase 1 entscheiden, nie mehr ändern)
Globale Hotkeys + Cross-Process-Text-Injektion = nicht sandboxfähig. Direktvertrieb (notarisiert, kein Sandbox).

**C2 — Accessibility Permission: Stille Fehler**
`AXUIElement` schlägt ohne Fehlermeldung fehl wenn keine Berechtigung. `AXIsProcessTrusted()` bei jeder Injektion prüfen. Permission wird nach App-Updates still widerrufen.

**C3 — AVAudioEngine crasht bei Gerätewechsel**
Kopfhörer anstecken/trennen invalidiert die Engine. `AVAudioEngineConfigurationChangeNotification` beobachten und Engine-Graph neu aufbauen — von Anfang an.

**C4 — Model Loading muss async sein**
1.5GB synchron laden = 2-20 Sekunden Freeze. `MLModel.load` async, beim App-Start, mit Lade-Indikator im Icon.

**I1 — Text-Injektion schlägt in Electron/Terminal fehl**
VS Code, Slack, Notion, Terminal ignorieren `kAXValueAttribute`. Zwei-Stufen-Strategie von Anfang an: AX → CGEvent Keystroke → Clipboard.

---

## Vorgeschlagene Build-Reihenfolge

| Phase | Was | Gate |
|-------|-----|------|
| 1 — App Shell | `NSStatusItem`, `LSUIElement`, PTT-Hotkey, Entitlements (kein Sandbox) | Tastendruck ändert Icon-Farbe |
| 2 — Audio Capture | `AVAudioEngine` Tap, Mic-Permission, Gerätewechsel-Handler | `stopRecording()` gibt nicht-leeres `[Float]` zurück |
| 3 — Transkription | `TranscriptionService` (WhisperKit), async Model Loading | Korrektes Transkript aus gespeichertem Audio |
| 4 — Text-Injektion | `TextOutputService` (AX + CGEvent + Clipboard) | Hardcodierter String erscheint in VS Code, Terminal, TextEdit |
| 5 — E2E-Pipeline | Hotkey → Audio → Transkription → Injektion verdrahten | Vollständiges PTT-Diktat funktioniert |
| 6 — Historie | GRDB, `TranscriptionRecord`, FTS5, WAL | Einträge nach Diktat abfragbar |
| 7 — LLM + Profile | `PromptProfile`, `GroqService`, Fehlerbehandlung | Transkript transformiert mit echtem API-Key |
| 8 — Settings UI | `KeychainService`, `SettingsView`, Profil-Editor, Hotkey-Recorder | API-Key überlebt Neustart; Profile editierbar |
| 9 — Polish | Login-Item, Onboarding, Fehlerzustände, Icon-Animation, Audio-Cues | First-Run-Experience vollständig |

---

## Offene Fragen (vor Phase 1 klären)

1. **Parakeet vs WhisperKit?** — Blockiert gesamte Phase 3
2. **macOS Mindestversion?** — Stack zielt auf macOS 14+; 13 möglich mit kleineren Anpassungen
3. **Modell gebundelt oder Download bei Erststart?** — ~1.5GB in App vs. Setup-Step bei Erststart
4. **Standard-Hotkey?** — `⌥⌘R` empfohlen (keine bekannten Konflikte)
