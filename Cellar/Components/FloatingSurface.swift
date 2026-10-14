import SwiftUI

extension View {
    /// Background for UI that floats over content — notices, Quick Open:
    /// Liquid Glass on macOS 26, a material with a hairline and shadow before.
    @ViewBuilder
    func floatingSurface(cornerRadius: CGFloat = CornerRadius.card) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(.primary.opacity(Opacity.subtleBorder)))
                .shadow(color: Shadow.elevatedColor, radius: Shadow.elevatedBlur, y: Shadow.elevatedY)
        }
    }
}
