import SwiftUI

/// The pages with an inspector; each remembers its visibility and width.
enum InspectorPage: String {
    case package
    case service
    case tap
    case dependency
}

/// A page's inspector that the user can show or hide from the toolbar and
/// resize; the width is remembered across launches.
struct PageInspector<Inspector: View>: ViewModifier {
    @Binding var isPresented: Bool
    /// `false` hides the inspector without changing the user's choice —
    /// for pages whose inspector only shows a selection.
    let hasContent: Bool
    @ViewBuilder let inspector: Inspector
    @AppStorage private var width: Double

    private static var minWidth: Double { 320 }
    private static var maxWidth: Double { 560 }

    init(page: InspectorPage, isPresented: Binding<Bool>, hasContent: Bool, @ViewBuilder inspector: () -> Inspector) {
        _isPresented = isPresented
        self.hasContent = hasContent
        _width = AppStorage(wrappedValue: 380, SettingsKey.inspectorWidth(page))
        self.inspector = inspector()
    }

    private var isShown: Bool { isPresented && hasContent }

    func body(content: Content) -> some View {
        content
            .inspector(isPresented: Binding(get: { isShown }, set: { isPresented = $0 })) {
                inspector
                    .inspectorColumnWidth(min: Self.minWidth, ideal: width, max: Self.maxWidth)
                    .onGeometryChange(for: Double.self) { $0.size.width } action: { newWidth in
                        if newWidth >= Self.minWidth { width = newWidth }
                    }
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
        _ page: InspectorPage,
        isPresented: Binding<Bool>,
        hasContent: Bool = true,
        @ViewBuilder inspector: () -> Inspector
    ) -> some View {
        modifier(PageInspector(page: page, isPresented: isPresented, hasContent: hasContent, inspector: inspector))
    }
}

#Preview {
    @Previewable @State var isPresented = true

    NavigationStack {
        Text("Content")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .pageInspector(.tap, isPresented: $isPresented) {
                Text("Inspector")
            }
    }
    .frame(width: 700, height: 400)
}
