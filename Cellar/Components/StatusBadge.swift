import SwiftUI

/// A tinted capsule with a short status label, such as "Installed" or
/// "Official", and an optional icon.
struct StatusBadge: View {
    let text: String
    let color: Color
    var icon: String?
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Group {
            if let icon {
                Label(text, systemImage: icon)
            } else {
                Text(text)
            }
        }
        .font(.caption2.weight(.semibold))
        .smallBadgeInset()
        .background(
            color.opacity(contrast == .increased ? 0.24 : Opacity.badgeBackground),
            in: Capsule()
        )
        .overlay(Capsule().strokeBorder(color.opacity(contrast == .increased ? 0.7 : 0.18), lineWidth: contrast == .increased ? 1 : 0.5))
        .foregroundStyle(color)
        .transition(.scale.combined(with: .opacity))
        .help(text)
    }
}

#Preview {
    HStack(spacing: Spacing.item) {
        StatusBadge(text: "Outdated", color: .orange)
        StatusBadge(text: "Pinned", color: .blue, icon: "pin.fill")
        StatusBadge(text: "Deprecated", color: .red, icon: "exclamationmark.triangle")
        StatusBadge(text: "Leaf", color: .green)
        StatusBadge(text: "Orphan", color: .orange)
    }
    .padding()
}
