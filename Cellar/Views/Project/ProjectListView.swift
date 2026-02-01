import SwiftUI
import CellarCore

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
    @State private var isConfirmingDeleteProject = false
    @State private var projectToDelete: ProjectEnvironment?

    var body: some View {
        mainContent
            .navigationTitle("Projects")
            .toolbar { toolbarContent }
            .sheet(isPresented: $isAddingProject) { addProjectSheet }
            .sheet(isPresented: $isAddingService) { addServiceSheet }
            .sheet(isPresented: $isAddingPackage) { addPackageSheet }
            .confirmationDialog(
                "Delete Project?",
                isPresented: $isConfirmingDeleteProject,
                presenting: projectToDelete
            ) { project in
                Button("Delete", role: .destructive) {
                    store.delete(project)
                }
            } message: { project in
                Text("Delete project '\(project.name)'? Installed packages and services will not be removed.")
            }
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
            if store.projects.isEmpty {
                emptyProjectList
            } else {
                List(selection: $store.selectedProjectId) {
                    ForEach(store.projects) { project in
                        projectRow(project)
                            .tag(project.id)
                            .contextMenu {
                                Button(role: .destructive) {
                                    projectToDelete = project
                                    isConfirmingDeleteProject = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.sidebar)
            }

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
                        projectToDelete = project
                        isConfirmingDeleteProject = true
                    } label: {
                        Label("Delete", systemImage: "minus")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(8)
        }
    }

    private var emptyProjectList: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No Projects")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Add a project to get started.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func projectRow(_ project: ProjectEnvironment) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(store.activeProjectId == project.id ? .green : .clear)
                .frame(width: 8, height: 8)
                .overlay {
                    if store.activeProjectId == project.id {
                        Circle()
                            .fill(.green.opacity(0.4))
                            .frame(width: 14, height: 14)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .fontWeight(.medium)

                HStack(spacing: 6) {
                    if !project.services.isEmpty {
                        Label("\(project.services.count)", systemImage: "gearshape.2")
                    }
                    if !project.packages.isEmpty {
                        Label("\(project.packages.count)", systemImage: "terminal")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Detail Panel

    @ViewBuilder
    private var detailPanel: some View {
        if store.projects.isEmpty {
            onboardingView
        } else if let project = store.selectedProject {
            projectDetail(project)
        } else {
            ContentUnavailableView(
                "Select a Project",
                systemImage: "hammer",
                description: Text("Choose a project from the list to manage its services and packages.")
            )
        }
    }

    // MARK: - Onboarding

    private var onboardingView: some View {
        VStack(spacing: 24) {
            Image(systemName: "hammer.circle")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Project Environments")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Define which Homebrew services and packages each of your projects needs. Activate a project to start all its services at once.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            VStack(alignment: .leading, spacing: 12) {
                featureRow(
                    icon: "gearshape.2",
                    color: .blue,
                    title: "Service Management",
                    description: "Assign brew services (PostgreSQL, Redis, etc.) to a project and start/stop them together."
                )
                featureRow(
                    icon: "terminal",
                    color: .green,
                    title: "Package Tracking",
                    description: "List the formulae your project requires and check if any are missing."
                )
                featureRow(
                    icon: "play.circle",
                    color: .orange,
                    title: "One-Click Activation",
                    description: "Activate a project to start all its services. Deactivate to stop them when you're done."
                )
            }
            .frame(maxWidth: 420)

            Button {
                newProjectName = ""
                newProjectPath = ""
                isAddingProject = true
            } label: {
                Label("Create Your First Project", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func featureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Project Detail

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
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.1), in: Circle())

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

    private func projectDetailBody(_ project: ProjectEnvironment) -> some View {
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
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text(name)
                                .fontWeight(.medium)
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Label("Missing Packages", systemImage: "exclamationmark.triangle.fill")
                        Text("\(missingPackages.count)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.15), in: Capsule())
                    }
                    .foregroundStyle(.orange)
                }
            }

            // Services section
            Section {
                if project.services.isEmpty {
                    HStack(spacing: 8) {
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
                    HStack(spacing: 8) {
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
                autoStartToggle(for: project)
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
            .help("Add a brew service to this project")

            Button {
                newPackageName = ""
                isAddingPackage = true
            } label: {
                Label("Add Package", systemImage: "plus.square")
            }
            .disabled(store.selectedProject == nil)
            .help("Add a required formula to this project")

            Button {
                guard let project = store.selectedProject else { return }
                Task {
                    missingPackages = await store.checkMissingPackages(project)
                }
            } label: {
                Label("Check Packages", systemImage: "checkmark.circle")
            }
            .disabled(store.selectedProject == nil || store.isLoading)
            .help("Check which required packages are not installed")
        }
    }

    // MARK: - Add Project Sheet

    private var addProjectSheet: some View {
        VStack(spacing: 16) {
            Text("New Project")
                .font(.headline)

            Text("Define a project environment to group related brew services and packages together.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Form {
                TextField("Name", text: $newProjectName, prompt: Text("e.g. My Web App"))
                TextField("Path", text: $newProjectPath, prompt: Text("e.g. /Users/you/Projects/myapp"))
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
        .frame(width: 440)
    }

    // MARK: - Add Service Sheet

    private var addServiceSheet: some View {
        VStack(spacing: 16) {
            Text("Add Service")
                .font(.headline)

            Text("Enter the name of a brew service this project needs running.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Form {
                TextField("Service Name", text: $newServiceName, prompt: Text("e.g. postgresql@16"))
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
        .frame(width: 400)
    }

    // MARK: - Add Package Sheet

    private var addPackageSheet: some View {
        VStack(spacing: 16) {
            Text("Add Package")
                .font(.headline)

            Text("Enter the name of a formula this project depends on.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Form {
                TextField("Formula Name", text: $newPackageName, prompt: Text("e.g. node"))
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
        .frame(width: 400)
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
