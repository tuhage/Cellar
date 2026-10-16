import SwiftUI

/// The in-window notice for the latest finished operation. Successes fade
/// after a few seconds (not while hovered); failures stay until dismissed.
struct OperationNoticeView: View {
    let notice: OperationNotice

    @Environment(NoticeStore.self) private var noticeStore

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sectionContent) {
            Image(systemName: notice.status.symbolName)
                .font(.title3)
                .foregroundStyle(notice.status.color)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Text(notice.title)
                    .font(.subheadline.weight(.semibold))
                if let message = notice.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Details") {
                ActivityPanel.show()
                noticeStore.dismiss()
            }
            .buttonStyle(.borderless)
            .controlSize(.small)

            Button {
                noticeStore.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
            .accessibilityLabel("Dismiss")
        }
        .padding(Spacing.cardPadding)
        .frame(maxWidth: WindowSize.narrowWidth)
        .floatingSurface()
        .onHover { noticeStore.setHovering($0) }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Placement

/// The notice sliding in at the top center of the space it's given.
private struct OperationNoticeSlot: View {
    @Environment(NoticeStore.self) private var noticeStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let notice = noticeStore.current {
                OperationNoticeView(notice: notice)
                    .padding(.horizontal, Spacing.section)
                    .padding(.top, Spacing.sectionContent)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : AnimationToken.smooth, value: noticeStore.current)
    }
}

/// Whether a page shows the notice itself.
nonisolated private struct ShowsOperationNoticeKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    /// Shows the notice over this page content. A page with an inspector
    /// uses it (through `PageInspector`) so the notice centers beside the
    /// inspector instead of spanning both columns.
    func operationNotice() -> some View {
        overlay(alignment: .top) { OperationNoticeSlot() }
            .preference(key: ShowsOperationNoticeKey.self, value: true)
    }

    /// Shows the notice over the detail column, unless its page shows it.
    func defaultOperationNotice() -> some View {
        overlayPreferenceValue(ShowsOperationNoticeKey.self, alignment: .top) { pageShowsNotice in
            if !pageShowsNotice {
                OperationNoticeSlot()
            }
        }
    }
}

#Preview {
    OperationNoticeView(notice: OperationNotice(operation: BrewOperation.previewList[2]))
        .environment(AppStores())
        .padding()
}
