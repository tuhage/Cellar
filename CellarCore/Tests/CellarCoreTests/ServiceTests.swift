import Testing
import Foundation
@testable import CellarCore

@Suite("Services")
struct ServiceTests {

    // MARK: Status

    @Test("serviceStatus_decode_mapsEveryBrewStatus")
    func serviceStatus_decode_mapsEveryBrewStatus() throws {
        let json = #"["started","scheduled","stopped","none","error","other","unknown","bogus"]"#
        let statuses = try JSONDecoder().decode([ServiceStatus].self, from: Data(json.utf8))

        #expect(statuses == [.started, .scheduled, .stopped, .none, .error, .other, .unknown, .unknown])
    }

    @Test("serviceStatus_sort_putsErrorsFirstAndUnloadedLast")
    func serviceStatus_sort_putsErrorsFirstAndUnloadedLast() {
        let sorted = [ServiceStatus.none, .stopped, .started, .error].sorted()

        #expect(sorted == [.error, .started, .stopped, .none])
    }

    // MARK: Exit Codes

    @Test("brewServiceItem_explainExitCode_describesCommonCodesAndSignals")
    func brewServiceItem_explainExitCode_describesCommonCodesAndSignals() {
        #expect(BrewServiceItem.explainExitCode(78) == "Configuration error")
        #expect(BrewServiceItem.explainExitCode(127) == "The command wasn’t found")
        #expect(BrewServiceItem.explainExitCode(-9) == "Killed by a signal (SIGKILL, signal 9)")
        #expect(BrewServiceItem.explainExitCode(139) == "Crashed (SIGSEGV, signal 11)")
        #expect(BrewServiceItem.explainExitCode(42) == "Exited with an error")
    }

    // MARK: launchd

    @Test("brewServiceItem_parseLaunchctlList_returnsRunningJobsByLabel")
    func brewServiceItem_parseLaunchctlList_returnsRunningJobsByLabel() {
        let output = """
        PID\tStatus\tLabel
        -\t0\tcom.apple.SafariHistoryServiceAgent
        1828\t0\thomebrew.mxcl.postgresql@17
        -\t78\thomebrew.mxcl.redis
        """

        let pids = BrewServiceItem.parseLaunchctlList(output)

        #expect(pids == ["homebrew.mxcl.postgresql@17": 1828])
    }

    @Test("brewServiceItem_applyingLaunchdPID_marksRunningRootServiceStarted")
    func brewServiceItem_applyingLaunchdPID_marksRunningRootServiceStarted() {
        let root = BrewServiceItem(name: "tailscale", status: .none, user: "root", file: nil, exitCode: nil, pid: nil, registered: true)
        let stoppedUser = BrewServiceItem(name: "redis", status: .stopped, user: "me", file: nil, exitCode: 0, pid: nil, registered: true)

        #expect(root.applyingLaunchdPID(813).status == .started)
        #expect(root.applyingLaunchdPID(813).pid == 813)
        #expect(root.applyingLaunchdPID(nil) == root)
        #expect(stoppedUser.applyingLaunchdPID(42) == stoppedUser)
    }

    // MARK: Commands

