---
phase: "04-text-output"
plan: "02"
subsystem: "text-output"
tags: ["accessibility", "ax-injection", "clipboard", "unit-tests", "swift6"]

dependency_graph:
  requires:
    - "VoiceScribe/AppState.swift (axPermissionDenied — wird in Plan 01 ergaenzt)"
    - "VoiceScribe/Extensions/Defaults+Keys.swift (OutputMode — wird in Plan 01 ergaenzt)"
  provides:
    - "TextOutputServiceProtocol — testbares Interface fuer Text-Ausgabe"
    - "TextOutputService.shared — @MainActor Singleton fuer AX + Clipboard"
    - "insertText() — interne Unicode-Scalar-Insert-Hilfsfunktion"
  affects:
    - "VoiceScribe/AppDelegate.swift (Plan 03 ersetzt print()-Stub durch TextOutputService.output())"

tech_stack:
  added: []
  patterns:
    - "@MainActor final class Singleton (TextOutputService.shared)"
    - "Protocol-Mock-Pattern fuer AX-Tests ohne echte Permission"
    - "Unicode-Scalar-replaceSubrange fuer AX-konforme String-Manipulation"
    - "AXValueGetValue(.cfRange) fuer korrekte CFRange-Extraktion"

key_files:
  created:
    - "VoiceScribe/TextOutput/TextOutputService.swift"
    - "VoiceScribeTests/TextOutputServiceTests.swift"
  modified:
    - "VoiceScribe.xcodeproj/project.pbxproj"

decisions:
  - "OutputMode als Forward-Deklaration in TextOutputService.swift — Plan 01 laeuft parallel und legt den kanonischen Enum mit Defaults.Serializable an; Forward-Deklaration wird nach Merge entfernt"
  - "insertText() als package-interne Funktion (nicht private) — ermoeglicht @testable import VoiceScribe Zugriff ohne separate Test-Hilfsdatei"
  - "writeToClipboard() ist internal (nicht private) — wird von Tests via TextOutputService.shared direkt aufgerufen fuer 2040-Guard-Verifikation"
  - "TextOutput-Unterordner in VoiceScribe/ — konsistent mit bestehenden Audio/ und Transcription/ Gruppen; pbxproj-Gruppe BB040230 angelegt"

metrics:
  duration_minutes: 25
  completed_date: "2026-04-19"
  tasks_completed: 2
  files_created: 2
  files_modified: 1
---

# Phase 4 Plan 02: TextOutputService (AX-Injektion + Clipboard + Tests) Summary

**One-liner:** @MainActor TextOutputService mit AX-Injektion (Unicode-Scalar-korrekt, 2040-Guard), Clipboard-Fallback und vollstaendigen Unit-Tests via MockTextOutputService ohne echte AX-Permission.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | TextOutputServiceProtocol + TextOutputService | 0256fe0 | VoiceScribe/TextOutput/TextOutputService.swift, project.pbxproj |
| 2 | Unit-Tests fuer TextOutputService via MockTextOutputService | d79bf47 | VoiceScribeTests/TextOutputServiceTests.swift, project.pbxproj |

## What Was Built

### TextOutputService (OUT-01, OUT-02)

`@MainActor final class TextOutputService` implementiert den gesamten Text-Ausgabe-Pfad:

- `output(_ text: String, mode: OutputMode, axPermitted: Bool)` — zentraler Einstiegspunkt
- Modus-Routing: `.clipboard` oder `axPermitted == false` → direkt Clipboard (D-04, D-07)
- `injectViaAX()` — vollstaendige AX-Aufrufsequenz nach RESEARCH.md Pattern 1:
  - `AXUIElementCreateSystemWide()` + `kAXFocusedUIElementAttribute` (D-01)
  - `kAXValueAttribute` lesen + `AXValueGetValue(.cfRange)` fuer Cursor-Range (kein direktes CFRange-Casting)
  - `insertText()` mit `unicodeScalars.replaceSubrange` (D-03, Unicode-Scalar-korrekt)
  - **2040-Zeichen-Guard**: `guard composed.count <= 2000` → Clipboard-Fallback (T-04-03)
  - Cursor schreiben via `kAXSelectedTextRangeAttribute` (best-effort, Fehler ignoriert)
  - `D-05`: alle AXError-Faelle → stille Rueckkehr, kein Crash
