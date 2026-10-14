import SwiftUI

/// A page's inspector that the user can show or hide from the toolbar and
/// resize; the width is remembered across launches under `widthKey`.
struct PageInspector<Inspector: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder let inspector: Inspector
    @AppStorage private var width: Double

    private static var minWidth: Double { 280 }
    private static var maxWidth: Double { 560 }

    init(isPresented: Binding<Bool>, widthKey: String, @ViewBuilder inspector: () -> Inspector) {
        _isPresented = isPresented
        _width = AppStorage(wrappedValue: 360, widthKey)
        self.inspector = inspector()
    }

    func body(content: Content) -> some View {
        content
            .inspector(isPresented: $isPresented) {
                inspector
                    .inspectorColumnWidth(min: Self.minWidth, ideal: width, max: Self.maxWidth)
                    .onGeometryChange(for: Double.self) { $0.size.width } action: { newWidth in
                        if newWidth >= Self.minWidth { width = newWidth }
                    }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresented.toggle()
                    } label: {
                        Label(isPresented ? "Hide Inspector" : "Show Inspector", systemImage: "sidebar.trailing")
                    }
                    .help(isPresented ? "Hide Inspector" : "Show Inspector")
                }
            }
    }
}

extension View {
    func pageInspector<Inspector: View>(
        isPresented: Binding<Bool>,
        widthKey: String,
        @ViewBuilder inspector: () -> Inspector
    ) -> some View {
        modifier(PageInspector(isPresented: isPresented, widthKey: widthKey, inspector: inspector))
    }
}

#Preview {
    @Previewable @State var isPresented = true

    NavigationStack {
        Text("Content")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .pageInspector(isPresented: $isPresented, widthKey: "previewInspectorWidth") {
                Text("Inspector")
            }
    }
    .frame(width: 700, height: 400)
}
