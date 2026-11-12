// ExperienceEngineQualityTests — feature 188 T-U02-033 (US5, US1 scenario 5; FR-U02-006, FR-U02-052, FR-U02-054,
// FR-U02-055): quality tier, cache shedding, the leak rule of deactivation, and every operation in every state.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreTestSupport

@Suite struct ExperienceEngineQualityTests {
    @Test func everyDeclaredTierIsAcceptedAndKeepsTheDigest() async throws {
        for state in [ExperienceLifecycleState.ready, .active, .suspended] {
            var engine = try await makeSampleEngine(in: state)
            let digest = try engine.digest()
            for tier in [1, 2, 0, 2] {
                try engine.setQualityTier(tier)
                #expect(engine.qualityTier == tier)
                #expect(engine.core?.tier == tier)
                #expect(try engine.digest() == digest)
            }
        }
    }

    @Test func aTierThatWasNotDeclaredIsRefused() async throws {
        var engine = try await makeSampleEngine(in: .active)
        try engine.setQualityTier(1)
        for tier in [3, -1, .max] {
            do {
                try engine.setQualityTier(tier)
                Issue.record("tier \(tier) was accepted")
            } catch {
                #expect(error == .invalidTier(tier, tiers: 3))
                #expect(error.code == "experience.invalid-tier")
            }
        }
        #expect(engine.qualityTier == 1)
        #expect(engine.core?.tier == 1)
    }

    @Test func theTierIsAppliedAgainAfterRestoreAndPreparation() async throws {
        var engine = try await makeSampleEngine(in: .active)
        let snapshot = try engine.snapshot()
        try engine.setQualityTier(2)
        try engine.restore(snapshot)
        #expect(engine.core?.tier == 2)
        try engine.beginDeactivation()
        try engine.finishDeactivation()
        try await engine.prepare(seed: 9)
        #expect(engine.qualityTier == 2)
        #expect(engine.core?.tier == 2)
    }

    @Test func sheddingKeepsTheDigestAndTheCacheIsRebuilt() async throws {
        var engine = try await makeSampleEngine(in: .active)
        try engine.run(steps: 3)
        #expect(engine.core?.cache.isEmpty == false)
        let digest = try engine.digest()
        try engine.shedCaches()
        #expect(engine.core?.cache.isEmpty == true)
        #expect(try engine.digest() == digest)
        try engine.run(steps: 1)
        #expect(engine.core?.cache.isEmpty == false)
    }

    @Test func deactivationEndsInInactiveOrReportsALeak() async throws {
        var clean = try await makeSampleEngine(in: .deactivating)
        try clean.finishDeactivation(gpu: GPUResourceCounts(objects: 0, bytes: 0, leaked: 0))
        #expect(clean.lifecycle.state == .inactive)
        #expect(clean.core == nil)

        for counts in [GPUResourceCounts(objects: 1, bytes: 4, leaked: 0), GPUResourceCounts(objects: 0, bytes: 0, leaked: 2)] {
            var leaking = try await makeSampleEngine(in: .deactivating)
            do {
                try leaking.finishDeactivation(gpu: counts)
                Issue.record("a leak was accepted")
            } catch {
                #expect(error == .gpuLeak(live: counts.objects, leaked: counts.leaked))
            }
            #expect(leaking.lifecycle.state == .failed)
            #expect(leaking.lifecycle.lastError?.code == "experience.gpu-leak")
            // Leaving is still possible once the objects are gone.
            try leaking.beginDeactivation()
            try leaking.finishDeactivation(gpu: GPUResourceCounts(objects: 0, bytes: 0, leaked: 0))
            #expect(leaking.lifecycle.state == .inactive)
        }
    }

    @Test func everyOperationIsLegalInExactlyItsStates() async throws {
        let source = try await makeSampleEngine(in: .ready)
        var copy = source
        let snapshot = try copy.snapshot()
        typealias Call = (operation: ExperienceOperation, run: (inout SampleEngine) throws(ExperienceError) -> Void)
        let calls: [Call] = [
            (.prepare, { e throws(ExperienceError) in _ = try e.beginPreparation(seed: 1) }),
            (.activate, { e throws(ExperienceError) in try e.activate() }),
            (.update, { e throws(ExperienceError) in try e.run(steps: 2) }),
            (.action, { e throws(ExperienceError) in
                if case .rejected(.notActive(let state)) = e.handle(control: "ping") { throw .illegalOperation(.action, in: state) }
            }),
            (.snapshot, { e throws(ExperienceError) in _ = try e.snapshot() }),
            (.restore, { e throws(ExperienceError) in try e.restore(snapshot) }),
            (.reset, { e throws(ExperienceError) in try e.reset() }),
            (.setQualityTier, { e throws(ExperienceError) in try e.setQualityTier(1) }),
            (.shedCaches, { e throws(ExperienceError) in try e.shedCaches() }),
            (.suspend, { e throws(ExperienceError) in try e.suspend() }),
            (.resume, { e throws(ExperienceError) in try e.resume() }),
            (.deactivate, { e throws(ExperienceError) in try e.beginDeactivation() }),
        ]
        #expect(calls.count == ExperienceOperation.allCases.count)
        var legal = 0, refused = 0
        for state in ExperienceLifecycleState.allCases {
            for call in calls {
                var engine = try await makeSampleEngine(in: state)
                let before = engine
                let expected = ExperienceLifecycle.isLegal(call.operation, in: state)
                do {
                    try call.run(&engine)
                    #expect(expected, "\(call.operation) was accepted in \(state)")
                    legal += 1
                } catch {
                    #expect(!expected, "\(call.operation) was refused in \(state): \(error)")
                    #expect(error == .illegalOperation(call.operation, in: state))
                    #expect(engine.lifecycle.state == state)
                    #expect(engine.lifecycle.rejectedOperations == before.lifecycle.rejectedOperations + 1)
                    #expect(engine.core?.updateCalls == before.core?.updateCalls)
                    #expect(engine.core?.applyCalls == before.core?.applyCalls)
                    #expect((try? engine.digest()) == (try? before.digest()))
                    refused += 1
                }
            }
        }
        #expect(legal == 28)
        #expect(refused == 68)
    }
}
