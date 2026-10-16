import SwiftUI

extension View {
    /// The prominent button style: Liquid Glass on macOS 26. In an inspector
    /// on macOS 27, a tinted `.borderedProminent` renders washed out (orange
    /// turns pale yellow under its white label); `.glassProminent` keeps the tint.
    @ViewBuilder
    func prominentButtonStyle() -> some View {
        if #available(macOS 26, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }
}
