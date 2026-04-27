// SPRECHKRAFT/SPRECHKRAFTApp.swift
// Zweck: @main-Einstiegspunkt — SwiftUI App mit AppKit-Delegate-Brücke.
// Das hidden-Fenster dient als Aktivierungsanker für das Einstellungsfenster;
// ohne diesen Trick öffnet openSettings bzw. openWindow auf macOS 26 Tahoe
// mit .accessory-Aktivierungspolicy nicht zuverlässig (RESEARCH.md Pitfall 2).

@preconcurrency import SwiftUI
import AppKit
import Defaults

@main
struct SPRECHKRAFTApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        // Verstecktes Aktivierungsfenster — MUSS vor 'settings' stehen!
        // 1×1 pt, transparent; dient ausschließlich als SwiftUI-Aktivierungsanker.
        Window("Hidden", id: "hidden") {
            HiddenActivationView(appState: appState, appDelegate: appDelegate)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)

        // Echtes Einstellungsfenster (UI-SPEC Einstellungsfenster Contract).
        Window("SPRECHKRAFT — Einstellungen", id: "settings") {
            SettingsView(appState: appState)
                .frame(minWidth: 400, minHeight: 300)
        }
        .windowResizability(.contentSize)

        // D-01: Dediziertes History-Fenster (nicht Popover, nicht Settings-Tab)
        // UI-SPEC §4: 640×480 initial, minWidth 480, minHeight 320
        Window("SPRECHKRAFT — Verlauf", id: "history") {
            HistoryView()
                .frame(minWidth: 480, minHeight: 320)
        }
        .defaultSize(width: 640, height: 480)
        .windowResizability(.contentSize)

        // ONB-02: Onboarding-Fenster (Welcome Window)
        Window("Willkommen bei SPRECHKRAFT", id: "onboarding") {
            OnboardingView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

/// Transparent 1×1-View: initialisiert die AppDelegate-zu-AppState-Bindung und
/// empfängt NotificationCenter-Events, um das Einstellungsfenster in den
/// Vordergrund zu bringen — inkl. temporärem Wechsel der Activation-Policy.
private struct HiddenActivationView: View {
    let appState: AppState
    let appDelegate: AppDelegate

    @Environment(\.openWindow) private var openWindow
    @Default(.hasCompletedOnboarding) private var hasCompletedOnboarding

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear {
                // AppState in AppDelegate injizieren — einmalig beim Start.
                appDelegate.appState = appState
                // GroqService in AppDelegate injizieren.
                appDelegate.groqService = GroqService() // Hier wird die konkrete Implementierung injiziert
                // AudioController nach AppState-Injection initialisieren und verdrahten.
                appDelegate.setupAudioController()
                // Icon nach AppState-Injection aktualisieren.
                appDelegate.updateIcon()
                
                // ONB-01: First Launch Check
                if !hasCompletedOnboarding {
                    openOnboarding()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
                Task { @MainActor in
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                    // UX-01: Warten bis das Fenster Key wird, dann Policy zurücksetzen.
                    // notifications(named:) auf @MainActor löst das token-Capture-Problem (Swift 6).
                    for await notification in NotificationCenter.default.notifications(named: NSWindow.didBecomeKeyNotification) {
                        guard let window = notification.object as? NSWindow,
                              window.identifier?.rawValue == "settings" else { continue }
                        NSApp.setActivationPolicy(.accessory)
                        break
                    }
                }
            }
            // D-02: History-Fenster öffnen via NotificationCenter-Brücke (analog .openSettings)
            .onReceive(NotificationCenter.default.publisher(for: .openHistory)) { _ in
                Task { @MainActor in
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "history")
                    for await notification in NotificationCenter.default.notifications(named: NSWindow.didBecomeKeyNotification) {
                        guard let window = notification.object as? NSWindow,
                              window.identifier?.rawValue == "history" else { continue }
                        NSApp.setActivationPolicy(.accessory)
                        break
                    }
                }
            }
    }

    private func openOnboarding() {
        Task { @MainActor in
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "onboarding")
            for await notification in NotificationCenter.default.notifications(named: NSWindow.didBecomeKeyNotification) {
                guard let window = notification.object as? NSWindow,
                      window.identifier?.rawValue == "onboarding" else { continue }
                NSApp.setActivationPolicy(.accessory)
                break
            }
        }
    }
}
