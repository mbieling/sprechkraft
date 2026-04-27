# Project Research Summary

**Project:** SPRECHKRAFT — macOS Menu Bar Dictation App
**Domain:** Native macOS, lokale ASR, globaler Hotkey, LLM-Nachbearbeitung
**Researched:** 2026-04-21 (Milestone v0.19.0: Parakeet + Settings)
**Confidence:** HIGH

## Executive Summary

SPRECHKRAFT ist eine native macOS Menu-Bar-Diktat-App der Kategorie "systemweite Push-to-Talk-Sprachsteuerung". Die Kernanforderungen — globale Hotkeys, Text-Injektion in beliebige Fremdfenster, vollständig lokale Inferenz — schließen App-Sandbox und Mac-App-Store-Distribution aus. Der richtige Stack ist: Swift 6 + AppKit (NSStatusItem), AVFoundation für Audio-Capture, und ein austauschbares Transkriptions-Backend hinter einem `TranscriptionBackend`-Protokoll.

Die wichtigste architektonische Entdeckung dieser Recherche: **FluidAudio (FluidInference/FluidAudio v0.12.4)** macht die Python-Subprocess-Brücke unnötig. FluidAudio ist ein natives Swift-SPM-Paket, das Parakeet TDT v3 via CoreML/Neural Engine bereitstellt — 66 MB RAM statt ~2 GB MLX, ~110x Realtime-Factor auf M4 Pro, und direkte Swift-API ohne venv-Bundling, SIP-Kompatibilitätsprobleme oder codesign-Aufwand für hunderte `.so`-Dateien. Die Python-Subprocess-Variante bleibt als dokumentierter Fallback bestehen, ist aber nicht mehr der empfohlene Weg.

Die größten Risiken des Milestones v0.19.0 liegen in der Build-Infrastruktur: Sollte FluidAudio nicht ausreichen und die Python-Bridge benötigt werden, sind SIP-Stripping von DYLD-Variablen (C5), Pipe-Deadlock durch nicht-concurrent stdout/stderr-Drain (C6) und unsigned Mach-O-Binaries im Bundle (C7) die wahrscheinlichsten Show-Stopper. Unabhängig davon muss die Settings-Erweiterung die `@Default`+MenuBarExtra-Freeze-Regression (I10) und den programmatischen Settings-Window-Öffner (I11, nur macOS 14+) berücksichtigen.

---

## Key Findings

### Recommended Stack

Der Stack ist vollständig etabliert und erfordert für Milestone v0.19.0 nur **ein neues SPM-Paket**: FluidAudio. Alle anderen Libraries (KeyboardShortcuts, KeychainAccess, LaunchAtLogin-modern, GRDB.swift, Defaults) sind bereits vorhanden. Python-Bundling entfällt beim FluidAudio-Ansatz vollständig.

**Core technologies:**
- Swift 6 / AppKit (NSStatusItem): Menu-Bar-Shell — volle Kontrolle über Icon-Animation und Hotkey-Events
- AVFoundation (AVAudioEngine): In-Memory-PCM-Buffer-Capture via installTap — kein Disk-Roundtrip
- FluidAudio v0.12.4 (SPM): Parakeet TDT v3 nativ in Swift via CoreML/Neural Engine — **primäre Empfehlung**
- Python/MLX-Subprocess (parakeet-mlx + uv + py-app-standalone): Fallback falls FluidAudio nicht ausreicht
- URLSession (Foundation): Groq REST API (OpenAI-kompatibel) — kein Swift SDK nötig
- AXUIElement + NSPasteboard/CGEvent: Text-Injektion, zweistufige Strategie
- GRDB.swift v7.5.0: SQLite-History mit FTS5-Volltextsuche
- sindresorhus/Defaults: Type-safe UserDefaults für alle Präferenzen
- KeyboardShortcuts: User-konfigurierbarer globaler Hotkey, Mac-App-Store-sicher

**Kritische Versionsentscheidungen:**
- macOS 14+ als Deployment Target (erlaubt `@Environment(\.openSettings)`, schließt I11-Workaround aus)
- FluidAudio v0.12.4: Context7 verifiziert, 1500+ GitHub Stars, in VoiceInk und 20+ Production-Apps im Einsatz

### Expected Features

