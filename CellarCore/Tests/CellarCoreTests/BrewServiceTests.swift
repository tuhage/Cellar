import Testing
import Foundation
@testable import CellarCore

@Suite("BrewService")
struct BrewServiceTests {

    @Test("brewService_listFormulaeData_returnsRawData")
    func brewService_listFormulaeData_returnsRawData() async throws {
        let json = String(data: try fixtureData("formula_installed.json"), encoding: .utf8)!
        let mock = MockBrewProcess(stubbedOutput: ProcessOutput(stdout: json, stderr: "", exitCode: 0))
        let service = BrewService(process: mock)

        let data = try await service.listFormulaeData()

        #expect(!data.isEmpty)
        let response = try JSONDecoder().decode(BrewJSONResponse.self, from: data)
        #expect(response.formulae.count == 1)
        #expect(response.formulae.first?.name == "openssl@3")
    }

    @Test("brewService_upgradeAndInstall_passExplicitFormulaOrCaskFlag")
    func brewService_upgradeAndInstall_passExplicitFormulaOrCaskFlag() async throws {
        let process = RecordingBrewProcess()
        let service = BrewService(process: process)

        for try await _ in service.upgrade("mobile-dev-inc/tap/maestro", isCask: false) {}
        for try await _ in service.upgrade("firefox", isCask: true) {}
        for try await _ in service.install("wget", isCask: false) {}

        #expect(process.streamedArguments == [
            ["upgrade", "--formula", "mobile-dev-inc/tap/maestro"],
            ["upgrade", "--cask", "firefox"],
            ["install", "--formula", "wget"],
        ])
    }

    @Test("brewServiceItem_processStartDate_readsRunningProcess")
    func brewServiceItem_processStartDate_readsRunningProcess() throws {
        let item = BrewServiceItem(
            name: "self", status: .started, user: nil, file: nil,
            exitCode: nil, pid: Int(ProcessInfo.processInfo.processIdentifier), registered: true
        )

        let started = try #require(item.processStartDate)
        #expect(started <= Date())
        #expect(started > Date().addingTimeInterval(-3600))
    }

    @Test("brewService_listServicesData_parsesBrewServiceItems")
    func brewService_listServicesData_parsesBrewServiceItems() async throws {
        let json = String(data: try fixtureData("services_list.json"), encoding: .utf8)!
        let mock = MockBrewProcess(stubbedOutput: ProcessOutput(stdout: json, stderr: "", exitCode: 0))
        let service = BrewService(process: mock)

        let data = try await service.listServicesData()
        let items = try JSONDecoder().decode([BrewServiceItem].self, from: data)

        #expect(items.count == 2)
        #expect(items[0].name == "postgresql@16")
        #expect(items[0].status == .started)
        #expect(items[1].name == "redis")
        #expect(items[1].status == .stopped)
    }

    @Test("brewServiceItem_parseLaunchctlRuntime_detectsRunningSystemService")
    func parseLaunchctlRuntimeDetectsRunningSystemService() {
        let output = """
        system/homebrew.mxcl.tailscale = {
            state = running
            pid = 641
            last exit code = (never exited)
        }
        """

        let runtime = BrewServiceItem.parseLaunchctlRuntime(output)

        #expect(runtime.isRunning)
        #expect(runtime.pid == 641)
    }

    @Test("brewServiceItem_parseLaunchctlRuntime_detectsStoppedSystemService")
    func parseLaunchctlRuntimeDetectsStoppedSystemService() {
        let output = """
        system/homebrew.mxcl.example = {
            state = not running
            last exit code = 0
        }
        """

        let runtime = BrewServiceItem.parseLaunchctlRuntime(output)

        #expect(!runtime.isRunning)
        #expect(runtime.pid == nil)
    }

    @Test("brewService_searchFormulae_returnsNameArray")
    func brewService_searchFormulae_returnsNameArray() async throws {
        let mock = MockBrewProcess(stubbedOutput: ProcessOutput(
            stdout: "httpie\nhttpx\nhttp-server\n",
            stderr: "",
            exitCode: 0
        ))
        let service = BrewService(process: mock)

        let results = try await service.searchFormulae("http")

        #expect(results.count == 3)
        #expect(results.contains("httpie"))
        #expect(results.contains("httpx"))
        #expect(results.contains("http-server"))
    }

    @Test("brewService_nonZeroExitCode_throwsProcessFailure")
    func brewService_nonZeroExitCode_throwsProcessFailure() async throws {
        let mock = MockBrewProcess(stubbedOutput: ProcessOutput(
            stdout: "",
            stderr: "command not found",
            exitCode: 1
        ))
        let service = BrewService(process: mock)

        await #expect(throws: BrewError.self) {
            _ = try await service.listFormulaeData()
        }
    }

    @Test("brewService_listCasksData_returnsRawData")
    func brewService_listCasksData_returnsRawData() async throws {
        let json = String(data: try fixtureData("cask_installed.json"), encoding: .utf8)!
        let mock = MockBrewProcess(stubbedOutput: ProcessOutput(stdout: json, stderr: "", exitCode: 0))
        let service = BrewService(process: mock)

        let data = try await service.listCasksData()

        #expect(!data.isEmpty)
        let response = try JSONDecoder().decode(BrewJSONResponse.self, from: data)
        #expect(response.casks?.count == 1)
        #expect(response.casks?.first?.token == "firefox")
    }

    @Test("brewService_packageCommands_passKindFlagsAndOptions")
    func brewService_packageCommands_passKindFlagsAndOptions() async throws {
        let process = RecordingBrewProcess()
        let service = BrewService(process: process)

        for try await _ in service.reinstall("wget", isCask: false) {}
        for try await _ in service.upgradeGreedy(cask: "firefox") {}
        try await service.uninstall(formula: "openssl@3", ignoringDependents: true)
        try await service.uninstall(cask: "firefox", zap: true)
        _ = try await service.infoData(["wget", "jq"], isCask: false)

        #expect(process.streamedArguments == [
            ["reinstall", "--formula", "wget"],
            ["upgrade", "--cask", "--greedy", "firefox"],
        ])
        #expect(process.runArguments == [
            ["uninstall", "--formula", "--ignore-dependencies", "openssl@3"],
            ["uninstall", "--cask", "--zap", "firefox"],
            ["info", "--json=v2", "--formula", "wget", "jq"],
        ])
    }
}
