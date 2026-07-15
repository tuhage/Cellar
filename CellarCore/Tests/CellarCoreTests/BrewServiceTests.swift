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
}