**Must have (Table Stakes) — v0.19.0:**
- Parakeet v3 Transkription (ersetzt WhisperKit): `result.text` aus PCM-Samples via FluidAudio
- Model-Download beim Erststart mit Fortschrittsbalken — ohne dies wirkt die App eingefroren
- Größenangabe vor Download ("ca. X GB") — Nutzer muss informiert entscheiden können
- Klarer Fehlerfall und Retry-Button wenn Download scheitert
- Download-Phase als eigener App-State — kein Diktat-Versuch bevor Modell bereit
- Settings-Fenster: Hotkey-Konfiguration mit Konflikt-Erkennung
- Settings-Fenster: Mikrofon-Auswahl
- Settings-Fenster: Ausgabemodus (Textfeld / Clipboard)
- Settings-Fenster: Groq API-Key (aus ProfileEditorSheet herauslösen)
- Settings-Fenster: Profil-Verwaltung (konsolidiert)
- Settings-Fenster: Launch at Login
- Settings-Fenster: Modell-Status + Retry

**Should have (Differenziator):**
- Warm-up-Indikator beim App-Start ("Modell wird geladen...")
- Konfidenzwert aus `result.sentences[].confidence` in History speichern
- Silence-Detection-Schwellenwert in Settings (aus PROJECT.md explizit gefordert)
- Geschätzte Restzeit beim Download ("ca. 2 Minuten verbleibend")

**Defer to v2+:**
- Quantisiertes 8-Bit-Modell als Alternative (~909 MB)
- Download abbrechen und fortsetzen (HF Hub: kein resumable download)
- Export/Import von Profilen als Datei
- Toggle-Modus vs. PTT (PTT ist Standard und sicherer)

**Anti-Features (explizit ausschließen):**
- Sprach-Selektor (Parakeet v3 primär English-optimiert)
- Multiple LLM-Provider in v1
- Modell ins App-Bundle bundeln (~1.2 GB Download)

### Architecture Approach

Die Architektur baut auf dem Facade-Pattern: `TranscriptionService` (actor) delegiert an ein austauschbares `TranscriptionBackend`-Protokoll. Milestone v0.19.0 implementiert `ParakeetBackend` mit FluidAudio als primäre Implementierung und behält `WhisperKitBackend` als Fallback. AppDelegate bleibt unverändert — der Aufruf `transcriptionService.transcribeWithResampling(samples, sampleRate:)` ist API-stabil. Das bestehende Settings-Window-Pattern (`Window(id: "settings")` + NotificationCenter-Brücke) wird beibehalten und mit neuen `Section()`-Blöcken erweitert.

**Major components:**
1. `AppDelegate` (NSStatusItem, Hotkeys, Callbacks) — Koordinator; bleibt in v0.19.0 unverändert
2. `TranscriptionService` (actor, Facade) — delegiert an `TranscriptionBackend`-Implementierung
3. `ParakeetBackend` (actor, FluidAudio) — neu; `AsrModels.downloadAndLoad` + `AsrManager.transcribe`
4. `WhisperKitBackend` (actor, Refaktor) — bestehender TranscriptionService-Code extrahiert als Fallback
5. `SettingsView` (SwiftUI Form) — erweitert um Hotkey-Sektion und Transkriptions-Status-Sektion
6. Audio / Groq / TextOutput / HistoryStore — unverändert

**Datenfluss nach v0.19.0:**

```
onRecordingComplete
  -> TranscriptionService.transcribeWithResampling()
     -> ParakeetBackend.transcribeWithResampling()
        -> AsrManager.transcribe()  [FluidAudio, CoreML/ANE]
           -> String?
```

### Critical Pitfalls

Für Milestone v0.19.0 show-stopper-relevante Pitfalls, die vor Wave 1 adressiert sein müssen:

1. **C4 — Model Loading blockiert Main Thread** — FluidAudio-API ist async (`try await AsrModels.downloadAndLoad`); Aufruf nur aus Background-Task, nie von `@MainActor`. Model-Loading Architecture muss initial korrekt sein.

2. **I8 — Metal Shader Warmup (5–15 Sekunden)** — Warmup-Inferenz mit Dummy-Audio nach Model-Load senden; "Warming up..." Status im Menu Bar Icon anzeigen. Muss in Startup-Sequenz eingebaut werden, nicht nachgerüstet.

3. **I10 — Defaults + MenuBarExtra Freeze Loop** — `@Default` nicht direkt im MenuBarExtra-View-Body verwenden. `.window`-Style oder lokales `@State` das außerhalb des Render-Zyklus befüllt wird.

4. **I11 — Settings programmatisch öffnen** — `@Environment(\.openSettings)` ist macOS 14+ only; Deployment Target muss auf macOS 14 gesetzt sein (bereits in CLAUDE.md festgelegt).

