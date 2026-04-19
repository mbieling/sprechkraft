// VoiceScribe/AppDelegate.swift
// Zweck: AppKit-Schicht für Menu-Bar-Icon, globalen Hotkey und AudioController-Wiring.
// Implementiert SET-02 (Hotkey ⌥⌘R), SET-05 (Login-Toggle),
// SET-06 (kein Dock-Icon via .accessory), FEED-01 (Icon-Zustände via AppState),
// FEED-02 (Audio-Cues: Tink/Pop), RECORD-01 (echtes Start/Stopp via AudioController),
// RECORD-04/RECORD-05 (Transkription via TranscriptionService, Download-Kickoff).
// Quellen: RESEARCH.md Pattern 1, 3, 4, 5; PATTERNS.md AppDelegate; 02-02-PLAN.md Task 3; 03-04-PLAN.md.

import AppKit
import SwiftUI
import KeyboardShortcuts
import LaunchAtLogin
import ApplicationServices  // AXIsProcessTrusted()
import Defaults             // Defaults[.outputMode]

/// NotificationCenter.Name für die Brücke AppDelegate → VoiceScribeApp.
extension Notification.Name {
    static let openSettings = Notification.Name("com.voicescribe.openSettings")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var appState: AppState?

    /// AudioController — initialisiert nach AppState-Injection via setupAudioController().
    private var audioController: AudioController?

    /// TranscriptionService — Download und Transkription. Actor-isoliert.
    private let transcriptionService = TranscriptionService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // SET-06: .accessory VOR allem anderen — verhindert Dock-Icon auch
        // wenn LSUIElement aus irgendeinem Grund nicht greift.
        NSApp.setActivationPolicy(.accessory)

        // NSStatusItem-Button mit Split-Click konfigurieren.
        // statusItem ist lazy var — wird hier beim ersten Zugriff initialisiert.
        guard let button = statusItem.button else { return }
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.action = #selector(handleClick(_:))
        button.target = self

