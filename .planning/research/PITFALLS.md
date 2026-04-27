# Pitfalls Research

**Project:** SPRECHKRAFT — macOS Menu Bar Dictation App
**Domain:** Native macOS, local ASR, Accessibility text injection, global hotkey
**Researched:** 2026-04-15 (initial); 2026-04-21 (v0.19.0 supplement: Python/MLX subprocess + Settings UI)
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

### C5: SIP Strips DYLD_LIBRARY_PATH Before Python Subprocess Starts

**What goes wrong:**
macOS System Integrity Protection (SIP) removes all `DYLD_*` environment variables before launching any child process spawned by a hardened runtime app. This means `DYLD_LIBRARY_PATH` and `DYLD_FALLBACK_LIBRARY_PATH` — which many Python venv setups rely on to find bundled `.dylib` files — are silently stripped and never reach the Python interpreter.

The subprocess appears to launch but immediately crashes with `Library not loaded: @rpath/libpython3.x.dylib` or similar. The error is written to stderr, which is often not monitored, so the Swift side receives an empty stdout and interprets it as a transcription failure.

**Why it happens:**
`DYLD_*` variables are a documented attack vector for bypassing code signature validation. SIP strips them unconditionally for any process launched from a hardened-runtime parent, regardless of the variables' intended use. This is not a bug — it is intentional security policy.

**Consequences:**
- Python subprocess crashes on launch; Swift receives empty transcription result
- Error is invisible unless stderr is explicitly read
- Works perfectly in development (where SIP may be partially relaxed, Xcode injects entitlements) but fails in production distribution

**Warning signs:**
- `libpython*.dylib` not found errors in the system log
- Python process exits with code 1 immediately after `launch()`
- Transcription silently returns empty string in production builds only

**Prevention:**
- Use `@rpath`-relative linkage baked into the Python binary at build time rather than `DYLD_LIBRARY_PATH`. Embed the Python framework at `Contents/Frameworks/` and rewrite install names with `install_name_tool -change` and `install_name_tool -rpath` before signing.
- Include the entitlement `com.apple.security.cs.disable-library-validation` — for local-distribution-only apps (no notarization required) this is acceptable.
- Alternatively, use a fully self-contained Python binary (e.g., from `python-build-standalone`) where all stdlib `.dylib` dependencies are statically linked or co-located with correct rpath baked in.
- Test the production build outside Xcode, from a standard user account without SIP disabled.

**Phase:** v0.19.0 (Parakeet integration). Must be resolved before any production testing.

---

### C6: Python Subprocess Pipe Deadlock Under Buffered Output

**What goes wrong:**
When Swift reads from the Python subprocess's stdout `Pipe`, a deadlock occurs if:
1. The Python process writes more data to stderr than the OS pipe buffer can hold (~64 KB on macOS) while Swift is only reading from stdout.
2. The Python process writes to both stdout and stderr, Swift reads from one sequentially — the unread pipe fills up, blocking the Python process, which cannot write to the other pipe, causing both sides to wait forever.

Foundation's `Process` API with `standardOutput = Pipe()` and `standardError = Pipe()` requires both pipes to be drained concurrently. Reading one then the other sequentially is the most common mistake.

**Why it happens:**
OS pipe buffers are finite (64 KB). When the buffer fills, the writing process blocks until the reader drains it. MLX outputs verbose progress and Metal compilation logs to stderr during model load, which can easily exceed 64 KB.

**Consequences:**
- App hangs indefinitely on first transcription (or on every transcription if MLX is verbose)
- Deadlock is non-deterministic — works for short audio, fails for longer recordings that produce more output
- No timeout fires because the process never exits; it is blocked in a write syscall

**Warning signs:**
- Transcription hangs for audio clips longer than ~15 seconds
- `process.waitUntilExit()` never returns
- Python process shows as running but not consuming CPU in Activity Monitor

**Prevention:**
- Drain stdout and stderr on separate concurrent tasks/threads simultaneously:

```swift
let stdoutData = try await Task.detached {
    pipe.fileHandleForReading.readDataToEndOfFile()
}.value

// WRONG — reading stderr after stdout may deadlock if stderr filled first
```

