# Phase 4: Text Output - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-18
**Phase:** 04-text-output
**Areas discussed:** AX-Injektion Strategie, Fallback-Verhalten, Ausgabemodus UX, AX-Permission Onboarding

---

## AX-Injektion Strategie

| Option | Beschreibung | Gewählt |
|--------|-------------|---------|
| AXUIElement setValue | Direkt, schnell, kein Tippen-Overhead. Scheitert in Electron | ✓ |
| CGEvent Keyboard-Simulation | Universell aber langsam und blockierend | |
| NSPasteboard + Cmd+V | Überschreibt Clipboard, einfach aber destruktiv | |

**User's choice:** AXUIElement setValue

| Option | Beschreibung | Gewählt |
|--------|-------------|---------|
| TextEdit | Standard macOS Text-Editor | ✓ |
| Notes | Apple Notes | ✓ |
| Safari (Textfelder) | Web-Formulare | ✓ |
| Mail / Xcode | Native Apple-Apps | ✓ |

**Ziel-Apps:** TextEdit, Notes, Safari, Mail, Xcode (alle 4 gewählt)

---

## Fallback-Verhalten

| Option | Beschreibung | Gewählt |
|--------|-------------|---------|
| Nur bei fehlender AX-Permission | AX-Fehler mit Permission → stille Rückkehr | ✓ |
| Bei Permission-Fehler UND setValue-Fehler | Robuster, aber v2-Scope laut REQUIREMENTS | |

**User's choice:** Nur bei fehlender AX-Permission

| Option | Beschreibung | Gewählt |
|--------|-------------|---------|
| Stille Rückkehr zu idle | Konsistent mit Phase-3-Muster (D-12) | ✓ |
| Clipboard-Fallback + kurze Meldung | Bessere UX, mehr Code | |

**Bei AX-Fehler mit Permission:** Stille Rückkehr

---

## Ausgabemodus UX

| Option | Beschreibung | Gewählt |
|--------|-------------|---------|
| Textfeld-Injektion | Core Value: Tippen-Ersatz | ✓ |
| Clipboard | Sicherer Start, kein Permission-Risk | |

**Standard-Modus:** Textfeld-Injektion

| Option | Beschreibung | Gewählt |
|--------|-------------|---------|
| Menü-Häkchen | ✓ Textfeld / ✓ Clipboard im Dropdown | ✓ |
| Icon ändert sich | Verwässert 4-Zustands-Semantik | |
| Kein Indikator | Schlechte UX | |

**Modus-Anzeige:** Menü-Häkchen

| Option | Beschreibung | Gewählt |
|--------|-------------|---------|
| ⇧⌘V | Shift+Cmd+V, Mnemonik Voice-Paste | ✓ |
| Kein Standard-Hotkey | User muss selbst konfigurieren | |

**Wechsel-Hotkey:** ⇧⌘V

---

## AX-Permission Onboarding

| Option | Beschreibung | Gewählt |
|--------|-------------|---------|
| Banner in SettingsView | Analog zu micPermissionDenied | ✓ |
| Menü-Warnung | Weniger auffällig, leichter | |

**Permission UX:** Banner in SettingsView

| Option | Beschreibung | Gewählt |
|--------|-------------|---------|
| Beim App-Start prüfen | Sofortiges Feedback | ✓ |
| Lazy bei erster Injektion | Spart API-Call, spätes Feedback | |

**Permission Check:** Beim App-Start via AXIsProcessTrusted()

---

## Deferred Ideas

- App-spezifischer Fallback (VS Code, Electron) → v2
- Cursor-Position-Awareness ohne fokussiertes Textfeld → v2
- Automatic Retry bei AX-Fehler → v2
