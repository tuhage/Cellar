import Foundation
import Observation
import CellarCore

// MARK: - ServiceMetricsStore

/// CPU and memory of running services, measured from one `ps` snapshot per
/// sample and kept for a few minutes so views can chart them.
@Observable
@MainActor
final class ServiceMetricsStore {

    // MARK: Data

    /// Latest sample per service name.
    private(set) var usages: [String: ResourceUsage] = [:]
    /// Samples from the last `historyWindow` per service name, oldest first.
    private(set) var history: [String: [ResourceUsage]] = [:]

    // MARK: Configuration

    static let sampleInterval: Duration = .seconds(5)
    static let historyWindow: TimeInterval = 10 * 60
    /// A CPU rate is measured against the previous sample only if it is this
    /// recent; older ones would average over a long, unrelated stretch.
    private static let rateWindow: TimeInterval = 60
    /// Samples closer together than this are skipped: tiny intervals make
    /// the CPU rate noisy, and the menu bar may sample while a page does.
    private static let minimumSpacing: TimeInterval = 2

    private var lastSampledAt: Date?

    // MARK: Computed

    var totalCPU: Double {
        usages.values.reduce(0) { $0 + $1.cpuPercent }
    }

    var totalMemoryBytes: Int64 {
        usages.values.reduce(0) { $0 + $1.memoryBytes }
    }

    func usage(for service: BrewServiceItem) -> ResourceUsage? {
        usages[service.name]
    }

    func history(for service: BrewServiceItem) -> [ResourceUsage] {
        history[service.name] ?? []
    }

    // MARK: Sampling

    /// Takes one sample of the running services. PIDs are looked up afresh,
    /// since the services list may come from a cache.
    func refresh(for services: [BrewServiceItem]) async {
        if let lastSampledAt, Date().timeIntervalSince(lastSampledAt) < Self.minimumSpacing { return }
        let running = services.filter(\.isRunning)
        guard !running.isEmpty else {
            usages = [:]
            history = [:]
            return
        }

        async let currentPIDs = BrewServiceItem.currentPIDs(of: running)
        async let currentTable = ProcessTable.current()
        guard let table = await currentTable else { return }
        let pids = await currentPIDs

        var latest: [String: ResourceUsage] = [:]
        for (name, pid) in pids {
            let previous = usages[name].flatMap { previous in
                table.capturedAt.timeIntervalSince(previous.timestamp) < Self.rateWindow ? previous : nil
            }
            latest[name] = ResourceUsage.measure(serviceName: name, pid: pid, in: table, previous: previous)
        }
        usages = latest
        lastSampledAt = table.capturedAt
        appendToHistory(latest)
    }

    /// Samples every `sampleInterval` until cancelled; run it from `.task`
    /// while a page shows metrics.
    func monitor(_ services: @escaping @MainActor () -> [BrewServiceItem]) async {
        while !Task.isCancelled {
            await refresh(for: services())
            try? await Task.sleep(for: Self.sampleInterval)
        }
    }

    // MARK: Private

    private func appendToHistory(_ latest: [String: ResourceUsage]) {
        let cutoff = Date().addingTimeInterval(-Self.historyWindow)
        history = latest.mapValues { usage in
            let kept = history[usage.serviceName, default: []].filter { $0.timestamp > cutoff && $0.pid == usage.pid }
            return kept + [usage]
        }
    }
}
