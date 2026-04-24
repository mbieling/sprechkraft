# Phase 7: Parakeet Backend - Context

**Gathered:** 2026-04-24
**Status:** Ready for planning

<domain>
## Phase Boundary

WhisperKit durch FluidAudio/Parakeet TDT v3 ersetzen. Neue Dateien: `TranscriptionBackend`-Protokoll, `ParakeetBackend` actor, `WhisperKitBackend` actor (auskommentiert). `TranscriptionService` wird zur Facade die an das Backend delegiert. `AppDelegate.transcribeWithResampling()` bleibt API-stabil — kein Umbau von AppDelegate, AppState.isModelReady oder onRecordingComplete.

Neue App-States: `.warmingUp` und `.modelError` in RecordingState. Neue AppState-Properties: `isModelError: Bool`.

Nicht in Phase 7: Retry-Button (Phase 8), Settings-Erweiterungen (Phase 8), End-to-End-Validierung (Phase 9).

</domain>

<decisions>
## Implementation Decisions

### WhisperKit-Fallback

- **D-01:** `WhisperKitBackend.swift` als auskommentierte Datei im Repo erhalten. Dokumentiert den Fallback-Pfad ohne Build-Overhead.
- **D-02:** WhisperKit SPM-Dependency vollständig aus dem Projekt entfernen (Package.resolved, pbxproj). Reaktivieren = Dependency readden + Datei uncommenten.

### Warmup-State

- **D-03:** `RecordingState` bekommt neuen Case `.warmingUp` — zwischen `.modelLoading` und `.idle`. Tritt auf nach erfolgreichem Model-Load, bleibt aktiv während Dummy-Audio-Inferenz läuft.
- **D-04:** Hotkey während `.warmingUp` wird silent ignoriert (bestehender `isModelReady`-Guard in AppDelegate greift). Kein User-Feedback nötig — Icon kommuniziert den Zustand.
- **D-05:** `StatusBarIconView` wird um `.warmingUp` und `.modelError` Cases erweitert.

### Download-Fortschritt UX

- **D-06:** Kein Fortschrittsbalken — stattdessen Spinner (animiertes Icon im `.modelLoading`-State) mit Größen-Hinweis im Menü-Titel: "Parakeet-Modell wird geladen (~1.2 GB)…".
- **D-07:** Cache-Pfad `~/Library/Application Support/FluidAudio/Models` explizit prüfen bevor Download-UI gezeigt wird. Wenn Modell-Datei existiert: direkt `downloadAndLoad` (FluidAudio handled cache intern), kein Spinner.

### Fehlerbehandlung

- **D-08:** `AppState` bekommt `isModelError: Bool` (analog zu `isModelReady`). Wird bei Download-Fehler auf `true` gesetzt.
- **D-09:** `RecordingState` bekommt `.modelError` — `StatusBarIconView` zeigt Fehler-Symbol (Ausrufezeichen oder X-Icon im SF Symbols Repertoire).
- **D-10:** Retry-Logik kommt in Phase 8 (Settings-Fenster mit Retry-Button). Phase 7 liefert nur State + Icon — kein Retry-Menüpunkt, keine Notification.

### Architecture

- **D-11:** `TranscriptionBackend`-Protokoll: `func downloadAndLoad(progressHandler: @MainActor @escaping (Double) -> Void) async` + `func transcribeWithResampling(_ samples: [Float], sampleRate: Double) async -> String?` + `var isModelReady: Bool { get }`. API spiegelt bestehende `TranscriptionService`-Schnittstelle.
- **D-12:** `@preconcurrency import FluidAudio` wenn nötig — analog zum bestehenden WhisperKit-Pattern.
- **D-13:** `resampleTo16kHz` bleibt in `TranscriptionService` (backend-unabhängig, wiederverwendbar). Backends bekommen 16-kHz-Samples übergeben, nicht die Hardware-Rate.

### Claude's Discretion

