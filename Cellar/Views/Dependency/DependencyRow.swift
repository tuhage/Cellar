import SwiftUI
import CellarCore

/// A package in the dependency list: why it's installed, how connected it
/// is, and — while searching dependencies — which of them matched.
struct DependencyRow: View {
    let node: DependencyNode
    let graph: DependencyGraph
    /// What made the row match the search, in `scope`.
    let matches: [String]
    let scope: DependencySearchScope

    var body: some View {
        HStack(spacing: Spacing.row) {
            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Text(node.name)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            DependencyBadges(node: node, graph: graph)
        }
        .padding(.vertical, Spacing.compact)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        switch scope {
        case .dependsOn where !matches.isEmpty:
            "Depends on \(matches.briefList(limit: 3))"
        case .usedBy where !matches.isEmpty:
            "Used by \(matches.briefList(limit: 3))"
        default:
            node.connectionSummary
        }
    }
}

// MARK: - DependencyBadges

/// Why a package is installed, as text badges rather than colors alone.
struct DependencyBadges: View {
    let node: DependencyNode
    let graph: DependencyGraph

    var body: some View {
        HStack(spacing: Spacing.related) {
            if graph.isRemovable(node) {
                StatusBadge(text: "Removable", color: .orange, icon: "minus.circle")
            }
            if graph.isRequested(node.name) {
                StatusBadge(text: "Installed by You", color: .blue, icon: "person")
            } else {
                StatusBadge(text: "Dependency", color: .secondary, icon: "link")
            }
        }
    }
}

// MARK: - Summary

extension DependencyNode {
    /// "Needs 4 · Used by 2".
    var connectionSummary: String {
        let needs = dependencies.isEmpty ? "No dependencies" : "Needs \(dependencies.count)"
        let usedBy = dependents.isEmpty ? "nothing needs it" : "used by \(dependents.count)"
        return "\(needs) · \(usedBy)"
    }
}

// MARK: - Preview

#Preview {
    let graph = DependencyGraph.preview

    List(graph.nodes) { node in
        DependencyRow(node: node, graph: graph, matches: [], scope: .name)
    }
    .frame(width: 480, height: 500)
}
