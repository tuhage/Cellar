import SwiftUI

/// A small capsule with a count — updates in the sidebar, running
/// operations on the toolbar icon.
struct CountBadge: View {
    enum Style {
        /// Colored text on a light tint; for lists.
        case tinted
        /// White text on solid color; for overlays on icons.
        case filled
    }

    let count: Int
    let tint: Color
    var style: Style = .tinted

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Text(count, format: .number)
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(style == .filled ? .white : tint)
            .smallBadgeInset()
            .background(background, in: Capsule())
    }

    private var background: Color {
        switch style {
        case .filled: tint
        case .tinted: tint.opacity(contrast == .increased ? 0.28 : Opacity.badgeBackground)
        }
    }
}

#Preview {
    HStack {
        CountBadge(count: 5, tint: .orange)
        CountBadge(count: 2, tint: .red, style: .filled)
    }
    .padding()
}
