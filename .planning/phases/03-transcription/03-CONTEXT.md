# Phase 3: Transcription - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Aufgenommenes PCM-Audio (akkumuliert über AVAudioEngine installTap während der Aufnahme) wird
lokal via WhisperKit transkribiert. Das Modell (whisper-large-v3-turbo, ~800MB) wird beim
App-Start heruntergeladen, Fortschritt im NSStatusItem-Title sichtbar. Während des Downloads
ist Aufnahme blockiert. Ergebnis: Rohtext per print() auf der Konsole — kein Text-Injection,
kein LLM in dieser Phase. Phase 4 hängt Text-Output ein.

</domain>

<decisions>
## Implementation Decisions

### Transkriptions-Engine

- **D-01:** Engine: **WhisperKit** (argmaxinc/whisperkit) — pure Swift SPM-Package, MLX/CoreML-beschleunigt auf Apple Silicon, kein Python-Subprocess, kein Bundling-Aufwand. Parakeet (Python/MLX) explizit verworfen für Phase 3 (zu hohe Integrationskosten für ein Prototype-Stadium).
- **D-02:** Modell: **whisper-large-v3-turbo** (~800MB) — optimale Balance aus Genauigkeit und Inferenz-Geschwindigkeit für Push-to-Talk.
- **D-03:** Sprache: **Deutsch, fest** (`language: "de"`) — keine automatische Spracherkennung, keine Settings-Option in Phase 3. Vermeidet Fehlklassifizierungen bei kurzen deutschen Äußerungen.

### Audio-Buffer-Übergabe

- **D-04:** Akkumulierungsmethode: **In-Memory `[Float]`-Array** — `installTap`-Callback schreibt Float-Samples in ein Array im `AudioController`. Kein Disk-I/O, kein Temp-File. WhisperKit akzeptiert `[Float]` nativ.
- **D-05:** Buffer-Ownership: `AudioController` akkumuliert das Array während `.recording`; übergibt es (einmalig, als Kopie) an den Transcription-Service wenn `stopRecording()` aufgerufen wird. Array wird danach freigegeben.
- **D-06:** Samplerate-Normierung: WhisperKit erwartet 16 kHz mono. `AVAudioConverter` oder WhisperKits `AudioProcessor.convertBufferToArray` übernimmt Resampling falls Hardware-Rate abweicht.

### Pipeline-Stub (Phase 3)

- **D-07:** Ausgabe: `print("Transkription: \(text)")` auf der Konsole — kein Clipboard, keine Text-Injection. Phase 4 ersetzt diesen Stub.
- **D-08:** Zustandsübergang nach Transkription: `.transcribing → .idle` sobald Text zurückkommt (oder bei Fehler). `appState.resetToIdle()` wird vom Transcription-Service nach Abschluss auf Main Thread aufgerufen.

### Modell-Download UX

- **D-09:** Download-Start: **beim App-Start** (in `applicationDidFinishLaunching` oder einem async Task der App-Initialisierung). Modell ist bereit bevor erste Aufnahme gestartet wird.
- **D-10:** Fortschrittsanzeige: **`NSStatusItem.button?.title`** — Text neben dem Icon, z.B. `"↓ 42%"`. Während Download: Icon zeigt `.idle`-Farbe, Title zeigt Prozent-Fortschritt. Nach Abschluss: Title wird entfernt.
- **D-11:** Aufnahme während Download: **blockiert** — `startRecordingWithCue()` prüft ob Modell geladen ist; wenn nicht, wird der Hotkey/Klick ignoriert (kein Audio-Cue, kein State-Wechsel).

### Fehlerbehandlung

- **D-12:** Transkriptionsfehler: **stille Rückkehr zu `.idle`** — `appState.resetToIdle()`, kein Text, Fehler via `print("Transkriptionsfehler: \(error)")`. Keine Benutzer-sichtbare Fehlermeldung in Phase 3.
- **D-13:** Download-Fehler: **stille Rückkehr** — Download-Title wird entfernt, App bleibt im Download-Blocked-Zustand. Nächster Versuch beim nächsten App-Start. Keine automatische Retry-Logik in Phase 3.

### Claude's Discretion

- Exakte WhisperKit-Konfigurationsparameter (`computeUnits`, `chunkingStrategy`, etc.): dem Entwickler überlassen
- Mindestsampleanzahl vor Transkriptionsaufruf: dem Entwickler überlassen (Leeraufruf vermeiden)
- Download-Caching-Pfad (WhisperKit standard vs. Custom): dem Entwickler überlassen
- Debounce-Schwelle für Title-Update-Häufigkeit während Download: dem Entwickler überlassen

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Anforderungen
- `.planning/REQUIREMENTS.md` — Phase 3 betrifft: RECORD-04, RECORD-05
- `.planning/ROADMAP.md` §Phase 3 — Goal, Success Criteria

