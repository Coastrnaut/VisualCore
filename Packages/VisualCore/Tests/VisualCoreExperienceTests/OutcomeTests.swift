// OutcomeTests — feature 195 T-U09-002 (UA-F09; FR-U09-004; research R1): the outcome of an experience. A code is
// 1 to 64 characters of a-z, 0-9 and -, encoded as a plain string; a core without an outcome reports nil through
// the engine; the sample reports `target-reached` exactly while its marker is on the target, without changing any
// committed digest; the diagnostics carry the outcome only when there is one.
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreTestSupport

/// A core that does not implement `outcome`, so it gets the default.
private struct OutcomelessCore: ExperienceCore, Codable, Equatable {
    var value = 0
    static var migrations: MigrationChain { MigrationChain(currentVersion: 1) }
    static var controls: [ExperienceControl] { [] }
    static func prepare(seed: UInt64) async throws -> OutcomelessCore { OutcomelessCore(value: Int(seed % 7)) }
    mutating func update(step: Int) { value = (value + 1) % 1_000 }
    mutating func apply(_ action: ExperienceAction) -> ActionResult { .rejected(.unknownControl(action.control)) }
    mutating func reset() { value = 0 }
    func writeDigest(into builder: inout DigestBuilder) throws(DigestError) { builder.add(value) }
}

/// The outcome of any core, read through a generic, so the core's own implementation must be dispatched.
private func genericOutcome<Core: ExperienceCore>(of core: Core) -> ExperienceOutcome? { core.outcome }

/// -1, 0 or 1: the direction from `from` towards `to`.
private func step(from: Int, to: Int) -> Double {
    if to > from { return 1 }
    if to < from { return -1 }
    return 0
}

@Suite struct OutcomeTests {
    // MARK: Codes

    @Test func validCodesAreAccepted() {
        let valid = ["a", "target-reached", "level-2-solved", "0", "-", String(repeating: "z", count: 64)]
        for code in valid {
            let outcome = ExperienceOutcome(code: code)
            #expect(outcome?.code == code, "\(code)")
        }
    }

    @Test func invalidCodesAreRefused() {
        let invalid = ["", String(repeating: "z", count: 65), "Upper", "space x", "ü", "a_b", "e\u{301}", "tab\t",
                       "dot.ted"]
        for code in invalid {
            let outcome = ExperienceOutcome(code: code)
            #expect(outcome == nil, "\(code.debugDescription)")
        }
    }

    // MARK: Coding

    @Test func anOutcomeEncodesAsAPlainStringAndRoundTrips() throws {
        let outcome = try #require(ExperienceOutcome(code: "target-reached"))
        let data = try JSONEncoder().encode(outcome)
        let text = String(data: data, encoding: .utf8)
        #expect(text == "\"target-reached\"")
        let decoded = try JSONDecoder().decode(ExperienceOutcome.self, from: data)
        #expect(decoded == outcome)
    }

    @Test func anInvalidStringDoesNotDecode() {
        for text in ["\"Upper\"", "\"\"", "\"a_b\"", "\"\(String(repeating: "z", count: 65))\"", "42", "{}"] {
            let result = Result { try JSONDecoder().decode(ExperienceOutcome.self, from: Data(text.utf8)) }
            var failed = false
            if case .failure(let error) = result { failed = error is DecodingError }
            #expect(failed, "\(text)")
        }
        var isDataCorrupted = false
        do {
            _ = try JSONDecoder().decode(ExperienceOutcome.self, from: Data("\"Upper\"".utf8))
        } catch DecodingError.dataCorrupted {
            isDataCorrupted = true
        } catch {
            isDataCorrupted = false
        }
        #expect(isDataCorrupted)
    }

    // MARK: Default

    @Test func aCoreWithoutAnOutcomeReportsNilThroughTheEngine() async throws {
        let id = try #require(ExperienceID(rawValue: "a98.outcome-plain"))
        var engine = ExperienceEngine<OutcomelessCore>(id: id)
        #expect(engine.outcome == nil)
        try await engine.prepare(seed: 3)
        #expect(engine.outcome == nil)
        try engine.activate()
        try engine.run(steps: 10)
        #expect(engine.outcome == nil)
        #expect(engine.diagnostics().outcome == nil)
    }

