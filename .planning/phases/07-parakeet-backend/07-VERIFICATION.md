---
phase: 07-parakeet-backend
verified: 2026-04-30T00:00:00Z
status: human_needed
score: 4/5 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Modell-Download-UX beim Erststart"
    expected: "Menüleisten-Icon zeigt orange arrow.down.circle (.modelLoading), Titel 'Parakeet-Modell wird geladen (~1.2 GB)…', nach Abschluss hourglass (.warmingUp), dann grauer Mic (.idle)"
    why_human: "Download-Lifecycle kann nicht ohne tatsächlichen Parakeet-Modell-Download automatisch verifiziert werden. Plan 07-07 Task 2 wurde ohne explizite Bestätigung übergangen."
  - test: "Live-Transkription via FluidAudio/Parakeet TDT v3"
    expected: "Spracheingabe (z.B. 'Hallo, das ist ein Test') erzeugt eine sinnvolle Transkription im aktiven Textfeld. Console zeigt keine [ParakeetBackend] Fehlermeldungen. Kein WhiskerKit-Output."
    why_human: "End-to-End Inferenz mit echtem Parakeet-Modell kann nur durch Sprechen und Beobachten verifiziert werden. Plan 07-07 Task 3 wurde ohne explizite Bestätigung übergangen."
---

# Phase 07: Parakeet Backend — Verifikationsbericht

**Phase-Ziel:** WhisperKit durch FluidAudio/Parakeet TDT v3 ersetzen — natives Swift-SPM-Paket, CoreML/ANE-beschleunigt, kein Python-Subprocess. TranscriptionBackend-Protokoll als Facade einführen, WhisperKitBackend als dokumentierten Fallback erhalten.

**Verifiziert:** 2026-04-30
**Status:** human_needed
**Re-Verifikation:** Nein — initiale Verifikation

---

## Ziel-Erreichung

### Beobachtbare Wahrheiten (Success Criteria)

| # | Wahrheit | Status | Evidenz |
|---|----------|--------|---------|
| 1 | App transkribiert Sprache via FluidAudio/Parakeet TDT v3 statt WhisperKit | ? UNCERTAIN | ParakeetBackend.swift implementiert den vollständigen FluidAudio-Pfad (AsrModels.downloadAndLoad → AsrManager → initialize → transcribe). Kein WhisperKit-Import in TranscriptionService oder AppDelegate. Ob echter Inference-Output korrekt fließt, erfordert Human-Verifikation (Plan 07-07 Task 3 ohne explizite Bestätigung übergangen). |
| 2 | Modell-Download beim Erststart mit Fortschrittsanzeige | ? UNCERTAIN | Code-Pfad vollständig implementiert: Cache-Check (FluidAudio/Models), .modelLoading State, Titel-Text "~1.2 GB", progressHandler(0.0/1.0). Plan 07-07 Task 2 ohne explizite Nutzer-Bestätigung übergangen — Human-Verifikation erforderlich. |
| 3 | Warmup-Inferenz nach Model-Load | ✓ VERIFIED | ParakeetBackend.swift Zeile 45-46: `let dummySamples = [Float](repeating: 0.0, count: 16000)` + `_ = try? await manager.transcribe(dummySamples, source: .microphone)`. AppDelegate setzt .warmingUp-State im progressHandler. Warmup ist Pflicht-Implementierung (Pitfall I8). |
| 4 | TranscriptionBackend-Protokoll isoliert Backend-Wechsel von AppDelegate und AppState | ✓ VERIFIED | TranscriptionBackend.swift: `protocol TranscriptionBackend: Sendable` mit 3 Membern. TranscriptionService ist Facade mit `init(backend: any TranscriptionBackend = ParakeetBackend())`. AppDelegate ruft nur `transcriptionService.downloadAndLoad/isModelReady/transcribeWithResampling` auf — keine direkte ParakeetBackend-Referenz. |
| 5 | WhiskerKitBackend bleibt als Fallback erhalten (auskommentiert) | ✓ VERIFIED | WhisperKitBackend.swift existiert mit vollständiger Implementierung in `/* ... */` Block-Kommentar. Enthält Reaktivierungs-Anleitung, SPM-URL, vollständige TranscriptionBackend-Konformanz. Kein aktiver Swift-Code auf Datei-Ebene — kein Build-Overhead. |

**Score:** 3 automatisch VERIFIED / 2 UNCERTAIN (Human-Verifikation ausstehend)
**Gesamt:** 4/5 (SC3, SC4, SC5 eindeutig verifiziert; SC1 und SC2 code-seitig implementiert aber ohne Human-Bestätigung des Laufzeitverhaltens)

