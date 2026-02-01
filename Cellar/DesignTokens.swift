import SwiftUI

// MARK: - Spacing

nonisolated enum Spacing {
    /// 0 pt — Divider-separated stacked groups
    static let none: CGFloat = 0
    /// 2 pt — Title/subtitle pairs, tight vertical gaps
    static let textPair: CGFloat = 2
    /// 3 pt — Badge vertical padding
    static let badgeVertical: CGFloat = 3
    /// 4 pt — Very close elements
    static let compact: CGFloat = 4
    /// 6 pt — Badge groups, flow layout, tag rows
    static let related: CGFloat = 6
    /// 8 pt — Component inner spacing
    static let item: CGFloat = 8
    /// 10 pt — List row inner spacing
    static let row: CGFloat = 10
    /// 12 pt — Section contents, grid gaps
    static let sectionContent: CGFloat = 12
    /// 14 pt — Detail header, stat card inner spacing
    static let detailElement: CGFloat = 14
    /// 16 pt — Card inner padding, overlays
    static let cardPadding: CGFloat = 16
    /// 24 pt — Top-level section separation, content area padding
    static let section: CGFloat = 24
}

// MARK: - CornerRadius

nonisolated enum CornerRadius {
    /// 3 pt — Progress bar segments
    static let progressBar: CGFloat = 3
    /// 4 pt — CPU bar, clip shapes
    static let minimal: CGFloat = 4
    /// 6 pt — Chips, dependency tags, small icon backgrounds
    static let small: CGFloat = 6
    /// 8 pt — Stat card icon background, shortcut key boxes
    static let medium: CGFloat = 8
    /// 10 pt — Quick action buttons, banners, profile headers
    static let card: CGFloat = 10
    /// 12 pt — Stat cards, disk overview cards
    static let large: CGFloat = 12
    /// 16 pt — Modal overlays
    static let extraLarge: CGFloat = 16
}

// MARK: - IconSize

nonisolated enum IconSize {
    /// 8 pt — Status dots (Circle)
    static let statusDot: CGFloat = 8
    /// 10 pt — Larger status indicators
    static let indicator: CGFloat = 10
    /// 14 pt — Animated glow overlay
    static let dotGlow: CGFloat = 14
    /// 20 pt — List row icon column width
    static let iconColumn: CGFloat = 20
    /// 28 pt — Quick action, dependency node icons
    static let smallIcon: CGFloat = 28
    /// 36 pt — Stat card icons
    static let mediumIcon: CGFloat = 36
    /// 40 pt — Disk overview icons
    static let largeIcon: CGFloat = 40
    /// 44 pt — Detail view header icons
    static let headerIcon: CGFloat = 44
}

// MARK: - View Modifiers

extension View {
    /// Padding for list rows: vertical 6, horizontal 4
    func listRowInset() -> some View {
        self
            .padding(.vertical, Spacing.related)
            .padding(.horizontal, Spacing.compact)
    }

    /// Padding for status badges: horizontal 8, vertical 3
    func badgeInset() -> some View {
        self
            .padding(.horizontal, Spacing.item)
            .padding(.vertical, Spacing.badgeVertical)
    }

    /// Padding for dependency/tag chips: horizontal 8, vertical 4
    func chipInset() -> some View {
        self
            .padding(.horizontal, Spacing.item)
            .padding(.vertical, Spacing.compact)
    }

    /// Padding for small badges: horizontal 6, vertical 2
    func smallBadgeInset() -> some View {
        self
            .padding(.horizontal, Spacing.related)
            .padding(.vertical, Spacing.textPair)
    }

    /// Card background with subtle shadow and thin border
    func cardStyle(cornerRadius: CGFloat = CornerRadius.large) -> some View {
        self
            .background(.quaternary, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.primary.opacity(Opacity.subtleBorder), lineWidth: 0.5)
            )
            .shadow(color: Shadow.cardColor, radius: Shadow.cardBlur, y: Shadow.cardY)
    }

    /// Elevated card background with stronger shadow — used for hover states
    func elevatedCardStyle(cornerRadius: CGFloat = CornerRadius.large) -> some View {
        self
            .background(.quaternary, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.primary.opacity(Opacity.subtleBorder), lineWidth: 0.5)
            )
            .shadow(color: Shadow.elevatedColor, radius: Shadow.elevatedBlur, y: Shadow.elevatedY)
    }
}

// MARK: - Shadow

nonisolated enum Shadow {
    /// Card shadow: blur 8, y 2, 6% opacity
    static let cardBlur: CGFloat = 8
    static let cardY: CGFloat = 2
    static let cardColor: Color = .black.opacity(0.06)

    /// Elevated shadow: blur 16, y 4, 10% opacity
    static let elevatedBlur: CGFloat = 16
    static let elevatedY: CGFloat = 4
    static let elevatedColor: Color = .black.opacity(0.10)

    /// Subtle shadow: blur 4, y 1, 4% opacity
    static let subtleBlur: CGFloat = 4
    static let subtleY: CGFloat = 1
    static let subtleColor: Color = .black.opacity(0.04)
}

// MARK: - AnimationToken

nonisolated enum AnimationToken {
    /// Interactive spring: 0.3s, bounce 0.15 — buttons, hovers
    static let interactive: Animation = .spring(duration: 0.3, bounce: 0.15)
    /// Smooth spring: 0.4s — layout transitions
    static let smooth: Animation = .spring(duration: 0.4)
    /// Snap spring: 0.2s, bounce 0.2 — quick pops, numeric transitions
    static let snap: Animation = .spring(duration: 0.2, bounce: 0.2)
    /// Gentle ease: 0.3s — fades, opacity changes
    static let gentle: Animation = .easeInOut(duration: 0.3)
    /// Stagger delay between items
    static let staggerDelay: Double = 0.05
}

// MARK: - Opacity

nonisolated enum Opacity {
    /// Background tint for icon containers
    static let iconBackground: Double = 0.12
    /// Background tint for badge capsules
    static let badgeBackground: Double = 0.12
    /// Hover overlay tint
    static let hoverOverlay: Double = 0.04
    /// Pressed overlay tint
    static let pressedOverlay: Double = 0.08
    /// Thin border stroke
    static let subtleBorder: Double = 0.08
}

// MARK: - HoverableCardButtonStyle

/// A button style that elevates shadow on hover and scales down on press.
struct HoverableCardButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : isHovered ? 1.01 : 1.0)
            .shadow(
                color: isHovered ? Shadow.elevatedColor : Shadow.cardColor,
                radius: isHovered ? Shadow.elevatedBlur : Shadow.cardBlur,
                y: isHovered ? Shadow.elevatedY : Shadow.cardY
            )
            .brightness(isHovered ? 0.02 : 0)
            .animation(AnimationToken.interactive, value: configuration.isPressed)
            .animation(AnimationToken.interactive, value: isHovered)
            .onHover { isHovered = $0 }
    }
}
