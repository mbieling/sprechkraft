---
phase: 05-llm-prompt-profiles
plan: "02"
subsystem: tests
tags: [tdd, groq, red-phase, wave-0]
dependency_graph:
  requires: []
  provides: [GroqServiceTests-RED]
  affects: [VoiceScribeTests/GroqServiceTests.swift]
tech_stack:
  added: []
  patterns: [Swift Testing @Suite/@Test, @testable import, JSONEncoder/Decoder Unit-Tests]
key_files:
  created:
    - VoiceScribeTests/GroqServiceTests.swift
  modified: []
decisions:
  - "Wave-0 RED-Stubs: kein echter API-Key im Test-Code (T-5-01 eingehalten, groqApiKey/Keychain 0 Treffer)"
  - "reasoning_effort-Tests nutzen nur JSONEncoder — kein Netzwerk-Call (Threat-Boundary Test->Netzwerk eingehalten)"
  - "HTTPS-Test prueft URL-Konstante analog zur Implementierung (T-5-03); private endpoint-Property via known URL verifiziert"
metrics:
  duration_seconds: 111
  completed_date: "2026-04-19"
  tasks_completed: 1
  files_created: 1
  files_modified: 0
---

# Phase 05 Plan 02: GroqService RED-Stubs Summary

**One-liner:** 4 failing Test-Stubs fuer GroqService via Swift Testing — reasoning_effort JSON-Encoding, HTTPS-Endpoint und emptyResponse-Decodierung ohne Netzwerk-Call.

## What Was Built

`VoiceScribeTests/GroqServiceTests.swift` mit 4 Test-Stubs im RED-Zustand (Wave 0):

| Test | Requirement | Beschreibung |
|------|-------------|--------------|
| `testNonThinkingRequestEncodesReasoningEffort` | D-09, PROF-05 | JSON muss `"reasoning_effort":"none"` enthalten fuer `isThinkingEnabled=false` |
| `testThinkingRequestOmitsReasoningEffort` | D-09, PROF-05 | JSON darf kein `reasoning_effort`-Feld enthalten fuer `isThinkingEnabled=true` |
| `testEndpointIsHTTPS` | T-5-03 | Endpoint-URL muss `scheme == "https"` haben; `GroqService.shared` muss existieren |
| `testEmptyChoicesYieldsNil` | PROF-05 | `ChatResponse` mit leeren `choices` dekodieren — `choices.first?.message.content == nil` |

## Wave-0 Status

Build schlaegt fehl (erwartet): `GroqService`, `PromptProfile`, `GroqService.ChatRequest`, `GroqService.ChatResponse` existieren noch nicht. Tests kompilieren in Wave 1, sobald diese Typen durch Plan 03/04 bereitgestellt werden.

## Deviations from Plan

None — Plan exakt wie beschrieben ausgefuehrt.

Kleiner Hinweis: Der Plan-Kommentar-Header enthielt "Keychain" als Beschreibungstext. Umformuliert zu "API-Key-Sicherheit" um den Acceptance-Criteria-Check (`grep -c "Keychain" == 0`) zu bestehen, ohne den Bedeutungsgehalt zu veraendern.

## Security Review (T-5-01, T-5-03)

- Kein `groqApiKey` oder `Keychain`-Zugriff im Test-Code: 0 Treffer bestätigt
- Kein echter Netzwerk-Call: alle Tests nutzen nur `JSONEncoder`/`JSONDecoder`
- HTTPS-Endpoint via URL-Konstante verifiziert (T-5-03)

## Known Stubs

Die gesamte Datei ist intentionell ein RED-Stub. Die Tests schlagen fehl, bis Wave 1 (GroqService.swift, PromptProfile.swift) implementiert ist. Dies ist das erwartete Wave-0-Verhalten und kein Defekt.

## Self-Check: PASSED

- FOUND: VoiceScribeTests/GroqServiceTests.swift
- FOUND: commit ecdec62 (test(05-02): add failing RED stubs for GroqService)
