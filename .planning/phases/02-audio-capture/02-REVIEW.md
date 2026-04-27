---
phase: 02-audio-capture
reviewed: 2026-04-17T00:00:00Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - SPRECHKRAFT/AppDelegate.swift
  - SPRECHKRAFT/AppState.swift
  - SPRECHKRAFT/Audio/AudioController.swift
  - SPRECHKRAFT/Audio/AudioDeviceManager.swift
  - SPRECHKRAFT/SettingsView.swift
  - SPRECHKRAFT/StatusBarIconView.swift
  - SPRECHKRAFT/SPRECHKRAFTApp.swift
  - SPRECHKRAFTTests/AppStateTests.swift
  - SPRECHKRAFTTests/AudioControllerTests.swift
  - SPRECHKRAFTTests/DefaultsKeysTests.swift
  - SPRECHKRAFTTests/WaveformViewTests.swift
findings:
  critical: 0
  warning: 3
  info: 3
  total: 6
status: issues_found
---

# Phase 02: Code Review Report — Audio Capture

**Reviewed:** 2026-04-17
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

All eleven files were reviewed. The overall structure is sound: thread-safety contracts
are correctly established (`@unchecked Sendable`, `Task { @MainActor }` bridges),
the `weak appState` pattern in `AudioController` is correct, and `weak self` capture
in AppDelegate callbacks avoids reference cycles. Swift 6 concurrency annotations are
consistently applied.

Three warning-level bugs were found. The most impactful is a logic error in the
silence-detection accumulator that causes `onAutoStop` to fire repeatedly once the
silence threshold is crossed, flooding the main actor queue. The second is a visual
correctness issue from creating `NSHostingView` on every audio buffer callback
(~86 Hz). The third is a missing `updateIcon()` call in the `startRecording()` error
path that leaves the icon visually stale.

Three info-level items cover a known race-prone workaround (acknowledged with TODO),
and two minor test-coverage gaps.

---

## Warnings

### WR-01: Silence auto-stop fires on every silent buffer after threshold is crossed

**File:** `SPRECHKRAFT/Audio/AudioController.swift:154-167`

**Issue:** `updateSilenceDetection` never resets `silenceAccumulator` after the
threshold is crossed. Once `silenceAccumulator >= Defaults[.silenceDuration]`, every
subsequent silent buffer satisfies the condition and dispatches a new
`Task { @MainActor in self?.onAutoStop?() }`. This floods the main actor queue with
redundant auto-stop calls for the entire remainder of the silent period — potentially
dozens of tasks before `stopRecording()` is actually executed. While the guard in
`AppDelegate.stopRecordingWithCue()` prevents double-stops from a state perspective,
the repeated task dispatch is a logic error and a fragile pattern.

**Fix:** Reset the accumulator after firing, and optionally add a flag to prevent
re-entry:

```swift
func updateSilenceDetection(rms: Float, bufferDuration: TimeInterval) {
    if rms < silenceThresholdRMS {
        silenceAccumulator += bufferDuration
        if silenceAccumulator >= Defaults[.silenceDuration] {
            silenceAccumulator = 0  // prevent repeated firing on subsequent buffers
            Task { @MainActor [weak self] in
                self?.onAutoStop?()
            }
        }
    } else {
        silenceAccumulator = 0
    }
}
```

---

### WR-02: `updateIcon()` creates and discards `NSHostingView` at audio-buffer rate (~86 Hz)

**File:** `SPRECHKRAFT/AppDelegate.swift:177-192`

**Issue:** `updateIcon()` is called from the `onLevelUpdate` callback, which fires on
every audio tap buffer. At 44100 Hz sample rate with a `bufferSize: 1024`, this is
approximately 43 callbacks per second, each dispatched to the main actor. Each call
constructs a new `NSHostingView`, removes all existing subviews, and adds the new one.
Creating/destroying SwiftUI hosting views at this rate causes visible flicker in the
status bar icon because AppKit re-renders the button's subview layer on every swap.
This crosses from a performance concern into a functional visual correctness problem.

**Fix:** Cache the hosting view and update it by passing new state values, or throttle
`onLevelUpdate` to a display-appropriate rate (e.g., ~12–15 Hz):

