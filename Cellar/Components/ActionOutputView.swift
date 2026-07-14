import SwiftUI

/// Displays streaming process output with a "Done" button at the bottom.
///
/// Used by DashboardView and BrewfileView to show progress
/// for long-running brew operations (upgrade, cleanup, install).
struct ActionOutputView: View {
    let title: String
    let stream: AsyncThrowingStream<String, Error>
    let onDismiss: () -> Void
    @State private var isComplete = false

    var body: some View {
        VStack(spacing: 0) {
            ProcessOutputView(
                title: title,
                stream: stream,
                onCompletion: { isComplete = true }
            )

            Divider()

            HStack {
                Spacer()
                Button("Done", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isComplete)
            }
            .padding()
            .background {
                Rectangle()
                    .fill(.background)
                    .shadow(color: Shadow.subtleColor, radius: Shadow.subtleBlur, y: -Shadow.subtleY)
            }
        }
    }
}

#Preview {
    ActionOutputView(
        title: "Running Operation",
        stream: AsyncThrowingStream { $0.finish() },
        onDismiss: {}
    )
    .frame(width: 500, height: 350)
}
