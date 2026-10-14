import SwiftUI
import CellarCore

/// Name, location, package summary and actions of the selected Brewfile.
struct BrewfileHeader: View {
    let brewfile: Brewfile
    @Binding var sheet: BrewfileSheet?
    @Binding var confirmation: BrewfileConfirmation?

    @Environment(BrewfileStore.self) private var store

    private var isBusy: Bool { store.isBusy(brewfile) }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sectionContent) {
            Image(systemName: brewfile.systemImage)
                .font(.title)
                .foregroundStyle(.tint)
                .frame(width: IconSize.headerIcon, height: IconSize.headerIcon)
                .background(Color.accentColor.opacity(Opacity.iconBackground), in: RoundedRectangle(cornerRadius: CornerRadius.card))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.compact) {
                HStack(spacing: Spacing.item) {
                    Text(brewfile.name)
                        .font(.title2.weight(.semibold))
                    activationBadge
                }
                Text(brewfile.displayPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                summary
                    .font(.callout)
            }

            Spacer(minLength: Spacing.item)

            actions
        }
        .padding(Spacing.cardPadding)
    }

    // MARK: - Summary

    @ViewBuilder
    private var summary: some View {
        HStack(spacing: Spacing.item) {
            if store.isCheckingStatus {
                ProgressView()
                    .controlSize(.small)
                Text("Checking packages\u{2026}")
                    .foregroundStyle(.secondary)
            } else if store.check != nil, !store.content.isEmpty {
                let missing = store.missingEntries.count
                let total = store.content.entries.count
                if missing == 0 {
                    Label(total == 1 ? "Installed" : "All \(total) installed", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                } else {
                    Label("\(missing) of \(total) missing", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            if brewfile.kind == .mac, let lastExported = brewfile.lastExported {
                Text("Exported \(lastExported, format: .relative(presentation: .named))")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var activationBadge: some View {
        if brewfile.kind == .project, store.isActivated(brewfile) {
            let state = store.serviceState(of: brewfile)
            if state == .running {
                StatusBadge(text: "Active", color: .green, icon: "bolt.fill")
            } else {
                StatusBadge(text: "Active · \(state.label)", color: .orange, icon: "exclamationmark.triangle")
            }
        }
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: Spacing.item) {
            Group {
                let missing = store.missingEntries.count
                if missing > 0 {
                    Button("Install Missing (\(missing))", systemImage: "arrow.down.circle") {
                        Task { await store.installMissing(from: brewfile) }
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Install \(store.missingEntries.map(\.name).formatted(.list(type: .and)))")
                }

                if brewfile.kind == .mac {
                    macActions
                } else if !brewfile.services.isEmpty {
                    activationActions
                }
            }
            .disabled(isBusy)

            Menu {
                BrewfileMenuItems(brewfile: brewfile, sheet: $sheet, confirmation: $confirmation)
            } label: {
                Label("More", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("More Actions")
            .help("More actions for \(brewfile.name)")
        }
    }

    @ViewBuilder
    private var macActions: some View {
        if brewfile.exists {
            Button("Export Current Setup\u{2026}", systemImage: "square.and.arrow.down") {
                if brewfile.hasChangesSinceExport {
                    confirmation = .export(brewfile)
                } else {
                    Task { await store.export(brewfile) }
                }
            }
            .help("Replace this Brewfile with what’s installed now; the previous version is kept as \(brewfile.backupURL.lastPathComponent)")

            Button("Clean Up\u{2026}", systemImage: "trash") {
                sheet = .cleanUp(brewfile)
            }
            .disabled(store.cleanupPlan?.isEmpty == true)
            .help("Preview and uninstall packages this Brewfile doesn’t list")
        }
    }

    @ViewBuilder
    private var activationActions: some View {
        if store.isActivated(brewfile) {
            if store.serviceState(of: brewfile) != .running {
                Button("Start Stopped Services\u{2026}", systemImage: "play.circle") {
                    sheet = .activate(brewfile)
                }
            }
            let toStop = store.servicesToStopOnDeactivation(of: brewfile)
            Button("Deactivate", systemImage: "stop.circle") {
                Task { await store.deactivate(brewfile) }
            }
            .help(toStop.isEmpty
                  ? "Nothing Cellar started for this project is running"
                  : "Stop \(toStop.formatted(.list(type: .and)))")
        } else {
            Button("Activate\u{2026}", systemImage: "play.circle") {
                sheet = .activate(brewfile)
            }
            .help("Preview which services start and stop")
        }
    }
}

#Preview {
    let stores = AppStores()
    stores.brewfiles.loadLibraryIfNeeded()
    return BrewfileHeader(brewfile: .preview, sheet: .constant(nil), confirmation: .constant(nil))
        .environment(stores)
        .frame(width: 760)
}
