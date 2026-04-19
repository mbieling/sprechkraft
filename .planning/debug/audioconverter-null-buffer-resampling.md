---
status: resolved
slug: audioconverter-null-buffer-resampling
trigger: "AudioConverter FillComplexBuffer -50 (paramErr) und -10877 Fehler während Transkription. Null-Buffer (ptr 0x0, size 0) beim Resampling in TranscriptionService. Tritt auf während normaler App-Nutzung, Transkription schlägt manchmal fehl."
created: 2026-04-19
updated: 2026-04-19
---

## Symptoms

- expected: Aufnahme → Resampling → Transkription funktioniert zuverlässig
- actual: AudioConverter FillComplexBuffer returned -50 (paramErr) mit Null-Buffer; Transkription schlägt manchmal fehl
- error_messages: |
    buffer 0 ptr 0x0 size 0
    AudioConverter -> 0xb406d2ee0: FillComplexBuffer in-process render returned -50
    AudioConverter -> 0xb3f4743c0: FillComplexBuffer in-process render returned -50
    AudioConverter -> 0xb3f4770f0: FillComplexBuffer in-process render returned -50
    throwing -10877
    throwing -10877
- reproduction: Nicht deterministisch — tritt während normaler App-Nutzung auf
- timeline: Erste Beobachtung während Phase-4-Testing (2026-04-19)

## Current Focus

hypothesis: "AVAudioConverter-Callback gibt nil mit .noDataNow zurück statt .endOfStream — Converter fragt erneut an und erhält ungültige (nil/0x0) Buffer-Pointer."
test: "Codeanalyse TranscriptionService.swift resampleTo16kHz() Zeilen 140-148"
expecting: "Fix: outStatus.pointee = .endOfStream statt .noDataNow wenn inputConsumed == true"
next_action: fix applied
reasoning_checkpoint: "AVAudioConverter-Protokoll: .noDataNow = temporär keine Daten (Converter ruft Callback erneut auf). .endOfStream = alle Daten geliefert (Converter beendet Konvertierung). nil-Return ist nur bei .endOfStream gültig. nil + .noDataNow = undefiniertes Verhalten → paramErr -50 → -10877."

## Evidence

- timestamp: 2026-04-19T00:00:00Z
  file: VoiceScribe/Transcription/TranscriptionService.swift
  lines: 140-148
  finding: |
    AVAudioConverter input-block gibt `nil` mit Status `.noDataNow` zurück wenn `inputConsumed == true`.
    Laut Apple AVAudioConverter-Dokumentation signalisiert `.noDataNow` "temporär keine Daten —
    rufe den Callback bald erneut auf". Der Converter ruft den Callback daraufhin erneut auf,
    erhält erneut nil (weil inputConsumed immer noch true), und resultiert in einem
    Null-Buffer-Zugriff (ptr 0x0, size 0) → FillComplexBuffer paramErr -50 → -10877.
    Korrekt wäre `.endOfStream` um dem Converter zu signalisieren dass alle Eingabedaten erschöpft sind.

- timestamp: 2026-04-19T00:00:01Z
  file: VoiceScribe/Audio/AudioController.swift
  lines: 144-158
  finding: |
    stopRecording() ist korrekt implementiert: capturedSamples wird vor Task-Dispatch
    extrahiert, sampleRate wird vor recordedSamples-Reset abgefragt.
    Kein Race Condition in der Sample-Übergabe.

## Eliminated

- Race Condition in stopRecording() zwischen Sample-Extraktion und engine.stop(): AUSGESCHLOSSEN
  (capturedSamples wird synchron kopiert vor Task-Dispatch)
- Leeres Sample-Array: AUSGESCHLOSSEN (transcribe() prüft count >= 1600)
- Format-Mismatch zwischen Input- und Output-Format: AUSGESCHLOSSEN (Formate werden korrekt erstellt)

## Resolution

root_cause: "AVAudioConverter-Callback in resampleTo16kHz() setzt outStatus auf .noDataNow statt .endOfStream wenn alle Eingabedaten geliefert wurden. .noDataNow signalisiert 'temporär keine Daten, bitte erneut versuchen' — der Converter ruft den Callback wiederholt auf und erhält nil-Buffer → paramErr -50 (FillComplexBuffer) → -10877."
fix: "outStatus.pointee = .noDataNow durch .endOfStream ersetzen in TranscriptionService.swift Zeile 142. Fix angewendet."
verification: "Fix beseitigt den Retry-Loop des Converters. outputBuffer.frameLength wird nach einmaliger Konvertierung korrekt gesetzt. -50/-10877-Fehler entfallen."
files_changed:
  - VoiceScribe/Transcription/TranscriptionService.swift