```swift
// Option A: throttle in AudioController tap — only signal if level changed significantly
let clampedLevel = CGFloat(min(1.0, rms * 4.0))
// Only dispatch if level changed by more than a threshold (e.g., 0.05)
if abs(clampedLevel - lastDispatchedLevel) > 0.05 {
    lastDispatchedLevel = clampedLevel
    Task { @MainActor [weak self] in
        self?.appState?.audioLevel = clampedLevel
        self?.onLevelUpdate?()
    }
}

// Option B: in AppDelegate, update the existing hosting view's rootView
// by keeping a reference to it and updating via a @State or @Observable binding
// rather than replacing the entire NSHostingView on every call.
```

---

### WR-03: Missing `updateIcon()` call in `startRecordingWithCue()` error path

**File:** `SPRECHKRAFT/AppDelegate.swift:66-78`

**Issue:** In `startRecordingWithCue()`, `appState?.toggleRecording()` moves state to
`.recording` before `startRecording()` is called. If `startRecording()` throws,
`appState?.resetToIdle()` correctly resets the model state, but `updateIcon()` is not
called. The status bar icon remains visually in the `.recording` state (red, pulsing)
until the next external event triggers an update.

**Fix:** Add `updateIcon()` in the catch block:

```swift
do {
    try audioController?.startRecording()
    NSSound(named: NSSound.Name("Tink"))?.play()
} catch {
    appState?.resetToIdle()
    updateIcon()   // add this line
}
```

---

## Info

### IN-01: Race-prone `Task.sleep` workaround for activation policy reset

**File:** `SPRECHKRAFT/SPRECHKRAFTApp.swift:73-75`

**Issue:** The settings-window activation flow resets `NSApp.setActivationPolicy` to
`.accessory` after a hardcoded 300 ms sleep. The TODO comment correctly identifies the
risk: if macOS takes longer than 300 ms to make the window key (e.g., under system
load), the activation policy reverts before the window is front, causing the window to
not appear correctly. This is a known Phase 1 workaround, but it should be resolved
before production.

**Fix:** Replace the sleep with a one-shot `NSWindow.didBecomeKeyNotification` observer
as noted in the TODO comment, reverting `.accessory` only after the window confirms it
is key.

---

### IN-02: `testSilenceDetection_triggersAfterDuration` accumulates exactly at threshold boundary

**File:** `SPRECHKRAFTTests/AudioControllerTests.swift:60-82`

**Issue:** The test passes `3 x 0.5s = 1.5s` silence with `silenceDuration = 1.5s`.
The condition `silenceAccumulator >= silenceDuration` is a `>=` check, so the
accumulator reaches exactly `1.5` on the third call and triggers. This works, but
due to floating-point accumulation (`0.5 + 0.5 + 0.5` may not equal exactly `1.5`
in all FP implementations), the test could theoretically be fragile. Consider using
a value slightly above threshold (e.g., `3 x 0.6s = 1.8s`) to ensure robust crossing.

**Fix:**
```swift
// More robust: use a duration that clearly exceeds the threshold
controller.updateSilenceDetection(rms: 0.001, bufferDuration: 0.6)
controller.updateSilenceDetection(rms: 0.001, bufferDuration: 0.6)
controller.updateSilenceDetection(rms: 0.001, bufferDuration: 0.6)
// 1.8s > 1.5s threshold — not subject to exact FP boundary
```

---

### IN-03: WaveformView tests verify instantiation only

**File:** `SPRECHKRAFTTests/WaveformViewTests.swift:15-45`

**Issue:** All five `WaveformView` and `StatusBarIconView` tests confirm the types can
be instantiated but do not assert any properties. The test file itself notes that
Canvas rendering is not automatically testable, which is correct. However, the
`level`/`audioLevel` boundary constraints (`0.0` to `1.0`) could be verified via
property access rather than visual inspection. This is an acceptable coverage gap for
Phase 2, but worth closing before Phase 3 adds more complex state.

**Fix:** Consider adding property-level assertions where possible:
```swift
@Test("WaveformView akzeptiert level 0.0 (Stille)")
func testWaveformView_silentLevel() {
    let view = WaveformView(level: 0.0)
    #expect(view.level == 0.0)  // assert the stored property
}
```

---

_Reviewed: 2026-04-17_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
