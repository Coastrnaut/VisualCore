// ExperienceScenarioTests — feature 188 T-U02-029 (US6; FR-U02-062; SC-U02-007, script part): the scenario hooks
// that exist only in builds made for testing.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreTestSupport

@Suite struct ExperienceScenarioTests {
    /// 100 steps and 10 actions on seed 42.
    private static let scenario = ExperienceScenario(seed: 42, entries: (0..<10).map { index in
        let actions = [ScriptedAction("tone", [Double(index) / 10]), ScriptedAction("move", [1, 0]), ScriptedAction("ping"),
                       ScriptedAction("move", [0, 0]), ScriptedAction("jump")]
        return ExperienceScenario.Entry(steps: 10, action: actions[index % actions.count])
    })

    @Test func aScenarioReportsItsDigestAndResults() async throws {
        let result = await SampleEngine.runScenario(Self.scenario, id: SampleExperience.id)
        #expect(result.error == nil)
        #expect(result.stepIndex == 100)
        #expect(result.results.count == 10)
        #expect(result.results == ["accepted", "accepted", "accepted", "action.rule.sample.no-move", "action.unknown-control",
                                   "accepted", "accepted", "accepted", "action.rule.sample.no-move", "action.unknown-control"])
        #expect(result.digest?.hex == SampleExperience.scenarioDigest)
    }

    @Test func runningAScenarioEqualsDrivingTheEngineByHand() async throws {
        var byHand = try await makeSampleEngine(in: .active, seed: 42)
        var codes: [String] = []
        for entry in Self.scenario.entries {
            try byHand.run(steps: entry.steps)
            if let action = entry.action { codes.append(byHand.handle(control: action.control, values: action.values).code) }
        }
        var scripted = try await makeSampleEngine(in: .active, seed: 42)
        let result = scripted.run(Self.scenario)
        #expect(result.results == codes)
        #expect(result.digest == (try byHand.digest()))
        #expect(result.stepIndex == byHand.stepIndex)
    }

    @Test func aScenarioBeyondTheLimitsRunsNothing() async throws {
        var engine = try await makeSampleEngine(in: .active)
        let digest = try engine.digest()
        let tooManyEntries = ExperienceScenario(seed: 1, entries: Array(repeating: .init(steps: 0), count: 10_001))
        let tooManySteps = ExperienceScenario(seed: 1, entries: [.init(steps: 600_000), .init(steps: 400_001)])
        for scenario in [tooManyEntries, tooManySteps] {
            #expect(!scenario.isWithinLimits)
            let result = engine.run(scenario)
            #expect(result.error?.code == "experience.scenario-too-large")
            #expect(result.results.isEmpty)
            #expect(result.stepIndex == 0)
        }
        #expect(try engine.digest() == digest)
        #expect(ExperienceScenario(seed: 1, entries: [.init(steps: 1_000_000)]).isWithinLimits)
    }

    @Test func aScenarioOnAnEngineThatIsNotActiveReportsTheError() async throws {
        var engine = try await makeSampleEngine(in: .suspended)
        let result = engine.run(Self.scenario)
        #expect(result.error?.code == "experience.illegal-operation")
        #expect(result.results.isEmpty)
        let failing = await ExperienceEngine<SampleExperienceCore<FailingPreparation>>.runScenario(Self.scenario, id: SampleExperience.id)
        #expect(failing.error?.code == "sample.broken")
        #expect(failing.digest == nil)
    }

    @Test func scenarioAndResultSurviveAJSONRoundTrip() async throws {
        let data = try JSONEncoder().encode(Self.scenario)
        #expect(try JSONDecoder().decode(ExperienceScenario.self, from: data) == Self.scenario)
        let result = await SampleEngine.runScenario(Self.scenario, id: SampleExperience.id)
        let encoded = try JSONEncoder().encode(result)
        #expect(try JSONDecoder().decode(ExperienceScenarioResult.self, from: encoded) == result)
    }
}
#endif
