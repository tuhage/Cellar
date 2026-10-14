import Testing
import Foundation
@testable import CellarCore

@Suite("BrewIssue")
struct BrewIssueTests {

    @Test("brewIssue_detect_outdatedCommandLineToolsFromFullStderr")
    func brewIssue_detect_outdatedCommandLineToolsFromFullStderr() {
        let stderr = """
        ==> Upgrading mobile-dev-inc/tap/maestro
        Error: Your Command Line Tools are too outdated.

        Update them from Software Update in System Settings.

        If that doesn't show you any updates, run:
          sudo rm -rf /Library/Developer/CommandLineTools
          sudo xcode-select --install
        """
        let error = BrewError.processFailure(exitCode: 1, stderr: stderr)

        #expect(BrewIssue.detect(in: error) == .outdatedCommandLineTools)
        #expect(BrewIssue.outdatedCommandLineTools.remedies.first == .softwareUpdate)
    }

    @Test("brewIssue_detect_offlineFromCurlOutputBeforeTheErrorLine")
    func brewIssue_detect_offlineFromCurlOutputBeforeTheErrorLine() {
        let stderr = """
        curl: (6) Could not resolve host: ghcr.io
        Error: Failure while executing; `/usr/bin/curl` exited with 6.
        """
        let error = BrewError.processFailure(exitCode: 1, stderr: stderr)

        #expect(error.briefDescription.hasPrefix("Failure while executing"))
        #expect(BrewIssue.detect(in: error) == .offline)
    }

    @Test("brewIssue_detect_appAlreadyExistsKeepsThePath")
    func brewIssue_detect_appAlreadyExistsKeepsThePath() {
        let output = "Error: It seems there is already an App at '/Applications/Visual Studio Code.app'."

        let issue = BrewIssue.detect(in: output)

        #expect(issue == .appAlreadyExists(path: "/Applications/Visual Studio Code.app"))
        #expect(issue?.remedies == [.reveal(path: "/Applications/Visual Studio Code.app")])
    }

    @Test("brewIssue_detect_recognizesCommonFailures", arguments: [
        ("Error: No space left on device @ rb_sysopen", BrewIssue.diskFull),
        ("Error: Another active Homebrew update process is already in progress.", .homebrewBusy),
        ("Error: SHA256 mismatch", .checksumMismatch),
        ("Error: Permission denied @ apply2files - /opt/homebrew/share", .notWritable),
        ("xcrun: error: invalid active developer path (/Library/Developer/CommandLineTools)", .missingCommandLineTools),
        ("Error: You have not agreed to the Xcode license.", .xcodeLicenseNotAccepted),
    ])
    func brewIssue_detect_recognizesCommonFailures(output: String, expected: BrewIssue) {
        #expect(BrewIssue.detect(in: output) == expected)
    }

    @Test("brewIssue_detect_returnsNilForUnknownErrors")
    func brewIssue_detect_returnsNilForUnknownErrors() {
        #expect(BrewIssue.detect(in: "Error: Refusing to uninstall openssl@3 because it is required by curl") == nil)
    }
}
