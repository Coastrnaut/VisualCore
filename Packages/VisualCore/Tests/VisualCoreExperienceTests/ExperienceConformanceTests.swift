// ExperienceConformanceTests — feature 188 T-U02-040 (US7; FR-U02-070 to FR-U02-073; SC-U02-008): the conformance
// helper passes the sample that keeps the contract, finds each deliberate fault of the sample with exactly the check
// that is meant to find it, reports as data and keeps its limits.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreTestSupport

@Suite struct ExperienceConformanceTests {
    /// The report of the sample with the fault `fault`, run with the sample's plan.
    private func conformance<Fault: SampleFault>(of fault: Fault.Type) async -> ConformanceReport {
        await ExperienceConformance.run(SampleExperienceCore<Fault>.self, id: SampleExperience.id,
                                        plan: SampleExperience.plan)
    }

    /// Expects that `report` fails `check` and nothing else, and that the failure names the first seed.
    private func expectOnly(_ check: ConformanceCheck, in report: ConformanceReport) {
        #expect(report.failed == [check])
        #expect(!report.passed)
        let entry = report.entries.first { $0.check == check }
        #expect(entry?.passed == false)
        #expect(entry?.detail.hasPrefix("seed 0: ") == true, "detail: \(entry?.detail ?? "none")")
    }

    // MARK: The sample that keeps the contract

    @Test func sampleWithoutFaultPassesAllSevenChecks() async {
        let report = await conformance(of: NoFault.self)
        #expect(report.passed)
        #expect(report.failed.isEmpty)
        #expect(report.entries.count == 7)
        for entry in report.entries {
            #expect(entry.passed, "\(entry.check.rawValue): \(entry.detail)")
            #expect(entry.detail == "4 seeds")
        }
    }

    // MARK: Each fault fails exactly its own check

    @Test func unseededPreparationFailsSeedDeterminism() async {
        expectOnly(.seedDeterminism, in: await conformance(of: UnseededPreparation.self))
    }

    @Test func lossySnapshotFailsSnapshotRoundTrip() async {
        let report = await conformance(of: LossySnapshot.self)
        expectOnly(.snapshotRoundTrip, in: report)
        let detail = report.entries.first { $0.check == .snapshotRoundTrip }?.detail ?? ""
        #expect(detail.contains("snapshot.state-mismatch"), "detail: \(detail)")
    }

    @Test func wrongResetFailsResetEquivalence() async {
        expectOnly(.resetEquivalence, in: await conformance(of: WrongReset.self))
    }

    @Test func mutatingRejectionFailsRejectionKeepsDigest() async {
        let report = await conformance(of: MutatingRejection.self)
        expectOnly(.rejectionKeepsDigest, in: report)
        let detail = report.entries.first { $0.check == .rejectionKeepsDigest }?.detail ?? ""
        #expect(detail.contains("action.rule.sample.no-move"), "detail: \(detail)")
    }

    @Test func tierChangesStateFailsTierKeepsDigest() async {
        let report = await conformance(of: TierChangesState.self)
        expectOnly(.tierKeepsDigest, in: report)
        let detail = report.entries.first { $0.check == .tierKeepsDigest }?.detail ?? ""
        #expect(detail.contains("quality tier 1"), "detail: \(detail)")
    }

    @Test func sheddingChangesStateFailsSheddingKeepsDigest() async {
        expectOnly(.sheddingKeepsDigest, in: await conformance(of: SheddingChangesState.self))
    }

    @Test func clockInUpdateFailsReplayReproducesDigest() async {
        expectOnly(.replayReproducesDigest, in: await conformance(of: ClockInUpdate.self))
    }

    @Test func failingPreparationFailsSeedDeterminismWithTheFailureCode() async {
        let report = await conformance(of: FailingPreparation.self)
        #expect(report.failed == [.seedDeterminism])
        let entry = report.entries.first { $0.check == .seedDeterminism }
        #expect(entry?.detail.contains("sample.broken") == true, "detail: \(entry?.detail ?? "none")")
        #expect(entry?.detail.hasPrefix("seed 0: ") == true)
        // The other checks did not run for any seed; they are not failed because of the preparation.
        for other in report.entries where other.check != .seedDeterminism {
            #expect(other.passed)
            #expect(other.detail.hasPrefix("0 of 4 seeds"), "detail: \(other.detail)")
        }
    }

    // MARK: The report

