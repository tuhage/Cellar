import Foundation

/// A TCP port a process accepts connections on.
public struct ListeningPort: Hashable, Sendable, Comparable {
    public let port: Int
    /// Whether only this Mac can connect (bound to a loopback address).
    public let isLocalOnly: Bool

    public init(port: Int, isLocalOnly: Bool) {
        self.port = port
        self.isLocalOnly = isLocalOnly
    }

    public static func < (lhs: ListeningPort, rhs: ListeningPort) -> Bool {
        (lhs.port, lhs.isLocalOnly ? 0 : 1) < (rhs.port, rhs.isLocalOnly ? 0 : 1)
    }

    /// The ports `pid` listens on. Only works for the user's own processes:
    /// `lsof` can't inspect root processes without elevating.
    public static func ports(ofProcess pid: Int) async -> [ListeningPort] {
        let output = await SystemCommand.output(
            "/usr/sbin/lsof",
            ["-nP", "-a", "-p", String(pid), "-iTCP", "-sTCP:LISTEN", "-Fn"]
        )
        return output.map(parseLsof) ?? []
    }

    /// Parses `lsof -Fn` output, whose `n` lines hold addresses such as
    /// `127.0.0.1:5432`, `[::1]:5432` or `*:8080`. IPv4 and IPv6 bindings of
    /// the same port collapse into one entry.
    static func parseLsof(_ output: String) -> [ListeningPort] {
        let ports = output.split(whereSeparator: \.isNewline).compactMap { line -> ListeningPort? in
            guard line.first == "n",
                  let separator = line.lastIndex(of: ":"),
                  let port = Int(line[line.index(after: separator)...])
            else { return nil }
            let host = line[line.index(after: line.startIndex)..<separator]
            let isLocalOnly = host == "127.0.0.1" || host == "[::1]" || host == "localhost"
            return ListeningPort(port: port, isLocalOnly: isLocalOnly)
        }
        return Set(ports).sorted()
    }
}
