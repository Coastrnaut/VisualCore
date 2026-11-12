// ExperienceEngineTests — feature 188 T-U02-015 (US2; FR-U02-006, FR-U02-011 to FR-U02-017, FR-U02-021 to
// FR-U02-025; SC-U02-002, SC-U02-005, SC-U02-010): preparation, lifecycle calls and fixed steps of the engine,
// proven with the sample experience.
import Foundation
import Testing
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreTestSupport

typealias Sample = SampleExperienceCore<NoFault>
typealias SampleEngine = ExperienceEngine<Sample>

/// An engine of the sample in the given lifecycle state (seed 42). Shared by the engine test files.
func makeSampleEngine(in state: ExperienceLifecycleState, seed: UInt64 = 42) async throws -> SampleEngine {
    var engine = SampleEngine(id: SampleExperience.id)
    switch state {
    case .registered:
        break
    case .preparing:
        _ = try engine.beginPreparation(seed: seed)
    case .ready:
        try await engine.prepare(seed: seed)
    case .active:
        try await engine.prepare(seed: seed)
        try engine.activate()
    case .suspended:
        try await engine.prepare(seed: seed)
        try engine.activate()
        try engine.suspend()
    case .deactivating:
        try await engine.prepare(seed: seed)
        try engine.activate()
        try engine.beginDeactivation()
    case .inactive:
        try await engine.prepare(seed: seed)
        try engine.activate()
        try engine.beginDeactivation()
        try engine.finishDeactivation()
    case .failed:
        try await engine.prepare(seed: seed)
        engine.fail(ExperienceFailure(code: "test.failed", message: "failed on purpose"))
    }
    #expect(engine.lifecycle.state == state)
    return engine
}

private protocol StepLength: Sendable { static var seconds: Double { get } }
private enum TooLong: StepLength { static let seconds = 1.0 }
private enum TooShort: StepLength { static let seconds = 0.001 }
private enum NotFinite: StepLength { static let seconds = Double.nan }

/// A minimal core whose only purpose is to declare a step length.
private struct StepCore<Length: StepLength>: ExperienceCore, Codable {
    var ticks = 0
    static var migrations: MigrationChain { MigrationChain(currentVersion: 1) }
    static var controls: [ExperienceControl] { [] }
    static var stepDuration: Double { Length.seconds }
    static func prepare(seed: UInt64) async throws -> Self { Self() }
    mutating func update(step: Int) { ticks += 1 }
    mutating func apply(_ action: ExperienceAction) -> ActionResult { .accepted }
    mutating func reset() { ticks = 0 }
    func writeDigest(into builder: inout DigestBuilder) throws(DigestError) { builder.add(ticks) }
}

@Suite struct ExperienceEngineTests {
    // MARK: Preparation

    @Test func aNewEngineHasNoState() {
        let engine = SampleEngine(id: SampleExperience.id)
        #expect(engine.lifecycle.state == .registered)
        #expect(engine.core == nil)
        #expect(engine.seed == nil)
        #expect(engine.stepIndex == 0)
        #expect(throws: ExperienceError.notPrepared) { try engine.digest() }
    }

    @Test func preparationLeadsToReady() async throws {
        var engine = SampleEngine(id: SampleExperience.id)
        try await engine.prepare(seed: 7)
        #expect(engine.lifecycle.state == .ready)
        #expect(engine.seed == 7)
        #expect(engine.stepIndex == 0)
        #expect(engine.core != nil)
        _ = try engine.digest()
    }

