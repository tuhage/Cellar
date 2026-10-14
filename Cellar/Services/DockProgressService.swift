import AppKit

/// Shows batch progress on the Dock icon: a progress bar over the icon and
/// the number of packages left as the badge.
@MainActor
final class DockProgressService {
    static let shared = DockProgressService()

    private var progressIndicator: NSProgressIndicator?
    private var shownProgress: (fraction: Double, remaining: Int)?

    private init() {}

    /// Pass the running batch operation, or `nil` to restore the plain icon.
    func update(for operation: BrewOperation?) {
        let tile = NSApp.dockTile
        guard let operation, operation.isRunning, !operation.steps.isEmpty else {
            guard shownProgress != nil else { return }
            tile.contentView = nil
            tile.badgeLabel = nil
            tile.display()
            progressIndicator = nil
            shownProgress = nil
            return
        }

        let fraction = Double(operation.finishedStepCount) / Double(operation.steps.count)
        let remaining = operation.steps.count - operation.finishedStepCount
        // Log lines change the operation constantly; only redraw on progress.
        if let shownProgress, shownProgress.fraction == fraction, shownProgress.remaining == remaining {
            return
        }

        let indicator = progressIndicator ?? installIndicator(in: tile)
        indicator.doubleValue = fraction
        tile.badgeLabel = remaining > 0 ? "\(remaining)" : nil
        tile.display()
        shownProgress = (fraction, remaining)
    }

    private func installIndicator(in tile: NSDockTile) -> NSProgressIndicator {
        let size = tile.size
        let container = NSView(frame: NSRect(origin: .zero, size: size))

        let icon = NSImageView(frame: container.bounds)
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown
        container.addSubview(icon)

        let inset = size.width * 0.12
        let indicator = NSProgressIndicator(frame: NSRect(
            x: inset,
            y: size.height * 0.08,
            width: size.width - inset * 2,
            height: size.height * 0.1
        ))
        indicator.style = .bar
        indicator.isIndeterminate = false
        indicator.minValue = 0
        indicator.maxValue = 1
        container.addSubview(indicator)

        tile.contentView = container
        progressIndicator = indicator
        return indicator
    }
}
