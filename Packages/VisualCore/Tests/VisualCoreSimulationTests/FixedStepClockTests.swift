// FixedStepClockTests — feature 006 T-F507 (FR-F503, FR-F511; US2 AC1–AC3; spec A1/C2).
import Testing
@testable import VisualCoreSimulation

@Test func sixtyHertzFramesGiveExactly120Steps() {
    // AC1: step 1/120, 60 frames of 1/60 s → exactly 120 steps; alpha stays in [0, 1).
    var c = FixedStepClock()
    var steps = 0
    for _ in 0..<60 {
        steps += c.advance(by: 1.0 / 60)
        #expect(c.alpha >= 0 && c.alpha < 1)
    }
    #expect(steps == 120)
    #expect(c.droppedTime == 0)
}

@Test func oddRatesAccumulateFractions() {
    var c = FixedStepClock()
    var steps = 0
    for _ in 0..<144 { steps += c.advance(by: 1.0 / 144) }   // 1 s at 144 Hz
    #expect(steps == 120)
    var d = FixedStepClock()
    #expect(d.advance(by: 0.5 / 120) == 0)
    #expect(abs(d.alpha - 0.5) < 1e-12)
}

@Test func stallIsCappedAndDroppedTimeCounted() {
    // AC2: a 2 s stall runs at most 8 steps; the rest is dropped and counted.
    var c = FixedStepClock()
    #expect(c.advance(by: 2) == 8)
    #expect(abs(c.droppedTime - (240 - 8) / 120.0) < 1e-9)
    #expect(c.advance(by: 1.0 / 120) == 1, "normal frames continue afterwards")
}

@Test func invalidDeltasAreZero() {
    var c = FixedStepClock()
    #expect(c.advance(by: .nan) == 0)
    #expect(c.advance(by: -1) == 0)
    #expect(c.advance(by: .infinity) == 0)
    #expect(c.invalidDeltas == 3)
    #expect(c.accumulator == 0)
}

@Test func parametersAreBounded() {
    #expect(FixedStepClock(step: 0).step == 1.0 / 120)
    #expect(FixedStepClock(maxSteps: 100).maxSteps == 8)
    #expect(FixedStepClock(maxSteps: 0).maxSteps == 1)
}

@Test func resetAccumulatorDropsPendingTime() {
    var c = FixedStepClock()
    _ = c.advance(by: 0.9 / 120)
    c.resetAccumulator()
    #expect(c.alpha == 0)
    #expect(c.droppedTime == 0)
}

/// A toy simulation driven by the clock and a seeded RNG.
private func replay(seed: UInt64, frames: Int, frameTime: (inout SeededRandom) -> Double) -> (state: UInt64, steps: Int) {
    var clock = FixedStepClock()
    var sim = SeededRandom(seed: seed)
    var jitter = SeededRandom(seed: seed ^ 0xFFFF)
    var x = 0.0
    for _ in 0..<frames {
        for _ in 0..<clock.advance(by: frameTime(&jitter)) { x = x * 0.99 + sim.double() }
    }
    return (x.bitPattern, clock.totalSteps)
}

@Test func clockAndRandomReplayIsBitIdentical() {
    // US2 AC3 / spec C2: same seed and frame sequence → bit-identical state, twice.
    let jittered: (inout SeededRandom) -> Double = { $0.range(0.004...0.03) }
    let a = replay(seed: 5, frames: 10_000, frameTime: jittered)
    let b = replay(seed: 5, frames: 10_000, frameTime: jittered)
    #expect(a.state == b.state && a.steps == b.steps)
    #expect(replay(seed: 6, frames: 10_000, frameTime: jittered).state != a.state)
}

@Test func stateIsIndependentOfDisplayRate() {
    // FR-F511: 10 s at 60 Hz and at 120 Hz reach the same step count and state.
    let at60 = replay(seed: 11, frames: 600) { _ in 1.0 / 60 }
    let at120 = replay(seed: 11, frames: 1200) { _ in 1.0 / 120 }
    #expect(at60.steps == 1200 && at120.steps == 1200)
    #expect(at60.state == at120.state)
}
