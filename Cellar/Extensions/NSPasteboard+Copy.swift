import AppKit

extension NSPasteboard {
    /// Replaces the general pasteboard's contents with `text`.
    static func copy(_ text: String) {
        general.clearContents()
        general.setString(text, forType: .string)
    }
}
