// SimulationCoreTests — feature 117 (A16-P01) T-A16-105 (FR-A16-120, FR-A16-130; clarifications Q4, Q5). The Simulation
// Lab core as an experience core, without a GPU: the first state and the contract (id, one host step of 1/60 s, seven
// controls, one tier, schema 1); host steps run the scheduler's iterations; every action and every refusal, a refusal
// changing nothing; a paused single step equals one model step; a stability refusal reads `a16.unstable`; the snapshot
// payload restores to the same digest and damaged or 32 × 32 states are refused; the outcome and the words. Short runs
// only, plain loops.
import Foundation
import Testing
@testable import SimulationLabExperience
import SimulationLabCore
import VisualCoreExperience

@Suite struct SimulationCoreTests {
    /// The refusal code of `a16.invalid-choice`.
    static let invalid = "action.rule." + SimulationRule.invalidChoice

    @Test func theFirstStateAndTheContract() throws {
        #expect(SimulationCore.experienceID == "a16.simulation-lab")
        #expect(SimulationCore.stepDuration == 1.0 / 60)
        #expect(SimulationCore.qualityTiers == 1)
        #expect(SimulationCore.migrations.currentVersion == 1)
        #expect(SimulationCore.controls.map(\.id) == SimulationCore.actionIDs)
        #expect(SimulationCore.actionIDs == ["sim.family", "sim.preset", "sim.run", "sim.pause", "sim.step",
                                             "sim.reset", "sim.speed"])
        let core = SimulationCore(seed: 1)
        #expect(core.kind == .automaton)
        #expect(core.preset == 0)
        #expect(core.isRunning)
        #expect(core.speedIndex == 2)
        #expect(core.stepCount == 0)
        #expect(core.model.spec == SimulationSpec.standard(.automaton, preset: 0, seed: 1))
        #expect(core.model.spec.gridSize == 64)
        #expect(core.outcome?.code == "simulating-automaton")
        #expect(SimulationCore(seed: 1) == core, "the same seed gives the same first state")
        #expect(SimulationCore(seed: 2).model.field != core.model.field, "the seed sets the seeded start")
    }

    @Test func hostStepsRunTheSchedulersIterations() {
        var core = SimulationCore(seed: 1)
        var model = core.model
        for step in 0..<6 { core.update(step: step) }
        #expect(core.stepCount == 1, "10 per second at ×1 is one generation per 6 host steps")
        model.step()
        #expect(core.model.field == model.field)
        var paused = simulationApplied(SimulationCore(seed: 1), "sim.pause").0
        let before = paused
        for step in 0..<30 { paused.update(step: step) }
        #expect(paused == before, "a paused simulation runs nothing")
    }

    @Test func familyPresetAndSpeedActions() {
        var core = SimulationCore(seed: 1)
        let speed = simulationApplied(core, "sim.speed", [4])
        #expect(speed.1 == .accepted)
        core = speed.0
        for (index, kind) in SimulationCore.families.enumerated() {
            let (next, result) = simulationApplied(core, "sim.family", [Double(index)])
            #expect(result == .accepted, "family \(index)")
            #expect(next.kind == kind)
            #expect(next.preset == 0)
            #expect(next.stepCount == 0)
            #expect(next.isRunning, "running is kept")
            #expect(next.speedIndex == 4, "the speed is kept")
            #expect(next.model.spec == SimulationSpec.standard(kind, preset: 0, seed: 1))
            #expect(next.outcome?.code == SimulationCore.outcomeCode(kind))
            let count = ParameterCatalog.presetNames(for: kind).count
            for preset in 0..<count {
                let chosen = simulationApplied(next, "sim.preset", [Double(preset)])
                #expect(chosen.1 == .accepted, "\(kind) preset \(preset)")
                #expect(chosen.0.preset == preset)
                #expect(chosen.0.model.spec == SimulationSpec.standard(kind, preset: preset, seed: 1))
            }
            for preset in stride(from: count, through: SimulationCore.maxPresetIndex, by: 1) {
                let refused = simulationApplied(next, "sim.preset", [Double(preset)])
                #expect(refused.1.code == Self.invalid, "\(kind) has no preset \(preset)")
                #expect(refused.0 == next, "a refusal changes nothing")
            }
        }
        #expect(SimulationCore.outcomeCode(family: 1) == "simulating-reaction-diffusion")
        #expect(SimulationCore.outcomeCode(family: 2) == "simulating-wave")
        for index in 0..<5 {
            let set = simulationApplied(core, "sim.speed", [Double(index)])
            #expect(set.1 == .accepted)
            #expect(set.0.speedIndex == index)
        }
    }

    @Test func refusalsChangeNothing() {
        let core = SimulationCore(seed: 1)
        let cases: [(String, [Double])] = [("sim.family", [0.5]), ("sim.preset", [1.5]), ("sim.speed", [2.5]),
                                           ("sim.run", []), ("sim.step", [])]
        for (control, values) in cases {
            let (next, result) = simulationApplied(core, control, values)
            #expect(result.code == Self.invalid, "\(control) \(values)")
            #expect(next == core, "\(control): a refusal changes nothing")
        }
        let paused = simulationApplied(core, "sim.pause").0
        #expect(simulationApplied(paused, "sim.pause").1.code == Self.invalid, "a pause while paused")
        #expect(simulationApplied(core, "sim.unknown").1 == .rejected(.unknownControl("sim.unknown")))
        #expect(simulationApplied(core, "sim.family").1 == .rejected(.wrongValueCount(expected: 1, found: 0)))
        #expect(simulationApplied(core, "sim.run", [1]).1 == .rejected(.wrongValueCount(expected: 0, found: 1)))
    }

    @Test func aPausedSingleStepEqualsOneModelStep() {
        let paused = simulationApplied(SimulationCore(seed: 1), "sim.pause").0
        for index in 0..<3 {
            let family = simulationApplied(paused, "sim.family", [Double(index)]).0
            var model = family.model
            model.step()
            let (stepped, result) = simulationApplied(family, "sim.step")
            #expect(result == .accepted)
            #expect(stepped.model == model, "family \(index): one step is one model step")
            #expect(stepped.stepCount == 1)
            #expect(!stepped.isRunning)
        }
        let running = simulationApplied(paused, "sim.run")
        #expect(running.1 == .accepted)
        #expect(running.0.isRunning)
    }

    @Test func resetActionAndCoreReset() {
        var core = SimulationCore(seed: 1)
        core = simulationApplied(core, "sim.family", [1]).0
        core = simulationApplied(core, "sim.speed", [0]).0
        for step in 0..<20 { core.update(step: step) }
        #expect(core.stepCount > 0)
        let (reset, result) = simulationApplied(core, "sim.reset")
        #expect(result == .accepted)
        #expect(reset.stepCount == 0)
        #expect(reset.kind == .reactionDiffusion, "the family stays")
        #expect(reset.speedIndex == 0, "the speed stays")
        #expect(reset.model.field == Seeding.start(for: reset.model.spec), "the seeded start")
        var fresh = core
        fresh.reset()
        #expect(fresh == SimulationCore(seed: 1), "the core's reset is a fresh preparation")
    }

    @Test func aStabilityRefusalReadsUnstable() {
        var wave = SimulationSpec.standard(.wave)
        wave.timeStep = 1
        let model = SimulationCore(seed: 1).model
        guard case .failure(let refusal) = SimulationCore.remade(model, spec: wave) else {
            Issue.record("a Courant number of 1 must be refused")
            return
        }
        #expect(refusal == .courant)
        #expect(SimulationCore.ruleCode(for: refusal) == SimulationRule.unstable)
        #expect(SimulationCore.ruleCode(for: .reactionStep) == SimulationRule.unstable)
        #expect(SimulationCore.ruleCode(for: .damaged) == SimulationRule.invalidChoice)
        var small = SimulationSpec.standard(.automaton)
        small.gridSize = 32
        guard case .failure(let grid) = SimulationCore.remade(model, spec: small) else {
            Issue.record("a 32 × 32 grid must be refused in this phase")
            return
        }
        #expect(grid.reason == .invalidGridSize)
        #expect(SimulationCore.ruleCode(for: grid) == SimulationRule.invalidChoice)
    }

    @Test func snapshotAndRestoreGiveTheSameDigest() throws {
        var core = SimulationCore(seed: 5)
        core = simulationApplied(core, "sim.family", [2]).0
        for step in 0..<12 { core.update(step: step) }
        core = simulationApplied(core, "sim.pause").0
        let payload = try core.snapshotPayload()
        #expect(payload == core.model.state.encoded())
        let restored = try SimulationCore.restore(payload: payload, seed: 5)
        #expect(restored == core)
        #expect(try simulationDigest(restored) == simulationDigest(core))
        #expect(throws: SimulationRestoreError.refused(.damaged)) {
            try SimulationCore.restore(payload: Data("{".utf8), seed: 5)
        }
        var small = SimulationSpec.standard(.automaton, seed: 5)
        small.gridSize = 32
        let model = try SimulationModel(spec: small)
        #expect(throws: SimulationRestoreError.gridSize(32)) {
            try SimulationCore.restore(payload: model.state.encoded(), seed: 5)
        }
    }

    @Test func theDigestFollowsTheState() throws {
        let core = SimulationCore(seed: 1)
        let digest = try simulationDigest(core)
        #expect(digest.count == 64)
        #expect(try simulationDigest(SimulationCore(seed: 1)) == digest)
        #expect(try simulationDigest(simulationApplied(core, "sim.pause").0) != digest)
        #expect(try simulationDigest(simulationApplied(core, "sim.family", [1]).0) != digest)
        #expect(try simulationDigest(simulationApplied(core, "sim.speed", [3]).0) != digest)
    }

    @Test func theWordsNameTheFamilyPresetGridStateAndStep() {
        let core = SimulationCore(seed: 1)
        #expect(core.canvasDescription == "Simulation Lab: cellular automaton, rule Life (B3/S23); 64 × 64 grid; "
                + "running at ×1; step 0; 1042 of 4096 cells alive.")
        #expect(core.status == "Running at ×1, step 0")
        let reaction = simulationApplied(core, "sim.family", [1]).0
        #expect(reaction.canvasDescription == "Simulation Lab: reaction-diffusion, preset Spots (feed 0.035, kill "
                + "0.065, time step 1); 64 × 64 grid; running at ×1; step 0; v from 0.00 to 0.25.")
        let wave = simulationApplied(core, "sim.family", [2]).0
        #expect(wave.canvasDescription == "Simulation Lab: wave field, preset Pulse (wave speed 1, damping 0.002, "
                + "Courant number 0.5); 64 × 64 grid; running at ×1; step 0; height from 0.00 to 1.00.")
        let paused = simulationApplied(core, "sim.pause").0
        let stepped = simulationApplied(paused, "sim.step").0
        #expect(stepped.status == "Paused, step 1")
        #expect(stepped.canvasDescription.contains("; paused; step 1; "))
        #expect(SimulationCore.presetTitles(.automaton) == ["Life (B3/S23)", "HighLife (B36/S23)", "Seeds (B2/S)"])
        #expect(SimulationCore.presetTitles(.reactionDiffusion) == ["Spots", "Mazes"])
        #expect(SimulationCore.presetTitles(.wave) == ["Pulse"])
        #expect(SimulationCore.familyTitle(index: 2) == "Wave field")
        #expect(SimulationCore.speedTitle(index: 0) == "×0.25")
        #expect(SimulationCore.decimal(-0.5) == "\u{2212}0.5")
    }
}
