# Phase 4: Text Output - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Der `print("Transkription: \(text)")` Pipeline-Stub aus Phase 3 (AppDelegate.swift:75) wird durch
echte Text-Ausgabe ersetzt. Zwei Modi: AXUIElement-Injektion in das aktive Textfeld (OUT-01) oder
NSPasteboard/Clipboard (OUT-02), umschaltbar per dediziertem Hotkey (OUT-03).

Kein LLM in dieser Phase. Kein App-spezifischer Fallback-Mechanismus (v2). Keine Settings-UI-Erweiterung
über das Menü-Häkchen hinaus.

</domain>

<decisions>
## Implementation Decisions

### AX-Injektion Methode

- **D-01:** Primärmethode: **`AXUIElement` setValue** — `AXUIElementCopyAttributeValue` liest das
  fokussierte Element, dann `AXUIElementSetAttributeValue` schreibt `kAXValueAttribute`. Kein
  simuliertes Tippen, kein Clipboard-Overhead. Schnell auch bei langen Texten.
- **D-02:** Ziel-Apps (Phase-4-Minimum): **TextEdit, Notes, Safari (Textfelder), Mail, Xcode** —
  alle native Apple-Apps mit Standard-AX-Stack. VS Code, Terminal, Electron-Apps sind v2.
- **D-03:** Cursor-Position: Text wird am aktuellen Cursor eingesetzt (nicht am Ende des Feldes) —
  AXUIElement übernimmt das via `kAXSelectedTextRangeAttribute` + setValue.

### Fallback-Verhalten

- **D-04:** Automatischer Clipboard-Fallback: **nur bei fehlender AX-Permission** —
  `AXIsProcessTrusted()` → false → direkt Clipboard, kein Injektion-Versuch.
- **D-05:** AX-Fehler bei vorhandener Permission: **stille Rückkehr zu .idle** — kein Text,
  kein Fehler-Toast, State zurück zu .idle. Konsistent mit Phase-3-Fehlerbehandlung (D-12 dort).
  App-spezifischer Fallback (VS Code etc.) ist explizit auf v2 verschoben.

### Ausgabemodus

- **D-06:** Standard-Modus beim ersten Start: **Textfeld-Injektion** — Core Value ist Tippen-Ersatz.
  Clipboard als Opt-in per Hotkey.
- **D-07:** Persistenz: **`Defaults.Key<OutputMode>`** — neuer Enum `OutputMode { case field, clipboard }`.
  Speicherung via `Defaults`-Pattern analog zu `silenceDuration` und `selectedMicUID`.
- **D-08:** Modus-Anzeige: **Menü-Häkchen im Dropdown** — `"✓ Textfeld"` / `"✓ Clipboard"` als
  auswählbare Menüpunkte. Kein Icon-Wechsel, keine extra UI. Passt ins bestehende Menü-Pattern.
- **D-09:** Wechsel-Hotkey: **⇧⌘V** (`KeyboardShortcuts.Name.toggleOutputMode`) — Mnemonik: V für
  Voice-Paste, Shift als Modifier. Standard voreingestellt (wie ⌥⌘R für Aufnahme). Konfigurierbar
  in SettingsView.

### AX-Permission Onboarding

- **D-10:** Permission-Check: **beim App-Start** via `AXIsProcessTrusted()` in
  `applicationDidFinishLaunching`. Ergebnis in neuem `AppState.axPermissionDenied: Bool`.
- **D-11:** Fehlende Permission UX: **Banner in SettingsView** — analog zum bestehenden
  `micPermissionDenied`-Banner in Phase 2. Roter Hinweis mit Link zu Systemeinstellungen
  (Datenschutz → Bedienungshilfen). Kein separater Onboarding-Flow.
- **D-12:** Im Clipboard-Fallback (D-04): Banner bleibt sichtbar, Modus wechselt automatisch
  auf Clipboard. Kein stiller Fail — der User sieht den Permission-Hinweis beim nächsten
  Öffnen von Settings.

### Claude's Discretion

