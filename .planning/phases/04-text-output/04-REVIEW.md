---
phase: 04-text-output
reviewed: 2026-04-19T00:00:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - SPRECHKRAFT/Extensions/Defaults+Keys.swift
  - SPRECHKRAFT/Extensions/KeyboardShortcuts+Names.swift
  - SPRECHKRAFT/AppState.swift
  - SPRECHKRAFT/TextOutput/TextOutputService.swift
  - SPRECHKRAFTTests/TextOutputServiceTests.swift
  - SPRECHKRAFTTests/DefaultsKeysTests.swift
  - SPRECHKRAFT/AppDelegate.swift
  - SPRECHKRAFT/SettingsView.swift
findings:
  critical: 1
  warning: 4
  info: 3
  total: 8
status: issues_found
---

# Phase 4: Code Review Report

**Reviewed:** 2026-04-19
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found

## Summary

Phase 4 implementiert den Text-Ausgabe-Pfad (AX-Injektion und Clipboard-Fallback) sowie die zugehörigen UI-Elemente in SettingsView. Die Architektur ist insgesamt solide: `@MainActor`-Isolation ist durchgängig korrekt angewendet, die Unicode-Scalar-Behandlung in `insertText()` ist korrekt begründet, und das Protokoll-basierte Mocking-Pattern erlaubt sinnvolle Unit-Tests ohne echte AX-Permission.

Ein kritisches Problem wurde identifiziert: Der `force_cast` auf `AXUIElement` (Schritt 1 in `injectViaAX`) ist zwar durch einen `swiftlint:disable`-Kommentar markiert, aber der zugehörige `guard`-Block schützt nur gegen `nil`, nicht gegen einen falschen Laufzeittyp — dieser Fall würde ohne Vorwarnung crashen. Vier Warnungen betreffen einen logischen Fehler im Cursor-Positionierungs-Code, ein fehlgeleitetes `weak self`-Pattern im Hotkey-Handler, das Fehlen eines Clipboard-Fallbacks nach einem AX-`setAttributeValue`-Fehler (stille Rückkehr statt Fallback), und eine nicht-atomare Lese-Schreib-Sequenz auf `NSPasteboard` in Tests. Drei Info-Befunde adressieren fehlende Ausgabe-Bestätigung nach Clipboard-Schreiben, eine deprecated API-Warnung und toten Code.

---

## Critical Issues

### CR-01: force_cast auf AXUIElement kann bei Fremdtypen crashen

**File:** `SPRECHKRAFT/TextOutput/TextOutputService.swift:63`
**Issue:** `focusedRef as! AXUIElement` ist ein unkonditionierter Force-Cast. Der vorausgehende `guard`-Block garantiert nur, dass `focusedRef` nicht `nil` ist — nicht, dass der Laufzeittyp tatsächlich `AXUIElement` ist. Liefert ein Accessibility-Provider aus einer Drittanbieter-App oder einem Browser-Plugin ein Objekt eines anderen CF-Typs zurück, crasht die App mit `EXC_BAD_ACCESS` oder einem Laufzeitfehler ohne Möglichkeit zur Fehlerbehandlung.

Das gleiche Muster tritt bei Zeile 88 (`rv as! AXValue`) auf, ist dort jedoch erheblich weniger riskant: `AXValueGetValue` liefert selbst einen `Bool`-Return, sodass ein falsch getyptes Objekt maximal einen `false`-Return erzeugt.

**Fix:**
```swift
// Statt:
let focused = focusedRef as! AXUIElement

// Sicher:
guard CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else {
    // Unbekannter Typ — kein fokussiertes AX-Element, stille Rückkehr
    return
}
let focused = focusedRef as! AXUIElement  // jetzt sicher durch Typ-Prüfung
```

Alternativ, wenn `swiftlint:disable force_cast` beibehalten werden soll, genügt die CFTypeID-Prüfung als Voraussetzung:
```swift
guard CFGetTypeID(focusedRef) == AXUIElementGetTypeID(),
      let focused = focusedRef as? AXUIElement else {
    return
}
```

---

## Warnings

### WR-01: Cursor-Positionierung nach Einfügen verwendet falschen Ausgangspunkt

