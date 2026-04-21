// VoiceScribe/History/HistoryView.swift
// History-Fenster: Listenzeilen, Live-Suche, Copy-Flash, Delete.
// Implementiert HIST-03 (FTS5-Suche D-06), HIST-04 (Clipboard D-09, D-10),
// T6-DELETE (Confirm-Dialog D-12).
// Quellen: UI-SPEC §4-13; RESEARCH.md Pattern 4, 7, 8; PATTERNS.md HistoryView.

import SwiftUI
import AppKit  // NSPasteboard
import Accessibility  // AccessibilityNotification

// MARK: - HistoryView

struct HistoryView: View {
    @State private var searchText: String = ""
    @State private var entries: [HistoryEntry] = []
    @State private var flashingEntryID: Int64? = nil
    @State private var showClearConfirm: Bool = false
    @State private var debounceTask: Task<Void, Never>? = nil
    private let historyStore = HistoryStore.shared

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar-Bereich: Suchfeld + Verlauf-leeren-Button (UI-SPEC §5)
            HStack(spacing: DesignTokens.Spacing.sm) {
                TextField("Verlauf durchsuchen…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Verlauf durchsuchen")

                Button("Verlauf leeren…") {
                    showClearConfirm = true
                }
                .accessibilityLabel("Verlauf leeren")
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)

            Divider()

            // Hauptinhalt: Liste oder Leer-Zustand
            if entries.isEmpty && searchText.isEmpty {
                // Leer-Zustand A: noch keine Einträge (UI-SPEC §9.3)
                emptyStateA
            } else if entries.isEmpty && !searchText.isEmpty {
                // Leer-Zustand B: Suche ohne Treffer (UI-SPEC §9.4)
                emptyStateB
            } else {
                // Normale Liste mit Datum-Sektionen (D-05)
                List {
                    ForEach(groupedEntries, id: \.0) { (sectionTitle, sectionEntries) in
                        Section(sectionTitle) {
                            ForEach(sectionEntries) { entry in
                                HistoryRowView(
                                    entry: entry,
                                    isFlashing: flashingEntryID == entry.id
                                )
                                .contentShape(Rectangle())
                                .onTapGesture { copyEntry(entry) }
                                .contextMenu {
                                    // T6-DELETE (Einzellöschen): Kontextmenü statt onDelete
                                    // (macOS SwiftUI List.onDelete erfordert Edit-Mode — Pitfall 5)
                                    Button("Eintrag löschen", role: .destructive) {
                                        try? historyStore.delete(entry)
                                    }
                                }
                                .accessibilityLabel(accessibilityLabel(for: entry))
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        // T6-DELETE: Confirm-Dialog für Gesamt-Löschen (D-12)
        .alert("Verlauf leeren?", isPresented: $showClearConfirm) {
            Button("Löschen", role: .destructive) {
                try? historyStore.deleteAll()
                entries = []
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle Einträge werden unwiderruflich gelöscht.")
        }
        // ValueObservation: task(id:) bricht automatisch ab wenn View entfernt wird (Pitfall 7)
        .task(id: searchText.isEmpty) {
            if searchText.isEmpty {
                do {
                    for try await updated in historyStore.observeAll() {
                        entries = updated
                    }
                } catch { /* Observation-Fehler still schlucken */ }
            }
        }
        // Debounce für Suche (D-06: 200ms — Task.sleep-Pattern, kein Combine)
        .onChange(of: searchText) { _, newValue in
            debounceTask?.cancel()
            if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                // Leer → zurück zur Observation (task(id:) übernimmt)
                return
            }
            debounceTask = Task {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                entries = (try? historyStore.search(query: newValue)) ?? []
            }
        }
    }

    // MARK: - Leer-Zustände

    private var emptyStateA: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "clock")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Noch keine Einträge")
                .font(.system(size: 16, weight: .semibold))
            Text("Transkriptionen werden hier gespeichert, sobald du diktierst.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateB: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Keine Ergebnisse")
                .font(.system(size: 16, weight: .semibold))
            // UI-SPEC §9.4: typografische Anführungszeichen „…" (U+201E öffnend, U+201C schließend)
            Text("Keine Eintr\u{00E4}ge f\u{00FC}r \u{201E}\(searchText)\u{201C} gefunden.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(DesignTokens.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Datum-Gruppierung (D-05)

    /// Einträge nach Tagesdatum gruppiert, neueste Sektion zuerst.
    private var groupedEntries: [(String, [HistoryEntry])] {
        let calendar = Calendar.current
        // Dictionary grouping (entries sind bereits ORDER BY created_at DESC)
        let grouped = Dictionary(grouping: entries) { entry -> String in
            if calendar.isDateInToday(entry.createdAt) { return "HEUTE" }
            if calendar.isDateInYesterday(entry.createdAt) { return "GESTERN" }
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy"
            return formatter.string(from: calendar.startOfDay(for: entry.createdAt))
        }
        // Sektionen nach neuestem Eintrag in der Gruppe sortieren (D-05: neueste zuerst)
        return grouped.sorted { a, b in
            let dateA = a.value.first?.createdAt ?? .distantPast
            let dateB = b.value.first?.createdAt ?? .distantPast
            return dateA > dateB
        }
    }

    // MARK: - Copy-Feedback (D-09, D-10)

    private func copyEntry(_ entry: HistoryEntry) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.copyText, forType: .string)
        withAnimation(.easeOut(duration: 0.4)) {
            flashingEntryID = entry.id
        }
        // UI-SPEC §12: Accessibility-Announcement nach Kopieren
        AccessibilityNotification.Announcement("Kopiert").post()
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeOut(duration: 0.4)) {
                flashingEntryID = nil
            }
        }
    }

    // MARK: - Accessibility

    private func accessibilityLabel(for entry: HistoryEntry) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: entry.createdAt)
        let llm = entry.isLLMProcessed ? ", KI-verarbeitet" : ""
        let profile = entry.profileName.map { ", Profil: \($0)" } ?? ""
        return "\(time), \(entry.preview)\(profile)\(llm). Tippen zum Kopieren."
    }
}

// MARK: - HistoryRowView

/// Kompakte Listenzeile: Zeit + 80-Zeichen-Vorschau + optionaler Profilname + optionales KI-Badge.
/// Hintergrundfarbe blinkt grün wenn isFlashing (D-10).
struct HistoryRowView: View {
    let entry: HistoryEntry
    let isFlashing: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            // Zeitstempel (UI-SPEC §6: 11pt, monospacedDigit, secondary, min-width 32pt)
            Text(timeString)
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 32, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                // Vorschautext (UI-SPEC §6: 13pt, max 80 Zeichen + "…", 1 Zeile)
                Text(entry.preview)
                    .font(.system(size: 13))
                    .lineLimit(1)

                // Metadaten-Zeile: Profilname + KI-Badge
                HStack(spacing: DesignTokens.Spacing.xs) {
                    if let profileName = entry.profileName {
                        Text(profileName)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if entry.isLLMProcessed {
                        // KI-Badge (UI-SPEC §6: 10pt semibold, systemPurple, cornerRadius 4, Padding xs)
                        Text("KI")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                            .background(Color(.systemPurple))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .accessibilityLabel("KI-verarbeitet")
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        // D-10: Grün-Flash (UI-SPEC §9.5: systemGreen 30% opacity, easeOut 0.4s)
        .background(isFlashing ? Color(.systemGreen).opacity(0.3) : Color.clear)
        .animation(.easeOut(duration: 0.4), value: isFlashing)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: entry.createdAt)
    }
}
