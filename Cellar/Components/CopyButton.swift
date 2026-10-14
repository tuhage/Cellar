import SwiftUI
import AppKit

/// Copies text, then shows "Copied" with a checkmark for a moment. Add
/// `.labelStyle(.iconOnly)` for a compact button; the title stays its
/// VoiceOver label.
struct CopyButton: View {
    let text: String
    var title = "Copy"

    @State private var isCopied = false

    private static let feedbackDuration: Duration = .seconds(2)

    var body: some View {
        Button {
            NSPasteboard.copy(text)
            isCopied = true
        } label: {
            Label(isCopied ? "Copied" : title, systemImage: isCopied ? "checkmark" : "doc.on.doc")
                .contentTransition(.symbolEffect(.replace))
        }
        .help(isCopied ? "Copied" : title)
        .task(id: isCopied) {
            guard isCopied else { return }
            try? await Task.sleep(for: Self.feedbackDuration)
            isCopied = false
        }
    }
}

#Preview {
    HStack {
        CopyButton(text: "brew install wget")
        CopyButton(text: "brew install wget", title: "Copy Command")
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
    }
    .padding()
}
