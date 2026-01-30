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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
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
            .padding(24)
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
        VStack(alignment: .leading, spacing: 8) {
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

    private var badges: [PackageBadge] {
        var result: [PackageBadge] = []
        if package.isOutdated {
            result.append(PackageBadge(text: "Outdated", color: .orange, icon: "arrow.triangle.2.circlepath"))
        }
        if package.isDeprecated {
            result.append(PackageBadge(text: "Deprecated", color: .red, icon: "exclamationmark.triangle"))
        }
        if case .formula(let formula) = package {
            if formula.pinned {
                result.append(PackageBadge(text: "Pinned", color: .blue, icon: "pin.fill"))
            }
            if formula.isKegOnly {
                result.append(PackageBadge(text: "Keg-only", color: .purple, icon: "shippingbox"))
            }
            if formula.disabled {
                result.append(PackageBadge(text: "Disabled", color: .gray, icon: "xmark.circle"))
            }
        }
        return result
    }

    private var badgeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(badges, id: \.text) { badge in
                    Label(badge.text, systemImage: badge.icon)
                        .font(.callout)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(badge.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(badge.color)
                }
            }
        }
    }

    // MARK: - Dependencies

    private func dependenciesSection(_ dependencies: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dependencies")
                .font(.headline)

            FlowLayout(spacing: 6) {
                ForEach(dependencies, id: \.self) { dep in
                    Text(dep)
                        .font(.callout)
                        .fontDesign(.monospaced)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private func runtimeDependenciesSection(_ dependencies: [RuntimeDependency]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Runtime Dependencies")
                .font(.headline)

            FlowLayout(spacing: 6) {
                ForEach(dependencies, id: \.fullName) { dep in
                    HStack(spacing: 4) {
                        Text(dep.fullName)
                            .fontWeight(.medium)
                        Text(dep.version)
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                    .fontDesign(.monospaced)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)

            HStack(spacing: 12) {
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

// MARK: - PackageBadge

private struct PackageBadge {
    let text: String
    let color: Color
    let icon: String
}

// MARK: - FlowLayout

/// A simple horizontal wrapping layout for tags and badges.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return ArrangeResult(
            positions: positions,
            size: CGSize(width: totalWidth, height: currentY + lineHeight)
        )
    }

    private struct ArrangeResult {
        let positions: [CGPoint]
        let size: CGSize
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
