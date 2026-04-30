---
phase: 07-parakeet-backend
reviewed: 2026-04-30T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - SPRECHKRAFT.xcodeproj/project.pbxproj
  - SPRECHKRAFT/AppState.swift
  - SPRECHKRAFT/StatusBarIconView.swift
  - SPRECHKRAFT/Transcription/ParakeetBackend.swift
  - SPRECHKRAFT/Transcription/TranscriptionBackend.swift
  - SPRECHKRAFT/Transcription/WhisperKitBackend.swift
  - SPRECHKRAFTTests/AppStateTests.swift
  - SPRECHKRAFTTests/RecordingStateTests.swift
  - SPRECHKRAFTTests/TranscriptionServiceTests.swift
findings:
  critical: 2
  warning: 5
  info: 3
  total: 10
status: issues_found
---

# Phase 07: Code Review Report

**Reviewed:** 2026-04-30
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Zusammenfassung

Geprüft wurden das Transkriptions-Backend (ParakeetBackend, TranscriptionService, Protokoll), AppState, StatusBarIconView sowie die zugehörigen Unit-Tests. Die Implementierung ist strukturell solide — der Actor-basierte Ansatz für Swift-6-Concurrency ist korrekt, und die Resampling-Logik folgt dem Apple-TN3136-Pattern. Es gibt jedoch zwei kritische Fehler: ein stiller Fehler im Fehlerfall von `downloadAndLoad` verursacht inkonsistenten AppState, und die `resampleTo16kHz`-Funktion initialisiert den Ausgabepuffer nicht, was Garbage-Daten in die Transkription einfließen lassen kann. Zusätzlich gibt es fünf Warnungen, darunter eine fehlerhafte Testannahme und ein Animation-Reset-Bug.

---

## Critical Issues

### CR-01: `downloadAndLoad` meldet Fehler nicht an Caller — AppState bleibt inkonsistent

**File:** `SPRECHKRAFT/Transcription/ParakeetBackend.swift:52-56`

**Issue:** Der `catch`-Block gibt lediglich einen `print`-Aufruf aus und kehrt still zurück. `progressHandler(1.0)` wird bei Fehler NICHT aufgerufen. Der Caller (`TranscriptionService.downloadAndLoad` → `AppDelegate.setupTranscription`) wartet nach dem `await`-Aufruf und liest dann `isModelReady`. Diese Semantik ist zwar dokumentiert, aber das Problem liegt in dem fehlenden Aufruf von `progressHandler` im Fehlerfall: AppDelegate zeigt laut Kommentar im `downloadAndLoad`-Aufruf den Zustand `.modelLoading` an, wenn `progressHandler(0.0)` kommt, und erwartet `progressHandler(1.0)` als Signal zur Zustandsänderung. Wenn der Fehlerfall eintritt, erhält AppDelegate niemals das 1.0-Signal — der UI-Zustand `.modelLoading` bleibt dauerhaft hängen, sofern AppDelegate den Fortschritts-Handler für die Zustandsübergabe nutzt (was das Design impliziert, da 0.0 = Start, 1.0 = fertig).

Zusätzlich: `progressHandler(1.0)` nach `self.isModelReady = true` gesetzt — wenn `transcribe` im Warmup-Schritt (Zeile 46) mit `try?` erfolgreich läuft, aber `asrManager`-Zuweisung und `isModelReady = true` Teil desselben Task sind, gibt es keine Race Condition (Actor). Aber die Fehlerfall-Benachrichtigung fehlt.

**Fix:**
```swift
} catch {
    print("[ParakeetBackend] Download/Load error: \(error)")
    // Fehlerfall dem Caller signalisieren — sonst bleibt UI in .modelLoading hängen
    await progressHandler(-1.0)  // Konvention: negativer Wert = Fehler
    // ODER: Protokoll auf throws ändern / separaten errorHandler-Parameter einführen
}
```

Besser: Das Protokoll `TranscriptionBackend.downloadAndLoad` auf `throws` erweitern oder einen `errorHandler`-Parameter hinzufügen, damit Fehler typsicher propagiert werden können.

---

