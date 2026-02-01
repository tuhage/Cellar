import SwiftUI

/// A consistent section header with icon, title, and optional trailing content.
///
/// Used across Dashboard, Outdated, Search, Health, and other views
/// to provide uniform section labeling.
struct SectionHeaderView<Trailing: View>: View {
    let title: String
    let systemImage: String
    var color: Color = .primary
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: Spacing.item) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: IconSize.smallIcon, height: IconSize.smallIcon)
                .background(color.opacity(Opacity.iconBackground), in: Circle())

            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()

            trailing()
        }
    }
}

extension SectionHeaderView where Trailing == EmptyView {
    init(title: String, systemImage: String, color: Color = .primary) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.trailing = { EmptyView() }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        SectionHeaderView(title: "Quick Actions", systemImage: "bolt.fill", color: .blue)

        SectionHeaderView(title: "Outdated Packages", systemImage: "arrow.triangle.2.circlepath", color: .orange) {
            Text("7 updates available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        SectionHeaderView(title: "Formulae", systemImage: "terminal", color: .blue) {
            StatusBadge(text: "12", color: .blue)
        }
    }
    .padding()
    .frame(width: 500)
}
