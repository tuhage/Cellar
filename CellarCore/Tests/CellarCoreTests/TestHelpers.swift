import Foundation
import Testing

func fixtureData(_ filename: String) throws -> Data {
    guard let url = Bundle.module.url(forResource: filename, withExtension: nil, subdirectory: "Fixtures") else {
        Issue.record("Fixture not found: \(filename)")
        throw CocoaError(.fileNoSuchFile)
    }
    return try Data(contentsOf: url)
}
