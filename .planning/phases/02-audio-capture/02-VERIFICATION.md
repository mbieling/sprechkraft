---
phase: 02-audio-capture
verified: 2026-04-17T12:00:00Z
status: passed
score: 5/5
overrides_applied: 0
human_verification:
  - test: "Hotkey druecken → Tink-Ton hörbar, Icon wechselt zu rot mit Waveform-Linie"
    expected: "Sofortiger Tonwiedergabe + visuelles Icon-Feedback"
    why_human: "NSSound-Wiedergabe und SwiftUI-Canvas-Animation koennen nicht ohne laufende App geprueft werden"
    resolution: "Vom Nutzer in 02-03-SUMMARY.md bestaetigt (Test 1 + Test 2 — approved)"
  - test: "Hotkey erneut druecken → Pop-Ton hörbar, Icon wechselt auf idle"
    expected: "Unterschiedlicher (tieferer) Ton fuer Stopp vs. Start"
    why_human: "NSSound-Unterscheidung Tink vs. Pop muss akustisch verifiziert werden"
    resolution: "Vom Nutzer in 02-03-SUMMARY.md bestaetigt (Test 3 — approved)"
  - test: "Stille-Auto-Stopp nach ~1,5 s ohne Benutzeraktion"
    expected: "Aufnahme stoppt automatisch, Stopp-Ton ertönt"
    why_human: "Timing-basiertes Verhalten mit echtem Mikrofon noetig"
    resolution: "Vom Nutzer in 02-03-SUMMARY.md bestaetigt (Test 4 — approved)"
  - test: "Waveform-Linie im Icon animiert bei Sprache sichtbar"
    expected: "Canvas-Wellenform oszilliert bei aktivem Audio-Eingang"
    why_human: "Canvas-Rendering mit echtem Audio-Level-Feed noetig"
    resolution: "Vom Nutzer in 02-03-SUMMARY.md bestaetigt (Test 2 — approved)"
  - test: "Mikrofon-Picker in Settings zeigt verfuegbare Geraete"
    expected: "Mindestens 'System-Standard' + eingebautes Mikrofon sichtbar"
    why_human: "Geraete-Enumeration haengt von Hardware-Konfiguration ab"
    resolution: "Vom Nutzer in 02-03-SUMMARY.md bestaetigt (Test 5 — approved)"
---

# Phase 2: Audio Capture — Verifikationsbericht

**Phase-Ziel:** Hotkey startet/stoppt echte Mikrofon-Aufnahme via AVAudioEngine. Stille erkennt sich automatisch. Audio-Cues bei Start/Stopp. Menu-Bar-Icon zeigt Live-Pegel als Waveform-Linie. Mikrofon waehlbar in Settings.
**Verifiziert:** 2026-04-17
**Status:** PASSED
**Re-Verifikation:** Nein — Erstverifikation

## Ziel-Erreichung

### Beobachtbare Wahrheiten (Roadmap Success Criteria)

| # | Wahrheit | Status | Nachweis |
|---|----------|--------|----------|
| 1 | Hotkey startet Aufnahme; Icon animiert Live-Waveform/Level-Meter | VERIFIED | `KeyboardShortcuts.onKeyUp` → `startRecordingWithCue()` → `audioController?.startRecording()`. `onLevelUpdate`-Callback → `updateIcon()` → `StatusBarIconView(state:, audioLevel:)`. `WaveformView` bei `state == .recording` sichtbar. Nutzer-Bestaetigung: Tests 1+2 approved. |
| 2 | Loslassen oder erneuter Hotkey-Druck stoppt Aufnahme mit eigenem Audio-Cue | VERIFIED | `stopRecordingWithCue()`: `NSSound("Pop")?.play()` fuer Stopp; `NSSound("Tink")?.play()` fuer Start (D-06: unterschiedliche Toene). Nutzer-Bestaetigung: Test 3 approved. |
| 3 | Aufnahme stoppt automatisch nach konfigurierter Stille-Dauer ohne Nutzeraktion | VERIFIED | `updateSilenceDetection()` akkumuliert Stille; triggert `Task { @MainActor in onAutoStop?() }` nach `Defaults[.silenceDuration]` Sekunden. `onAutoStop` verdrahtet mit `stopRecordingWithCue()` in `setupAudioController()`. Nutzer-Bestaetigung: Test 4 approved. |
| 4 | Nutzer kann anderes Mikrofon-Eingabegeraet waehlen; Aufnahme nutzt es sofort | VERIFIED | `SettingsView`: `Picker("Eingabegeraet", selection: $selectedMicUID)` mit `@Default(.selectedMicUID)`. `AudioDeviceManager.availableMicrophones()` in `onAppear`. `AudioController.startRecording()` liest `Defaults[.selectedMicUID]` und ruft `AudioDeviceManager.setInputDevice()` auf. Nutzer-Bestaetigung: Test 5 approved. |
| 5 | Stille-Schwellwert (Sekunden) ist konfigurierbar und wirkt bei naechster Aufnahme | VERIFIED | `Slider(value: $silenceDuration, in: 0.5...5.0, step: 0.5)` mit `@Default(.silenceDuration)`. `AudioController` liest `Defaults[.silenceDuration]` bei jeder Buffer-Iteration dynamisch. Nutzer-Bestaetigung: Test 6 approved. |

