# Features Research

**Domain:** macOS push-to-talk dictation app mit lokaler Transkription und LLM-Nachbearbeitung
**Researched:** 2026-04-21
**Confidence:** MEDIUM-HIGH

---

## Kontext: Milestone v0.19.0

Dieses Dokument ist ein **Update** zur ursprünglichen Feature-Recherche (2026-04-15).
Bereits gebaut: WhisperKit-Transkription, Audio-Capture, AX-Text-Injektion, Groq LLM-Profile
(Keychain, ProfileEditorSheet), GRDB-History-Panel.

**Fokus dieses Updates:** Die drei neuen Feature-Bereiche des Milestones:

1. Parakeet v3 als Transkriptions-Engine (Ersatz für WhisperKit)
2. Erststart-Modell-Download-Erfahrung
3. Konsolidiertes Einstellungsfenster

---

## 1. Parakeet v3 als Transkriptions-Engine

### API-Verifikation (HIGH confidence — Context7 /senstella/parakeet-mlx)

**Eingabe:** WAV-Datei (kein ffmpeg nötig für WAV; ffmpeg nur für andere Formate).
Sample Rate wird über `model.preprocessor_config.sample_rate` abgefragt — nicht hardcoden.
In der Praxis 16 kHz (NVIDIA Parakeet Standard).

**Ausgabe:** `result.text` (string), plus `result.sentences[]` mit Zeitstempeln und
Konfidenzwerten pro Satz, plus `result.sentences[i].tokens[]` mit Wort-Level-Timestamps.
Für Diktat ist nur `result.text` erforderlich.

**High-Level API (empfohlen für Diktat):**

```python
from parakeet_mlx import from_pretrained

model = from_pretrained("mlx-community/parakeet-tdt-0.6b-v3")
result = model.transcribe("audio_file.wav")
print(result.text)  # "Hello world. This is a test."
```

**Modell-Laden:** `from_pretrained("mlx-community/parakeet-tdt-0.6b-v3")` lädt beim
ersten Aufruf von Hugging Face Hub in `~/.cache/huggingface/hub/` (oder konfigurierbares
`cache_dir`). Wenn das Modell bereits lokal vorliegt, kein Download.

**Modellgröße:** Die bfloat16-Version (`mlx-community/parakeet-tdt-0.6b-v3`) hat ca. 1.1–1.3 GB.
Eine 8-Bit-quantisierte Variante (`animaslabs/parakeet-tdt-0.6b-v3-mlx-8bit`) ist ~909 MB.
MEDIUM confidence — exakte Zahl nicht in der Doku, aus Community-Daten inferiert.

**Subprocess-Bridge-Architektur:** Das etablierte Muster für Swift↔Python ist
stdin/stdout oder Unix Domain Socket. Der Python-Prozess läuft als Daemon, empfängt
WAV-Dateipfade (oder rohe PCM-Bytes), gibt JSON mit `.text` zurück.
Konkret: Swift schreibt PCM-Buffer in eine temporäre WAV-Datei → sendet Pfad via stdin
an Python-Prozess → Python antwortet mit JSON `{"text": "..."}`.

**Alternative: swift-parakeet-mlx** (GitHub: FluidInference/swift-parakeet-mlx) —
Ein Swift-Wrapper in frühem Stadium. Noch nicht produktionsreif. Nicht empfohlen.

### Table Stakes für Parakeet-Integration

| Feature | Warum erwartet | Komplexität | Abhängigkeit von Bestehendem |
|---------|---------------|-------------|------------------------------|
| WAV-Datei als Übergabeformat | Parakeet-API erwartet Datei oder Mel-Spektrogramm; temporäre WAV-Datei ist der einfachste Weg | Low | AVAudioEngine-Tap bereits vorhanden; buffer → WAV-Datei nötig |
| Python-Subprocess starten und warm halten | Kalt-Start kostet 2–4 s (MLX-Modell laden). Daemon muss beim App-Start initialisiert werden, nicht beim ersten Diktat | Med | Neuer PythonBridgeManager als Singleton |
| Fehler-Handling: Python nicht bereit | Modell noch ladend, Prozess abgestürzt, Python-venv fehlt | Med | Error-State im Icon bereits vorhanden |
| Sample-Rate-Matching | AVAudioEngine muss mit der Sample Rate aufnehmen, die `model.preprocessor_config.sample_rate` zurückgibt (16 kHz) | Low | Bestehender Audio-Capture muss ggf. Resampler vorschalten |
| WhisperKit ersetzen, nicht parallel betreiben | WhisperKit bleibt als totes Gewicht wenn Parakeet aktiv. Klare Migration, kein doppeltes Backend | Low | Bestehender TranscriptionService-Abstraction-Layer empfohlen |

