import SwiftUI

/// A tinted strip across the top of a page for status that needs the
/// user's attention — failures, pending restarts, running operations.
/// Stack several in `.safeAreaInset(edge: .top)`; each draws its own divider.
struct NoticeBanner<Content: View, Actions: View>: View {
    let tint: Color
    let systemImage: String
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    var body: some View {
        HStack(spacing: Spacing.sectionContent) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            content
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Spacing.item) {
                actions
            }
            .controlSize(.small)
        }
        .padding(.horizontal, Spacing.cardPadding)
        .padding(.vertical, Spacing.row)
        .background(tint.opacity(Opacity.bannerBackground))
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .contain)
    }
}

extension NoticeBanner where Content == NoticeText {
    init(
        tint: Color,
        systemImage: String,
        title: String,
        message: String? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.init(tint: tint, systemImage: systemImage) {
            NoticeText(title: title, message: message)
        } actions: {
            actions()
        }
    }
}

/// Title and optional secondary line of a `NoticeBanner`.
struct NoticeText: View {
    let title: String
    var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.textPair) {
            Text(title)
                .font(.callout.weight(.medium))
                .lineLimit(2)
            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

// MARK: - Load Error

/// Shown when a refresh failed but older data is still on screen, so the
/// failure isn't swallowed.
struct LoadErrorBanner: View {
    let message: String
    let lastUpdated: Date?
    let retry: () async -> Void

    var body: some View {
        NoticeBanner(tint: .red, systemImage: "exclamationmark.triangle.fill") {
            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Text(message)
                    .font(.callout.weight(.medium))
                if let lastUpdated {
                    Text("Showing data from \(lastUpdated, style: .relative) ago.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } actions: {
            Button("Try Again") {
                Task { await retry() }
            }
        }
    }
}

extension View {
    /// Shows a `LoadErrorBanner` above the content when `store` failed to
    /// refresh but still has earlier data.
    func loadErrorBanner(for store: some LoadableStore, retry: @escaping () async -> Void) -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            if let message = store.errorMessage, store.lastUpdated != nil {
                LoadErrorBanner(message: message, lastUpdated: store.lastUpdated, retry: retry)
            }
        }
    }

    /// "Updated 2 minutes ago" under the window title.
    func dataFreshness(_ lastUpdated: Date?) -> some View {
        navigationSubtitle(lastUpdated.map { Text("Updated \($0, style: .relative) ago") } ?? Text(""))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        NoticeBanner(
            tint: .blue,
            systemImage: "arrow.clockwise.circle.fill",
            title: "postgresql@17 is still running the previous version",
            message: "Upgraded while running. Restart to use the new version."
        ) {
            Button("Restart") {}
        }
        LoadErrorBanner(message: "Services couldn’t be loaded.", lastUpdated: .now.addingTimeInterval(-300)) {}
    }
    .frame(width: 640)
}
