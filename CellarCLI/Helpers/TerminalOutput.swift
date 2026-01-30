import Foundation

enum ANSIColor: String {
    case reset = "\u{001B}[0m"
    case bold = "\u{001B}[1m"
    case dim = "\u{001B}[2m"

    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case blue = "\u{001B}[34m"
    case magenta = "\u{001B}[35m"
    case cyan = "\u{001B}[36m"
    case white = "\u{001B}[37m"
}

enum TerminalOutput {
    private static var colorEnabled: Bool {
        isatty(STDOUT_FILENO) != 0
    }

    static func colored(_ text: String, _ color: ANSIColor) -> String {
        guard colorEnabled else { return text }
        return "\(color.rawValue)\(text)\(ANSIColor.reset.rawValue)"
    }

    static func bold(_ text: String) -> String {
        colored(text, .bold)
    }

    static func success(_ text: String) -> String {
        colored(text, .green)
    }

    static func warning(_ text: String) -> String {
        colored(text, .yellow)
    }

    static func error(_ text: String) -> String {
        colored(text, .red)
    }

    static func info(_ text: String) -> String {
        colored(text, .cyan)
    }

    static func printHeader(_ title: String) {
        print(bold(title))
        print(String(repeating: "─", count: title.count))
    }

    static func printError(_ message: String) {
        FileHandle.standardError.write(Data((error("Error: \(message)") + "\n").utf8))
    }

    static func printSuccess(_ message: String) {
        print(success("✓ \(message)"))
    }

    static func printStatusDot(running: Bool) -> String {
        running ? success("●") : colored("○", .dim)
    }
}
