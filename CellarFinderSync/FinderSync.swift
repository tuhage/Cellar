import Cocoa
import FinderSync
import CellarCore

final class CellarFinderSyncExtension: FIFinderSync {
    private static let stopServiceNotification = Notification.Name("com.tuhage.Cellar.stopService")
    private static let startServiceNotification = Notification.Name("com.tuhage.Cellar.startService")
    private static let brewfileBadgeIdentifier = "brewfile"
    private static let bundleIdentifier = "com.tuhage.Cellar"

    override init() {
        super.init()

        let paths = AppGroupStorage.finderSyncPaths
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }

        let controller = FIFinderSyncController.default()
        controller.directoryURLs = Set(paths)

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

        if let brewfileURL = targetedBrewfileURL(for: menuKind) {
            let openItem = NSMenuItem(
                title: "Open in Cellar",
                action: #selector(openBrewfileAction(_:)),
                keyEquivalent: ""
            )
            openItem.representedObject = brewfileURL
            openItem.target = self
            menu.addItem(openItem)
            menu.addItem(.separator())
        }

        let snapshot = WidgetSnapshot.load()
        let runningNames = snapshot?.runningServiceNames ?? []
        let stoppedNames = snapshot?.stoppedServiceNames ?? []

        if runningNames.isEmpty && stoppedNames.isEmpty {
            let item = NSMenuItem(title: "No services available", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for name in runningNames {
                let stopItem = NSMenuItem(
                    title: "Stop \(name)",
                    action: #selector(stopServiceAction(_:)),
                    keyEquivalent: ""
                )
                stopItem.representedObject = name
                stopItem.target = self
                menu.addItem(stopItem)
            }

            if !runningNames.isEmpty && !stoppedNames.isEmpty {
                menu.addItem(.separator())
            }

            for name in stoppedNames {
                let startItem = NSMenuItem(
                    title: "Start \(name)",
                    action: #selector(startServiceAction(_:)),
                    keyEquivalent: ""
                )
                startItem.representedObject = name
                startItem.target = self
                menu.addItem(startItem)
            }
        }

        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "Open Cellar", action: #selector(openCellarAction(_:)), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        return menu
    }

    /// The Brewfile of the right-clicked folder (or the Brewfile itself),
    /// if there is one.
    private func targetedBrewfileURL(for menuKind: FIMenuKind) -> URL? {
        let controller = FIFinderSyncController.default()
        let target = menuKind == .contextualMenuForContainer
            ? controller.targetedURL()
            : controller.selectedItemURLs()?.first
        guard let target else { return nil }
        let brewfileURL = target.lastPathComponent == "Brewfile" ? target : target.appendingPathComponent("Brewfile")
        return FileManager.default.fileExists(atPath: brewfileURL.path) ? brewfileURL : nil
    }

    // MARK: - Actions

    /// Opens the Brewfile on Cellar's Brewfiles page via `cellar://brewfile?path=…`.
    @objc private func openBrewfileAction(_ sender: NSMenuItem) {
        guard let brewfileURL = sender.representedObject as? URL else { return }
        var components = URLComponents()
        components.scheme = "cellar"
        components.host = "brewfile"
        components.queryItems = [URLQueryItem(name: "path", value: brewfileURL.path)]
        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func stopServiceAction(_ sender: NSMenuItem) {
        guard let serviceName = sender.representedObject as? String else { return }
        DistributedNotificationCenter.default().postNotificationName(
            Self.stopServiceNotification,
            object: nil,
            userInfo: ["serviceName": serviceName],
            deliverImmediately: true
        )
    }

    @objc private func startServiceAction(_ sender: NSMenuItem) {
        guard let serviceName = sender.representedObject as? String else { return }
        DistributedNotificationCenter.default().postNotificationName(
            Self.startServiceNotification,
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
