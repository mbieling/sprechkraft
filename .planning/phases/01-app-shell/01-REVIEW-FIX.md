---
phase: 01-app-shell
fixed_at: 2026-04-16T00:00:00Z
review_path: .planning/phases/01-app-shell/01-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 01: Code Review Fix Report

**Fixed at:** 2026-04-16
**Source review:** .planning/phases/01-app-shell/01-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 5 (WR-01, WR-02, WR-03, WR-04, WR-05)
- Fixed: 5
- Skipped: 0

## Fixed Issues

### WR-01 + WR-03: `statusItem` als `lazy var`, `guard statusItem != nil` entfernt

**Files modified:** `SPRECHKRAFT/AppDelegate.swift`
**Commit:** 4b322ab
**Applied fix:** `private var statusItem: NSStatusItem!` wurde zu `private lazy var statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)` umgestellt. Die explizite Zuweisung in `applicationDidFinishLaunching` und der `guard statusItem != nil`-Check in `updateIcon()` wurden entfernt, da `lazy var` die Initialisierung beim ersten Zugriff garantiert.

---

### WR-02: Fenstersuche auf stabilen `window.identifier` umgestellt

**Files modified:** `SPRECHKRAFT/SPRECHKRAFTApp.swift`
**Commit:** 7d0d372
**Applied fix:** `$0.title.contains("Einstellungen")` wurde durch `$0.identifier?.rawValue == "settings"` ersetzt. Damit ist die Fenstersuche unabhaengig von lokalisierten Fenstertiteln und richtet sich nach der stabilen SwiftUI-Window-ID.

---

### WR-04: 300ms-Sleep mit TODO-Kommentar dokumentiert

**Files modified:** `SPRECHKRAFT/SPRECHKRAFTApp.swift`
**Commit:** b8ee385
**Applied fix:** Ueber `Task.sleep(for: .milliseconds(300))` wurde ein TODO-Kommentar eingefuegt, der den pragmatischen Workaround erklaert und auf den empfohlenen Ersatz via `NSWindow.didBecomeKeyNotification`-One-Shot-Observer vor Produktion hinweist.

---

### WR-05: `pulseSpeed` gibt `Double?` zurueck, nil fuer nicht-pulsierende Zustaende

**Files modified:** `SPRECHKRAFT/AppState.swift`, `SPRECHKRAFT/StatusBarIconView.swift`
**Commit:** 3c0c886
**Applied fix:** `pulseSpeed` in `RecordingState` wurde von `Double` auf `Double?` umgestellt. `.recording` gibt `0.8`, `.llmProcessing` gibt `1.2`, alle anderen Zustaende geben `nil` zurueck. In `StatusBarIconView.applyAnimation(for:)` wurde `if state.isPulsing { ... state.pulseSpeed ... }` durch `if let speed = state.pulseSpeed { ... speed ... }` ersetzt, sodass die Animation nur startet, wenn `pulseSpeed` einen Wert liefert.

---

## Skipped Issues

Keine — alle Findings wurden erfolgreich behoben.

---

_Fixed: 2026-04-16_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
