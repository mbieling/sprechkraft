# Phase 7: Parakeet Backend - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-24
**Phase:** 07-parakeet-backend
**Areas discussed:** WhisperKit-Fallback, Warmup-State & Icon, Download-Fortschritt UX, Fehlerbehandlung

---

## WhisperKit-Fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Auskommentiert im Code | WhisperKitBackend.swift bleibt als auskommentierte Datei. Kein Build-Overhead, kein SPM mehr. | ✓ |
| Feature Flag via Defaults | Backend per Defaults.Keys umschaltbar. Beide SPM-Dependencies im Build. | |
| Git-Tag / Branch | WhisperKit-Version als Tag gesichert, dann aus Code entfernt. | |

**User's choice:** Auskommentiert im Code

---

| Option | Description | Selected |
|--------|-------------|----------|
| WhisperKit SPM entfernen | Kleinerer Build, 2-Schritt-Reaktivierung. | ✓ |
| SPM drin lassen | Einfacheres Reaktivieren per Uncommenten. | |

**User's choice:** Entfernen

---

## Warmup-State & Icon

| Option | Description | Selected |
|--------|-------------|----------|
| Neuer .warmingUp State | RecordingState bekommt .warmingUp, klare Kommunikation. | ✓ |
| Transcribing-State wiederverwenden | Einfacher aber semantisch inkorrekt. | |
| Nur Menu-Text | Kein neuer State, aber weniger auffallend. | |

**User's choice:** Neuer .warmingUp State

---

| Option | Description | Selected |
|--------|-------------|----------|
| Blockiert — silent ignore | isModelReady bleibt false, bestehender Guard greift. | ✓ |
| Blockiert — mit Feedback | Kurze Benachrichtigung bei Hotkey-Druck. | |

**User's choice:** Blockiert — silent ignore

---

## Download-Fortschritt UX

| Option | Description | Selected |
|--------|-------------|----------|
| Spinner + Größen-Hinweis | Animierter Spinner, Menu-Text "~1.2 GB". API-unabhängig. | ✓ |
| Fake-Fortschritt | Progress-Bar linear bis 90%. Technisch unehrlich. | |
| Echter Progress wenn API verfügbar | Beim ersten Build prüfen, Fallback wenn nicht. | |

**User's choice:** Spinner + Größen-Hinweis

---

| Option | Description | Selected |
|--------|-------------|----------|
| Cache prüfen zuerst | Modell-Datei-Existenz explizit prüfen vor Download-UI. | ✓ |
| Immer durch downloadAndLoad | FluidAudio handled Cache intern. | |

**User's choice:** Cache prüfen zuerst

---

## Fehlerbehandlung

| Option | Description | Selected |
|--------|-------------|----------|
| Fehlerzustand in AppState | isModelError: Bool, .modelError State, Retry in Phase 8. | ✓ |
| Alles in Phase 7 inkl. Retry | Mehr Scope, vollständiger. | |
| Stille Rückkehr (aktuell) | Wie WhisperKit. Schlechte UX. | |

**User's choice:** Fehlerzustand in AppState

---

| Option | Description | Selected |
|--------|-------------|----------|
| Icon-Zustand .modelError | Fehler-Symbol im Menu-Bar-Icon. | ✓ |
| Nur Menü-Eintrag | Icon neutral, Fehler nur im Menü. | |

**User's choice:** Icon-Zustand .modelError

---

## Claude's Discretion

- SF-Symbol-Wahl für `.warmingUp` und `.modelError`
- Interne Struktur von ParakeetBackend
- Ob FluidAudio v3 einen echten Progress-Handler hat (beim ersten Build prüfen)

## Deferred Ideas

- Retry-Button → Phase 8
- Qualitätsvergleich WhisperKit vs. Parakeet → Phase 9
- 8-Bit-Quantisierung → v2