**Score: 5/5 Wahrheiten verifiziert**

### Erforderliche Artefakte

| Artefakt | Erwartet | Status | Details |
|----------|----------|--------|---------|
| `SPRECHKRAFT/Audio/AudioController.swift` | AVAudioEngine-Wrapper mit installTap, RMS, Silence-Detection | VERIFIED | `final class AudioController: @unchecked Sendable`; `startRecording() throws`; `stopRecording()`; `calculateRMS(buffer:)`; `updateSilenceDetection(rms:bufferDuration:)`; Permission-Check via `AVAudioApplication.shared.recordPermission` |
| `SPRECHKRAFT/Audio/AudioDeviceManager.swift` | Geraete-Enumeration + Core-Audio-Bridge | VERIFIED | `enum AudioDeviceManager`; `availableMicrophones() -> [AVCaptureDevice]`; `uniqueIDToAudioObjectID(_:)`; `setInputDevice(uid:engine:)` mit `kAudioHardwarePropertyTranslateUIDToDevice` |
| `SPRECHKRAFT/Extensions/Defaults+Keys.swift` | Type-safe Defaults-Keys fuer Phase 2 | VERIFIED | `silenceDuration = Key<Double>("silenceDuration", default: 1.5)`; `selectedMicUID = Key<String?>("selectedMicUID", default: nil)` |
| `SPRECHKRAFT/AppState.swift` | `audioLevel` + `micPermissionDenied` Properties | VERIFIED | `var audioLevel: CGFloat = 0.0`; `var micPermissionDenied: Bool = false`; `toggleRecording()` (echter Cycle, kein Demo-Cycle); `resetToIdle()` |
| `SPRECHKRAFT/StatusBarIconView.swift` | WaveformView + audioLevel-Parameter | VERIFIED | `struct WaveformView: View` mit Canvas-Rendering; `let audioLevel: CGFloat`; `VStack(spacing: 0)`; `if state == .recording { WaveformView(level: audioLevel) }`; `.frame(width: 18, height: 4)`; `.accessibilityHidden(true)` |
| `SPRECHKRAFT/SettingsView.swift` | Mikrofon-Picker, Stille-Slider, Permission-Banner | VERIFIED | `Section("Mikrofon")` + `Section("Stille-Erkennung")`; `Picker("Eingabegeraet")`; `Slider(in: 0.5...5.0)`; Permission-Banner mit `Color(.systemRed)`; `AudioDeviceManager.availableMicrophones()` in `onAppear` |
| `SPRECHKRAFT/AppDelegate.swift` | AudioController-Initialisierung, echtes Toggle, Audio-Cues | VERIFIED | `private var audioController: AudioController?`; `setupAudioController()`; `startRecordingWithCue()` + `stopRecordingWithCue()`; `NSSound("Tink")`/`NSSound("Pop")`; `StatusBarIconView(state: state, audioLevel: level)` |
| `SPRECHKRAFTTests/AudioControllerTests.swift` | Unit-Tests fuer RMS + Silence-Logic | VERIFIED | `@Suite("AudioController (RECORD-01, RECORD-02)")`; Tests fuer stille/laute Buffer, Silence-Trigger, Silence-Reset |
| `SPRECHKRAFTTests/DefaultsKeysTests.swift` | Unit-Tests fuer Defaults-Keys | VERIFIED | `@Suite("Defaults Keys (SET-03, SET-04)")`; Tests fuer silenceDuration (1.5) und selectedMicUID (nil) |
| `SPRECHKRAFTTests/WaveformViewTests.swift` | Unit-Tests fuer WaveformView-Sichtbarkeit | VERIFIED | `@Suite("WaveformView (FEED-03)")`; 6 Tests fuer Level-Varianten und alle RecordingState-Werte |
| `SPRECHKRAFT/Info.plist` | NSMicrophoneUsageDescription | VERIFIED | Zeile 25: `<key>NSMicrophoneUsageDescription</key>` vorhanden |

