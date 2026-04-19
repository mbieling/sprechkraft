# Roadmap: VoiceScribe

## Overview

Build a native macOS menu bar dictation app from the ground up, starting with the app shell and global hotkey, then layering in audio capture, local transcription, text injection, LLM post-processing with prompt profiles, searchable history, and full settings UI. Each phase delivers one complete, testable capability before the next begins.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: App Shell** - Menu bar app skeleton with global hotkey and icon state machine *(completed 2026-04-18)*
- [x] **Phase 2: Audio Capture** - Microphone recording with silence detection, audio cues, and level meter *(completed 2026-04-18)*
- [x] **Phase 3: Transcription** - Local WhisperKit/Parakeet integration with async model loading *(completed 2026-04-18)*
- [x] **Phase 4: Text Output** - Text injection into active field and clipboard with mode switching *(completed 2026-04-19)*
- [ ] **Phase 5: LLM + Prompt Profiles** - Groq API integration with named, hotkey-driven prompt profiles
- [ ] **Phase 6: History** - Persistent, full-text-searchable transcription history with GRDB/FTS5

## Phase Details

### Phase 1: App Shell
**Goal**: The app runs as a menu bar-only process, responds to a global hotkey, and drives a 4-state icon — no audio or transcription yet.
**Depends on**: Nothing (first phase)
**Requirements**: SET-06, SET-02, SET-05, FEED-01
**Success Criteria** (what must be TRUE):
  1. App launches with no Dock icon; only a menu bar icon is visible
  2. Pressing the default hotkey (⌥⌘R) cycles the icon through Idle, Recording, Transcribing, and LLM states visually
  3. A menu bar dropdown shows the app name, a quit option, and a placeholder for settings
  4. The app can be configured to launch automatically at login via a toggle in the menu
**Plans**: 4 plans
- [x] 01-01-PLAN.md — Xcode-Projekt, Info.plist (LSUIElement=YES), SPM-Dependencies, Test-Scaffolds (RED)
- [x] 01-02-PLAN.md — RecordingState + AppState @Observable + StatusBarIconView + DesignTokens (GREEN)
- [x] 01-03-PLAN.md — VoiceScribeApp @main + AppDelegate (NSStatusItem, Split-Click, Menü, Hotkey) + SettingsView + KeyboardShortcuts.Name
- [x] 01-04-PLAN.md — Manuelle Human-Verify-Checkpoints (Dock-Icon, 4 Zustände, Menü, LaunchAtLogin-Persistenz)

### Phase 2: Audio Capture
**Goal**: The hotkey starts and stops real microphone recording, silence auto-stops recording, audio cues play, and a live level meter animates in the icon.
**Depends on**: Phase 1
**Requirements**: RECORD-01, RECORD-02, RECORD-03, SET-03, SET-04, FEED-02, FEED-03
**Success Criteria** (what must be TRUE):
  1. Pressing the hotkey starts recording and the icon animates a live waveform/level meter
  2. Releasing or pressing the hotkey again stops recording with a distinct audio cue
  3. Recording stops automatically after the configured silence duration with no user action
  4. The user can select a different microphone input device and recording immediately uses it
  5. The silence threshold (seconds) is configurable and takes effect on the next recording
**Plans**: 3 plans
- [x] 02-01-PLAN.md — Audio-Subsystem Core: AudioController (AVAudioEngine, RMS, Silence-Detection), AudioDeviceManager, Defaults-Keys, AppState-Erweiterung, Info.plist
- [x] 02-02-PLAN.md — UI + Integration: WaveformView, SettingsView (Mic-Picker, Stille-Slider, Permission-Banner), AppDelegate-Wiring, Audio-Cues
- [x] 02-03-PLAN.md — Manuelle Human-Verify-Checkpoints (Aufnahme, Waveform, Auto-Stopp, Settings)
**UI hint**: yes

### Phase 3: Transcription
**Goal**: Recorded audio is transcribed locally; the model downloads once on first launch with a visible progress indicator.
**Depends on**: Phase 2
**Requirements**: RECORD-04, RECORD-05
**Success Criteria** (what must be TRUE):
  1. On first launch, the model download starts automatically and progress is shown in the menu bar icon or a status indicator
  2. After recording stops, the icon switches to the Transcribing state and a correct text transcript is produced
  3. Transcription completes and the result is printed to console (pipeline stub) — no hang or crash on 30-second audio
**Plans**: 5 plans
- [x] 03-01-PLAN.md — SPM-Dependency (WhisperKit v0.18.0) + TranscriptionServiceTests RED-Stubs (Wave 0, Build-Gate)
- [x] 03-02-PLAN.md — AudioController Float-Sample-Akkumulation + onRecordingComplete-Callback + AppState.isModelReady (Wave 1)
- [x] 03-03-PLAN.md — TranscriptionService actor: downloadAndLoad, resampleTo16kHz, transcribe, transcribeWithResampling (Wave 1, TDD)
- [x] 03-04-PLAN.md — AppDelegate Wiring: setupTranscription, onRecordingComplete, isModelReady-Guard, Platzhalter entfernen (Wave 2)
- [x] 03-05-PLAN.md — Manuelle Human-Verify-Checkpoints: Download-Fortschritt, Transkription, 30s-Test (Wave 3)

