# Features Research

**Domain:** macOS push-to-talk dictation app with local transcription and LLM post-processing
**Researched:** 2026-04-15
**Confidence:** MEDIUM-HIGH (based on competitive knowledge of VoiceInk, Superwhisper, Whisper Transcription, macOS Dictation as of Aug 2025)

---

## Table Stakes (Users expect these)

Features whose absence makes the product feel broken or incomplete. Every serious competitor has these.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Global hotkey (hold-to-record) | The entire interaction model. No hotkey = no app. | Low | Push-to-talk is the dominant pattern; toggle-to-record is the alternative but PTT is safer (no runaway recordings) |
| Menu bar presence, no Dock icon | "System tool" expectation. VoiceInk, Superwhisper both do this. Dock icon feels wrong for always-on tools. | Low | LaunchAgent + `LSUIElement = YES` in Info.plist |
| Visual recording feedback | Users need to know if recording is active. Without it, they re-trigger or miss dictations. | Low | Animated menu bar icon is standard. A subtle audio cue (pop in/out) is also expected. |
| Text insertion into active field | The core promise. If it only copies to clipboard you've failed the primary use case. | Med | Requires Accessibility API permission; fragile in some apps (Electron apps especially) |
| Clipboard fallback | Required for apps where Accessibility insertion fails (Terminal, some Electron apps, browser address bars). | Low | Users accept this as a workaround; it must be easy to trigger |
| Transcription accuracy on English | Users compare to macOS Dictation and expect parity or better. Parakeet v3 exceeds this. | N/A (model quality) | Accuracy for non-English is a separate concern — out of scope per PROJECT.md |
| Local/offline processing | Privacy-conscious users (the target demographic) explicitly require this. Mentioning "no cloud" in onboarding is expected. | Med | Bundling Parakeet means model management complexity at build time, not runtime |
| Settings/preferences window | API keys, hotkey config, output mode selection. Without this, power users churn. | Med | Standard SwiftUI Settings scene or custom window |
| Launch at login option | "Set it and forget it" expectation. If it's not in login items, users lose the tool after restart. | Low | SMAppService API (macOS 13+) preferred over legacy Login Items |
| Hotkey configurability | Default hotkey conflicts are common. Users must be able to change it. | Low | Use a hotkey recorder component; common conflicts: Option+Space (Spotlight variants), Fn keys |
| Audio input device selection | Users with external mics expect to choose. Default device works for most but blocking this causes reviews. | Low | Expose AVAudioSession device picker in settings |
| Transcription history | Users want to retrieve something they said 10 minutes ago. This is load-bearing for trust. | Med | Local SQLite or Core Data store; search is expected |

---

## Differentiators (Competitive advantage)

Features that exceed baseline expectations. These are why users pick your app over macOS built-in Dictation or a basic Whisper wrapper.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Multiple named prompt profiles with individual hotkeys | No competitor does per-profile hotkeys well. VoiceInk has profiles but hotkey switching is clunky. This is the headline differentiator for power users. | Med | Each profile = a named system-prompt + hotkey binding. Hotkeys must not conflict with each other or with record hotkey. |
| LLM post-processing with visible prompt editing | Users want to shape output style (email tone, code comments, meeting notes). Seeing and editing the prompt builds trust. | Med | Groq latency (qwen3-32b) is ~1-2s for typical dictation length. Show a processing indicator. |
| Per-profile LLM toggle | Some contexts want raw transcription (quick notes), others want LLM rewriting (emails). Toggling per profile is a UX win. | Low | Boolean flag on each profile, toggled in profile settings |
| Instant output mode switching | Toggle between "insert into field" and "clipboard" without opening settings. A quick-key or menu click. | Low | Massive friction reducer. Users often need clipboard mode for one specific app. |
| Profile-aware output — distinct results per context | E.g., "Email mode" reformats as a proper email; "Code comment mode" wraps in `//`. Power users will discover and love this. | Low (prompt engineering, not code) | Document example prompts in onboarding |
| Privacy-first messaging in UI | "Transcription never leaves your Mac" shown at first launch and in About. This is table stakes for the privacy-conscious niche but differentiates from cloud tools. | Low | Copy/UI only, no implementation work |
| History with copy-to-clipboard per entry | Users regularly retrieve past dictations to re-use or correct. One-click copy per row is the UX. | Low | Add to history view |
| Waveform or level visualizer during recording | Confirms mic is hot and audio is being captured. Reduces "did it hear me?" anxiety. | Low-Med | NSLevelMeterView or a custom SwiftUI waveform; not required but high perceived quality |
| Processing state distinction (recording vs transcribing vs LLM) | Three distinct states exist. Showing "Transcribing..." vs "Thinking..." lets users know why there's latency. | Low | Three icon states or a tooltip |
| Keyboard shortcut to re-run last transcription through a different profile | Re-process without re-speaking. High value for power users. | Med | Keep last raw transcript in memory; re-submit to selected profile |

