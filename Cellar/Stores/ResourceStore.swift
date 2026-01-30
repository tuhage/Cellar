import Foundation
import Observation
import CellarCore

// MARK: - ResourceStore

/// Manages resource-usage state for running Homebrew services and disk consumption.
///
/// Queries `ps` for per-service CPU/memory and `du` for Homebrew directory sizes.
/// Views bind to this store for the resource monitoring UI.
@Observable
@MainActor
final class ResourceStore {

    // MARK: Data

    var usages: [ResourceUsage] = []
    var diskUsage: DiskUsage?

    // MARK: State

    var isLoading = false
    var errorMessage: String?

    // MARK: Computed

    var totalCPU: Double {
        usages.reduce(0) { $0 + $1.cpuPercent }
    }

    var totalMemoryMB: Double {
        usages.reduce(0) { $0 + $1.memoryMB }
    }

    var sortedUsages: [ResourceUsage] {
        usages.sorted { $0.memoryMB > $1.memoryMB }
    }

    // MARK: Actions

    func loadResourceUsage(for services: [BrewServiceItem]) async {
        let runningServices = services.filter { $0.isRunning && $0.pid != nil }

        guard !runningServices.isEmpty else {
            usages = []
            return
        }

        var results: [ResourceUsage] = []

        for service in runningServices {
            guard let pid = service.pid else { continue }

            guard let output = try? await runCommand(
                "/bin/ps",
                ["-p", "\(pid)", "-o", "%cpu=,%mem=,rss="]
            ) else { continue }

            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(whereSeparator: \.isWhitespace)
            guard parts.count >= 3,
                  let cpu = Double(parts[0]),
                  let rssKB = Double(parts[2])
            else { continue }

            results.append(ResourceUsage(
                serviceName: service.name,
                pid: pid,
                cpuPercent: cpu,
                memoryMB: rssKB / 1024.0
            ))
        }

        usages = results
    }

    func loadDiskUsage() async {
        do {
            async let homebrewSize = fetchDirectorySize("/opt/homebrew")
            async let cellarSize = fetchDirectorySize("/opt/homebrew/Cellar")
            async let cacheSize = fetchDirectorySize(
                NSHomeDirectory() + "/Library/Caches/Homebrew"
            )

            diskUsage = DiskUsage(
                homebrewTotal: try await homebrewSize,
                cellarSize: try await cellarSize,
                cacheSize: try await cacheSize
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadAll(services: [BrewServiceItem]) async {
        isLoading = true
        errorMessage = nil

        async let resourceTask: () = loadResourceUsage(for: services)
        async let diskTask: () = loadDiskUsage()

        _ = await (resourceTask, diskTask)

        isLoading = false
    }

    // MARK: - Private Helpers

    /// Fetches the human-readable size of a directory using `du -sh`.
    private func fetchDirectorySize(_ path: String) async throws -> String {
        let output = try await runCommand("/usr/bin/du", ["-sh", path])
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)

        // du output format: "2.5G\t/path/to/dir"
        guard let tabIndex = trimmed.firstIndex(of: "\t") else {
            return "N/A"
        }

        let size = String(trimmed[trimmed.startIndex..<tabIndex])
            .trimmingCharacters(in: .whitespaces)

        return formatDuSize(size)
    }

    /// Converts compact `du` output (e.g. "2.5G") to a readable string (e.g. "2.5 GB").
    private func formatDuSize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        guard let lastChar = trimmed.last, lastChar.isLetter else {
            return trimmed
        }

        let number = String(trimmed.dropLast())
        let suffix: String = switch lastChar {
        case "K": "KB"
        case "M": "MB"
        case "G": "GB"
        case "T": "TB"
        case "B": "B"
        default: String(lastChar)
        }

        return "\(number) \(suffix)"
    }
}

// MARK: - Command Runner

/// Runs a generic system command and returns its stdout.
///
/// This is `nonisolated` so the `Process` work happens off the main actor.
/// The `ResourceStore` calls it from async methods that can hop off
/// the main actor for the duration of the process.
private nonisolated func runCommand(_ executablePath: String, _ arguments: [String]) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        process.terminationHandler = { _ in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            continuation.resume(returning: output)
        }

        do {
            try process.run()
        } catch {
            continuation.resume(throwing: error)
        }
    }
}
