import SwiftUI

/// A sheet that displays streaming process output with a dismiss button.
///
/// Used by `FormulaListView` and `CaskListView` to show install progress.
/// The sheet presents a `ProcessOutputView` with a "Done" button that
/// clears the stream and triggers a reload callback.
struct InstallProgressSheet: ViewModifier {
    @Binding var stream: AsyncThrowingStream<String, Error>?
    @Binding var title: String?
    var onDismiss: () -> Void

    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(
            get: { stream != nil },
            set: { if !$0 { dismiss() } }
        )) {
            if let stream {
                VStack(spacing: 0) {
                    ProcessOutputView(
                        title: title ?? "Installing",
                        stream: stream
                    )

                    Divider()

                    HStack {
                        Spacer()
                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding()
                }
                .frame(minWidth: 500, minHeight: 350)
                .presentationBackground(.ultraThinMaterial)
            }
        }
    }

    private func dismiss() {
        stream = nil
        title = nil
        onDismiss()
    }
}

extension View {
    func installProgressSheet(
        stream: Binding<AsyncThrowingStream<String, Error>?>,
        title: Binding<String?>,
        onDismiss: @escaping () -> Void
    ) -> some View {
        modifier(InstallProgressSheet(stream: stream, title: title, onDismiss: onDismiss))
    }
}

#Preview {
    Text("Background Content")
        .installProgressSheet(
            stream: .constant(nil),
            title: .constant(nil),
            onDismiss: {}
        )
}
