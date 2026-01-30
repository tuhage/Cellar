import SwiftUI

// MARK: - ProjectListView

/// Displays project environments in a sidebar-detail layout.
/// The left panel lists all projects with active indicators.
/// The right panel shows services, packages, and activation controls.
struct ProjectListView: View {
    @Environment(ProjectStore.self) private var store

    @State private var isAddingProject = false
    @State private var isAddingService = false
    @State private var isAddingPackage = false
    @State private var newProjectName = ""
    @State private var newProjectPath = ""
    @State private var newServiceName = ""
    @State private var newPackageName = ""
    @State private var missingPackages: [String] = []

    var body: some View {
        mainContent
            .navigationTitle("Projects")
            .toolbar { toolbarContent }
            .sheet(isPresented: $isAddingProject) { addProjectSheet }
            .sheet(isPresented: $isAddingService) { addServiceSheet }
            .sheet(isPresented: $isAddingPackage) { addPackageSheet }
            .task { store.load() }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        HSplitView {
            projectList
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
            detailPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Project List

    private var projectList: some View {
        @Bindable var store = store

        return VStack(spacing: 0) {
            List(selection: $store.selectedProjectId) {
                ForEach(store.projects) { project in
                    projectRow(project)
                        .tag(project.id)
                        .contextMenu {
                            Button(role: .destructive) {
                                store.delete(project)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack {
                Button {
                    newProjectName = ""
                    newProjectPath = ""
                    isAddingProject = true
                } label: {
                    Label("Add Project", systemImage: "plus")
                }
                .buttonStyle(.borderless)

                Spacer()

                if let project = store.selectedProject {
                    Button(role: .destructive) {
                        store.delete(project)
                    } label: {
                        Label("Delete", systemImage: "minus")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(8)
        }
    }

    private func projectRow(_ project: ProjectEnvironment) -> some View {
        HStack(spacing: 10) {
            // Active indicator
            Circle()
                .fill(store.activeProjectId == project.id ? .green : .clear)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .fontWeight(.medium)
                Text(project.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    // MARK: - Detail Panel

    @ViewBuilder
    private var detailPanel: some View {
        if let project = store.selectedProject {
            projectDetail(project)
        } else {
            ContentUnavailableView(
                "Select a Project",
                systemImage: "hammer",
                description: Text("Choose a project from the list or create a new one.")
            )
        }
    }

    private func projectDetail(_ project: ProjectEnvironment) -> some View {
        VStack(spacing: 0) {
            projectDetailHeader(project)
            Divider()
            projectDetailBody(project)
        }
    }

    private func projectDetailHeader(_ project: ProjectEnvironment) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "hammer")
                .font(.title)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
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

            activationButton(for: project)
        }
        .padding()
    }

    private func activationButton(for project: ProjectEnvironment) -> some View {
        Group {
            if store.activeProjectId == project.id {
                Button {
                    Task { await store.deactivate() }
                } label: {
                    Label("Deactivate", systemImage: "stop.circle")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            } else {
                Button {
                    Task { await store.activate(project) }
                } label: {
                    Label("Activate", systemImage: "play.circle")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .disabled(store.isLoading)
        .controlSize(.regular)
    }

    private func projectDetailBody(_ project: ProjectEnvironment) -> some View {
        List {
            // Missing packages warning
            if !missingPackages.isEmpty {
                Section {
                    ForEach(missingPackages, id: \.self) { name in
                        Label(name, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Label("Missing Packages", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            // Services section
            Section("Services (\(project.services.count))") {
                if project.services.isEmpty {
                    Text("No services configured")
                        .foregroundStyle(.secondary)
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
            }

            // Packages section
            Section("Packages (\(project.packages.count))") {
                if project.packages.isEmpty {
                    Text("No packages configured")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(project.packages, id: \.self) { packageName in
                        HStack {
                            Label(packageName, systemImage: "terminal")

                            if missingPackages.contains(packageName) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
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
            }

            // Auto-start toggle
            Section("Settings") {
                autoStartToggle(for: project)
            }
        }
        .task(id: project.id) {
            missingPackages = await store.checkMissingPackages(project)
        }
    }

    private func autoStartToggle(for project: ProjectEnvironment) -> some View {
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

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                newServiceName = ""
                isAddingService = true
            } label: {
                Label("Add Service", systemImage: "gearshape.2")
            }
            .disabled(store.selectedProject == nil)
            .help("Add a service to this project")

            Button {
                newPackageName = ""
                isAddingPackage = true
            } label: {
                Label("Add Package", systemImage: "plus.square")
            }
            .disabled(store.selectedProject == nil)
            .help("Add a required package to this project")

            Button {
                guard let project = store.selectedProject else { return }
                Task {
                    missingPackages = await store.checkMissingPackages(project)
                }
            } label: {
                Label("Check Packages", systemImage: "checkmark.circle")
            }
            .disabled(store.selectedProject == nil || store.isLoading)
            .help("Check for missing packages")
        }
    }

    // MARK: - Add Project Sheet

    private var addProjectSheet: some View {
        VStack(spacing: 16) {
            Text("New Project")
                .font(.headline)

            Form {
                TextField("Name", text: $newProjectName)
                TextField("Project Path", text: $newProjectPath)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    isAddingProject = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    let name = newProjectName.trimmingCharacters(in: .whitespaces)
                    let path = newProjectPath.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty, !path.isEmpty else { return }
                    store.create(name: name, path: path)
                    isAddingProject = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    newProjectName.trimmingCharacters(in: .whitespaces).isEmpty
                    || newProjectPath.trimmingCharacters(in: .whitespaces).isEmpty
                )
            }
        }
        .padding()
        .frame(width: 420)
    }

    // MARK: - Add Service Sheet

    private var addServiceSheet: some View {
        VStack(spacing: 16) {
            Text("Add Service")
                .font(.headline)

            Form {
                TextField("Service Name (e.g. postgresql@16)", text: $newServiceName)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    isAddingService = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    guard let project = store.selectedProject else { return }
                    let name = newServiceName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    store.addService(name, to: project)
                    isAddingService = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newServiceName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 380)
    }

    // MARK: - Add Package Sheet

    private var addPackageSheet: some View {
        VStack(spacing: 16) {
            Text("Add Package")
                .font(.headline)

            Form {
                TextField("Package Name (e.g. node)", text: $newPackageName)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    isAddingPackage = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    guard let project = store.selectedProject else { return }
                    let name = newPackageName.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    store.addPackage(name, to: project)
                    isAddingPackage = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newPackageName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 380)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProjectListView()
            .environment(ProjectStore())
    }
    .frame(width: 800, height: 600)
}
