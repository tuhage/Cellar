import Foundation
import Testing
@testable import CellarCore

@Suite("Brew Process")
struct BrewProcessTests {

    @Test("drains large stdout and stderr without deadlocking", .timeLimit(.minutes(1)))
    func drainsBothPipes() async throws {
        let process = BrewProcess(brewPath: "/bin/sh")
        let output = try await process.run([
            "-c",
            "/usr/bin/yes stdout | /usr/bin/head -c 200000; "
                + "/usr/bin/yes stderr | /usr/bin/head -c 200000 >&2"
        ])

        #expect(output.exitCode == 0)
        #expect(output.stdout.utf8.count == 200_000)
        #expect(output.stderr.utf8.count == 200_000)
    }

    @Test("stream emits complete lines including final unterminated line")
    func streamsCompleteLines() async throws {
        let process = BrewProcess(brewPath: "/bin/sh")
        var lines: [String] = []

        for try await line in process.stream(["-c", "printf 'first\\nsecond\\nthird'"]) {
            lines.append(line)
        }

        #expect(lines == ["first", "second", "third"])
    }

    @Test("cancelling a run terminates the process", .timeLimit(.minutes(1)))
    func cancellationTerminatesProcess() async {
        let process = BrewProcess(brewPath: "/bin/sh")
        let task = Task {
            try await process.run(["-c", "sleep 10"])
        }

        try? await Task.sleep(for: .milliseconds(100))
        task.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
    }
}