### CR-02: Ausgabepuffer von `resampleTo16kHz` wird nicht mit Null initialisiert — Garbage-Daten möglich

**File:** `SPRECHKRAFT/Transcription/TranscriptionService.swift:97-101`

**Issue:** Der `outputBuffer` wird mit `AVAudioPCMBuffer(pcmFormat:frameCapacity:)` erstellt. `frameCapacity` wird gesetzt, aber `outputBuffer.frameLength` wird vor dem `converter.convert()`-Aufruf nicht auf 0 gesetzt. `AVAudioPCMBuffer` initialisiert den Speicher intern, aber `frameLength` ist nach Allokation 0. Das eigentliche Problem: `outputBuffer.frameLength` nach dem Converter-Aufruf wird direkt für `UnsafeBufferPointer(count:)` verwendet (Zeile 122). Wenn der Converter weniger Frames produziert als `outputFrameCount` (z.B. wegen Rounding bei der Ratio-Berechnung), ist `outputBuffer.frameLength` korrekt gesetzt — das ist kein Bug. **Jedoch:** Die `outputFrameCount`-Berechnung auf Zeile 97 verwendet Integer-Arithmetik-Truncation via `AVAudioFrameCount(Double(...))`. Bei bestimmten Samplerate-Verhältnissen (z.B. 44100 → 16000) kann die berechnete Kapazität um 1 Frame zu klein sein, was dazu führt, dass `converter.convert` die Konvertierung vorzeitig abbricht und `outputBuffer.frameLength` kleiner als erwartet ist — Audiodaten gehen verloren (kein Crash, aber Transkriptionsfehler am Ende der Aufnahme möglich).

**Fix:**
```swift
// Großzügige Kapazität mit Ceiling-Arithmetik
let outputFrameCount = AVAudioFrameCount(
    ceil(Double(inputSamples.count) * targetRate / inputRate)
) + 1  // +1 als Sicherheitsmarge gegen Rundungsfehler
```

---

## Warnings

### WR-01: `MockTranscriptionBackend` ist ein `struct` — verletzt Swift-6-Sendable-Anforderung des Protokolls und testet falsches Verhalten

**File:** `SPRECHKRAFTTests/TranscriptionServiceTests.swift:15-27`

**Issue:** `MockTranscriptionBackend` ist als `struct` deklariert und implementiert `TranscriptionBackend`. Die `var isModelReady: Bool`-Eigenschaft in einem `struct` ist `let`-äquivalent wenn die Instanz nicht `var` ist. In `testTranscribeReturnsNilWhenNotReady` (Zeile 81) wird `var notReadyBackend = MockTranscriptionBackend()` verwendet — korrekt. Aber wenn der Mock als unveränderlicher Wert übergeben wird (`TranscriptionService(backend: MockTranscriptionBackend())`), kann `isModelReady` nicht mehr geändert werden. Kritischer: Das Protokoll verlangt `var isModelReady: Bool { get async }` — ein `struct` hat keine Actor-Isolation, erfüllt `Sendable` nur durch Value-Copy-Semantik. Das ist kein Compile-Fehler, führt aber dazu, dass Tests die echte Concurrency des Protokolls nicht prüfen. Der `TranscriptionService` ist ein `actor`, der `any TranscriptionBackend` hält — nach Übergabe ist die `struct`-Kopie eingefroren.

Außerdem testet `testMinimumSampleGuardReturnsNil` (Zeile 71-77) **nur das Mock-Backend**, nicht `TranscriptionService` selbst, weil der Mock keinen eigenen Resampling-Guard hat: 800 Samples bei 16000 Hz → `resampleTo16kHz` wird mit 800 Samples aufgerufen (kein Resampling nötig) → Backend bekommt 800 Samples → Mock-Guard greift. Der Test prüft also nicht, ob `TranscriptionService.transcribeWithResampling` selbst einen Guard hat (er hat keinen — er delegiert blind ans Backend). Falls das Backend den Guard entfernt, würde der Test brechen.

**Fix:** `MockTranscriptionBackend` als `actor` implementieren, oder den Guard explizit in `TranscriptionService.transcribeWithResampling` vor dem Backend-Aufruf hinzufügen und separat testen.

