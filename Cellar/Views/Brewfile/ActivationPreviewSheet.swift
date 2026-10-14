import SwiftUI
import CellarCore

/// Shows which services activating a project will start and stop before
/// anything happens.
struct ActivationPreviewSheet: View {
    let project: Brewfile

    @Environment(BrewfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.registersProjectServicesAtLogin) private var registerAtLogin = false

    var body: some View {
        let plan = store.activationPlan(for: project)

        VStack(alignment: .leading, spacing: Spacing.sectionContent) {
            Text("Activate \(project.name)?")
                .font(.headline)

            VStack(alignment: .leading, spacing: Spacing.item) {
                if plan.changesNothing {
                    Text("All of this project’s services are already running, so nothing needs to start.")
                        .foregroundStyle(.secondary)
                }
                planRow("Will start", plan.toStart, systemImage: "play.circle", tint: .green)
                planRow(
                    plan.previousProjectName.map { "Will stop (started for \($0))" } ?? "Will stop",
                    plan.toStop,
                    systemImage: "stop.circle",
                    tint: .orange
                )
                planRow("Already running, left running on deactivate", plan.alreadyRunning, systemImage: "checkmark.circle", tint: .secondary)
            }

            if !plan.toStart.isEmpty {
                Picker("Start services", selection: $registerAtLogin) {
                    Text("For this session only").tag(false)
                    Text("At every login").tag(true)
                }
                .pickerStyle(.radioGroup)
                Text(registerAtLogin
                     ? "Uses brew services start: the services also start when you log in, until stopped."
                     : "Uses brew services run: the services stop when you log out or deactivate.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Activate") {
                    Task { await store.activate(project, plan: plan, registerAtLogin: registerAtLogin) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Spacing.section)
        .frame(width: WindowSize.narrowWidth)
    }

    @ViewBuilder
    private func planRow(_ title: String, _ names: [String], systemImage: String, tint: Color) -> some View {
        if !names.isEmpty {
            Label {
                VStack(alignment: .leading, spacing: Spacing.textPair) {
                    Text(title)
                        .font(.callout.weight(.medium))
                    Text(names.formatted(.list(type: .and)))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
            }
        }
    }
}

#Preview {
    ActivationPreviewSheet(project: .preview)
        .environment(AppStores())
}
