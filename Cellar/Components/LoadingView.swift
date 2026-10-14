import SwiftUI

/// Full-page loading state. After a while it explains why brew may be slow
/// and offers Activity, so a stuck load never looks like a frozen app.
struct LoadingView: View {
    var message: String = "Loading\u{2026}"

    @State private var isSlow = false

    private static let slowThreshold: Duration = .seconds(10)

    var body: some View {
        VStack(spacing: Spacing.sectionContent) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .foregroundStyle(.secondary)

            if isSlow {
                VStack(spacing: Spacing.item) {
                    Text("Still working. brew can be slow the first time, or while another brew command runs.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Show Activity") {
                        NotificationCenter.default.post(name: .openActivityPanel, object: nil)
                    }
                }
                .frame(maxWidth: 360)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(AnimationToken.gentle, value: isSlow)
        .transition(.opacity)
        .task {
            try? await Task.sleep(for: Self.slowThreshold)
            isSlow = !Task.isCancelled
        }
    }
}

#Preview {
    LoadingView(message: "Loading Formulae\u{2026}")
}
