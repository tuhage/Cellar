import Foundation

// MARK: - BrewIssue

/// A common, recognizable reason a brew command failed, with what the user
/// can do about it. Detected from brew's output so a failure can say more
/// than brew's one-line error.
public enum BrewIssue: Hashable, Sendable {
    case outdatedCommandLineTools
    case missingCommandLineTools
    case xcodeLicenseNotAccepted
    case homebrewBusy
    case offline
    case diskFull
    case notWritable
    case checksumMismatch
    /// A cask's app already exists, installed without Homebrew.
    case appAlreadyExists(path: String?)

    // MARK: Detection

    /// The first issue whose telltale text appears in `output`. More
    /// specific issues are checked first.
    public static func detect(in output: String) -> BrewIssue? {
        let text = output.lowercased()
        if text.contains("there is already an app at") {
            return .appAlreadyExists(path: existingAppPath(in: output))
        }
        return signatures.first { _, phrases in
            phrases.contains { text.contains($0) }
        }?.issue
    }

    /// Detects the issue behind a failed command from its whole output,
    /// not just the one-line summary.
    public static func detect(in error: Error) -> BrewIssue? {
        if case BrewError.processFailure(_, let stderr) = error {
            return detect(in: stderr)
        }
        return detect(in: error.localizedDescription)
    }

    /// Lowercased phrases brew (or the tools it runs) prints for each issue.
    private static let signatures: [(issue: BrewIssue, phrases: [String])] = [
        (.outdatedCommandLineTools, [
            "command line tools are too outdated",
            "command line tools (clt) does not support",
        ]),
        (.missingCommandLineTools, [
            "invalid active developer path",
            "no developer tools were found",
            "command line tools are not installed",
            "xcode alone is not sufficient",
        ]),
        (.xcodeLicenseNotAccepted, [
            "agreed to the xcode license",
            "xcode license agreements",
        ]),
        (.homebrewBusy, [
            "another active homebrew",
            "already locked",
        ]),
        (.diskFull, ["no space left on device"]),
        (.checksumMismatch, ["sha256 mismatch", "checksum mismatch"]),
        (.notWritable, ["not writable by your user", "permission denied @ "]),
        (.offline, [
            "could not resolve host",
            "failed to connect to",
            "network is unreachable",
            "connection timed out",
            "operation timed out",
        ]),
    ]

    /// The quoted path in brew's "already an App at '…'" message.
    private static func existingAppPath(in output: String) -> String? {
        output.firstMatch(of: /already an App at '([^']+)'/.ignoresCase()).map { String($0.1) }
    }

    // MARK: Explanation

    /// What went wrong, in a few words.
    public var title: String {
        switch self {
        case .outdatedCommandLineTools: "Command Line Tools need an update"
        case .missingCommandLineTools: "Command Line Tools aren’t installed"
        case .xcodeLicenseNotAccepted: "Xcode license not accepted"
        case .homebrewBusy: "Homebrew is busy"
        case .offline: "Couldn’t reach the download server"
        case .diskFull: "Your disk is full"
        case .notWritable: "Homebrew can’t write to its folders"
        case .checksumMismatch: "The download didn’t match"
        case .appAlreadyExists: "The app is already installed"
        }
    }

    /// Why it happened and what to do next.
    public var explanation: String {
        switch self {
        case .outdatedCommandLineTools:
            "Homebrew needs Command Line Tools that match your macOS to install this package. Install the Command Line Tools update from Software Update, then retry. If none is offered, reinstall them in Terminal."
        case .missingCommandLineTools:
            "Homebrew needs Apple’s Command Line Tools to install this package. Install them, then retry."
        case .xcodeLicenseNotAccepted:
            "Homebrew can’t use Xcode’s tools until its license is accepted. Accept it in Terminal, then retry."
        case .homebrewBusy:
            "Another Homebrew command, perhaps in Terminal, is running. Retry once it finishes."
        case .offline:
            "Check your internet connection, then retry."
        case .diskFull:
            "Free up some space, for example with Clean Up, then retry."
        case .notWritable:
            "Some Homebrew folders aren’t owned by your user. A Health Check shows the exact command that fixes them."
        case .checksumMismatch:
            "The cached download is damaged or changed upstream. Clean Up removes it so a retry downloads it again."
        case .appAlreadyExists:
            "This app was installed without Homebrew. Move it to the Trash, then retry so Homebrew can manage it."
        }
    }

    /// Ways to fix it, the most direct first.
    public var remedies: [Remedy] {
        switch self {
        case .outdatedCommandLineTools:
            [.softwareUpdate, .terminal("sudo rm -rf /Library/Developer/CommandLineTools && sudo xcode-select --install")]
        case .missingCommandLineTools:
            [.terminal("xcode-select --install")]
        case .xcodeLicenseNotAccepted:
            [.terminal("sudo xcodebuild -license accept")]
        case .homebrewBusy, .offline:
            []
        case .diskFull, .notWritable, .checksumMismatch:
            [.maintenance]
        case .appAlreadyExists(let path):
            path.map { [.reveal(path: $0)] } ?? []
        }
    }
}

// MARK: - Remedy

extension BrewIssue {

    /// Something the app can do, or open, to fix an issue.
    public enum Remedy: Hashable, Sendable {
        /// System Settings › Software Update.
        case softwareUpdate
        /// A command for the user to run in Terminal.
        case terminal(String)
        /// Cellar's Maintenance page: Clean Up and Health Check.
        case maintenance
        /// Shows a file in Finder.
        case reveal(path: String)
    }
}
