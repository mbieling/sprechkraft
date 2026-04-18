# Phase 1: App Shell — Pattern Map

**Erstellt:** 2026-04-16
**Dateien analysiert:** 8 (neu zu erstellende Dateien)
**Analogs gefunden:** 0 / 8 — Greenfield-Projekt, kein bestehender Swift-Code

---

## Kontext: Greenfield-Projekt

Es existiert noch kein Swift-Quellcode im Repository. Alle Muster stammen daher aus:
1. Offizieller Apple-Dokumentation (NSStatusItem, NSApplicationDelegateAdaptor, SwiftUI Scenes)
2. Verifizierten Drittquellen aus RESEARCH.md (sindresorhus-Libraries, etablierte Patterns)
3. Konkreten Code-Excerpts aus RESEARCH.md (direkt übertragbar)

Der Planner soll die unten dokumentierten Muster direkt in Implementierungsschritte übersetzen.

---

## Datei-Klassifikation

| Neu zu erstellende Datei | Rolle | Data Flow | Analog | Match-Qualität |
|--------------------------|-------|-----------|--------|----------------|
| `VoiceScribe/VoiceScribeApp.swift` | app-entry | event-driven | — | kein Analog (Greenfield) |
| `VoiceScribe/AppDelegate.swift` | controller | event-driven | — | kein Analog (Greenfield) |
| `VoiceScribe/AppState.swift` | store | event-driven | — | kein Analog (Greenfield) |
| `VoiceScribe/StatusBarIconView.swift` | component | event-driven | — | kein Analog (Greenfield) |
| `VoiceScribe/SettingsView.swift` | component | request-response | — | kein Analog (Greenfield) |
| `VoiceScribe/Extensions/KeyboardShortcuts+Names.swift` | utility | — | — | kein Analog (Greenfield) |
| `VoiceScribe/Constants/DesignTokens.swift` | config | — | — | kein Analog (Greenfield) |
| `VoiceScribe/Info.plist` | config | — | — | kein Analog (Greenfield) |

---

## Pattern-Zuweisungen

### `VoiceScribe/VoiceScribeApp.swift` (app-entry, event-driven)

**Analog:** kein Codebase-Analog — Greenfield
**Quelle:** Apple Developer Documentation (`NSApplicationDelegateAdaptor`) + RESEARCH.md Pattern 1

**Imports-Pattern:**
```swift
import SwiftUI
import AppKit
```

**Kern-Pattern — @main + NSApplicationDelegateAdaptor + Window-Scenes:**
```swift
// Quelle: RESEARCH.md Pattern 1 (verifiziert via Apple Docs + steipete.me)
@main
struct VoiceScribeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        // Verstecktes Aktivierungsfenster — MUSS vor Settings stehen!
        // Zweck: Aktivierungsanker für Settings-Öffnung (openSettings schlägt auf macOS 26 fehl)
        Window("Hidden", id: "hidden") {
            Color.clear.frame(width: 1, height: 1)
                .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
                    Task { @MainActor in
                        NSApp.setActivationPolicy(.regular)
                        NSApp.activate(ignoringOtherApps: true)
                        if let win = NSApp.windows.first(where: { $0.title.contains("Einstellungen") }) {
                            win.makeKeyAndOrderFront(nil)
                        }
                        try? await Task.sleep(for: .milliseconds(300))
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)

        // Einstellungsfenster
        Window("VoiceScribe — Einstellungen", id: "settings") {
            SettingsView()
                .frame(minWidth: 400, minHeight: 300)
        }
        .windowResizability(.contentSize)
    }
}
```

**Kritische Entscheidung:** Kein `MenuBarExtra` verwenden — AppKit `NSStatusItem` im AppDelegate ist zwingend für Split-Click (D-06). Kein `Settings`-Scene verwenden — erfordert `SettingsLink` und funktioniert auf macOS 26 Tahoe mit `.accessory`-Policy nicht zuverlässig.

---

### `VoiceScribe/AppDelegate.swift` (controller, event-driven)

**Analog:** kein Codebase-Analog — Greenfield
**Quelle:** RESEARCH.md Pattern 1 + Code Examples (verifiziert via medium.com/@clyapp + polpiella.dev)

**Imports-Pattern:**
```swift
import AppKit
import SwiftUI
import KeyboardShortcuts
import LaunchAtLogin
```