    @Test("brewService_serviceCommands_passBrewArguments")
    func brewService_serviceCommands_passBrewArguments() async throws {
        let process = RecordingBrewProcess()
        let service = BrewService(process: process)

        try await service.stopService("redis", keepRegistered: true)
        try await service.stopService("redis")
        try await service.runService("redis")

        #expect(process.ranArguments == [
            ["services", "stop", "--keep", "redis"],
            ["services", "stop", "redis"],
            ["services", "run", "redis"],
        ])
    }

    @Test("brewService_restartServicesPrivileged_usesOnePrompt")
    func brewService_restartServicesPrivileged_usesOnePrompt() async throws {
        let process = RecordingBrewProcess()
        let service = BrewService(process: process)

        try await service.restartServicesPrivileged(["tailscale", "dnsmasq"])

        #expect(process.privilegedCalls == [[
            .brew(["services", "restart", "tailscale"]),
            .brew(["services", "restart", "dnsmasq"]),
        ]])
    }

    @Test("brewProcess_privilegedShellScript_runsEveryCommandAndKeepsFailure")
    func brewProcess_privilegedShellScript_runsEveryCommandAndKeepsFailure() {
        let script = BrewProcess.privilegedShellScript(
            [.brew(["services", "restart", "it's"]), .tool(path: "/bin/kill", arguments: ["-KILL", "42"])],
            brewPath: "/opt/homebrew/bin/brew",
            home: "/Users/someone"
        )

        #expect(script == "s=0; "
            + "HOME='/Users/someone' HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_CLEANUP=1 '/opt/homebrew/bin/brew' 'services' 'restart' 'it'\\''s' || s=$?; "
            + "'/bin/kill' '-KILL' '42' || s=$?; exit $s")
    }

    @Test("brewProcess_appleScriptErrorMessage_unwrapsTheScriptsMessage")
    func brewProcess_appleScriptErrorMessage_unwrapsTheScriptsMessage() {
        let stderr = "0:183: execution error: Error: $HOME must be set to run brew. (1)\n"

        #expect(BrewProcess.appleScriptErrorMessage(stderr) == "Error: $HOME must be set to run brew.")
        #expect(BrewError.processFailure(exitCode: 1, stderr: BrewProcess.appleScriptErrorMessage(stderr)).summary
            == "$HOME must be set to run brew.")
        #expect(BrewProcess.appleScriptErrorMessage("something else") == "something else")
    }

    // MARK: Info

    @Test("serviceInfo_decode_readsLogsAndSchedule")
    func serviceInfo_decode_readsLogsAndSchedule() throws {
        let info = try #require(try JSONDecoder().decode([ServiceInfo].self, from: fixtureData("service_info.json")).first)

        #expect(info.label == "homebrew.mxcl.postgresql@17")
        #expect(info.registered == true)
        #expect(info.workingDirectory == "/opt/homebrew")
        #expect(info.errorLogOrLogPath == "/opt/homebrew/var/log/postgresql@17.log")
        #expect(info.interval == nil)
        #expect(info.cron == "0 * * * *")
    }

    @Test("serviceInfo_lastLines_readsOnlyCompleteTrailingLines")
    func serviceInfo_lastLines_readsOnlyCompleteTrailingLines() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cellar-log-\(UUID()).log")
        try (1...100).map { "line \($0)" }.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let lines = try #require(ServiceInfo.lastLines(ofFileAt: url.path, count: 3))
        let truncated = try #require(ServiceInfo.lastLines(ofFileAt: url.path, count: 50, maxBytes: 20))

        #expect(lines == ["line 98", "line 99", "line 100"])
        #expect(truncated == ["line 99", "line 100"])
        #expect(ServiceInfo.lastLines(ofFileAt: "/nonexistent/cellar.log", count: 3) == nil)
    }

    // MARK: Ports

    @Test("listeningPort_parseLsof_collapsesAddressFamilies")
    func listeningPort_parseLsof_collapsesAddressFamilies() {
        let output = """
        p1828
        f7
        n[::1]:5432
        f8
        n127.0.0.1:5432
        f9
        n*:8080
        """

        #expect(ListeningPort.parseLsof(output) == [
            ListeningPort(port: 5432, isLocalOnly: true),
            ListeningPort(port: 8080, isLocalOnly: false),
        ])
    }
}

// MARK: - Metrics

@Suite("Service metrics")
struct ServiceMetricsTests {

    private let psOutput = """
        1     0   0.0  16960 359:45.62
     1828     1   1.5   2000   2:17.13
     2359  1828   0.0    512   0:11.22
     2361  1828   0.5    496   1-00:00:06.47
     9999     1   0.0    100   0:00.01
    """

    @Test("processTable_parseCPUTime_handlesMinutesHoursAndDays")
    func processTable_parseCPUTime_handlesMinutesHoursAndDays() {
        #expect(abs((ProcessTable.parseCPUTime("2:17.13") ?? 0) - 137.13) < 0.001)
        #expect(abs((ProcessTable.parseCPUTime("359:45.62") ?? 0) - 21_585.62) < 0.001)
        #expect(ProcessTable.parseCPUTime("1-02:00:00.00") == 93_600)
        #expect(ProcessTable.parseCPUTime("x") == nil)
    }

    @Test("processTable_treeUsage_sumsDescendants")
    func processTable_treeUsage_sumsDescendants() throws {
        let table = ProcessTable.parse(psOutput, capturedAt: .now)

        let usage = try #require(table.treeUsage(of: 1828))

        #expect(usage.processCount == 3)
        #expect(usage.residentBytes == (2000 + 512 + 496) * 1024)
        #expect(abs(usage.cpuPercent - 2.0) < 0.001)
        #expect(table.treeUsage(of: 4242) == nil)
    }

    @Test("resourceUsage_measure_usesCPUTimeDeltaAfterFirstSample")
    func resourceUsage_measure_usesCPUTimeDeltaAfterFirstSample() throws {
        let start = Date()
        let first = ProcessTable.parse(" 10 1 50.0 1024 0:10.00", capturedAt: start)
        let second = ProcessTable.parse(" 10 1 50.0 1024 0:12.00", capturedAt: start.addingTimeInterval(4))

        let initial = try #require(ResourceUsage.measure(serviceName: "redis", pid: 10, in: first, previous: nil))
        let next = try #require(ResourceUsage.measure(serviceName: "redis", pid: 10, in: second, previous: initial))

        #expect(initial.cpuPercent == 50)
        #expect(next.cpuPercent == 50) // 2 s of CPU over 4 s
        #expect(next.memoryBytes == 1024 * 1024)
        #expect(next.id == initial.id)
    }
}
