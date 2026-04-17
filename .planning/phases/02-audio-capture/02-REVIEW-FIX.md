---
phase: 02-audio-capture
fixed_at: 2026-04-17T00:00:00Z
review_path: .planning/phases/02-audio-capture/02-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 2
skipped: 1
status: partial
---

# Phase 02: Code Review Fix Report

**Fixed at:** 2026-04-17
**Source review:** .planning/phases/02-audio-capture/02-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 3
- Fixed: 2
- Skipped: 1

## Fixed Issues

### WR-01: Silence auto-stop fires on every silent buffer after threshold is crossed

**Files modified:** `VoiceScribe/Audio/AudioController.swift`
**Commit:** 4a52487
**Applied fix:** `silenceAccumulator = 0` direkt vor dem `Task { @MainActor }` Dispatch in `updateSilenceDetection()` eingefügt. Verhindert, dass nach Überschreitung des Schwellwerts jeder weitere stille Buffer einen neuen Auto-Stopp-Task auslöst.

### WR-02: `updateIcon()` creates and discards `NSHostingView` at audio-buffer rate (~86 Hz)

**Files modified:** `VoiceScribe/Audio/AudioController.swift`
**Commit:** ea0a32a
**Applied fix:** Option A (Throttle im Tap) umgesetzt. Neue Property `lastDispatchedLevel: CGFloat = -1` hinzugefügt. Im Tap-Block wird ein `guard abs(clampedLevel - self.lastDispatchedLevel) > 0.05` eingefügt — Level-Updates werden nur noch dispatcht wenn sich der Pegel um mehr als 5% geändert hat. `lastDispatchedLevel` wird in `startRecording()` und `stopRecording()` auf `-1` zurückgesetzt, damit der erste Dispatch der neuen Session sicher feuert.

## Skipped Issues

### WR-03: Missing `updateIcon()` call in `startRecordingWithCue()` error path

**File:** `VoiceScribe/AppDelegate.swift:66-78`
**Reason:** Fix bereits implizit vorhanden — kein Handlungsbedarf. Der aktuelle Code hat `updateIcon()` auf Zeile 77 **ausserhalb** des do/catch-Blocks. Damit wird `updateIcon()` in beiden Pfaden ausgeführt: sowohl bei erfolgreichem Start als auch nach einem Fehler (catch-Pfad mit `appState?.resetToIdle()`). Der Reviewer hat den Code möglicherweise mit einer früheren Version analysiert, in der `updateIcon()` noch innerhalb des do-Blocks (nur bei Erfolg) stand. Das Verhalten ist aktuell korrekt.
**Original issue:** Icon bleibt nach fehlgeschlagenem `startRecording()` visuell im `.recording`-Zustand, weil `updateIcon()` im catch-Block fehlte.

---

_Fixed: 2026-04-17_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