### Technology Stack
- `CLAUDE.md` §Technology Stack §Local ML / Parakeet Integration — Kontext zur Engine-Wahl; WhisperKit ist entschiedener Ersatz für Python-Subprocess-Ansatz
- `CLAUDE.md` §What NOT to Use — CoreML-Konvertierung und Python-Subprocess explizit ausgeschlossen
- `.planning/research/ARCHITECTURE.md` §Transkription — WhisperKit-Empfehlung, AVAudioConverter-Pattern, Float-Array-Übergabe, Code-Beispiel für WhisperKit-Init
- `.planning/research/STACK.md` §Local ML / Parakeet Integration — Stack-Analyse; WhisperKit-Entscheidungsgrundlage

### Phase 2 Basis
- `.planning/phases/02-audio-capture/02-CONTEXT.md` — AudioController-Architektur, installTap-Pattern, Observation-B, Swift 6 Concurrency-Strategie (@unchecked Sendable)
- `.planning/phases/01-app-shell/01-CONTEXT.md` — AppState @Observable, RecordingState, NSStatusItem-Pattern

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SPRECHKRAFT/Audio/AudioController.swift` — `installTap` bereits vorhanden, akkumuliert aktuell nur RMS. Phase 3 ergänzt Float-Sample-Akkumulation in derselben Callback-Closure. `stopRecording()` gibt das akkumulierte Array zurück (oder via Callback an AppDelegate).
- `SPRECHKRAFT/AppState.swift` — `RecordingState.transcribing` existiert, `resetToIdle()` existiert. Phase 3 nutzt beide ohne Änderung. Neuer State für "Modell lädt" (z.B. `isModelLoading: Bool`) oder Download-Progress-Property nötig.
- `SPRECHKRAFT/AppDelegate.swift:82-93` — `stopRecordingWithCue()` ruft aktuell `appState?.resetToIdle()` als Platzhalter auf. Phase 3 ersetzt diesen Aufruf durch den Transcription-Service-Kickoff.
- `SPRECHKRAFT/AppDelegate.swift:175-191` — `updateIcon()` / `statusItem.button?.title` — Download-Fortschritt kann hier als `title` gesetzt werden (kein neues View-Layer nötig).

### Established Patterns
- **Swift 6 Strict Concurrency** (`SWIFT_STRICT_CONCURRENCY = complete`) — Transcription-Task muss async sein, Ergebnis via `Task { @MainActor in }` zurück auf Main Thread.
- **Observation-B** (manueller `updateIcon()`-Aufruf) — Download-Fortschritts-Updates müssen `updateIcon()` oder `statusItem.button?.title` manuell anstoßen.
- **`@unchecked Sendable` für AudioController** — Float-Sample-Array kann auf dem Audio-Render-Thread geschrieben werden; Übergabe an Transcription-Service nach `stopRecording()` ist sicher da einmalig.
- **`weak var appState: AppState?`** in AudioController — gleicher Referenz-Pattern für TranscriptionService.

### Integration Points
- `AudioController.stopRecording()` → gibt akkumuliertes `[Float]`-Array zurück (oder via neues `onRecordingComplete: ([Float]) -> Void`-Callback analog zu `onAutoStop`)
- `AppDelegate.stopRecordingWithCue()` → ruft Transcription-Service mit dem Float-Array auf, setzt State `.transcribing`
- `AppState` → neues Property `isModelReady: Bool` (oder ähnlich) das `startRecordingWithCue()` in AppDelegate prüft (D-11)
- `AppDelegate.updateIcon()` → liest `statusItem.button?.title` für Download-Fortschritt (D-10)

</code_context>

<specifics>
## Specific Ideas

- WhisperKit-Init-Muster aus `.planning/research/ARCHITECTURE.md`: `WhisperKitConfig` + `WhisperKit(config)` async-Init
- NSStatusItem-Title für Download-Progress: `"↓ 42%"` — kurz, eindeutig, kein Icon-Ersatz
- Float-Array übergeben via Callback `onRecordingComplete: ([Float]) -> Void` — konsistent mit bestehendem `onAutoStop`-Muster

</specifics>

<deferred>
## Deferred Ideas

- Sprachauswahl als Settings-Option (Deutsch/Englisch/Auto) — kommt in einer späteren Phase wenn Settings-UI ausgebaut wird
- Retry-Logik bei Download-Fehlern — Phase 3 ist Stub; robuste Download-UX in späteren Phasen
- Parakeet-Integration als Genauigkeits-Option — bleibt in Backlog; zu hoher Integrationsaufwand für v1

</deferred>

---

*Phase: 03-transcription*
*Context gathered: 2026-04-18*
