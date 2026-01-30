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
                            Label(item.title, systemImage: item.icon)
                                .badge(badge(for: item))
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

    private func badge(for item: SidebarItem) -> Int {
        switch item {
        case .outdated:
            packageStore.totalOutdated
        case .services:
            serviceStore.runningCount
        default:
            0
        }
    }
}

#Preview {
    @Previewable @State var selection: SidebarItem? = .dashboard
    NavigationSplitView {
        SidebarView(selection: $selection)
            .environment(PackageStore())
            .environment(ServiceStore())
    } detail: {
        Text(selection?.title ?? "Select an item")
    }
}
