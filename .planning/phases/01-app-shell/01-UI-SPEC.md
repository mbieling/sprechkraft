---
phase: 1
slug: app-shell
status: draft
shadcn_initialized: false
preset: none
created: 2026-04-15
platform: macOS native (SwiftUI + AppKit)
---

# Phase 1 — UI Design Contract: App Shell

> Visueller und Interaktions-Vertrag für Phase 1 (macOS Menu-Bar App Shell).
> Generiert von gsd-ui-researcher, verifiziert durch gsd-ui-checker.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (kein Web-Framework) |
| Preset | not applicable |
| Component library | SwiftUI native + AppKit NSStatusItem |
| Icon library | SF Symbols (system-provided) |
| Font | SF Pro (System default — `.font(.system(...))`) |

**Begründung:** Natives macOS SwiftUI-Projekt. Kein shadcn, kein Radix, kein Tailwind.
Alle Design-Tokens werden als Swift-Konstanten (`CGFloat`, `Color`) definiert, nicht als CSS-Klassen.

---

## Spacing Scale

Deklarierte Werte (Vielfache von 4):

| Token | Value | Swift | Usage |
|-------|-------|-------|-------|
| xs | 4px | `4.0` | Icon-interne Abstände |
| sm | 8px | `8.0` | Menüpunkt-Innenabstand (vertikal) |
| md | 16px | `16.0` | Standard-Element-Abstand |
| lg | 24px | `24.0` | Abschnittstrennungen im Menü |
| xl | 32px | `32.0` | Fensterkanten-Padding (Einstellungsfenster) |

Ausnahmen:
- Menu-Bar-Icon Touch-Target: **44×44 pt** (Apple HIG Mindestgröße für anklickbare Elemente)
- `NSMenuItem` Separator: Höhe durch AppKit festgelegt, kein Token

---

## Typography

Alle Textelemente folgen dem System-Font (SF Pro). Keine Custom-Schriften in Phase 1.

| Role | Size | Weight | Line Height | SwiftUI |
|------|------|--------|-------------|---------|
| App-Name (disabled) | 13pt | Semibold (600) | 1.2 | `.font(.system(size: 13, weight: .semibold))` |
| Menüpunkte | 13pt | Regular (400) | 1.4 | `.font(.system(size: 13))` — Standard `NSMenuItem` |
| Einstellungsfenster-Titel | 15pt | Semibold (600) | 1.2 | `.font(.system(size: 15, weight: .semibold))` |
| Label / Toggle-Text | 13pt | Regular (400) | 1.4 | `.font(.system(size: 13))` |

**Regel:** Genau 2 Schriftgewichte: Regular (400) und Semibold (600). Kein Bold, kein Light.

---

## Color

### Systemfarben (bevorzugt, da macOS Dark/Light-Mode-aware)

| Role | Light Mode | Dark Mode | SwiftUI | Usage |
|------|-----------|-----------|---------|-------|
| Dominant (60%) | Systemhintergrund (Menü) | Systemhintergrund (Menü) | `Color(.windowBackgroundColor)` | Menü-Hintergrund, Einstellungsfenster |
| Secondary (30%) | Systemgrau-Oberflächen | Systemgrau-Oberflächen | `Color(.controlBackgroundColor)` | Trennlinien-Bereiche, Fensterkopf |
| Neutral Text | `NSColor.labelColor` | `NSColor.labelColor` | `Color(.labelColor)` | Alle aktiven Menüpunkte |
| Disabled Text | `NSColor.disabledControlTextColor` | `NSColor.disabledControlTextColor` | `Color(.disabledControlTextColor)` | App-Name-Zeile (nicht klickbar) |

### Accent-Farben (Icon-Zustände, 10%)

Icon-Zustände sind das **einzige** Element mit Farbe außerhalb des Systemschemas.

| Zustand | Farbe | Hex (SRGB) | SwiftUI `Color` | Semantik |
|---------|-------|-----------|-----------------|---------|
| Idle | Grau | `#8E8E93` | `Color(red: 0.557, green: 0.557, blue: 0.576)` | Inaktiv, bereit |
| Aufnahme | Rot | `#FF3B30` | `Color(.systemRed)` | Aktiv, Gefahr, Aufmerksamkeit |
| Transkribieren | Blau | `#007AFF` | `Color(.systemBlue)` | Verarbeitung, neutral |
| LLM-Verarbeitung | Lila | `#AF52DE` | `Color(.systemPurple)` | KI-Aktivität |

**Accent reserved for:** Ausschließlich das Menu-Bar-Icon-Symbol (`mic.fill`) zur Zustandsanzeige. Kein anderes UI-Element verwendet diese Farben in Phase 1.

Destruktiv: Kein destruktiver Zustand in Phase 1 (Beenden-Menüpunkt ist Standard-AppKit, keine eigene Farbe).

---

## Icon-Design Contract

Quelle: CONTEXT.md D-01 bis D-04 (gesperrt).

| Eigenschaft | Wert |
|-------------|------|
| SF Symbol | `mic.fill` |
| Rendering Mode | `.alwaysOriginal` (kein Template-Image) |
| Größe | 18×18 pt (Standard Menu-Bar-Icon-Größe) |
| Padding | 4 pt allseitig (Touch-Target auf 44 pt via `NSStatusItem`) |

### Animationen