### Key-Link-Verifikation

| Von | Nach | Ueber | Status | Details |
|-----|------|-------|--------|---------|
| `AudioController.swift` | `AppState.swift` | `Task { @MainActor in }` im installTap-Callback | VERIFIED | Zeilen 105-108: `Task { @MainActor [weak self] in self?.appState?.audioLevel = clampedLevel; self?.onLevelUpdate?() }` |
| `AudioController.swift` | `AudioDeviceManager.swift` | `setInputDevice` ruft intern `uniqueIDToAudioObjectID` auf | VERIFIED | AudioController Zeile 87: `try AudioDeviceManager.setInputDevice(uid: uid, engine: engine)`; AudioDeviceManager Zeile 69: `guard let deviceID = uniqueIDToAudioObjectID(uid)` |
| `AudioController.swift` | `Defaults+Keys.swift` | `Defaults[.silenceDuration]` in Silence-Detection | VERIFIED | Zeile 157: `if silenceAccumulator >= Defaults[.silenceDuration]`; Zeile 86: `if let uid = Defaults[.selectedMicUID]` |
| `AppDelegate.swift` | `AudioController.swift` | `audioController.startRecording()` / `stopRecording()` | VERIFIED | Zeilen 70, 84: `try audioController?.startRecording()`; `audioController?.stopRecording()` |
| `AppDelegate.swift` | `StatusBarIconView.swift` | `updateIcon()` mit audioLevel-Parameter | VERIFIED | Zeile 182: `NSHostingView(rootView: StatusBarIconView(state: state, audioLevel: level))` |
| `SettingsView.swift` | `Defaults+Keys.swift` | `@Default(.silenceDuration)` und `@Default(.selectedMicUID)` | VERIFIED | Zeilen 17-18: `@Default(.silenceDuration) private var silenceDuration`; `@Default(.selectedMicUID) private var selectedMicUID` |
| `SettingsView.swift` | `AudioDeviceManager.swift` | `AudioDeviceManager.availableMicrophones()` fuer Picker-Daten | VERIFIED | Zeile 118: `availableMics = AudioDeviceManager.availableMicrophones()` |
| `SPRECHKRAFTApp.swift` | `AppDelegate.swift` | `appDelegate.setupAudioController()` nach AppState-Injection | VERIFIED | Zeile 49: `appDelegate.setupAudioController()` in `HiddenActivationView.onAppear` |

### Datenfluss-Trace (Level 4)

| Artefakt | Datenvariable | Quelle | Liefert echte Daten | Status |
|----------|---------------|--------|---------------------|--------|
| `StatusBarIconView` | `audioLevel: CGFloat` | `AppState.audioLevel` ← `AudioController` installTap-Callback via `Task { @MainActor }` | Ja — AVAudioEngine-Buffer-RMS-Berechnung | FLOWING |
| `SettingsView` | `availableMics: [AVCaptureDevice]` | `AudioDeviceManager.availableMicrophones()` via `AVCaptureDevice.DiscoverySession` | Ja — echte Systemgeraete-Enumeration | FLOWING |
| `SettingsView` | `silenceDuration: Double` | `@Default(.silenceDuration)` via Defaults-SPM-Library | Ja — UserDefaults-gestuetzt, persistiert | FLOWING |
| `SettingsView` | `selectedMicUID: String?` | `@Default(.selectedMicUID)` via Defaults-SPM-Library | Ja — UserDefaults-gestuetzt, persistiert | FLOWING |

### Verhaltens-Spot-Checks (Step 7b)

Uebersprungen: Tests erfordern laufende macOS-App mit Mikrofon-Hardware und TCC-Berechtigung. Manuelle Verifikation wurde stattdessen in Plan 03 durchgefuehrt (02-03-SUMMARY.md, alle 7 Tests approved).

### Requirements-Abdeckung

