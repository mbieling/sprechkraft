# Pitfalls Research

**Project:** VoiceScribe — macOS Menu Bar Dictation App
**Domain:** Native macOS, local ASR, Accessibility text injection, global hotkey
**Researched:** 2026-04-15
**Overall confidence:** HIGH for macOS/Swift/CoreML specifics; MEDIUM for Parakeet-specific behavior (limited public docs)

---

## Critical Pitfalls (Show-stoppers)

---

### C1: App Sandbox is Incompatible with This App's Core Features

**What goes wrong:**
If you enable the macOS App Sandbox (required for Mac App Store distribution), the app loses the ability to:
- Monitor global keyboard events (`NSEvent.addGlobalMonitorForEventsMatchingMask` is blocked)
- Inject text into other processes via Accessibility API (requires `com.apple.security.automation.apple-events`, which Apple does not grant to App Store apps that inject keystrokes into arbitrary apps)
- Use Carbon `RegisterEventHotKey` reliably across all apps

Attempting to sandbox the app and work around these restrictions with temporary exceptions almost never succeeds for App Store review. Apple's reviewer guidelines explicitly disallow automating other apps without disclosure, and the required entitlements (`com.apple.security.automation`) are classified as restricted.

**Why it happens:**
Apple's sandbox model treats cross-process automation as a privilege, not a right. Dictation apps that inject text into any frontmost app are categorically cross-process automation tools.

**Consequences:**
- App Store distribution is effectively blocked
- If sandboxing is added mid-project (e.g., hoping to ship via App Store later), it breaks hotkey and text injection — requiring a full permissions architecture rewrite

**Warning signs:**
- You see `AXError -25211 (kAXErrorCannotComplete)` when injecting text
- `NSEvent.addGlobalMonitorForEventsMatchingMask` returns a monitor object but never fires callbacks
- System log shows `sandbox: deny mach-lookup com.apple.accessibility.AXServer`

**Prevention:**
Distribute directly (notarized, not sandboxed). Decide this in Phase 1 and never add sandbox entitlements. Document the distribution model explicitly in the project.

**Phase:** Address in Phase 1 (project setup, entitlements, signing configuration). Never revisit.

---

### C2: Accessibility Permission Not Granted — Silent Failures at Runtime

**What goes wrong:**
`AXIsProcessTrusted()` returns `false` when the user has not granted Accessibility access in System Settings → Privacy & Security → Accessibility. All `AXUIElementSetAttributeValue` calls fail silently (return `kAXErrorAPIDisabled`) or with an opaque error. The app appears to work (no crash), but text never appears in the target app.

This is the single most common source of "it's broken on my machine" reports for dictation apps.

**Why it happens:**
macOS requires explicit per-app user consent for Accessibility. The permission is not granted by entitlement alone — the user must manually add the app in System Settings. After an app update that changes the binary signature (e.g., a new build), the permission can be silently revoked and must be re-granted.

**Consequences:**
- Text injection silently fails
- No user-facing error unless the app explicitly checks `AXIsProcessTrusted()` before every injection attempt
- After a code-signed update, users who updated must re-grant permission without any notification from the system

**Warning signs:**
- `AXUIElementSetAttributeValue` returns `kAXErrorAPIDisabled (-25211)`
- `AXIsProcessTrusted()` returns `false` at launch
- App works for developer but not for fresh-install testers

**Prevention:**
- Check `AXIsProcessTrusted()` at launch and on every injection attempt
- If `false`, show a modal pointing to System Settings with a deep link: `"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"`
- Never assume permission persists across binary updates — re-check on app launch
- Store permission state and show a persistent menu bar warning icon when not granted

**Phase:** Phase 1 (architecture), Phase 2 (text injection implementation). Detection UI must ship before any injection code.

---

### C3: AVAudioEngine Crashes on Audio Device Change

**What goes wrong:**
`AVAudioEngine` does not automatically handle hardware configuration changes (headphones plugged in or unplugged, USB audio interface connected/disconnected, AirPods switching to/from active device). When the audio hardware graph changes, the engine enters an inconsistent state. Attempting to continue recording causes a hard crash or silent audio capture failure (empty buffers with no error).

The notification that signals this is `AVAudioEngineConfigurationChangeNotification`. If not observed, the engine remains started against a now-invalid hardware configuration.

