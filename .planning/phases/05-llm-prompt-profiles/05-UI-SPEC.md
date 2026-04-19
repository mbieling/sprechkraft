---
phase: 5
slug: llm-prompt-profiles
status: draft
shadcn_initialized: false
preset: none
created: 2026-04-19
---

# Phase 5 — UI Design Contract: LLM + Prompt Profiles

> Visual and interaction contract für die native macOS SwiftUI-App VoiceScribe.
> Generiert von gsd-ui-researcher. Verifiziert von gsd-ui-checker.
>
> Dieses Dokument ist SwiftUI-spezifisch: alle Maßangaben in Punkten (pt),
> alle Farben als SwiftUI-System-Farben oder sRGB-Werte, kein CSS.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none (natives SwiftUI, kein shadcn) |
| Preset | not applicable |
| Component library | SwiftUI + AppKit (NSMenu) |
| Icon library | SF Symbols 5 (macOS 14+) |
| Font | SF Pro (System-Standard via `.system(size:weight:)`) |

**Quelle:** CLAUDE.md §Technology Stack — SwiftUI macOS 14+, keine Web-Technologie.

---

## Spacing Scale

Deklarierte Werte aus `DesignTokens.swift` — unverändertes Fortschreiben:

| Token | Value | Verwendung |
|-------|-------|------------|
| xs | 4 pt | Icon-interne Abstände, Inline-Padding |
| sm | 8 pt | Banner-Innenabstand, HStack-Spacing in Bannern |
| md | 16 pt | Standard-Element-Abstand in Form-Rows |
| lg | 24 pt | Abschnittstrenner im Menü |
| xl | 32 pt | Fensterkanten-Padding (`.padding(DesignTokens.Spacing.xl)`) |

Ausnahmen:
- Sheet-Modal-Innenabstand: 20 pt (`.padding(20)`) — macOS HIG-Empfehlung für Sheets
- Prompt-Texteditor Mindesthöhe: 80 pt — mehrzeilige Eingabe braucht feste Mindesthöhe
- Touch-Target Mindestgröße: 44 pt × 44 pt — SF-Symbol-Buttons im Sheet (macOS HIG)

**Quelle:** `VoiceScribe/Constants/DesignTokens.swift` — bestehende Skala, direkt übernommen.

---

## Typography

Alle Angaben in Punkten (pt), System-Font via `.system(size:weight:)`.
Identisch zum bestehenden Muster in `SettingsView.swift`:

| Rolle | Größe | Weight | Line Height | SwiftUI-Ausdruck |
|-------|-------|--------|-------------|------------------|
| Body | 13 pt | regular (400) | 1.4 (system default) | `.font(.system(size: 13))` |
| Label | 13 pt | semibold (600) | 1.4 | `.font(.system(size: 13, weight: .semibold))` |
| Caption | 11 pt | regular (400) | 1.3 | `.font(.system(size: 11))` |
| Heading (Sheet-Titel) | 15 pt | semibold (600) | 1.2 | `.font(.system(size: 15, weight: .semibold))` |

Anmerkungen:
- Keine Display-Größe in dieser Phase — kein Onboarding, keine Leerseite mit großem Titel.
- `.monospacedDigit()` auf Wertanzeigen (konsistent mit Stille-Slider in SettingsView).
- Sheet-Navigationstitel verwendet `.navigationTitle()` — Größe liegt bei macOS-Systemdefault (~15 pt semibold).
- Zwei Weights: `regular (400)` für Body und Caption; `semibold (600)` für Label und Heading.

**Quelle:** `VoiceScribe/SettingsView.swift` Zeilen 38–43 (Banner-Label 13pt, Caption 11pt) — identisches Muster. Weight `medium (500)` wird nicht verwendet.

---

## Color

Natives macOS-Semantic-Color-System. Kein Custom-Hex außer dem bereits etablierten Idle-Grau.

