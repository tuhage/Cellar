import Testing
import Foundation
@testable import CellarCore

@Suite("PersistenceService")
struct PersistenceServiceTests {

    private func makeTempService() throws -> (PersistenceService, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CellarCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return (PersistenceService(baseURL: tempDir), tempDir)
    }

    @Test("persistenceService_saveAndLoad_roundTripsValue")
    func persistenceService_saveAndLoad_roundTripsValue() throws {
        let (service, _) = try makeTempService()
        let original = ["openssl@3", "wget", "curl"]

        try service.save(original, to: "test.json")
        let loaded = try service.load([String].self, from: "test.json")

        #expect(loaded == original)
    }

    @Test("persistenceService_loadOrDefault_returnsDefaultWhenFileAbsent")
    func persistenceService_loadOrDefault_returnsDefaultWhenFileAbsent() throws {
        let (service, _) = try makeTempService()
        let fallback = ["default"]

        let result = service.loadOrDefault([String].self, from: "nonexistent.json", default: fallback)

        #expect(result == fallback)
    }

    @Test("persistenceService_loadOrDefault_returnsDefaultWhenCorrupt")
    func persistenceService_loadOrDefault_returnsDefaultWhenCorrupt() throws {
        let (service, tempDir) = try makeTempService()
        let corruptData = Data("this is not valid json }{".utf8)
        try corruptData.write(to: tempDir.appendingPathComponent("corrupt.json"))

        let result = service.loadOrDefault([String].self, from: "corrupt.json", default: [])

        #expect(result == [])
    }

    @Test("persistenceService_saveToCache_andLoadCacheEntry_returnsDataWithTimestamp")
    func persistenceService_saveToCache_andLoadCacheEntry_returnsDataWithTimestamp() throws {
        let (service, _) = try makeTempService()
        let value = ["redis", "postgresql@16"]
        let before = Date()

        service.saveToCache(value, to: "cache.json")
        let entry = service.loadCacheEntry([String].self, from: "cache.json")

        #expect(entry?.data == value)
        #expect(entry.map { $0.timestamp >= before } == true)
    }

    @Test("persistenceService_loadCacheEntry_returnsNilWhenFileAbsent")
    func persistenceService_loadCacheEntry_returnsNilWhenFileAbsent() throws {
        let (service, _) = try makeTempService()

        #expect(service.loadCacheEntry([String].self, from: "no-cache.json") == nil)
    }
}
