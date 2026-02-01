import SwiftUI

/// A section header displaying a label with a trailing count badge.
///
/// Used in list sections across FormulaListView, CaskListView, SearchView,
/// and OutdatedView to show section titles with item counts.
struct CountedSectionHeader: View {
    let title: String
    let systemImage: String
    let count: Int

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }
}

#Preview {
    List {
        Section {
            Text("Item 1")
            Text("Item 2")
        } header: {
            CountedSectionHeader(title: "Installed", systemImage: "checkmark.circle.fill", count: 2)
        }

        Section {
            Text("Item 1")
        } header: {
            CountedSectionHeader(title: "Available", systemImage: "arrow.down.circle", count: 1)
        }
    }
    .frame(width: 400, height: 300)
}
