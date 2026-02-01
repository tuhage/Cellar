import SwiftUI

// MARK: - Spacing

nonisolated enum Spacing {
    /// 0 pt — Divider-separated stacked groups
    static let none: CGFloat = 0
    /// 2 pt — Title + subtitle VStack pairs
    static let textPair: CGFloat = 2
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
    /// Padding for list rows: vertical 6 + horizontal 4
    func listRowInset() -> some View {
        self
            .padding(.vertical, Spacing.related)
            .padding(.horizontal, Spacing.compact)
    }

    /// Padding for status badges: horizontal 8 + vertical 3
    func badgeInset() -> some View {
        self
            .padding(.horizontal, Spacing.item)
            .padding(.vertical, 3)
    }

    /// Padding for dependency/tag chips: horizontal 8 + vertical 4
    func chipInset() -> some View {
        self
            .padding(.horizontal, Spacing.item)
            .padding(.vertical, Spacing.compact)
    }

    /// Padding for small badges: horizontal 6 + vertical 2
    func smallBadgeInset() -> some View {
        self
            .padding(.horizontal, Spacing.related)
            .padding(.vertical, 2)
    }
}
