import SwiftUI
import CellarCore

/// A project's services with their live status, as reported by the
/// service list rather than by what Cellar last did.
struct ProjectServicesSection: View {
    let project: Brewfile
    @Binding var sheet: BrewfileSheet?

    @Environment(BrewfileStore.self) private var store
    @Environment(ServiceStore.self) private var serviceStore

    private var startedByCellar: Set<String> {
        Set(store.servicesToStopOnDeactivation(of: project))
    }

    var body: some View {
        Section {
            if project.services.isEmpty {
                HStack {
                    Text("Add the services this project needs, such as a database, to start them together.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Add Services\u{2026}") { sheet = .addServices(project) }
                }
            }
            ForEach(project.services, id: \.self) { name in
                row(for: name)
            }
        } header: {
            CountedSectionHeader(title: "Services", systemImage: "gearshape.2", count: project.services.count)
        } footer: {
            if !project.services.isEmpty {
                Text(store.isActivated(project)
                     ? "Deactivate stops only the services Cellar started for this project."
                     : "Activate starts these services together. Ones already running are left running when you deactivate.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func row(for name: String) -> some View {
        let service = serviceStore.services.first { $0.name == name }

        return HStack(spacing: Spacing.item) {
            Text(name)
            if startedByCellar.contains(name) {
                Text("Started by Cellar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let service {
                StatusDotLabel(text: service.isRunning ? "Running" : "Stopped", color: service.status.color)
                    .font(.callout)
            } else {
                StatusBadge(text: "Not Installed", color: .orange, icon: "exclamationmark.triangle")
            }
            Button {
                store.removeService(name, from: project)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove \(name) from \(project.name)")
            .help("Remove \(name) from this project; the service itself isn’t changed")
        }
        .contextMenu {
            Button("Remove from Project", systemImage: "minus.circle") {
                store.removeService(name, from: project)
            }
        }
    }
}

#Preview {
    List {
        ProjectServicesSection(project: .preview, sheet: .constant(nil))
    }
    .environment(AppStores())
    .frame(width: 600, height: 300)
}
