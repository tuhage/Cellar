import AppKit

extension NSApplication {
    /// The open (visible or minimized) main Cellar window, if any. Closed
    /// windows linger in `windows` but must not be reused.
    var cellarMainWindow: NSWindow? {
        windows.first { window in
            window.identifier?.rawValue.hasPrefix(SceneID.main) == true
                && (window.isVisible || window.isMiniaturized)
        }
    }

    var isMainWindowInFront: Bool {
        isActive && cellarMainWindow?.isVisible == true
    }
}