| Rolle | Wert | Verwendung |
|-------|------|------------|
| Dominant (60%) | `Color(NSColor.windowBackgroundColor)` | Form-Hintergrund, Settings-Fenster |
| Secondary (30%) | `Color(NSColor.controlBackgroundColor)` | Form-Rows, Sheet-Hintergrund, Listenzeilen |
| Accent (10%) | `Color.accentColor` (System-Blau) | Primär-CTA-Buttons im Sheet, aktive Toggle-States |
| Destructive | `Color(.systemRed)` | Banner bei fehlendem Groq-Key, Löschen-Button |
| Disabled | `Color.secondary` mit `.opacity(0.4)` | Löschen-Button wenn nur 1 Profil vorhanden (D-06) |

Accent reserviert für:
- "Als Standard markieren"-Button (wenn Profil noch nicht Standard ist)
- Toggle-Indikatoren in aktivem Zustand (SwiftUI-System-Toggle, Farbe automatisch)
- Fokus-Ring auf dem Profil-Namensfeld im Sheet

Destructive reserviert für:
- Groq-API-Key-fehlt-Banner (analog `axPermissionDenied`-Banner, Quelle: D-11)
- Löschen-Button-Label im Sheet (Profil löschen)
- Löschen-Button ist ausgegraut (`Color.secondary.opacity(0.4)`) wenn nur 1 Profil verbleibt (D-06)

**Icon-Zustands-Farben** (bereits in `RecordingState.color` definiert, unveränderter Kontrakt):
- `.llmProcessing` → `Color(.systemPurple)`, pulsierend 1.2s — wird in Phase 5 während Groq-Aufruf gesetzt.

**Quelle:** `VoiceScribe/AppState.swift` RecordingState.color; `VoiceScribe/SettingsView.swift` Banner-Pattern.

---

## Komponenten-Inventar

### 1. SettingsView — neue Sektion „Prompt-Profile" (PROF-01 bis PROF-04)

**Position:** Neue `Section("Prompt-Profile")` unter der bestehenden Textausgabe-Sektion.

**Focal Point (Normalzustand ohne Banner):** Das aktive Standard-Profil in der Profilliste fällt als erstes ins Auge — es trägt das `⭐`-Symbol (U+2B50) in der rechten Hälfte der Zeile. Die Profilliste ist das visuell dominante Element der Sektion; der „Profil hinzufügen"-Button ist visuell zurückgenommen (`.buttonStyle(.borderless)`).

**Struktur:**

```
Section("Prompt-Profile") {
    // Groq-API-Key-Banner (D-11) — nur sichtbar wenn AppState.groqKeyMissing == true
    // [roter Banner — analog axPermissionDenied-Banner]

    // Groq-API-Key-Eingabe (SET-01)
    SecureField("API-Schlüssel", text: $groqApiKey)
        .textContentType(.password)

    // Profilliste
    List {
        ForEach(profiles) { profile in
            ProfileRowView(profile: profile)
                .onTapGesture { selectedProfile = profile }
        }
    }

    // Neues Profil anlegen
    Button("Profil hinzufügen") { ... }
        .buttonStyle(.borderless)
}
```

**Groq-API-Key-Banner:** Identisches Layout zum `axPermissionDenied`-Banner:
- `HStack(spacing: DesignTokens.Spacing.sm)`
- SF Symbol links: `"key.slash"` (weiß)
- Titeltext 13 pt semibold weiß + Body 11 pt weiß 0.9 Opacity
- Button `.buttonStyle(.bordered)` rechts: "Schlüssel eingeben"
- Hintergrund: `Color(.systemRed)`, `.cornerRadius(8)`, `.padding(DesignTokens.Spacing.sm)`

---

### 2. ProfileRowView — Listenzeile in der Profilliste

**Layout:** `HStack`

```
HStack {
    Text(profile.name)                        // 13 pt regular
        .lineLimit(1)
    Spacer()
    if profile.isDefault {
        Text("⭐")                             // Unicode U+2B50 — D-13
            .font(.system(size: 13))
    }
    Image(systemName: "chevron.right")        // SF Symbol, secondary color
        .foregroundStyle(.secondary)
        .font(.system(size: 11, weight: .semibold))
}
.contentShape(Rectangle())                   // volle Zeile klickbar
```

