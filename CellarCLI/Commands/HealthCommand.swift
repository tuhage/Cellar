import CellarCore

enum HealthCommand {
    static func run() async throws {
        TerminalOutput.printHeader("Homebrew Health Check")
        print("")
        print("Running \(TerminalOutput.info("brew doctor"))...")
        print("")

        let report = DoctorReport(output: try await BrewService.shared.doctor())
        guard !report.findings.isEmpty else {
            TerminalOutput.printSuccess(report.summary)
            return
        }

        print(TerminalOutput.warning(report.summary))
        for finding in report.findings {
            print("")
            print(TerminalOutput.bold("\u{26A0} \(finding.title)"))
            for block in finding.blocks {
                switch block {
                case .text(let text): print(indented(text, by: 2))
                case .command(let command): print(indented(TerminalOutput.info(command), by: 4))
                }
            }
        }
    }

    private static func indented(_ text: String, by count: Int) -> String {
        let indent = String(repeating: " ", count: count)
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { indent + $0 }
            .joined(separator: "\n")
    }
}
