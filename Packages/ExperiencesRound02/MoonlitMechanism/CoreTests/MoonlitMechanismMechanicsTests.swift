// MoonlitMechanismMechanicsTests — feature 431 (R02-G14-01) T-R02G1401-003 (FR-R02G1401-002, 003, 005, 014;
// SC-R02G1401-003, 004; clarifications Q2, Q3, Q4). The exact mechanics against independent references: on 500 seeded
// set-ups (the fixtures' levels with random phases and lamp heights drawn from seed 2_431) every handle turn equals a
// tooth-by-tooth walk with directions found by following parents to the driver, every alignment error equals a brute
// force over whole multiples of the mesh divisor, every cast equals a rasterisation into a W × H grid, and every run's
// outcome and frame counts equal a direct transcription of clarification Q4. Properties: a turn never changes an
// alignment error; a re-seat of a child by ±1 moves that pair's phase sum modulo g by ±1. Hand cases: a 6- and 12-tooth
// train, a forbidden cell at a key frame that is not required, stray at and above the allowance, a jam reported before a
// forbidden cell, and cells the lamp shifts off the wall.
import Testing
import VisualCoreSimulation
@testable import MoonlitMechanismCore

@Suite struct MoonlitMechanismMechanicsTests {
    // MARK: - Independent references

    /// The direction of gear `index`, found by following parents to the driver and counting the meshes.
    static func walkDirection(_ gears: [MoonlitMechanismGear], _ index: Int) -> Int {
        var sign: Int = 1
        var current: Int = index
        while let parent = gears[current].parent {
            sign = -sign
            current = parent
        }
        return sign
    }

    /// The phases after `turns` handle turns, stepped one tooth at a time.
    static func walkTurned(_ gears: [MoonlitMechanismGear], phases: [Int], by turns: Int) -> [Int] {
        var result: [Int] = phases
        let step: Int = turns >= 0 ? 1 : -1
        var remaining: Int = abs(turns)
        while remaining > 0 {
            for index in gears.indices {
                var next: Int = result[index] + walkDirection(gears, index) * step
                if next >= gears[index].teeth { next -= gears[index].teeth }
                if next < 0 { next += gears[index].teeth }
                result[index] = next
            }
            remaining -= 1
        }
        return result
    }

    /// The greatest common divisor by trial: the largest d dividing both.
    static func trialDivisor(_ a: Int, _ b: Int) -> Int {
        var best: Int = 1
        for d in 1...min(a, b) where a % d == 0 && b % d == 0 { best = d }
        return best
    }

    /// The alignment error by brute force: the minimum over k of |s + k·g − a| with s = (pₚ + p_c) mod g.
    static func bruteError(_ gears: [MoonlitMechanismGear], phases: [Int], child: Int) -> Int {
        guard let parent = gears[child].parent else { return 0 }
        let g: Int = trialDivisor(gears[parent].teeth, gears[child].teeth)
        let s: Int = (phases[parent] + phases[child]) % g
        var best: Int = Int.max
        for k in -2...2 { best = min(best, abs(s + k * g - gears[child].alignment)) }
        return best
    }

    /// The cast by rasterisation into a rows × width grid of booleans, read back row by row.
    static func rasterCast(_ gears: [MoonlitMechanismGear], phases: [Int], height: Int, width: Int,
                           rows: Int) -> [Int] {
        var grid: [[Bool]] = Array(repeating: Array(repeating: false, count: width), count: rows)
        for index in gears.indices {
            let gear: MoonlitMechanismGear = gears[index]
            for b in 0..<gear.teeth {
                guard gear.blades[b] else { continue }
                let slot: Int = (b + phases[index]) % gear.teeth
                for offset in gear.slots[slot] {
                    let x: Int = gear.centre.column + offset.column
                    let y: Int = gear.centre.row + offset.row + height * gear.depth
                    if x < 0 || x >= width || y < 0 || y >= rows { continue }
                    grid[y][x] = true
                }
            }
        }
        var cells: [Int] = []
        for y in 0..<rows {
            for x in 0..<width where grid[y][x] { cells.append(y * width + x) }
        }
        return cells
    }

    /// One key frame's counts by the references: covered, missing, stray and the forbidden cells shadowed (sorted).
    struct Counts: Equatable {
        let phases: [Int]
        let cast: [Int]
        let covered: Int
        let missing: Int
        let stray: Int
        let forbidden: [Int]
    }

