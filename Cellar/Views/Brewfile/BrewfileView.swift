import SwiftUI
import CellarCore

// MARK: - BrewfileView

/// Section-based Brewfile management view with unified profile header,
/// stats, quick actions, check results, and categorised package lists.
struct BrewfileView: View {
    @Environment(BrewfileStore.self) private var store

    @State private var isAddingProfile = false
    @State private var isEditingRaw = false
    @State private var isConfirmingDeleteProfile = false
    @State private var alsoDeleteFile = false
    @State private var newProfileName = ""
    @State private var newProfilePath = ""
    @State private var newProfileMode: BrewfileCreationMode = .empty

    var body: some View {
        Group {
            if let stream = store.actionStream {
                actionOutputView(
                    title: store.actionTitle ?? "Running",
                    stream: stream
                )
            } else if store.selectedProfile != nil, store.brewfileExistsOnDisk {
                brewfileContent
            } else if store.selectedProfile != nil {
                noBrewfileOnDiskView
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Brewfile")
        .toolbar { toolbarContent }
        .sheet(isPresented: $isAddingProfile) { addProfileSheet }
        .sheet(isPresented: $isEditingRaw) { rawEditorSheet }
        .alert(
            "Delete \"\(store.selectedProfile?.name ?? "Profile")\"?",
            isPresented: $isConfirmingDeleteProfile
        ) {
            Button("Delete", role: .destructive) {
                guard let profile = store.selectedProfile else { return }
                if alsoDeleteFile {
                    store.deleteBrewfile(for: profile)
                }
                store.deleteProfile(profile)
                if let first = store.profiles.first {
                    store.selectProfile(first.id)
                }
                alsoDeleteFile = false
            }
            Button("Cancel", role: .cancel) {
                alsoDeleteFile = false
            }
        } message: {
            if let profile = store.selectedProfile {
                Text("This will remove the profile. You can also delete the Brewfile at \(profile.path).")
            }
        }
        .task {
            store.loadProfiles()
            store.ensureDefaultProfile()
            if store.selectedProfileId == nil, let first = store.profiles.first {
                store.selectProfile(first.id)
            }
        }
    }

    // MARK: - Content

    private var brewfileContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                profileHeader
                statsSection
                quickActionsSection
                if let result = store.checkResult {
                    checkResultBanner(result)
                }
                packageListSections
            }
            .padding(24)
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.largeTitle)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                if let profile = store.selectedProfile {
                    Text(profile.name)
                        .font(.headline)

                    HStack(spacing: 6) {
                        Text(profile.path)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if let lastExported = profile.lastExported {
                            Text("·")
                            Text("Exported \(lastExported, format: .relative(presentation: .named))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }

                Text("A Brewfile lists all your Homebrew packages. Use it to back up your setup or migrate to another Mac.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if store.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            profileMenu
        }
        .padding(12)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Profile Menu

    private var profileMenu: some View {
        Menu {
            ForEach(store.profiles) { profile in
                Button {
                    store.selectProfile(profile.id)
                } label: {
                    if profile.id == store.selectedProfileId {
                        Label(profile.name, systemImage: "checkmark")
                    } else {
                        Text(profile.name)
                    }
                }
            }

            Divider()

            Button {
                newProfileName = ""
                newProfilePath = defaultBrewfilePath()
                newProfileMode = .empty
                isAddingProfile = true
            } label: {
                Label("New Profile...", systemImage: "plus")
            }

            if store.selectedProfile != nil {
                Divider()

                Button(role: .destructive) {
                    alsoDeleteFile = false
                    isConfirmingDeleteProfile = true
                } label: {
                    Label("Delete Profile", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "chevron.down.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .font(.title3)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "Contents", systemImage: "tray.full.fill", color: .secondary) {
                StatusBadge(
                    text: "\(store.parsedContent.totalItems) items",
                    color: store.parsedContent.isEmpty ? .secondary : .blue
                )
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                spacing: 12
            ) {
                StatCardView(
                    title: "Taps",
                    value: "\(store.parsedContent.taps.count)",
                    systemImage: "spigot",
                    color: .gray
                )

                StatCardView(
                    title: "Formulae",
                    value: "\(store.parsedContent.formulae.count)",
                    systemImage: "terminal",
                    color: .blue
                )

                StatCardView(
                    title: "Casks",
                    value: "\(store.parsedContent.casks.count)",
                    systemImage: "macwindow",
                    color: .purple
                )
            }
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "Actions", systemImage: "bolt.fill", color: .secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2),
                spacing: 12
            ) {
                quickActionButton(
                    title: "Sync",
                    subtitle: "Export current packages to Brewfile",
                    systemImage: "arrow.triangle.2.circlepath",
                    color: .blue
                ) {
                    guard let profile = store.selectedProfile else { return }
                    Task { await store.exportBrewfile(to: profile) }
                }

                quickActionButton(
                    title: "Install",
                    subtitle: "Install all packages from Brewfile",
                    systemImage: "square.and.arrow.down.fill",
                    color: .green
                ) {
                    guard let profile = store.selectedProfile else { return }
                    store.beginInstall(from: profile)
                }

                quickActionButton(
                    title: "Check",
                    subtitle: "Verify all packages are installed",
                    systemImage: "checkmark.shield.fill",
                    color: .orange
                ) {
                    guard let profile = store.selectedProfile else { return }
                    Task { await store.checkBrewfile(for: profile) }
                }

                quickActionButton(
                    title: "Cleanup",
                    subtitle: "Remove packages not in Brewfile",
                    systemImage: "trash.circle.fill",
                    color: .red
                ) {
                    guard let profile = store.selectedProfile else { return }
                    store.cleanupBrewfile(for: profile)
                }
            }
        }
    }

    private func quickActionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        let isDisabled = store.isLoading || store.isPerformingAction || store.isChecking

        return Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.medium))

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(BrewfileQuickActionStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }

    // MARK: - Check Result Banner

    private func checkResultBanner(_ result: String) -> some View {
        let isSuccess = result.localizedCaseInsensitiveContains("satisfied")
            || result.localizedCaseInsensitiveContains("dependencies are satisfied")
        let bannerColor: Color = isSuccess ? .green : .orange

        return HStack(spacing: 12) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(bannerColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(isSuccess ? "All Satisfied" : "Issues Found")
                    .font(.headline)

                Text(result)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                store.checkResult = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(bannerColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Package List Sections

    @ViewBuilder
    private var packageListSections: some View {
        if store.parsedContent.isEmpty {
            emptyPackagesView
        } else {
            if !store.parsedContent.taps.isEmpty {
                packageSection(
                    title: "Taps",
                    systemImage: "spigot",
                    color: .gray,
                    entries: store.parsedContent.taps
                )
            }

            if !store.parsedContent.formulae.isEmpty {
                packageSection(
                    title: "Formulae",
                    systemImage: "terminal",
                    color: .blue,
                    entries: store.parsedContent.formulae
                )
            }

            if !store.parsedContent.casks.isEmpty {
                packageSection(
                    title: "Casks",
                    systemImage: "macwindow",
                    color: .purple,
                    entries: store.parsedContent.casks
                )
            }
        }
    }

    private func packageSection(
        title: String,
        systemImage: String,
        color: Color,
        entries: [BrewfileContent.Entry]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: title, systemImage: systemImage, color: color) {
                StatusBadge(text: "\(entries.count)", color: color)
            }

            GroupBox {
                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        HStack(spacing: 8) {
                            Image(systemName: systemImage)
                                .foregroundStyle(color)
                                .frame(width: 20)

                            Text(entry.name)
                                .fontWeight(.medium)

                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)

                        if entry.id != entries.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var emptyPackagesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "Packages", systemImage: "shippingbox", color: .secondary)

            ContentUnavailableView(
                "No Packages",
                systemImage: "doc.text",
                description: Text(
                    store.brewfileExistsOnDisk
                        ? "This Brewfile is empty. Use Sync to populate it from your current packages."
                        : "No Brewfile found on disk. Use Sync to create one from your current packages."
                )
            )
        }
    }

    // MARK: - No Brewfile on Disk

    private var noBrewfileOnDiskView: some View {
        ContentUnavailableView {
            Label("No Brewfile", systemImage: "doc.text")
        } description: {
            if let profile = store.selectedProfile {
                Text("No Brewfile found at \(profile.path)")
            }
        } actions: {
            Button {
                guard let profile = store.selectedProfile else { return }
                Task { await store.exportBrewfile(to: profile) }
            } label: {
                Text("Generate from System")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Profile Selected",
            systemImage: "doc.text",
            description: Text("Create a Brewfile profile to get started.")
        )
    }

    // MARK: - Action Output

    private func actionOutputView(
        title: String,
        stream: AsyncThrowingStream<String, Error>
    ) -> some View {
        VStack(spacing: 0) {
            ProcessOutputView(title: title, stream: stream)

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    store.dismissAction()
                    if let profile = store.selectedProfile {
                        store.loadBrewfileContent(for: profile)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                isEditingRaw = true
            } label: {
                Label("Edit Raw", systemImage: "pencil")
            }
            .disabled(store.selectedProfile == nil || !store.brewfileExistsOnDisk)
            .help("Edit raw Brewfile content")

            Button {
                newProfileName = ""
                newProfilePath = defaultBrewfilePath()
                newProfileMode = .empty
                isAddingProfile = true
            } label: {
                Label("New Profile", systemImage: "plus")
            }
            .help("Create a new Brewfile profile")
        }
    }

    // MARK: - Raw Editor Sheet

    private var rawEditorSheet: some View {
        NavigationStack {
            rawEditorContent
                .navigationTitle("Edit Brewfile")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            // Revert changes
                            if let profile = store.selectedProfile {
                                store.loadBrewfileContent(for: profile)
                            }
                            isEditingRaw = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if let profile = store.selectedProfile {
                                store.saveBrewfileContent(for: profile)
                            }
                            isEditingRaw = false
                        }
                    }
                }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private var rawEditorContent: some View {
        @Bindable var store = store

        return VStack(spacing: 0) {
            TextEditor(text: $store.brewfileContent)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)

            Divider()

            HStack {
                let lineCount = store.brewfileContent.components(separatedBy: "\n").count
                Text("\(lineCount) lines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.fill.tertiary, in: Capsule())
                Spacer()
            }
            .padding(8)
        }
    }

    // MARK: - Add Profile Sheet

    private var addProfileSheet: some View {
        VStack(spacing: 16) {
            Text("New Brewfile Profile")
                .font(.headline)

            Form {
                TextField("Name", text: $newProfileName)
                TextField("File Path", text: $newProfilePath)

                Picker("Contents", selection: $newProfileMode) {
                    ForEach(BrewfileCreationMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                switch newProfileMode {
                case .empty:
                    Text("Creates an empty Brewfile with a comment header.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .generate:
                    Text("Generates a Brewfile from your currently installed packages.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    isAddingProfile = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    let name = newProfileName.trimmingCharacters(in: .whitespaces)
                    let path = newProfilePath.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty, !path.isEmpty else { return }
                    store.createProfile(name: name, path: path, mode: newProfileMode)
                    isAddingProfile = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    newProfileName.trimmingCharacters(in: .whitespaces).isEmpty
                    || newProfilePath.trimmingCharacters(in: .whitespaces).isEmpty
                )
            }
        }
        .padding()
        .frame(width: 420)
    }

    // MARK: - Helpers

    private func defaultBrewfilePath() -> String {
        "\(NSHomeDirectory())/Brewfile"
    }
}

// MARK: - Quick Action Button Style

private struct BrewfileQuickActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(configuration.isPressed ? .tertiary : .quaternary)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BrewfileView()
            .environment(BrewfileStore())
    }
    .frame(width: 700, height: 600)
}