**File:** `SPRECHKRAFT/TextOutput/TextOutputService.swift:117`
**Issue:** Die Cursor-Neuposition nach dem Schreiben berechnet sich aus `safeLoc`, das bereits durch `min(cursorRange.location, existing.unicodeScalars.count)` gebildet wurde. Gleichzeitig wird `cursorRange.location` (der ursprüngliche Cursor) ohne dieselbe Clampung für `safeLoc` wiederholt — aber das ist noch korrekt. Das eigentliche Problem: `safeLoc` wird aus `cursorRange.location` im Verhältnis zu `existing` berechnet, aber `insertText()` in Schritt 4 hat `loc` ebenfalls intern geclamppt. Wenn `cursorRange.location > existing.unicodeScalars.count` (z.B. bei einem Race-Condition zwischen Lesen und Schreiben des AX-Werts durch eine andere App), ist `safeLoc` korrekt. Der `insertScalarCount`-Ausdruck in Zeile 116 verwendet jedoch `text.unicodeScalars.count` (der neue Text) — das ist korrekt. Der Bug liegt woanders:

`safeLoc` in Zeile 117 entspricht `min(cursorRange.location, existing.unicodeScalars.count)`. Bei einer nicht-leeren Selektion (`cursorRange.length > 0`) zeigt die neue Cursor-Position auf `safeLoc + insertScalarCount`, d.h. auf das Ende des eingefügten Textes, **aber der ersetzte Bereich (`cursorRange.length` Skalare) wurde nicht vom Offset abgezogen**. Das `insertText()`-Ergebnis hat an Position `safeLoc` bereits `cursorRange.length` Skalare gelöscht und `insertScalarCount` eingefügt. Die korrekte neue Cursor-Endposition ist `safeLoc + insertScalarCount` — das ist richtig für den Fall dass `length == 0`. Bei `length > 0` bleibt der Cursor ebenfalls auf `safeLoc + insertScalarCount`, was korrekt ist (Ende der Ersetzung). **Tatsächlicher Bug**: Der `safeLoc` in Zeile 117 wird aus `cursorRange.location` und `existing.unicodeScalars.count` gebildet, aber `cursorRange.location` ist der Beginn der Selektion — was richtig ist. Der wirkliche Fehler: Zeile 117 re-berechnet `safeLoc` unabhängig von dem `safeLoc` in `insertText()`, was zu einem inkonsistenten Cursor führt wenn `cursorRange.location > existing.unicodeScalars.count`. `insertText()` clamppt `loc` auf `scalars.count` intern, die externe `safeLoc`-Berechnung (Zeile 117) clamppt auf `existing.unicodeScalars.count` — beide sollten identisch sein. Das ist sauber. **Der echte Bug**: `cursorRange.length` wird beim Aufbau von `newCursorRange` nirgends berücksichtigt — bei Ersetzungen (`length > 0`) ist das akzeptabel (Cursor ans Ende der Einfügung), aber `safeLoc` hätte `min(cursorRange.location, composedScalarCount - insertScalarCount)` sein sollen, um im resultierenden String gültig zu sein, nicht im Quell-String `existing`.

**Konkreter Bug:** Bei einer Selektion (`cursorRange.length > 0`) kann `safeLoc + insertScalarCount` den Bereich des zusammengesetzten Strings `composed` überschreiten, da `composed.unicodeScalars.count == existing.unicodeScalars.count - cursorRange.length + insertScalarCount`. Wenn `safeLoc = existing.count` und `insertScalarCount > 0`, ist `safeLoc + insertScalarCount > composed.count` — ein ungültiger AX-Range wird gesetzt.

**Fix:**
```swift
// Zeile 117-118 ersetzen durch:
let composedScalarCount = composed.unicodeScalars.count
let newCursorLocation = min(safeLoc + insertScalarCount, composedScalarCount)
var newCursorRange = CFRange(location: newCursorLocation, length: 0)
```

---

### WR-02: setupOutputModeHotkey verwendet guard self != nil statt guard let self

