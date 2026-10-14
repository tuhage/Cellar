import Foundation

extension BrewServiceItem {

    /// What the last exit code means, in plain words.
    public var exitCodeExplanation: String? {
        exitCode.map(Self.explainExitCode)
    }

    /// The meaning of a launchd job's exit status. launchd reports a process
    /// ended by a signal as the negative signal number; shells use 128 + N.
    public static func explainExitCode(_ code: Int) -> String {
        if code < 0 { return signalDescription(-code) }
        if (129...159).contains(code) { return signalDescription(code - 128) }
        return exitCodeMeanings[code] ?? "Exited with an error"
    }

    /// Common conventions plus BSD `sysexits.h` (64–78), which many daemons use.
    private static let exitCodeMeanings: [Int: String] = [
        0: "Exited normally",
        1: "Exited with an error",
        2: "Invalid arguments",
        64: "Invalid command-line usage",
        65: "Invalid input data",
        66: "An input file is missing",
        67: "Unknown user",
        68: "Unknown host",
        69: "A service it needs is unavailable",
        70: "Internal software error",
        71: "System error",
        72: "A system file is missing",
        73: "Couldn’t create an output file",
        74: "Input/output error",
        75: "Temporary failure; it may work if retried",
        76: "Protocol error",
        77: "Permission denied",
        78: "Configuration error",
        126: "The command isn’t executable",
        127: "The command wasn’t found",
    ]

    private static let signalNames: [Int: String] = [
        1: "SIGHUP", 2: "SIGINT", 3: "SIGQUIT", 4: "SIGILL", 5: "SIGTRAP", 6: "SIGABRT",
        8: "SIGFPE", 9: "SIGKILL", 10: "SIGBUS", 11: "SIGSEGV", 13: "SIGPIPE", 14: "SIGALRM", 15: "SIGTERM",
    ]

    /// Signals raised by the process's own fault rather than sent to it.
    private static let crashSignals: Set<Int> = [4, 5, 6, 8, 10, 11]

    private static func signalDescription(_ signal: Int) -> String {
        let name = signalNames[signal].map { "\($0), " } ?? ""
        let outcome = crashSignals.contains(signal) ? "Crashed" : "Killed by a signal"
        return "\(outcome) (\(name)signal \(signal))"
    }
}
