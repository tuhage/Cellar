import SwiftUI
import CellarCore

struct SidebarView: View {
    @Binding var selection: SidebarItem?

    @Environment(PackageStore.self) private var packageStore
    @Environment(ServiceStore.self) private var serviceStore

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarSection.allCases) { section in
                let items = SidebarItem.items(for: section)
                if !items.isEmpty {
                    Section(section.title) {
                        ForEach(items) { item in
                            SidebarItemRow(item: item, badge: badge(for: item))
                                .tag(item)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollIndicators(.hidden)
        .navigationTitle("Cellar")
    }

    private func badge(for item: SidebarItem) -> SidebarBadge? {
        switch item {
        case .outdated:
            guard packageStore.totalOutdated > 0 else { return nil }
            return SidebarBadge(
                text: "\(packageStore.totalOutdated)",
                color: .orange,
                accessibilityLabel: "\(packageStore.totalOutdated) updates available"
            )
        case .services:
            let failureCount = serviceStore.services.filter(\.isError).count
            if failureCount > 0 {
                return SidebarBadge(
                    text: "\(failureCount)",
                    color: .red,
                    accessibilityLabel: "\(failureCount) services need attention"
                )
            }
            guard serviceStore.runningCount > 0 else { return nil }
            return SidebarBadge(
                text: "\(serviceStore.runningCount)",
                color: .green,
                accessibilityLabel: "\(serviceStore.runningCount) services running"
            )
        default:
            return nil
        }
    }
}

private struct SidebarBadge {
    let text: String
    let color: Color
    let accessibilityLabel: String
}

private struct SidebarItemRow: View {
    let item: SidebarItem
    let badge: SidebarBadge?
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: Spacing.item) {
            Label(item.title, systemImage: item.icon)
            Spacer(minLength: Spacing.compact)
            if let badge {
                Text(badge.text)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(badge.color)
                    .padding(.horizontal, Spacing.related)
                    .padding(.vertical, 1)
                    .background(badge.color.opacity(contrast == .increased ? 0.28 : 0.14), in: Capsule())
                    .accessibilityLabel(badge.accessibilityLabel)
            }
        }
    }
}

#Preview {
    @Previewable @State var selection: SidebarItem? = .dashboard
    NavigationSplitView {
        SidebarView(selection: $selection)
            .environment(PackageStore())
            .environment(ServiceStore())
            .environment(TapStore())
    } detail: {
        Text(selection?.title ?? "Select an item")
    }
}
