import SwiftUI
import CellarCore

struct SidebarView: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarSection.allCases) { section in
                let items = SidebarItem.items(for: section)
                if !items.isEmpty {
                    Section(section.title) {
                        ForEach(items) { item in
                            Label(item.title, systemImage: item.icon)
                                .tag(item)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Cellar")
    }
}

#Preview {
    @Previewable @State var selection: SidebarItem? = .dashboard
    NavigationSplitView {
        SidebarView(selection: $selection)
    } detail: {
        Text(selection?.title ?? "Select an item")
    }
}
