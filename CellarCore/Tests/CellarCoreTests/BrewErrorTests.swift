import Testing
import Foundation
@testable import CellarCore

@Suite("BrewError")
struct BrewErrorTests {

    @Test("brewError_processFailure_descriptionContainsExitCodeAndStderr")
    func brewError_processFailure_descriptionContainsExitCodeAndStderr() {
        let error = BrewError.processFailure(exitCode: 1, stderr: "formula not found")

        let description = error.errorDescription ?? ""
        #expect(description.contains("1"))
        #expect(description.contains("formula not found"))
    }

    @Test("brewError_parsingFailure_descriptionContainsContext")
    func brewError_parsingFailure_descriptionContainsContext() {
        let error = BrewError.parsingFailure(context: "Invalid UTF-8")

        let description = error.errorDescription ?? ""
        #expect(description.contains("Invalid UTF-8"))
    }

    @Test("brewError_brewNotFound_descriptionMentionsHomebrew")
    func brewError_brewNotFound_descriptionMentionsHomebrew() {
        let error = BrewError.brewNotFound

        let description = error.errorDescription ?? ""
        #expect(description.contains("Homebrew"))
    }

    @Test("brewError_commandTimeout_hasDescription")
    func brewError_commandTimeout_hasDescription() {
        let error = BrewError.commandTimeout

        #expect(error.errorDescription != nil)
        #expect(!(error.errorDescription ?? "").isEmpty)
    }

    @Test("brewError_cancelled_hasDescription")
    func brewError_cancelled_hasDescription() {
        let error = BrewError.cancelled

        #expect(error.errorDescription != nil)
        #expect(!(error.errorDescription ?? "").isEmpty)
    }
}