**Kern-Pattern — NSStatusItem + Split-Click-Handler:**
```swift
// Quelle: RESEARCH.md Code Examples (Split-Click)
// WICHTIG: @MainActor — Swift 6 strict concurrency erfordert explizite Annotation
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // KRITISCH: .accessory VOR allem anderen setzen — verhindert Dock-Icon (SET-06)
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }

        // Split-Click: Button muss BEIDE Events empfangen
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.action = #selector(handleClick(_:))
        button.target = self

        updateIcon()
        setupHotkey()
    }

    @objc private func handleClick(_ sender: NSButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            appState?.toggleRecording()
            updateIcon()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        let titleItem = NSMenuItem(title: "VoiceScribe", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Einstellungen…",
                               action: #selector(openSettings),
                               keyEquivalent: ","))
        let loginItem = NSMenuItem(title: "Beim Login starten",
                                  action: #selector(toggleLoginItem),
                                  keyEquivalent: "")
        loginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Beenden",
                               action: #selector(NSApplication.terminate(_:)),
                               keyEquivalent: "q"))

        // KRITISCH: menu temporär setzen, sofort danach nil — sonst übernimmt
        // AppKit das gesamte Click-Handling und Linksklick löst auch das Menü aus
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    @objc private func toggleLoginItem() {
        LaunchAtLogin.isEnabled.toggle()
    }
}
```

**Icon-Aktualisierungs-Pattern (NSHostingView):**
```swift
// Quelle: RESEARCH.md Pattern 3 (NSHostingView für SwiftUI-Animationen)
private func updateIcon() {
    let state = appState?.recordingState ?? .idle
    let hostingView = NSHostingView(
        rootView: StatusBarIconView(state: state)
    )
    hostingView.frame = NSRect(x: 0, y: 0, width: 26, height: 26)
    statusItem.button?.subviews.forEach { $0.removeFromSuperview() }
    statusItem.button?.addSubview(hostingView)
    statusItem.button?.frame = hostingView.frame

    // Accessibility-Label pro Zustand (UI-SPEC Accessibility Contract)
    statusItem.button?.setAccessibilityLabel(state.accessibilityLabel)
}
```

**Hotkey-Setup-Pattern:**
```swift
private func setupHotkey() {
    KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
        Task { @MainActor in
            self?.appState?.toggleRecording()
            self?.updateIcon()
        }
    }
}
```

**Anti-Pattern-Warnung:** `statusItem.menu` darf NICHT dauerhaft gesetzt bleiben. Pitfall 1 aus RESEARCH.md: sobald `.menu` gesetzt ist, übernimmt AppKit das Click-Handling vollständig — Linksklick ruft kein `.action` mehr auf.

---

### `VoiceScribe/AppState.swift` (store, event-driven)

**Analog:** kein Codebase-Analog — Greenfield
**Quelle:** RESEARCH.md Pattern 2 (Swift 6 Observation framework)

**Imports-Pattern:**
```swift
import Observation
import SwiftUI
import KeyboardShortcuts
```

**Kern-Pattern — @Observable Source of Truth + RecordingState-Enum:**
```swift
// Quelle: RESEARCH.md Pattern 2 + UI-SPEC State Machine Contract
enum RecordingState: Equatable {
    case idle          // Icon: #8E8E93 (grau), statisch
    case recording     // Icon: systemRed,    pulsierend 0.8s
    case transcribing  // Icon: systemBlue,   statisch
    case llmProcessing // Icon: systemPurple, pulsierend 1.2s

    // UI-SPEC Color Contract (D-02)
    var color: Color {
        switch self {
        case .idle:          return Color(red: 0.557, green: 0.557, blue: 0.576)
        case .recording:     return Color(.systemRed)
        case .transcribing:  return Color(.systemBlue)
        case .llmProcessing: return Color(.systemPurple)
        }
    }

    // UI-SPEC Animation Contract (D-04)
    var isPulsing: Bool {
        self == .recording || self == .llmProcessing
    }

    var pulseSpeed: Double {
        self == .recording ? 0.8 : 1.2
    }

    // UI-SPEC Accessibility Contract
    var accessibilityLabel: String {
        switch self {
        case .idle:          return "VoiceScribe — Bereit"
        case .recording:     return "VoiceScribe — Aufnahme läuft"
        case .transcribing:  return "VoiceScribe — Transkribiert"
        case .llmProcessing: return "VoiceScribe — KI verarbeitet"
        }
    }
}

// Swift 6: @MainActor explizit — alle Properties auf Main Thread
@MainActor
@Observable
final class AppState {
    var recordingState: RecordingState = .idle

    // Phase 1 Demo: zyklisch durch alle 4 Zustände (echte Audio-Logik folgt Phase 2)
    func toggleRecording() {
        switch recordingState {
        case .idle:          recordingState = .recording
        case .recording:     recordingState = .transcribing
        case .transcribing:  recordingState = .llmProcessing
        case .llmProcessing: recordingState = .idle
        }
    }
}
```

**Swift-6-Concurrency-Hinweis:** `@MainActor @Observable` — AppDelegate muss ebenfalls `@MainActor` sein. KeyboardShortcuts-Callbacks die von fremdem Kontext kommen in `Task { @MainActor in ... }` wrappen.