    /// A run transcribed from clarification Q4.
    static func transcribedRun(_ level: MoonlitMechanismLevel, phases: [Int],
                               height: Int) -> (errors: [Int], frames: [Counts], outcome: MoonlitMechanismOutcome) {
        var errors: [Int] = []
        for index in level.gears.indices { errors.append(bruteError(level.gears, phases: phases, child: index)) }
        var frames: [Counts] = []
        for frame in level.keyFrames {
            let at: [Int] = walkTurned(level.gears, phases: phases, by: frame.turns)
            let cells: [Int] = rasterCast(level.gears, phases: at, height: height, width: level.width,
                                          rows: level.rows)
            var covered: Int = 0
            for cell in frame.target where cells.contains(cell) { covered += 1 }
            var stray: Int = 0
            for cell in cells where !frame.target.contains(cell) { stray += 1 }
            var shadowed: [Int] = []
            for cell in level.forbidden where cells.contains(cell) { shadowed.append(cell) }
            frames.append(Counts(phases: at, cast: cells, covered: covered, missing: frame.target.count - covered,
                                 stray: stray, forbidden: shadowed.sorted()))
        }
        for child in 1..<max(1, level.gears.count) where errors[child] != 0 {
            return (errors, frames, .jammed(child: child))
        }
        for (index, counts) in frames.enumerated() {
            if let cell = counts.forbidden.min() { return (errors, frames, .forbidden(frame: index, cell: cell)) }
            if level.keyFrames[index].required {
                if counts.missing > 0 { return (errors, frames, .missing(frame: index, count: counts.missing)) }
                if counts.stray > level.allowance {
                    return (errors, frames, .stray(frame: index, count: counts.stray))
                }
            }
        }
        return (errors, frames, .won)
    }

    /// A seeded set-up: a level, phases and a lamp height.
    struct SetUp {
        let level: MoonlitMechanismLevel
        let phases: [Int]
        let height: Int
    }

    /// 500 seeded set-ups from the fixtures' levels: by turns, random phases (mostly jammed), the solution turned by a
    /// random count (aligned, so the key frames decide), the solution with one random re-seat, and the start.
    static func setUps() -> [SetUp] {
        let fixtures: [MoonlitMechanismFixture] = MoonlitMechanismFixture.all(count: 50)
        var random = SeededRandom(seed: 2_431)
        var result: [SetUp] = []
        for i in 0..<500 {
            let fixture: MoonlitMechanismFixture = fixtures[i % fixtures.count]
            let level: MoonlitMechanismLevel = fixture.level
            let height: Int = Int.random(in: 0..<level.lampHeights, using: &random)
            var phases: [Int]
            switch i % 4 {
            case 0:
                phases = []
                for gear in level.gears { phases.append(Int.random(in: 0..<gear.teeth, using: &random)) }
            case 1:
                phases = MoonlitMechanismTrain.turned(level.gears, phases: fixture.solution,
                                                      by: Int.random(in: -12...12, using: &random))
            case 2:
                phases = fixture.solution
                let gear: Int = Int.random(in: 1..<level.gears.count, using: &random)
                let step: Int = Bool.random(using: &random) ? 1 : -1
                phases[gear] = (phases[gear] + step + level.gears[gear].teeth) % level.gears[gear].teeth
            default:
                phases = level.startingPhases
            }
            result.append(SetUp(level: level, phases: phases, height: height))
        }
        return result
    }

    // MARK: - Seeded comparisons

