---
phase: 05-llm-prompt-profiles
reviewed: 2026-04-19T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - VoiceScribe/Models/PromptProfile.swift
  - VoiceScribe/Services/GroqService.swift
  - VoiceScribe/AppState.swift
  - VoiceScribe/AppDelegate.swift
  - VoiceScribe/Extensions/Defaults+Keys.swift
  - VoiceScribe/Extensions/KeyboardShortcuts+Names.swift
  - VoiceScribe/ProfileEditorSheet.swift
  - VoiceScribe/SettingsView.swift
  - VoiceScribeTests/PromptProfileTests.swift
  - VoiceScribeTests/GroqServiceTests.swift
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 05: Code Review Report

**Reviewed:** 2026-04-19
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Phase 5 introduces PromptProfile model, GroqService actor, profile CRUD in SettingsView/ProfileEditorSheet, and LLM routing in AppDelegate. The implementation is architecturally sound: API key is never cached in AppState or logs, HTTPS is enforced, actor isolation is respected, and the silent-fallback contract (D-10) is consistently applied.

Four warnings were found: a missing HTTP response status check before JSON decoding (which will silently produce garbled output on API errors), a new-profile CRUD bug where the user can open and save a profile with an empty name without validation at the sheet level, a double Keychain read that could theoretically produce a TOCTOU inconsistency, and a Groq API response that may contain thinking-block text prefixed to the actual content. Three info items cover minor quality issues.

No critical security issues were found.

---

## Warnings

### WR-01: HTTP error responses decoded as JSON, silently producing raw-text fallback

**File:** `VoiceScribe/Services/GroqService.swift:100-101`

**Issue:** The service calls `URLSession.shared.data(for:)` and immediately passes `data` to `JSONDecoder().decode(ChatResponse.self, from:)` without first checking the HTTP status code. When Groq returns a 4xx or 5xx error (invalid key, rate-limit, quota exceeded), the response body is an error JSON like `{"error":{"message":"..."}}`, not a `ChatResponse`. The decoder throws, the `catch` block in AppDelegate silently falls back to `rawText` — which is the intended behavior per D-10. However, the caller has no way to distinguish a transient 429/503 from an invalid key (401), so the `groqKeyMissing` banner can remain visible after the key is entered and the first request fails for a different reason, misleading the user. More practically: if Groq ever returns a 200 with a body that partially matches `ChatResponse` (malformed streaming leak, etc.) the decoder will silently return incomplete content.

**Fix:**
```swift
let (data, response) = try await URLSession.shared.data(for: urlRequest)
if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
    // Throw a typed error so callers can distinguish auth failures from transient ones
    throw GroqError.httpError(httpResponse.statusCode)
}
let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
```
Add `case httpError(Int)` to `GroqError`. The AppDelegate catch block can then distinguish `GroqError.httpError(401)` to set `appState?.groqKeyMissing = true` dynamically.

---

### WR-02: New profile with empty name can be saved via sheet keyboard shortcut

**File:** `VoiceScribe/SettingsView.swift:237-245`, `VoiceScribe/ProfileEditorSheet.swift:101-108`

**Issue:** In `SettingsView`, the "Profil hinzufügen" button creates a `PromptProfile` with `name: ""` and immediately sets `editingProfile = newProfile`. The "Profil sichern" button in `ProfileEditorSheet` is correctly `.disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)`. However, if the user opens the sheet and immediately presses Return (or submits via the default button keyboard binding on macOS), macOS may activate the first non-disabled button — in practice the Form's default action can bypass the disabled check. Additionally, a profile with an empty name would produce an empty `Text("")` row in the ForEach list and an empty `NSMenuItem` title in the menu, causing invisible UI entries.

The more direct risk: `onSave` in the sheet closure appends the new profile to `Defaults[.profiles]` regardless of name content, because the only guard is the SwiftUI `.disabled()` modifier. There is no server-side/model-level validation.

**Fix:** Add a name guard in the `onSave` closure in `SettingsView`:
```swift
onSave: { updatedProfile in
    guard !updatedProfile.name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
    var current = Defaults[.profiles]
    // ... rest of save logic
}
```
This is a second line of defense and makes the invariant explicit at the data layer, not just the UI layer.

---

### WR-03: Double Keychain read creates a subtle TOCTOU window