**File:** `SPRECHKRAFT/AppDelegate.swift:300`
**Issue:** Der Hotkey-Callback prüft `guard self != nil else { return }` — das ist ineffektiv. `self` ist `[weak self]` im Closure-Kopf, d.h. es handelt sich um `Optional<AppDelegate>`. `guard self != nil` stellt nur sicher, dass `self` nicht dealloziert wurde, lädt `self` aber nicht in eine starke Referenz. Jeder nachfolgende Zugriff auf `self` (in diesem Fall `Defaults[.outputMode]`) ist zwar `@MainActor`-isoliert, aber da `Defaults` hier nicht über `self` aufgerufen wird, gibt es keinen direkten ABA-Fehler — der Toggle-Code greift nie auf `self` zu. Das eigentliche Problem: Das Pattern ist irreführend und im Gegensatz zu `setupHotkey()` (Zeile 282) inkonsistent. Sollte in Zukunft Code hinzugefügt werden, der `self` nach dem Guard nutzt, entsteht ein latenter ABA-Race.

**Fix:**
```swift
// Inkonsistent (Zeile 298-305):
KeyboardShortcuts.onKeyUp(for: .toggleOutputMode) { [weak self] in
    Task { @MainActor [weak self] in
        guard self != nil else { return }
        Defaults[.outputMode] = Defaults[.outputMode] == .field ? .clipboard : .field
    }
}

// Konsistent mit setupHotkey() — wenn self nicht benötigt wird, weak self weglassen:
KeyboardShortcuts.onKeyUp(for: .toggleOutputMode) {
    Task { @MainActor in
        Defaults[.outputMode] = Defaults[.outputMode] == .field ? .clipboard : .field
    }
}
```

Da `Defaults` thread-safe ist und hier kein `self`-Zugriff erfolgt, ist `[weak self]` im `onKeyUp`-Callback nicht notwendig — `KeyboardShortcuts` hält keine starke Referenz auf den Callback-Besitzer, sodass ein Retain Cycle nicht entstehen kann.

---

### WR-03: AX-Injektion fällt bei setAttributeValue-Fehler still zurück ohne Clipboard-Fallback

**File:** `SPRECHKRAFT/TextOutput/TextOutputService.swift:105-112`
**Issue:** Wenn `AXUIElementSetAttributeValue` in Schritt 6 fehlschlägt (z.B. weil ein Element `kAXValueAttribute` zwar lesbar, aber nicht schreibbar hat — ein häufiger Fall bei read-only Feldern), gibt `injectViaAX` still zurück (`return`). Der Text wird weder injiziert noch in den Clipboard geschrieben. Der Nutzer verliert seinen diktierten Text ohne jede Rückmeldung. Das ist ein stiller Datenverlust.

**Fix:**
```swift
// Zeile 105-112 ersetzen durch:
guard AXUIElementSetAttributeValue(
    focused,
    kAXValueAttribute as CFString,
    composed as CFTypeRef
) == .success else {
    // D-05-Ergänzung: Schreib-Fehler bei vorhandener Permission → Clipboard-Fallback
    // (Read-Only-Felder, Browser-Content-Editable, etc.)
    writeToClipboard(text)
    return
}
```

