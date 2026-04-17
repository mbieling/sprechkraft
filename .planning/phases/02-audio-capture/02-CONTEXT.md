# Phase 2: Audio Capture - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Der Hotkey startet und stoppt echte Mikrofon-Aufnahme via AVAudioEngine. Stille erkennt sich
automatisch und stoppt die Aufnahme. Audio-Cues spielen bei Start und Stopp. Das Menu-Bar-Icon
zeigt während der Aufnahme einen Live-Pegel als Waveform-Linie unterhalb des mic.fill-Symbols.
Der Nutzer kann das Eingabegerät im Settings-Fenster wählen. Keine Transkription in dieser Phase.

</domain>

<decisions>
## Implementation Decisions

### Level-Meter Visualisierung (FEED-03)
- **D-01:** Darstellungsform: **Waveform-Linie** unterhalb des mic.fill-Symbols
- **D-02:** Position: direkt **unterhalb** des Mic-Icons (Mic bleibt oben und zentriert sichtbar)
- **D-03:** Die Linie oszilliert in Echtzeit entsprechend dem RMS-Pegel des Eingangssignals
- **D-04:** Das bestehende Pulse-System (Phase 1) bleibt für .recording aktiv — die Waveform
  ergänzt es als zusätzliches visuelles Layer innerhalb derselben StatusBarIconView

### Audio-Cues (FEED-02)
- **D-05:** Tonquelle: **NSSound System-Töne** (kein Bundle-Asset, kein AVAudioEngine-Ton)
- **D-06:** Start und Stopp erhalten **unterschiedliche Töne** (z.B. heller Ton für Start,
  tieferer Ton für Stopp) — eindeutiges auditives Feedback ohne hinzuschauen
- **D-07:** Auto-Stopp durch Stille spielt **denselben Stopp-Ton** wie manueller Stopp

### Stille-Erkennung (RECORD-02, SET-03)
- **D-08:** Methode: **RMS-Pegel-Schwellwert** — wenn Energie unter Schwellwert für N Sekunden
  → Auto-Stopp ausgelöst
- **D-09:** Standard-Stille-Dauer: **1.5 Sekunden**
- **D-10:** Konfigurierbar in Einstellungen (SET-03); Wert wirkt ab der nächsten Aufnahme

### Mikrofon-Auswahl (RECORD-03, SET-04)
- **D-11:** UI-Platzierung: **ausschließlich im Settings-Fenster** — Dropdown-Auswahl im
  bestehenden Einstellungs-Fenster (Phase 1 angelegt)
- **D-12:** Kein Schnellzugriff im Menü nötig

### Mikrofonberechtigung
- **D-13:** Fehlerpfad: **Roter Banner im Settings-Fenster** + Button „Berechtigung erteilen"
  der macOS Datenschutz-Einstellungen öffnet (`NSWorkspace.shared.open(privacyURL)`)
- **D-14:** Kein Crash oder stille Fehler — Permission-State wird geprüft vor AVAudioEngine-Start

### Claude's Discretion
- Genaue NSSound-Namen für Start und Stopp: dem Entwickler überlassen (z.B. „Tink", „Pop")
- AVAudioEngine Tap-Puffer-Größe und Samplerate: technische Entscheidung
- RMS-Schwellwert-Wert für Stille-Erkennung (default): dem Entwickler überlassen
- Waveform-Linien-Rendering: Anzahl der dargestellten Samples und Canvas-Größe innerhalb der 18×18px-Constraints

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Anforderungen
- `.planning/REQUIREMENTS.md` — Phase 2 betrifft: RECORD-01, RECORD-02, RECORD-03, SET-03, SET-04, FEED-02, FEED-03
- `.planning/ROADMAP.md` §Phase 2 — Goal, Success Criteria, Requirements-Traceability

### Technology Stack
- `CLAUDE.md` §Audio Capture — AVAudioEngine (`installTap`) für Push-to-Talk Buffer, kein AVAudioRecorder
- `CLAUDE.md` §Technology Stack — Swift 6.x, SwiftUI + AppKit (NSStatusItem), no AVAudioSession on macOS

### Phase 1 Basis
- `.planning/phases/01-app-shell/01-CONTEXT.md` — Architektur-Entscheidungen: AppDelegate/NSStatusItem,
  AppState @Observable, StatusBarIconView, Pulse-Animation, Swift 6 Strict Concurrency (complete)

No external ADRs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `VoiceScribe/AppState.swift` — `@MainActor @Observable final class AppState`, `RecordingState` enum mit `.idle/.recording/.transcribing/.llmProcessing`; `toggleRecording()` wird in Phase 2 durch echte Audio-Logik ersetzt
- `VoiceScribe/StatusBarIconView.swift` — `mic.fill` + Pulse-Animation; Phase 2 fügt Waveform-Linie als zweites View-Layer hinzu
- `VoiceScribe/AppDelegate.swift` — NSStatusItem + NSHostingView; Audio-Controller wird hier initialisiert

### Established Patterns
- Swift 6 Strict Concurrency: `SWIFT_STRICT_CONCURRENCY = complete` — alle Audio-Callbacks müssen @MainActor-konform sein oder explizit per `Task { @MainActor in … }` dispatchen
- Observation Strategy B (manueller `updateIcon()`-Aufruf) statt `withObservationTracking` — Phase 2 muss das Level-Update über denselben Mechanismus anstoßen
- AppState ist die einzige Source of Truth für `RecordingState` — Audio-Controller setzt `appState.recordingState`, nie direkt das Icon

### Integration Points
- `AppState.toggleRecording()` → wird zu echter Start/Stopp-Logik (AVAudioEngine start/stop)
- `StatusBarIconView` → erhält neuen Parameter für Live-Pegel-Wert (CGFloat 0.0–1.0)
- `SettingsView` → Phase 2 ergänzt erste echte Controls: Mikrofon-Dropdown + Stille-Dauer-Slider + Permission-Banner

</code_context>

<specifics>
## Specific Ideas

- VoiceInk-ähnlicher Look: https://tryvoiceink.com — kompaktes, unauffälliges Menu-Bar-Icon
- Waveform unterhalb des Mics, nicht überlagernd — Mic bleibt der primäre visuelle Anker
- NSSound-Töne sollen diskret klingen (kein System-Alert-Charakter), eher kurze „Click"-artige Töne

</specifics>

<deferred>
## Deferred Ideas

None — Diskussion blieb im Phase-Scope.

</deferred>

---

*Phase: 02-audio-capture*
*Context gathered: 2026-04-17*
