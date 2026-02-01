import SwiftUI

/// A reusable capsule badge for displaying status labels.
///
/// Used across FormulaListView, CaskListView, DependencyGraphView,
/// PackageDetailView, and other views that show package/node status.
struct StatusBadge: View {
    let text: String
    let color: Color
    var icon: String?

    var body: some View {
        Group {
            if let icon {
                Label(text, systemImage: icon)
            } else {
                Text(text)
            }
        }
        .font(.caption)
        .fontWeight(.medium)
        .badgeInset()
        .background(color.opacity(Opacity.badgeBackground), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.2), lineWidth: 0.5))
        .foregroundStyle(color)
        .shadow(color: Shadow.subtleColor, radius: Shadow.subtleBlur, y: Shadow.subtleY)
        .transition(.scale.combined(with: .opacity))
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
