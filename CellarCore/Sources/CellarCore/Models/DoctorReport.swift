import Foundation

// MARK: - DoctorReport

/// `brew doctor` output split into findings — one per `Warning:` — each with
/// a short title, its explanation and the commands brew suggests running.
public struct DoctorReport: Hashable, Sendable {

    // MARK: Data

    public let findings: [Finding]
    /// brew printed "Your system is ready to brew."
    public let isReadyToBrew: Bool

    public init(findings: [Finding], isReadyToBrew: Bool) {
        self.findings = findings
        self.isReadyToBrew = isReadyToBrew
    }

    /// Parses the combined stdout and stderr of `brew doctor`. Text before
    /// the first warning (brew's "Please note…" preamble, support tier
    /// notes) is not a finding and is dropped.
    public init(output: String) {
        let sections = output.components(separatedBy: "Warning: ").dropFirst()
        self.init(
            findings: sections.enumerated().map { Finding(id: $0.offset, text: $0.element) },
            isReadyToBrew: output.contains("Your system is ready to brew")
        )
    }

    /// One line for a report.
    public var summary: String {
        if findings.isEmpty {
            return isReadyToBrew ? "Your system is ready to brew. No issues found." : "Health check completed with notes."
        }
        return "Found \(findings.count) \(findings.count == 1 ? "warning" : "warnings") during health check."
    }

    // MARK: Preview

    public static var preview: DoctorReport {
        DoctorReport(output: """
        Warning: Homebrew's "sbin" was not found in your PATH but you have installed
        formulae that put executables in /opt/homebrew/sbin.

        Consider setting your PATH for example like so:
          echo 'export PATH="/opt/homebrew/sbin:$PATH"' >> ~/.zshrc

        Warning: Your Command Line Tools are too outdated.

        Update them from Software Update in System Settings.
        """)
    }
}

// MARK: - Finding

extension DoctorReport {

    public struct Finding: Identifiable, Hashable, Sendable {
        public let id: Int
        /// The first sentence, without its period.
        public let title: String
        /// The rest of the warning in order: prose and suggested commands.
        public let blocks: [Block]

        public enum Block: Hashable, Sendable {
            /// A paragraph; hard-wrapped lines are joined, indented lines
            /// (paths, URLs, lists) keep their own line.
            case text(String)
            /// A shell command brew suggests, ready to copy.
            case command(String)
        }

        public var commands: [String] {
            blocks.compactMap {
                if case .command(let command) = $0 { command } else { nil }
            }
        }

        public init(id: Int, title: String, blocks: [Block]) {
            self.id = id
            self.title = title
            self.blocks = blocks
        }

        init(id: Int, text: String) {
            let lines = text.components(separatedBy: .newlines)
            let leadEnd = lines.firstIndex {
                $0.hasPrefix(" ") || $0.trimmingCharacters(in: .whitespaces).isEmpty
            } ?? lines.endIndex
            let lead = lines[..<leadEnd].joined(separator: " ")
            let (title, leadRest) = Self.splitFirstSentence(lead)

            var body = Array(lines[leadEnd...])
            if !leadRest.isEmpty { body.insert(leadRest, at: 0) }
            self.init(id: id, title: title, blocks: Self.blocks(from: body))
        }

        /// Splits "A thing is wrong. More detail." after the first period
        /// that ends a sentence.
        private static func splitFirstSentence(_ text: String) -> (String, String) {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            guard let end = trimmed.range(of: ". ") else {
                let title = trimmed.hasSuffix(".") || trimmed.hasSuffix(":") ? String(trimmed.dropLast()) : trimmed
                return (title, "")
            }
            return (
                String(trimmed[..<end.lowerBound]),
                String(trimmed[end.upperBound...]).trimmingCharacters(in: .whitespaces)
            )
        }

        private static func blocks(from lines: [String]) -> [Block] {
            var blocks: [Block] = []
            var paragraph = ""
            var previousWasIndented = false

            func flush() {
                if !paragraph.isEmpty { blocks.append(.text(paragraph)) }
                paragraph = ""
            }

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let isIndented = line.hasPrefix(" ")
                if trimmed.isEmpty {
                    flush()
                } else if isIndented, isCommand(trimmed) {
                    flush()
                    blocks.append(.command(trimmed))
                } else if paragraph.isEmpty {
                    paragraph = trimmed
                } else {
                    let keepsLine = isIndented || previousWasIndented
                    paragraph += (keepsLine ? "\n" : " ") + trimmed
                }
                previousWasIndented = isIndented
            }
            flush()
            return blocks
        }

        /// Programs brew's remediations start with; other indented lines
        /// are paths, URLs or package lists.
        private static let commandPrograms: Set<String> = [
            "brew", "sudo", "rm", "git", "printf", "echo", "export", "xcode-select",
            "xcodebuild", "chmod", "chown", "mkdir", "ln", "launchctl", "softwareupdate",
        ]

        private static func isCommand(_ line: String) -> Bool {
            line.split(separator: " ").first.map { commandPrograms.contains(String($0)) } ?? false
        }
    }
}