5. **C5 — SIP entfernt DYLD-Variablen** (Python-Fallback) — `python-build-standalone` mit eingebackenem `@rpath` verwenden. Signierte Production-Builds immer außerhalb Xcode testen.

6. **C6 — Pipe-Deadlock** (Python-Fallback) — stdout und stderr immer concurrent drainieren mit `async let stdout = ...; async let stderr = ...`.

7. **C7 — Unsigned .so/.dylib** (Python-Fallback) — Build-Script das alle Mach-O-Binaries im Bundle vor dem finalen App-Signing signiert (innerste zuerst).

---

## Implications for Roadmap

Milestone v0.19.0 hat zwei parallele Hauptarbeitsströme: **Parakeet-Backend** (ersetzt WhisperKit) und **Settings-Erweiterung** (konsolidiert bestehende Fragmente). Die Architektur zeigt drei klare Waves.

### Wave 1: TranscriptionBackend-Protokoll + FluidAudio (Blockiert alles andere)

**Rationale:** Alle anderen Änderungen hängen davon ab, dass ein funktionierendes Parakeet-Backend existiert. AppDelegate.setupTranscription() und die Model-Status-Anzeige in Settings brauchen `isModelReady` aus dem neuen Backend.
**Delivers:** Lauffähige Parakeet-Transkription via FluidAudio; WhisperKit als dokumentierter Fallback erhalten
**Features:** Parakeet v3 Engine-Swap, Download + Progress, Model-Ready-Guard, Warmup
**Stack:** FluidAudio SPM (neu hinzufügen), TranscriptionBackend Protokoll (neue Datei), ParakeetBackend actor (neue Datei)
**Pitfalls to avoid:** C4 (async model load), I8 (warmup inference), FluidAudio Progress-Handler-Validierung
**Unveränderter bestehender Code:** AppDelegate.onRecordingComplete, AppState.isModelReady, setupTranscription()-Aufruf

### Wave 2: Settings-Erweiterungen (Parallel zu Wave 1 ausführbar)

**Rationale:** Settings-UI-Erweiterungen haben keine Abhängigkeit auf das Transkriptions-Backend; nur die Modell-Status-Sektion braucht `isModelReady` aus AppState (bereits vorhanden).
**Delivers:** Konsolidiertes Settings-Fenster mit allen Konfigurationsoptionen
**Features:** Hotkey-Konfiguration (KeyboardShortcuts.Recorder), Transkriptions-Engine-Status, Modell-Retry
**Pitfalls to avoid:** I10 (Defaults + MenuBarExtra), I11 (openSettings macOS 14+), I12 (KeyboardShortcuts first responder)
**Erweiterter bestehender Code:** SettingsView.swift (neue Sections); kein neues Window-Pattern

### Wave 3: Integration & Validierung

**Rationale:** End-to-End-Tests erst wenn beide Arbeitsströme stabil sind. Qualitätsvergleich WhisperKit vs. Parakeet auf Deutsch braucht beide Backends.
**Delivers:** Validierter v0.19.0-Release; Qualitätsbaseline für Parakeet auf Deutsch
**Tests:** Diktat → ParakeetBackend → TextOutput → HistoryStore; Download-Fortschritt-UX; Memory-Profil (8 GB Mac)

### Phase Ordering Rationale

- Wave 1 vor Wave 3, weil End-to-End ohne Parakeet nicht möglich
- Wave 2 parallel zu Wave 1, da Settings keine Backend-Abhängigkeit hat
- FluidAudio vor Python-Bridge, weil der gesamte C5/C6/C7-Pitfall-Cluster entfällt
- TranscriptionBackend-Protokoll als erstes Artefakt, damit WhisperKitBackend-Extraktion und ParakeetBackend-Implementierung parallel möglich sind

### Research Flags

**Validierung beim ersten Build notwendig:**
- **Wave 1 / FluidAudio Progress-Handler:** `AsrModels.downloadAndLoad(version: .v3)` — hat es einen Progress-Handler? Context7 zeigt Handler nur für `LSEENDModelDescriptor`; für v3-API in FluidAudio-Source prüfen. Fallback: Fake-Progress ist akzeptabel.
- **Wave 1 / Swift 6 Concurrency:** `@preconcurrency import FluidAudio` ggf. nötig (wie schon bei WhisperKit).
- **Wave 3 / Deutsch-Qualität:** Parakeet TDT v3 trainiert auf 85k Std. Englisch + 25 EU-Sprachen inkl. Deutsch; echter Sprachtest nötig.