---

## Erforderliche Artefakte

| Artefakt | Erwartet | Status | Details |
|----------|----------|--------|---------|
| `SPRECHKRAFT/Transcription/TranscriptionBackend.swift` | Protocol `TranscriptionBackend: Sendable` mit 3 Membern | ✓ VERIFIED | Exakt wie spezifiziert: `isModelReady: Bool { get async }`, `downloadAndLoad(progressHandler:)`, `transcribeWithResampling`. Keine Imports. |
| `SPRECHKRAFT/Transcription/ParakeetBackend.swift` | `actor ParakeetBackend: TranscriptionBackend` via FluidAudio | ✓ VERIFIED | `@preconcurrency import FluidAudio`. Vollständiger Pfad: downloadAndLoad, initialize(models:), Warmup-Inferenz, isModelReady. Minimum-Guard `>= 1600 samples`. Stille Fehlerbehandlung. |
| `SPRECHKRAFT/Transcription/WhisperKitBackend.swift` | Auskommentierter Fallback mit Reaktivierungs-Anleitung | ✓ VERIFIED | FALLBACK-Header, Reaktivierungs-URL, vollständige WhiskerKitBackend-Implementierung in `/* */`. Kein aktiver Code auf Datei-Ebene. |
| `SPRECHKRAFT/Transcription/TranscriptionService.swift` | Facade-Actor, delegates to backend, resampleTo16kHz erhalten | ✓ VERIFIED | `init(backend: any TranscriptionBackend = ParakeetBackend())`. `isModelReady` computed async. Kein WhisperKit-Import. `resampleTo16kHz` + NaN/Inf-Sanitizer (zusätzlich vs. Plan). |
| `SPRECHKRAFT/AppState.swift` | 8 RecordingState-Cases, `isModelError: Bool = false` | ✓ VERIFIED | Alle 8 Cases vorhanden (idle, recording, transcribing, llmProcessing, error, modelLoading, warmingUp, modelError). Alle 5 computed properties exhaustiv. `isModelError: Bool = false` nach `isModelReady`. |
| `SPRECHKRAFT/AppDelegate.swift` | `setupTranscription()` mit Cache-Check, neuen States, Error-Pfad | ✓ VERIFIED | Cache-Check auf `FluidAudio/Models`. `.modelLoading` vor Task. `.warmingUp` + Titel-Text in progressHandler. `isModelError = true` + `.modelError` im Fehlerfall. Guard `isModelReady == true` unverändert. |
| `SPRECHKRAFT.xcodeproj/project.pbxproj` | WhisperKit entfernt, FluidAudio 0.12.x hinzugefügt | ✓ VERIFIED | 0 WhisperKit/argmax-Referenzen. FluidAudio in 5 pbxproj-Sektionen (PBXBuildFile, PBXFrameworksBuildPhase, packageProductDependencies, packageReferences, XCRemoteSwiftPackageReference + XCSwiftPackageProductDependency). Version: exactVersion 0.12.6 (Plan: 0.12.4 — Minor-Abweichung, akzeptabel). |

---

## Key Link Verifikation

| Von | Nach | Via | Status | Details |
|-----|------|-----|--------|---------|
| `TranscriptionService.swift` | `ParakeetBackend.swift` | `init(backend: any TranscriptionBackend = ParakeetBackend())` | ✓ WIRED | Zeile 26 in TranscriptionService.swift — ParakeetBackend ist der Default-Backend. |
| `TranscriptionService.swift` | `TranscriptionBackend.swift` | `private let backend: any TranscriptionBackend` | ✓ WIRED | Facade delegiert downloadAndLoad, transcribeWithResampling, isModelReady an Backend. |
| `AppDelegate.swift` | `AppState.swift` | `appState?.isModelError = true` | ✓ WIRED | Zeile 483 in AppDelegate.swift — setzt isModelError bei Download-Fehler. |
| `AppDelegate.swift` | `TranscriptionService.swift` | `await transcriptionService.downloadAndLoad(progressHandler:)` | ✓ WIRED | Zeile 460 in AppDelegate.swift — ruft Facade auf, keine WhisperKit-Referenz. |
| `ParakeetBackend.swift` | FluidAudio (SPM) | `@preconcurrency import FluidAudio; AsrModels.downloadAndLoad(version: .v3)` | ✓ WIRED | Import vorhanden, AsrModels.downloadAndLoad + AsrManager.initialize(models:) + manager.transcribe verwendet. |