- `writeToClipboard()` — `clearContents()` vor `setString()` (OUT-02)

### Unit-Tests (15 Tests, alle gruen)

Testsuiten ohne echte AX-Permission via `MockTextOutputService`:

| Suite | Tests |
|-------|-------|
| Modus-Routing | 4 Tests (leer, .clipboard, axPermitted=false, .field+permitted) |
| String-Insert-Logik | 7 Tests (Mitte, Anfang, Ende, Selektion, Emoji-Unicode-Scalar, 2 Safe-Bounds) |
| 2040-Zeichen-Guard | 3 Tests (>2000, =2000, =2001) |
| Clipboard-Schreiben | 3 Tests (write, ueberschreiben, leer) |

## Deviations from Plan

### Auto-angepasst

**1. [Deviation] OutputMode Forward-Deklaration hinzugefuegt**
- **Grund:** Plan 01 laeuft parallel (wave: 1, separate Worktree) — OutputMode existiert noch nicht in Defaults+Keys.swift
- **Fix:** `enum OutputMode: String { case field; case clipboard }` am Anfang von TextOutputService.swift als Forward-Deklaration mit TODO-Kommentar
- **Nach Merge:** Plan-01-OutputMode hat `Defaults.Serializable`-Konformanz; die lokale Deklaration muss entfernt werden
- **Datei:** VoiceScribe/TextOutput/TextOutputService.swift (Zeilen 12-15)

**2. [Deviation] insertText() aus injectViaAX() extrahiert**
- **Grund:** Planvorlage zeigte insertText() als lokale Test-Kopie; fuer DRY und echte Verifikation wurde sie als interne package-Funktion in TextOutputService.swift angelegt
- **Fix:** `func insertText(...)` in TextOutputService.swift (nicht private) — Tests nutzen diese direkt via `@testable import VoiceScribe`
- **Vorteil:** Tests validieren exakt dieselbe Logik wie die Produktion (keine Divergenz moeglich)

**3. [Rule 2 - Missing Test] safe-bounds Test fuer len > remaining ergaenzt**
- **Grund:** RESEARCH.md erwaehnt `safeEnd = min(safeLoc + max(len, 0), scalars.count)` als wichtig; Plan-Testliste enthielt diesen Fall nicht explizit
- **Fix:** Zusaetzlicher Test in den String-Insert-Tests
- **Regel:** Rule 2 (fehlende Testabdeckung fuer kritische Guard-Logik)

## Known Stubs

**OutputMode Forward-Deklaration** (wird nach Plan-01-Merge entfernt):
- Datei: `VoiceScribe/TextOutput/TextOutputService.swift`, Zeilen 12-15
- Aktuell: `enum OutputMode: String { case field; case clipboard }` (ohne `Defaults.Serializable`)
- Nach Merge: Plan-01-Deklaration in `Defaults+Keys.swift` hat `Defaults.Serializable`; lokale Deklaration wird entfernt
- **Intentional:** Plan-02 haengt nicht von Plan-01 ab (wave: 1, parallel)

## Threat Flags

Keine neuen Bedrohungen jenseits des Plan-Threat-Modells gefunden. T-04-03 (2040-Guard) und T-04-04 (Clipboard Disclosure) sind plankonform mitigiert bzw. akzeptiert.

## Self-Check: PASSED

- TextOutputService.swift: FOUND
- TextOutputServiceTests.swift: FOUND
- TextOutputServiceProtocol: FOUND (Zeile 23)
- guard composed.count <= 2000: FOUND (Zeile 108)
- AXValueGetValue: FOUND (Zeile 98)
- replaceSubrange: FOUND (Zeile 159)
- Commit 0256fe0: FOUND
- Commit d79bf47: FOUND
- xcodebuild test: TEST SUCCEEDED