### Differenziator

| Feature | Wert | Komplexität |
|---------|------|-------------|
| Warm-up-Indikator beim App-Start ("Modell wird geladen...") | Verhindert Frustration bei erstem Diktat nach App-Start | Low |
| Konfidenzwert aus `result.sentences[].confidence` in History speichern | Nutzer sieht bei unsicheren Transkriptionen, warum der Text seltsam klingt | Low |

---

## 2. Erststart-Modell-Download-Erfahrung

### Kontext

Das Modell (~1.1–1.3 GB) wird beim ersten Start von Hugging Face Hub geladen.
`from_pretrained()` hat keinen nativen Progress-Callback für den HF-Download —
der Fortschritt muss durch Polling des lokalen Cache-Verzeichnisses oder durch
einen separaten Download-Manager (z.B. `huggingface_hub.snapshot_download` mit
`tqdm_class`) ermittelt werden.

Referenz-Implementierungen: WhisperKit (`WhisperKit.download(variant:) { progress in ... }`)
zeigt, wie macOS-Apps dieses Muster mit einem Progress-Closure lösen.
LTX-Video macOS App zeigt Download-Fortschritt in 1%-Schritten mit ETA.

### Table Stakes

| Feature | Warum erwartet | Komplexität | Notes |
|---------|---------------|-------------|-------|
| Fortschrittsbalken mit MB/Gesamt | Ohne dies wirkt die App eingefroren. Nutzer brechen ab oder force-quiten. | Med | `huggingface_hub` `snapshot_download` mit Progress-Hook; Fortschritt via stdout an Swift-Seite |
| Größenangabe vor Download-Start | "Parakeet-Modell herunterladen (ca. 1.2 GB)?" — Nutzer muss informiert entscheiden. Mobil-Nutzer auf LTE erwarten dies. | Low | Statisch hardcodiert ist akzeptabel (Größe ändert sich selten) |
| Klarer Fehlerfall: Kein Netz / unterbrochener Download | Download schlägt fehl ohne Drama; Retry-Button. App muss ohne Modell nicht crashen. | Med | Download-State-Machine: NotStarted → Downloading → Complete → Failed |
| Lokale Speicherung prüfen beim App-Start | Modell muss nicht jedes Mal neu geladen werden. Prüfe ob Cache-Verzeichnis existiert und Modell intakt ist. | Low | `from_pretrained` macht dies automatisch wenn `cache_dir` gesetzt und persistent |
| Onboarding blockiert bis Download komplett | App darf keinen Diktat-Versuch erlauben, bevor das Modell da ist. Klarer "Bitte warten"-Zustand im Menu Bar Icon. | Low | Download-Phase als eigener App-State |

### Differenziator

| Feature | Wert | Komplexität |
|---------|------|-------------|
| Geschätzter Zeitraum ("ca. 2 Minuten verbleibend") | Reduziert Abbrüche bei langsamen Verbindungen erheblich | Med |
| Download abbrechen und später fortsetzen | HF Hub unterstützt kein resumable download out-of-the-box; Workaround aufwendig | High — Anti-Feature für v1 |
| Quantisiertes Modell als Alternative anbieten (8-Bit, ~909 MB) | Kleinerer Download, etwas geringere Qualität | Med — Defer to v2 |

### Anti-Features (Erststart-Download)

| Anti-Feature | Warum vermeiden |
|--------------|-----------------|
| Download im Hintergrund ohne Feedback | Führt zu "Warum funktioniert das nicht?"-Fragen; Nutzer deinstallieren |
| Erzwungenes Konto / E-Mail für Download | Hugging Face Hub braucht keine Auth für öffentliche Modelle. Kein Konto nötig. |
| Modell mit App bundeln | Macht den App-Download ~1.2 GB schwer. Kein macOS-App-Store nötig, aber unnötig groß. Gegen PROJECT.md-Entscheidung |

---

## 3. Einstellungsfenster

### Table Stakes

Funktionen, die fehlen = Nutzer kann die App nicht sinnvoll konfigurieren.