**Zustandsregeln:**
- Standard-Profil: `⭐`-Symbol sichtbar, kein sonstiger visueller Unterschied
- Normales Profil: kein Symbol

---

### 3. Sheet-Modal „Profil bearbeiten" (D-12)

Öffnet via `.sheet(item: $selectedProfile)` — SwiftUI-Standard-Sheet auf macOS.

**Sheet-Größe:** `.frame(width: 420, minHeight: 380)` — konsistent mit der Settings-Fensterbreite 450pt.

**Struktur (von oben nach unten, in dieser Reihenfolge):**

```
NavigationStack {
    Form {
        // 1. Profil-Name
        Section {
            TextField("Name", text: $draftName)
                .font(.system(size: 13))
        }

        // 2. Aktivierungs-Hotkey
        Section("Aktivierungs-Hotkey") {
            KeyboardShortcuts.Recorder("Profil-Hotkey", name: profileHotkeyName)
            Text("Halte diesen Hotkey während der Aufnahme, um das Profil zu aktivieren.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }

        // 3. LLM-Verarbeitung
        Section("KI-Verarbeitung") {
            Toggle("LLM-Verarbeitung aktivieren", isOn: $draftLLMEnabled)
            if draftLLMEnabled {
                Toggle("Thinking-Modus (qwen3 Chain-of-Thought)", isOn: $draftThinkingEnabled)
            }
        }

        // 4. Prompt-Text (nur sichtbar wenn LLM enabled)
        if draftLLMEnabled {
            Section("Prompt") {
                TextEditor(text: $draftPrompt)
                    .font(.system(size: 13))
                    .frame(minHeight: 80)
                Text("Der Prompt wird dem Transkript vorangestellt und an Groq qwen3-32b gesendet.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }

        // 5. Aktionen
        Section {
            // "Als Standard markieren" — ausgegraut wenn bereits Standard
            Button("Als Standard markieren") { ... }
                .disabled(profile.isDefault)

            // Profil löschen — ausgegraut wenn nur 1 Profil (D-06)
            Button(role: .destructive) {
                Text("Profil löschen")
            }
            .disabled(isOnlyProfile)
        }
    }
    .formStyle(.grouped)
    .navigationTitle(draftName.isEmpty ? "Neues Profil" : draftName)
    .toolbar {
        ToolbarItem(placement: .cancellationAction) {
            Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Profil sichern") { save(); dismiss() }
                .disabled(draftName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}
```

**Formularreihenfolge-Begründung:** Name zuerst (wichtigstes Feld, sofort editierbar) → Hotkey → KI-Toggle → Prompt (bedingt sichtbar, da abhängig von Toggle) → Aktionen am Ende (destruktive Aktion immer letzte).

---

### 4. Kontextmenü im NSMenu — aktives Profil mit Häkchen (D-03)

Analog zum OutputMode-Häkchen-Pattern in `AppDelegate.showMenu()`:

```swift
// Profile-Untersektion im NSMenu
let activeProfileID = appState.activeProfileID

for profile in profiles {
    let item = NSMenuItem(
        title: profile.name,
        action: #selector(setActiveProfile(_:)),
        keyEquivalent: ""
    )
    item.representedObject = profile.id
    item.state = profile.id == activeProfileID ? .on : .off
    item.target = self
    menu.addItem(item)
}
```

**Position im Menü:** Neue Gruppe oberhalb der OutputMode-Gruppe, mit `.separator()` davor und danach.

---

## Copywriting Contract

