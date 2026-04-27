---
phase: 01-app-shell
plan: "02"
subsystem: domain-state
tags: [swift6, observable, recording-state, swiftui, tdd-green, menu-bar-icon]
dependency_graph:
  requires:
    - 01-01 (Xcode-Projektgerüst, pbxproj, SPM-Dependencies)
  provides:
    - RecordingState (enum, 4 Fälle, Farben, isPulsing, pulseSpeed, accessibilityLabel)
    - AppState (@MainActor @Observable, toggleRecording() Demo-Cycle)
    - StatusBarIconView (SwiftUI View, mic.fill, Pulse-Animation)
    - DesignTokens.Spacing (xs/sm/md/lg/xl = 4/8/16/24/32 pt)
    - KeyboardShortcuts+Names (toggleRecording, vorgezogen aus Plan 03)
  affects:
    - 01-03 (AppDelegate konsumiert AppState + StatusBarIconView via NSHostingView)
    - 01-04 (HotkeyTests bereits grün durch KeyboardShortcuts+Names)
tech_stack:
  added:
    - Observation framework (@Observable macro, Swift 5.9+)
    - SwiftUI Color(.systemRed/Blue/Purple) für System-Accent-Farben
    - SwiftUI Image.TemplateRenderingMode.original (nicht .alwaysOriginal — NSImage-API)
  patterns:
    - "@MainActor @Observable class als Source of Truth"
    - "SwiftUI View mit @State opacity + onAppear/onChange für Pulse-Animation"
    - "easeInOut.repeatForever(autoreverses: true) für Menu-Bar-Icon-Pulse"
    - "enum als Namespace für Design-Tokens (kein struct, keine Instanziierung möglich)"
key_files:
  created:
    - SPRECHKRAFT/AppState.swift
    - SPRECHKRAFT/StatusBarIconView.swift
    - SPRECHKRAFT/Constants/DesignTokens.swift
    - SPRECHKRAFT/Extensions/KeyboardShortcuts+Names.swift
  modified:
    - SPRECHKRAFT.xcodeproj/project.pbxproj (4 neue Dateien + 2 neue Gruppen registriert)
decisions:
  - "SwiftUI .renderingMode(.original) statt .alwaysOriginal — Image.TemplateRenderingMode kennt kein .alwaysOriginal (NSImage/UIImage-API); Verhalten ist äquivalent"
  - "KeyboardShortcuts+Names.swift aus Plan 03 vorgezogen — HotkeyTests.swift blockierte Test-Target-Build ohne toggleRecording-Name-Extension"
  - "onAppear + onChange(of:) in StatusBarIconView statt nur onChange — damit Initialzustand korrekt animiert wird"
metrics:
  duration_minutes: 15
  completed_date: "2026-04-16"
  tasks_total: 3
  tasks_completed: 3
  files_created: 4
  files_modified: 1
requirements_satisfied:
  - FEED-01
---

# Phase 01 Plan 02: Domain-State und Menu-Bar-Icon-View Summary

RecordingState-Enum mit 4 Zuständen (idle/recording/transcribing/llmProcessing), Farben, Pulse-Properties und Accessibility-Labels; AppState @MainActor @Observable als Source of Truth; StatusBarIconView mit mic.fill und easeInOut-Pulse-Animation; DesignTokens.Spacing-Skala — alle Tests GREEN.

## Completed Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | RecordingState-Enum und AppState implementieren | 24de095 | SPRECHKRAFT/AppState.swift, project.pbxproj |
| 2 | StatusBarIconView mit Pulse-Animation | e5d542b | SPRECHKRAFT/StatusBarIconView.swift, SPRECHKRAFT/Extensions/KeyboardShortcuts+Names.swift |
| 3 | DesignTokens-Enum für Spacing-Konstanten | 574db4d | SPRECHKRAFT/Constants/DesignTokens.swift |

## Test Status

**GREEN Phase — alle Tests bestanden:**

| Test Suite | Tests | Status |
|-----------|-------|--------|
| RecordingStateTests | 8 | PASSED |
| AppStateTests | 2 | PASSED |
| HotkeyTests | 2 | PASSED (Bonus: durch KeyboardShortcuts+Names.swift) |
| **Total** | **12** | **PASSED** |

## Öffentliche API-Contracts

### RecordingState

```swift
enum RecordingState: Equatable {
    case idle          // Color(red: 0.557, green: 0.557, blue: 0.576), statisch
    case recording     // Color(.systemRed), pulsierend 0.8s
    case transcribing  // Color(.systemBlue), statisch
    case llmProcessing // Color(.systemPurple), pulsierend 1.2s

    var color: Color
    var isPulsing: Bool       // true für .recording und .llmProcessing
    var pulseSpeed: Double    // 0.8 für .recording, 1.2 für .llmProcessing
    var accessibilityLabel: String  // Deutsch: "SPRECHKRAFT — Bereit" etc.
}
```

### AppState

```swift
@MainActor @Observable final class AppState {
    var recordingState: RecordingState  // startet bei .idle
    func toggleRecording()              // Demo-Cycle: idle→recording→transcribing→llmProcessing→idle
}
```

### StatusBarIconView

```swift
struct StatusBarIconView: View {
    init(state: RecordingState)  // Plan 03: in NSHostingView einbetten
}
```

