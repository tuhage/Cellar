import Cocoa
import FinderSync
import CellarCore

final class CellarFinderSyncExtension: FIFinderSync {
    private static let stopServiceNotification = Notification.Name("com.tuhage.Cellar.stopService")
    private static let brewfileBadgeIdentifier = "brewfile"
    private static let bundleIdentifier = "com.tuhage.Cellar"

    private let monitoredPaths: [URL] = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Projects"),
            home.appendingPathComponent("Developer"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Documents"),
        ].filter { FileManager.default.fileExists(atPath: $0.path) }
    }()

    override init() {
        super.init()

        let controller = FIFinderSyncController.default()
        controller.directoryURLs = Set(monitoredPaths)

        if let badgeImage = NSImage(systemSymbolName: "mug.fill", accessibilityDescription: "Brewfile") {
            controller.setBadgeImage(badgeImage, label: "Brewfile", forBadgeIdentifier: Self.brewfileBadgeIdentifier)
        }
    }

    // MARK: - Badges

    override func requestBadgeIdentifier(for url: URL) {
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("Brewfile").path) else { return }
        FIFinderSyncController.default().setBadgeIdentifier(Self.brewfileBadgeIdentifier, for: url)
    }

    // MARK: - Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems || menuKind == .contextualMenuForContainer else {
            return nil
        }

        let menu = NSMenu(title: "Cellar")
        let serviceNames = WidgetSnapshot.load()?.runningServiceNames ?? []

        if serviceNames.isEmpty {
            let item = NSMenuItem(title: "No services running", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for name in serviceNames {
                let stopItem = NSMenuItem(
                    title: "Stop \(name)",
                    action: #selector(stopServiceAction(_:)),
                    keyEquivalent: ""
                )
                stopItem.representedObject = name
                stopItem.target = self
                menu.addItem(stopItem)
            }
        }

        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "Open Cellar", action: #selector(openCellarAction(_:)), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        return menu
    }

    // MARK: - Actions

    @objc private func stopServiceAction(_ sender: NSMenuItem) {
        guard let serviceName = sender.representedObject as? String else { return }
        DistributedNotificationCenter.default().postNotificationName(
            Self.stopServiceNotification,
            object: nil,
            userInfo: ["serviceName": serviceName],
            deliverImmediately: true
        )
    }

    @objc private func openCellarAction(_ sender: NSMenuItem) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleIdentifier) else {
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }
}
