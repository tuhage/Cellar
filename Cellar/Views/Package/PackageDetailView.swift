import SwiftUI
import CellarCore

// MARK: - PackageType

enum PackageType: Hashable, Sendable {
    case formula(Formula)
    case cask(Cask)

    var name: String {
        switch self {
        case .formula(let formula): formula.name
        case .cask(let cask): cask.displayName
        }
    }

    var identifier: String {
        switch self {
        case .formula(let formula): formula.name
        case .cask(let cask): cask.token
        }
    }

    var version: String {
        switch self {
        case .formula(let formula): formula.version
        case .cask(let cask): cask.installed ?? cask.version
        }
    }

    var description: String? {
        switch self {
        case .formula(let formula): formula.desc
        case .cask(let cask): cask.desc
        }
    }

    var homepage: String? {
        switch self {
        case .formula(let formula): formula.homepage
        case .cask(let cask): cask.homepage
        }
    }

    var isOutdated: Bool {
        switch self {
        case .formula(let formula): formula.outdated
        case .cask(let cask): cask.outdated
        }
    }

    var isDeprecated: Bool {
        switch self {
        case .formula(let formula): formula.deprecated
        case .cask(let cask): cask.deprecated
        }
    }
}

// MARK: - PackageDetailView

struct PackageDetailView: View {
    let package: PackageType

    @Environment(PackageStore.self) private var store
    @State private var isPerformingAction = false
    @State private var actionError: String?

    private var packageIcon: String {
        switch package {
        case .formula: "terminal"
        case .cask: "macwindow"
        }
    }