### DesignTokens

```swift
enum DesignTokens {
    enum Spacing {
        static let xs: CGFloat = 4   // Icon-interne Abstände
        static let sm: CGFloat = 8   // Menüpunkt-Innenabstand
        static let md: CGFloat = 16  // Standard-Element-Abstand
        static let lg: CGFloat = 24  // Abschnittstrennungen
        static let xl: CGFloat = 32  // Fensterkanten-Padding
    }
}
```

### KeyboardShortcuts.Name (vorgezogen aus Plan 03)

```swift
extension KeyboardShortcuts.Name {
    static let toggleRecording: KeyboardShortcuts.Name  // ⌥⌘R, default shortcut
}
```

## Downstream-Konsumenten

| Plan | Datei | Konsumiert |
|------|-------|-----------|
| 01-03 | AppDelegate.swift | AppState (toggleRecording), StatusBarIconView (via NSHostingView), RecordingState.accessibilityLabel |
| 01-03 | AppDelegate.swift | KeyboardShortcuts.Name.toggleRecording (setupHotkey) |
| 01-03 | SettingsView.swift | DesignTokens.Spacing.xl (Padding) |
| 02+ | Audio-Layer | AppState.recordingState (wird in Phase 2 von toggleRecording entkoppelt) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] SwiftUI Image.TemplateRenderingMode hat kein .alwaysOriginal**
- **Gefunden während:** Task 2 (Build-Fehler)
- **Problem:** Der Plan-Code nutzt `.renderingMode(.alwaysOriginal)`. In SwiftUI ist `Image.TemplateRenderingMode` ein eigenständiger Typ ohne `.alwaysOriginal` — das ist die `NSImage`/`UIImage`-API. SwiftUI kennt nur `.original` und `.template`.
- **Fix:** `.renderingMode(.original)` — gleiches Verhalten (keine Template-Umfärbung), korrekte SwiftUI-API.
- **Dateien:** SPRECHKRAFT/StatusBarIconView.swift
- **Commit:** e5d542b

**2. [Rule 3 - Blockierendes Problem] HotkeyTests.swift blockierte Test-Target-Build**
- **Gefunden während:** Task 1 Verifikation (Test-Run)
- **Problem:** `HotkeyTests.swift` referenziert `KeyboardShortcuts.Name.toggleRecording`, das laut ursprünglichem Plan erst in Plan 03 definiert wird. Das Test-Target ließ sich nicht kompilieren — weder `-only-testing` noch `-skip-testing` helfen vor dem Build.
- **Fix:** `KeyboardShortcuts+Names.swift` aus Plan 03 vorgezogen. Die Extension ist trivial (1 statische Konstante), hat keine Abhängigkeiten und schadet Plan 03 nicht — Plan 03 muss die Datei nur noch in AppDelegate.setupHotkey() verwenden.
- **Bonus:** HotkeyTests (2 Tests) laufen jetzt ebenfalls grün — Plan 03 muss sie nicht mehr GREEN machen.
- **Dateien:** SPRECHKRAFT/Extensions/KeyboardShortcuts+Names.swift, project.pbxproj
- **Commit:** e5d542b

**3. [Rule 2 - Fehlende Funktionalität] onAppear fehlte im Pattern-Code**
- **Gefunden während:** Task 2 Implementierung
- **Problem:** Das PATTERNS.md-Pattern für StatusBarIconView nutzt nur `onChange(of:)`, nicht `onAppear`. Damit würde der initiale Zustand (z.B. `.recording` beim App-Start) keine Pulse-Animation starten.
- **Fix:** `onAppear { applyAnimation(for: state) }` ergänzt, damit der Initialzustand korrekt animiert wird.
- **Dateien:** SPRECHKRAFT/StatusBarIconView.swift
- **Commit:** e5d542b

## Threat Mitigations Applied

| Threat | Mitigation |
|--------|-----------|
| T-01-06 (Farbwerte-Tampering) | Farben als Literal-Konstanten im Enum; RecordingStateTests verifizieren alle 4 Farbwerte — keine externe Konfiguration möglich |
| T-01-08 (Pulse DoS) | Animation stoppt via `withAnimation(nil) { opacity = 1.0 }` sobald isPulsing false wird; kein unbegrenzter Animation-Loop ohne Zustandsänderung |

## Known Stubs

Keine — alle Werte sind konkret implementiert und durch Tests verifiziert.

## Self-Check: PASSED

- [x] SPRECHKRAFT/AppState.swift: FOUND
- [x] SPRECHKRAFT/StatusBarIconView.swift: FOUND
- [x] SPRECHKRAFT/Constants/DesignTokens.swift: FOUND
- [x] SPRECHKRAFT/Extensions/KeyboardShortcuts+Names.swift: FOUND
- [x] Commit 24de095: FOUND (feat: RecordingState + AppState)
- [x] Commit e5d542b: FOUND (feat: StatusBarIconView + KeyboardShortcuts+Names)
- [x] Commit 574db4d: FOUND (feat: DesignTokens)
- [x] RecordingStateTests 8/8: PASSED
- [x] AppStateTests 2/2: PASSED
- [x] HotkeyTests 2/2: PASSED (Bonus)
- [x] BUILD SUCCEEDED (App-Target)
