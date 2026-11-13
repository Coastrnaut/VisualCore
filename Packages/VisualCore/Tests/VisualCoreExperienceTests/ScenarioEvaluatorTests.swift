// ScenarioEvaluatorTests — feature 195 T-U09-006 (FR-U09-003, FR-U09-010, FR-U09-052; data-model section 3): every
// expectation kind passes when the observation matches and fails with a named message when it does not.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import Testing
import VisualCoreExperience

@Suite struct ScenarioEvaluatorTests {
    private static let digestA = String(repeating: "a", count: 64)
    private static let digestB = String(repeating: "b", count: 64)
    private static let digestC = String(repeating: "c", count: 64)

    /// Three actions; the third is expected to be rejected as out of range, the second carries a digest.
    private static let spec = ScenarioSpec(name: "rejection", seed: 42, entries: [
        ScenarioStep(steps: 5, action: ScriptedAction("move", [0.5, 0.5]), result: "accepted"),
        ScenarioStep(steps: 3),
        ScenarioStep(steps: 2, action: ScriptedAction("tap"), result: "accepted", digest: digestB),
        ScenarioStep(steps: 1, action: ScriptedAction("move", [2, 0]), result: "action.out-of-range"),
    ])

    private static let matchingSteps = [
        StepObservation(control: "move", values: [0.5, 0.5], result: "accepted", digest: digestA),
        StepObservation(control: "tap", result: "accepted", digest: digestB),
        StepObservation(control: "move", values: [2, 0], result: "action.out-of-range", digest: digestB),
    ]

    private func observation(scenario: String = "rejection", seed: UInt64 = 42,
                             steps: [StepObservation] = ScenarioEvaluatorTests.matchingSteps,
                             digests: ObservedDigests = ObservedDigests(), outcome: String? = nil,
                             frame: FrameObservation? = nil, sent: Int = 3, handled: Int = 3,
                             failures: [String] = []) -> ScenarioObservation {
        ScenarioObservation(scenario: scenario, seed: seed, steps: steps, digests: digests, outcome: outcome, frame: frame,
                            actionsSent: sent, actionsHandled: handled, failures: failures)
    }

    private func expecting(_ expect: ScenarioExpectations) -> ScenarioSpec {
        ScenarioSpec(name: "completion", seed: 1, entries: [ScenarioStep(steps: 1, action: ScriptedAction("tap"))],
                     expect: expect)
    }

    private func plain(digests: ObservedDigests = ObservedDigests(), outcome: String? = nil,
                       frame: FrameObservation? = nil) -> ScenarioObservation {
        ScenarioObservation(scenario: "completion", seed: 1,
                            steps: [StepObservation(control: "tap", result: "accepted")],
                            digests: digests, outcome: outcome, frame: frame, actionsSent: 1, actionsHandled: 1)
    }

    private func frame(_ probes: [String: String]) -> FrameObservation {
        FrameObservation(width: 4, height: 4, sha256: Self.digestC, nonBlank: true, probes: probes)
    }

    // MARK: Steps

    @Test func matchingStepsPass() {
        let failures = ScenarioEvaluator.failures(Self.spec, observation())
        #expect(failures.isEmpty)
    }

    @Test func aStepResultMismatchIsNamed() {
        var steps = Self.matchingSteps
        steps[2] = StepObservation(control: "move", values: [2, 0], result: "accepted", digest: Self.digestB)
        let failures = ScenarioEvaluator.failures(Self.spec, observation(steps: steps))
        #expect(failures == ["step 3: expected rejected action.out-of-range, got accepted"])
    }

    @Test func anUnexpectedRejectionIsNamed() {
        var steps = Self.matchingSteps
        steps[0] = StepObservation(control: "move", values: [0.5, 0.5], result: "action.rule.blocked")
        let failures = ScenarioEvaluator.failures(Self.spec, observation(steps: steps))
        #expect(failures == ["step 1: expected accepted, got rejected action.rule.blocked"])
    }

    @Test func aStepDigestMismatchIsNamed() {
        var steps = Self.matchingSteps
        steps[1] = StepObservation(control: "tap", result: "accepted", digest: Self.digestC)
        let failures = ScenarioEvaluator.failures(Self.spec, observation(steps: steps))
        #expect(failures == ["step 2 digest: expected \(Self.digestB), got \(Self.digestC)"])
    }

    @Test func aMissingStepObservationIsAFailure() {
        let steps = Array(Self.matchingSteps.prefix(2))
        let failures = ScenarioEvaluator.failures(Self.spec, observation(steps: steps))
        #expect(failures == ["step 3: expected rejected action.out-of-range, got no observation"])
    }

    @Test func aStepWithAnotherControlIsNamed() {
        var steps = Self.matchingSteps
        steps[1] = StepObservation(control: "move", result: "accepted", digest: Self.digestB)
        let failures = ScenarioEvaluator.failures(Self.spec, observation(steps: steps))
        #expect(failures == ["step 2: expected control tap, got move"])
    }

    @Test func anotherScenarioOrSeedIsNamed() {
        let failures = ScenarioEvaluator.failures(Self.spec, observation(scenario: "reset", seed: 43))
        #expect(failures == ["scenario: expected rejection, got reset", "seed: expected 42, got 43"])
    }

    // MARK: Digests

    @Test func theInitialDigestPassesAndFails() {
        let spec = expecting(ScenarioExpectations(initialDigest: Self.digestA))
        let passing = ScenarioEvaluator.failures(spec, plain(digests: ObservedDigests(initial: Self.digestA)))
        #expect(passing.isEmpty)
        let failing = ScenarioEvaluator.failures(spec, plain(digests: ObservedDigests(initial: Self.digestB)))
        #expect(failing == ["initial digest: expected \(Self.digestA), got \(Self.digestB)"])
        let missing = ScenarioEvaluator.failures(spec, plain())
        #expect(missing == ["initial digest: expected \(Self.digestA), got none"])
    }