| Element | Text (Deutsch) |
|---------|---------------|
| Section-Titel Profilliste | `"Prompt-Profile"` |
| Primäre CTA Profil anlegen | `"Profil hinzufügen"` |
| Sheet Sichern-Button | `"Profil sichern"` |
| Sheet Abbrechen-Button | `"Abbrechen"` |
| Sheet Löschen-Button | `"Profil löschen"` |
| Sheet Standard-Button | `"Als Standard markieren"` |
| Sheet Standard-Button (bereits Standard) | `"Als Standard markieren"` (disabled) — kein Label-Wechsel |
| Name-Feld Placeholder | `"Name"` |
| Hotkey-Sektion Titel | `"Aktivierungs-Hotkey"` |
| Hotkey-Sektion Hilfetext | `"Halte diesen Hotkey während der Aufnahme, um das Profil zu aktivieren."` |
| KI-Sektion Titel | `"KI-Verarbeitung"` |
| LLM-Toggle Label | `"LLM-Verarbeitung aktivieren"` |
| Thinking-Toggle Label | `"Thinking-Modus (qwen3 Chain-of-Thought)"` |
| Prompt-Sektion Titel | `"Prompt"` |
| Prompt-Hilfetext | `"Der Prompt wird dem Transkript vorangestellt und an Groq qwen3-32b gesendet."` |
| Groq-Banner Titel | `"Groq API-Schlüssel fehlt"` |
| Groq-Banner Body | `"Ohne API-Schlüssel ist LLM-Verarbeitung nicht möglich. Füge deinen Schlüssel ein."` |
| Groq-Banner Button | `"Schlüssel eingeben"` — scrollt zum SecureField und fokussiert es |
| Groq Key-Feld Label | `"API-Schlüssel"` |
| Groq Key-Feld Hilfetext | `"Schlüssel wird sicher im macOS Keychain gespeichert."` |
| Leerstand Profilliste | Nicht möglich — initiales Default-Profil „Rohe Transkription" ist immer vorhanden (D-05) |
| Löschen-Button deaktiviert (1 Profil) | Button ausgegraut, kein zusätzlicher Tooltip-Text erforderlich |
| Sheet-Navigationstitel bei leerem Namen | `"Neues Profil"` |
| Initial-Profil-Name | `"Rohe Transkription"` |

**Destructive-Bestätigung:** Kein separater Alert für Profil-Löschen — macOS HIG erlaubt direkte destruktive Aktionen in Form-Rows ohne Alert-Bestätigung, wenn die Aktion rückgängig gemacht werden kann oder der Datenverlust minimal ist. Profile sind in UserDefaults — kein Alert erforderlich. Der Button mit `role: .destructive` kommuniziert die Absicht durch die rote Textfarbe.

---

## Interaction Contract

### SettingsView-Profilliste

| Interaktion | Reaktion |
|-------------|----------|
| Klick auf Profilzeile | Sheet öffnet sich mit Profil-Daten (`.sheet(item:)`) |
| Klick auf „Profil hinzufügen" | Sheet öffnet sich mit leerem Draft-Profil |
| Klick auf Groq-Banner-Button | Focus springt auf SecureField (`.focused($apiKeyFocused)`) |

### Sheet-Modal

| Interaktion | Reaktion |
|-------------|----------|
| LLM-Toggle EIN → AUS | Thinking-Toggle und Prompt-Editor werden mit `.transition(.opacity)` ausgeblendet (kein Ruckeln durch Layout-Shift) |
| LLM-Toggle AUS → EIN | Thinking-Toggle und Prompt-Editor eingeblendet |
| Name-Feld leer | „Profil sichern"-Button disabled |
| „Als Standard markieren" geklickt | `isDefault` auf diesem Profil true, alle anderen false; Button sofort disabled |
| „Profil löschen" geklickt (≥ 2 Profile) | Profil aus Array entfernt, Sheet dismissed |
| „Profil löschen" geklickt (1 Profil) | Aktion blockiert — Button disabled (D-06) |
| „Profil sichern" geklickt | Draft-Felder in Profil-Array persistiert, Sheet dismissed |
| „Abbrechen" geklickt | Sheet dismissed, keine Änderungen übernommen |

### NSMenu-Kontextmenü

| Interaktion | Reaktion |
|-------------|----------|
| Klick auf Profil-Eintrag | `AppState.activeProfileID` = gewähltes Profil; Häkchen wechselt |
| Nächste Menü-Öffnung | `showMenu()` baut Menü neu — Häkchen spiegelt `AppState.activeProfileID` |

### Icon-State während LLM-Verarbeitung