---

## Anti-Features (Deliberately NOT build in v1)

Features that sound useful but add complexity, maintenance burden, or dilute focus. Defer to v2 or never.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Real-time streaming transcription (words appear as you speak) | Parakeet runs on push-to-talk completion. Streaming requires a different model architecture and much more complex audio/UI pipeline. High complexity for marginal v1 value. | PTT with fast post-recording transcription (Parakeet is fast). Users adapt quickly. |
| Custom vocabulary / word correction dictionary | Solves a real problem (proper nouns, jargon) but requires a separate text normalization layer. Parakeet v3 has decent OOV handling. | Let LLM prompt profiles handle context-specific terminology via system prompt instructions. |
| Multi-language auto-detection | Parakeet v3 supports multiple languages but auto-detection adds a pre-processing step and introduces errors. | Expose a language selector in settings for v2. Pin to English for v1. |
| Speaker identification / diarization | Irrelevant for solo dictation. This is a meeting transcription feature. | Out of scope entirely for this app's purpose. |
| Cloud sync of history or profiles | Breaks the local/privacy story. Adds auth, backend, and GDPR surface. | Profiles and history stay local. Export-to-file for backup if needed. |
| Transcription of audio files / drag-drop | Different use case (podcast editing, meeting notes from recordings). Adds UI complexity and a separate processing pipeline. | Stay focused on real-time dictation. Refer users to MacWhisper for file transcription. |
| In-app LLM provider management (add your own OpenAI, etc.) | Becomes a mini LLM settings panel. Groq + qwen3-32b is the decided stack; generalizing it in v1 is yak shaving. | Hard-code Groq + qwen3-32b. API key is the only config needed. Add provider choice in v2 if needed. |
| iOS companion app | Different platform, different tech stack, different distribution. PROJECT.md explicitly excludes this. | macOS only. |
| Social sharing or export to Notion/Obsidian | These are workflow integrations that require maintaining connectors. High ongoing maintenance. | Clipboard is the universal integration layer. |
| Dictation within a built-in text editor | The app inserts into wherever the user is working. A built-in editor creates an alternate workflow that competes with the core flow. | Use the active text field as the editor. |
| Voice commands ("new line", "period") | Requires a command detection layer on top of transcription. Complex to do well; macOS Dictation does this but it's an entire subsystem. | LLM post-processing can normalize punctuation via prompt. |
| Team features, shared profiles, usage analytics | Explicitly out of scope. Solo tool for a power user. | Never (or a separate product). |

---

## Feature Dependencies