---

### WR-02: `applyAnimation` in `StatusBarIconView` hat Bug beim Zustandswechsel von pulsierend zu pulsierend

**File:** `SPRECHKRAFT/StatusBarIconView.swift:47-60`

**Issue:** `withAnimation(nil) { opacity = 1.0 }` wird aufgerufen, wenn ein Zustand ohne `pulseSpeed` eintritt. Aber wenn von `.recording` (0.8s) direkt zu `.llmProcessing` (1.2s) gewechselt wird (was bei einem komplexen Fehlerfluss möglich ist), wird die alte `repeatForever`-Animation nicht gestoppt — SwiftUI überschreibt die laufende Animation mit einer neuen `repeatForever`. Dadurch kann `opacity` auf einem undefinierten Wert zwischen 0.5 und 1.0 "einfrieren", da die neue Animation von einem unbekannten Startpunkt beginnt. Kein Crash, aber visuell falsches Verhalten.

**Fix:**
```swift
private func applyAnimation(for state: RecordingState) {
    // Erst Animation zurücksetzen, dann neu setzen
    withAnimation(nil) { opacity = 1.0 }
    if let speed = state.pulseSpeed {
        withAnimation(
            .easeInOut(duration: speed)
                .repeatForever(autoreverses: true)
        ) {
            opacity = 0.5
        }
    }
}
```

---

### WR-03: `TranscriptionBackend.isModelReady` ist `async` im Protokoll — actors und structs haben unterschiedliche Semantik

**File:** `SPRECHKRAFT/Transcription/TranscriptionBackend.swift:15`

**Issue:** `var isModelReady: Bool { get async }` ist korrekt für Actor-Implementierungen. Aber `MockTranscriptionBackend` (ein `struct`) implementiert `var isModelReady: Bool = false` als stored property — das erfüllt die `async`-Anforderung syntaktisch (Swift erlaubt sync als Subtyp von async), aber es entsteht ein semantischer Mismatch: Der Test ruft `await service.isModelReady` auf (Zeile 45), was korrekt durch den `actor TranscriptionService` geht. Die Protokolldefinition erzwingt jedoch keine Isolation und kein Threading-Verhalten. Das ist ein subtiles Design-Problem: Das Protokoll könnte stattdessen `nonisolated var isModelReady: Bool { get }` deklarieren und die Async-Variante als computed property in der Erweiterung bereitstellen.

**Fix:** Dokumentation ergänzen oder Protokoll explizit auf `actor`-Konformanz einschränken:
```swift
protocol TranscriptionBackend: Actor, Sendable {
    var isModelReady: Bool { get }
    // ...
}
```
Damit wird erzwungen, dass alle Implementierungen Actors sind und `isModelReady` actor-isoliert ist.

---

### WR-04: `resampleTo16kHz` ist als `func` im Actor deklariert, aber nicht `nonisolated` — unnötiger Serialisierungsdruck

**File:** `SPRECHKRAFT/Transcription/TranscriptionService.swift:68`

**Issue:** `resampleTo16kHz` greift auf keinen Actor-State zu (keine `self`-Eigenschaften). Da es eine normale Methode eines `actor` ist, muss jeder Aufrufer von außerhalb des Actors `await` verwenden — das serialisiert Aufrufe unnötig durch den Actor-Kontext, obwohl die Funktion zustandslos ist. In Tests wird `await service.resampleTo16kHz(...)` benötigt (Zeilen 55, 65), obwohl die Funktion sicher parallel ausgeführt werden könnte.

**Fix:**
```swift
nonisolated func resampleTo16kHz(_ inputSamples: [Float], fromSampleRate inputRate: Double) -> [Float] {
    // ... unverändert
}
```
Damit kann der Test synchron aufrufen und der Actor-Serialisierungspuffer wird nicht blockiert.

---

### WR-05: `RecordingStateTests` testet `isPulsing` ohne `.modelLoading` — Test ist unvollständig und dadurch irreführend

**File:** `SPRECHKRAFTTests/RecordingStateTests.swift:35-42`

