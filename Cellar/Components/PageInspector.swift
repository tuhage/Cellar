import SwiftUI

/// The pages with an inspector; each remembers whether it is shown.
enum InspectorPage: String {
    case package
    case service
    case tap
    case dependency
}

/// A page's inspector that the user can show or hide from the toolbar.
///
/// Its width isn't remembered: reading the inspector's geometry to save it
/// made macOS squeeze the column below its minimum width.
struct PageInspector<Inspector: View>: ViewModifier {
    @Binding var isPresented: Bool
    /// `false` hides the inspector without changing the user's choice —
    /// for pages whose inspector only shows a selection.
    let hasContent: Bool
    @ViewBuilder let inspector: Inspector

    private var isShown: Bool { isPresented && hasContent }

    func body(content: Content) -> some View {
        content
            .operationNotice()
            .inspector(isPresented: Binding(get: { isShown }, set: { isPresented = $0 })) {
                inspector
                    .inspectorColumnWidth(min: 320, ideal: 400, max: WindowSize.readableWidth)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresented = !isShown
                    } label: {
                        Label(isShown ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.trailing")
                    }
                    .help(isShown ? "Hide Inspector" : "Show Inspector")
                }
            }
    }
}

extension View {
    func pageInspector<Inspector: View>(
        isPresented: Binding<Bool>,
        hasContent: Bool = true,
        @ViewBuilder inspector: () -> Inspector
    ) -> some View {
        modifier(PageInspector(isPresented: isPresented, hasContent: hasContent, inspector: inspector))
    }
}

#Preview {
    @Previewable @State var isPresented = true

    NavigationStack {
        Text("Content")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .pageInspector(isPresented: $isPresented) {
                Text("Inspector")
            }
    }
    .frame(width: 700, height: 400)
}