- Genaue SF-Symbol-Wahl für `.warmingUp` (z.B. `hourglass`, `clock`) und `.modelError` (z.B. `exclamationmark.triangle`) — visuell konsistent mit bestehenden RecordingState-Icons.
- Interne Struktur von `ParakeetBackend` (Actor-Properties, Task-Management).
- Ob `AsrModels.downloadAndLoad` tatsächlich einen Progress-Handler hat: beim ersten Build prüfen. Falls ja: echter Progress statt Fake-Double für progressHandler.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Research & Architecture
- `.planning/research/SUMMARY.md` — FluidAudio-API, Pitfalls C4/I8/I10/I11, Wave-Struktur, empfohlener Stack
- `.planning/ROADMAP.md` §Phase 7 — Goal, Success Criteria, Requirements

### Bestehende Implementierung (lesen vor Umbau)
- `VoiceScribe/Transcription/TranscriptionService.swift` — aktueller WhisperKit-Wrapper, API-Kontrakt, resampleTo16kHz-Implementierung
- `VoiceScribe/AppDelegate.swift` §setupTranscription, §onRecordingComplete — Aufruf-Kontext der API-stabilen Methoden
- `VoiceScribe/AppState.swift` — isModelReady-Property, RecordingState-Enum

### Prior Phase Context
- `.planning/phases/03-transcription/03-CONTEXT.md` — D-01 (WhisperKit-Entscheidung), D-13 (stille Rückkehr bei Fehler)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TranscriptionService.resampleTo16kHz(_:fromSampleRate:)` — bleibt in TranscriptionService, Backends bekommen 16-kHz-Samples
- `AppState.isModelReady: Bool` — bereits vorhanden, Pattern für `isModelError` übernehmen
- `@preconcurrency import WhisperKit` — Muster für `@preconcurrency import FluidAudio`

### Established Patterns
- Actor-Isolierung für ML-Services: `TranscriptionService` ist actor, `ParakeetBackend` wird ebenfalls actor
- Observation-Strategie B (manueller updateIcon-Aufruf aus AppDelegate) — für neue States beibehalten
- progressHandler als `@MainActor @escaping (Double) -> Void` — bestehende Signatur beibehalten

### Integration Points
- `AppDelegate.setupTranscription()` ruft `transcriptionService.downloadAndLoad(progressHandler:)` auf — unverändert
- `AppDelegate.onRecordingComplete` ruft `transcriptionService.transcribeWithResampling(_:sampleRate:)` auf — unverändert
- `AppState.isModelReady` wird nach Download-Abschluss gesetzt — `isModelError` analog daneben
- `RecordingState` enum in AppState.swift — neue Cases `.warmingUp` und `.modelError` dort hinzufügen
- `StatusBarIconView` switch über RecordingState — neue Cases ergänzen

</code_context>

<specifics>
## Specific Ideas

- FluidAudio-Version: v0.12.4 (Context7 verifiziert, Score 89.75, 1500+ Stars, in VoiceInk im Einsatz)
- Modell: Parakeet TDT v3 (`AsrModels.downloadAndLoad(version: .v3)`)
- Cache-Pfad: `~/Library/Application Support/FluidAudio/Models` (Research)
- Warmup: Dummy-Audio-Inferenz mit kurzen Null-Samples nach Model-Load
- Modell-Größe für Größen-Hinweis: "~1.2 GB" (Community-Daten; beim Download prüfen und ggf. anpassen)

</specifics>

<deferred>
## Deferred Ideas

- Retry-Button im Menü bei `.modelError` → Phase 8 (Settings)
- Transkriptions-Engine-Status-Sektion in Settings → Phase 8
- Qualitätsvergleich WhisperKit vs. Parakeet auf Deutsch → Phase 9
- Echter Progress-Handler falls FluidAudio v3 API ihn hat (beim ersten Build validieren, ggf. in Phase 9 nachrüsten)
- Quantisiertes 8-Bit-Modell als Alternative (~909 MB) → v2

</deferred>

---

*Phase: 07-parakeet-backend*
*Context gathered: 2026-04-24*
