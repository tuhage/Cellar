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

    @Test("stream can interleave stderr lines and still reports stderr on failure")
    func streamIncludesStandardError() async throws {
        let process = BrewProcess(brewPath: "/bin/sh")
        var lines: [String] = []

        do {
            for try await line in process.stream(
                ["-c", "echo out; echo err >&2; exit 3"],
                includingStandardError: true
            ) {
                lines.append(line)
            }
            Issue.record("Expected a failure")
        } catch BrewError.processFailure(let exitCode, let stderr) {
            #expect(exitCode == 3)
            #expect(stderr == "err\n")
        }

        #expect(Set(lines) == ["out", "err"])
    }

    @Test("stream finishes when brew exits even if a background child keeps the pipe open", .timeLimit(.minutes(1)))
    func streamDoesNotWaitForInheritedPipe() async throws {
        let process = BrewProcess(brewPath: "/bin/sh")
        let start = ContinuousClock.now
        var lines: [String] = []

        for try await line in process.stream(["-c", "/bin/sleep 20 & echo done"]) {
            lines.append(line)
        }

        #expect(lines == ["done"])
        #expect(ContinuousClock.now - start < .seconds(10))
    }

    @Test("run finishes when brew exits even if a background child keeps the pipe open", .timeLimit(.minutes(1)))
    func runDoesNotWaitForInheritedPipe() async throws {
        let process = BrewProcess(brewPath: "/bin/sh")
        let start = ContinuousClock.now

        let output = try await process.run(["-c", "/bin/sleep 20 & echo done"])

        #expect(output.stdout == "done\n")
        #expect(ContinuousClock.now - start < .seconds(10))
    }

    @Test("stdin is closed so prompts fail instead of waiting for input", .timeLimit(.minutes(1)))
    func stdinIsNullDevice() async throws {
        let process = BrewProcess(brewPath: "/bin/sh")

        let output = try await process.run(["-c", "read answer; echo \"exit=$?\""])

        #expect(output.stdout == "exit=1\n")
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
