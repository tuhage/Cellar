import SwiftUI
import CellarCore

/// Asks for a tap's `user/repo` name, shows where brew will clone it from,
/// and warns before trusting a third-party tap.
struct AddTapSheet: View {
    @Environment(TapStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var nameText = ""
    @State private var remoteText = ""
    @State private var usesCustomRemote = false

    private var tapName: TapName? { TapName(nameText) }

    private var trimmedRemote: String? {
        let remote = remoteText.trimmingCharacters(in: .whitespaces)
        return usesCustomRemote && !remote.isEmpty ? remote : nil
    }

    /// Why the tap can't be added yet, if anything blocks it.
    private var problem: String? {
        guard !nameText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        guard let tapName else { return "Enter the name as user/repo, using letters, numbers, - and _." }
        if store.isTapped(tapName.name) { return "\(tapName.name) is already tapped." }
        if let trimmedRemote, !TapName.isValidRemote(trimmedRemote) {
            return "Enter a git URL, such as https://… or git@host:path."
        }
        return nil
    }

    private var canAdd: Bool {
        tapName != nil && problem == nil && (!usesCustomRemote || trimmedRemote != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionContent) {
            Text("Add Tap")
                .font(.headline)

            Form {
                TextField("Name", text: $nameText, prompt: Text("user/repo"))
                    .autocorrectionDisabled()

                Toggle("Use a custom URL", isOn: $usesCustomRemote)

                if usesCustomRemote {
                    TextField("URL", text: $remoteText, prompt: Text("https://example.com/user/homebrew-repo.git"))
                        .autocorrectionDisabled()
                }
            }

            details
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add Tap") { add() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdd)
            }
        }
        .padding(Spacing.section)
        .frame(width: WindowSize.narrowWidth)
    }

    // MARK: - Details

    @ViewBuilder
    private var details: some View {
        if let problem {
            Label(problem, systemImage: "exclamationmark.circle")
                .foregroundStyle(.red)
        } else if let tapName {
            VStack(alignment: .leading, spacing: Spacing.item) {
                if trimmedRemote == nil {
                    Label {
                        Text("Clones \(Text(tapName.defaultRemote.absoluteString).foregroundStyle(.primary))")
                    } icon: {
                        Image(systemName: "arrow.down.doc")
                    }
                    .foregroundStyle(.secondary)
                }
                if !tapName.isOfficial {
                    Label(
                        "Taps outside Homebrew run their own code on your Mac. Only add taps you trust.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.orange)
                }
            }
        } else {
            Text("Taps add formulae and casks from a git repository, named user/repo for github.com/user/homebrew-repo.")
                .foregroundStyle(.secondary)
        }
    }

    private func add() {
        guard canAdd, let tapName else { return }
        let remote = trimmedRemote
        Task { await store.addTap(tapName.name, remote: remote) }
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    AddTapSheet()
        .environment(AppStores())
}
