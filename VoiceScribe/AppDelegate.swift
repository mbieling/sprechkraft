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
import KeychainAccess
import LaunchAtLogin
import ApplicationServices  // AXIsProcessTrusted()
import Defaults             // Defaults[.outputMode]

/// NotificationCenter.Name für die Brücke AppDelegate → VoiceScribeApp.
extension Notification.Name {
    static let openSettings = Notification.Name("com.voicescribe.openSettings")
    /// Wird von SettingsView nach Profil-Aenderungen gepostet — AppDelegate registriert Hotkeys neu.
    static let refreshProfileHotkeys = Notification.Name("com.voicescribe.refreshProfileHotkeys")
    /// D-02: Brücke für Menüpunkt "Verlauf…" → History-Window-Scene in VoiceScribeApp.
    static let openHistory = Notification.Name("com.voicescribe.openHistory")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var appState: AppState?

    /// AudioController — initialisiert nach AppState-Injection via setupAudioController().
    private var audioController: AudioController?

    /// GroqService — injiziert von VoiceScribeApp für bessere Testbarkeit.
    var groqService: GroqServiceProtocol!

    /// TranscriptionService — Download und Transkription. Actor-isoliert.
    private let transcriptionService = TranscriptionService()

    /// Keychain-Instanz fuer Groq API-Key (SET-01, T-5-01).
    /// Service-Name = Bundle-Identifier fuer Keychain-Isolation zwischen Apps.
    private let keychain = Keychain(service: Bundle.main.bundleIdentifier ?? "com.voicescribe")

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
        setupProfileHotkeys()
        // SET-01: Groq API-Key Verfuegbarkeit pruefen — Banner in SettingsView (Phase 5)
        // T-5-02: Key wird nicht gecacht — groqKeyMissing ist nur ein Bool-Flag
        appState?.groqKeyMissing = (keychain["groqApiKey"] == nil || keychain["groqApiKey"]?.isEmpty == true)
        // Phase 5 Plan 06: Observer fuer Profil-Aenderungen aus SettingsView (Pitfall 2)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRefreshProfileHotkeys),
            name: .refreshProfileHotkeys,
            object: nil
        )
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

        // Phase 5: LLM-Routing nach Transkription (PROF-03, PROF-05)
        // D-10: Stille Fallback — bei Fehler oder fehlendem Key wird rawText ausgegeben.
        audioController?.onRecordingComplete = { [weak self] samples, sampleRate in
            guard let self else { return }
            Task {
                let text = await self.transcriptionService.transcribeWithResampling(samples, sampleRate: sampleRate)
                await MainActor.run {
                    guard let text else {
                        self.appState?.resetToIdle()
                        self.updateIcon()
                        return
                    }

                    // D-02: Profil-ID lesen und sofort zuruecksetzen (naechste Aufnahme sauber)
                    let profileID = self.appState?.activeProfileID
                    self.appState?.activeProfileID = nil

                    // Aktives Profil ermitteln: per Hotkey (PROF-02) → Default (PROF-04) → erstes
                    let profiles = Defaults[.profiles]
                    let activeProfile = profiles.first { $0.id == profileID }
                        ?? profiles.first { $0.isDefault }
                        ?? profiles.first   // Absoluter Fallback: erstes Profil

                    // Ausgabe-Parameter
                    let mode = Defaults[.outputMode]
                    let axPermitted = !(self.appState?.axPermissionDenied ?? true)

                    if let activeProfile, activeProfile.isLLMEnabled {
                        // PROF-05: LLM-Pfad — Icon zu .llmProcessing (FEED-01, lila pulsierend 1.2s)
                        self.appState?.recordingState = .llmProcessing
                        self.updateIcon()  // Observation-B: sofort nach State-Mutation

                        Task { [weak self] in
                            guard let self else { return }
                            // T-5-02: Key unmittelbar vor Request aus Keychain lesen — nie gecacht
                            let apiKey = self.keychain["groqApiKey"]
                            let outputText: String

                            if let key = apiKey, !key.isEmpty {
                                do {
                                    outputText = try await self.groqService.process(
                                        transcript: text,
                                        profile: activeProfile,
                                        apiKey: key
                                    )
                                } catch {
                                    // Improved Error Feedback (UX-02): Zeige Fehler-Icon für 2 Sekunden
                                    await MainActor.run {
                                        self.appState?.recordingState = .error
                                        self.updateIcon()
                                    }
                                    // Kurze Pause, damit der User den Fehlerzustand wahrnimmt
                                    try? await Task.sleep(for: .seconds(2))
                                    
                                    // D-10: Stille Fallback bei Groq-Fehler (Timeout, API-Fehler, etc.)
                                    outputText = text
                                }
                            } else {
                                // D-10: Kein Key → Fallback zu Raw-Text (Banner zeigt SET-01-Warnung)
                                outputText = text
                            }

                            // D-15: Entry vor MainActor.run bauen — wird danach async inserted (WR-01)
                            let historyEntry = HistoryEntry(
                                id: nil,
                                createdAt: Date(),
                                originalText: text,
                                llmText: outputText != text ? outputText : nil,
                                profileName: activeProfile.name,
                                isLLMProcessed: true
                            )
                            await MainActor.run {
                                TextOutputService.shared.output(outputText, mode: mode, axPermitted: axPermitted)
                                self.appState?.resetToIdle()
                                self.updateIcon()  // Observation-B: .llmProcessing → .idle
                            }
                            // Insert nach TextOutput — async, blockiert Main Thread nicht (WR-01)
                            do {
                                try await HistoryStore.shared.insert(historyEntry)
                            } catch {
                                print("[HistoryStore] Insert failed: \(error)")
                            }
                        }
                    } else {
                        // Direkt-Pfad: LLM deaktiviert → Raw-Transkript ausgeben
                        TextOutputService.shared.output(text, mode: mode, axPermitted: axPermitted)
                        self.appState?.resetToIdle()
                        self.updateIcon()
                        // D-15: GRDB-Insert — Direkt-Pfad (kein LLM), async (WR-01)
                        let historyEntry = HistoryEntry(
                            id: nil,
                            createdAt: Date(),
                            originalText: text,
                            llmText: nil,
                            profileName: activeProfile?.name,
                            isLLMProcessed: false
                        )
                        Task {
                            do {
                                try await HistoryStore.shared.insert(historyEntry)
                            } catch {
                                print("[HistoryStore] Insert failed: \(error)")
                            }
                        }
                    }
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

        // D-02: Verlauf-Menüpunkt — vor "Einstellungen…" (analog zu openSettingsMenu)
        let historyItem = NSMenuItem(
            title: "Verlauf\u{2026}",  // U+2026 ELLIPSIS
            action: #selector(openHistoryMenu),
            keyEquivalent: ""
        )
        historyItem.target = self
        menu.addItem(historyItem)

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

        // PROF-04/D-03: Profil-Auswahl im Menü mit Häkchen (analog OutputMode-Häkchen)
        let profiles = Defaults[.profiles]
        let activeProfileID = appState?.activeProfileID

        for profile in profiles {
            let item = NSMenuItem(
                title: profile.name,
                action: #selector(setActiveProfileFromMenu(_:)),
                keyEquivalent: ""
            )
            item.representedObject = profile.id as AnyObject
            // Häkchen: aktives Profil (via Hotkey) ODER Default-Profil wenn keins aktiv
            let isActive = (activeProfileID != nil)
                ? profile.id == activeProfileID
                : profile.isDefault
            item.state = isActive ? .on : .off
            item.target = self
            menu.addItem(item)
        }

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

        // UX-03: Hilfe-Menü mit Dokumentation und Support
        let helpItem = NSMenuItem(title: "Hilfe", action: nil, keyEquivalent: "")
        let helpSubmenu = NSMenu()
        
        let docItem = NSMenuItem(title: "Dokumentation", action: #selector(openDocumentation), keyEquivalent: "")
        docItem.target = self
        helpSubmenu.addItem(docItem)
        
        let supportItem = NSMenuItem(title: "Support & Feedback", action: #selector(openSupport), keyEquivalent: "")
        supportItem.target = self
        helpSubmenu.addItem(supportItem)
        
        helpItem.submenu = helpSubmenu
        menu.addItem(helpItem)

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

    @objc private func openHistoryMenu() {
        NotificationCenter.default.post(name: .openHistory, object: nil)
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

    @objc private func setActiveProfileFromMenu(_ sender: NSMenuItem) {
        guard let profileID = sender.representedObject as? UUID else { return }
        appState?.activeProfileID = profileID
    }

    @objc private func openDocumentation() {
        if let url = URL(string: "https://github.com/mbieling/VoiceScribe") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openSupport() {
        if let url = URL(string: "https://github.com/mbieling/VoiceScribe/issues") {
            NSWorkspace.shared.open(url)
        }
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

    /// Startet Modell-Download beim App-Start.
    /// D-07: Cache-Prüfung — wenn Modell bereits vorhanden, kein Spinner anzeigen.
    /// D-06: Kein Fortschrittsbalken — Spinner (.modelLoading) + Titel-Text als UX.
    /// isModelReady wird nach Abschluss gesetzt; isModelError bei Fehler (D-08).
    private func setupTranscription() {
        // D-07: Cache-Pfad prüfen bevor Lade-UI angezeigt wird.
        // FluidAudio cached intern in ~/Library/Application Support/FluidAudio/Models.
        // Wenn Modell-Datei existiert: kein Spinner — downloadAndLoad returned schnell.
        let cacheURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/FluidAudio/Models")
        let modelCached = FileManager.default.fileExists(atPath: cacheURL.path)

        if !modelCached {
            // D-06: Spinner-State + Titel-Text — kein Fortschrittsbalken
            appState?.recordingState = .modelLoading
            updateIcon()  // Observation-B: sofort nach State-Mutation
        }

        Task {
            // D-03: .warmingUp setzen bevor downloadAndLoad — Warmup läuft im Backend-Call
            // (progressHandler mit fraction=0.0 → 1.0 signalisiert den vollen Lifecycle)
            await transcriptionService.downloadAndLoad { [weak self] fraction in
                // @MainActor Closure — safe für UI-Updates
                // fraction: 0.0 = Beginn (kein echter Progress von FluidAudio — Pitfall 3)
                //           1.0 = fertig (nach loadModels + Warmup-Inferenz)
                if fraction < 1.0 {
                    // D-06: Größen-Hinweis im Titel während Download läuft
                    self?.statusItem.button?.title = "Parakeet-Modell wird geladen (~1.2 GB)…"
                    self?.appState?.recordingState = .warmingUp  // D-03: Backend führt Warmup durch
                    self?.updateIcon()
                } else {
                    self?.statusItem.button?.title = ""
                }
            }

            // Download abgeschlossen (oder fehlgeschlagen — isModelReady bleibt dann false)
            statusItem.button?.title = ""
            let ready = await transcriptionService.isModelReady
            appState?.isModelReady = ready

            if ready {
                appState?.recordingState = .idle
            } else {
                // D-08: isModelError setzen — Phase 8 zeigt Retry-Button
                appState?.isModelError = true
                // D-09: .modelError-State für Icon-Feedback
                appState?.recordingState = .modelError
            }
            updateIcon()  // Observation-B: finaler Icon-Update nach State-Settle
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
        // REVIEW WR-02: [weak self] entfernt — self wird im Callback nirgends verwendet.
        // Defaults ist thread-safe, kein Retain-Cycle durch KeyboardShortcuts-Callback.
        // Konsistent mit setupHotkey()-Muster nur wenn self tatsaechlich benoetigt wird.
        KeyboardShortcuts.onKeyUp(for: .toggleOutputMode) {
            Task { @MainActor in
                // D-07: Toggle zwischen .field und .clipboard
                Defaults[.outputMode] = Defaults[.outputMode] == .field ? .clipboard : .field
                // Menü spiegelt neuen Zustand beim nächsten Öffnen (showMenu() baut Menü neu)
            }
        }
    }

    // MARK: - Profil-Hotkey Refresh (Phase 5 Plan 06)

    /// Wird via NotificationCenter von SettingsView nach Profil-Aenderungen aufgerufen.
    /// Loest setupProfileHotkeys() erneut aus — registriert Hotkeys nach CRUD neu.
    @objc private func handleRefreshProfileHotkeys() {
        setupProfileHotkeys()
    }

    // MARK: - Profile Hotkeys (PROF-02)

    /// Registriert globale onKeyDown-Handler fuer alle gespeicherten Profile.
    /// Pitfall 1 (RESEARCH.md): onKeyDown statt onKeyUp — Profil muss WAEHREND der Aufnahme aktiv sein.
    /// Pitfall 2 (RESEARCH.md): Vor Neuregistrierung alle alten Handler entfernen.
    /// Wird nach Profil-Aenderungen (ProfileEditorSheet) erneut aufgerufen.
    func setupProfileHotkeys() {
        // Alle bisherigen Profil-Hotkey-Handler zuruecksetzen (Pitfall 2: keine doppelten Handler)
        let currentProfiles = Defaults[.profiles]
        for profile in currentProfiles {
            KeyboardShortcuts.removeHandler(for: .profile(profile.id))
        }

        // Neue Handler registrieren
        for profile in currentProfiles {
            let name = KeyboardShortcuts.Name.profile(profile.id)
            KeyboardShortcuts.onKeyDown(for: name) { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self,
                          self.appState?.recordingState == .recording,
                          self.appState?.activeProfileID == nil   // D-02: Erster gewinnt
                    else { return }
                    self.appState?.activeProfileID = profile.id
                }
            }
        }
    }
}
