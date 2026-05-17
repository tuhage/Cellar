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
            .padding(Spacing.item)
        }
    }

    private var emptyProjectList: some View {
        VStack(spacing: Spacing.item) {
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
        HStack(spacing: Spacing.row) {
            Circle()
                .fill(store.activeProjectId == project.id ? .green : .clear)
                .frame(width: IconSize.statusDot, height: IconSize.statusDot)
                .overlay {
                    if store.activeProjectId == project.id {
                        Circle()
                            .fill(.green.opacity(0.4))
                            .frame(width: IconSize.dotGlow, height: IconSize.dotGlow)
                    }
                }

            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Text(project.name)
                    .fontWeight(.medium)

                HStack(spacing: Spacing.related) {
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
            ProjectDetailView(project: project, missingPackages: $missingPackages)
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
        VStack(spacing: Spacing.section) {
            Image(systemName: "hammer.circle")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            VStack(spacing: Spacing.item) {
                Text("Project Environments")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Define which Homebrew services and packages each of your projects needs. Activate a project to start all its services at once.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: WindowSize.narrowSheet)
            }

            VStack(alignment: .leading, spacing: Spacing.sectionContent) {
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
            .frame(maxWidth: WindowSize.narrowSheet)

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
        HStack(alignment: .top, spacing: Spacing.sectionContent) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: IconSize.smallIcon, alignment: .center)

            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
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
        VStack(spacing: Spacing.cardPadding) {
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
        VStack(spacing: Spacing.cardPadding) {
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
        .frame(width: WindowSize.addItemSheet)
    }

    // MARK: - Add Package Sheet

    private var addPackageSheet: some View {
        VStack(spacing: Spacing.cardPadding) {
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
        .frame(width: WindowSize.addItemSheet)
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