        updateIcon()
        setupHotkey()
        setupTranscription()
        setupOutputModeHotkey()
    }

    // MARK: - AudioController Setup

    /// Initialisiert AudioController und verdrahtet Callbacks.
    /// Wird von VoiceScribeApp.HiddenActivationView.onAppear aufgerufen,
    /// nachdem appState injiziert wurde.
    func setupAudioController() {
        guard let appState else { return }
        audioController = AudioController(appState: appState)

        // D-07: Auto-Stopp durch Stille spielt denselben Stopp-Ton wie manueller Stopp
        audioController?.onAutoStop = { [weak self] in
            self?.stopRecordingWithCue()
        }

        // FEED-03: Level-Update → Icon neu zeichnen (Observation-B Pattern)
        audioController?.onLevelUpdate = { [weak self] in
            self?.updateIcon()
        }

        // D-10: AX-Permission jetzt sicher setzen (appState ist hier garantiert nicht nil)
        // AXIsProcessTrusted() ist ein einfacher Bool-Return, kein blocking call (T-04-08)
        let axGranted = AXIsProcessTrusted()
        appState.axPermissionDenied = !axGranted

        // Phase 3: Transkription nach Aufnahme-Ende (RECORD-04, D-05)
        // Callback laeuft auf @MainActor (Task { @MainActor } in AudioController.stopRecording())
        audioController?.onRecordingComplete = { [weak self] samples, sampleRate in
            guard let self else { return }
            Task {
                // Resampling (D-06) und Transkription (D-07) im actor — kein Main-Thread-Block
                let text = await self.transcriptionService.transcribeWithResampling(samples, sampleRate: sampleRate)
                await MainActor.run {
                    if let text {
                        // OUT-01/OUT-02: Text ausgeben via TextOutputService (ersetzt Phase-3-Pipeline-Stub)
                        // axPermissionDenied von AppState — gesetzt in setupAudioController() (D-10)
                        let mode = Defaults[.outputMode]
                        let axPermitted = !(self.appState?.axPermissionDenied ?? true)
                        TextOutputService.shared.output(text, mode: mode, axPermitted: axPermitted)
                    }
                    self.appState?.resetToIdle()  // D-08: .transcribing → .idle
                    self.updateIcon()
                }
            }
        }
    }

    // MARK: - Recording mit Audio-Cues (RECORD-01, FEED-02)

    /// Startet Aufnahme: State .idle → .recording, AudioController.startRecording(), Start-Ton.
    /// Guard verhindert doppelten Start (T-02-06).
    private func startRecordingWithCue() {
        guard appState?.recordingState == .idle else { return }
        // D-11: Aufnahme waehrend Download blockiert — kein Audio-Cue, kein State-Wechsel
        guard appState?.isModelReady == true else { return }
        appState?.toggleRecording()  // .idle → .recording
        do {
            try audioController?.startRecording()
            // D-05/D-06: Start-Ton — "Tink": hell, kurz (~150ms), klar unterscheidbar von Stopp
            NSSound(named: NSSound.Name("Tink"))?.play()
        } catch {
            // Bei Fehler Zustand zuruecksetzen — kein Ton
            appState?.resetToIdle()
        }
        updateIcon()
    }

    /// Stoppt Aufnahme: AudioController.stopRecording(), State .recording → .transcribing → .idle, Stopp-Ton.
    /// Guard verhindert Stopp im falschen Zustand (T-02-08).
    private func stopRecordingWithCue() {
        guard appState?.recordingState == .recording else { return }
        audioController?.stopRecording()
        appState?.toggleRecording()  // .recording → .transcribing (audioLevel wird in toggleRecording() resettet)
        // D-06/D-07: Stopp-Ton — "Pop": tiefer als Start-Ton, kurz (~150ms)
        // Gilt gleichermassen fuer manuellen Stopp und Auto-Stopp durch Stille (D-07)
        NSSound(named: NSSound.Name("Pop"))?.play()
        updateIcon()
        // resetToIdle() kommt via onRecordingComplete-Callback (nicht mehr hier)
    }

    // MARK: - Split-Click Handler

    @objc private func handleClick(_ sender: NSButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            // Linksklick togglet Aufnahme mit Audio-Cues
            if appState?.recordingState == .idle {
                startRecordingWithCue()
            } else if appState?.recordingState == .recording {
                stopRecordingWithCue()
            }
        }
    }

    // MARK: - NSMenu (temporäres Pattern)

    private func showMenu() {
        let menu = NSMenu()

        // Zeile 1: App-Name, disabled (UI-SPEC D-05)
        let titleItem = NSMenuItem(title: "VoiceScribe", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(.separator())

        // Einstellungen…
        let settingsItem = NSMenuItem(
            title: "Einstellungen…",
            action: #selector(openSettingsMenu),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Beim Login starten — Toggle mit State (SET-05)
        let loginItem = NSMenuItem(
            title: "Beim Login starten",
            action: #selector(toggleLoginItem),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        // OUT-03/D-08: Ausgabemodus-Häkchen — zeigt aktiven Modus und erlaubt Umschalten
        let currentMode = Defaults[.outputMode]

        let fieldItem = NSMenuItem(
            title: "Textfeld-Injektion",
            action: #selector(setOutputModeField),
            keyEquivalent: ""
        )
        fieldItem.target = self
        fieldItem.state = currentMode == .field ? .on : .off
        menu.addItem(fieldItem)

        let clipItem = NSMenuItem(
            title: "Clipboard",
            action: #selector(setOutputModeClipboard),
            keyEquivalent: ""
        )
        clipItem.target = self
        clipItem.state = currentMode == .clipboard ? .on : .off
        menu.addItem(clipItem)

        menu.addItem(.separator())

        // Beenden
        menu.addItem(NSMenuItem(
            title: "Beenden",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        // KRITISCH (RESEARCH.md Pitfall 1): menu temporär setzen, sofort nach
        // performClick() wieder auf nil — sonst übernimmt AppKit das
        // gesamte Click-Handling und Linksklick würde auch das Menü öffnen.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - Menu Actions

    @objc private func openSettingsMenu() {
        // Brücke zur SwiftUI-Scene in VoiceScribeApp.swift.
        // Siehe RESEARCH.md Pitfall 2: openSettings Environment-Action ist
        // auf macOS 26 Tahoe mit .accessory-Policy unzuverlässig.
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    @objc private func toggleLoginItem() {
        LaunchAtLogin.isEnabled.toggle()
    }

    @objc private func setOutputModeField() {
        Defaults[.outputMode] = .field
    }

    @objc private func setOutputModeClipboard() {
        Defaults[.outputMode] = .clipboard
    }

    // MARK: - Icon-Update

    /// Aktualisiert das NSHostingView im StatusItem-Button mit dem aktuellen AppState.
    /// Wird manuell nach jedem State-/Level-Change aufgerufen (Observation-B Pattern).
    /// audioLevel wird an StatusBarIconView durchgereicht fuer WaveformView (FEED-03).
    func updateIcon() {
        guard let button = statusItem.button else { return }

        let state = appState?.recordingState ?? .idle
        let level = appState?.audioLevel ?? 0.0
        let hostingView = NSHostingView(rootView: StatusBarIconView(state: state, audioLevel: level))
        hostingView.frame = NSRect(x: 0, y: 0, width: 26, height: 26)

        // Alte Subviews entfernen, neue einsetzen.
        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(hostingView)
        button.frame = hostingView.frame

        // UI-SPEC Accessibility Contract: Label pro Zustand.
        button.setAccessibilityLabel(state.accessibilityLabel)
    }

    // MARK: - Transcription Setup (RECORD-05)

    /// Startet Modell-Download beim App-Start (D-09).
    /// Fortschritt via NSStatusItem-Title "↓ XX%" (D-10).
    /// isModelReady wird nach Abschluss auf true gesetzt (D-11).
    private func setupTranscription() {
        Task {
            await transcriptionService.downloadAndLoad { [weak self] fraction in
                // @MainActor (Closure deklariert in downloadAndLoad als @MainActor)
                let pct = Int(fraction * 100)
                self?.statusItem.button?.title = pct < 100 ? "↓ \(pct)%" : ""
            }
            // Download abgeschlossen (oder fehlgeschlagen — isModelReady bleibt dann false, D-13)
            statusItem.button?.title = ""
            appState?.isModelReady = await transcriptionService.isModelReady
            updateIcon()
        }
    }

    // MARK: - Global Hotkey (SET-02)

    private func setupHotkey() {
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.appState?.recordingState == .idle {
                    self.startRecordingWithCue()
                } else if self.appState?.recordingState == .recording {
                    self.stopRecordingWithCue()
                }
            }
        }
    }

    // MARK: - Output-Mode Hotkey (OUT-03, D-09)

    /// Registriert den toggleOutputMode-Hotkey (⇧⌘V, konfigurierbar).
    /// Wechselt Defaults[.outputMode] zwischen .field und .clipboard (D-07).
    private func setupOutputModeHotkey() {
        KeyboardShortcuts.onKeyUp(for: .toggleOutputMode) { [weak self] in
            Task { @MainActor [weak self] in
                guard self != nil else { return }
                // D-07: Toggle zwischen .field und .clipboard
                Defaults[.outputMode] = Defaults[.outputMode] == .field ? .clipboard : .field
                // Menü spiegelt neuen Zustand beim nächsten Öffnen (showMenu() baut Menü neu)
            }
        }
    }
}