```swift
// CORRECT — drain both pipes concurrently
async let stdout = Task.detached { stdoutPipe.fileHandleForReading.readDataToEndOfFile() }
async let stderr = Task.detached { stderrPipe.fileHandleForReading.readDataToEndOfFile() }
let (out, err) = await (stdout.value, stderr.value)
```

- Alternatively, redirect Python's stderr to `/dev/null` if verbose logs are not needed (acceptable for production).
- Set a timeout: if the subprocess has not exited within N seconds (e.g., 30), `terminate()` and report an error.

**Phase:** v0.19.0 (Parakeet subprocess bridge). The concurrent drain pattern must be the initial implementation.

---

### C7: All Bundled .so and .dylib Files Must Be Individually Code-Signed

**What goes wrong:**
When distributing a macOS app that embeds a Python environment, every binary file inside the bundle (`.dylib`, `.so`, the Python interpreter itself, compiled extension modules) must be individually code-signed with the same developer certificate. If any are unsigned or signed with a different identity, Gatekeeper blocks the app on launch with a generic "can't be opened" error.

The specific failure mode for Python bundles: extension modules (e.g., `numpy`, `mlx`, `soundfile`) ship as `.so` files. These are treated as Mach-O binaries by Gatekeeper and must each be signed with `codesign --timestamp -o runtime`.

**Why it happens:**
Apple's hardened runtime requirement mandates that every executable Mach-O in the bundle carry a valid code signature. The check is recursive — signing only the `.app` wrapper does not sign nested binaries.

**Consequences:**
- App is blocked by Gatekeeper on first launch on any machine other than the developer's
- Error message gives no indication of which binary is unsigned
- Signing each binary manually after adding new Python packages is tedious and easy to forget

**Warning signs:**
- `codesign --verify --deep --strict SPRECHKRAFT.app` reports unsigned binaries
- App opens on developer machine (where Gatekeeper may be relaxed) but not on other machines
- System log contains `AMFI: ... not valid`

**Prevention:**
- Write a build script that signs every file matching `**/*.so` and `**/*.dylib` inside the bundle before the final app signing step.
- Sign leaf binaries first (innermost), then the outer `.app` wrapper last.
- Use `--timestamp` and `-o runtime` flags on every `codesign` invocation.
- For local-only distribution (no notarization), `xattr -r -d com.apple.quarantine SPRECHKRAFT.app` removes the quarantine flag that triggers Gatekeeper for the developer's own use.

```bash
# Sign all Python extension modules and dylibs
find SPRECHKRAFT.app -name "*.so" -o -name "*.dylib" | while read f; do
  codesign --force --timestamp -o runtime --sign "Developer ID Application: ..." "$f"
done
# Sign the app bundle last
codesign --force --deep --timestamp -o runtime --sign "Developer ID Application: ..." SPRECHKRAFT.app
```

**Phase:** v0.19.0 (Parakeet bundling). Must be automated in the build process, not a manual step.

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
    kSecAttrService as String: "SPRECHKRAFT",
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

### I6: Python venv Symlinks Are Relative — They Break When the App Is Moved

**What goes wrong:**
A standard Python `venv` at `Contents/Resources/venv/` contains symlinks to the Python interpreter (e.g., `venv/bin/python3 -> /usr/local/bin/python3`). These symlinks point to the system Python used at creation time, which:
- May not exist on the user's machine
- Points outside the `.app` bundle, violating bundle self-containment

When the Python interpreter path embedded in the venv is absolute and points to a system location, the subprocess fails with `python3: command not found` or a `Library not loaded` error on any machine where that exact Python version is not installed at that exact path.

**Why it happens:**
The `venv` module creates relative or absolute symlinks depending on how `python -m venv` is invoked. If created against a Homebrew or pyenv Python, the symlink is absolute to that installation. The `.app` bundle cannot carry that external dependency.

**Consequences:**
- App works on developer machine (has the right Python) but not on any other machine
- Error is not obvious — Python appears to be present but the wrong version is found

**Warning signs:**
- `venv/bin/python3` is a symlink to `/usr/local/...` or `/opt/homebrew/...`
- App works in development but fails for any other user
- `python3 --version` inside the subprocess returns the wrong version or fails