**File:** `VoiceScribe/AppDelegate.swift:58`

**Issue:** In `applicationDidFinishLaunching`, the Keychain is read twice in one expression:
```swift
appState?.groqKeyMissing = (keychain["groqApiKey"] == nil || keychain["groqApiKey"]?.isEmpty == true)
```
The two `keychain["groqApiKey"]` subscript calls each invoke a Keychain lookup. Between the two calls the value is in principle unchanged (app just launched, no concurrent writes possible at this point), so this is not a security vulnerability. However, it is semantically imprecise: if the key exists but is empty, the first check `== nil` is false, and the second check `?.isEmpty` performs a second Keychain read. The correct pattern is one read, then check.

**Fix:**
```swift
let storedKey = keychain["groqApiKey"]
appState?.groqKeyMissing = storedKey == nil || storedKey?.isEmpty == true
```

---

### WR-04: Thinking-mode responses may include `<think>...</think>` block in output text

**File:** `VoiceScribe/Services/GroqService.swift:103-106`

**Issue:** When `isThinkingEnabled == true` and `reasoning_effort` is omitted from the request, qwen3-32b's thinking mode produces a response where `choices[0].message.content` may contain a `<think>…</think>` prefix block followed by the actual answer. The current code returns `content` verbatim. If this block is injected into a text field, the user sees the raw chain-of-thought XML. The RESEARCH.md mentions the `/no_think` prefix as "unstable" and opts for `reasoning_effort` instead, but does not address stripping the response-side `<think>` block.

**Fix:** Strip the thinking block from the response before returning:
```swift
var result = content
// qwen3 thinking mode wraps CoT in <think>…</think>; strip before output
if let thinkEnd = result.range(of: "</think>") {
    result = String(result[thinkEnd.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
}
return result
```
This is safe to apply unconditionally (non-thinking responses never contain `</think>`).

---

## Info

### IN-01: `PromptProfile.defaultProfile` generates a new UUID on every call

**File:** `VoiceScribe/Models/PromptProfile.swift:22-31`

**Issue:** `defaultProfile` is a computed `static var`, not a `static let`. Each call to `PromptProfile.defaultProfile` produces a `PromptProfile` with a freshly generated `UUID()`. This is intentional for use as the `Defaults.Keys.profiles` default value (each fresh install gets a unique ID), but it means that calling `defaultProfile` twice — e.g., in tests or in two places during setup — returns structurally identical profiles with different IDs. A test comparing `defaultProfile.id == defaultProfile.id` would fail. The current test suite does not do this, but it is a non-obvious footgun.

**Suggestion:** Document the intentional behavior with a comment, or make it a `static func makeDefault() -> PromptProfile` to signal that each call is a constructor, not a singleton accessor.

---

### IN-02: `updateIcon()` allocates a new `NSHostingView` on every audio level update

**File:** `VoiceScribe/AppDelegate.swift:333-348`

**Issue:** `updateIcon()` creates a new `NSHostingView` every time it is called, including on every `onLevelUpdate` callback during recording. During active recording this can be called at 10–60 Hz depending on the tap buffer size. The old subview is removed and the new one is added, but the NSHostingView allocation and SwiftUI graph creation occurs on every call. This is an existing pattern (not introduced in Phase 5), but Phase 5 adds the `llmProcessing` state which also calls `updateIcon()` after state transitions.

**Suggestion:** Cache the `NSHostingView` and update it via a `@State`/`@Binding` rather than replacing it on each call. This is a quality improvement; it does not affect correctness.

---

### IN-03: `GroqServiceTests.testEndpointIsHTTPS` does not actually test the service's endpoint

**File:** `VoiceScribeTests/GroqServiceTests.swift:66-73`

**Issue:** The test constructs a local `URL(string: "https://...")` and checks its scheme. It does not access the `private let endpoint` property of `GroqService`. The test would pass even if the production endpoint were changed to `http://`. The `@testable import` does not help here because `endpoint` is `private`. The comment acknowledges this limitation.

**Suggestion:** Change `endpoint` visibility to `internal` (the Swift default) so tests can access it directly:
```swift
// In GroqService.swift
let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
```
Then the test can assert `GroqService.shared.endpoint.scheme == "https"`.

---

_Reviewed: 2026-04-19_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
