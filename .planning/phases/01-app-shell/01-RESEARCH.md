# Phase 1: App Shell — Research

**Recherchiert:** 2026-04-16
**Domain:** macOS SwiftUI + AppKit Menu Bar App, globale Hotkeys, Login-Item
**Konfidenz:** MEDIUM-HIGH (Kernbereich gut dokumentiert; macOS 26 Tahoe-spezifische Eigenheiten beachten)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Gesperrte Entscheidungen (Locked Decisions)

**Icon-Design (FEED-01)**
- D-01: Symbol `mic.fill` (SF Symbol) für alle 4 Zustände
- D-02: Farben: Idle = grau (#8E8E93), Aufnahme = rot (#FF3B30), Transkribieren = blau (#007AFF), LLM = lila (#AF52DE)
- D-03: `renderingMode: .alwaysOriginal` — kein Template-Image, Farben bleiben sichtbar
- D-04: Phase 1 enthält Pulse-Animation für Aufnahme (0.8s) und LLM (1.2s); Idle und Transkribieren statisch

**Menü-Struktur (SET-02, SET-05, SET-06)**
- D-05: Menü minimal — App-Name (disabled), Einstellungen…, Beim Login starten (Toggle), Beenden
- D-06: Linksklick = direkte Aktion (Aufnahme toggle), Rechtsklick = Menü — erfordert AppKit NSStatusItem

**Einstellungen-Placeholder (D-07)**
- Echtes leeres SwiftUI-Fenster „SPRECHKRAFT — Einstellungen", Mindestgröße 400×300 pt

### Claude's Discretion
- Xcode-Projektstruktur und Swift Package Manager Setup
- Genaue SwiftUI-Architektur (App-Delegate vs. @main SwiftUI App)
- Hotkey-Default ⌥⌘R ist durch ROADMAP.md vorgegeben; keine weitere Entscheidung nötig

### Deferred Ideas (OUT OF SCOPE)
- Keine — Diskussion blieb im Phase-Scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Beschreibung | Research-Support |
|----|-------------|-----------------|
| SET-06 | App läuft ohne Dock-Icon (`LSUIElement = YES`) | LSUIElement + `.accessory`-Aktivierungspolicy dokumentiert |
| SET-02 | Globaler Hotkey konfigurierbar (Standard ⌥⌘R) | KeyboardShortcuts SPM-Library, `initial:`-Parameter für Default |
| SET-05 | App startet automatisch beim Login (konfigurierbar) | LaunchAtLogin-modern SPM-Library, SwiftUI Toggle |
| FEED-01 | Menu-Bar-Icon: 4 Zustände mit Farbe + Animation | NSStatusItem + SwiftUI Hosting, `.alwaysOriginal`, SwiftUI `.opacity`-Animation |
</phase_requirements>

---

## Zusammenfassung

Phase 1 legt das Fundament der App: einen macOS-Prozess ohne Dock-Icon, der nur als Menu-Bar-Icon sichtbar ist. Der technische Kernkonflikt ist, dass reines SwiftUI `MenuBarExtra` die Anforderungen von D-06 (Split-Click: Links = Aktion, Rechts = Menü) nicht nativ unterstützt. Daher muss ein **AppKit/SwiftUI-Hybrid** eingesetzt werden: `@NSApplicationDelegateAdaptor` in einer SwiftUI `@main`-App, mit einem `AppDelegate` der `NSStatusItem` verwaltet.

Das zweitgrößte Problem ist das **Öffnen des Einstellungsfensters** aus dem Menu-Bar-Kontext. `openSettings` (Environment Action) funktioniert auf macOS 26 Tahoe nicht zuverlässig für accessory-Policy-Apps. Die empfohlene Lösung ist eine Aktivierungs-Policy-Umschaltung (`accessory` → `regular`) kombiniert mit `NSApp.activate()` und einem `Window`-Scene für das Einstellungsfenster.

macOS 26 Tahoe führt einen transparenten Menu-Bar-Hintergrund ein (Liquid Glass). Das hat Auswirkungen auf Icon-Sichtbarkeit: Das geplante `.alwaysOriginal`-Rendering für Farbicons ist korrekt — Template-Icons würden in manchen Wallpaper-Situationen unsichtbar werden. Die Farb-Icons bleiben sichtbar.

**Primäre Empfehlung:** `@main SwiftUI App` + `@NSApplicationDelegateAdaptor` + `NSStatusItem` im AppDelegate. SwiftUI `MenuBarExtra` nicht verwenden (zu eingeschränkt für Split-Click + Einstellungen).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Menu-Bar-Icon (Darstellung) | AppKit (NSStatusItem) | SwiftUI (Image/Animation via NSHostingView) | NSStatusItem ist die einzige API für split-click + custom rendering |
| App State (RecordingState) | App (Observable) | — | Zentrales Observable-Objekt, von Icon + Menu beobachtet |
| Globaler Hotkey | Process-global (KeyboardShortcuts) | AppState | Registrierung beim App-Start, callback in AppState |
| Rechtsklick-Menü | AppKit (NSMenu) | — | NSStatusItem.menu oder popUpMenu() |
| Einstellungsfenster | SwiftUI Window-Scene | AppKit (NSApp activate) | Window-Scene managed Lifecycle; AppKit für Aktivierung nötig |
| Login-Item Toggle | LaunchAtLogin-modern | SwiftUI Toggle | Library kapselt ServiceManagement-API |
| Farbkonstanten / Design-Tokens | Swift-Enum/Struct | — | Keine CSS, reine Swift-Konstanten |

---

## Standard Stack

### Core

| Library | Version | Zweck | Warum Standard |
|---------|---------|-------|----------------|
| Swift | 6.3 (Xcode 26) | Primärsprache | Vorhanden auf System; Swift 6 strict concurrency aktiv |
| SwiftUI | macOS 14+ | Window-Scene für Einstellungsfenster | Native Scene-API; `Window` scene für separates Fenster |
| AppKit (NSStatusItem) | macOS 14+ | Menu-Bar-Icon, Split-Click | Einzige API für differenziertes Click-Handling |
| KeyboardShortcuts | 2.4.0 | Globale Hotkeys, konfigurierbar | [VERIFIED: GitHub/SPI] Swift-tools-version 6.2, macOS 10.15+, Swift 6-kompatibel |
| LaunchAtLogin-modern | latest (1.x) | Login-Item-Toggle | [VERIFIED: GitHub] macOS 13+, Swift-tools-version 5.9 |
| Defaults | latest (8.x) | Type-safe UserDefaults-Wrapper | [VERIFIED: GitHub] Swift-tools-version 6.2, macOS 11+ |

### Supporting (Phase 1 noch nicht benötigt, aber vorbereiten)

| Library | Version | Zweck | Wann einsetzen |
|---------|---------|-------|----------------|
| GRDB.swift | v7.5.0 | SQLite Transkriptions-Historie | Ab Phase 6 |
| KeychainAccess | latest | Groq API-Key im Keychain | Ab Phase 5 |

### Alternativen (bewusst nicht gewählt)

| Statt | Könnte man | Tradeoff |
|-------|-----------|---------|
| NSStatusItem (AppKit) | SwiftUI MenuBarExtra | MenuBarExtra unterstützt kein Split-Click; kein Zugriff auf underlying NSStatusItem ohne Drittbibliothek |
| eigener Window-Controller | orchetect/SettingsAccess | Eigener NSApp-activate-Ansatz reicht; keine zusätzliche Abhängigkeit nötig |

### Installation (SPM)

```swift
// Package.swift dependencies:
dependencies: [
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    .package(url: "https://github.com/sindresorhus/LaunchAtLogin-modern", from: "1.0.0"),
    .package(url: "https://github.com/sindresorhus/Defaults", from: "8.0.0"),
]
```

---

## Architecture Patterns

### System Architecture Diagram

```
Hotkey-Event (global)
        │
        ▼
KeyboardShortcuts ──► AppState.handleHotkey()
                              │
                   ┌──────────┴──────────┐
                   ▼                     ▼
           RecordingState          (Phase 2: Audio)
           .idle → .recording
           .recording → .idle
                   │
                   ▼
         NSStatusItem.button
         ┌─────────────────┐
         │  SwiftUI Image   │  ◄── AppState.recordingState
         │  mic.fill        │       (Farbe + Animation)
         │  .alwaysOriginal │
         └─────────────────┘
                   │
         ┌─────────┴──────────┐
    Linksklick           Rechtsklick
         │                    │
         ▼                    ▼
  AppState.toggle()     NSMenu.popUp()
                         ┌──────────────────┐
                         │ SPRECHKRAFT       │
                         │ ─────────────     │
                         │ Einstellungen…   │──► NSApp.activate()
                         │ ☑ Beim Login     │    + Window("settings")
                         │ ─────────────     │
                         │ Beenden          │──► NSApp.terminate()
                         └──────────────────┘
```

### Empfohlene Projektstruktur

```
SPRECHKRAFT/
├── SPRECHKRAFTApp.swift        # @main, NSApplicationDelegateAdaptor
├── AppDelegate.swift           # NSStatusItem, NSMenu, Split-Click
├── AppState.swift              # @Observable, RecordingState enum
├── StatusBarIconView.swift     # SwiftUI View für mic.fill + Animation
├── SettingsView.swift          # Placeholder-Fenster (leerer Inhalt)
├── Extensions/
│   └── KeyboardShortcuts+Names.swift  # Extension für .toggleRecording
├── Constants/
│   └── DesignTokens.swift      # Farben, Spacings als Swift-Konstanten
├── Info.plist                  # LSUIElement = YES
└── SPRECHKRAFT.entitlements   # Keine Sandbox
```

### Pattern 1: @main + NSApplicationDelegateAdaptor + NSStatusItem

**Was:** SwiftUI `@main` App mit AppKit-Delegate für NSStatusItem-Verwaltung.
**Wann verwenden:** Immer wenn Split-Click (Links ≠ Rechts) oder feine Icon-Kontrolle nötig sind.

```swift
// SPRECHKRAFTApp.swift
// Source: Apple Developer Documentation (NSApplicationDelegateAdaptor)
@main
struct SPRECHKRAFTApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        // Verstecktes Aktivierungsfenster (muss VOR Settings stehen!)
        Window("Hidden", id: "hidden") {
            Color.clear.frame(width: 1, height: 1)
                .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
                    Task { @MainActor in
                        NSApp.setActivationPolicy(.regular)
                        NSApp.activate(ignoringOtherApps: true)
                        // Einstellungsfenster vordergrundieren
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
        Window("SPRECHKRAFT — Einstellungen", id: "settings") {
            SettingsView()
                .frame(minWidth: 400, minHeight: 300)
        }
        .windowResizability(.contentSize)
    }
}
```

```swift
// AppDelegate.swift
// Source: https://medium.com/@clyapp/implementing-left-click-and-right-click-...
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }

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
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        let titleItem = NSMenuItem(title: "SPRECHKRAFT", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Einstellungen…",
                               action: #selector(openSettings), keyEquivalent: ","))
        // LaunchAtLogin-Toggle als NSMenuItem mit State
        let loginItem = NSMenuItem(title: "Beim Login starten",
                                  action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Beenden",
                               action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil  // KRITISCH: sofort zurücksetzen, sonst wird immer Menü gezeigt
    }
}
```

### Pattern 2: AppState als @Observable Source of Truth

**Was:** Zentrales Observable-Objekt mit RecordingState-Enum.
**Wann verwenden:** Immer — ist die einzige Source of Truth für Icon-Zustand.

```swift
// AppState.swift
// Source: Apple Swift 6 Observation framework
import Observation
import KeyboardShortcuts

enum RecordingState {
    case idle          // Grau, statisch
    case recording     // Rot, pulsierend 0.8s
    case transcribing  // Blau, statisch
    case llmProcessing // Lila, pulsierend 1.2s

    var color: Color {
        switch self {
        case .idle:          return Color(red: 0.557, green: 0.557, blue: 0.576) // #8E8E93
        case .recording:     return Color(.systemRed)                             // #FF3B30
        case .transcribing:  return Color(.systemBlue)                            // #007AFF
        case .llmProcessing: return Color(.systemPurple)                          // #AF52DE
        }
    }

    var isPulsing: Bool {
        self == .recording || self == .llmProcessing
    }

    var pulseSpeed: Double {
        self == .recording ? 0.8 : 1.2
    }
}

@MainActor
@Observable
final class AppState {
    var recordingState: RecordingState = .idle

    // Phase 1 Demo: zyklisch durch alle Zustände
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

### Pattern 3: NSHostingView für animiertes Icon in NSStatusItem

**Was:** SwiftUI-View in NSStatusItem.button eingebettet via NSHostingView.
**Wann verwenden:** Wenn SwiftUI-Animationen im Menu-Bar-Icon benötigt werden.

```swift
// StatusBarIconView.swift
// Source: Apple Developer Documentation (NSHostingView)
struct StatusBarIconView: View {
    let state: RecordingState
    @State private var opacity: Double = 1.0

    var body: some View {
        Image(systemName: "mic.fill")
            .renderingMode(.alwaysOriginal)  // D-03: Farben bleiben sichtbar
            .foregroundStyle(state.color)
            .font(.system(size: 16, weight: .medium))
            .frame(width: 18, height: 18)
            .opacity(opacity)
            .onChange(of: state) { _, newState in
                if newState.isPulsing {
                    withAnimation(.easeInOut(duration: newState.pulseSpeed).repeatForever()) {
                        opacity = 0.5
                    }
                } else {
                    withAnimation(nil) { opacity = 1.0 }
                }
            }
    }
}

// In AppDelegate: Icon aktualisieren
private func updateIcon() {
    let hostingView = NSHostingView(rootView: StatusBarIconView(state: appState?.recordingState ?? .idle))
    hostingView.frame = NSRect(x: 0, y: 0, width: 26, height: 26)
    statusItem.button?.subviews.forEach { $0.removeFromSuperview() }
    statusItem.button?.addSubview(hostingView)
    statusItem.button?.frame = hostingView.frame
}
```

### Pattern 4: KeyboardShortcuts Default-Hotkey setzen

**Was:** `initial:` Parameter beim `.Name`-Enum-Eintrag setzt ⌥⌘R als Default.
**Wann verwenden:** Nur für interne/nicht-App-Store-Apps erlaubt (lt. Dokumentation).

```swift
// Extensions/KeyboardShortcuts+Names.swift
// Source: https://github.com/sindresorhus/keyboardshortcuts/blob/main/readme.md
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self(
        "toggleRecording",
        initial: .init(.r, modifiers: [.option, .command])  // ⌥⌘R
    )
}
```

### Anti-Patterns vermeiden

- **`statusItem.menu = menu` permanent setzen:** Wenn `.menu` gesetzt ist, übernimmt das System das Click-Handling vollständig — Linksklick ruft kein `.action` mehr auf. Deshalb muss `.menu` nach `performClick()` sofort auf `nil` zurückgesetzt werden.
- **Reines SwiftUI `MenuBarExtra` für Split-Click:** Kein nativer API-Zugang zum underlying NSStatusItem; nur mit orchetect/MenuBarExtraAccess möglich (zusätzliche Abhängigkeit).
- **`openSettings` Environment-Action direkt aus MenuBarExtra:** Funktioniert auf macOS 26 Tahoe nicht ohne Aktivierungskontext. Stattdessen: NotificationCenter + verstecktes Window-Pattern.
- **`NSApp.sendAction(#selector(showSettingsWindow:)):`** Deprecated seit macOS Sonoma, nicht mehr zuverlässig.
- **`@Observable` + `@State` mit `@MainActor`:** Ein `@Observable`-Objekt mit `@MainActor`-Annotation kann nicht direkt als `@State` deklariert werden wenn der View selbst nicht `@MainActor` ist. Lösung: `@State private var appState = AppState()` ist korrekt wenn AppState `@MainActor @Observable` ist und der View-Body implizit auf MainActor läuft (Swift 6: SwiftUI Views sind implizit @MainActor).
- **`.alwaysOriginal` auf macOS Tahoe transparent Menu Bar:** Entscheidung D-03 ist korrekt. Mit transparentem Hintergrund (Liquid Glass) würden Template-Icons auf hellen Wallpapern unsichtbar. Colored icons via `.alwaysOriginal` bleiben immer sichtbar.

---

## Don't Hand-Roll

| Problem | Nicht selbst bauen | Stattdessen | Warum |
|---------|-------------------|-------------|-------|
| Globale Hotkeys | Eigene CGEventTap-Registrierung | KeyboardShortcuts | CGEventTap benötigt Accessibility-Permission, Konflikt-Erkennung, UserDefaults-Persistenz — alles in Library gelöst |
| Login-Item | LSSharedFileList (deprecated) / SMLoginItemSetEnabled | LaunchAtLogin-modern | SMAppService ist macOS 13+-API mit neuen Entitlements — Library kapselt das korrekt |
| UserDefaults-Zugriff | `UserDefaults.standard.bool(forKey:)` direkt | Defaults (SPM) | Type-safety, SwiftUI-Bindungen, automatische Defaultwert-Registrierung |

**Kernerkenntnis:** Der Login-Item-Mechanismus hat sich mit macOS 13 (SMAppService) grundlegend verändert. Die LaunchAtLogin-modern-Library ist die einzige korrekte Abstraktion für macOS 13+.

---

## Common Pitfalls

### Pitfall 1: NSStatusItem.menu verhindert Split-Click

**Was passiert:** Sobald `statusItem.menu` auf ein NSMenu-Objekt gesetzt ist, übernimmt AppKit das gesamte Click-Handling. Linksklick zeigt dann auch das Menü — `.action` des Buttons wird nicht aufgerufen.
**Warum passiert es:** NSStatusItem-Design: Menu hat Priorität vor Button-Action.
**Wie vermeiden:** Menu nur temporär setzen: `statusItem.menu = menu` → `statusItem.button?.performClick(nil)` → `statusItem.menu = nil`.
**Warnsignal:** Linksklick öffnet immer das Menü statt eine Aktion auszuführen.

### Pitfall 2: openSettings schlägt auf macOS 26 Tahoe fehl

**Was passiert:** `@Environment(\.openSettings)` wird aufgerufen, tut aber nichts — kein Fenster erscheint.
**Warum passiert es:** Die Environment-Action benötigt einen aktiven SwiftUI-Render-Tree mit App-Aktivierung. Accessory-Apps (ohne Dock-Icon) haben diesen Kontext nicht zuverlässig.
**Wie vermeiden:** Verstecktes `Window`-Scene als Aktivierungsanker + `NSApp.setActivationPolicy(.regular)` → `NSApp.activate()` → Fenster vordergrundieren → zurück zu `.accessory`. Alternativ: `Window("settings", id: "settings")` direkt per `openWindow` Environment-Action öffnen (funktioniert stabiler als `openSettings`).
**Warnsignal:** `Einstellungen…`-Klick ohne sichtbares Ergebnis.

### Pitfall 3: Swift 6 Concurrency — @Observable + @MainActor

**Was passiert:** Compiler-Fehler „Main actor-isolated ... cannot be used to satisfy nonisolated requirement" oder „Sending value to MainActor-isolated context may cause data race".
**Warum passiert es:** Swift 6 strikte Concurrency: `@MainActor @Observable`-Klassen müssen von `@MainActor`-Kontexten aufgerufen werden. AppDelegate ist implizit `@MainActor` wenn mit `@MainActor` annotiert.
**Wie vermeiden:** AppDelegate explizit mit `@MainActor` annotieren. KeyboardShortcuts-Callbacks in `Task { @MainActor in ... }` wrappen wenn sie von nicht-MainActor-Kontext kommen.
**Warnsignal:** Compiler-Warnungen zu Sendable, MainActor-isolation, data races.

### Pitfall 4: LSUIElement fehlt oder wird überschrieben

**Was passiert:** Dock-Icon erscheint trotz `NSApp.setActivationPolicy(.accessory)`.
**Warum passiert es:** `NSApp.setActivationPolicy(.accessory)` muss VOR `applicationDidFinishLaunching` oder sehr früh darin aufgerufen werden. Xcode generiert ggf. `GENERATE_INFOPLIST_FILE = YES` — dann ist kein `LSUIElement` in der generierten plist.
**Wie vermeiden:** Info.plist manuell verwalten mit `LSUIElement = YES`. Build Setting `GENERATE_INFOPLIST_FILE` auf `NO` setzen. `INFOPLIST_FILE` auf Pfad zur manuellen plist zeigen.
**Warnsignal:** App erscheint im Dock oder im Force-Quit-Fenster.

### Pitfall 5: macOS 26 Liquid Glass — Icon-Sichtbarkeit

**Was passiert:** Menu-Bar-Icon wird auf bestimmten Wallpapern unsichtbar oder zu schwach sichtbar.
**Warum passiert es:** macOS 26 hat standardmäßig transparenten Menu-Bar-Hintergrund. Template-Icons passen sich an und können sich gegen den Hintergrund verlieren.
**Wie vermeiden:** `.alwaysOriginal` Rendering-Mode verwenden (D-03 ist bereits korrekt). Icon-Farben haben ausreichend Kontrast zu typischen Wallpaper-Farben (grau, rot, blau, lila).
**Warnsignal:** Icon ist auf bestimmten Wallpapern nicht erkennbar.

### Pitfall 6: KeyboardShortcuts — initial: nur für nicht-App-Store

**Was passiert:** Apple empfiehlt ausdrücklich, `initial:` NICHT für öffentlich verteilte Apps zu setzen.
**Warum passiert es:** Hotkey-Konflikte mit System- oder anderen App-Shortcuts stören den Benutzer.
**Wie vermeiden:** Da SPRECHKRAFT kein App-Store-Release ist (Sandbox inkompatibel mit globalem Hotkey + AX-Injektion), ist `initial: .init(.r, modifiers: [.option, .command])` legitim. Dokumentieren dass dies bewusste Entscheidung ist.
**Warnsignal:** Benutzer beschwert sich über ungewollte Hotkey-Übernahme.

---

## Code Examples

### Vollständige NSStatusItem Split-Click Implementierung

```swift
// Source: https://medium.com/@clyapp/implementing-left-click-and-right-click-...
// Pattern verifiziert via WebFetch 2026-04-16

func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)

    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    statusItem.button?.action = #selector(handleClick(_:))
    statusItem.button?.target = self
}

@objc func handleClick(_ sender: NSButton) {
    guard let event = NSApp.currentEvent else { return }
    if event.type == .rightMouseUp {
        showMenu()
    } else {
        appState?.toggleRecording()
        updateIcon()
    }
}

func showMenu() {
    // ... NSMenu aufbauen ...
    statusItem.menu = menu
    statusItem.button?.performClick(nil)
    statusItem.menu = nil  // KRITISCH: sofort zurücksetzen!
}
```

### LaunchAtLogin-Toggle als NSMenuItem

```swift
// Source: https://github.com/sindresorhus/launchatlogin-modern/blob/main/readme.md
import LaunchAtLogin

@objc func toggleLoginItem() {
    LaunchAtLogin.isEnabled.toggle()
}

// In showMenu():
let loginItem = NSMenuItem(title: "Beim Login starten",
                          action: #selector(toggleLoginItem),
                          keyEquivalent: "")
loginItem.state = LaunchAtLogin.isEnabled ? .on : .off
```

### Defaults Key-Deklaration (für spätere Phasen vorbereiten)

```swift
// Source: https://github.com/sindresorhus/defaults/blob/main/readme.md
import Defaults

extension Defaults.Keys {
    // Phase 1: noch keine Keys benötigt
    // Phase 2+: Beispiel
    // static let outputMode = Key<OutputMode>("outputMode", default: .textField)
}
```

---

## State of the Art

| Alter Ansatz | Aktueller Ansatz | Seit | Auswirkung |
|--------------|-----------------|------|-----------|
| `NSStatusBar.system.statusItem` + NSApplicationMain() | `@main SwiftUI App` + `@NSApplicationDelegateAdaptor` | macOS 13 | SwiftUI-Scenes für Fenster nutzbar; AppKit für NSStatusItem |
| `SMLoginItemSetEnabled` | `SMAppService` (via LaunchAtLogin-modern) | macOS 13 | Login-Helper-Bundle nicht mehr nötig |
| `NSApp.sendAction(#selector(showSettingsWindow:))` | `openSettings` Environment + Aktivierungsanker | macOS 14 | Kaputt in macOS 14-26; Workaround nötig |
| `NSStatusItem.menu` immer gesetzt | Temporäres Menu + `.menu = nil` | — | Ermöglicht Split-Click-Verhalten |

**Deprecated/veraltet:**
- `LSSharedFileList`: Für Login-Items seit macOS 13 deprecated; LaunchAtLogin-modern nutzt `SMAppService`
- `NSApp.sendAction(#selector(showSettingsWindow:))`: Seit macOS 14 nicht mehr zuverlässig

---

## Assumptions Log

| # | Behauptung | Abschnitt | Risiko wenn falsch |
|---|-----------|-----------|-------------------|
| A1 | LaunchAtLogin-modern v1.x ist Swift 6.3-kompatibel (Package.swift nutzt tools-version 5.9, keine explizite swiftLanguageMode) | Standard Stack | Compile-Fehler bei Swift 6 strict concurrency — würde Fork oder manuellen Patch erfordern |
| A2 | `.alwaysOriginal` Colored Icons auf macOS 26 Transparent Menu Bar sind stets sichtbar | Pitfalls | Falls System Farben normalisiert: Icons könnten monochromatisch wirken; Design-Entscheidung D-03 müsste überdacht werden |
| A3 | `openWindow` Environment-Action für Window-ID "settings" funktioniert auf macOS 26 stabiler als `openSettings` | Architecture Patterns | Falls auch `openWindow` versagt: Fallback zu `NSApp.windows`-Suche und manueller `makeKeyAndOrderFront()` |

---

## Open Questions

1. **Xcode nicht installiert — BLOCKIERT**
   - Was bekannt: Nur Command Line Tools (swift 6.3, CLT). Kein Xcode.app vorhanden.
   - Was unklar: Xcode ist zwingend erforderlich um eine .app-Bundle zu bauen, zu signieren und zu notarisieren. `swift build` erzeugt nur ein CLI-Executable.
   - Empfehlung: **Xcode installieren als Wave-0-Aufgabe** (Xcode 26 aus dem Mac App Store). Ohne Xcode kann Phase 1 nicht als lauffähige macOS-App abgeschlossen werden.

2. **Settings-Fenster: Window-Scene vs. NSWindowController**
   - Was bekannt: Window("id") Scene ist der SwiftUI-native Weg. NSWindowController gibt mehr AppKit-Kontrolle.
   - Was unklar: Ob Window-Scene zuverlässig ohne Dock-Icon vordergrundiert werden kann.
   - Empfehlung: Mit Window-Scene beginnen. Bei Problemen auf NSPanel/NSWindowController mit `NSApp.activate()` wechseln.

3. **NSHostingView vs. NSImage für Icon-Animation**
   - Was bekannt: NSHostingView ermöglicht SwiftUI-Animationen direkt in NSStatusItem.button.
   - Was unklar: Performance-Overhead bei häufigen State-Updates (Pulse-Animation läuft dauerhaft).
   - Empfehlung: NSHostingView testen. Falls UI-Ruckeln: Core Animation (CABasicAnimation) als Fallback.

---

## Environment Availability

| Dependency | Benötigt für | Verfügbar | Version | Fallback |
|------------|------------|-----------|---------|----------|
| macOS | Zielbetriebssystem | ✓ | 26.4.1 (Tahoe) | — |
| Swift | Compiler | ✓ | 6.3 | — |
| Swift Package Manager | Dependencies | ✓ | 6.3.0 | — |
| Xcode.app | .app-Bundle bauen, Code Signing | ✗ | nicht installiert | KEIN FALLBACK |
| git | Versionskontrolle | ✓ | 2.52.0 | — |

**Fehlende Dependencies ohne Fallback:**
- **Xcode.app** — Ohne Xcode kann keine signierte, lauffähige macOS-App erstellt werden. `swift build` erzeugt nur ein unsigniertes CLI-Binary ohne Info.plist, Entitlements oder App-Bundle-Struktur. Wave 0 muss Xcode-Installation als Voraussetzung benennen.

---

## Validation Architecture

### Test-Framework

| Eigenschaft | Wert |
|-------------|------|
| Framework | XCTest (integriert in Xcode) |
| Config-Datei | `SPRECHKRAFTTests/` (Target in Xcode-Projekt) |
| Schnell-Befehl | `xcodebuild test -scheme SPRECHKRAFT -destination 'platform=macOS'` |
| Vollständig | Identisch (Phase 1 hat keine komplexen Unit-Tests) |

### Anforderungen → Test-Map

| REQ-ID | Verhalten | Test-Typ | Automatisierter Befehl | Datei |
|--------|----------|----------|----------------------|-------|
| SET-06 | App zeigt kein Dock-Icon | UI-Test / manuell | Manuell prüfen nach App-Start | ❌ Wave 0 |
| SET-02 | Hotkey ⌥⌘R registriert und auslösbar | Unit (AppState) | `xcodebuild test -only-testing:SPRECHKRAFTTests/AppStateTests` | ❌ Wave 0 |
| SET-05 | LaunchAtLogin-Toggle wechselt State | Unit | `xcodebuild test -only-testing:SPRECHKRAFTTests/AppStateTests` | ❌ Wave 0 |
| FEED-01 | RecordingState-Enum hat 4 Zustände mit korrekten Farben | Unit | `xcodebuild test -only-testing:SPRECHKRAFTTests/RecordingStateTests` | ❌ Wave 0 |

### Wave 0 Gaps

- [ ] `SPRECHKRAFTTests/RecordingStateTests.swift` — prüft alle 4 RecordingState-Farben und isPulsing
- [ ] `SPRECHKRAFTTests/AppStateTests.swift` — prüft toggleRecording-Zustandsmaschine
- [ ] Xcode-Projekt mit Test-Target anlegen (Wave 0: Xcode installieren)

---

## Security Domain

### Applicable ASVS Categories

| ASVS-Kategorie | Anwendbar | Standard-Kontrolle |
|----------------|---------|-------------------|
| V2 Authentication | Nein | Keine Auth in Phase 1 |
| V3 Session Management | Nein | Keine Sessions |
| V4 Access Control | Teilweise | Accessibility-Permission: System fragt Nutzer; kein Code nötig |
| V5 Input Validation | Nein | Kein User-Input in Phase 1 |
| V6 Cryptography | Nein | Keine Krypto in Phase 1 |

### Bekannte Threat Patterns für macOS Menu-Bar-Apps

| Pattern | STRIDE | Standard-Mitigation |
|---------|--------|-------------------|
| Accessibility-API Missbrauch durch andere Apps | Tampering | App selbst hat keinen AX-Listener in Phase 1; keine Mitigation nötig |
| Hotkey-Konflikte mit Malware | Elevation of Privilege | KeyboardShortcuts erkennt Konflikte und warnt den Nutzer im Recorder |
| Kein Sandbox — App kann beliebige Dateien lesen | Information Disclosure | Bewusste Entscheidung (Sandbox inkompatibel mit globalem Hotkey + AX); akzeptiertes Risiko |

**Sandbox-Entscheidung:** SPRECHKRAFT läuft OHNE App Sandbox. Dies ist explizit dokumentiert in STATE.md als initiale Entscheidung. Die Entitlements-Datei muss entsprechend konfiguriert sein (kein `com.apple.security.app-sandbox`).

---

## Sources

### Primary (HIGH confidence)
- Context7 `/sindresorhus/keyboardshortcuts` — Setup, Registrierung, Default-Shortcut, SwiftUI-Recorder
- Context7 `/sindresorhus/launchatlogin-modern` — Toggle-API, programmatische Kontrolle
- Context7 `/sindresorhus/defaults` — Key-Deklaration, SwiftUI-Integration
- GitHub `sindresorhus/KeyboardShortcuts/Package.swift` — Version swift-tools-version:6.2 [VERIFIED]
- GitHub `sindresorhus/launchatlogin-modern/Package.swift` — macOS 13+, tools 5.9 [VERIFIED]
- GitHub `sindresorhus/defaults/Package.swift` — macOS 11+, tools 6.2 [VERIFIED]

### Secondary (MEDIUM confidence)
- https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items — Settings-Window-Problem auf macOS 26 Tahoe, Workaround mit verstecktem Window
- https://medium.com/@clyapp/implementing-left-click-and-right-click-for-menu-bar-status-button-in-macos-app-c3fc0b981cf0 — NSStatusItem Split-Click Muster
- https://github.com/sjhooper/TahoeMenuDemo — macOS 26 Tahoe Menu-Bar-App Muster
- https://www.polpiella.dev/a-menu-bar-only-macos-app-using-appkit/ — AppKit-basierter Ansatz, `.accessory`-Policy

### Tertiary (LOW confidence)
- WebSearch-Ergebnis zu Liquid Glass / transparent Menu Bar auf macOS 26 — `alwaysOriginal` sollte funktionieren, aber nicht mit Xcode 26 gegen echtes Device getestet

---

## Metadata

**Konfidenz-Aufschlüsselung:**
- Standard Stack: HIGH — Library-Versionen direkt aus Package.swift verifiziert
- Architecture: HIGH — NSStatusItem-Split-Click-Pattern ist etabliert und mehrfach quellen-verifiziert
- Settings-Fenster: MEDIUM — macOS-26-spezifische openSettings-Bugs bestätigt; Workaround dokumentiert aber nicht selbst getestet
- Pitfalls: HIGH — Aus offiziellen Quellen und bestätigten Entwicklerberichten
- macOS-26-Eigenheiten: MEDIUM — Liquid Glass / transparent Menu Bar: Verhalten mit `.alwaysOriginal` nur indirekt bestätigt

**Research-Datum:** 2026-04-16
**Gültig bis:** 2026-05-16 (30 Tage; macOS 26 ist stabil released)