- Genaue AX-API-Aufrufsequenz (welche Attribute, Fehlerbehandlung im Detail)
- OutputMode-Enum-Struktur und Defaults-Key-Name
- Wie der Text bei leerem Fokus-Element behandelt wird (kein fokussiertes Textfeld)
- Debounce oder Retry-Logik beim AX-Aufruf

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Anforderungen
- `.planning/REQUIREMENTS.md` — Phase 4: OUT-01, OUT-02, OUT-03
- `.planning/ROADMAP.md` §Phase 4 — Goal, Success Criteria (4 Kriterien)

### Bestehendes Pattern
- `CLAUDE.md` §Technology Stack §Text Injection (Accessibility) — AXUIElement + NSPasteboard Fallback explizit dokumentiert
- `.planning/phases/02-audio-capture/02-CONTEXT.md` — micPermissionDenied-Pattern, Defaults-Key-Pattern
- `.planning/phases/03-transcription/03-CONTEXT.md` D-07/D-08/D-12 — Pipeline-Stub der ersetzt wird, resetToIdle-Pattern, Fehlerbehandlung

### Bestehendes Code
- `VoiceScribe/AppDelegate.swift:72-78` — onRecordingComplete-Callback (Integrationspunkt: print() wird durch TextOutputService ersetzt)
- `VoiceScribe/Extensions/Defaults+Keys.swift` — Vorlage für neuen OutputMode-Key
- `VoiceScribe/Extensions/KeyboardShortcuts+Names.swift` — Vorlage für toggleOutputMode-Name
- `VoiceScribe/Views/SettingsView.swift` — micPermissionDenied-Banner als Pattern für axPermissionDenied-Banner

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `AppState.micPermissionDenied: Bool` — exakt dasselbe Pattern für `axPermissionDenied: Bool`
- `Defaults+Keys.swift` — neuer Key `outputMode: OutputMode` nach gleichem Schema
- `KeyboardShortcuts+Names.swift` — neuer Name `toggleOutputMode` nach gleichem Schema
- `SettingsView.swift` — Permission-Banner-Komponente direkt wiederverwendbar

### Established Patterns
- **Defaults-Persistenz**: `@Default(.key) var property` in Views/AppDelegate
- **Observation-B**: Modus-Wechsel → `updateIcon()` oder Menü-Update manuell anstoßen
- **Swift 6 Strict Concurrency**: AX-Calls müssen auf `@MainActor` laufen (UIKit-Analogie)
- **KeyboardShortcuts**: neuer `.toggleOutputMode`-Name analog zu `.toggleRecording`

### Integration Points
- `AppDelegate.swift:75` — `print("Transkription: \(text)")` → ersetzen durch `TextOutputService.output(text)`
- `AppDelegate.applicationDidFinishLaunching` — `AXIsProcessTrusted()` Check hinzufügen
- `AppState` — `axPermissionDenied: Bool` hinzufügen
- Menü in `AppDelegate` / `SettingsView` — Modus-Häkchen + Hotkey-Eintrag
- `KeyboardShortcuts+Names.swift` — `toggleOutputMode` Name

</code_context>

<specifics>
## Specific Ideas

- `AXUIElementCreateSystemWide()` → `kAXFocusedUIElementAttribute` → setValue auf `kAXValueAttribute`
  ist der Standard-Pfad für systemweite Text-Injektion (VoiceInk, ähnliche Tools nutzen diesen Pfad)
- Banner-Text Vorschlag: "Bedienungshilfen-Zugriff erforderlich — in Systemeinstellungen aktivieren →"
  mit einem Button der `NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:...")!)` aufruft

</specifics>

<deferred>
## Deferred Ideas

- **App-spezifischer AX-Fallback** (VS Code, Terminal, Electron-Apps) — in REQUIREMENTS.md als v2 markiert
- **Cursor-Position-Awareness** wenn kein Textfeld fokussiert ist (z.B. Toast "Kein Textfeld fokussiert") — v2 UX-Polish
- **Automatic Retry** wenn AX-Injektion scheitert — v2

</deferred>

---

*Phase: 04-text-output*
*Context gathered: 2026-04-18*
