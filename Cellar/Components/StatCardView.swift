import SwiftUI
import CellarCore

struct StatCardView: View {
    let title: String
    let value: String
    let systemImage: String
    var color: Color = .accentColor

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Spacing.detailElement) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: IconSize.mediumIcon, height: IconSize.mediumIcon)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))

            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
                    .animation(AnimationToken.snap, value: value)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.detailElement)
        .cardStyle()
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .shadow(
            color: isHovered ? Shadow.elevatedColor : .clear,
            radius: isHovered ? Shadow.elevatedBlur : 0,
            y: isHovered ? Shadow.elevatedY : 0
        )
        .animation(AnimationToken.interactive, value: isHovered)
        .onHover { isHovered = $0 }
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.sectionContent) {
        StatCardView(title: "Formulae", value: "142", systemImage: "terminal", color: .blue)
        StatCardView(title: "Casks", value: "38", systemImage: "macwindow", color: .purple)
        StatCardView(title: "Services", value: "4/7", systemImage: "gearshape.2", color: .green)
        StatCardView(title: "Updates", value: "5", systemImage: "arrow.triangle.2.circlepath", color: .orange)
    }
    .padding()
    .frame(width: 500)
}
