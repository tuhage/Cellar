import SwiftUI
import CellarCore

/// The Maintenance page's disk usage: a stacked bar of where Homebrew's
/// space goes, with a labelled row per part so nothing relies on color.
struct DiskUsageSection: View {
    let store: DiskUsageStore

    var body: some View {
        Section {
            if let usage = store.usage {
                LabeledContent {
                    Text(usage.totalBytes.formatted(.byteCount(style: .file)))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                } label: {
                    Text("Total")
                    Text("The Homebrew prefix and the download cache")
                }

                UsageBar(usage: usage)

                ForEach(usage.segments) { segment in
                    SegmentRow(segment: segment, usage: usage)
                }
            } else if let errorMessage = store.errorMessage {
                LabeledContent {
                    Button("Try Again") {
                        Task { await store.load(force: true) }
                    }
                } label: {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                }
            } else {
                Label {
                    Text("Measuring disk usage\u{2026}")
                } icon: {
                    ProgressView()
                        .controlSize(.small)
                }
                .foregroundStyle(.secondary)
            }
        } header: {
            Text("Disk Usage")
        } footer: {
            if let usage = store.usage {
                Text(footer(for: usage))
            }
        }
    }

    private func footer(for usage: HomebrewDiskUsage) -> String {
        let prefix = "\(usage.prefix.path) uses \(usage.prefix.bytes.formatted(.byteCount(style: .file)))."
        return usage.cache.isInside(usage.prefix)
            ? prefix
            : "\(prefix) The download cache is stored outside it, so it adds to the total."
    }
}

// MARK: - Bar

private struct UsageBar: View {
    let usage: HomebrewDiskUsage

    private static let height: CGFloat = 10

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: Spacing.none) {
                ForEach(usage.segments) { segment in
                    Rectangle()
                        .fill(segment.area.color)
                        .frame(width: geometry.size.width * usage.fraction(of: segment))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: Self.height)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.progressBar))
        .accessibilityHidden(true)
    }
}

// MARK: - Segment

private struct SegmentRow: View {
    let segment: HomebrewDiskUsage.Segment
    let usage: HomebrewDiskUsage

    var body: some View {
        LabeledContent {
            Text(segment.bytes.formatted(.byteCount(style: .file)))
                .monospacedDigit()
        } label: {
            Label {
                Text(segment.area.title)
                Text(location)
                    .truncationMode(.middle)
            } icon: {
                Circle()
                    .fill(segment.area.color)
                    .frame(width: IconSize.statusDot, height: IconSize.statusDot)
            }
        }
    }

    private var location: String {
        let path = switch segment.area {
        case .cellar: usage.cellar.path
        case .caskroom: usage.caskroom.path
        case .otherFiles: usage.prefix.path
        case .cache: usage.cache.path
        }
        return (path as NSString).abbreviatingWithTildeInPath
    }
}

private extension HomebrewDiskUsage.Area {
    var color: Color {
        switch self {
        case .cellar: .purple
        case .caskroom: .blue
        case .otherFiles: .gray
        case .cache: .orange
        }
    }
}

// MARK: - Preview

#Preview {
    let store = DiskUsageStore()
    store.usage = .preview
    return Form {
        DiskUsageSection(store: store)
    }
    .formStyle(.grouped)
    .frame(width: 600, height: 420)
}
