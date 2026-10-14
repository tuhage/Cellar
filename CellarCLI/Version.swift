import Foundation

enum AppVersion {
    /// The CLI target embeds a generated Info.plist in its binary, so this
    /// is the project's MARKETING_VERSION — the same one the app shows.
    static var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }
}
