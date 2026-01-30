import SwiftUI
import CellarCore

// MARK: - HistoryView

/// Displays a timeline of Homebrew actions performed through the app.
///
/// Features filter chips for event types, a searchable list grouped by
/// relative date (Today, Yesterday, This Week, Older), and a toolbar
/// button to clear all history.
struct HistoryView: View {
    @Environment(HistoryStore.self) private var store
    @State private var showClearConfirmation = false

    var body: some View {
        @Bindable var store = store

        Group {
            if store.isLoading && store.events.isEmpty {
                LoadingView(message: "Loading history\u{2026}")
            } else if let errorMessage = store.errorMessage, store.events.isEmpty {
                ErrorView(message: errorMessage) {
                    store.load()
                }
            } else if store.events.isEmpty {
                EmptyStateView(
                    title: "No History",
                    systemImage: "clock.arrow.counterclockwise",
                    description: "Actions you perform in Cellar will appear here."
                )
            } else if store.filteredEvents.isEmpty {
                EmptyStateView(
                    title: "No Results",
                    systemImage: "magnifyingglass",
                    description: "No history events match your current filters."
                )
            } else {
                historyContent
            }
        }
        .navigationTitle("History")
        .searchable(text: $store.searchQuery, prompt: "Search history")
        .toolbar { toolbarContent }
        .confirmationDialog(
            "Clear History",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All History", role: .destructive) {
                store.clearHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove all history events. This action cannot be undone.")
        }
        .task { store.load() }
    }

    // MARK: - Content

    private var historyContent: some View {
        VStack(spacing: 0) {
            filterChips
            Divider()
            eventList
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    isSelected: store.filterType == nil
                ) {
                    store.filterType = nil
                }

                ForEach(HistoryEventType.allCases, id: \.self) { eventType in
                    FilterChip(
                        title: eventType.title,
                        icon: eventType.icon,
                        color: eventType.color,
                        isSelected: store.filterType == eventType
                    ) {
                        store.filterType = eventType
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Event List

    private var eventList: some View {
        let grouped = groupedEvents

        return List {
            ForEach(grouped, id: \.label) { group in
                Section {
                    ForEach(group.events) { event in
                        HistoryEventRow(event: event)
                    }
                } header: {
                    Text(group.label)
                }
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Grouping

    /// Groups filtered events by relative date: Today, Yesterday, This Week, Older.
    private var groupedEvents: [EventGroup] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday),
              let startOfWeek = calendar.date(byAdding: .day, value: -7, to: startOfToday)
        else {
            return [EventGroup(label: "All", events: store.filteredEvents)]
        }

        var today: [HistoryEvent] = []
        var yesterday: [HistoryEvent] = []
        var thisWeek: [HistoryEvent] = []
        var older: [HistoryEvent] = []

        for event in store.filteredEvents {
            if event.timestamp >= startOfToday {
                today.append(event)
            } else if event.timestamp >= startOfYesterday {
                yesterday.append(event)
            } else if event.timestamp >= startOfWeek {
                thisWeek.append(event)
            } else {
                older.append(event)
            }
        }

        var groups: [EventGroup] = []
        if !today.isEmpty { groups.append(EventGroup(label: "Today", events: today)) }
        if !yesterday.isEmpty { groups.append(EventGroup(label: "Yesterday", events: yesterday)) }
        if !thisWeek.isEmpty { groups.append(EventGroup(label: "This Week", events: thisWeek)) }
        if !older.isEmpty { groups.append(EventGroup(label: "Older", events: older)) }

        return groups
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showClearConfirmation = true
            } label: {
                Label("Clear History", systemImage: "trash")
            }
            .disabled(store.events.isEmpty)
            .help("Clear all history")
        }
    }
}

// MARK: - EventGroup

/// A group of events sharing a relative date label.
private struct EventGroup {
    let label: String
    let events: [HistoryEvent]
}

// MARK: - FilterChip

/// A toggleable chip button used for filtering event types.
private struct FilterChip: View {
    let title: String
    var icon: String?
    var color: Color = .accentColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.15) : Color.clear, in: Capsule())
            .foregroundStyle(isSelected ? color : .secondary)
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? color.opacity(0.3) : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - HistoryEventRow

/// A single row in the history list showing event icon, package name, summary, and timestamp.
private struct HistoryEventRow: View {
    let event: HistoryEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.eventType.icon)
                .font(.title3)
                .foregroundStyle(event.eventType.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.packageName)
                    .fontWeight(.medium)

                Text(event.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let details = event.details {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(event.timestamp, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HistoryView()
    }
    .environment(HistoryStore())
    .frame(width: 700, height: 600)
}
