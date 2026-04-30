---
status: partial
phase: 07-parakeet-backend
source: [07-VERIFICATION.md]
started: 2026-04-30T00:00:00Z
updated: 2026-04-30T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Modell-Download-UX beim Erststart (SC2)

expected: Menüleisten-Icon zeigt orange arrow.down.circle (.modelLoading), Titel "Parakeet-Modell wird geladen (~1.2 GB)…", nach Abschluss hourglass (.warmingUp), dann grauer Mic (.idle). Hotkey ⌥⌘R während Download startet kein Recording.
result: [pending]

**Verify:**
1. `rm -rf ~/Library/Application\ Support/FluidAudio/Models`
2. App starten
3. Orange Icon + Titel-Text beobachten → nach Download `.warmingUp` → `.idle`
4. Hotkey während Download drücken — kein Recording

### 2. Live-Transkription via FluidAudio/Parakeet TDT v3 (SC1)

expected: ⌥⌘R drücken → sprechen → loslassen → sinnvolle Transkription im aktiven Textfeld oder Clipboard. Keine [ParakeetBackend] Fehlermeldungen in der Konsole, keine WhiskerKit-Referenzen.
result: [pending]

**Verify:**
1. Warten bis `.idle` (Modell bereit)
2. ⌥⌘R → "Hallo, das ist ein Test für die Diktat-App." → ⌥⌘R
3. Transkription im Textfeld prüfen
4. Stille/zu kurze Aufnahme → kein Output

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
