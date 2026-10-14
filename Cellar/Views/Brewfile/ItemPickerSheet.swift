import SwiftUI

/// A searchable checklist for picking services or packages to add, instead
/// of typing names that may not exist.
struct ItemPickerSheet: View {
    struct Item: Identifiable, Hashable {
        let id: String
        var detail: String?
    }

    let title: String
    let items: [Item]
    let emptyMessage: String
    let onAdd: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selection: Set<String> = []

    private var filteredItems: [Item] {
        guard !searchText.isEmpty else { return items }
        return items.filter {
            $0.id.localizedCaseInsensitiveContains(searchText)
                || ($0.detail?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionContent) {
            Text(title)
                .font(.headline)

            TextField("Search", text: $searchText, prompt: Text("Search"))
                .textFieldStyle(.roundedBorder)

            list
                .frame(minHeight: WindowSize.mediumSheetHeight / 2, maxHeight: WindowSize.mediumSheetHeight)

            HStack {
                Text(selection.isEmpty ? "" : "\(selection.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(selection.isEmpty ? "Add" : "Add \(selection.count)") {
                    onAdd(items.map(\.id).filter(selection.contains))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection.isEmpty)
            }
        }
        .padding(Spacing.section)
        .frame(width: WindowSize.mediumSheet)
    }

    @ViewBuilder
    private var list: some View {
        if items.isEmpty {
            EmptyStateView(title: emptyMessage, systemImage: "tray")
        } else if filteredItems.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            List(filteredItems) { item in
                Toggle(isOn: isSelected(item)) {
                    VStack(alignment: .leading, spacing: Spacing.textPair) {
                        Text(item.id)
                        if let detail = item.detail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .toggleStyle(.checkbox)
            }
            .listStyle(.bordered)
        }
    }

    private func isSelected(_ item: Item) -> Binding<Bool> {
        Binding(
            get: { selection.contains(item.id) },
            set: { isOn in
                if isOn { selection.insert(item.id) } else { selection.remove(item.id) }
            }
        )
    }
}

#Preview {
    ItemPickerSheet(
        title: "Add Services to My Web App",
        items: [
            .init(id: "postgresql@16", detail: "Running"),
            .init(id: "redis", detail: "Stopped"),
            .init(id: "mysql", detail: "Stopped"),
        ],
        emptyMessage: "No Services"
    ) { _ in }
}
