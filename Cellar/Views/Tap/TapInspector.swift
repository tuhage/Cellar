import SwiftUI
import CellarCore

/// A tap's repository and packages — the installed ones first, since those
/// are what untapping affects.
struct TapInspector: View {
    let usage: TapUsage
    let canUntap: Bool
    let untap: () -> Void

    private var tap: Tap { usage.tap }

    var body: some View {
        List {
            header
            repositorySection
            installedSection
            availableSection(.formula, names: usage.availableFormulae)
            availableSection(.cask, names: usage.availableCasks)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.item) {
            Text(tap.name)
                .font(.title2.weight(.semibold))
                .textSelection(.enabled)

            HStack(spacing: Spacing.related) {
                if tap.official {
                    StatusBadge(text: "Official", color: .blue, icon: "checkmark.seal")
                } else {
                    StatusBadge(text: "Third Party", color: .secondary, icon: "person.2")
                }
                if tap.isPrivate {
                    StatusBadge(text: "Private", color: .secondary, icon: "lock")
                }
            }

            Button(role: .destructive, action: untap) {
                Label("Untap\u{2026}", systemImage: "trash")
            }
            .disabled(!canUntap)
            .help(tap.installed ? "Remove this tap" : "Served by the Homebrew API — there’s nothing to untap")
        }
        .padding(.vertical, Spacing.compact)
    }

    // MARK: - Repository

    private var repositorySection: some View {
        Section("Repository") {
            LabeledContent("Remote") {
                if let url = tap.githubURL ?? URL(string: tap.remote), !tap.remote.isEmpty {
                    Link(tap.remote, destination: url)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("Homebrew API")
                }
            }
            if !tap.branch.isEmpty {
                LabeledContent("Branch", value: tap.branch)
            }
            if !tap.lastCommit.isEmpty {
                LabeledContent("Last Commit") {
                    Text(tap.head.isEmpty ? tap.lastCommit : "\(tap.lastCommit) (\(tap.head.prefix(7)))")
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Packages

    private var installedSection: some View {
        Section {
            if usage.installedCount == 0 {
                Text("No installed packages come from this tap.")
                    .foregroundStyle(.secondary)
            }
            ForEach(usage.installedFormulae, id: \.self) { name in
                installedRow(PackageID(kind: .formula, name: name))
            }
            ForEach(usage.installedCasks, id: \.self) { token in
                installedRow(PackageID(kind: .cask, name: token))
            }
        } header: {
            CountedSectionHeader(title: "Installed", systemImage: "checkmark.circle", count: usage.installedCount)
        }
    }

    private func installedRow(_ package: PackageID) -> some View {
        ShowPackageButton(package: package) {
            HStack {
                Label(package.name, systemImage: package.kind.systemImage)
                Spacer()
                Image(systemName: "arrow.forward.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func availableSection(_ kind: PackageKind, names: [String]) -> some View {
        if !names.isEmpty {
            Section {
                ForEach(names, id: \.self) { name in
                    Text(name)
                        .foregroundStyle(.secondary)
                }
            } header: {
                CountedSectionHeader(title: "Available \(kind.title)", systemImage: kind.systemImage, count: names.count)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TapInspector(
        usage: TapUsage(tap: .preview, installedFormulae: ["wget"], installedCasks: []),
        canUntap: true,
        untap: {}
    )
    .environment(AppStores())
    .frame(width: 360, height: 600)
}
