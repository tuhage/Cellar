import SwiftUI

/// A generic skeleton/placeholder list shown while data is loading.
///
/// Displays a configurable number of rows using the provided content closure,
/// wrapped with `.redacted(reason: .placeholder)` for a shimmer effect.
/// The content should mimic the layout of the real data rows.
struct SkeletonListView<Row: View>: View {
    var rowCount: Int = 8
    @ViewBuilder var row: () -> Row

    var body: some View {
        List {
            ForEach(0..<rowCount, id: \.self) { _ in
                row()
            }
        }
        .redacted(reason: .placeholder)
        .disabled(true)
    }
}

#Preview {
    SkeletonListView {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("package-name")
                    .fontWeight(.medium)
                Text("A short description of the package")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("1.0.0")
                .font(.body.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
