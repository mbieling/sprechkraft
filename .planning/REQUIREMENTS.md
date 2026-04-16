# Requirements — VoiceScribe

## v1 Requirements

### RECORD — Aufnahme & Transkription

- [ ] **RECORD-01**: User kann Aufnahme per Hotkey starten (einmal drücken = Start, einmal drücken = Stopp)
- [ ] **RECORD-02**: Aufnahme stoppt automatisch nach konfigurierbarer Stille-Dauer
- [ ] **RECORD-03**: User kann Mikrofon-Eingabegerät in den Einstellungen wählen
- [ ] **RECORD-04**: Parakeet v3 transkribiert Aufnahme lokal via Python/MLX-Subprocess
- [ ] **RECORD-05**: Parakeet-Modell wird beim Erststart heruntergeladen (mit Fortschrittsanzeige)

### FEED — Visuelles & Audio-Feedback

- [x] **FEED-01**: Menüleisten-Icon zeigt 4 Zustände: Idle / Aufnahme / Transkribieren / LLM-Verarbeitung
- [ ] **FEED-02**: Kurze Töne beim Starten und Stoppen der Aufnahme
- [ ] **FEED-03**: Waveform / Level-Meter im Menüleisten-Icon während Aufnahme

### OUT — Text-Ausgabe

- [ ] **OUT-01**: Transkription wird ins aktive Textfeld an Cursor-Position eingefügt (via macOS Accessibility API)
- [ ] **OUT-02**: Alternativ: Transkription in Clipboard kopieren
- [ ] **OUT-03**: Ausgabemodus (Textfeld vs. Clipboard) per dedizierten Hotkey umschaltbar

### PROF — Prompt-Profile

- [ ] **PROF-01**: User kann mehrere benannte Prompt-Profile anlegen, bearbeiten und löschen
- [ ] **PROF-02**: Jedes Profil enthält: Name, Prompt-Text, eigenen Aktivierungs-Hotkey
- [ ] **PROF-03**: Jedes Profil hat einen LLM-Toggle (mit LLM-Verarbeitung vs. nur Transkription)
- [ ] **PROF-04**: Ein Profil kann als Standard markiert werden (aktiv wenn kein Profil-Hotkey gedrückt)
- [ ] **PROF-05**: Groq API (qwen/qwen3-32b) verarbeitet Transkript mit dem Prompt des aktiven Profils

### HIST — Historie

- [ ] **HIST-01**: Jede Transkription wird lokal mit Zeitstempel gespeichert
- [ ] **HIST-02**: Sowohl Original-Transkript als auch LLM-verarbeiteter Text werden gespeichert
- [ ] **HIST-03**: User kann durch alle gespeicherten Transkriptionen suchen (Volltext)
- [ ] **HIST-04**: User kann einen Historien-Eintrag per Klick in Clipboard kopieren

### SET — Einstellungen & App-Verhalten

- [ ] **SET-01**: Groq API-Key wird sicher im macOS Keychain gespeichert
- [ ] **SET-02**: Globaler Aufnahme-Hotkey ist konfigurierbar (Standard: `⌥⌘R`)
- [ ] **SET-03**: Stille-Erkennungs-Schwellwert ist konfigurierbar (Sekunden bis Auto-Stopp)
- [ ] **SET-04**: Mikrofon-Eingabegerät ist in Einstellungen wählbar
- [ ] **SET-05**: App startet automatisch beim Mac-Login (konfigurierbar)
- [x] **SET-06**: App läuft als Menu Bar App ohne Dock-Icon (`LSUIElement = YES`)

---

## v2 Requirements (deferred)

- Automatischer Fallback auf Clipboard wenn Accessibility-Injektion scheitert (z.B. VS Code, Terminal) — wichtig aber als separate Phase
- Push-to-Talk Modus (halten = aufnehmen) als Alternative zum Toggle
- Sprachauswahl für Transkription
- Export der Historie (CSV, JSON)
- Onboarding-Assistent für Erstnutzung
- Audio-Device-Wechsel-Erkennung (Kopfhörer anschließen)

## Out of Scope

- Cloud-basierte Transkription — Parakeet lokal ist ausreichend und privater
- Mac App Store Distribution — Sandbox inkompatibel mit Accessibility + globalem Hotkey
- iOS / iPadOS — macOS only
- Team-Features, Sync, Benutzerkonten — Solo-Tool
- Echtzeit-Streaming-Transkription — Toggle-Modus reicht
- Multi-Provider LLM-Support — Groq + qwen3-32b ist entschieden
- Custom Vocabulary / Feinabstimmung — v2+

---

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| RECORD-01 | Phase 2 | pending |
| RECORD-02 | Phase 2 | pending |
| RECORD-03 | Phase 2 | pending |
| RECORD-04 | Phase 3 | pending |
| RECORD-05 | Phase 3 | pending |
| FEED-01 | Phase 1 | Complete |
| FEED-02 | Phase 2 | pending |
| FEED-03 | Phase 2 | pending |
| OUT-01 | Phase 4 | pending |
| OUT-02 | Phase 4 | pending |
| OUT-03 | Phase 4 | pending |
| PROF-01 | Phase 5 | pending |
| PROF-02 | Phase 5 | pending |
| PROF-03 | Phase 5 | pending |
| PROF-04 | Phase 5 | pending |
| PROF-05 | Phase 5 | pending |
| HIST-01 | Phase 6 | pending |
| HIST-02 | Phase 6 | pending |
| HIST-03 | Phase 6 | pending |
| HIST-04 | Phase 6 | pending |
| SET-01 | Phase 5 | pending |
| SET-02 | Phase 1 | pending |
| SET-03 | Phase 2 | pending |
| SET-04 | Phase 2 | pending |
| SET-05 | Phase 1 | pending |
| SET-06 | Phase 1 | Complete |