    @Test func turnedEqualsToothByToothWalk() {
        var random = SeededRandom(seed: 2_431)
        for setUp in Self.setUps() {
            let gears: [MoonlitMechanismGear] = setUp.level.gears
            for index in gears.indices {
                #expect(MoonlitMechanismTrain.direction(gears, index) == Self.walkDirection(gears, index),
                        "a gear's direction is +1 at an even distance from the driver and -1 at an odd one")
            }
            let turns: Int = Int.random(in: 1...40, using: &random)
            for signed in [turns, -turns, 0] {
                #expect(MoonlitMechanismTrain.turned(gears, phases: setUp.phases, by: signed)
                        == Self.walkTurned(gears, phases: setUp.phases, by: signed),
                        "a handle turn of t equals t single-tooth steps of every gear in its direction")
            }
        }
    }

    @Test func alignmentErrorEqualsBruteForce() {
        for setUp in Self.setUps() {
            let gears: [MoonlitMechanismGear] = setUp.level.gears
            for child in gears.indices {
                let error: Int = MoonlitMechanismTrain.alignmentError(gears, phases: setUp.phases, child: child)
                #expect(error == Self.bruteError(gears, phases: setUp.phases, child: child),
                        "the alignment error is the cyclic distance between the phase sum modulo g and the alignment")
                if let parent = gears[child].parent {
                    #expect(error <= Self.trialDivisor(gears[parent].teeth, gears[child].teeth) / 2,
                            "an alignment error is at most half the mesh divisor")
                }
            }
        }
    }

    @Test func castEqualsRasterisation() {
        var random = SeededRandom(seed: 2_431)
        for setUp in Self.setUps() {
            let level: MoonlitMechanismLevel = setUp.level
            let heights: [Int] = [setUp.height, Int.random(in: 0...6, using: &random)]
            for height in heights {
                #expect(MoonlitMechanismTrain.cast(level.gears, phases: setUp.phases, height: height,
                                                   width: level.width, rows: level.rows)
                        == Self.rasterCast(level.gears, phases: setUp.phases, height: height, width: level.width,
                                           rows: level.rows),
                        "the cast equals the rasterised union of every solid blade's cells shifted by height times depth")
            }
        }
    }

    @Test func runEqualsTranscriptionOfQ4() {
        var outcomes: [String: Int] = [:]
        for setUp in Self.setUps() {
            let report: MoonlitMechanismRunReport = setUp.level.run(phases: setUp.phases, height: setUp.height)
            let expected = Self.transcribedRun(setUp.level, phases: setUp.phases, height: setUp.height)
            #expect(report.outcome == expected.outcome,
                    "the run's outcome follows Q4: jam first, then forbidden, missing and stray by key frame")
            #expect(report.errors == expected.errors, "the report lists every pair's alignment error")
            #expect(report.frames.count == expected.frames.count, "the report lists every key frame")
            for (frame, counts) in zip(report.frames, expected.frames) {
                let mine = Counts(phases: frame.phases, cast: frame.cast, covered: frame.covered,
                                  missing: frame.missing, stray: frame.stray, forbidden: frame.forbidden)
                #expect(mine == counts, "every key frame's phases, cast and counts equal the transcription")
            }
            let key: String
            switch report.outcome {
            case .won: key = "won"
            case .jammed: key = "jammed"
            case .forbidden: key = "forbidden"
            case .missing: key = "missing"
            case .stray: key = "stray"
            }
            outcomes[key, default: 0] += 1
        }
        #expect((outcomes["won"] ?? 0) > 0, "the seeded set-ups include wins")
        #expect((outcomes["jammed"] ?? 0) > 0, "the seeded set-ups include jams")
        #expect((outcomes["missing"] ?? 0) + (outcomes["stray"] ?? 0) > 0,
                "the seeded set-ups include key-frame failures")
    }

    // MARK: - Properties

    @Test func turnNeverChangesAnAlignmentError() {
        var random = SeededRandom(seed: 2_431)
        for setUp in Self.setUps() {
            let gears: [MoonlitMechanismGear] = setUp.level.gears
            let turns: Int = Int.random(in: -30...30, using: &random)
            let after: [Int] = MoonlitMechanismTrain.turned(gears, phases: setUp.phases, by: turns)
            for child in gears.indices {
                #expect(MoonlitMechanismTrain.alignmentError(gears, phases: after, child: child)
                        == MoonlitMechanismTrain.alignmentError(gears, phases: setUp.phases, child: child),
                        "a handle turn never changes any alignment error")
            }
        }
    }

    @Test func reseatMovesThePairSumByOne() {
        for setUp in Self.setUps() {
            let gears: [MoonlitMechanismGear] = setUp.level.gears
            for child in 1..<gears.count {
                guard let parent = gears[child].parent else { continue }
                let g: Int = Self.trialDivisor(gears[parent].teeth, gears[child].teeth)
                let before: Int = (setUp.phases[parent] + setUp.phases[child]) % g
                for step in [1, -1] {
                    guard let next = MoonlitMechanismFixture.apply(.reseat(child, step), gears: gears,
                                                                   phases: setUp.phases, height: setUp.height,
                                                                   lampHeights: setUp.level.lampHeights)
                    else {
                        Issue.record("a re-seat of a child by one tooth is accepted")
                        continue
                    }
                    let after: Int = (next.phases[parent] + next.phases[child]) % g
                    #expect(after == (before + step + g) % g,
                            "a re-seat of a child by one tooth moves that pair's sum modulo g by the same step")
                    let errorBefore: Int = MoonlitMechanismTrain.alignmentError(gears, phases: setUp.phases,
                                                                                child: child)
                    let errorAfter: Int = MoonlitMechanismTrain.alignmentError(gears, phases: next.phases,
                                                                               child: child)
                    #expect(abs(errorAfter - errorBefore) <= 1, "a re-seat by one tooth moves an error by at most one")
                }
            }
        }
    }

    // MARK: - Hand cases

    /// The hand train: gear 0 (6 teeth, one solid blade at bit 0, slot k covers offset (k − 2, 0), centre (4, 2)) and
    /// gear 1 (12 teeth, `solid` solid blades from bit 0, every slot covers the centre (8, 5)); both depth 1; g = 6,
    /// alignment 0.
    static func handGears(phases: [Int] = [0, 0], firstSolid: Int = 1) -> [MoonlitMechanismGear] {
        var blades0: [Bool] = Array(repeating: false, count: 6)
        for b in 0..<firstSolid { blades0[b] = true }
        var slots0: [[MoonlitMechanismCell]] = []
        for k in 0..<6 { slots0.append([MoonlitMechanismCell(column: k - 2, row: 0)]) }
        var blades1: [Bool] = Array(repeating: false, count: 12)
        blades1[0] = true
        var slots1: [[MoonlitMechanismCell]] = []
        for _ in 0..<12 { slots1.append([MoonlitMechanismCell(column: 0, row: 0)]) }
        return [
            MoonlitMechanismGear(teeth: 6, phase: phases[0], blades: blades0, depth: 1,
                                 centre: MoonlitMechanismCell(column: 4, row: 2), parent: nil, alignment: 0,
                                 slots: slots0),
            MoonlitMechanismGear(teeth: 12, phase: phases[1], blades: blades1, depth: 1,
                                 centre: MoonlitMechanismCell(column: 8, row: 5), parent: 0, alignment: 0,
                                 slots: slots1),
        ]
    }

    static func handLevel(frames: [MoonlitMechanismKeyFrame], forbidden: [Int], allowance: Int,
                          firstSolid: Int = 1) throws(MoonlitMechanismError) -> MoonlitMechanismLevel {
        try MoonlitMechanismLevel(id: "hand", seed: 1, difficulty: 1, gears: handGears(firstSolid: firstSolid),
                                  width: 10, rows: 8, lampHeights: 4, startingHeight: 0, keyFrames: frames,
                                  forbidden: forbidden, allowance: allowance, budget: 5)
    }

    @Test func handTrainOfSixAndTwelveTeeth() {
        let gears: [MoonlitMechanismGear] = Self.handGears()
        #expect(MoonlitMechanismTrain.gcd(6, 12) == 6, "the mesh divisor of 6 and 12 teeth is 6")
        #expect(MoonlitMechanismTrain.direction(gears, 0) == 1, "the driver turns forward")
        #expect(MoonlitMechanismTrain.direction(gears, 1) == -1, "the driven gear turns backward")
        let cases: [(Int, Int, Int)] = [(3, 4, 2), (-8, 5, 1), (14, 3, 3), (0, 1, 5), (12, 1, 5)]
        for (turns, phase0, phase1) in cases {
            let after: [Int] = MoonlitMechanismTrain.turned(gears, phases: [1, 5], by: turns)
            #expect(after == [phase0, phase1], "the hand train from phases 1 and 5 lands on its known phases")
            #expect(MoonlitMechanismTrain.alignmentError(gears, phases: after, child: 1) == 0,
                    "the hand train stays aligned through every turn")
        }
        #expect(MoonlitMechanismTrain.alignmentError(gears, phases: [1, 2], child: 1) == 3,
                "a phase sum of 3 against alignment 0 modulo 6 is 3 teeth off")
        #expect(MoonlitMechanismTrain.alignmentError(gears, phases: [1, 4], child: 1) == 1,
                "a phase sum of 5 against alignment 0 modulo 6 is 1 tooth off cyclically")
    }

    @Test func forbiddenAtAKeyFrameThatIsNotRequiredFails() throws {
        let frames: [MoonlitMechanismKeyFrame] = [MoonlitMechanismKeyFrame(turns: 0, target: [22, 58], required: true),
                                                  MoonlitMechanismKeyFrame(turns: 1, target: [58], required: false)]
        let level: MoonlitMechanismLevel = try Self.handLevel(frames: frames, forbidden: [5, 23], allowance: 0)
        let report: MoonlitMechanismRunReport = level.run(phases: [0, 0], height: 0)
        #expect(report.frames[0].cast == [22, 58], "key frame 0 casts the driver's blade and the driven centre")
        #expect(report.frames[1].cast == [23, 58], "key frame 1 moves the driver's blade one column right")
        #expect(report.frames[1].forbidden == [23], "key frame 1 shadows forbidden cell 23")
        #expect(report.outcome == .forbidden(frame: 1, cell: 23),
                "a forbidden cell fails the run even at a key frame that is not required")
    }

    @Test func strayAtTheAllowanceWinsAndOneMoreFails() throws {
        let frames: [MoonlitMechanismKeyFrame] = [MoonlitMechanismKeyFrame(turns: 0, target: [22], required: true),
                                                  MoonlitMechanismKeyFrame(turns: 1, target: [58], required: false)]
        let atAllowance: MoonlitMechanismLevel = try Self.handLevel(frames: frames, forbidden: [], allowance: 1)
        let report: MoonlitMechanismRunReport = atAllowance.run(phases: [0, 0], height: 0)
        #expect(report.frames[0].stray == 1, "key frame 0 casts one cell outside its target")
        #expect(report.outcome == .won, "stray exactly at the allowance wins")
        let belowAllowance: MoonlitMechanismLevel = try Self.handLevel(frames: frames, forbidden: [], allowance: 0)
        #expect(belowAllowance.run(phases: [0, 0], height: 0).outcome == .stray(frame: 0, count: 1),
                "one stray cell above an allowance of 0 fails stray")
        let twoBlades: MoonlitMechanismLevel = try Self.handLevel(frames: frames, forbidden: [], allowance: 1,
                                                                  firstSolid: 2)
        let wider: MoonlitMechanismRunReport = twoBlades.run(phases: [0, 0], height: 0)
        #expect(wider.frames[0].cast == [22, 23, 58], "two solid driver blades cast two neighbouring cells")
        #expect(wider.outcome == .stray(frame: 0, count: 2), "two stray cells above an allowance of 1 fail stray")
    }

    @Test func jamIsReportedBeforeAForbiddenCell() throws {
        let frames: [MoonlitMechanismKeyFrame] = [MoonlitMechanismKeyFrame(turns: 0, target: [22, 58], required: true),
                                                  MoonlitMechanismKeyFrame(turns: 1, target: [58], required: false)]
        let level: MoonlitMechanismLevel = try Self.handLevel(frames: frames, forbidden: [5, 23], allowance: 0)
        let report: MoonlitMechanismRunReport = level.run(phases: [1, 0], height: 0)
        #expect(report.errors == [0, 1], "the driven gear is one tooth off")
        #expect(report.frames[0].forbidden == [23], "key frame 0 shadows forbidden cell 23 at these phases")
        #expect(report.outcome == .jammed(child: 1), "a jam decides before any forbidden cell")
    }

    @Test func cellsShiftedOffTheWallAreDropped() {
        let gears: [MoonlitMechanismGear] = Self.handGears()
        #expect(MoonlitMechanismTrain.cast(gears, phases: [0, 0], height: 2, width: 10, rows: 8) == [42, 78],
                "at lamp height 2 both cells move down two rows and stay on the wall")
        #expect(MoonlitMechanismTrain.cast(gears, phases: [0, 0], height: 3, width: 10, rows: 8) == [52],
                "at lamp height 3 the driven gear's cell moves to row 8 and is dropped")
        #expect(MoonlitMechanismTrain.cast(gears, phases: [0, 0], height: 7, width: 10, rows: 8).isEmpty,
                "at lamp height 7 every cell is below the wall and is dropped")
        #expect(MoonlitMechanismTrain.cast(gears, phases: [5, 0], height: 0, width: 4, rows: 8) == [],
                "cells right of a narrow wall are dropped")
    }
}