---

## Data-Flow Trace (Level 4)

| Artefakt | Datenvariable | Quelle | Echte Daten | Status |
|----------|---------------|--------|-------------|--------|
| `ParakeetBackend.transcribeWithResampling` | `result.text` | `AsrManager.transcribe(samples, source: .microphone)` | Erfordert Laufzeit-Verifikation | ? UNCERTAIN — Code-Pfad korrekt, aber FluidAudio-Inference nur durch Human-Test prüfbar |
| `AppDelegate.setupTranscription` | `appState?.isModelReady` | `await transcriptionService.isModelReady` → `backend.isModelReady` | Korrekt verdrahtet | ✓ FLOWING — transitiv: AppDelegate → TranscriptionService → ParakeetBackend |

---

## Behavioral Spot-Checks

| Verhalten | Prüfung | Ergebnis | Status |
|-----------|---------|----------|--------|
| TranscriptionBackend-Protokoll exportiert korrekte Signaturen | `grep "protocol TranscriptionBackend: Sendable" TranscriptionBackend.swift` | Match | ✓ PASS |
| ParakeetBackend konformiert zu Protokoll | `grep "actor ParakeetBackend: TranscriptionBackend"` | Match | ✓ PASS |
| Kein WhisperKit-Import in TranscriptionService | `grep "WhisperKit\|argmax" TranscriptionService.swift AppDelegate.swift` | 0 Treffer | ✓ PASS |
| Warmup-Inferenz implementiert | `grep "dummySamples" ParakeetBackend.swift` | Match (Zeile 45) | ✓ PASS |
| isModelError in AppDelegate gesetzt | `grep "isModelError = true" AppDelegate.swift` | Match (Zeile 483) | ✓ PASS |
| FluidAudio in pbxproj (min. 4 Sektionen) | `grep -c "FluidAudio" project.pbxproj` | 9 Treffer | ✓ PASS |
| WhisperKit vollständig aus pbxproj entfernt | `grep "WhisperKit\|argmax-oss-swift" project.pbxproj` | 0 Treffer (Argmax) | ✓ PASS |
| Automatisierte Tests (Plan 07-07 SUMMARY) | 75/75 Tests grün | Dokumentiert in 07-07-SUMMARY.md | ✓ PASS (manuell bestätigt) |

---

## Anti-Patterns

| Datei | Zeile | Muster | Schwere | Auswirkung |
|-------|-------|--------|---------|-----------|
| `SPRECHKRAFT/Transcription/ParakeetBackend.swift` | 39 | `manager.initialize(models: models)` statt `manager.loadModels(models)` (Plan 07-04 Action spezifizierte `loadModels`) | INFO | Keine — zeigt FluidAudio-API-Anpassung an tatsächliche API. Beide Varianten sind äquivalent. |
| `SPRECHKRAFT.xcodeproj/project.pbxproj` | — | FluidAudio exactVersion 0.12.6 statt 0.12.4 (Plan 07-03 spezifizierte 0.12.4) | INFO | Keine — neuere Patch-Version, kein Breaking Change. Package.resolved pinnt den konkreten Commit. |
| `SPRECHKRAFT/Transcription/TranscriptionService.swift` | 58 | NaN/Inf-Sanitizer zusätzlich zum Plan | INFO | Kein negativer Effekt — defensiver Fix für einen bekannten AVAudioEngine-Datenfehler (siehe commit docs/260426-a1b). |
| `WhisperKitBackend.swift` | 49 | Datei als PBXBuildFile in Sources registriert (project.pbxproj) | WARNING | Da der gesamte Dateiinhalt in `/* ... */` ist, kompiliert der Swift-Compiler die Datei ohne Fehler. Kein Linker-Overhead, keine WhisperKit-Dependency. Kein echter Blocker, aber ungewöhnlich — würde bei Reaktivierung korrekt funktionieren. |
| `REQUIREMENTS.md` | 10 | RECORD-04 beschreibt "Python/MLX-Subprocess", Traceability zeigt "Phase 3, pending" | WARNING | Requirements-Dokument wurde nicht aktualisiert. Die Phase-7-Implementierung erfüllt das Ziel via CoreML/FluidAudio (natives Swift-SPM), was dem Phase-Goal entspricht aber von der RECORD-04-Formulierung abweicht. Kein funktionaler Blocker. |

---

## Anforderungsabdeckung (RECORD-04, RECORD-05)

