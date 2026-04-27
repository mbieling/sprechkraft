# Phase 1: App Shell - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Die App startet als Menu-Bar-only-Prozess ohne Dock-Icon. Ein globaler Hotkey (⌥⌘R, konfigurierbar) wechselt visuell zwischen 4 Icon-Zuständen. Das Menü zeigt App-Name, Einstellungen-Placeholder, Login-Toggle und Beenden. Kein Audio, keine Transkription in dieser Phase.

</domain>

<decisions>
## Implementation Decisions

### Icon-Design (FEED-01)
- **D-01:** Symbol: `mic.fill` (SF Symbol) für alle 4 Zustände — einheitliches Vokabular
- **D-02:** Farben pro Zustand: Idle = grau, Aufnahme = rot, Transkribieren = blau, LLM-Verarbeitung = lila
- **D-03:** Icon ist **kein Template-Image** — `renderingMode: .alwaysOriginal` damit Farben sichtbar bleiben
- **D-04:** Phase 1 enthält bereits eine **sanfte Pulse-Animation** für Aufnahme + LLM-Verarbeitung; Transkribieren und Idle sind statisch. Waveform/Level-Meter folgen erst in Phase 2.

### Menü-Struktur (SET-02, SET-05, SET-06)
- **D-05:** Menü-Inhalt minimal:
  ```
  SPRECHKRAFT          (disabled, App-Name)
  ────────────────
  Einstellungen…
  ☑ Beim Login starten  (Toggle)
  ────────────────
  Beenden
  ```
- **D-06:** **Linksklick auf Icon = direkte Aktion** (Aufnahme starten/stoppen), **Rechtsklick = Menü öffnen**. Erfordert AppKit `NSStatusItem` statt reinem SwiftUI `MenuBarExtra` — der SwiftUI-Layer bleibt für UI-Inhalte, aber der Click-Handler braucht die AppKit-Schicht.

### Einstellungen-Placeholder
- **D-07:** `Einstellungen…` öffnet ein **echtes, zunächst leeres SwiftUI-Fenster** mit Titel „SPRECHKRAFT — Einstellungen". Spätere Phasen ergänzen Tabs und Inhalte. Kein greyed-out Menüpunkt.

### Claude's Discretion
- Xcode-Projektstruktur und Swift Package Manager Setup: dem Entwickler überlassen
- Genaue SwiftUI-Architektur (App-Delegate vs. @main SwiftUI App): dem Entwickler überlassen
- Hotkey-Default ⌥⌘R ist durch ROADMAP.md vorgegeben; keine weitere Entscheidung nötig

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Anforderungen
- `.planning/REQUIREMENTS.md` — Vollständige Requirement-Liste; Phase 1 betrifft: SET-02, SET-05, SET-06, FEED-01
- `.planning/ROADMAP.md` §Phase 1 — Goal, Success Criteria und Traceability für Phase 1

### Technology Choices
- `CLAUDE.md` §Technology Stack — Festgelegte Libraries: KeyboardShortcuts (SPM), LaunchAtLogin-modern (SPM), Defaults (SPM). SwiftUI `MenuBarExtra` + AppKit-Fallback für split click handling.

No external ADRs or specs beyond the above — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Keine — Greenfield-Projekt. Noch kein Swift-Code vorhanden.

### Established Patterns
- Noch keine. Phase 1 legt die Basisstruktur fest, auf der alle weiteren Phasen aufbauen.

### Integration Points
- `NSStatusItem` / `MenuBarExtra` ist der zentrale Einstiegspunkt. Alle späteren Phasen (Audio, Transkription, Output) hängen am gleichen App-State-Objekt, das hier angelegt wird.
- `AppState` (oder ähnlich benanntes Observable-Objekt) muss den aktuellen `RecordingState` (Idle/Recording/Transcribing/LLM) als Source of Truth halten — Icon und Menü reagieren darauf.

</code_context>

<specifics>
## Specific Ideas

- Inspiration: https://tryvoiceink.com — ähnlicher Look und Feel erwünscht
- Icon-Farben orientieren sich an semantischen Signalfarben: grau = inaktiv, rot = Aufnahme (Gefahr/Aktiv), blau = Verarbeitung, lila = KI

</specifics>

<deferred>
## Deferred Ideas

None — Diskussion blieb im Phase-Scope.

</deferred>

---

*Phase: 01-app-shell*
*Context gathered: 2026-04-15*