---

### `VoiceScribe/StatusBarIconView.swift` (component, event-driven)

**Analog:** kein Codebase-Analog — Greenfield
**Quelle:** RESEARCH.md Pattern 3 (NSHostingView + SwiftUI Animations)

**Imports-Pattern:**
```swift
import SwiftUI
```

**Kern-Pattern — SwiftUI View mit Pulse-Animation:**
```swift
// Quelle: RESEARCH.md Pattern 3
// UI-SPEC: Icon-Design Contract (D-01 bis D-04)
struct StatusBarIconView: View {
    let state: RecordingState
    @State private var opacity: Double = 1.0

    var body: some View {
        Image(systemName: "mic.fill")
            // D-03: .alwaysOriginal — kein Template-Image, Farben bleiben sichtbar
            // (macOS 26 Liquid Glass: Template-Icons können auf Transparenz verschwinden)
            .renderingMode(.alwaysOriginal)
            .foregroundStyle(state.color)
            .font(.system(size: 16, weight: .medium))
            .frame(width: 18, height: 18)  // UI-SPEC: 18×18 pt
            .opacity(opacity)
            .onChange(of: state) { _, newState in
                if newState.isPulsing {
                    // D-04: Pulse für Recording (0.8s) und LLM (1.2s)
                    withAnimation(.easeInOut(duration: newState.pulseSpeed).repeatForever()) {
                        opacity = 0.5
                    }
                } else {
                    withAnimation(nil) { opacity = 1.0 }
                }
            }
    }
}
```

**Fallback-Hinweis (RESEARCH.md Open Question 3):** Falls NSHostingView Performance-Probleme zeigt (UI-Ruckeln bei dauerhafter Pulse-Animation), kann auf `CABasicAnimation` umgestellt werden. Erst testen, dann optimieren.

---

### `VoiceScribe/SettingsView.swift` (component, request-response)

**Analog:** kein Codebase-Analog — Greenfield
**Quelle:** RESEARCH.md Pattern 1 (Window-Scene), UI-SPEC Einstellungsfenster Contract

**Imports-Pattern:**
```swift
import SwiftUI
```

**Kern-Pattern — Placeholder-Fenster:**
```swift
// UI-SPEC: Fenster-Titel "VoiceScribe — Einstellungen" (Em-Dash, macOS-Konvention)
// UI-SPEC: Mindestgröße 400×300 pt
// UI-SPEC: Copywriting "Einstellungen folgen in weiteren Phasen."
struct SettingsView: View {
    var body: some View {
        VStack {
            Text("Einstellungen folgen in weiteren Phasen.")
                .font(.system(size: 13))
                .foregroundStyle(Color(.labelColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)  // DesignTokens.xl
    }
}
```

**Fenster-Bindung:** Die `minWidth/minHeight`-Constraint wird im `Window`-Scene in VoiceScribeApp.swift gesetzt (`.frame(minWidth: 400, minHeight: 300)`), nicht in der View selbst.

---

### `VoiceScribe/Extensions/KeyboardShortcuts+Names.swift` (utility)

**Analog:** kein Codebase-Analog — Greenfield
**Quelle:** RESEARCH.md Pattern 4 (KeyboardShortcuts readme.md)

**Vollständiger Datei-Inhalt:**
```swift
// Quelle: https://github.com/sindresorhus/keyboardshortcuts/blob/main/readme.md
// HINWEIS: initial: Parameter ist nur für nicht-App-Store-Apps erlaubt (Pitfall 6)
// VoiceScribe ist kein App-Store-Release (Sandbox inkompatibel mit globalem Hotkey + AX)
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self(
        "toggleRecording",
        initial: .init(.r, modifiers: [.option, .command])  // ⌥⌘R — SET-02
    )
}
```

---

### `VoiceScribe/Constants/DesignTokens.swift` (config)

**Analog:** kein Codebase-Analog — Greenfield
**Quelle:** UI-SPEC Spacing Scale + Color Contract

**Vollständiger Datei-Inhalt:**
```swift
// UI-SPEC Spacing Scale (Vielfache von 4)
// UI-SPEC Color: Systemfarben bevorzugt, Accent-Farben nur für Icon-Zustände
import SwiftUI

enum DesignTokens {
    enum Spacing {
        static let xs: CGFloat = 4    // Icon-interne Abstände
        static let sm: CGFloat = 8    // Menüpunkt-Innenabstand (vertikal)
        static let md: CGFloat = 16   // Standard-Element-Abstand
        static let lg: CGFloat = 24   // Abschnittstrennungen im Menü
        static let xl: CGFloat = 32   // Fensterkanten-Padding (Einstellungsfenster)
    }

    // Accent-Farben ausschließlich für Menu-Bar-Icon — definiert in RecordingState.color
    // Systemfarben für alle anderen UI-Elemente (Dark/Light-Mode-aware):
    // Color(.windowBackgroundColor) — Menü-Hintergrund, Einstellungsfenster
    // Color(.labelColor)            — Aktive Menüpunkte
    // Color(.disabledControlTextColor) — App-Name-Zeile (disabled)
}
```