| Feature | Warum erwartet | Komplexität | Abhängigkeit |
|---------|---------------|-------------|--------------|
| Groq API-Key eingeben/ändern | Ohne Key ist kein LLM-Modus verfügbar. Schon in Phase 05 implementiert, aber derzeit in ProfileEditorSheet — gehört in Settings | Low | Keychain-Integration bereits vorhanden |
| Prompt-Profile verwalten (CRUD) | Schon implementiert. Muss in Settings-Fenster konsolidiert werden. | Low | ProfileEditorSheet bereits vorhanden |
| Ausgabemodus wählen (Textfeld / Clipboard) | Core-UX-Entscheidung des Nutzers. Steht derzeit nirgendwo? | Low | Defaults-Integration (`sindresorhus/Defaults`) bereits Stack-Entscheidung |
| Hotkey konfigurieren mit Konflikt-Erkennung | Standardhotkey ⌥⌘R kann mit anderen Apps kollidieren. Nutzer müssen ihn ändern können, und die App muss Konflikte erkennen. | Med | `KeyboardShortcuts`-Library bereits im Stack; Konflikt-Erkennung ist eigene Logik |
| Mikrofon auswählen (Eingabegerät) | Nutzer mit externen Mics (Podcaster, Headsets) erwarten dies. Ohne diese Option berichten sie Qualitätsprobleme, die eigentlich Gerätekonflikte sind. | Low | AVAudioEngine-Device-Auswahl |
| Launch at Login Toggle | "Set it and forget it" für ein System-Tool | Low | `LaunchAtLogin-modern` bereits im Stack |
| Datenschutz-Hinweis sichtbar ("Keine Cloud, alles lokal") | Vertrauen aufbauen, Nutzer beruhigen. In macOS Settings-Pattern oft unter "About" oder als Info-Text sichtbar | Low | Nur UI-Copy |

### Nice-to-Have (Differenziator)

| Feature | Wert | Komplexität | Priorität |
|---------|------|-------------|-----------|
| Silence-Detection-Schwellenwert (dB) | Fortgeschrittene Nutzer passen ihn an ihr Mikrofon an. Wichtig für sehr laute oder sehr leise Umgebungen. | Med | Im PROJECT.md explizit gelistet → implementieren |
| Modell-Status und Re-Download | Zeigt "Parakeet v3 geladen" und erlaubt Re-Download bei Korruption. | Low | Logisch an Download-State-Machine gekoppelt |
| Tastaturkürzel-Übersicht in Settings | Alle konfigurierten Hotkeys auf einen Blick (Diktat, Profile-Switch) | Low | Gut für Orientierung nach Setup |
| Automatisches Starten der Aufnahme mit Tastendruck vs. Halten | Toggle zwischen PTT (Halten) und Toggle-Modus (einmal drücken = start, nochmals = stop) | Med | Nische; PTT ist Standard und sicherer |

### Anti-Features (Settings)

| Anti-Feature | Warum vermeiden |
|--------------|-----------------|
| Sprach-Selektor für Transkription | Parakeet v3 ist primär für Englisch optimiert. Multi-Language ist Anti-Feature gemäß bestehendem FEATURES.md. |
| Aussehen/Themes konfigurieren | Menu-Bar-App hat kaum UI. Scheinbar nützlich, aber Pflegelast. |
| Multiple LLM-Provider (OpenAI, Anthropic etc.) | Groq ist entschieden. Generalisierung ist Yak Shaving in v1. |
| Export/Import von Profilen als Datei | Nützlich in v2, Overhead in v1. Clipboard-Copy als Workaround reicht. |

### Settings-Fenster-Struktur (empfohlen)

Basierend auf macOS-HIG-Pattern: SwiftUI `Settings`-Scene mit `TabView`.
Standard-Tab-Struktur für diese App:

```
Settings
├── Tab: Allgemein
│   ├── Ausgabemodus (Textfeld / Clipboard)
│   ├── Launch at Login
│   └── Modell-Status + Re-Download
├── Tab: Aufnahme
│   ├── Hotkey konfigurieren
│   ├── Mikrofon auswählen
│   └── Silence Detection Schwellenwert
├── Tab: KI & Profile
│   ├── Groq API-Key
│   └── Prompt-Profile (CRUD — bestehender ProfileEditorSheet)
└── Tab: Über
    ├── Version
    └── Datenschutz-Statement
```

Komplexität: Die Tab-Struktur selbst ist Low. Die einzelnen Sektionen sind bereits
implementiert oder Low-Medium. Die Integration aller bestehenden Settings-Fragmente
in ein kohärentes Fenster ist der Hauptaufwand.

---

## Feature-Abhängigkeiten (v0.19.0)