```
Global Hotkey
  └── Recording Pipeline (AVAudioEngine)
        └── Parakeet Transcription
              ├── Raw Text Output
              │     ├── Active Field Insertion (Accessibility API)
              │     └── Clipboard Output
              └── LLM Post-Processing (Groq API)
                    ├── Active Prompt Profile selection
                    │     └── Multiple Profiles with hotkeys
                    └── Processed Text Output
                          ├── Active Field Insertion
                          └── Clipboard Output

Transcription History
  └── Raw Text (always stored)
  └── Processed Text (stored if LLM ran)
  └── Profile used (stored for context)

Settings Window
  └── Groq API Key (required before LLM features work)
  └── Prompt Profile management (create/edit/delete/assign hotkey)
  └── Output Mode selection
  └── Audio device selection
  └── Launch at login toggle

Menu Bar Icon
  └── State: Idle / Recording / Transcribing / LLM Processing / Error
```

**Critical path for v1 MVP:** Global Hotkey → Recording → Parakeet → Active Field Insertion. Everything else adds on top of this spine.

**LLM features are gated on:** Groq API key entered in Settings. App must be fully functional without it (raw transcription only).

**History requires:** Transcription to complete (any mode). Store raw transcript; store LLM result if applicable.

**Multiple profile hotkeys require:** Profile management UI complete, hotkey conflict detection logic.

---

## Onboarding Flow

Typical onboarding for this category follows a "grant permissions then use it" pattern:

1. **First launch screen** — One sentence value prop ("Voice to text, everywhere on your Mac") + Privacy statement ("All transcription happens on your device"). Two buttons: Get Started / Quit.

2. **Microphone permission** — Request `NSSpeechRecognitionUsageDescription` and `NSMicrophoneUsageDescription` via standard macOS prompt. If denied, show recovery instructions. Do not proceed without mic permission.

3. **Accessibility permission** — Request for AXUIElement (text insertion). This requires directing user to System Settings > Privacy > Accessibility. Show a screenshot or animation. This step has the highest drop-off; make the benefit clear ("so I can type into any app for you").

4. **Hotkey setup** — Show the default hotkey. Offer to change it now or later. One-line "hold while speaking, release to insert."

5. **Optional: Groq API key** — Frame as optional: "Want AI to rewrite your text? Enter your Groq API key." Link to groq.com to get a key. Skip button is prominent. Users who skip get raw transcription only; they can add it later in Settings.

6. **Demo dictation** — Focus a visible text field, prompt "Try it now — hold [hotkey] and say something." Showing it work in-app builds immediate trust.

7. **Done screen** — "You're set. I'll live in your menu bar." Mention login item if they said yes to autostart.

**Anti-pattern:** Requiring API key before the app works at all. Many users will not have a Groq key at first launch. Raw transcription must work without it — this is also a product differentiator (fallback privacy story).

---

## Competitive Landscape Summary

| App | Transcription | LLM Post-Processing | Profiles | Privacy |
|-----|---------------|---------------------|----------|---------|
| VoiceInk | Whisper (local) | Yes (OpenAI/custom) | Yes, limited hotkeys | Local option |
| Superwhisper | Whisper (local or cloud) | Yes | Yes, per-profile | Local option |
| macOS Dictation | Apple on-device | No | No | On-device |
| Whisper Transcription (app) | Whisper local | No | No | Local |
| **This app** | Parakeet v3 (local, bundled) | Groq qwen3-32b | Yes, per-profile hotkeys | Fully local |

**Differentiation angle:** Parakeet v3 is faster than Whisper for English (NVIDIA-optimized, near real-time), fully bundled (no model download step), and per-profile hotkeys are genuinely novel vs competitors.

---

## Sources

- Competitive analysis based on VoiceInk (tryvoiceink.com), Superwhisper (superwhisper.com), macOS Dictation (Apple docs), Whisper Transcription (App Store) — feature sets known as of August 2025
- macOS Accessibility API text insertion patterns: Apple Developer Documentation (AXUIElement, kAXFocusedUIElementAttribute)
- Push-to-talk UX patterns: established in gaming (Discord PTT), voice assistants, and dictation tools
- Confidence: MEDIUM for competitive feature parity claims (based on training data, not live scraping); HIGH for macOS technical constraints (Accessibility permission, SMAppService, AVAudioEngine patterns)