**Issue:** Der Test `isPulsing nur für recording und llmProcessing` prüft explizit nur `.idle`, `.recording`, `.transcribing`, `.llmProcessing`. Er prüft aber **nicht** `.modelLoading`, obwohl `AppState.isPulsing` auch für `.modelLoading` `true` zurückgibt (laut `AppState.swift:49`). Der Testname ist damit sachlich falsch — `isPulsing` gilt für drei Zustände, nicht zwei. Wenn zukünftig `isPulsing` für `.modelLoading` auf `false` geändert wird, schlägt dieser Test nicht an.

Ein separater Test `modelLoadingIsPulsing` (Zeile 69-73) prüft `.modelLoading.isPulsing == true` korrekt, aber der erste Test mit dem irreführenden Namen bleibt im Codebase und widerspricht dem separaten Test.

**Fix:** Testname und Assertion korrigieren:
```swift
@Test("isPulsing für recording, llmProcessing und modelLoading")
func isPulsing() {
    #expect(RecordingState.idle.isPulsing == false)
    #expect(RecordingState.recording.isPulsing == true)
    #expect(RecordingState.transcribing.isPulsing == false)
    #expect(RecordingState.llmProcessing.isPulsing == true)
    #expect(RecordingState.modelLoading.isPulsing == true)  // fehlend
    #expect(RecordingState.warmingUp.isPulsing == false)
    #expect(RecordingState.modelError.isPulsing == false)
}
```

---

## Info

### IN-01: `WhisperKitBackend.swift` enthält auskommentierten Produktionscode — kompiliert im App-Bundle mit

**File:** `SPRECHKRAFT/Transcription/WhisperKitBackend.swift:13-86`

**Issue:** Die gesamte Implementierung ist in `/* ... */` eingeschlossen. Die Datei wird trotzdem im App-Bundle kompiliert (sie ist im `project.pbxproj` unter `WK070805` als Build-Source eingetragen). Auskommentierter Code im App-Bundle erhöht die Bundle-Größe marginal und erschwert Code-Review durch das "optische Rauschen". Für einen alternativen Backend-Pfad wäre ein separater Swift-Package-Target oder eine Compile-Condition (`#if ENABLE_WHISPERKIT`) sauberer.

**Fix:** Entweder als eigenes SPM-Target auslagern oder mittels Build-Flag einblenden:
```swift
#if ENABLE_WHISPERKIT
// ... Implementation
#endif
```

---

### IN-02: `print`-Debugging in Produktionscode ohne Logger-Abstraktion

**File:** `SPRECHKRAFT/Transcription/ParakeetBackend.swift:55`, `SPRECHKRAFT/Transcription/ParakeetBackend.swift:79`

**Issue:** `print("[ParakeetBackend] ...")` landet in `stdout`, ist in Release-Builds sichtbar, nicht filterbar, und enthält keine Metadaten (Level, Kategorie, Zeitstempel). Das Projekt nutzt noch kein `OSLog`/`Logger`-Framework.

**Fix:**
```swift
import OSLog
private let logger = Logger(subsystem: "de.sprechkraft", category: "ParakeetBackend")
// Dann:
logger.error("Download/Load error: \(error, privacy: .public)")
```

---

### IN-03: `StatusBarIconView` ignoriert `systemImage` von `RecordingState` — Icon ist hartcodiert

**File:** `SPRECHKRAFT/StatusBarIconView.swift:20`

**Issue:** `Image(systemName: "mic.fill")` ist hartcodiert, obwohl `RecordingState.systemImage` bereits das korrekte SF-Symbol pro Zustand definiert (`.modelLoading` → `"arrow.down.circle"`, `.warmingUp` → `"hourglass"`, `.error`/`.modelError` → `"exclamationmark.triangle.fill"`). Dadurch zeigen alle Zustände immer `mic.fill`, auch wenn das laut UI-Spec falsch ist (D-05, D-09).

**Fix:**
```swift
Image(systemName: state.systemImage)
    .renderingMode(.original)
    .foregroundStyle(state.color)
    // ...
```

---

_Reviewed: 2026-04-30_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