    @Test func preparingTwiceIsRefused() throws {
        var engine = SampleEngine(id: SampleExperience.id)
        _ = try engine.beginPreparation(seed: 1)
        #expect(throws: ExperienceError.illegalOperation(.prepare, in: .preparing)) {
            _ = try engine.beginPreparation(seed: 2)
        }
        #expect(engine.lifecycle.rejectedOperations == 1)
        #expect(engine.seed == 1)
    }

    @Test func aStaleTicketIsDiscarded() async throws {
        var engine = SampleEngine(id: SampleExperience.id)
        let first = try engine.beginPreparation(seed: 1)
        try engine.beginDeactivation()
        #expect(engine.lifecycle.state == .inactive)
        let second = try engine.beginPreparation(seed: 2)
        #expect(first != second)

        let late = await SampleEngine.prepare(seed: 1)
        let completed1 = engine.completePreparation(first, with: late)
        #expect(completed1 == false)
        #expect(engine.discardedPreparations == 1)
        #expect(engine.lifecycle.state == .preparing)
        #expect(engine.core == nil)

        let current = await SampleEngine.prepare(seed: 2)
        let completed2 = engine.completePreparation(second, with: current)
        #expect(completed2)
        #expect(engine.lifecycle.state == .ready)
        #expect(engine.seed == 2)
        let completed3 = engine.completePreparation(second, with: current)
        #expect(completed3 == false)
        #expect(engine.discardedPreparations == 2)
    }

    @Test func aCancelledResultEndsInInactive() throws {
        var engine = SampleEngine(id: SampleExperience.id)
        let ticket = try engine.beginPreparation(seed: 1)
        let completed4 = engine.completePreparation(ticket, with: .failure(.cancelled))
        #expect(completed4)
        #expect(engine.lifecycle.state == .inactive)
        #expect(engine.lifecycle.lastError == nil)
    }

    @Test func aFailingPreparationEndsInFailedAndCanBeRepeated() async throws {
        var engine = ExperienceEngine<SampleExperienceCore<FailingPreparation>>(id: SampleExperience.id)
        await #expect(throws: ExperienceError.self) { try await engine.prepare(seed: 3) }
        #expect(engine.lifecycle.state == .failed)
        #expect(engine.lifecycle.lastError?.code == "sample.broken")
        #expect(engine.core == nil)
        // Preparing again is legal: the error is the sample's own failure again, not an illegal operation.
        do {
            try await engine.prepare(seed: 3)
            Issue.record("the failing sample prepared")
        } catch {
            #expect(error.code == "sample.broken")
        }

        var healthy = try await makeSampleEngine(in: .failed)
        #expect(healthy.lifecycle.lastError?.code == "test.failed")
        try await healthy.prepare(seed: 9)
        #expect(healthy.lifecycle.state == .ready)
        #expect(healthy.lifecycle.lastError == nil)
    }

    @Test func aPreparationOverItsLimitTimesOut() async throws {
        var engine = ExperienceEngine<SampleExperienceCore<SlowPreparation>>(id: SampleExperience.id)
        let clock = ContinuousClock()
        let started = clock.now
        do {
            try await engine.prepare(seed: 1, timeLimit: .milliseconds(100))
            Issue.record("the slow sample prepared within 100 ms")
        } catch {
            #expect(error == .preparationTimedOut)
        }
        #expect(clock.now - started < .seconds(5))
        #expect(engine.lifecycle.state == .failed)
        #expect(engine.lifecycle.lastError?.code == "experience.preparation-timeout")
    }

    @Test func aCancelledPreparationEndsWithinOneSecond() async throws {
        let clock = ContinuousClock()
        let task = Task { await ExperienceEngine<SampleExperienceCore<SlowPreparation>>.prepare(seed: 1) }
        try await Task.sleep(for: .milliseconds(50))
        let cancelledAt = clock.now
        task.cancel()
        let result = await task.value
        #expect(clock.now - cancelledAt < .seconds(1))
        switch result {
        case .success: Issue.record("the cancelled preparation succeeded")
        case .failure(let error): #expect(error == .cancelled)
        }
    }

    // MARK: Lifecycle calls

    @Test func theLifecycleCallsWalkTheStates() async throws {
        var engine = try await makeSampleEngine(in: .ready)
        try engine.activate()
        try engine.suspend()
        try engine.resume()
        try engine.beginDeactivation()
        #expect(engine.core != nil)
        try engine.finishDeactivation()
        #expect(engine.lifecycle.state == .inactive)
        #expect(engine.core == nil)
        #expect(engine.lifecycle.rejectedTransitions == 0)
        #expect(engine.lifecycle.rejectedOperations == 0)
        try await engine.prepare(seed: 5)
        #expect(engine.lifecycle.state == .ready)
    }

    @Test func finishingADeactivationThatDidNotBeginIsRefused() async throws {
        var engine = try await makeSampleEngine(in: .active)
        #expect(throws: ExperienceError.illegalOperation(.deactivate, in: .active)) { try engine.finishDeactivation() }
        #expect(engine.lifecycle.state == .active)
        #expect(engine.core != nil)
    }

    @Test func callsOfThisPhaseAreRefusedOutsideTheirStates() async throws {
        typealias Call = (name: String, operation: ExperienceOperation, legal: Set<ExperienceLifecycleState>,
                          run: (inout SampleEngine) throws(ExperienceError) -> Void)
        let calls: [Call] = [
            ("beginPreparation", .prepare, [.registered, .inactive, .failed], { e throws(ExperienceError) in _ = try e.beginPreparation(seed: 1) }),
            ("activate", .activate, [.ready], { e throws(ExperienceError) in try e.activate() }),
            ("advance", .update, [.active], { e throws(ExperienceError) in _ = try e.advance(frame: 0.05) }),
            ("run", .update, [.active], { e throws(ExperienceError) in try e.run(steps: 3) }),
            ("suspend", .suspend, [.active], { e throws(ExperienceError) in try e.suspend() }),
            ("resume", .resume, [.suspended], { e throws(ExperienceError) in try e.resume() }),
            ("beginDeactivation", .deactivate, [.preparing, .ready, .active, .suspended, .failed],
             { e throws(ExperienceError) in try e.beginDeactivation() }),
        ]
        for state in ExperienceLifecycleState.allCases {
            for call in calls {
                var engine = try await makeSampleEngine(in: state)
                let before = engine
                if call.legal.contains(state) {
                    do { try call.run(&engine) } catch { Issue.record("\(call.name) refused in \(state): \(error)") }
                    continue
                }
                do {
                    try call.run(&engine)
                    Issue.record("\(call.name) was accepted in \(state)")
                } catch {
                    #expect(error == .illegalOperation(call.operation, in: state), "\(call.name) in \(state)")
                }
                #expect(engine.lifecycle.state == state)
                #expect(engine.lifecycle.rejectedOperations == before.lifecycle.rejectedOperations + 1)
                #expect(engine.core?.updateCalls == before.core?.updateCalls)
                #expect(engine.stepIndex == before.stepIndex)
                #expect((try? engine.digest()) == (try? before.digest()))
            }
        }
    }

    // MARK: Determinism

    @Test func theSameSeedGivesTheSameDigest() async throws {
        var digests = Set<StateDigest>()
        for index in 0..<256 {
            let seed = UInt64(index) &* 0x9E37_79B9_7F4A_7C15 &+ 11
            var first = SampleEngine(id: SampleExperience.id)
            var second = SampleEngine(id: SampleExperience.id)
            try await first.prepare(seed: seed)
            try await second.prepare(seed: seed)
            let digest = try first.digest()
            #expect(digest == (try second.digest()), "seed \(seed)")
            digests.insert(digest)
        }
        #expect(digests.count >= 250)
    }

    // MARK: Fixed steps

    @Test func stepsDoNotDependOnTheFramePattern() async throws {
        let irregular = Array(repeating: [0.005, 0.02, 0.0125, 0.0125], count: 40).flatMap { $0 }
        let patterns: [(name: String, frames: [Double])] = [
            ("60 frames", Array(repeating: 1.0 / 30, count: 60)),
            ("120 frames", Array(repeating: 1.0 / 60, count: 120)),
            ("240 frames", Array(repeating: 1.0 / 120, count: 240)),
            ("irregular", irregular),
        ]
        var results: [StateDigest] = []
        for pattern in patterns {
            var engine = try await makeSampleEngine(in: .active)
            var steps = 0
            for frame in pattern.frames { steps += try engine.advance(frame: frame) }
            #expect(steps == 240, "\(pattern.name)")
            #expect(engine.stepIndex == 240, "\(pattern.name)")
            #expect(engine.clock.droppedTime == 0, "\(pattern.name)")
            results.append(try engine.digest())
        }
        #expect(Set(results).count == 1)
        let fresh = try await makeSampleEngine(in: .active)
        #expect(results.first != (try fresh.digest()))
    }

    @Test func aLongFrameIsCappedAndItsTimeIsDropped() async throws {
        var engine = try await makeSampleEngine(in: .active)
        let capped = try engine.advance(frame: 1.0)
        #expect(capped == 8)
        #expect(engine.stepIndex == 8)
        #expect(engine.clock.droppedTime > 0.9)
        let next = try engine.advance(frame: 1.0 / 120)
        #expect(next == 1)
        #expect(engine.stepIndex == 9)
    }

    @Test func invalidFrameTimesRunNoStep() async throws {
        var engine = try await makeSampleEngine(in: .active)
        for delta in [-1.0, Double.nan, Double.infinity] {
            let steps = try engine.advance(frame: delta)
            #expect(steps == 0)
        }
        #expect(engine.stepIndex == 0)
        #expect(engine.clock.invalidDeltas == 3)
    }

    @Test func resumingDoesNotCatchUp() async throws {
        var engine = try await makeSampleEngine(in: .active)
        let before = try engine.advance(frame: 0.00833)
        #expect(before == 0)
        try engine.suspend()
        #expect(throws: ExperienceError.illegalOperation(.update, in: .suspended)) { _ = try engine.advance(frame: 10) }
        try engine.resume()
        // Without the reset the 0.00833 s from before the suspension would complete a step now.
        let after = try engine.advance(frame: 0.0001)
        #expect(after == 0)
        #expect(engine.stepIndex == 0)
    }

    @Test func runStepsRunsExactlyThatMany() async throws {
        var engine = try await makeSampleEngine(in: .active)
        try engine.run(steps: 7)
        #expect(engine.stepIndex == 7)
        #expect(engine.core?.updateCalls == 7)
        try engine.run(steps: -3)
        #expect(engine.stepIndex == 7)
    }

    @Test func aStepLengthOutsideTheRangeIsClamped() {
        #expect(ExperienceEngine<StepCore<TooLong>>.stepDuration == 1.0 / 30)
        #expect(ExperienceEngine<StepCore<TooShort>>.stepDuration == 1.0 / 240)
        #expect(ExperienceEngine<StepCore<NotFinite>>.stepDuration == 1.0 / 120)
        #expect(SampleEngine.stepDuration == 1.0 / 120)
        #expect(SampleEngine.schemaVersion == 2)
        #expect(ExperienceEngine<StepCore<TooLong>>(id: SampleExperience.id).clock.step == 1.0 / 30)
    }
}