    @Test func reportHasOneEntryPerCheckInTheOrderOfAllCases() async {
        let expected: [ConformanceCheck] = [.seedDeterminism, .snapshotRoundTrip, .resetEquivalence,
                                            .rejectionKeepsDigest, .tierKeepsDigest, .sheddingKeepsDigest,
                                            .replayReproducesDigest]
        #expect(ConformanceCheck.allCases == expected)
        let passing = await conformance(of: NoFault.self)
        #expect(passing.entries.map(\.check) == expected)
        let failing = await conformance(of: WrongReset.self)
        #expect(failing.entries.map(\.check) == expected)
    }

    @Test func reportSurvivesAJSONRoundTrip() async throws {
        let reports = [await conformance(of: NoFault.self), await conformance(of: TierChangesState.self)]
        for report in reports {
            let data = try JSONEncoder().encode(report)
            let decoded = try JSONDecoder().decode(ConformanceReport.self, from: data)
            #expect(decoded == report)
            #expect(decoded.failed == report.failed)
            #expect(decoded.passed == report.passed)
        }
        let passing = await conformance(of: NoFault.self)
        let text = String(decoding: try JSONEncoder().encode(passing), as: UTF8.self)
        #expect(text.contains("\"seedDeterminism\""))
        #expect(text.contains("\"replayReproducesDigest\""))
    }

    // MARK: Limits

    @Test func oversizedPlanIsCut() {
        let actions = (0..<2_000).map { _ in ScriptedAction("ping") }
        let plan = ConformancePlan(seeds: (0..<100).map { UInt64($0) }, stepsPerSegment: 20_000, actions: actions,
                                   rejected: [])
        #expect(plan.effectiveSeeds == (0..<64).map { UInt64($0) })
        #expect(plan.effectiveStepsPerSegment == 10_000)
        #expect(plan.effectiveActions.count == 1_000)
        // The stored values stay as given.
        #expect(plan.seeds.count == 100)
        #expect(plan.stepsPerSegment == 20_000)
        #expect(plan.actions.count == 2_000)
        #expect(ConformancePlan.maxSeeds == 64)
        #expect(ConformancePlan.maxStepsPerSegment == 10_000)
        #expect(ConformancePlan.maxActions == 1_000)
    }

    @Test func negativeStepsPerSegmentMeansZero() {
        let plan = ConformancePlan(seeds: [7], stepsPerSegment: -5, actions: [], rejected: [])
        #expect(plan.effectiveStepsPerSegment == 0)
        #expect(plan.effectiveSeeds == [7])
        #expect(plan.effectiveActions.isEmpty)
    }

    @Test func runUsesOnlyTheFirst64Seeds() async {
        let plan = ConformancePlan(seeds: (0..<100).map { UInt64($0) }, stepsPerSegment: 1,
                                   actions: [ScriptedAction("ping")], rejected: [])
        let report = await ExperienceConformance.run(Sample.self, id: SampleExperience.id, plan: plan)
        #expect(report.passed)
        for entry in report.entries { #expect(entry.detail == "64 seeds") }
    }

    @Test func emptySeedListMeansSeedZero() async {
        let plan = ConformancePlan(seeds: [], stepsPerSegment: SampleExperience.stepsPerSegment,
                                   actions: SampleExperience.acceptedActions,
                                   rejected: SampleExperience.rejectedActions)
        #expect(plan.effectiveSeeds == [0])
        let passing = await ExperienceConformance.run(Sample.self, id: SampleExperience.id, plan: plan)
        #expect(passing.passed)
        for entry in passing.entries { #expect(entry.detail == "1 seed") }
        let failing = await ExperienceConformance.run(SampleExperienceCore<WrongReset>.self, id: SampleExperience.id,
                                                      plan: plan)
        #expect(failing.failed == [.resetEquivalence])
        let detail = failing.entries.first { $0.check == .resetEquivalence }?.detail ?? ""
        #expect(detail.hasPrefix("seed 0: "), "detail: \(detail)")
    }

    @Test func samplePlanIsBuiltFromItsIngredients() {
        let plan = SampleExperience.plan
        #expect(plan.seeds == SampleExperience.seeds)
        #expect(plan.stepsPerSegment == SampleExperience.stepsPerSegment)
        #expect(plan.actions == SampleExperience.acceptedActions)
        #expect(plan.rejected == SampleExperience.rejectedActions)
    }

    // MARK: Time (SC-U02-008)

    @Test func wholeRunForTheSampleTakesLessThanTenSeconds() async {
        let clock = ContinuousClock()
        let start = clock.now
        let report = await conformance(of: NoFault.self)
        let elapsed = clock.now - start
        #expect(report.passed)
        #expect(elapsed < .seconds(10), "the run took \(elapsed)")
    }
}
