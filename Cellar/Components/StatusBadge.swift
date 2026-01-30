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
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
        .foregroundStyle(color)
    }
}

#Preview {
    HStack(spacing: 8) {
        StatusBadge(text: "Outdated", color: .orange)
        StatusBadge(text: "Pinned", color: .blue, icon: "pin.fill")
        StatusBadge(text: "Deprecated", color: .red, icon: "exclamationmark.triangle")
        StatusBadge(text: "Leaf", color: .green)
        StatusBadge(text: "Orphan", color: .orange)
    }
    .padding()
}
