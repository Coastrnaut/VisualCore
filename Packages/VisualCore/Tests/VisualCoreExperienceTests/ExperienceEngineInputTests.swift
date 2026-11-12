// ExperienceEngineInputTests — feature 188 T-U02-024 (US4; FR-U02-032 to FR-U02-036, FR-U02-085; SC-U02-004): the
// engine's action door, proven with the sample experience.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreSimulation
import VisualCoreTestSupport

@Suite struct ExperienceEngineInputTests {
    /// An active sample whose marker stands in the corner (0, 0), so that a move to the left hits the wall.
    private func engineInTheCorner() async throws -> SampleEngine {
        var engine = try await makeSampleEngine(in: .active, seed: 42)
        while let core = engine.core, core.x > 0 { _ = engine.handle(control: "move", values: [-1, 0]) }
        while let core = engine.core, core.y > 0 { _ = engine.handle(control: "move", values: [0, -1]) }
        #expect(engine.core?.x == 0 && engine.core?.y == 0)
        return engine
    }

    @Test func everyRejectionHasItsCodeAndChangesNothing() async throws {
        var engine = try await engineInTheCorner()
        let rows: [(control: String, values: [Double], code: String)] = [
            ("jump", [], "action.unknown-control"),
            ("move", [1], "action.wrong-value-count"),
            ("ping", [1], "action.wrong-value-count"),
            ("tone", [.nan], "action.non-finite"),
            ("move", [0, .infinity], "action.non-finite"),
            ("tone", [2], "action.out-of-range"),
            ("move", [0, -1.5], "action.out-of-range"),
            ("move", [-1, 0], "action.rule.sample.wall"),
            ("move", [0, 0], "action.rule.sample.no-move"),
        ]
        var codes = Set<String>()
        for row in rows {
            let digest = try engine.digest()
            let calls = engine.core?.applyCalls
            let rejectedBefore = engine.rejectedActions
            let result = engine.handle(control: row.control, values: row.values)
            #expect(result.code == row.code, "\(row.control) \(row.values)")
            #expect(try engine.digest() == digest, "\(row.code)")
            #expect(engine.rejectedActions == rejectedBefore + 1)
            if !row.code.hasPrefix("action.rule.") {
                #expect(engine.core?.applyCalls == calls, "\(row.code) reached the core")
            }
            codes.insert(result.code)
        }

        let stale = engine.handle(ExperienceAction(control: "ping", values: [], step: engine.stepIndex + 1))
        #expect(stale == .rejected(.wrongStep(expected: engine.stepIndex, found: engine.stepIndex + 1)))
        codes.insert(stale.code)

        for state in ExperienceLifecycleState.allCases where state != .active {
            var other = try await makeSampleEngine(in: state)
            let before = other
            let result = other.handle(control: "ping")
            #expect(result == .rejected(.notActive(state)))
            #expect(other.lifecycle.rejectedOperations == before.lifecycle.rejectedOperations + 1)
            #expect(other.rejectedActions == before.rejectedActions + 1)
            #expect((try? other.digest()) == (try? before.digest()))
            #expect(other.core?.applyCalls == before.core?.applyCalls)
            codes.insert(result.code)
        }
        #expect(codes == ["action.unknown-control", "action.wrong-value-count", "action.non-finite", "action.out-of-range",
                          "action.rule.sample.wall", "action.rule.sample.no-move", "action.wrong-step", "action.not-active"])
    }

    @Test func acceptedActionsChangeTheStateAsDocumented() async throws {
        var engine = try await engineInTheCorner()
        let accepted = engine.acceptedActions
        let energy = try #require(engine.core?.energy)
        #expect(engine.handle(control: "move", values: [1, 1]) == .accepted)
        #expect(engine.core?.x == 1 && engine.core?.y == 1)
        #expect(engine.core?.energy == energy + 1)
        #expect(engine.handle(control: "move", values: [0.6, -0.6]) == .accepted)
        #expect(engine.core?.x == 2 && engine.core?.y == 0)
        #expect(engine.handle(control: "tone", values: [0.25]) == .accepted)
        #expect(engine.core?.tone == 0.25)
        let digest = try engine.digest()
        #expect(engine.handle(control: "ping") == .accepted)
        #expect(try engine.digest() == digest)
        #expect(engine.acceptedActions == accepted + 4)
    }

    @Test func aCoreThatChangesStateWhileRejectingIsRolledBack() async throws {
        var engine = ExperienceEngine<SampleExperienceCore<MutatingRejection>>(id: SampleExperience.id)
        try await engine.prepare(seed: 42)
        try engine.activate()
        let digest = try engine.digest()
        #expect(engine.handle(control: "move", values: [0, 0]).code == "action.rule.sample.no-move")
        #expect(try engine.digest() == digest)
        // The core itself, called without the engine, does change: that is what the conformance helper reports.
        var core = try #require(engine.core)
        _ = core.apply(ExperienceAction(control: "move", values: [0, 0], step: 0))
        #expect(core.energy == 1)
    }

    @Test func aRecordedRunReplaysToTheSameDigest() async throws {
        var generator = SplitMix64(seed: 2026)
        var original = try await makeSampleEngine(in: .active, seed: 7)
        var log: [ExperienceAction] = []
        var results: [ActionResult] = []
        for _ in 0..<200 {
            try original.run(steps: Int(generator.next() % 4))
            let action: ExperienceAction
            switch generator.next() % 3 {
            case 0:
                let dx = Double(Int(generator.next() % 3)) - 1, dy = Double(Int(generator.next() % 3)) - 1
                action = ExperienceAction(control: "move", values: [dx, dy], step: original.stepIndex)
            case 1:
                action = ExperienceAction(control: "tone", values: [Double(generator.next() % 101) / 100], step: original.stepIndex)
            default:
                action = ExperienceAction(control: "ping", step: original.stepIndex)
            }
            log.append(action)
            results.append(original.handle(action))
        }
        #expect(results.contains(.accepted))
        #expect(results.contains { !$0.isAccepted })

        var replay = try await makeSampleEngine(in: .active, seed: 7)
        var replayed: [ActionResult] = []
        for action in log {
            try replay.run(steps: action.step - replay.stepIndex)
            replayed.append(replay.handle(action))
        }
        #expect(replayed == results)
        #expect(try replay.digest() == (try original.digest()))
        #expect(replay.stepIndex == original.stepIndex)

        // Only the accepted actions, at their steps, give the same state too (FR-U02-036).
        var acceptedOnly = try await makeSampleEngine(in: .active, seed: 7)
        for (action, result) in zip(log, results) where result.isAccepted {
            try acceptedOnly.run(steps: action.step - acceptedOnly.stepIndex)
            #expect(acceptedOnly.handle(action) == .accepted)
        }
        try acceptedOnly.run(steps: original.stepIndex - acceptedOnly.stepIndex)
        #expect(try acceptedOnly.digest() == (try original.digest()))
    }

    @Test func generatedActionsNeverStopTheProcess() async throws {
        var generator = SplitMix64(seed: 85)
        var engine = try await makeSampleEngine(in: .active, seed: 3)
        let controls = ["move", "tone", "ping", "", "jump", "MOVE", "move ", "🙂", String(repeating: "x", count: 5_000)]
        let specials: [Double] = [.nan, .infinity, -.infinity, .greatestFiniteMagnitude, -.greatestFiniteMagnitude, 0, -0.0, 1, -1,
                                  0.5, 1e300, .leastNonzeroMagnitude]
        var answered = 0
        for _ in 0..<1_000 {
            let control = controls[Int(generator.next() % UInt64(controls.count))]
            let values = (0..<Int(generator.next() % 13)).map { _ in specials[Int(generator.next() % UInt64(specials.count))] }
            let steps: [Int] = [engine.stepIndex, 0, -1, .max, .min, engine.stepIndex + 1]
            let step = steps[Int(generator.next() % UInt64(steps.count))]
            let result = engine.handle(ExperienceAction(control: control, values: values, step: step))
            #expect(!result.code.isEmpty)
            answered += 1
        }
        #expect(answered == 1_000)
        #expect(engine.acceptedActions + engine.rejectedActions == 1_000)
        _ = try engine.digest()
    }
}
