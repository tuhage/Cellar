import SwiftUI

/// A `ForEach` variant that inserts `Divider()` between each row.
///
/// Eliminates the common `Array(items.enumerated())` pattern used to
/// manually insert dividers between items in `GroupBox` or `VStack` layouts.
struct DividedForEach<Data: RandomAccessCollection, Content: View>: View
where Data.Element: Identifiable {
    let data: Data
    @ViewBuilder let content: (Data.Element) -> Content

    var body: some View {
        ForEach(Array(data.enumerated()), id: \.element.id) { index, element in
            content(element)

            if index < data.count - 1 {
                Divider()
            }
        }
    }
}

#Preview {
    struct Item: Identifiable {
        let id: Int
        let name: String
    }

    let items = [
        Item(id: 1, name: "First"),
        Item(id: 2, name: "Second"),
        Item(id: 3, name: "Third"),
    ]

    return GroupBox {
        VStack(spacing: 0) {
            DividedForEach(data: items) { item in
                Text(item.name)
                    .padding(.vertical, 6)
            }
        }
    }
    .padding()
    .frame(width: 300)
}
