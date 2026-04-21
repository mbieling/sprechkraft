// VoiceScribe/VoiceScribeApp.swift
// Zweck: @main-Einstiegspunkt — SwiftUI App mit AppKit-Delegate-Brücke.
// Das hidden-Fenster dient als Aktivierungsanker für das Einstellungsfenster;
// ohne diesen Trick öffnet openSettings bzw. openWindow auf macOS 26 Tahoe
// mit .accessory-Aktivierungspolicy nicht zuverlässig (RESEARCH.md Pitfall 2).

import SwiftUI
import AppKit

@main
struct VoiceScribeApp: App {
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
        Window("VoiceScribe — Einstellungen", id: "settings") {
            SettingsView(appState: appState)
                .frame(minWidth: 400, minHeight: 300)
        }
        .windowResizability(.contentSize)

        // D-01: Dediziertes History-Fenster (nicht Popover, nicht Settings-Tab)
        // UI-SPEC §4: 640×480 initial, minWidth 480, minHeight 320
        Window("VoiceScribe — Verlauf", id: "history") {
            HistoryView()
                .frame(minWidth: 480, minHeight: 320)
        }
        .defaultSize(width: 640, height: 480)
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

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear {
                // AppState in AppDelegate injizieren — einmalig beim Start.
                appDelegate.appState = appState
                // AudioController nach AppState-Injection initialisieren und verdrahten.
                appDelegate.setupAudioController()
                // Icon nach AppState-Injection aktualisieren.
                appDelegate.updateIcon()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
                Task { @MainActor in
                    // 1. Activation-Policy auf .regular, sonst akzeptiert macOS
                    //    die Fensteraktivierung nicht.
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)

                    // 2. Einstellungsfenster öffnen bzw. vordergrundieren.
                    openWindow(id: "settings")
                    if let win = NSApp.windows.first(where: {
                        $0.identifier?.rawValue == "settings"
                    }) {
                        win.makeKeyAndOrderFront(nil)
                    }

                    // 3. Zurück auf .accessory, damit Dock-Icon verschwindet,
                    //    sobald Fenster geschlossen wird.
                    // TODO: Vor Produktion durch NSWindow.didBecomeKeyNotification-Beobachtung
                    //       ersetzen (One-Shot-Observer), um die Activation-Policy erst dann
                    //       zurückzusetzen, wenn das Fenster tatsächlich Key ist. Der feste
                    //       300ms-Sleep ist ein pragmatischer Workaround für Phase 1.
                    try? await Task.sleep(for: .milliseconds(300))
                    NSApp.setActivationPolicy(.accessory)
                }
            }
            // D-02: History-Fenster öffnen via NotificationCenter-Brücke (analog .openSettings)
            // Pitfall 4: .accessory-Policy-Workaround — exakt identisch zum openSettings-Muster
            .onReceive(NotificationCenter.default.publisher(for: .openHistory)) { _ in
                Task { @MainActor in
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "history")
                    if let win = NSApp.windows.first(where: {
                        $0.identifier?.rawValue == "history"
                    }) {
                        win.makeKeyAndOrderFront(nil)
                    }
                    // Pitfall 4: 300ms Workaround — identisch zu openSettings (STATE.md)
                    try? await Task.sleep(for: .milliseconds(300))
                    NSApp.setActivationPolicy(.accessory)
                }
            }
    }
}