### Phase 4: Text Output
**Goal**: Transcribed text lands in the active text field at cursor position, or on the clipboard, with a hotkey to switch modes.
**Depends on**: Phase 3
**Requirements**: OUT-01, OUT-02, OUT-03
**Success Criteria** (what must be TRUE):
  1. After dictation, the transcription appears at the cursor position in TextEdit, Notes, and Safari address bar
  2. After dictation in clipboard mode, the transcription is on the clipboard and ready to paste
  3. Pressing the output-mode hotkey switches between field injection and clipboard mode and the change persists across app restarts
  4. When Accessibility permission is not granted, the app falls back to clipboard and does not crash silently
**Plans**: 4 plans
- [x] 04-01-PLAN.md — OutputMode-Enum + Defaults.Keys.outputMode + toggleOutputMode-Hotkey-Name + AppState.axPermissionDenied + Info.plist (Wave 1, parallel)
- [x] 04-02-PLAN.md — TextOutputService (@MainActor, AX-Injektion, 2040-Guard, Clipboard) + Unit-Tests via Protocol/Mock (Wave 1, parallel)
- [x] 04-03-PLAN.md — AppDelegate-Wiring (print()-Stub ersetzen, AX-Check, Hotkey, Menü-Häkchen) + SettingsView (AX-Banner, OutputMode-Section) (Wave 2)
- [x] 04-04-PLAN.md — Manuelle Human-Verify-Checkpoints: AX-Injektion Ziel-Apps, Clipboard-Modus, Hotkey-Toggle, Persistenz, Permission-Fallback (Wave 3)

### Phase 5: LLM + Prompt Profiles
**Goal**: The user can create named prompt profiles with individual hotkeys and LLM toggles; holding a profile hotkey during dictation routes the transcript through Groq before output.
**Depends on**: Phase 4
**Requirements**: PROF-01, PROF-02, PROF-03, PROF-04, PROF-05, SET-01
**Success Criteria** (what must be TRUE):
  1. The user can create, rename, edit the prompt text, and delete a profile in the settings UI
  2. Each profile has its own hotkey; holding that hotkey during recording activates the profile for that dictation
  3. A profile with LLM disabled produces raw transcription output; one with LLM enabled routes through Groq qwen3-32b
  4. One profile can be marked as default and is used automatically when no profile hotkey is held
  5. The Groq API key is entered once in settings, stored in macOS Keychain, and survives app restarts
**Plans**: 7 plans
- [x] 05-01-PLAN.md — PromptProfileTests RED-Stubs: 5 failing tests (PROF-01, PROF-03, PROF-04) (Wave 0, parallel)
- [x] 05-02-PLAN.md — GroqServiceTests RED-Stubs: 4 failing tests (PROF-05, SET-01, D-09, T-5-03) (Wave 0, parallel)
- [x] 05-03-PLAN.md — PromptProfile struct + Defaults.Keys.profiles + KeyboardShortcuts.Name.profile(_:) (Wave 1, parallel)
- [x] 05-04-PLAN.md — GroqService actor: URLSession POST, encodeIfPresent, HTTPS, 30s Timeout (Wave 1, parallel)
- [ ] 05-05-PLAN.md — AppState-Extensions (activeProfileID, groqKeyMissing) + AppDelegate-Wiring: setupProfileHotkeys, LLM-Routing, Keychain-Init (Wave 2)
- [ ] 05-06-PLAN.md — ProfileEditorSheet.swift (neu) + SettingsView Section "Prompt-Profile" + Groq-Banner (Wave 3)
- [ ] 05-07-PLAN.md — Manuelle Human-Verify-Checkpoints: Profil-CRUD, simultaner Hotkey, Groq-Call, Icon-State, Keychain-Persistenz (Wave 4)
**UI hint**: yes

### Phase 6: History
**Goal**: Every transcription is stored locally and the user can search, browse, and copy past results from a history panel.
**Depends on**: Phase 5
**Requirements**: HIST-01, HIST-02, HIST-03, HIST-04
**Success Criteria** (what must be TRUE):
  1. After every dictation, a new entry appears in the history panel with timestamp, original transcript, and LLM-processed text (if applicable)
  2. Typing a search query in the history panel returns matching entries via full-text search within under 200ms for a 1000-entry dataset
  3. Clicking a history entry copies its text to the clipboard with a visible confirmation
  4. History persists across app restarts and is stored entirely on-device with no cloud dependency
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. App Shell | 4/4 | Complete | 2026-04-18 |
| 2. Audio Capture | 3/3 | Complete | 2026-04-18 |
| 3. Transcription | 5/5 | Complete | 2026-04-18 |
| 4. Text Output | 4/4 | Complete | 2026-04-19 |
| 5. LLM + Prompt Profiles | 4/7 | In progress | - |
| 6. History | 0/TBD | Not started | - |
