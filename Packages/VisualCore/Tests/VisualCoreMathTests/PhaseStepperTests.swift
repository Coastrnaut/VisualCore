// PhaseStepperTests — feature 215 (R02-F15) T-R02F15-004 (FR-R02F15-004; SC-R02F15-003; clarification Q3).
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreMath

@Suite struct PhaseStepperTests {
    private func closed(tp: Double = 0.3) throws -> ConicOrbit {
        try ConicOrbit(periapsisDistance: 0.5, eccentricity: 0.5, inclination: 0.2, ascendingNode: 0.1,
                       argumentOfPeriapsis: 0.4, timeOfPeriapsis: tp, gravitationalParameter: 1)
    }

    @Test func steppingEqualsJumpingBitForBit() throws {
        var stepped = try PhaseStepper(startTime: 12.5, step: 1.0 / 120.0)
        for _ in 0..<100_000 { try stepped.advance() }
        var jumped = try PhaseStepper(startTime: 12.5, step: 1.0 / 120.0)
        try jumped.jump(to: 100_000)
        #expect(stepped == jumped)
        #expect(stepped.time.bitPattern == jumped.time.bitPattern)
        #expect(stepped.time.bitPattern == (12.5 + 100_000.0 * (1.0 / 120.0)).bitPattern)
    }

    @Test func phaseOfClosedAndOpenOrbits() throws {
        let orbit = try closed()
        let period = try #require(orbit.period)
        let quarter = try #require(PhaseStepper.phase(of: orbit, at: 0.3 + 0.25 * period))
        #expect(abs(quarter - 0.25) < 1e-12)
        for k in 0..<1_000 {
            let t: Double = -500 + Double(k) * 1.37
            let p = try #require(PhaseStepper.phase(of: orbit, at: t))
            #expect(p >= 0 && p < 1)
        }
        let open = try ConicOrbit(periapsisDistance: 1, eccentricity: 1.5, inclination: 0, ascendingNode: 0,
                                  argumentOfPeriapsis: 0, timeOfPeriapsis: 0, gravitationalParameter: 1)
        #expect(PhaseStepper.phase(of: open, at: 1) == nil)
        #expect(PhaseStepper.phase(of: orbit, at: .nan) == nil)
    }

    @Test func adjacentSpansReportEachPassageOnce() throws {
        let orbit = try closed()
        let period = try #require(orbit.period)
        let start: Double = 0.3
        let end: Double = 0.3 + 100 * period
        let whole = try PhaseStepper.passages(of: orbit, from: start, to: end)
        var periapses = 0
        var apoapses = 0
        for passage in whole {
            if passage.kind == .periapsis { periapses += 1 } else { apoapses += 1 }
        }
        #expect(periapses == 100 && apoapses == 100)
        for k in 1..<whole.count { #expect(whole[k - 1].time < whole[k].time) }
        var pieces: [Passage] = []
        var cut = start
        for k in 1...37 {
            let next = k == 37 ? end : start + (end - start) * Double(k) / 37
            pieces += try PhaseStepper.passages(of: orbit, from: cut, to: next)
            cut = next
        }
        #expect(pieces == whole)
    }

    @Test func openOrbitHasOnePeriapsisPassage() throws {
        let open = try ConicOrbit(periapsisDistance: 1, eccentricity: 1, inclination: 0, ascendingNode: 0,
                                  argumentOfPeriapsis: 0, timeOfPeriapsis: 4, gravitationalParameter: 1)
        let inside = try PhaseStepper.passages(of: open, from: 0, to: 10)
        #expect(inside == [Passage(kind: .periapsis, index: 0, time: 4)])
        #expect(try PhaseStepper.passages(of: open, from: 4.5, to: 10).isEmpty)
    }

    @Test func refusals() throws {
        #expect(throws: OrbitError.invalidStep) { try PhaseStepper(step: 0) }
        #expect(throws: OrbitError.invalidStep) { try PhaseStepper(step: .infinity) }
        #expect(throws: OrbitError.tickLimit(-1)) { try PhaseStepper(step: 1, tick: -1) }
        var stepper = try PhaseStepper(step: 1, tick: PhaseStepper.maxTick)
        #expect(throws: OrbitError.tickLimit(PhaseStepper.maxTick + 1)) { try stepper.advance() }
        #expect(stepper.tick == PhaseStepper.maxTick)
        let orbit = try closed()
        #expect(throws: OrbitError.invalidStep) { try PhaseStepper.passages(of: orbit, from: 2, to: 1) }
        #expect(throws: OrbitError.invalidStep) { try PhaseStepper.passages(of: orbit, from: 0, to: .nan) }
        do {
            _ = try PhaseStepper.passages(of: orbit, from: 0, to: 1e9)
            Issue.record("span limit not enforced")
        } catch {
            #expect(error.reasonCode == "r2-f15.span-limit")
        }
        #expect(OrbitError.tickLimit(3).reasonCode == "r2-f15.tick-limit")
    }
}
