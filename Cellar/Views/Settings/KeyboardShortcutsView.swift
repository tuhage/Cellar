import SwiftUI

/// Every keyboard shortcut, generated from `AppShortcut` so it always
/// matches the menus. Opened from Help › Keyboard Shortcuts.
struct KeyboardShortcutsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                header

                ShortcutSection(title: "General", systemImage: "command", shortcuts: Self.generalShortcuts)

                ForEach(AppShortcut.Category.allCases, id: \.self) { category in
                    ShortcutSection(
                        title: category.rawValue,
                        systemImage: category.systemImage,
                        shortcuts: shortcuts(in: category)
                    )
                }
            }
            .padding(Spacing.section)
        }
        .frame(width: WindowSize.narrowWidth, height: 560)
        .background(.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.compact) {
            Text("Keyboard Shortcuts")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Commands act on the page and selection in the front window.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func shortcuts(in category: AppShortcut.Category) -> [Shortcut] {
        var shortcuts = AppShortcut.allCases
            .filter { $0.category == category }
            .map { Shortcut(keys: $0.symbols, description: $0.title) }
        if category == .navigation {
            shortcuts.append(Shortcut(keys: "\u{2318}1\u{2013}\u{2318}9", description: "Go to Sidebar Section"))
        }
        return shortcuts
    }

    /// System shortcuts every Mac app has.
    private static let generalShortcuts = [
        Shortcut(keys: "\u{2318},", description: "Settings"),
        Shortcut(keys: "\u{2318}/", description: "Keyboard Shortcuts"),
        Shortcut(keys: "\u{2318}F", description: "Search"),
        Shortcut(keys: "\u{2318}W", description: "Close Window"),
        Shortcut(keys: "\u{2318}Q", description: "Quit Cellar"),
    ]
}

// MARK: - Shortcut Model

private struct Shortcut: Identifiable {
    let keys: String
    let description: String

    var id: String { description }
}

// MARK: - Shortcut Section

private struct ShortcutSection: View {
    let title: String
    let systemImage: String
    let shortcuts: [Shortcut]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.item) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(shortcuts) { shortcut in
                    ShortcutRow(shortcut: shortcut)

                    if shortcut.id != shortcuts.last?.id {
                        Divider()
                    }
                }
            }
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
    }
}

// MARK: - Shortcut Row

private struct ShortcutRow: View {
    let shortcut: Shortcut

    var body: some View {
        HStack {
            Text(shortcut.description)
                .font(.body)

            Spacer()

            Text(shortcut.keys)
                .font(.body)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
                .badgeInset()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .padding(.horizontal, Spacing.sectionContent)
        .padding(.vertical, Spacing.item)
    }
}

// MARK: - Preview

#Preview {
    KeyboardShortcutsView()
}
