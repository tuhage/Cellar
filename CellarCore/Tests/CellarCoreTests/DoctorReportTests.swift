import Foundation
import Testing
@testable import CellarCore

@Suite("Doctor Report")
struct DoctorReportTests {

    private func warnings() throws -> DoctorReport {
        DoctorReport(output: String(decoding: try fixtureData("doctor_warnings.txt"), as: UTF8.self))
    }

    @Test("doctorReport_init_splitsFindingsAndDropsPreamble")
    func doctorReport_init_splitsFindingsAndDropsPreamble() throws {
        let report = try warnings()

        #expect(report.findings.map(\.title) == [
            "Your Command Line Tools are too outdated",
            "/usr/bin occurs before /opt/homebrew/bin in your PATH",
            "Homebrew's \"sbin\" was not found in your PATH but you have installed formulae that put executables in /opt/homebrew/sbin",
        ])
        #expect(!report.isReadyToBrew)
        #expect(report.summary == "Found 3 warnings during health check.")
    }

    @Test("doctorReport_init_extractsSuggestedCommands")
    func doctorReport_init_extractsSuggestedCommands() throws {
        let findings = try warnings().findings

        #expect(findings[0].commands == ["sudo rm -rf /Library/Developer/CommandLineTools", "sudo xcode-select --install"])
        #expect(findings[1].commands == [#"printf '%s\n' export\ PATH\=/opt/homebrew/bin:\$PATH >> ~/.zshrc"#])
    }

    @Test("doctorReport_init_keepsExplanationInOrder")
    func doctorReport_init_keepsExplanationInOrder() throws {
        let finding = try warnings().findings[1]

        #expect(finding.blocks == [
            .text("This means that system-provided programs will be used instead of those provided by Homebrew."),
            .text("The following tools exist at both paths:\nbundle\nruby"),
            .text("Consider setting your PATH for example like so:"),
            .command(#"printf '%s\n' export\ PATH\=/opt/homebrew/bin:\$PATH >> ~/.zshrc"#),
        ])
    }

    @Test("doctorReport_init_keepsURLsAsText")
    func doctorReport_init_keepsURLsAsText() throws {
        let finding = try warnings().findings[0]

        #expect(finding.blocks.contains(.text(
            "Alternatively, manually download them from:\nhttps://developer.apple.com/download/all/.\nYou should download the Command Line Tools for Xcode 27.0."
        )))
    }

    @Test("doctorReport_init_readyToBrewHasNoFindings")
    func doctorReport_init_readyToBrewHasNoFindings() {
        let report = DoctorReport(output: "Your system is ready to brew.\n")

        #expect(report.findings.isEmpty)
        #expect(report.isReadyToBrew)
        #expect(report.summary == "Your system is ready to brew. No issues found.")
    }
}
