import Foundation

extension JSONDecoder {
    /// A decoder configured for brew JSON output.
    public nonisolated static let brew: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()
}
