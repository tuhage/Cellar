import Foundation

/// `brew services` commands. `privileged` runs them as root, which services
/// registered under `root` (LaunchDaemons) need.
extension BrewService {

    public func listServicesData() async throws -> Data {
        try await runJSON(["services", "list", "--json"])
    }

    /// Details `list` lacks: log paths, the command, its schedule.
    public func serviceInfoData(_ name: String) async throws -> Data {
        try await runJSON(["services", "info", name, "--json"])
    }

    /// Starts the service and registers it to start at login (boot for root).
    public func startService(_ name: String, privileged: Bool = false) async throws {
        try await runChecked(["services", "start", name], privileged: privileged)
    }

    /// Starts the service without registering it to start at login.
    public func runService(_ name: String, privileged: Bool = false) async throws {
        try await runChecked(["services", "run", name], privileged: privileged)
    }

    /// Stops the service. With `keepRegistered` it still starts at next login.
    public func stopService(_ name: String, keepRegistered: Bool = false, privileged: Bool = false) async throws {
        let keep = keepRegistered ? ["--keep"] : []
        try await runChecked(["services", "stop"] + keep + [name], privileged: privileged)
    }

    public func restartService(_ name: String, privileged: Bool = false) async throws {
        try await runChecked(["services", "restart", name], privileged: privileged)
    }

    /// Restarts root services under a single password prompt.
    public func restartServicesPrivileged(_ names: [String]) async throws {
        try await runPrivilegedChecked(names.map { .brew(["services", "restart", $0]) })
    }

    /// Sends SIGKILL to a service's process. `brew services kill` only asks
    /// launchd to stop the job, which does nothing for a KeepAlive service.
    public func forceQuit(pid: Int, privileged: Bool = false) async throws {
        if privileged {
            try await runPrivilegedChecked([.tool(path: "/bin/kill", arguments: ["-KILL", String(pid)])])
        } else if kill(pid_t(pid), SIGKILL) != 0 {
            let code = errno
            throw BrewError.processFailure(exitCode: code, stderr: String(cString: strerror(code)))
        }
    }
}
