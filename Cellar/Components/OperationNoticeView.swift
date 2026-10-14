import SwiftUI

/// The in-window notice for the latest finished operation. Successes fade
/// after a few seconds (not while hovered); failures stay until dismissed.
struct OperationNoticeView: View {
    let notice: OperationNotice

    @Environment(NoticeStore.self) private var noticeStore

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sectionContent) {
            Image(systemName: notice.outcome.systemImage)
                .font(.title3)
                .foregroundStyle(notice.outcome.color)
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
                NotificationCenter.default.post(name: .openActivityPanel, object: nil)
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
        .frame(width: 420)
        .floatingSurface()
        .onHover { noticeStore.setHovering($0) }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    OperationNoticeView(notice: OperationNotice(operation: BrewOperation.previewList[2]))
        .environment(AppStores())
        .padding()
}