---

### `VoiceScribe/Info.plist` (config)

**Analog:** kein Codebase-Analog — Greenfield
**Quelle:** RESEARCH.md Pitfall 4 (LSUIElement), RESEARCH.md Security Domain

**Kritische Einträge:**
```xml
<!-- LSUIElement = YES: App erscheint NICHT im Dock (SET-06) -->
<key>LSUIElement</key>
<true/>

<!-- Kein App Sandbox — bewusste Entscheidung (globalem Hotkey + AX-Injektion inkompatibel) -->
<!-- com.apple.security.app-sandbox darf NICHT gesetzt sein -->
```

**Build-Setting-Anforderung:** `GENERATE_INFOPLIST_FILE = NO` + `INFOPLIST_FILE` auf manuelle plist zeigen. Sonst überschreibt Xcode die LSUIElement-Einstellung.

---

## Gemeinsame Muster (Shared Patterns)

### Swift 6 Concurrency — @MainActor
**Gilt für:** VoiceScribeApp.swift, AppDelegate.swift, AppState.swift, alle Callbacks
**Quelle:** RESEARCH.md Pitfall 3

```swift
// Alle AppKit-UI-Klassen explizit annotieren:
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate { ... }

// KeyboardShortcuts-Callbacks in Task wrappen wenn Herkunft unklar:
KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
    Task { @MainActor in
        self?.appState?.toggleRecording()
    }
}
```

### NSMenu temporäres Pattern (Anti-Anti-Pattern)
**Gilt für:** AppDelegate.showMenu()
**Quelle:** RESEARCH.md Pitfall 1 + Anti-Patterns-Abschnitt

```swift
// IMMER: temporär setzen → performClick → sofort nil
statusItem.menu = menu
statusItem.button?.performClick(nil)
statusItem.menu = nil  // KRITISCH
```

### Aktivierungspolicy-Umschaltung für Settings
**Gilt für:** VoiceScribeApp.swift (hidden window receiver), AppDelegate.openSettings()
**Quelle:** RESEARCH.md Pitfall 2 + Pattern 1

```swift
// .accessory → .regular → Fenster → .accessory
NSApp.setActivationPolicy(.regular)
NSApp.activate(ignoringOtherApps: true)
// ... Fenster vordergrundieren ...
try? await Task.sleep(for: .milliseconds(300))
NSApp.setActivationPolicy(.accessory)
```

### Notification für Settings-Öffnung
**Gilt für:** AppDelegate.swift → VoiceScribeApp.swift
**Quelle:** RESEARCH.md Pattern 1 (NotificationCenter-Brücke)

```swift
// In AppDelegate — Brücke zwischen AppKit und SwiftUI-Scene:
NotificationCenter.default.post(name: .openSettings, object: nil)

// In VoiceScribeApp — Empfang im hidden Window:
.onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
    // Aktivierungssequenz (siehe oben)
}
```

---

## Keine Analogs gefunden

Alle geplanten Dateien sind neu (Greenfield). Der Planner verwendet die RESEARCH.md-Muster als Implementierungsgrundlage.

| Datei | Rolle | Data Flow | Grund |
|-------|-------|-----------|-------|
| `VoiceScribeApp.swift` | app-entry | event-driven | Erster Swift-Code im Projekt |
| `AppDelegate.swift` | controller | event-driven | Erster Swift-Code im Projekt |
| `AppState.swift` | store | event-driven | Erster Swift-Code im Projekt |
| `StatusBarIconView.swift` | component | event-driven | Erster Swift-Code im Projekt |
| `SettingsView.swift` | component | request-response | Erster Swift-Code im Projekt |
| `KeyboardShortcuts+Names.swift` | utility | — | Erster Swift-Code im Projekt |
| `DesignTokens.swift` | config | — | Erster Swift-Code im Projekt |
| `Info.plist` | config | — | Erster Swift-Code im Projekt |

---

## Metadata

**Analog-Suchbereich:** `/Users/mbieling/claude/voice/` (vollständig gescannt — nur CLAUDE.md und .planning/ vorhanden)
**Gescannte Swift-Dateien:** 0 (Greenfield)
**Pattern-Extraktion:** Aus RESEARCH.md (verifizierte Quellen) und UI-SPEC.md
**Erstellt:** 2026-04-16
