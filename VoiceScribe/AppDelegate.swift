// VoiceScribe/AppDelegate.swift
// Zweck: AppKit-Schicht für Menu-Bar-Icon und globalen Hotkey.
// Implementiert SET-02 (Hotkey ⌥⌘R), SET-05 (Login-Toggle),
// SET-06 (kein Dock-Icon via .accessory) und FEED-01 (Icon-Zustände via AppState).
// Quellen: RESEARCH.md Pattern 1, 3, 4 + Code Examples; PATTERNS.md AppDelegate.

import AppKit
import SwiftUI
import KeyboardShortcuts
import LaunchAtLogin

/// NotificationCenter.Name für die Brücke AppDelegate → VoiceScribeApp.
extension Notification.Name {
    static let openSettings = Notification.Name("com.voicescribe.openSettings")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var appState: AppState?

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
    }

    // MARK: - Split-Click Handler

    @objc private func handleClick(_ sender: NSButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            appState?.toggleRecording()
            // Variante B: manueller updateIcon()-Aufruf nach toggleRecording().
            // Variante A (withObservationTracking) wurde getestet und funktioniert
            // in dieser Konfiguration zuverlässig, jedoch wird Variante B als
            // explizitere und robustere Lösung für Swift 6 gewählt, da sie keine
            // Abhängigkeit vom re-registration-Mechanismus von withObservationTracking hat.
            updateIcon()
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

    // MARK: - Icon-Update

    /// Aktualisiert das NSHostingView im StatusItem-Button mit dem aktuellen AppState.
    /// Wird manuell nach jedem toggleRecording()-Aufruf aufgerufen (Variante B).
    /// Begründung: Expliziter Aufruf ist robuster als withObservationTracking-Re-Registrierung
    /// in Swift 6 strict concurrency Kontexten.
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

    // MARK: - Global Hotkey (SET-02)

    private func setupHotkey() {
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            Task { @MainActor [weak self] in
                self?.appState?.toggleRecording()
                // Variante B: manueller updateIcon()-Aufruf nach Hotkey-Toggle.
                self?.updateIcon()
            }
        }
    }
}
