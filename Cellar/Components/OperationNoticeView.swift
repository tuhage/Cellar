import SwiftUI

struct OperationNotice: Identifiable, Equatable {
    enum Kind {
        case success
        case failure
        case cancelled

        var color: Color {
            switch self {
            case .success: .green
            case .failure: .red
            case .cancelled: .secondary
            }
        }

        var systemImage: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .failure: "exclamationmark.triangle.fill"
            case .cancelled: "minus.circle.fill"
            }
        }
    }

    let id: UUID
    let kind: Kind
    let title: String
    let message: String

    init(operation: BrewOperation) {
        id = operation.id
        switch operation.status {
        case .succeeded:
            kind = .success
            title = String(localized: "Operation Completed")
            message = operation.kind.completionTitle
        case .failed(let reason):
            kind = .failure
            title = String(localized: "Operation Failed")
            message = reason
        case .cancelled:
            kind = .cancelled
            title = String(localized: "Operation Cancelled")
            message = operation.kind.displayTitle
        case .running:
            kind = .cancelled
            title = ""
            message = ""
        }
    }
}

struct OperationNoticeView: View {
    let notice: OperationNotice
    let showDetails: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sectionContent) {
            Image(systemName: notice.kind.systemImage)
                .font(.title3)
                .foregroundStyle(notice.kind.color)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Text(notice.title)
                    .font(.subheadline.weight(.semibold))
                Text(notice.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Button("Details", action: showDetails)
                .buttonStyle(.borderless)
                .controlSize(.small)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
            .accessibilityLabel("Dismiss notification")
        }
        .padding(Spacing.cardPadding)
        .frame(width: 420, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.card, style: .continuous)
                .strokeBorder(notice.kind.color.opacity(0.25))
        }
        .shadow(color: Shadow.elevatedColor, radius: Shadow.elevatedBlur, y: Shadow.elevatedY)
        .accessibilityElement(children: .contain)
    }
}
