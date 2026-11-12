// ExperienceErrorTests — feature 188 T-U02-004 (FR-U02-063): every error of the contract has the stable code that
// contracts/experience-core-api.md states, and a failure is always storable.
import Foundation
import Testing
import VisualCoreExperience

@Suite struct ExperienceErrorTests {
    @Test func digestAndSnapshotCodes() {
        #expect(DigestError.nonFinite(field: 3).code == "digest.non-finite")
        let table: [(SnapshotError, String)] = [
            (.wrongExperience(found: "a01.x"), "snapshot.wrong-experience"),
            (.unknownFormat(2), "snapshot.unknown-format"),
            (.newerSchema(found: 3, current: 2), "snapshot.newer-schema"),
            (.missingMigration(from: 0), "snapshot.missing-migration"),
            (.corrupt(reason: "x"), "snapshot.corrupt"),
            (.checksumMismatch, "snapshot.checksum-mismatch"),
            (.tooLarge(bytes: 2_000_000), "snapshot.too-large"),
            (.stateMismatch(expected: "a", found: "b"), "snapshot.state-mismatch"),
        ]
        for (error, code) in table { #expect(error.code == code) }
        #expect(Set(table.map(\.1)).count == 8)
    }

    @Test func actionCodes() {
        let table: [(ActionRejection, String)] = [
            (.unknownControl("x"), "action.unknown-control"),
            (.wrongValueCount(expected: 2, found: 1), "action.wrong-value-count"),
            (.nonFinite(index: 0), "action.non-finite"),
            (.outOfRange(index: 1), "action.out-of-range"),
            (.notActive(.suspended), "action.not-active"),
            (.wrongStep(expected: 4, found: 3), "action.wrong-step"),
            (.rule(code: "sample.wall"), "action.rule.sample.wall"),
        ]
        for (rejection, code) in table {
            #expect(rejection.code == code)
            #expect(ActionResult.rejected(rejection).code == code)
            #expect(!ActionResult.rejected(rejection).isAccepted)
        }
        #expect(ActionResult.accepted.code == "accepted")
        #expect(ActionResult.accepted.isAccepted)
    }

    @Test func experienceErrorCodes() {
        let own = ExperienceFailure(code: "sample.broken", message: "broken on purpose")
        let table: [(ExperienceError, String)] = [
            (.illegalOperation(.activate, in: .registered), "experience.illegal-operation"),
            (.notPrepared, "experience.not-prepared"),
            (.cancelled, "experience.cancelled"),
            (.preparationTimedOut, "experience.preparation-timeout"),
            (.stalePreparation, "experience.stale-preparation"),
            (.failed(own), "sample.broken"),
            (.invalidTier(3, tiers: 3), "experience.invalid-tier"),
            (.gpuLeak(live: 1, leaked: 0), "experience.gpu-leak"),
            (.snapshot(.checksumMismatch), "snapshot.checksum-mismatch"),
            (.digest(.nonFinite(field: 0)), "digest.non-finite"),
        ]
        for (error, code) in table {
            #expect(error.code == code)
            #expect(error.failure.code == code)
            #expect(!error.failure.message.isEmpty)
        }
        #expect(ExperienceError.failed(own).failure == own)
        #expect(ExperienceError.illegalOperation(.activate, in: .registered).failure.message.contains("activate"))
        #expect(ExperienceError.illegalOperation(.activate, in: .registered).failure.message.contains("registered"))
    }

    @Test func aFailureIsAlwaysStorable() throws {
        #expect(ExperienceFailure(code: "", message: "m").code == "experience.unspecified")
        #expect(ExperienceFailure(code: String(repeating: "a", count: 65), message: "m").code == "experience.unspecified")
        #expect(ExperienceFailure(code: String(repeating: "a", count: 64), message: "m").code.count == 64)
        #expect(ExperienceFailure(code: "Sample.Broken", message: "m").code == "experience.unspecified")
        #expect(ExperienceFailure(code: "sample broken", message: "m").code == "experience.unspecified")
        #expect(ExperienceFailure(code: "sample.broken-2", message: "m").code == "sample.broken-2")
        #expect(ExperienceFailure(code: "a.b", message: String(repeating: "x", count: 900)).message.count == 500)

        let failure = ExperienceFailure(code: "sample.broken", message: "broken on purpose")
        let data = try JSONEncoder().encode(failure)
        #expect(try JSONDecoder().decode(ExperienceFailure.self, from: data) == failure)
        let foreign = Data(#"{"code":"NOT VALID","message":"m"}"#.utf8)
        #expect(try JSONDecoder().decode(ExperienceFailure.self, from: foreign).code == "experience.unspecified")
    }

    @Test func statesAndOperationsAreComplete() {
        #expect(ExperienceLifecycleState.allCases.count == 8)
        #expect(ExperienceOperation.allCases.count == 12)
        let event = ExperienceLifecycleEvent(from: .registered, to: .preparing, accepted: true)
        #expect(event.from == .registered && event.to == .preparing && event.accepted)
    }
}
