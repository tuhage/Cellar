import SwiftUI

/// A page's filter: segmented while it fits, a pop-up menu when the page is
/// narrow. A segmented control can't shrink below its labels, and a page
/// that can't fit beside its inspector makes the window grow or, when it
/// can't, sends the split view into a layout loop.
struct FilterPicker<Value: Hashable, Options: View>: View {
    let title: String
    @Binding var selection: Value
    @ViewBuilder let options: Options

    var body: some View {
        ViewThatFits(in: .horizontal) {
            picker
                .pickerStyle(.segmented)
                .fixedSize()
            picker
                .pickerStyle(.menu)
                .fixedSize()
        }
    }

    private var picker: some View {
        Picker(title, selection: $selection) {
            options
        }
        .labelsHidden()
    }
}

#Preview {
    @Previewable @State var selection = "All"
    let options = ["All", "Outdated", "Pinned", "Installed by Me", "Dependencies"]

    VStack(alignment: .leading, spacing: Spacing.section) {
        FilterPicker(title: "Filter", selection: $selection) {
            ForEach(options, id: \.self) { Text($0).tag($0) }
        }
        .frame(width: 600, alignment: .leading)

        FilterPicker(title: "Filter", selection: $selection) {
            ForEach(options, id: \.self) { Text($0).tag($0) }
        }
        .frame(width: 240, alignment: .leading)
    }
    .padding()
}
