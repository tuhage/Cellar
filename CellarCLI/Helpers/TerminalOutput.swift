import Foundation

enum TerminalOutput {
    private static let colorEnabled = isatty(STDOUT_FILENO) != 0

    // MARK: - Color

    enum Color: String {
        case reset = "\u{001B}[0m"
        case bold = "\u{001B}[1m"
        case dim = "\u{001B}[2m"
        case red = "\u{001B}[31m"
        case green = "\u{001B}[32m"
        case yellow = "\u{001B}[33m"
        case cyan = "\u{001B}[36m"
    }

    static func colored(_ text: String, _ color: Color) -> String {
        guard colorEnabled else { return text }
        return "\(color.rawValue)\(text)\(Color.reset.rawValue)"
    }

    static func bold(_ text: String) -> String { colored(text, .bold) }
    static func success(_ text: String) -> String { colored(text, .green) }
    static func warning(_ text: String) -> String { colored(text, .yellow) }
    static func error(_ text: String) -> String { colored(text, .red) }
    static func info(_ text: String) -> String { colored(text, .cyan) }

    // MARK: - Printing

    static func printHeader(_ title: String) {
        print(bold(title))
        print(String(repeating: "\u{2500}", count: title.count))
    }

    static func printError(_ message: String) {
        FileHandle.standardError.write(Data((error("Error: \(message)") + "\n").utf8))
    }

    static func printSuccess(_ message: String) {
        print(success("\u{2713} \(message)"))
    }

    // MARK: - Formatting

    static func statusDot(running: Bool) -> String {
        running ? success("\u{25CF}") : colored("\u{25CB}", .dim)
    }
}