    @Test func theFinalDigestPassesAndFails() {
        let spec = expecting(ScenarioExpectations(finalDigest: Self.digestA))
        let passing = ScenarioEvaluator.failures(spec, plain(digests: ObservedDigests(final: Self.digestA)))
        #expect(passing.isEmpty)
        let failing = ScenarioEvaluator.failures(spec, plain(digests: ObservedDigests(final: Self.digestC)))
        #expect(failing == ["final digest: expected \(Self.digestA), got \(Self.digestC)"])
        let missing = ScenarioEvaluator.failures(spec, plain())
        #expect(missing == ["final digest: expected \(Self.digestA), got none"])
    }

    @Test func theAfterRestoreDigestPassesAndFails() {
        let spec = expecting(ScenarioExpectations(finalDigest: Self.digestA))
        let passing = ScenarioEvaluator.failures(spec, plain(digests: ObservedDigests(final: Self.digestA,
                                                                                      afterRestore: Self.digestA)))
        #expect(passing.isEmpty)
        let failing = ScenarioEvaluator.failures(spec, plain(digests: ObservedDigests(final: Self.digestA,
                                                                                      afterRestore: Self.digestB)))
        #expect(failing == ["after-restore digest: expected \(Self.digestA), got \(Self.digestB)"])
    }

    @Test func theAfterResetDigestPassesAndFails() {
        let spec = expecting(ScenarioExpectations(resetDigest: true))
        let passing = ScenarioEvaluator.failures(spec, plain(digests: ObservedDigests(initial: Self.digestA,
                                                                                      afterReset: Self.digestA)))
        #expect(passing.isEmpty)
        let failing = ScenarioEvaluator.failures(spec, plain(digests: ObservedDigests(initial: Self.digestA,
                                                                                      afterReset: Self.digestB)))
        #expect(failing == ["after-reset digest: expected \(Self.digestA), got \(Self.digestB)"])
        let missing = ScenarioEvaluator.failures(spec, plain(digests: ObservedDigests(initial: Self.digestA)))
        #expect(missing == ["after-reset digest: expected \(Self.digestA), got none"])
        let noInitial = ScenarioEvaluator.failures(spec, plain(digests: ObservedDigests(afterReset: Self.digestA)))
        #expect(noInitial == ["after-reset digest: no initial digest observed"])
    }

    // MARK: Outcome and probes

    @Test func theOutcomePassesAndFails() {
        let spec = expecting(ScenarioExpectations(outcome: "target-reached"))
        let passing = ScenarioEvaluator.failures(spec, plain(outcome: "target-reached"))
        #expect(passing.isEmpty)
        let missing = ScenarioEvaluator.failures(spec, plain())
        #expect(missing == ["outcome: expected target-reached, got none"])
        let other = ScenarioEvaluator.failures(spec, plain(outcome: "lost"))
        #expect(other == ["outcome: expected target-reached, got lost"])
    }

    @Test func aProbePassesAndFails() {
        let spec = expecting(ScenarioExpectations(probes: ["marker": "red", "sky": "dark"]))
        let passing = ScenarioEvaluator.failures(spec, plain(frame: frame(["marker": "red", "sky": "dark"])))
        #expect(passing.isEmpty)
        let failing = ScenarioEvaluator.failures(spec, plain(frame: frame(["marker": "blue", "sky": "dark"])))
        #expect(failing == ["probe marker: expected red, got blue"])
        let noFrame = ScenarioEvaluator.failures(spec, plain())
        #expect(noFrame == ["probe marker: expected red, got none", "probe sky: expected dark, got none"])
    }

    // MARK: Bypass and own failures

    @Test func differentSentAndHandledCountsFailAsBypass() {
        let failures = ScenarioEvaluator.failures(Self.spec, observation(sent: 4, handled: 3))
        #expect(failures == ["bypass: 4 actions sent, 3 handled"])
    }

    @Test func anObservationWithFailuresCannotPass() {
        let own = ["preparation: no frame within 120 attempts", "resources: 2 GPU objects leaked"]
        let failures = ScenarioEvaluator.failures(Self.spec, observation(failures: own))
        #expect(failures == own)
    }

    @Test func ownFailuresComeAfterTheComparisons() {
        let failures = ScenarioEvaluator.failures(Self.spec, observation(sent: 2, handled: 3, failures: ["crash"]))
        #expect(failures == ["bypass: 2 actions sent, 3 handled", "crash"])
    }

    // MARK: Encoding

    @Test func anObservationRoundTripsWithItsSeedAsText() throws {
        let original = ScenarioObservation(
            scenario: "rejection", seed: UInt64.max, steps: Self.matchingSteps,
            digests: ObservedDigests(initial: Self.digestA, final: Self.digestB), outcome: "target-reached",
            frame: frame(["marker": "red"]),
            timing: ScenarioTiming(preparation: 0.25, setup: 0.5, firstPresent: 0.75, programsCompiled: 3),
            resources: ScenarioResources(footprint: 1_000, gpuBytes: 2_000, live: 1, leaked: 0),
            actionsSent: 3, actionsHandled: 3, failures: ["none"])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"seed\":\"18446744073709551615\""))
        let decoded = try JSONDecoder().decode(ScenarioObservation.self, from: data)
        #expect(decoded == original)
    }
}
#endif