**Kein zusätzlicher Research-Bedarf (Standard-Pattern):**
- **Wave 2 / Settings-UI:** Vollständig dokumentiertes SwiftUI-Pattern; KeyboardShortcuts.Recorder in Context7 dokumentiert.
- **Wave 1 / TranscriptionBackend-Protokoll:** Standard Swift-Actor-Protokoll-Pattern.
- **Wave 3 / Integration:** Smoke-Test und Instruments-Profiling; kein Forschungsbedarf.

---

## Confidence Assessment

| Bereich | Confidence | Anmerkungen |
|---------|------------|-------------|
| Stack | HIGH | Alle Kern-Libraries via Context7 verifiziert; FluidAudio v0.12.4 aus Context7 mit Score 89.75, 1500+ Stars |
| Features | MEDIUM-HIGH | Parakeet-API HIGH (Context7); Modellgröße MEDIUM (Community-Daten); HF-Hub Download-Progress MEDIUM (API-Details brauchen Hands-on) |
| Architecture | HIGH | FluidAudio-Integration vollständig dokumentiert; Facade-Pattern aus Codebase-Analyse der bestehenden TranscriptionService-Struktur abgeleitet |
| Pitfalls | HIGH für macOS/Swift/CoreML; MEDIUM für Parakeet/MLX-spezifisches Verhalten | Python-Bridge-Pitfalls bleiben relevant als Fallback-Dokumentation |

**Overall confidence:** HIGH

### Gaps to Address

- **FluidAudio Progress-Handler für v3:** Beim ersten SPM-Resolve in Xcode prüfen; `AsrModels.downloadAndLoad`-Signatur in FluidAudio-Source ansehen. Fallback (Fake-Progress) ist bereit.
- **HF-Hub-Download-Progress (Python-Fallback):** `snapshot_download` hat keinen eingebauten Progress-Hook für Gesamtgröße; braucht `tqdm`-Integration oder manuelles Polling — nur bei Python-Bridge relevant.
- **Model-Cache-Verzeichnis:** FluidAudio cached in `~/Library/Application Support/FluidAudio/Models`; prüfen ob Re-Download-Feature durch Cache-Dir-Leeren funktioniert.
- **Daemon-Prozess-Lebensdauer (Python-Fallback):** Crash-Recovery, App-Termination-Handler — Pattern bekannt, Fehlerbehandlung braucht Hands-on-Validierung.

---

## Sources

### Primary (HIGH confidence)
- FluidAudio: Context7 `/fluidinference/fluidaudio` — Score 89.75; v0.12.4-API, AsrManager, AsrModels
- parakeet-mlx: Context7 `/senstella/parakeet-mlx` — Score 84.3; Python-API, cache_dir, result.text
- KeyboardShortcuts: Context7 `/sindresorhus/keyboardshortcuts` — Recorder-API, onKeyDown/onKeyUp
- GRDB.swift: Context7 `/groue/grdb.swift` — FTS5, DatabasePool, async observation
- SwiftUI Docs: Context7 `/websites/developer_apple_swiftui` — MenuBarExtra, NavigationSplitView, Settings
- Groq API: Context7 `/websites/console_groq` — OpenAI-kompatibel, kein offizielles Swift SDK bestätigt
- Apple AVFoundation Docs: Standard macOS audio capture pattern
- Apple AXUIElement Docs: kAXSelectedTextAttribute vs kAXValueAttribute

### Secondary (MEDIUM confidence)
- mlx-community/parakeet-tdt-0.6b-v3: Hugging Face Model Card — Modellgröße ~1.1–1.3 GB bfloat16
- animaslabs/parakeet-tdt-0.6b-v3-mlx-8bit: Hugging Face — 909 MB quantisiert
- py-app-standalone (jlevy/GitHub): install_name_tool-Fix für relocatable Python-Bundle
- steipete.me: Settings from macOS menu bar items — Activation-Policy-Workaround
- Python subprocess pipe deadlock: docs.python.org, POSIX behavior

### Tertiary (LOW confidence / Hands-on validation needed)
- FluidAudio AsrModels.downloadAndLoad Progress-Handler für v3: Context7-Doku nicht eindeutig — im ersten Build verifizieren
- MLX memory pressure / kernel panic: GitHub mlx-lm issue #883 + Community-Posts
- MLX warmup latency / Metal cache: deepwiki.com community benchmark
- Defaults + MenuBarExtra freeze: GitHub sindresorhus/Defaults issue #144 — confirmed library issue

---
*Research completed: 2026-04-21*
*Milestone: v0.19.0 (Parakeet + Settings)*
*Ready for roadmap: yes*