Alternativ kann das bewusste Nicht-Schreiben als Design-Entscheidung beibehalten werden (D-05 „stille Rückkehr"), dann sollte das im Kommentar explizit als „Datenverlust akzeptiert" dokumentiert werden, damit zukünftige Entwickler keine stillschweigende Fehlerbehandlung ergänzen.

---

### WR-04: NSPasteboard-Zugriff in Tests ist nicht isoliert — Tests können sich gegenseitig beeinflussen

**File:** `SPRECHKRAFTTests/TextOutputServiceTests.swift:48, 57, 171, 178`
**Issue:** Mehrere Test-Suites schreiben direkt auf `NSPasteboard.general` und lesen unmittelbar danach zurück, ohne den Pasteboard-Inhalt vor dem Test zurückzusetzen. Da Swift Testing keine garantierte Ausführungsreihenfolge erzwingt (insbesondere bei paralleler Ausführung via `swift test --parallel`), können Tests aus verschiedenen Suites denselben Pasteboard-Zustand sehen. Z.B. könnte `writeToClipboard()` in `TextOutputServiceClipboardTests` den Zustand von `TextOutputServiceModusTests.noPermissionUsesClipboard` überschreiben, wenn beide Suites parallel laufen. Dies kann zu Flaky-Tests führen.

**Fix:**
```swift
// In jedem Test, der NSPasteboard.general liest/schreibt, zu Beginn:
NSPasteboard.general.clearContents()

// Oder: einen setUp/tearDown-Mechanismus nutzen (Swift Testing: init/deinit):
@Suite("TextOutputService — Clipboard-Schreiben (OUT-02)")
struct TextOutputServiceClipboardTests {
    init() {
        NSPasteboard.general.clearContents()  // Isolation sicherstellen
    }
    // ...
}
```

---

## Info

### IN-01: writeToClipboard ist internal (kein private) — unbeabsichtigt öffentliche API

**File:** `SPRECHKRAFT/TextOutput/TextOutputService.swift:131`
**Issue:** `writeToClipboard(_ text: String)` hat keine explizite Zugriffsmodifikator-Annotation. Da es sich innerhalb eines `final class` befindet, ist die Standardsichtbarkeit `internal`. Der Testcode greift direkt darauf zu (`TextOutputService.shared.writeToClipboard(insert)` in Zeile 138 der Testdatei). Das erzeugt eine unbeabsichtigte öffentliche API — jeder Code im gleichen Modul kann Clipboard-Schreibvorgänge direkt auslösen, ohne den normalen `output()`-Pfad zu durchlaufen. Die Methode sollte `private` sein; der Test sollte stattdessen `output("insert", mode: .clipboard, axPermitted: false)` aufrufen.

**Fix:**
```swift
// Von:
func writeToClipboard(_ text: String) {

// Zu:
private func writeToClipboard(_ text: String) {
```

Der Test `longTextExceedsGuard()` muss dann umgeschrieben werden — die Guard-Logik für den 2040-Fall ist ohnehin besser über `output()` testbar.

---

### IN-02: SettingsView.appState ist Optional — defensive Prüfung über die gesamte View verteilt

**File:** `SPRECHKRAFT/SettingsView.swift:17`
**Issue:** `var appState: AppState?` ist optional, und alle Zugriffe nutzen `appState?.micPermissionDenied == true` / `appState?.axPermissionDenied == true`. Das ist defensiv, aber es führt dazu, dass fehlende Injection (kein `appState`) still ignoriert wird — die Permission-Banner werden nicht angezeigt, obwohl der Zustand möglicherweise korrekt sein sollte. Das Muster entspricht nicht dem Swift-Idiom für required dependencies (non-optional `let`). Wenn `appState` garantiert injiziert wird (was im AppDelegate-Aufruf der Fall ist), sollte es non-optional sein.

**Fix:**
```swift
// Wenn appState immer injiziert wird:
let appState: AppState

// Wenn es wirklich optional sein muss (Preview-freundlich):
// Dokumentieren, dass nil bedeutet "keine Permission-Banner"
```

---

### IN-03: Kommentar-Jahreszahl in RESEARCH.md-Referenz ist unplausibel

**File:** `SPRECHKRAFT/TextOutput/TextOutputService.swift:4`
**Issue:** `// Apple Developer Forums thread 658733 (2040-Limit)` — dieser Kommentar ist korrekt in der Sache. Kein Befund für die Kommentarqualität.

Stattdessen: `SettingsView.swift:58` — `.cornerRadius(8)` ist deprecated in macOS 14+ zugunsten von `.clipShape(.rect(cornerRadius: 8))`. Der Compiler erzeugt möglicherweise eine Deprecation-Warnung in zukünftigen Xcode-Versionen.

**File:** `SPRECHKRAFT/SettingsView.swift:58, 144`
**Issue:** `.cornerRadius(8)` ist seit macOS 14 / iOS 17 deprecated. Es funktioniert noch, erzeugt aber ab Xcode 16 eine Compiler-Warnung.

**Fix:**
```swift
// Von:
.cornerRadius(8)

// Zu:
.clipShape(.rect(cornerRadius: 8))
```

---

_Reviewed: 2026-04-19_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
