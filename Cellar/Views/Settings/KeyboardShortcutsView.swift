import SwiftUI

/// Displays all available keyboard shortcuts grouped by category.
///
/// Opened from the Help menu via "Keyboard Shortcuts" or through
/// the `Window` scene with identifier `"keyboard-shortcuts"`.
struct KeyboardShortcutsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                header

                ShortcutSection(title: "General", systemImage: "command", shortcuts: [
                    Shortcut(keys: "\u{2318},", description: "Open Settings"),
                    Shortcut(keys: "\u{2318}W", description: "Close Window"),
                    Shortcut(keys: "\u{2318}Q", description: "Quit Cellar"),
                ])

                ShortcutSection(title: "Packages", systemImage: "shippingbox", shortcuts: [
                    Shortcut(keys: "\u{2318}R", description: "Refresh All"),
                    Shortcut(keys: "\u{21E7}\u{2318}U", description: "Upgrade All"),
                    Shortcut(keys: "\u{21E7}\u{2318}K", description: "Cleanup"),
                ])

                ShortcutSection(title: "Services", systemImage: "gear", shortcuts: [
                    Shortcut(keys: "\u{2325}\u{2318}R", description: "Refresh Services"),
                ])

                ShortcutSection(title: "Navigation", systemImage: "sidebar.left", shortcuts: [
                    Shortcut(keys: "\u{2318}1\u{2013}\u{2318}9", description: "Switch Sidebar Section"),
                    Shortcut(keys: "\u{2318}F", description: "Search (when available)"),
                ])
            }
            .padding(Spacing.section)
        }
        .frame(width: 420, height: 460)
        .background(.background)
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.compact) {
            Text("Keyboard Shortcuts")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Quick reference for all available shortcuts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Shortcut Model

private struct Shortcut: Identifiable {
    let id = UUID()
    let keys: String
    let description: String
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
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
        }
        .padding(.horizontal, Spacing.sectionContent)
        .padding(.vertical, Spacing.item)
    }
}

// MARK: - Preview

#Preview {
    KeyboardShortcutsView()
}
