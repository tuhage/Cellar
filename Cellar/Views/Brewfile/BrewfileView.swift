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
    @State private var newProfileName = ""
    @State private var newProfilePath = ""
    @State private var newProfileMode: BrewfileCreationMode = .empty
    @State private var isConfirmingCleanup = false

    var body: some View {
        Group {
            if let stream = store.actionStream {
                ActionOutputView(
                    title: store.actionTitle ?? "Running",
                    stream: stream,
                    onDismiss: {
                        store.dismissAction()
                        if let profile = store.selectedProfile {
                            store.loadBrewfileContent(for: profile)
                        }
                    }
                )
            } else if let profile = store.selectedProfile {
                if store.brewfileExistsOnDisk {
                    brewfileContent
                } else {
                    noBrewfileOnDiskView(profile)
                }
            } else {
                emptyStateView
            }
        }
        .navigationTitle("Brewfile")
        .toolbar { toolbarContent }
        .sheet(isPresented: $isAddingProfile) { addProfileSheet }
        .sheet(isPresented: $isEditingRaw) { rawEditorSheet }
        .confirmationDialog(
            "Delete \"\(store.selectedProfile?.name ?? "Profile")\"?",
            isPresented: $isConfirmingDeleteProfile,
            titleVisibility: .visible
        ) {
            deleteProfileDialogButtons
        } message: {
            if let profile = store.selectedProfile {
                Text("The profile \"\(profile.name)\" will be removed. You can also delete the Brewfile at \(profile.path).")
            }
        }
        .confirmationDialog(
            "Cleanup Packages?",
            isPresented: $isConfirmingCleanup,
            titleVisibility: .visible
        ) {
            Button("Cleanup", role: .destructive) {
                guard let profile = store.selectedProfile else { return }
                store.cleanupBrewfile(for: profile)
            }
        } message: {
            Text("Remove all packages not listed in the current Brewfile? This cannot be undone.")
        }
        .task {
            store.loadProfiles()
            store.ensureDefaultProfile()
            if store.selectedProfileId == nil, let first = store.profiles.first {
                store.selectProfile(first.id)
            }
        }
    }

    // MARK: - Confirmation Dialog

    @ViewBuilder
    private var deleteProfileDialogButtons: some View {
        Button("Delete Profile Only", role: .destructive) {
            deleteSelectedProfileAndSelectFirst()
        }

        if store.brewfileExistsOnDisk {
            Button("Delete Profile and Brewfile", role: .destructive) {
                if let profile = store.selectedProfile {
                    store.deleteBrewfile(for: profile)
                }
                deleteSelectedProfileAndSelectFirst()
            }
        }

        Button("Cancel", role: .cancel) {}
    }

    // MARK: - Content

    private var brewfileContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                profileHeader
                statsSection
                quickActionsSection
                if let result = store.checkResult {
                    checkResultBanner(result)
                }
                packageListSections
            }
            .padding(Spacing.section)
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        HStack(alignment: .top, spacing: Spacing.sectionContent) {
            Image(systemName: "doc.text.fill")
                .font(.largeTitle)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: Spacing.compact) {
                if let profile = store.selectedProfile {
                    Text(profile.name)
                        .font(.headline)

                    HStack(spacing: Spacing.related) {
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
        .padding(Spacing.sectionContent)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.card))
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
                presentAddProfileSheet()
            } label: {
                Label("New Profile...", systemImage: "plus")
            }

            if store.selectedProfile != nil {
                Divider()

                Button(role: .destructive) {
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
        VStack(alignment: .leading, spacing: Spacing.sectionContent) {
            SectionHeaderView(title: "Contents", systemImage: "tray.full.fill", color: .secondary) {
                StatusBadge(
                    text: "\(store.parsedContent.totalItems) items",
                    color: store.parsedContent.isEmpty ? .secondary : .blue
                )
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sectionContent), count: 3),
                spacing: Spacing.sectionContent
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
        let isDisabled = store.isLoading || store.isPerformingAction || store.isChecking

        return VStack(alignment: .leading, spacing: Spacing.sectionContent) {
            SectionHeaderView(title: "Actions", systemImage: "bolt.fill", color: .secondary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.sectionContent), count: 2),
                spacing: Spacing.sectionContent
            ) {
                QuickActionButton(
                    title: "Sync",
                    subtitle: "Export current packages to Brewfile",
                    systemImage: "arrow.triangle.2.circlepath",
                    color: .blue,
                    isDisabled: isDisabled
                ) {
                    guard let profile = store.selectedProfile else { return }
                    Task { await store.exportBrewfile(to: profile) }
                }

                QuickActionButton(
                    title: "Install",
                    subtitle: "Install all packages from Brewfile",
                    systemImage: "square.and.arrow.down.fill",
                    color: .green,
                    isDisabled: isDisabled
                ) {
                    guard let profile = store.selectedProfile else { return }
                    store.beginInstall(from: profile)
                }

                QuickActionButton(
                    title: "Check",
                    subtitle: "Verify all packages are installed",
                    systemImage: "checkmark.shield.fill",
                    color: .orange,
                    isDisabled: isDisabled
                ) {
                    guard let profile = store.selectedProfile else { return }
                    Task { await store.checkBrewfile(for: profile) }
                }

                QuickActionButton(
                    title: "Cleanup",
                    subtitle: "Remove packages not in Brewfile",
                    systemImage: "trash.circle.fill",
                    color: .red,
                    isDisabled: isDisabled
                ) {
                    isConfirmingCleanup = true
                }
            }
        }
    }

    // MARK: - Check Result Banner

    private func checkResultBanner(_ result: String) -> some View {
        let isSuccess = result.localizedCaseInsensitiveContains("satisfied")
            || result.localizedCaseInsensitiveContains("dependencies are satisfied")
        let bannerColor: Color = isSuccess ? .green : .orange

        return HStack(spacing: Spacing.sectionContent) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(bannerColor)

            VStack(alignment: .leading, spacing: Spacing.textPair) {
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
        .padding(Spacing.sectionContent)
        .background(bannerColor.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.card))
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
        VStack(alignment: .leading, spacing: Spacing.sectionContent) {
            SectionHeaderView(title: title, systemImage: systemImage, color: color) {
                StatusBadge(text: "\(entries.count)", color: color)
            }

            GroupBox {
                VStack(spacing: 0) {
                    DividedForEach(data: entries) { entry in
                        HStack(spacing: Spacing.item) {
                            Image(systemName: systemImage)
                                .foregroundStyle(color)
                                .frame(width: IconSize.iconColumn)

                            Text(entry.name)
                                .fontWeight(.medium)

                            Spacer()
                        }
                        .listRowInset()
                    }
                }
            }
        }
    }

    private var emptyPackagesView: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionContent) {
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

    private func noBrewfileOnDiskView(_ profile: BrewfileProfile) -> some View {
        ContentUnavailableView {
            Label("No Brewfile", systemImage: "doc.text")
        } description: {
            Text("No Brewfile found at \(profile.path)")
        } actions: {
            Button("Generate from System") {
                Task { await store.exportBrewfile(to: profile) }
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
                presentAddProfileSheet()
            } label: {
                Label("New Profile", systemImage: "plus")
            }
            .help("Create a new Brewfile profile")
        }
    }

    // MARK: - Raw Editor Sheet

    private var rawEditorSheet: some View {
        @Bindable var store = store

        return NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $store.brewfileContent)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.item)

                Divider()

                HStack {
                    let lineCount = store.brewfileContent.components(separatedBy: "\n").count
                    Text("\(lineCount) lines")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .badgeInset()
                        .background(.fill.tertiary, in: Capsule())
                    Spacer()
                }
                .padding(Spacing.item)
            }
            .navigationTitle("Edit Brewfile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
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

    // MARK: - Add Profile Sheet

    private var addProfileSheet: some View {
        let trimmedName = newProfileName.trimmingCharacters(in: .whitespaces)
        let trimmedPath = newProfilePath.trimmingCharacters(in: .whitespaces)
        let isFormValid = !trimmedName.isEmpty && !trimmedPath.isEmpty

        return VStack(spacing: Spacing.cardPadding) {
            Text("New Profile")
                .font(.headline)

            Form {
                TextField("Name", text: $newProfileName)

                HStack {
                    TextField("Location", text: $newProfilePath)
                    Button("Browse...") {
                        showFilePicker()
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.item) {
                    Text("Contents")
                        .font(.subheadline.weight(.medium))

                    Picker("Contents", selection: $newProfileMode) {
                        ForEach(BrewfileCreationMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()

                    Text(newProfileMode.subtitle)
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
                    guard isFormValid else { return }
                    store.createProfile(name: trimmedName, path: trimmedPath, mode: newProfileMode)
                    isAddingProfile = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid)
            }
        }
        .padding()
        .frame(width: 420)
    }

    // MARK: - Helpers

    private func presentAddProfileSheet() {
        newProfileName = ""
        newProfilePath = defaultBrewfilePath()
        newProfileMode = .empty
        isAddingProfile = true
    }

    private func deleteSelectedProfileAndSelectFirst() {
        guard let profile = store.selectedProfile else { return }
        store.deleteProfile(profile)
        if let first = store.profiles.first {
            store.selectProfile(first.id)
        }
    }

    private func defaultBrewfilePath() -> String {
        "\(NSHomeDirectory())/Brewfile"
    }

    private func showFilePicker() {
        let panel = NSOpenPanel()
        panel.title = "Choose Brewfile Location"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())

        if panel.runModal() == .OK, let url = panel.url {
            if url.hasDirectoryPath {
                newProfilePath = url.appendingPathComponent("Brewfile").path
            } else {
                newProfilePath = url.path
            }
        }
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
