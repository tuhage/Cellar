import Foundation

extension String {
    /// The path with the home folder shortened to `~`.
    public var abbreviatingWithTildeInPath: String {
        (self as NSString).abbreviatingWithTildeInPath
    }
}