    private var packageColor: Color {
        switch package {
        case .formula: .blue
        case .cask: .purple
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                headerSection
                Divider()
                infoSection
                if !badges.isEmpty {
                    Divider()
                    badgeSection
                }
                if case .formula(let formula) = package, !formula.dependencies.isEmpty {
                    Divider()
                    dependenciesSection(formula.dependencies)
                }
                if case .formula(let formula) = package, !formula.runtimeDependencies.isEmpty {
                    Divider()
                    runtimeDependenciesSection(formula.runtimeDependencies)
                }
                Divider()
                actionsSection
            }
            .padding(Spacing.section)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(package.name)
        .alert("Error", isPresented: .init(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK") { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: Spacing.detailElement) {
            Image(systemName: packageIcon)
                .font(.title2)
                .foregroundStyle(packageColor)
                .frame(width: IconSize.headerIcon, height: IconSize.headerIcon)
                .background(packageColor.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: Spacing.related) {
                HStack(alignment: .firstTextBaseline) {
                    Text(package.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(package.version)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fontDesign(.monospaced)
                }

                if let description = package.description {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 10) {
            GridRow {
                Text("Identifier")
                    .foregroundStyle(.secondary)
                    .gridColumnAlignment(.trailing)
                Text(package.identifier)
                    .textSelection(.enabled)
                    .fontDesign(.monospaced)
            }

            GridRow {
                Text("Version")
                    .foregroundStyle(.secondary)
                Text(package.version)
                    .textSelection(.enabled)
                    .fontDesign(.monospaced)
            }

            if let homepage = package.homepage, let url = URL(string: homepage) {
                GridRow {
                    Text("Homepage")
                        .foregroundStyle(.secondary)
                    Link(homepage, destination: url)
                        .lineLimit(1)
                        .tint(.blue)
                }
            }

            if case .formula(let formula) = package {
                GridRow {
                    Text("License")
                        .foregroundStyle(.secondary)
                    Text(formula.license ?? "Unknown")
                }

                if let installTime = formula.installTime {
                    GridRow {
                        Text("Installed")
                            .foregroundStyle(.secondary)
                        Text(installTime, style: .date)
                    }
                }

                GridRow {
                    Text("Installed by")
                        .foregroundStyle(.secondary)
                    Text(formula.installedOnRequest ? "Request" : "Dependency")
                }
            }

            if case .cask(let cask) = package {
                GridRow {
                    Text("Auto Updates")
                        .foregroundStyle(.secondary)
                    Text(cask.autoUpdates ? "Yes" : "No")
                }
            }
        }
        .font(.body)
    }

    // MARK: - Badges

    private var badges: [(text: String, color: Color, icon: String)] {
        var result: [(text: String, color: Color, icon: String)] = []
        if package.isOutdated {
            result.append(("Outdated", .orange, "arrow.triangle.2.circlepath"))
        }
        if package.isDeprecated {
            result.append(("Deprecated", .red, "exclamationmark.triangle"))
        }
        if case .formula(let formula) = package {
            if formula.pinned {
                result.append(("Pinned", .blue, "pin.fill"))
            }
            if formula.isKegOnly {
                result.append(("Keg-only", .purple, "shippingbox"))
            }
            if formula.disabled {
                result.append(("Disabled", .gray, "xmark.circle"))
            }
        }
        return result
    }

    private var badgeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.item) {
            Text("Status")
                .font(.headline)

            HStack(spacing: Spacing.item) {
                ForEach(badges, id: \.text) { badge in
                    StatusBadge(text: badge.text, color: badge.color, icon: badge.icon)
                }
            }
        }
    }

    // MARK: - Dependencies

    private func dependenciesSection(_ dependencies: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.item) {
            Text("Dependencies")
                .font(.headline)

            FlowLayout(spacing: Spacing.related) {
                ForEach(dependencies, id: \.self) { dep in
                    Text(dep)
                        .font(.callout)
                        .fontDesign(.monospaced)
                        .chipInset()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: CornerRadius.small))
                }
            }
        }
    }

    private func runtimeDependenciesSection(_ dependencies: [RuntimeDependency]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.item) {
            Text("Runtime Dependencies")
                .font(.headline)

            FlowLayout(spacing: Spacing.related) {
                ForEach(dependencies, id: \.fullName) { dep in
                    HStack(spacing: Spacing.compact) {
                        Text(dep.fullName)
                            .fontWeight(.medium)
                        Text(dep.version)
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                    .fontDesign(.monospaced)
                    .chipInset()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: CornerRadius.small))
                }
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionContent) {
            Text("Actions")
                .font(.headline)

            HStack(spacing: Spacing.sectionContent) {
                if package.isOutdated {
                    Button {
                        performAction {
                            switch package {
                                case .formula(let f): await store.upgrade(f)
                                case .cask(let c): await store.upgrade(c)
                                }
                        }
                    } label: {
                        Label("Upgrade", systemImage: "arrow.up.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }

                if case .formula(let formula) = package {
                    if formula.pinned {
                        Button {
                            performAction {
                                await store.unpin(formula)
                            }
                        } label: {
                            Label("Unpin", systemImage: "pin.slash")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button {
                            performAction {
                                await store.pin(formula)
                            }
                        } label: {
                            Label("Pin", systemImage: "pin")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Button(role: .destructive) {
                    performAction {
                        switch package {
                            case .formula(let f): await store.uninstall(f)
                            case .cask(let c): await store.uninstall(c)
                            }
                    }
                } label: {
                    Label("Uninstall", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .disabled(isPerformingAction)

            if isPerformingAction {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Helpers

    private func performAction(_ action: @escaping () async -> Void) {
        isPerformingAction = true
        Task {
            await action()
            isPerformingAction = false
            if let error = store.errorMessage {
                actionError = error
            }
        }
    }
}

// MARK: - Preview

#Preview("Formula Detail") {
    NavigationStack {
        PackageDetailView(package: .formula(Formula.preview))
            .environment(PackageStore())
    }
    .frame(width: 600, height: 700)
}

#Preview("Cask Detail") {
    NavigationStack {
        PackageDetailView(package: .cask(Cask.preview))
            .environment(PackageStore())
    }
    .frame(width: 600, height: 700)
}
