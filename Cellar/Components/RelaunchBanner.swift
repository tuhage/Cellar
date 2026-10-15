import SwiftUI

/// Offers to relaunch Cellar after brew upgraded it while it ran, so the new
/// version takes over. Shows nothing otherwise.
struct RelaunchBanner: View {
    @Environment(UpdateStore.self) private var updateStore
    @Environment(ActivityStore.self) private var activityStore

    var body: some View {
        if let version = updateStore.versionAwaitingRelaunch {
            let isBusy = activityStore.runningCount > 0

            NoticeBanner(
                tint: .blue,
                systemImage: "arrow.triangle.2.circlepath.circle.fill",
                title: "Cellar \(version) is installed",
                message: "Relaunch Cellar to start using it."
            ) {
                Button("Relaunch") { updateStore.relaunch() }
                    .disabled(isBusy)
                    .help(isBusy ? "Available when running operations finish" : "Quit and reopen Cellar")
            }
        }
    }
}

#Preview {
    RelaunchBanner()
        .environment(AppStores())
        .frame(width: 600)
}
