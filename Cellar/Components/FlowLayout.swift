import SwiftUI

/// A horizontal wrapping layout for tags, badges, and chips.
///
/// Items flow left-to-right and wrap to the next line when they
/// exceed the available width. Used for dependency lists, filter
/// chips, and badge collections.
struct FlowLayout: Layout {
    var spacing: CGFloat = Spacing.item

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return ArrangeResult(
            positions: positions,
            size: CGSize(width: totalWidth, height: currentY + lineHeight)
        )
    }

    private struct ArrangeResult {
        let positions: [CGPoint]
        let size: CGSize
    }
}

#Preview {
    FlowLayout(spacing: Spacing.related) {
        ForEach(["openssl@3", "readline", "sqlite3", "xz", "zlib", "libyaml", "gmp"], id: \.self) { dep in
            Text(dep)
                .font(.callout)
                .fontDesign(.monospaced)
                .chipInset()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: CornerRadius.small))
        }
    }
    .padding()
    .frame(width: 300)
}