**Why it happens:**
`AVAudioEngine` builds a static node graph tied to the hardware's current sample rate and channel layout. When hardware changes, the graph becomes invalid. Apple documents this as requiring the developer to stop, reconfigure, and restart the engine.

**Consequences:**
- App crashes mid-dictation when user disconnects headphones
- Silent failure: recording appears active (UI shows recording state) but audio buffers are empty
- If the engine restart is not implemented, the only recovery is app restart

**Warning signs:**
- App crashes at `AVAudioEngine.inputNode` after audio device change
- Audio capture succeeds in testing (no device changes) but fails in production
- `AVAudioEngineConfigurationChangeNotification` is not observed in the codebase

**Prevention:**
```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleEngineConfigChange),
    name: .AVAudioEngineConfigurationChange,
    object: audioEngine
)

@objc func handleEngineConfigChange(_ notification: Notification) {
    stopRecording()
    reconfigureEngine()  // rebuild tap, reconnect nodes
    // Do NOT auto-restart — wait for user to initiate next recording
}
```
Always observe this notification before starting the engine. Reconfigure from scratch (don't try to patch the existing graph).

**Phase:** Phase 2 (audio capture implementation). Must be in the initial implementation, not a later fix.

---

### C4: Parakeet / Large Model Blocking the Main Thread on Load

**What goes wrong:**
Loading a large ASR model (Parakeet v3 at roughly 600MB–1.2GB depending on quantization) synchronously blocks the calling thread for 2–8 seconds on Apple Silicon, and 8–20+ seconds on Intel. If model loading is triggered on the main thread — even indirectly (e.g., lazy initialization when the user first presses the hotkey) — the entire app becomes unresponsive. The menu bar icon freezes, hotkey events queue up, and macOS may show the spinning beachball.

**Why it happens:**
CoreML's synchronous `MLModel(contentsOf:)` initializer blocks until the model is fully loaded and compiled. Model compilation from `.mlpackage` to `.mlmodelc` happens on first load and can add an additional 10–30 seconds on first launch. This compilation is cached, but the cache is invalidated on macOS version updates.

**Consequences:**
- App hangs at first dictation attempt
- User experience is broken on first use (worst possible first impression)
- On Intel Macs, the load time may be long enough that macOS kills the process

**Warning signs:**
- Model is loaded inside a `@MainActor` function or on `DispatchQueue.main`
- No loading indicator in the menu bar during initialization
- First hotkey press has a multi-second delay before recording starts

**Prevention:**
- Use `MLModel.load(contentsOf:configuration:)` async API (available macOS 12+)
- Load the model eagerly at app launch in a `Task` on a background actor, not on demand
- Show a loading state in the menu bar icon (e.g., grayed out or animated) until the model is ready
- Pre-compile the `.mlmodelc` at build time and bundle the compiled version, not the source `.mlpackage`
- For Parakeet specifically: if using whisper.cpp or ONNX runtime instead of CoreML, load on a background thread and use `DispatchQueue` or `async`/`await` with proper actor isolation

**Phase:** Phase 2 (model integration). The async loading architecture must be the initial design.

---

## Important Pitfalls (Significant rework risk)

---

### I1: Text Injection Fails in Specific App Categories

**What goes wrong:**
`AXUIElementSetAttributeValue(element, kAXValueAttribute, text)` works in most standard Cocoa apps but silently fails or partially works in:
- **Electron apps** (VS Code, Slack, Notion, Discord): These apps render their own text fields using Chromium's renderer, which has inconsistent Accessibility support. `AXValue` writes may be ignored or may replace the entire field contents instead of inserting at cursor position.
- **Terminal.app and iTerm2**: Terminal emulators do not expose editable text fields via Accessibility in the standard sense; text insertion requires CGEvent-based keystroke simulation.
- **Password fields**: Any field with `AXSecureText` role rejects external value writes — by design.
- **Web browsers** (address bar, specific web app inputs): Chrome and Firefox have partial Accessibility support; contenteditable divs and React-controlled inputs often lose the cursor position or trigger unexpected behavior.
- **Games and full-screen exclusive apps**: No accessibility tree at all.

**Why it happens:**
Accessibility API text injection was designed for screen readers, not text insertion tools. Many modern apps use custom rendering pipelines that don't implement the full Accessibility protocol, especially the writable `AXValue` and `AXSelectedTextRange` attributes.

**Consequences:**
- App works perfectly in TextEdit, Mail, Xcode but fails for the user's primary workflow app
- Partial injection (text appears but cursor is at wrong position)
- Double text (app receives both the injected text and echoed keypresses if both methods are used simultaneously)

**Warning signs:**
- `AXUIElementSetAttributeValue` returns `kAXErrorAttributeUnsupported` or `kAXErrorIllegalArgument`
- Testing only done in TextEdit or Notes — never in Electron apps

**Prevention:**
Implement a two-tier injection strategy from day one:
1. **Primary**: Try `AXUIElementSetAttributeValue` with `kAXSelectedTextAttribute` (insert at cursor) or fall back to `kAXValueAttribute` (replace full value)
2. **Fallback**: If `kAXErrorAttributeUnsupported` is returned, synthesize `CGEvent` keystroke events — this works in Terminal, Electron, and most other apps
3. **Last resort**: Copy to clipboard and notify the user

Test injection against: VS Code, Terminal, Chrome (address bar + body), Safari, Slack, TextEdit. These cover the failure cases.

**Phase:** Phase 2 (text injection). Design the fallback chain before implementing.

---

### I2: Global Hotkey Conflicts with System and App Shortcuts

**What goes wrong:**
Carbon's `RegisterEventHotKey` (the underlying API used by all Swift hotkey libraries including `soffes/HotKey`) fails silently when the requested key combination is already registered by the system or another app. The registration call returns `noErr` but the handler is never called — or worse, the system's handler fires instead of yours.

Common conflicts:
- `⌘Space` — Spotlight (cannot be overridden by apps)
- `^Space` — Input source switching
- `⌘⌥Esc` — Force Quit dialog
- `⌘⇧5` — Screenshot toolbar (macOS 10.14+)
- `⌘⇧4`, `⌘⇧3` — Screenshots
- Any hotkey registered by other running dictation apps (Dragon, Apple's built-in dictation via `Fn Fn`)

Additionally, `RegisterEventHotKey` silently fails for push-to-talk (hold-key-while-recording) workflows because Carbon hotkeys only report `keyDown` events, not the held state. Detecting hold-duration requires a separate `keyUp` event handler, which Carbon provides, but the pairing is fragile under fast key repeat.

**Why it happens:**
Carbon's hotkey API is first-registered-wins with no conflict detection API. The system's own shortcuts are registered at a higher priority level and cannot be intercepted.

**Consequences:**
- Users cannot use their preferred modifier+key combination
- No user feedback when registration silently fails
- Hold-to-record pattern requires careful `keyDown`/`keyUp` pairing — easy to have stuck recording state if `keyUp` is missed

**Warning signs:**
- Hotkey works in testing (no conflicts on dev machine) but fails for users
- `keyUp` event sometimes not received (app stays in recording state indefinitely)
- No conflict detection in the registration code

**Prevention:**
- Default hotkey should use an unusual combination: `⌥⌘R` or `⌘⌃.` — avoid anything with just `⌘` or `⌃`
- Verify registration actually works by trying a test fire after registration; log a warning if it doesn't fire within a timeout
- For push-to-talk: implement a safety timeout — if `keyUp` is not received within 60 seconds, auto-stop recording
- Consider using `CGEventTap` instead of Carbon for the hold-detection path, though this requires Accessibility permission (already needed for text injection)
- Expose hotkey conflict detection in settings: "This shortcut may conflict with [app name]"

**Phase:** Phase 1 (architecture decision on hotkey approach), Phase 2 (implementation with safety timeout).

---

### I3: Groq API Key Stored Insecurely

**What goes wrong:**
Developers commonly make one of these mistakes with API keys on macOS:
1. Store the key in `UserDefaults` — readable by any app that knows the bundle ID, and stored in plaintext in `~/Library/Preferences/`
2. Store the key in `kSecAttrAccessibleWhenUnlocked` Keychain class — works on screen but the app cannot read the key when the screen is locked (relevant for a background menu bar app that might need to make an API call when the screen locks)
3. Hardcode the key in source code — ends up in version control
4. Store in a local file without encryption — shows up in disk backups

For a menu bar app that runs continuously in the background, `kSecAttrAccessibleWhenUnlocked` is the wrong accessibility class because macOS allows the screen to lock while the app is running.

**Why it happens:**
`UserDefaults` is the path of least resistance for persistent storage in SwiftUI. `kSecAttrAccessibleWhenUnlocked` is the default Keychain accessibility level and sounds like the "secure" choice.

**Consequences:**
- API key exposed if another app reads UserDefaults (unlikely but possible with malicious apps)
- Keychain reads fail at runtime when screen is locked, causing API calls to silently fail or crash
- In a future scenario where the app is open-sourced, a hardcoded key is immediately exposed

**Warning signs:**
- API key read from `UserDefaults` in any code path
- Keychain query uses `kSecAttrAccessibleWhenUnlocked` for a key that the app reads from a background context
- API key stored as a plain string in any file

**Prevention:**
- Store in Keychain with `kSecAttrAccessibleAfterFirstUnlock` (persists across lock/unlock, survives background operation, is device-local)
- Never use `UserDefaults` for sensitive values
- Use `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` if the key should not migrate via iCloud Keychain

```swift
// Correct accessibility for a background menu bar app:
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "VoiceScribe",
    kSecAttrAccount as String: "groq-api-key",
    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
    kSecValueData as String: keyData
]
```

**Phase:** Phase 1 (settings/storage architecture). Cannot be retrofitted cleanly without user data migration.

---

### I4: Model Memory Not Released Between Recordings

**What goes wrong:**
Parakeet / CoreML models hold their weight tensors in memory for the lifetime of the model object. If the model object is loaded per-recording (not cached), each call allocates 600MB–1.2GB and the previous allocation may not be released immediately due to Swift ARC and CoreML's internal caching. On a MacBook with 8GB unified memory, running 3–4 recordings in quick succession can exhaust RAM, causing swapping and then OS-level memory pressure kills.

Conversely, if the model is kept alive permanently but the audio processing buffers are not released after inference, memory grows unboundedly over long sessions.

**Why it happens:**
CoreML models allocate GPU/Neural Engine memory that is not tracked by Swift's ARC alone — it lives in the Metal heap or ANE memory space. Releasing the Swift reference does not immediately reclaim this memory.

**Consequences:**
- Progressively slower transcription as memory pressure increases
- macOS kills the app after extended use sessions
- On 8GB M1 machines, visible in Activity Monitor as memory ballooning

**Warning signs:**
- Memory usage grows with each recording in Instruments' Allocations tool
- Model is instantiated inside the recording loop rather than at app startup
- No explicit nil assignment to temporary buffers after inference

**Prevention:**
- Load the model once at startup and keep a single shared instance
- Use `autoreleasepool {}` around inference calls to ensure temporary tensors are promptly reclaimed
- Profile with Instruments (Allocations + VM Tracker) after 10+ consecutive recordings
- For audio buffers: explicitly release `AVAudioPCMBuffer` instances after passing audio data to the model

**Phase:** Phase 2 (model integration). Profile before any beta release.

---

### I5: Microphone Permission Not Requested Correctly

**What goes wrong:**
`AVCaptureDevice.requestAccess(for: .audio)` or `AVAudioApplication.requestRecordPermission` must be called before any audio capture begins. If audio capture is attempted without explicit permission, it silently returns empty buffers. The `NSMicrophoneUsageDescription` key must be present in `Info.plist` or the app crashes on first access.

More subtly: on macOS 14+ (Sonoma), the microphone permission prompt has changed behavior — it may be shown at system login if the app registers for autostart, confusing users who have not yet launched the app interactively.

**Why it happens:**
Missing `Info.plist` key is caught immediately (crash), but missing explicit permission request before capture is not — it just silently records nothing.

**Consequences:**
- App silently records empty audio; model transcribes silence and outputs nothing
- User sees no error, assumes the app is broken
- Confusing permission prompt at login if autostart is registered before first interactive launch

**Warning signs:**
- `NSMicrophoneUsageDescription` missing from `Info.plist`
- Permission check not shown before first recording attempt
- Audio buffer contains all-zero samples

**Prevention:**
- Request microphone permission explicitly at first launch (not lazily on first recording)
- Show a pre-permission explanation screen before triggering the system prompt
- Verify permission with `AVCaptureDevice.authorizationStatus(for: .audio)` at each recording start; show UI if denied
- Delay autostart registration until after the user has completed first-run setup and granted permissions

**Phase:** Phase 1 (entitlements, Info.plist). Phase 2 (first-run UX flow).

---

## Minor Pitfalls (Worth knowing)

---

### M1: Apple Silicon vs Intel CoreML Compute Unit Selection

**What goes wrong:**
Using `MLComputeUnits.all` on Apple Silicon routes computation through the Neural Engine (ANE), which is fastest and most power-efficient. On Intel Macs, `.all` routes to GPU which may not be significantly faster than CPU for audio/speech models. Using `.cpuOnly` on Apple Silicon is safe but throws away 5–10x performance from the ANE.

Parakeet v3 (if packaged as a CoreML model) may or may not have an ANE-compatible architecture — ANE requires specific operator support and float16 precision. If the model uses operators unsupported by ANE, CoreML silently falls back to CPU even when `.all` is requested.

**Warning signs:**
- Inference time > 2 seconds on M-series chips for short audio clips
- Instruments shows 0% ANE utilization during inference
- Model was converted without explicit ANE compatibility validation

**Prevention:**
- Always use `MLComputeUnits.all` as default; CoreML will use the best available backend
- Profile with Instruments (Core ML Instrument) to verify which compute unit is actually used
- For whisper.cpp/ONNX-based approach: Metal backend (`WHISPER_METAL=1`) is the correct equivalent on Apple Silicon
- Test explicitly on both Apple Silicon and Intel if Intel support is required

**Phase:** Phase 2 (model optimization pass). Not a blocker for initial implementation.

---

### M2: Menu Bar App Appearing in the Dock or App Switcher

**What goes wrong:**
A Menu Bar-only app must set `LSUIElement = YES` in `Info.plist` to suppress the Dock icon and hide from `⌘Tab` app switcher. If this key is missing, the app appears in the Dock and Cmd-Tab — breaking the "system utility" UX. Adding it later forces all existing users to restart the app for the change to take effect.

In SwiftUI, using `@main App` with `WindowGroup` as the scene type will create a standard app window. A Menu Bar app requires `MenuBarExtra` scene (macOS 13+) and no `WindowGroup` — otherwise a blank window may flash on launch.

**Warning signs:**
- App icon appears in Dock during testing
- Blank window appears on first launch
- `Settings` or `⌘W` closes the app instead of dismissing a panel

**Prevention:**
- Set `LSUIElement = YES` and `LSBackgroundOnly = NO` in `Info.plist` from day one
- Use `MenuBarExtra` as the primary scene in SwiftUI App
- Use `Settings { ... }` scene for the preferences window
- Verify no `WindowGroup` is present unless explicitly needed for a non-modal window

**Phase:** Phase 1 (project setup).

---

### M3: History Database Corruption on Unclean Shutdown

**What goes wrong:**
If the app is force-quit mid-write to a SQLite database (or JSON file), the history file can become corrupted. This is particularly relevant for a menu bar app that can be force-quit at any time via the Activity Monitor or system restart. On next launch, the app fails to read history and may crash or show empty history.

**Warning signs:**
- History disappears after macOS restart or app crash
- SQLite "database disk image is malformed" error in logs
- Write to history happens synchronously on the main thread, blocking the app during shutdown

**Prevention:**
- Use SQLite with WAL (Write-Ahead Logging) mode: `PRAGMA journal_mode=WAL` — provides crash-safe writes
- Or use Core Data (which uses SQLite with WAL by default)
- Wrap all history writes in a proper transaction
- Register for `NSApplicationWillTerminate` to flush any pending writes before exit

**Phase:** Phase 3 (history feature). Use WAL from the start, not as a fix.

---

### M4: UX — Recording State Not Clearly Visible

**What goes wrong:**
The most common UX complaint in dictation apps is users not knowing whether the app is actively recording. A menu bar icon that subtly changes color is insufficient feedback when the user is looking at their document, not the menu bar.

A push-to-talk hold gesture (hold hotkey → record → release) is intuitive but fails when:
- The user holds too briefly (misses the hold detection threshold)
- The user holds too long without speaking (records silence, wastes tokens on Groq)
- The user cannot tell if the hotkey was received (no auditory or visual feedback)

**Warning signs:**
- No audio or visual cue at recording start beyond menu bar icon
- No feedback when Groq processing is in progress (user starts typing over where the text will appear)
- Processing spinner in menu bar not distinguishable from recording spinner

**Prevention:**
- Play a subtle system sound (or custom sound) at recording start and stop
- Use distinct, high-contrast menu bar icon states: idle / recording (red pulse) / processing (spinner)
- Disable recording start if Accessibility permission is not granted — don't silently do nothing
- Add a minimum hold duration (e.g., 200ms) to avoid accidental triggers from fast hotkey presses

**Phase:** Phase 2 (recording UX). Core part of the push-to-talk interaction design.

---

### M5: Groq API Rate Limits and Latency Under LLM Post-Processing

**What goes wrong:**
Groq's free/low-tier API has rate limits (tokens per minute, requests per minute). If the user dictates frequently, sequential recordings that each trigger a Groq call can hit rate limits, causing failures for the 2nd–3rd recording in a short session. The error is an HTTP 429 and must be handled gracefully.

Additionally, even on Groq's fast inference, `qwen3-32b` adds 1–3 seconds of latency per request. If the user starts typing into the target field immediately after releasing the hotkey, text injection may arrive after the user has already typed, causing text to be inserted at the wrong cursor position.

**Warning signs:**
- Second recording in a session silently produces no output
- HTTP 429 error not surfaced to user
- Text appears at wrong position in the document when user types quickly after dictation

**Prevention:**
- Implement exponential backoff for Groq API calls (max 2 retries)
- Show "Processing..." state in menu bar icon while waiting for Groq
- After Groq completes, check whether the focus target has changed before injecting; if focus moved, fall back to clipboard
- Allow disabling LLM post-processing per-profile for latency-sensitive use

**Phase:** Phase 3 (LLM integration). Error handling must be designed before first API call.

---

## Phase Mapping Summary

| Phase | Critical Pitfall to Address |
|-------|-----------------------------|
| Phase 1 (Setup) | C1 — No sandbox, direct distribution only. C2 — Accessibility permission check architecture. I3 — Keychain with `AfterFirstUnlock`. I5 — Info.plist microphone key. M2 — `LSUIElement`, `MenuBarExtra` scene. |
| Phase 2 (Core: Audio + Transcription + Injection) | C3 — `AVAudioEngineConfigurationChangeNotification`. C4 — Async model loading at startup. I1 — Two-tier text injection (AX + CGEvent fallback). I2 — Hotkey safety timeout for hold-to-talk. I4 — Single shared model instance, memory profiling. I5 — Permission request UX. M1 — Compute unit selection. M4 — Recording state feedback. |
| Phase 3 (LLM + History) | I3 — Confirmed Keychain implementation. M3 — SQLite WAL for history. M5 — Groq error handling, latency UX. |

---

## Sources

- Apple CoreML documentation: `MLComputeUnits`, `MLModel.load` async API — HIGH confidence
- Apple coremltools docs: quantization, model size — HIGH confidence (Context7 /apple/coremltools)
- whisper.cpp: Metal backend CMake options — HIGH confidence (Context7 /ggml-org/whisper.cpp)
- Apple Developer Forums thread on Keychain `kSecAttrAccessibleAfterFirstUnlock` background behavior — MEDIUM confidence (content from documentation proxy)
- AVAudioEngine `AVAudioEngineConfigurationChangeNotification` — HIGH confidence (Apple documented API, author knowledge)
- Sandbox restrictions on global event monitoring — HIGH confidence (NSEvent documentation, widely confirmed in developer community)
- Electron Accessibility API limitations — MEDIUM confidence (widely reported in dictation app communities, including VoiceInk and similar projects; no single authoritative source)
- Carbon `RegisterEventHotKey` silent failure on conflict — HIGH confidence (Carbon API documented behavior, widely observed)
- HotKey library (`soffes/HotKey`) basics — HIGH confidence (Context7 /soffes/hotkey)
- `LSUIElement` Menu Bar app requirements — HIGH confidence (standard macOS app lifecycle docs)
