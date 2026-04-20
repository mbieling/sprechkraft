// VoiceScribe/ProfileEditorSheet.swift
// Zweck: Sheet-Modal fuer Profil-CRUD (D-12, PROF-01 bis PROF-04).
// UI-SPEC: 05-UI-SPEC.md §Sheet-Modal "Profil bearbeiten"
// D-06: Loeschen-Button ausgegraut wenn nur 1 Profil vorhanden.
// D-09: Thinking-Toggle nur sichtbar wenn LLM aktiviert.
// isDefault-Invariante: beim Markieren alle anderen Profile auf false setzen.

import SwiftUI
import Defaults
import KeyboardShortcuts

struct ProfileEditorSheet: View {
    // Draft-Pattern: Aenderungen werden erst bei "Profil sichern" uebernommen
    @State private var draft: PromptProfile
    let isOnlyProfile: Bool    // D-06: Loeschen deaktiviert wenn true
    var onSave: (PromptProfile) -> Void
    var onDelete: () -> Void
    var onSetDefault: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(profile: PromptProfile,
         isOnlyProfile: Bool,
         onSave: @escaping (PromptProfile) -> Void,
         onDelete: @escaping () -> Void,
         onSetDefault: @escaping () -> Void) {
        _draft = State(initialValue: profile)
        self.isOnlyProfile = isOnlyProfile
        self.onSave = onSave
        self.onDelete = onDelete
        self.onSetDefault = onSetDefault
    }

    var body: some View {
        NavigationStack {
            Form {
                // 1. Profil-Name (UI-SPEC: erstes Feld, sofort editierbar)
                Section {
                    TextField("Name", text: $draft.name)
                        .font(.system(size: 13))
                }

                // 2. Aktivierungs-Hotkey (PROF-02)
                Section("Aktivierungs-Hotkey") {
                    KeyboardShortcuts.Recorder("Profil-Hotkey", name: .profile(draft.id))
                    Text("Halte diesen Hotkey während der Aufnahme, um das Profil zu aktivieren.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                // 3. KI-Verarbeitung (PROF-03, D-09)
                Section("KI-Verarbeitung") {
                    Toggle("LLM-Verarbeitung aktivieren", isOn: $draft.isLLMEnabled)
                        .accessibilityLabel("LLM-Verarbeitung aktivieren, \(draft.isLLMEnabled ? "aktiviert" : "deaktiviert")")
                    if draft.isLLMEnabled {
                        Toggle("Thinking-Modus (qwen3 Chain-of-Thought)", isOn: $draft.isThinkingEnabled)
                    }
                }

                // 4. Prompt-Text — nur sichtbar wenn LLM aktiviert (D-09)
                if draft.isLLMEnabled {
                    Section("Prompt") {
                        TextEditor(text: $draft.prompt)
                            .font(.system(size: 13))
                            .frame(minHeight: 80)
                            .accessibilityLabel("Prompt-Text")
                        Text("Der Prompt wird dem Transkript vorangestellt und an Groq qwen3-32b gesendet.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                // 5. Aktionen — destruktive Aktion immer zuletzt (UI-SPEC)
                Section {
                    // D-13: "Als Standard markieren" — ausgegraut wenn bereits Standard
                    Button("Als Standard markieren") {
                        onSetDefault()
                        dismiss()
                    }
                    .disabled(draft.isDefault)
                    .accessibilityHint(draft.isDefault ? "Dieses Profil ist bereits als Standard markiert." : "")

                    // D-06: Loeschen ausgegraut wenn letztes Profil
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Text("Profil löschen")
                    }
                    .disabled(isOnlyProfile)
                    .accessibilityHint(isOnlyProfile ? "Kann nicht gelöscht werden, da es das letzte Profil ist." : "")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(draft.name.trimmingCharacters(in: .whitespaces).isEmpty
                ? "Neues Profil" : draft.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Profil sichern") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(width: 420, height: 460)
    }
}