| Zustand | Animation | Implementierung |
|---------|-----------|-----------------|
| Idle | Keine — statisch | — |
| Aufnahme (Recording) | Sanfte Pulse-Animation: Opacity 1.0 → 0.5 → 1.0 | SwiftUI `.opacity()` + `.animation(.easeInOut(duration: 0.8).repeatForever())` |
| Transkribieren | Keine — statisch | — |
| LLM-Verarbeitung | Sanfte Pulse-Animation: identisch wie Aufnahme | SwiftUI `.opacity()` + `.animation(.easeInOut(duration: 1.2).repeatForever())` |

**Unterscheidung Aufnahme vs. LLM:** Farbe (rot vs. lila). Pulse-Geschwindigkeit darf sich minimal unterscheiden (0.8s vs. 1.2s), ist aber nicht alleiniges Unterscheidungsmerkmal.

---

## Menü-Struktur Contract

Quelle: CONTEXT.md D-05, D-06 (gesperrt).

```
┌─────────────────────────────┐
│  VoiceScribe                │  ← Disabled (App-Name, Semibold 13pt)
├─────────────────────────────┤  ← NSMenuItem.separator()
│  Einstellungen…             │  ← Öffnet Settings-Fenster (D-07)
│  ☑ Beim Login starten       │  ← LaunchAtLogin Toggle (NSMenuItem mit State)
├─────────────────────────────┤  ← NSMenuItem.separator()
│  Beenden                    │  ← NSApp.terminate()
└─────────────────────────────┘
```

### Klick-Verhalten

| Aktion | Verhalten |
|--------|-----------|
| Linksklick auf Icon | Aufnahme starten/stoppen (direkte Aktion, kein Menü) |
| Rechtsklick auf Icon | Menü öffnen |
| Klick auf „Einstellungen…" | Öffnet SwiftUI-Fenster „VoiceScribe — Einstellungen" |
| Klick auf „Beim Login starten" | Toggle-State wechseln via `LaunchAtLogin-modern` |
| Klick auf „Beenden" | `NSApp.terminate(nil)` |

**Implementierungshinweis:** Linksklick vs. Rechtsklick erfordert `NSStatusItem` mit AppKit-Delegate, nicht reinen SwiftUI `MenuBarExtra`. Siehe CONTEXT.md D-06.

---

## Einstellungsfenster Contract

Quelle: CONTEXT.md D-07 (gesperrt).

| Eigenschaft | Wert |
|-------------|------|
| Fenster-Titel | „VoiceScribe — Einstellungen" |
| Inhalt Phase 1 | Leer (Placeholder-Text: „Einstellungen folgen in weiteren Phasen") |
| Mindestgröße | 400×300 pt |
| Schließen | Standard macOS Fenster-Schließen-Button |
| Dock-Icon | Kein Dock-Icon auch wenn Fenster offen (`LSUIElement = YES` bleibt) |

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| App-Name im Menü | „VoiceScribe" |
| Einstellungen-Menüpunkt | „Einstellungen…" (mit Auslassungszeichen — macOS-Konvention für Menüpunkte die ein Fenster öffnen) |
| Login-Toggle-Label | „Beim Login starten" |
| Beenden-Menüpunkt | „Beenden" |
| Einstellungsfenster-Placeholder | „Einstellungen folgen in weiteren Phasen." |
| Fenster-Titel | „VoiceScribe — Einstellungen" (Em-Dash, macOS-Konvention) |
| Fehlerzustand (kein) | Phase 1 hat keine Fehlerzustände im UI |
| Empty State | Nicht anwendbar (kein Datenzustand in Phase 1) |

**Destruktive Aktionen:** Keine in Phase 1. „Beenden" ist eine Standard-AppKit-Aktion ohne Bestätigungs-Dialog.

---

## State Machine Contract

Für `AppState` (Observable-Objekt, wird in Phase 1 angelegt):

```swift
enum RecordingState {
    case idle          // Icon: grau, statisch
    case recording     // Icon: rot, pulsierend (0.8s)
    case transcribing  // Icon: blau, statisch
    case llmProcessing // Icon: lila, pulsierend (1.2s)
}
```

In Phase 1 wird der State durch Hotkey-Druck zyklisch durchgetastet (Demo-Modus). Echte Audio-Logik folgt in Phase 2.

---

## Accessibility Contract

| Element | Anforderung |
|---------|-------------|
| Menu-Bar-Icon | `accessibilityLabel`: aktueller Zustand als String (z.B. „VoiceScribe — Bereit", „VoiceScribe — Aufnahme läuft") |
| Toggle „Beim Login starten" | `accessibilityValue`: „Ein" / „Aus" |
| Alle Menüpunkte | Standard `NSMenuItem` Accessibility — keine Zusatzarbeit nötig |

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| shadcn official | keine | not applicable |
| Drittanbieter | keine | not applicable |

**Swift Package Manager Dependencies (keine UI-Registries):**
- `sindresorhus/KeyboardShortcuts` — SPM, kein UI-Registry-Eintrag
- `sindresorhus/LaunchAtLogin-modern` — SPM, kein UI-Registry-Eintrag

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS
- [ ] Dimension 2 Visuals: PASS
- [ ] Dimension 3 Color: PASS
- [ ] Dimension 4 Typography: PASS
- [ ] Dimension 5 Spacing: PASS
- [ ] Dimension 6 Registry Safety: PASS

**Approval:** pending

---

*Phase: 01-app-shell*
*UI-SPEC erstellt: 2026-04-15*
*Quellen: CONTEXT.md (D-01 bis D-07), REQUIREMENTS.md (SET-02, SET-05, SET-06, FEED-01), macOS HIG*