```
Parakeet-Integration
  ├── Python-venv bundeln (Build-Zeit)
  │     └── parakeet-mlx + Abhängigkeiten
  ├── PythonBridgeManager (neu)
  │     ├── Subprocess-Lifecycle (start, warm-up, crash-recovery)
  │     └── Audio-zu-WAV-Konvertierung (PCM buffer → temp .wav)
  ├── Modell-Download-Flow (Erststart)
  │     ├── DownloadStateManager
  │     └── SwiftUI Download-Progress-View
  └── TranscriptionService refactoring (WhisperKit → Parakeet swap)

Settings-Fenster
  ├── Bestehende Funktionen konsolidieren:
  │     ├── Groq API-Key (aus ProfileEditorSheet herauslösen)
  │     ├── Prompt-Profile (ProfileEditorSheet bleibt, wird eingebettet)
  │     └── Launch-at-Login (ggf. bereits vorhanden)
  └── Neue Funktionen:
        ├── Hotkey-Konfiguration mit Konflikt-Erkennung
        ├── Mikrofon-Auswahl (AVAudioEngine)
        ├── Ausgabemodus-Toggle
        ├── Silence Detection Schwellenwert
        └── Modell-Status-Anzeige
```

---

## Komplexitäts-Einschätzung Gesamtmilestone

| Bereich | Komplexität | Hauptrisiken |
|---------|-------------|--------------|
| Parakeet Python-venv bundeln + signieren (kein App-Store) | Med | Python-Pfade, venv-Isolation, ggf. codesign-Attribute auf Shared Libraries |
| PythonBridgeManager + Subprocess-Lifecycle | Med | Crash-Recovery, Startup-Timing, IPC-Protokoll |
| Modell-Download mit Fortschritts-Feedback | Med | HF Hub hat keinen nativen Progress-Callback; Polling oder stdout-Streaming nötig |
| Sample-Rate-Matching AVAudioEngine ↔ Parakeet | Low-Med | 16 kHz-Resample wenn Gerät anders konfiguriert |
| Settings-Fenster (Konsolidierung) | Low-Med | SwiftUI Settings-Scene-Pattern ist gut dokumentiert; Hauptarbeit ist UI-Zusammenführung |
| Hotkey-Konflikt-Erkennung | Med | KeyboardShortcuts-Library hat Basis; Konflikt-Logik ist eigene Implementierung |

---

## Verbleibende offene Fragen

1. **Python-venv-Bundling-Strategie:** Welche Python-Version (3.11? 3.12?)? Wie wird das
   venv in die App-Bundle-Struktur eingebettet? Wie wird es beim Build automatisiert?
   Benötigt ggf. eigene Recherche-Phase.

2. **HF-Hub-Download-Progress:** `huggingface_hub.snapshot_download` hat keinen eingebauten
   Progress-Hook für die gesamte Downloadgröße in allen Versionen. Muss mit `tqdm`-Integration
   oder manuellem Polling gelöst werden. Verifikation nötig.

3. **Modell-Cache-Verzeichnis:** Soll das Modell in `~/Library/Application Support/SPRECHKRAFT/`
   liegen (App-kontrolliert) oder in `~/.cache/huggingface/hub/` (HF-Standard)?
   App-Support-Verzeichnis ist besser für "Modell neu herunterladen"-Feature und Deinstallation.

4. **Sample-Rate:** 16 kHz ist Standard für NVIDIA Parakeet. Verifizieren via
   `model.preprocessor_config.sample_rate` im laufenden System — nicht hardcoden.

---

## Quellen

- parakeet-mlx API: Context7 `/senstella/parakeet-mlx` (HIGH confidence, Score 84.3)
  https://github.com/senstella/parakeet-mlx
- Modellgröße 8-Bit-Variante: https://huggingface.co/animaslabs/parakeet-tdt-0.6b-v3-mlx-8bit
  (909 MB — MEDIUM confidence für Basesmodell-Größe)
- WhisperKit Download-Pattern: Context7 `/argmaxinc/argmax-oss-swift`
  https://github.com/argmaxinc/argmax-oss-swift
- SwiftUI Settings-Scene: https://eclecticlight.co/2024/04/30/swiftui-on-macos-settings-defaults-and-about/
- VoiceInk Feature-Set: https://github.com/Beingpax/VoiceInk und https://tryvoiceink.com/
- swift-parakeet-mlx (nicht empfohlen, frühe Phase): https://github.com/FluidInference/swift-parakeet-mlx
- Bestehende Feature-Recherche: .planning/research/FEATURES.md (2026-04-15)
