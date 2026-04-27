---
phase: 04-text-output
fixed_at: 2026-04-19T00:00:00Z
review_path: .planning/phases/04-text-output/04-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 4: Code Review Fix Report

**Fixed at:** 2026-04-19
**Source review:** .planning/phases/04-text-output/04-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 5 (1 Critical, 4 Warning)
- Fixed: 5
- Skipped: 0

## Fixed Issues

### CR-01: force_cast auf AXUIElement kann bei Fremdtypen crashen

**Files modified:** `SPRECHKRAFT/TextOutput/TextOutputService.swift`
**Commit:** 4c19046
**Applied fix:** CFTypeID-Guard (`guard CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else { return }`) vor dem `force_cast` eingefügt. Die `as?`-Variante aus der Review-Empfehlung war nicht verwendbar — Swift meldet für CF-Typen "conditional downcast to CoreFoundation type will always succeed" als Compiler-Fehler. Der `force_cast` bleibt daher, ist aber durch den vorausgehenden Typ-Guard semantisch abgesichert. `swiftlint:disable:next force_cast`-Kommentar bleibt korrekt.

---

### WR-01: Cursor-Positionierung nach Einfügen verwendet falschen Ausgangspunkt

**Files modified:** `SPRECHKRAFT/TextOutput/TextOutputService.swift`
**Commit:** dd04154
**Applied fix:** In Schritt 7 (Cursor-Setzen) werden nun `composedScalarCount = composed.unicodeScalars.count` und `newCursorLocation = min(safeLoc + insertScalarCount, composedScalarCount)` berechnet. `var newCursorRange` verwendet `newCursorLocation` statt der unkontrollierten Summe `safeLoc + insertScalarCount`. Verhindert ungültige AX-Range-Werte bei Selektions-Ersetzungen.

---

### WR-02: setupOutputModeHotkey verwendet guard self != nil statt guard let self

**Files modified:** `SPRECHKRAFT/AppDelegate.swift`
**Commit:** 9a68c99
**Applied fix:** `[weak self]`-Capture-List aus `onKeyUp`-Callback und innerem `Task` entfernt. `guard self != nil` ebenfalls entfernt. Da `self` im Callback-Body nirgends referenziert wird, war die Capture-List irreführend und inkonsistent mit `setupHotkey()`. Der `Task { @MainActor in }` ohne Capture-List ist korrekt, da `Defaults` thread-safe ist.

---

### WR-03: AX-Injektion fällt bei setAttributeValue-Fehler still zurück ohne Clipboard-Fallback

**Files modified:** `SPRECHKRAFT/TextOutput/TextOutputService.swift`
**Commit:** b2c05c8
**Applied fix:** Im `else`-Zweig des `AXUIElementSetAttributeValue`-Guards wird nun `writeToClipboard(text)` aufgerufen statt still zurückzukehren. Verhindert stillen Datenverlust bei Read-Only-Feldern, Browser-Content-Editable und anderen AX-Elementen die lesbar aber nicht schreibbar sind.

---

### WR-04: NSPasteboard-Zugriff in Tests ist nicht isoliert

**Files modified:** `SPRECHKRAFTTests/TextOutputServiceTests.swift`
**Commit:** d7d47bd
**Applied fix:** `TextOutputServiceModusTests` und `TextOutputServiceClipboardTests` erhalten je ein `init() { NSPasteboard.general.clearContents() }`. Swift Testing ruft `init()` vor jedem Test-Suite-Durchlauf auf, womit Pasteboard-Zustandslecks bei paralleler Ausführung (`swift test --parallel`) verhindert werden. Die `TextOutputService2040GuardTests`-Suite liest nicht direkt vom Pasteboard und benötigt keine Isolation.

---

_Fixed: 2026-04-19_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
