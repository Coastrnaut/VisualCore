// FixedStepRunnerTests — feature 033 A04-P01 T-A04-103 (G-SIMSTEP; FR-A04-103, FR-A04-104; SC-A04-103, SC-A04-104;
// contract C5–C7).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreSimulation

/// A tiny simulation recording every step and applied value.
private struct Counter: FixedStepSimulation, Sendable {
    var steps = 0, value = 0, log: [String] = []
    mutating func step(_ dt: Double) { steps += 1 }
    func checksum() -> UInt64 { UInt64(steps) &* 31 &+ UInt64(bitPattern: Int64(value)) }
}

private func counterRunner(_ stream: ControlStream<Int> = ControlStream()) -> FixedStepRunner<Counter, Int> {
    FixedStepRunner(simulation: Counter(), stream: stream) { sim, add in
        sim.value += add
        sim.log.append("+\(add)@\(sim.steps)")
    }
}

@Test func pausedRunnerRunsNoStepsAndResumeDiscardsTime() {
    // C5 / SC-A04-104.
    var r = counterRunner()
    #expect(r.advance(frame: 1.0 / 60) == 2)
    r.pause()
    #expect(r.isPaused)
    for _ in 0..<1_800 { #expect(r.advance(frame: 1.0 / 60) == 0) }   // 30 s away
    r.advance(frame: 0.004)                                              // a partial frame while paused
    r.resume()
    #expect(r.advance(frame: 0.005) == 0, "time from before the pause is not caught up")
    #expect(r.simulation.steps == 2)
    #expect(r.clock.droppedTime == 0)
}

@Test func aLongFrameRunsAtMostTheCap() {
    // C6 / SC-A04-104: a 10 s frame runs 8 steps; the rest is dropped time.
    var r = counterRunner()
    #expect(r.advance(frame: 10) == 8)
    #expect(r.simulation.steps == 8)
    #expect(abs(r.clock.droppedTime - (10 - 8.0 / 120)) < 1e-9)
}

@Test func invalidFrameTimesRunNoStepsAndAreCounted() {
    var r = counterRunner()
    for dt in [Double.nan, -1, .infinity, -.infinity] { #expect(r.advance(frame: dt) == 0) }
    #expect(r.clock.invalidDeltas == 4)
    #expect(r.simulation.steps == 0)
}

@Test func stepOnceWorksWhilePaused() {
    var r = counterRunner()
    r.pause()
    r.stepOnce(); r.stepOnce()
    #expect(r.stepIndex == 2 && r.simulation.steps == 2)
}

@Test func commandsApplyJustBeforeTheirStep() {
    // C7: a command at step k applies after k steps have run; insertion order is kept within a step; negative steps
    // are dropped.
    var r = counterRunner(ControlStream([(step: 3, command: 10), (step: 0, command: 1), (step: 3, command: 20), (step: -1, command: 99)]))
    r.run(steps: 5)
    #expect(r.simulation.log == ["+1@0", "+10@3", "+20@3"])
    #expect(r.simulation.value == 31)
    #expect(r.stream.commands(at: 3) == [10, 20])
    #expect(r.stream.entries.count == 3)
}

@Test func frameSplittingDoesNotChangeTheReplay() {
    // C7 / SC-A04-103: the same particle replay through 1/60 s frames, 1/30 s frames and `run(steps:)` gives the same
    // checksum.
    func runner() -> FixedStepRunner<ParticleSystem, Vec2> {
        var ps = ParticleSystem(capacity: 2_000, seed: 0x5EED)
        ps.emitters = [Emitter(rate: 300, lifetime: 1...3, shape: .ring(radius: 50)),
                       Emitter(rate: 0, lifetime: 2...2, burst: EmitterBurst(count: 100, interval: 0.75))]
        ps.forces = [.attractor(point: .zero, strength: 200, radius: 400), .drag(0.3)]
        return FixedStepRunner(simulation: ps, stream: ControlStream([(step: 60, command: Vec2(120, 80)),
                                                                     (step: 150, command: Vec2(-50, 10))])) { sim, p in
            sim.forces[0] = .attractor(point: p, strength: 200, radius: 400)
        }
    }
    var a = runner(), b = runner(), c = runner()
    for _ in 0..<120 { a.advance(frame: 1.0 / 60) }   // 240 steps
    for _ in 0..<60 { b.advance(frame: 1.0 / 30) }    // 240 steps
    c.run(steps: 240)
    #expect(a.stepIndex == 240 && b.stepIndex == 240)
    #expect(a.simulation.checksum() == b.simulation.checksum())
    #expect(a.simulation.checksum() == c.simulation.checksum())
    #expect(a.simulation.aliveCount > 0)

    var other = runner()
    other.mutate { $0 = ParticleSystem(capacity: 2_000, seed: 1) }
    other.mutate { $0.emitters = c.simulation.emitters; $0.forces = [.attractor(point: .zero, strength: 200, radius: 400), .drag(0.3)] }
    other.run(steps: 240)
    #expect(other.simulation.checksum() != c.simulation.checksum(), "another seed gives another scene")
}