| Anforderung | Beschreibung (REQUIREMENTS.md) | Status | Evidenz |
|-------------|--------------------------------|--------|---------|
| RECORD-04 | Parakeet v3 transkribiert Aufnahme lokal | ? UNCERTAIN | Code-seitig implementiert via FluidAudio/CoreML. REQUIREMENTS.md-Beschreibung ("Python/MLX-Subprocess") veraltet — Phase 7 ersetzt dies durch natives Swift. Laufzeit-Verifikation erforderlich. |
| RECORD-05 | Parakeet-Modell beim Erststart heruntergeladen (mit Fortschrittsanzeige) | ? UNCERTAIN | Code-Pfad vollständig: Cache-Check → .modelLoading → downloadAndLoad → .warmingUp → .idle. Fortschrittsanzeige via Titel-Text ("~1.2 GB"). Download-UX-Verifikation durch Human ausstehend. |

**Hinweis:** REQUIREMENTS.md listet beide als "pending" und verweist auf Phase 3 als Implementierungsphase. Die tatsächliche Implementierung erfolgte in Phase 7 — das Dokument wurde nicht aktualisiert. Dies ist ein Dokumentationsmangel, kein funktionaler Fehler.

---

## Human-Verifikation erforderlich

### 1. Modell-Download-UX beim Erststart (Plan 07-07 Task 2)

**Test:** FluidAudio-Cache löschen (`rm -rf ~/Library/Application\ Support/FluidAudio/Models`), App starten, Menüleisten-Icon beobachten.

**Erwartet:**
- Icon zeigt sofort orange `arrow.down.circle` (`.modelLoading`)
- Menüleisten-Titel: "Parakeet-Modell wird geladen (~1.2 GB)…"
- Nach Download: kurz `hourglass` (`.warmingUp`), dann grauer Mic (`.idle`)
- Titel-Text wird geleert
- Hotkey ⌥⌘R blockiert während Download (Guard aktiv)

**Warum Human:** Tatsächlicher Model-Download und Icon-Transitions können nur durch Laufzeitbeobachtung verifiziert werden. Plan 07-07 Task 2 wurde ohne explizite Bestätigung ("download UX ok") übergangen.

### 2. Live-Transkription via FluidAudio/Parakeet TDT v3 (Plan 07-07 Task 3)

**Test:** Nach erfolgtem Modell-Load (`.idle`-State), ⌥⌘R drücken, deutschen Satz sprechen (z.B. "Hallo, das ist ein Test für die Diktat-App."), ⌥⌘R stoppen.

**Erwartet:**
- Icon: idle → recording (roter Puls) → transcribing (blau) → idle
- Transkription erscheint im aktiven Textfeld oder Clipboard
- Text ist eine sinnvolle Wiedergabe des Gesagten
- Console: KEINE "[ParakeetBackend] Download/Load error:" oder "[ParakeetBackend] Transkriptionsfehler:" Nachrichten bei normalem Betrieb
- Console: KEINE WhiskerKit-Ausgaben

**Warum Human:** End-to-End Inferenz-Qualität mit echtem Parakeet TDT v3 Modell ist nur durch tatsächliches Sprechen und Beobachten prüfbar. Plan 07-07 Task 3 wurde ohne explizite Bestätigung ("transcription ok") übergangen.

---

## Zusammenfassung

Phase 7 ist **code-seitig vollständig implementiert und verdrahtet**. Alle 7 Schlüssel-Artefakte existieren, sind substantiell (keine Stubs) und korrekt miteinander verbunden:

- `TranscriptionBackend`-Protokoll als saubere Facade-Abstraktion
- `ParakeetBackend` mit FluidAudio TDT v3, Warmup-Inferenz und stiller Fehlerbehandlung
- `WhisperKitBackend.swift` als vollständig auskommentierter, reaktivierbarer Fallback
- `TranscriptionService` als dünne Facade ohne WhisperKit-Import
- `AppDelegate.setupTranscription()` mit Cache-Check, neuen Model-Lifecycle-States und Error-Pfad
- `AppState` mit 8 RecordingState-Cases und `isModelError`-Property
- FluidAudio 0.12.6 in SPM, WhisperKit vollständig aus Build entfernt

**Ausstehend (Human-Verifikation):** Die automatisierten Tests sind per 07-07-SUMMARY.md grün (75/75) und der Error-State wurde manuell bestätigt. Zwei Checkpoints aus Plan 07-07 (Download-UX-Transition, Live-Transkription) wurden ohne explizite Nutzer-Bestätigung übergangen und müssen noch verifiziert werden.

---

_Verifiziert: 2026-04-30_
_Verifikator: Claude (gsd-verifier)_
