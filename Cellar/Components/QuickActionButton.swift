import SwiftUI

/// A button styled for quick-action grids in Dashboard and Brewfile views.
///
/// Displays an icon in a colored rounded square, a title, and a subtitle.
/// Automatically dims and disables when `isDisabled` is true.
struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.row) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: IconSize.smallIcon, height: IconSize.smallIcon)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.medium))

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(Spacing.row)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(QuickActionButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

// MARK: - Button Style

private struct QuickActionButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .cardStyle(cornerRadius: CornerRadius.card)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .brightness(configuration.isPressed ? -0.02 : isHovered ? 0.02 : 0)
            .shadow(
                color: isHovered ? Shadow.elevatedColor : .clear,
                radius: isHovered ? Shadow.elevatedBlur : 0,
                y: isHovered ? Shadow.elevatedY : 0
            )
            .contentShape(RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
            .animation(AnimationToken.interactive, value: configuration.isPressed)
            .animation(AnimationToken.interactive, value: isHovered)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: Spacing.sectionContent) {
        QuickActionButton(
            title: "Upgrade All",
            subtitle: "3 available",
            systemImage: "arrow.up.circle.fill",
            color: .orange,
            action: {}
        )

        QuickActionButton(
            title: "Cleanup",
            subtitle: "Free disk space",
            systemImage: "trash.circle.fill",
            color: .red,
            isDisabled: true,
            action: {}
        )
    }
    .padding()
    .frame(width: 500)
}