**Prevention:**
- Use `python-build-standalone` (Gregory Szorc's builds) as the base interpreter. These are fully self-contained, portable, and not Homebrew-dependent.
- Embed the Python interpreter at `Contents/Frameworks/Python.framework/` or `Contents/Resources/python/`. Replace venv symlinks with actual copies or use `--copies` flag: `python -m venv --copies venv`.
- After building the venv, verify: `file venv/bin/python3` should be a Mach-O binary, not a symlink.
- Use `otool -L venv/bin/python3` to verify all dylib dependencies are either within the bundle or in `/usr/lib/` (system-provided, always present).

**Phase:** v0.19.0 (Parakeet bundling). Foundation decision — cannot be changed incrementally.

---

### I7: MLX Memory Pressure Causes Kernel Panic or App Kill on Low-RAM Macs

**What goes wrong:**
MLX wires GPU memory for loaded models. On Apple Silicon, CPU and GPU share the same physical memory pool. When `parakeet-mlx` loads its model weights into the MLX cache, it allocates a large contiguous chunk of wired (non-swappable) GPU memory. On Macs with 8 GB unified memory, loading a 1.2 GB model plus MLX's operational buffers plus the rest of the OS can exhaust available memory, causing:
- macOS Jetsam OOM killer to terminate the Python subprocess
- In severe cases: IOGPUMemory crash → kernel panic (documented in `mlx-lm` issue #883)

The subprocess is terminated silently; the Swift parent receives an unexpected process exit.

**Why it happens:**
MLX by default does not limit its GPU memory pool. Metal memory is wired, meaning macOS cannot reclaim it by paging to disk. Unlike CPU memory pressure (which causes slowdowns), GPU memory exhaustion causes hard termination.

**Consequences:**
- Transcription silently fails on low-RAM machines (8 GB)
- Repeated failures may destabilize the system
- The failure is not a Swift-side bug, making it hard to diagnose from logs

**Warning signs:**
- Python subprocess exits with non-zero code during model load (not during inference)
- Activity Monitor shows memory pressure going red during first transcription
- Console.app shows IOGPUMemory allocation failures

**Prevention:**
- Set `MLX_METAL_MEMORY_LIMIT` (or use `mx.metal.set_cache_limit()` in Python) before loading the model to leave headroom for the OS.
- Recommend at least 16 GB RAM in user-facing documentation; show a warning on first launch if `sysctl hw.memsize` returns < 16 GB.
- Implement subprocess exit code monitoring in Swift: if the Python process exits unexpectedly, show an actionable error ("Transcription engine ran out of memory") rather than a generic failure.
- Call `mx.clear_cache()` in Python after each transcription to release the MLX activation cache.

**Phase:** v0.19.0 (Parakeet integration). Add the memory check and exit-code monitoring before first use.

---

### I8: MLX First-Inference Warmup Takes 5–15 Seconds (Metal Shader Compilation)

**What goes wrong:**
MLX (and Metal in general) compiles GPU shaders on first use and caches them in `~/Library/Caches/`. On the very first run after installation, or after a macOS update that invalidates the cache, the first call to the model incurs a one-time compilation penalty of 5–15 seconds where the app appears frozen.

For `parakeet-mlx` specifically, the model uses custom Metal kernels. If the Python process is short-lived (one inference per subprocess invocation), this compilation overhead occurs on every first cold start. Community benchmarks note MLX initialization at ~31 seconds for large LLMs; for parakeet's ASR model the overhead is lower but still significant on first use.

**Why it happens:**
Metal shader compilation is deferred to first use (not at app install time). The compiled pipeline objects are stored in the Metal cache, which is version-keyed to the macOS + GPU combination. Any OS update can invalidate the entire cache.

**Consequences:**
- First dictation after install takes 10–20 seconds with no visible progress
- User assumes the app is broken and force-quits before compilation completes
- If the subprocess is started fresh for each recording, the compilation overhead repeats on each launch (no caching benefit across process restarts)

**Warning signs:**
- First recording takes much longer than subsequent recordings
- Python subprocess CPU usage spikes but no audio processing is happening (shader compilation is CPU-bound)
- No loading indicator during the compilation phase

**Prevention:**
- Keep the Python subprocess running persistently (keep-alive mode) rather than spawning it per-recording. This amortizes the compilation cost across the app's lifetime.
- Send a "warmup" inference request (silent, zero-length or dummy audio) at app startup immediately after model load. This forces Metal compilation before the user makes their first real request.
- Show a "Warming up transcription engine..." status during this phase — do not silently block.
- On macOS updates (detect via `os.systemVersion` comparison against a stored value), proactively show "First run may be slower due to shader recompilation" warning.

**Phase:** v0.19.0 (Parakeet integration). Warmup must be built into the startup sequence, not added later.

---

### I9: Zombie Python Subprocesses Accumulate Without Explicit Wait

**What goes wrong:**
When Swift's `Process` object is not explicitly `.waitUntilExit()` or the `terminationHandler` is not set, the child Python process becomes a zombie after it exits. Zombie processes hold a PID and process table entry but no resources — except that they accumulate. In a long-running menu bar app that spawns a Python subprocess per recording, thousands of zombies can accumulate over days of use, eventually exhausting the process table.

Additionally, if `mlx` spawns its own worker processes internally (multiprocessing, thread pools), these grandchild processes can hold file descriptors open even after the direct child exits, preventing `readDataToEndOfFile()` from returning EOF and causing the Swift side to hang indefinitely.

**Why it happens:**
POSIX: a child process remains in the process table as a zombie until the parent calls `wait()` (Swift: `waitUntilExit()`). Foundation's `Process` does this automatically if `terminationHandler` is set, but not if the handler is nil and `waitUntilExit()` is never called.

**Consequences:**
- Process table fills up over multiple days of use
- `readDataToEndOfFile()` hangs if grandchild processes hold the pipe's write end open
- Activity Monitor shows accumulating zombie Python processes

**Warning signs:**
- `ps aux | grep defunct` shows growing count of zombie processes
- `process.terminationStatus` is never read
- `terminationHandler` is nil

**Prevention:**
- Always set `process.terminationHandler` or call `process.waitUntilExit()` from an `async` context.
- For persistent subprocess mode (recommended for warmup): use a keep-alive process with a simple JSON protocol over stdin/stdout rather than spawning per-recording.
- In Python: ensure MLX does not spawn persistent background threads by using `mx.disable_compile()` or appropriate MLX config before inference if multiprocessing is not needed.

**Phase:** v0.19.0 (Parakeet subprocess bridge). Required from day one; not easily retrofitted.

---

### I10: Defaults Library Causes MenuBarExtra Freeze State Loop

**What goes wrong:**
Using `@Default` (from `sindresorhus/Defaults`) as a state source inside a SwiftUI view rendered by `MenuBarExtra` with the `.menu` style causes an infinite re-render loop. The console is spammed with "Publishing changes from within view updates is not allowed" and the menu freezes. This is a confirmed issue (Defaults issue #144).

The root cause is that SwiftUI's `.menu`-style `MenuBarExtra` blocks the main runloop while the menu is open, and the Defaults library's `@ObservationIgnored` + Combine-based observation triggers a state update during a view update, which SwiftUI forbids.

**Why it happens:**
SwiftUI's `.menu` MenuBarExtra style is synchronous and blocks the runloop. Any reactive state update that fires during rendering creates a re-entry that SwiftUI cannot handle correctly.

**Consequences:**
- Menu bar menu freezes and must be force-quit
- All `@Default` bindings in MenuBarExtra views are affected
- The bug is intermittent (depends on timing of Defaults notification delivery)

**Warning signs:**
- "Publishing changes from within view updates is not allowed" in console
- MenuBarExtra menu hangs on open
- Only happens with `.menu` style, not `.window` style

**Prevention:**
- Use `.window` style for the MenuBarExtra, not `.menu` — this avoids the runloop blocking issue entirely.
- If `.menu` style is required, wrap `@Default` accesses in `DispatchQueue.main.async {}` to defer state updates out of the render cycle.
- Alternatively, use `@AppStorage` (SwiftUI's own UserDefaults wrapper) for values displayed in the menu, and `@Default` only in Settings views rendered in separate windows.
- Do not use `@Default` directly in menu body views — use a local `@State` that is populated from Defaults outside the view update.

**Phase:** v0.19.0 (Settings UI). Address in the MenuBarExtra content refactor.

---

### I11: SwiftUI Settings Scene Cannot Be Opened Programmatically (MenuBarExtra Context)

**What goes wrong:**
Apple removed the ability to open the SwiftUI `Settings` scene via `NSApp.sendAction(#selector(showSettingsWindow:), ...)` — the legacy approach no longer works on macOS 14+. The only supported way to open the Settings window is via `SettingsLink` (a SwiftUI view) or via the app's main menu "Settings..." item.

For a `MenuBarExtra`-only app (no menu bar, no `WindowGroup`), there is no built-in "Settings..." menu item. The app must add a `Button("Settings") { openSettings() }` inside the MenuBarExtra content and use the `@Environment(\.openSettings)` action introduced in macOS 14. On macOS 13, this API does not exist.

**Why it happens:**
Apple's SwiftUI team removed the AppKit bridge for settings window presentation in macOS 14 as part of tightening SwiftUI scene management.

**Consequences:**
- "Settings" button in the menu does nothing on macOS 13
- Custom Settings window can't be opened from hotkeys or notifications
- App feels broken on macOS 13 if the only entry to settings is a non-functional button

**Warning signs:**
- `NSApp.sendAction(#selector(showSettingsWindow:), ...)` returns `false`
- Settings window never opens from menu button on macOS 13
- `@Environment(\.openSettings)` causes compile error on macOS 13 target

**Prevention:**
- Use `@Environment(\.openSettings)` with `#available(macOS 14, *)` guard.
- For macOS 13 fallback: use `sindresorhus/Settings` package or `orchetect/SettingsAccess` which wrap the AppKit bridge reliably.
- Since the project targets macOS 14+ (per CLAUDE.md stack), `@Environment(\.openSettings)` is the correct approach — verify the deployment target is enforced in the Xcode project settings.

**Phase:** v0.19.0 (Settings UI). Confirm the macOS 14 deployment target is set before implementing.

---

### I12: KeyboardShortcuts Recorder Shows "First Responder" Warnings in MenuBarExtra Context

**What goes wrong:**
When embedding `KeyboardShortcuts.Recorder` in a Settings window that is opened from a `MenuBarExtra`-based app, Xcode console shows warnings about first responder not being set across windows. The recorder component uses `NSResponder` under the hood. When the Settings window is opened while the MenuBarExtra window is active, NSResponder chain resolution can be confused, causing the recorder to occasionally not receive key events for recording a new shortcut.

**Why it happens:**
`MenuBarExtra` manages its own window hierarchy, which is separate from the main app window hierarchy. When a Settings window is opened, NSApp's key window state may not correctly transfer, leaving the recorder without key event focus.

**Consequences:**
- Shortcut recorder does not respond to key presses intermittently
- User cannot record a new shortcut without clicking away and back
- Console warning spam in development builds

**Warning signs:**
- Console: "... first responder ... across different windows"
- Recorder works in isolation but not when opened from MenuBarExtra
- Issue disappears when tested without a MenuBarExtra scene

**Prevention:**
- Call `NSApp.activate(ignoringOtherApps: true)` and `window.makeKeyAndOrderFront(nil)` when opening the Settings window to explicitly transfer key focus.
- Wrap the `KeyboardShortcuts.Recorder` in an `NSViewRepresentable` that calls `becomeFirstResponder()` in `makeNSView`.
- File: this is a known integration quirk, not a blocking bug. The workaround (explicit `makeKeyAndOrderFront`) is two lines and reliable.

**Phase:** v0.19.0 (Settings UI / Hotkey configuration). Low severity; fix during Settings implementation.

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

### M6: Python Subprocess Audio Format Mismatch (Sample Rate, Bit Depth)

**What goes wrong:**
`AVAudioEngine` captures audio in the hardware's native format, which on most Macs is 32-bit float at 44.1 kHz or 48 kHz. Parakeet-mlx expects audio at 16 kHz, 16-bit int (the NeMo standard). If the Swift side sends raw PCM buffers without converting, parakeet will either error or produce garbage transcription silently.

**Why it happens:**
Format conversion is not automatic when sending audio over a pipe. Developers often send raw buffer bytes without accounting for format differences.

**Prevention:**
- Install an `AVAudioConverter` between the capture tap and the pipe, targeting 16 kHz mono float32 (then convert to int16 before sending, or let Python handle the float32-to-int16 conversion).
- Or write audio to a temporary WAV file with proper headers before passing to Python — simpler but adds a file I/O roundtrip.
- Validate format assumptions in the Python script: assert `sample_rate == 16000` at script startup with a clear error message.

**Phase:** v0.19.0 (Parakeet integration). Format contract must be established before implementing the bridge.

---

## Phase Mapping Summary

| Phase | Pitfalls to Address |
|-------|---------------------|
| Phase 1 (Setup) | C1 — No sandbox. C2 — Accessibility permission check architecture. I3 — Keychain with `AfterFirstUnlock`. I5 — Info.plist microphone key. M2 — `LSUIElement`, `MenuBarExtra` scene. |
| Phase 2 (Core: Audio + Transcription + Injection) | C3 — `AVAudioEngineConfigurationChangeNotification`. C4 — Async model loading. I1 — Two-tier text injection. I2 — Hotkey safety timeout. I4 — Single shared model instance. I5 — Permission request UX. M1 — Compute unit selection. M4 — Recording state feedback. |
| Phase 3 (LLM + History) | I3 — Confirmed Keychain implementation. M3 — SQLite WAL. M5 — Groq error handling. |
| v0.19.0 (Parakeet + Settings) | **C5** — SIP strips DYLD. **C6** — Pipe deadlock (concurrent drain). **C7** — Sign all .so/.dylib. **I6** — venv symlinks broken on other machines. **I7** — MLX memory pressure / kernel panic. **I8** — Metal shader warmup latency. **I9** — Zombie subprocess accumulation. **I10** — Defaults + MenuBarExtra freeze loop. **I11** — Settings scene programmatic open. **I12** — KeyboardShortcuts first responder in MenuBarExtra. **M6** — Audio format mismatch (16 kHz). |

---

## Sources

- Apple CoreML documentation: `MLComputeUnits`, `MLModel.load` async API — HIGH confidence
- Apple coremltools docs: quantization, model size — HIGH confidence (Context7 /apple/coremltools)
- whisper.cpp: Metal backend CMake options — HIGH confidence (Context7 /ggml-org/whisper.cpp)
- Apple Developer Forums thread on Keychain `kSecAttrAccessibleAfterFirstUnlock` background behavior — MEDIUM confidence
- AVAudioEngine `AVAudioEngineConfigurationChangeNotification` — HIGH confidence (Apple documented API)
- Sandbox restrictions on global event monitoring — HIGH confidence (NSEvent documentation)
- Electron Accessibility API limitations — MEDIUM confidence (widely reported in dictation app communities)
- Carbon `RegisterEventHotKey` silent failure on conflict — HIGH confidence (Carbon API documented behavior)
- HotKey library (`soffes/HotKey`) basics — HIGH confidence (Context7 /soffes/hotkey)
- `LSUIElement` Menu Bar app requirements — HIGH confidence (standard macOS app lifecycle docs)
- SIP stripping `DYLD_*` environment variables: https://hynek.me/articles/macos-dyld-env/ — HIGH confidence (documented macOS security behavior; Apple Developer Forums)
- Python subprocess pipe deadlock (64 KB buffer): https://discuss.python.org/t/details-of-process-wait-deadlock/69481 — HIGH confidence (Python docs, POSIX behavior)
- Code-signing all Mach-O binaries in bundle: Apple Developer Forums, PyInstaller docs — HIGH confidence
- Python venv symlinks / portable Python: `python-build-standalone` project — MEDIUM confidence (WebSearch, author knowledge)
- MLX memory pressure / kernel panic: https://github.com/ml-explore/mlx-lm/issues/883 and https://medium.com/@michael.hannecke/... — MEDIUM confidence (GitHub issue, community post)
- MLX warmup latency / Metal cache: https://deepwiki.com/huggingface/speech-to-speech/7.3-mac-os-and-mlx-optimizations — MEDIUM confidence (community benchmark)
- Defaults + MenuBarExtra freeze: https://github.com/sindresorhus/Defaults/issues/144 — HIGH confidence (confirmed library issue)
- `@Environment(\.openSettings)` macOS 14+: Apple Developer Forums, https://github.com/orchetect/SettingsAccess — HIGH confidence
- KeyboardShortcuts first responder in MenuBarExtra context: https://github.com/sindresorhus/KeyboardShortcuts/issues/127 — MEDIUM confidence (GitHub issue)