| Requirement | Quell-Plan | Beschreibung | Status | Nachweis |
|-------------|-----------|--------------|--------|----------|
| RECORD-01 | 02-01, 02-02, 02-03 | Aufnahme per Hotkey starten/stoppen | SATISFIED | `setupHotkey()` → `startRecordingWithCue()`/`stopRecordingWithCue()` → `audioController` |
| RECORD-02 | 02-01, 02-02, 02-03 | Auto-Stopp nach konfigurierbarer Stille-Dauer | SATISFIED | `updateSilenceDetection()` + `onAutoStop`-Callback + `Defaults[.silenceDuration]` |
| RECORD-03 | 02-01, 02-02, 02-03 | Mikrofon-Eingabegeraet in Einstellungen waehlbar | SATISFIED | `SettingsView` Picker + `AudioDeviceManager` + `Defaults[.selectedMicUID]` |
| SET-03 | 02-01, 02-02, 02-03 | Stille-Erkennungs-Schwellwert konfigurierbar | SATISFIED | `Slider(in: 0.5...5.0)` + `Key<Double>("silenceDuration", default: 1.5)` |
| SET-04 | 02-01, 02-02, 02-03 | Mikrofon-Eingabegeraet in Einstellungen waehlbar | SATISFIED | `Key<String?>("selectedMicUID", default: nil)` + Picker-Binding |
| FEED-02 | 02-02, 02-03 | Kurze Toene beim Starten und Stoppen | SATISFIED | `NSSound("Tink")?.play()` (Start) + `NSSound("Pop")?.play()` (Stopp); Nutzer-Bestaetigung |
| FEED-03 | 02-02, 02-03 | Waveform/Level-Meter im Icon waehrend Aufnahme | SATISFIED | `WaveformView` Canvas + `onLevelUpdate`-Callback-Kette; Nutzer-Bestaetigung |

Alle 7 Requirements vollstaendig abgedeckt. Keine verwaisten Requirements gefunden.

### Anti-Pattern-Scan

| Datei | Zeile | Pattern | Schwere | Auswirkung |
|-------|-------|---------|---------|------------|
| `SPRECHKRAFTApp.swift` | 70 | `TODO: Vor Produktion durch NSWindow.didBecomeKeyNotification ersetzen` — Sleep-Workaround fuer Settings-Fenster-Activation | Info | Betrifft nur das Oeffnen des Settings-Fensters, nicht Phase-2-Kernfunktionalitaet; kein Audio-Blocker |

Keine Blocker oder Warnung-Stufe Anti-Patterns in Phase-2-Kernfunktionen gefunden. Der TODO ist aus Phase 1 vorgeerbt und explizit als kuenftiger Verbesserungskandidat markiert.

### Manuell verifizierte Verhaltensweisen

Alle 5 hardware-abhaengigen Verhaltensweisen wurden vom Nutzer in Plan 03 (02-03-SUMMARY.md) am 2026-04-17 bestaetigt:

1. **Hotkey + Start-Ton + Icon-Wechsel** — approved (Test 1)
2. **Waveform-Animation bei Sprache** — approved (Test 2)
3. **Hotkey + Stopp-Ton + Icon-Idle** — approved (Test 3)
4. **Stille-Auto-Stopp nach ~1,5 s** — approved (Test 4)
5. **Settings: Mikrofon-Picker mit Geraeten** — approved (Test 5)
6. **Settings: Stille-Slider (0,5–5,0 s)** — approved (Test 6)
7. **Phase-1-Regression: Menu + kein Dock-Icon** — approved (Test 7)

### Zusammenfassung

Phase 2 erreicht ihr Ziel vollstaendig. Alle 5 Roadmap Success Criteria sind verifiziert:

- Das Audio-Backend (AudioController + AudioDeviceManager) ist substantiell implementiert und korrekt verdrahtet.
- Die UI (StatusBarIconView mit WaveformView, SettingsView) ist vollstaendig und mit den Backends verbunden.
- Der Datenfluss von AVAudioEngine-Buffer-RMS ueber AppState bis zur Canvas-Waveform ist durchgehend.
- Alle 7 Anforderungen (RECORD-01, RECORD-02, RECORD-03, SET-03, SET-04, FEED-02, FEED-03) sind abgedeckt.
- Alle hardware-abhaengigen Verhaltensweisen wurden manuell bestaetigt.
- 25/25 Unit-Tests laufen gemaess SUMMARY gruen (RMS, Silence-Detection, Defaults-Keys, WaveformView, AppState).

Einziger nicht-blockierender Befund: TODO in SPRECHKRAFTApp.swift (Sleep-Workaround fuer Settings-Fenster) — betrifft Phase 1, nicht Phase 2.

---

_Verifiziert: 2026-04-17_
_Verifier: Claude (gsd-verifier)_
