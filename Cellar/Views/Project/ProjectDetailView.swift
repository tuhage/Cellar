import SwiftUI
import CellarCore

// MARK: - ProjectDetailView

/// Displays services, packages, and activation controls for a single project environment.
struct ProjectDetailView: View {
    let project: ProjectEnvironment
    @Binding var missingPackages: [String]

    @Environment(ProjectStore.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            detailBody
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Spacing.sectionContent) {
            Image(systemName: "hammer")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: IconSize.headerIcon, height: IconSize.headerIcon)
                .background(Color.accentColor.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Text(project.name)
                    .font(.headline)
                Text(project.path)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if store.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            activationButton
        }
        .padding()
    }

    // MARK: - Activation Button

    private var activationButton: some View {
        Group {
            if store.activeProjectId == project.id {
                Button {
                    Task { await store.deactivate() }
                } label: {
                    Label("Deactivate", systemImage: "stop.circle")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .help("Stop all services for this project")
            } else {
                Button {
                    Task { await store.activate(project) }
                } label: {
                    Label("Activate", systemImage: "play.circle")
                }
                .buttonStyle(.borderedProminent)
                .help("Start all services for this project")
            }
        }
        .disabled(store.isLoading || project.services.isEmpty)
        .controlSize(.regular)
    }

    // MARK: - Detail Body

    private var detailBody: some View {
        List {
            if let errorMessage = store.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            if !missingPackages.isEmpty {
                Section {
                    ForEach(missingPackages, id: \.self) { name in
                        HStack(spacing: Spacing.item) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text(name)
                                .fontWeight(.medium)
                        }
                    }
                } header: {
                    HStack(spacing: Spacing.related) {
                        Label("Missing Packages", systemImage: "exclamationmark.triangle.fill")
                        Text("\(missingPackages.count)")
                            .font(.caption)
                            .smallBadgeInset()
                            .background(.orange.opacity(0.15), in: Capsule())
                    }
                    .foregroundStyle(.orange)
                }
            }

            // Services section
            Section {
                if project.services.isEmpty {
                    HStack(spacing: Spacing.item) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("Add brew services this project needs (e.g. postgresql@16, redis).")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                } else {
                    ForEach(project.services, id: \.self) { serviceName in
                        HStack {
                            Label(serviceName, systemImage: "gearshape.2")
                            Spacer()
                            Button {
                                store.removeService(serviceName, from: project)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            } header: {
                Label("Services (\(project.services.count))", systemImage: "gearshape.2")
            } footer: {
                if !project.services.isEmpty {
                    Text("These services will be started when you activate the project.")
                        .foregroundStyle(.tertiary)
                }
            }

            // Packages section
            Section {
                if project.packages.isEmpty {
                    HStack(spacing: Spacing.item) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("Add formulae this project depends on (e.g. node, python@3.12).")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                } else {
                    ForEach(project.packages, id: \.self) { packageName in
                        HStack {
                            Label(packageName, systemImage: "terminal")

                            if missingPackages.contains(packageName) {
                                StatusBadge(text: "Missing", color: .orange, icon: "exclamationmark.triangle")
                            }

                            Spacer()

                            Button {
                                store.removePackage(packageName, from: project)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            } header: {
                Label("Packages (\(project.packages.count))", systemImage: "terminal")
            } footer: {
                if !project.packages.isEmpty {
                    Text("Use the Check Packages button to verify these are installed.")
                        .foregroundStyle(.tertiary)
                }
            }

            // Auto-start toggle
            Section {
                autoStartToggle
            } header: {
                Label("Settings", systemImage: "gear")
            } footer: {
                Text("When enabled, services start automatically each time you activate this project.")
                    .foregroundStyle(.tertiary)
            }
        }
        .task(id: project.id) {
            missingPackages = await store.checkMissingPackages(project)
        }
    }

    // MARK: - Auto-Start Toggle

    private var autoStartToggle: some View {
        @Bindable var store = store

        return Toggle("Auto-start services on activation", isOn: Binding(
            get: { project.autoStart },
            set: { newValue in
                guard let index = store.projects.firstIndex(where: { $0.id == project.id }) else { return }
                store.projects[index].autoStart = newValue
                store.save()
            }
        ))
    }
}

// MARK: - Preview

#Preview {
    ProjectDetailView(project: .preview, missingPackages: .constant([]))
        .environment(ProjectStore())
        .frame(width: 600, height: 500)
}
