import Testing
import Foundation
@testable import CellarCore

@Suite("Brewfile library")
struct BrewfileLibraryTests {

    private func makeTempPersistence() throws -> (PersistenceService, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CellarCoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (PersistenceService(baseURL: directory), directory)
    }

    // MARK: Migration

    @Test("brewfileLibrary_migrated_turnsProfilesIntoMacBrewfiles")
    func brewfileLibrary_migrated_turnsProfilesIntoMacBrewfiles() {
        let exported = Date(timeIntervalSince1970: 1_700_000_000)
        let library = BrewfileLibrary.migrated(
            profiles: [
                .init(id: UUID(), name: "Default", path: Brewfile.defaultMacPath, lastExported: exported),
                .init(id: UUID(), name: "Work", path: "/Users/me/Brewfile-Work", lastExported: nil),
            ],
            projects: [],
            activeProjectID: nil
        )

        #expect(library.brewfiles.map(\.kind) == [.mac, .mac])
        #expect(library.brewfiles.map(\.name) == ["This Mac", "Work"])
        #expect(library.brewfiles.first?.lastExported == exported)
    }

    @Test("brewfileLibrary_migrated_keepsProjectServicesPackagesAndActivation")
    func brewfileLibrary_migrated_keepsProjectServicesPackagesAndActivation() {
        let projectID = UUID()
        let library = BrewfileLibrary.migrated(
            profiles: [],
            projects: [
                .init(id: projectID, name: "Web", path: "/Users/me/Projects/web",
                      services: ["postgresql@16", "redis"], packages: ["node"]),
                .init(id: UUID(), name: "API", path: "/Users/me/Projects/api/Brewfile", services: nil, packages: nil),
            ],
            activeProjectID: projectID
        )

        let web = library.brewfiles[0]
        #expect(web.id == projectID)
        #expect(web.kind == .project)
        #expect(web.path == "/Users/me/Projects/web/Brewfile")
        #expect(web.services == ["postgresql@16", "redis"])
        #expect(web.pendingPackages == ["node"])
        #expect(library.brewfiles[1].path == "/Users/me/Projects/api/Brewfile")
        #expect(library.activation == ProjectActivation(brewfileID: projectID, startedServices: ["postgresql@16", "redis"]))
    }

    @Test("brewfileLibrary_load_readsLegacyFilesAndLeavesThemInPlace")
    func brewfileLibrary_load_readsLegacyFilesAndLeavesThemInPlace() throws {
        let (persistence, directory) = try makeTempPersistence()
        let projectID = UUID()
        try Data("""
        [{"id":"\(projectID.uuidString)","name":"Web","path":"/tmp/web","services":["redis"],"packages":[],"autoStart":true}]
        """.utf8).write(to: directory.appendingPathComponent("project_environments.json"))
        try persistence.save(Optional(projectID), to: "active_project_id.json")

        let library = BrewfileLibrary.load(using: persistence)

        #expect(library.brewfiles.map(\.name) == ["Web"])
        #expect(library.activation?.brewfileID == projectID)
        #expect(persistence.exists(fileName: "project_environments.json"))
    }

    @Test("brewfileLibrary_load_prefersSavedLibraryOverLegacyFiles")
    func brewfileLibrary_load_prefersSavedLibraryOverLegacyFiles() throws {
        let (persistence, _) = try makeTempPersistence()
        let saved = BrewfileLibrary(brewfiles: [Brewfile(kind: .mac, name: "This Mac", path: "/tmp/Brewfile")])
        try persistence.save(saved, to: BrewfileLibrary.fileName)
        try persistence.save([["id": UUID().uuidString, "name": "Old", "path": "/tmp/old"]], to: "brewfile_profiles.json")

        #expect(BrewfileLibrary.load(using: persistence) == saved)
    }

    // MARK: Brewfile Files

    @Test("brewfile_addFormulae_appendsOnlyMissingPackagesAndNeverOverwrites")
    func brewfile_addFormulae_appendsOnlyMissingPackagesAndNeverOverwrites() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Brewfile-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let brewfile = Brewfile(kind: .project, name: "Test", path: Brewfile.path(forFileOrFolder: folder))
        try brewfile.write("# Keep me\nbrew \"wget\"\n")

        #expect(try !brewfile.createIfMissing())
        let added = try brewfile.addFormulae(["wget", "jq"])

        #expect(added == ["jq"])
        #expect(try brewfile.read() == "# Keep me\nbrew \"wget\"\nbrew \"jq\"\n")
    }

    @Test("brewfile_backUp_keepsPreviousVersion")
    func brewfile_backUp_keepsPreviousVersion() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("Brewfile-\(UUID().uuidString)").path
        let brewfile = Brewfile(kind: .mac, name: "This Mac", path: path)
        try brewfile.write("brew \"wget\"\n")

        try brewfile.backUp()
        try brewfile.write("brew \"jq\"\n")
        try brewfile.backUp()

        #expect(try String(contentsOf: brewfile.backupURL, encoding: .utf8) == "brew \"jq\"\n")
    }
}