    // MARK: Sample

    @Test func theSampleReportsTargetReachedExactlyWhileTheMarkerIsOnTheTarget() async throws {
        var engine = try await makeSampleEngine(in: .active, seed: 42)
        let prepared = try #require(engine.core)
        let startsOnTarget = prepared.x == prepared.targetX && prepared.y == prepared.targetY
        #expect((engine.outcome != nil) == startsOnTarget)

        // Walk the marker to the target; a diagonal move covers both axes, so 15 moves always suffice.
        var moves = 0
        while let core = engine.core, core.x != core.targetX || core.y != core.targetY, moves < Sample.boardSize {
            #expect(engine.outcome == nil)
            let result = engine.handle(control: "move", values: [step(from: core.x, to: core.targetX),
                                                                 step(from: core.y, to: core.targetY)])
            #expect(result.isAccepted)
            moves += 1
        }
        let onTarget = try #require(engine.core)
        #expect(onTarget.x == onTarget.targetX && onTarget.y == onTarget.targetY)
        let reached = try #require(ExperienceOutcome(code: "target-reached"))
        #expect(engine.outcome == reached)
        #expect(onTarget.outcome == reached)
        #expect(genericOutcome(of: onTarget) == reached)
        #expect(engine.diagnostics().outcome == reached)

        // One move away from the target ends the outcome.
        let away: Double = onTarget.x < Sample.boardSize - 1 ? 1 : -1
        let result = engine.handle(control: "move", values: [away, 0])
        #expect(result.isAccepted)
        #expect(engine.outcome == nil)
        #expect(engine.diagnostics().outcome == nil)
    }

    @Test func theFaultySamplesCompileAndReportTheSameOutcome() async throws {
        let core = try await SampleExperienceCore<LossySnapshot>.prepare(seed: 42)
        #expect((core.outcome != nil) == (core.x == core.targetX && core.y == core.targetY))
    }

    @Test func theCommittedDigestsAreUnchanged() async throws {
        let seeds: Set<UInt64> = [0, 42]
        let checked = SampleExperience.goldenDigests.filter { seeds.contains($0.seed) }
        #expect(checked.count == 2)
        for (seed, hex) in SampleExperience.goldenDigests {
            var engine = SampleEngine(id: SampleExperience.id)
            try await engine.prepare(seed: seed)
            _ = engine.outcome
            let digest = try engine.digest()
            #expect(digest.hex == hex, "seed \(seed)")
        }
    }

    // MARK: Diagnostics

    @Test func diagnosticsEncodeTheOutcomeOnlyWhenPresent() async throws {
        let fresh = SampleEngine(id: SampleExperience.id).diagnostics()
        #expect(fresh.outcome == nil)
        let freshData = try fresh.encoded()
        let freshText = try #require(String(data: freshData, encoding: .utf8))
        #expect(!freshText.contains("\"outcome\""))

        // Decoding a value without the key gives nil.
        let decodedFresh = try JSONDecoder().decode(ExperienceDiagnostics.self, from: freshData)
        #expect(decodedFresh.outcome == nil)
        #expect(decodedFresh == fresh)

        let reached = try #require(ExperienceOutcome(code: "target-reached"))
        let withOutcome = ExperienceDiagnostics(experience: SampleExperience.id, state: .active, seed: 42, stepIndex: 3,
                                                qualityTier: 0, gpu: nil, lastError: nil, digest: nil,
                                                rejectedTransitions: 0, rejectedOperations: 0, acceptedActions: 1,
                                                rejectedActions: 0, droppedTime: 0, invalidFrames: 0,
                                                outcome: reached)
        let data = try withOutcome.encoded()
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("\"outcome\":\"target-reached\""))
        let decoded = try JSONDecoder().decode(ExperienceDiagnostics.self, from: data)
        #expect(decoded.outcome == reached)
        #expect(decoded == withOutcome)
    }
}