| Zustand | Icon-Farbe | Animation |
|---------|-----------|-----------|
| `RecordingState.llmProcessing` | `Color(.systemPurple)` | Pulsierend 1.2s (bereits in AppState.swift definiert) |

AppDelegate setzt `appState.recordingState = .llmProcessing` beim Start des Groq-Requests und `appState.resetToIdle()` nach Abschluss oder Fehler (D-10 stille Fallback).

---

## SF Symbols Inventar

| Symbol | Verwendung | Variante |
|--------|-----------|---------|
| `key.slash` | Groq-API-Banner (fehlt) | `.fill`, weiß auf systemRed |
| `key` | Groq-API-Key-Feld-Label (optional) | standard |
| `chevron.right` | Profilzeile Disclosure-Indikator | standard, `.secondary` |
| `star.fill` | Standard-Profil-Markierung als SF Alternative (optional — Unicode ⭐ hat Vorrang per D-13) | standard |
| `plus` | „Profil hinzufügen"-Button | standard, `.buttonStyle(.borderless)` |

**D-13 ist verbindlich:** Das Standardprofil wird mit dem Unicode-Zeichen `⭐` (U+2B50) markiert, nicht mit SF Symbol `star.fill`, um exakt dem in der CONTEXT.md festgelegten Design zu entsprechen.

---

## Accessibility Contract

| Komponente | accessibilityLabel | Hinweis |
|------------|-------------------|---------|
| Groq-Key-Banner | `"Groq API-Schlüssel fehlt. Füge deinen Schlüssel in das Eingabefeld ein."` | analog axPermissionDenied-Banner |
| Profilliste | automatisch via List+ForEach | VoiceOver liest Profil-Name + ⭐ wenn Standard |
| ⭐-Text in Profilzeile | `.accessibilityLabel("Standard-Profil")` | SF-Symbol-Alternative falls VoiceOver ⭐ nicht liest |
| LLM-Toggle | `"LLM-Verarbeitung aktivieren, \(draftLLMEnabled ? "aktiviert" : "deaktiviert")"` | Toggle-State für VoiceOver |
| Löschen-Button (disabled) | `.accessibilityHint("Kann nicht gelöscht werden, da es das letzte Profil ist.")` | D-06 |
| „Als Standard"-Button (disabled) | `.accessibilityHint("Dieses Profil ist bereits als Standard markiert.")` | D-13 |
| KeyboardShortcuts.Recorder | automatisch via Library | Label "Profil-Hotkey" |
| Prompt-TextEditor | `.accessibilityLabel("Prompt-Text")` | TextEditor hat kein eingebautes Label |
| Icon-Zustand llmProcessing | `"VoiceScribe — KI verarbeitet"` | bereits in `RecordingState.accessibilityLabel` |

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| shadcn official | none | not applicable — kein shadcn |
| SPM: KeyboardShortcuts | `KeyboardShortcuts.Recorder` | Context7 verifiziert (CLAUDE.md); bereits in Phase 1 integriert |
| SPM: KeychainAccess | Subscript-API `keychain["groqApiKey"]` | Context7 verifiziert (CLAUDE.md); kein Registry-Vetting erforderlich |
| SPM: Defaults | `@Default(.profiles)`, `Defaults.Keys` | Context7 verifiziert; bereits in Phasen 2+4 integriert |

Kein Third-Party-UI-Registry. Alle SPM-Abhängigkeiten sind in CLAUDE.md als Context7-verifiziert dokumentiert und bereits im Projekt vorhanden.

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS
- [ ] Dimension 2 Visuals: PASS
- [ ] Dimension 3 Color: PASS
- [ ] Dimension 4 Typography: PASS
- [ ] Dimension 5 Spacing: PASS
- [ ] Dimension 6 Registry Safety: PASS

**Approval:** pending

---

*Phase: 05-llm-prompt-profiles*
*UI-SPEC erstellt: 2026-04-19*
*Quellen: 05-CONTEXT.md (D-01–D-13), SettingsView.swift, DesignTokens.swift, AppState.swift, AppDelegate.swift*
