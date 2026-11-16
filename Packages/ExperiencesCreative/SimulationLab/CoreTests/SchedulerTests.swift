// SchedulerTests — feature 117 (A16-P01) T-A16-104 (FR-A16-120; clarification Q4). The scheduler and the simulation
// model, host-free and short: each speed gives speed × base rate iterations per second at the 1/60 s host step; pause
// stops; one step while paused adds exactly one and equals one rule step; reset gives the seeded start and step 0; no
// host step runs more than 16; a long gap does not burst.
import Testing
import VisualCoreSimulation
@testable import SimulationLabCore

@Suite struct SchedulerTests {
    /// A valid 16 × 16 model of `kind`.
    private func model(_ kind: SimulationKind, preset: Int = 0, seed: UInt64 = 5, running: Bool = true)
        -> SimulationModel {
        var spec = SimulationSpec.standard(kind, preset: preset, seed: seed)
        spec.gridSize = 16
        return try! SimulationModel(spec: spec, running: running)
    }

    @Test func everySpeedRunsItsRateAtTheHostStep() {
        #expect(SimulationScheduler.speeds == [0.25, 0.5, 1, 2, 4] && SimulationScheduler.maxIterationsPerHostStep == 16)
        #expect(SimulationKind.automaton.baseRate == 10 && SimulationKind.reactionDiffusion.baseRate == 240)
        #expect(SimulationKind.wave.baseRate == 120 && SimulationScheduler.hostStep == 1.0 / 60)
        for kind in SimulationKind.allCases {
            for index in SimulationScheduler.speeds.indices {
                var scheduler = SimulationScheduler(kind: kind, speedIndex: index)
                var total = 0, most = 0
                for _ in 0..<240 {   // 4 s
                    let n = scheduler.iterations(forHostStep: SimulationScheduler.hostStep)
                    total += n
                    most = max(most, n)
                }
                let expected = Int(kind.baseRate * SimulationScheduler.speeds[index] * 4)
                #expect(total == expected && scheduler.stepCount == expected, "\(kind) ×\(SimulationScheduler.speeds[index])")
                #expect(most <= 16)
            }
        }
    }

    @Test func noHostStepRunsMoreThanSixteenAndALongGapDoesNotBurst() {
        var scheduler = SimulationScheduler(kind: .reactionDiffusion, speedIndex: 4)
        #expect(scheduler.iterations(forHostStep: SimulationScheduler.hostStep) == 16)
        #expect(scheduler.iterations(forHostStep: 1) == 16 && scheduler.accumulator == 0)
        #expect(scheduler.iterations(forHostStep: 3600) == 16 && scheduler.accumulator == 0)
        #expect(scheduler.iterations(forHostStep: 1e308) == 16)
        #expect(scheduler.iterations(forHostStep: SimulationScheduler.hostStep) == 16)
        var wave = SimulationScheduler(kind: .wave, speedIndex: 2)
        #expect(wave.iterations(forHostStep: 10) == 16)
        #expect(wave.iterations(forHostStep: SimulationScheduler.hostStep) == 2)
        let invalid: [Double] = [0, -1, .nan, .infinity, -.infinity]
        for step in invalid { #expect(wave.iterations(forHostStep: step) == 0, "\(step)") }
        #expect(wave.stepCount == 18)

        var m = model(.reactionDiffusion)
        m.setSpeed(4)
        #expect(m.advance(hostStep: 100) == 16 && m.stepCount == 16)
        #expect(m.advance() == 16 && m.stepCount == 32)
    }

    @Test func pauseStopsAndRunResumes() {
        var scheduler = SimulationScheduler(kind: .wave)
        #expect(scheduler.running && scheduler.speedIndex == 2)
        _ = scheduler.iterations(forHostStep: SimulationScheduler.hostStep)
        scheduler.pause()
        for _ in 0..<60 { #expect(scheduler.iterations(forHostStep: SimulationScheduler.hostStep) == 0) }
        #expect(scheduler.stepCount == 2 && !scheduler.running && scheduler.accumulator == 0)
        scheduler.run()
        #expect(scheduler.iterations(forHostStep: SimulationScheduler.hostStep) == 2)

        var m = model(.automaton)
        m.pause()
        let before = m
        for _ in 0..<30 { #expect(m.advance() == 0) }
        #expect(m == before)
    }

    @Test func oneStepWhilePausedAddsExactlyOneRuleStep() {
        for kind in SimulationKind.allCases {
            var m = model(kind, running: false)
            let start = m.field
            #expect(m.singleStep() && m.stepCount == 1, "\(kind)")
            switch kind {
            case .automaton:
                #expect(m.field.current == AutomatonRule.life.step(start.current))
            case .reactionDiffusion:
                #expect(m.field.current == GrayScott.step(start.current, spec: m.spec))
            case .wave:
                let previous = start.previous ?? start.current
                #expect(m.field.current == WaveField.step(current: start.current, previous: previous, spec: m.spec))
                #expect(m.field.previous == start.current)
            }
            #expect(m.field != start)
            m.run()
            let running = m
            #expect(!m.singleStep() && m == running)
            m.step()
            #expect(m.stepCount == 2)
        }
        var scheduler = SimulationScheduler(kind: .automaton, running: false)
        #expect(scheduler.singleStep() && scheduler.stepCount == 1)
    }

    @Test func resetGivesTheSeededStartAndStepZero() {
        for kind in SimulationKind.allCases {
            let fresh = model(kind)
            var m = fresh
            m.setSpeed(3)
            for _ in 0..<5 { m.advance() }
            #expect(m.stepCount > 0 && m.field != fresh.field, "\(kind)")
            m.reset()
            #expect(m.field == fresh.field && m.stepCount == 0 && m.scheduler.accumulator == 0)
            #expect(m.scheduler.speedIndex == 3 && m.isRunning)
            m.setSpeed(2)
            #expect(m.digest == fresh.digest)
        }
    }

    @Test func speedChangesAreBounded() {
        var scheduler = SimulationScheduler(kind: .automaton)
        #expect(scheduler.setSpeed(0) && scheduler.speed == 0.25 && scheduler.iterationsPerSecond == 2.5)
        let before = scheduler
        let refused: [Int] = [-1, 5, Int.max]
        for index in refused { #expect(!scheduler.setSpeed(index) && scheduler == before) }
        #expect(SimulationScheduler(kind: .wave, speedIndex: 99).speedIndex == 4)
    }

    @Test func theDigestIsDeterministic() {
        for kind in SimulationKind.allCases {
            var a = model(kind), b = model(kind)
            for _ in 0..<3 { a.advance(); b.advance() }
            #expect(a.digest == b.digest && a.digest.count == 64, "\(kind)")
            #expect(model(kind, seed: 6).digest != model(kind).digest)
        }
        var spec = SimulationSpec.standard(.wave)
        spec.timeStep = 0.9
        #expect(throws: SimulationRefusal.courant) { try SimulationModel(spec: spec) }
    }
}
