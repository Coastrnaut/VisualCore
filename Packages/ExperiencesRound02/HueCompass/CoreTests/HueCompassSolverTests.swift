// HueCompassSolverTests — feature 332 (R02-G04-02) T-R02G0402-003 (FR-R02G0402-002; SC-R02G0402-002; clarifications
// Q2, Q4). Host checks of the deduction solver: candidates, classes and the smallest selection on hand-made levels;
// hand-made levels that need one probe, two probes and more than two (nil); the smallest count, work and best single
// equal an independent brute force on 40 seeded random levels; the settling set is sound (every class has a selection
// the level accepts for every member); the ambiguity's targets share every clue and have no common selection; the
// work is bounded by 1 + 96 + 4,560 = 4,657; results are deterministic. No level needs zero probes: with a bearing
// tolerance of at most 4 the candidates (at least 87 of 96 bearings) never lie within the tolerance of one bearing, so
// zero is asserted never to occur instead of being constructed. Seed 2_332. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import HueCompassCore

@Suite struct HueCompassSolverTests {
    /// The test seed.
    static let seed: UInt64 = 2_332

    static func level(fog: [Int], offset: Int = 0, target: Int = 30, start: Int = 60, bearingTolerance: Int = 2,
                      bandTolerance: Int = 0, id: String = "solver") throws -> HueCompassLevel {
        try HueCompassLevel(id: id, seed: seed, band: 1, offset: offset, fog: fog, target: target, start: start,
                            bearingTolerance: bearingTolerance, bandTolerance: bandTolerance, allowance: 8)
    }

    /// Fog 1 on bearings 1 … 47 (the counter-clockwise half from bearing 0), clear elsewhere.
    static var halfFog: [Int] {
        var fog: [Int] = Array(repeating: 0, count: 96)
        for b in 1...47 { fog[b] = 1 }
        return fog
    }

    /// Random level `index`, tolerances and clear share cycling through the five band profiles.
    static func randomLevel(_ index: Int) throws -> HueCompassLevel {
        let profiles: [(bearing: Int, band: Int, clear: Int)] = [(4, 2, 0), (3, 1, 10), (2, 1, 20), (1, 0, 30), (1, 0, 40)]
        let profile: (bearing: Int, band: Int, clear: Int) = profiles[index % profiles.count]
        var random = HueCompassRandom(seed: seed &+ UInt64(index) &* 7_919)
        let offset: Int = random.int(0...23)
        var fog: [Int] = []
        for _ in 0..<96 { fog.append(random.int(0...99) < profile.clear ? 0 : random.int(1...9)) }
        let target: Int = random.int(0...95)
        var start: Int = random.int(0...95)
        while HueCompassWheel.bearingDistance(start, target) <= profile.bearing { start = random.int(0...95) }
        return try level(fog: fog, offset: offset, target: target, start: start, bearingTolerance: profile.bearing,
                         bandTolerance: profile.band, id: "random-\(index)")
    }

    // MARK: - Independent brute force

    /// The clue (hue gap, depth) at `probe` if the target were `t`, computed directly from the wheel.
    static func bruteClue(_ level: HueCompassLevel, probe: Int, target t: Int) -> [Int] {
        var depth: Int = 0
        for inside in HueCompassWheel.arc(from: probe, to: t) { depth += level.fog[inside] }
        return [HueCompassWheel.bandDistance(level.band(of: probe), level.band(of: t)), depth]
    }

    /// Whether some bearing and some band accept every member.
    static func bruteAcceptable(_ level: HueCompassLevel, _ members: [Int]) -> Bool {
        var bearingFound: Bool = false
        for b in 0..<96 {
            var all: Bool = true
            for t in members where HueCompassWheel.bearingDistance(b, t) > level.bearingTolerance { all = false }
            if all { bearingFound = true }
        }
        var bandFound: Bool = false
        for band in 0..<24 {
            var all: Bool = true
            for t in members where HueCompassWheel.bandDistance(band, level.band(of: t)) > level.bandTolerance {
                all = false
            }
            if all { bandFound = true }
        }
        return bearingFound && bandFound
    }

    /// The brute-force first settling set (sets in solver order) and its 1-based index, or nil within depth 2.
    static func bruteSolve(_ level: HueCompassLevel) -> (probes: [Int], work: Int)? {
        var candidates: [Int] = []
        for b in 0..<96 where HueCompassWheel.bearingDistance(b, level.start) > level.bearingTolerance {
            candidates.append(b)
        }
        var clues: [[[Int]]] = []
        for probe in 0..<96 {
            var row: [[Int]] = []
            for t in 0..<96 { row.append(bruteClue(level, probe: probe, target: t)) }
            clues.append(row)
        }
        var sets: [[Int]] = [[]]
        for a in 0..<96 { sets.append([a]) }
        for a in 0..<96 {
            for b in (a + 1)..<96 { sets.append([a, b]) }
        }
        var index: Int = 0
        for set in sets {
            index += 1
            var groups: [[Int]: [Int]] = [:]
            for t in candidates {
                var key: [Int] = []
                for probe in set { key.append(contentsOf: clues[probe][t]) }
                groups[key, default: []].append(t)
            }
            var settles: Bool = true
            for (_, members) in groups where !bruteAcceptable(level, members) {
                settles = false
                break
            }
            if settles { return (set, index) }
        }
        return nil
    }

    // MARK: - Tests

    @Test func candidatesExcludeTheBearingsWithinTheToleranceOfTheStart() throws {
        let level: HueCompassLevel = try Self.level(fog: Self.halfFog, start: 60, bearingTolerance: 2)
        let candidates: [Int] = HueCompassSolver.candidates(level)
        #expect(candidates.count == 91)
        for b in 58...62 { #expect(!candidates.contains(b)) }
        #expect(candidates.contains(57) && candidates.contains(63))
        #expect(candidates == candidates.sorted())
        let wrap: HueCompassLevel = try Self.level(fog: Self.halfFog, target: 50, start: 1, bearingTolerance: 4)
        let wrapped: [Int] = HueCompassSolver.candidates(wrap)
        #expect(wrapped.count == 87 && wrapped.first == 6 && wrapped.last == 92)
    }

    @Test func theClueTableMatchesTheLevelsClues() throws {
        for index in 0..<10 {
            let level: HueCompassLevel = try Self.randomLevel(index)
            let table: [[Int]] = HueCompassSolver.clueTable(level)
            for probe in 0..<96 {
                let clue: HueCompassClue = level.clue(at: probe)
                #expect(table[probe][level.target] == clue.hueGap * 512 + clue.depth)
                for t in 0..<96 {
                    let brute: [Int] = Self.bruteClue(level, probe: probe, target: t)
                    #expect(table[probe][t] == brute[0] * 512 + brute[1])
                }
            }
        }
    }

    @Test func classesAreOrderedAndPartitionTheCandidates() throws {
        let level: HueCompassLevel = try Self.randomLevel(3)
        let empty: [[Int]] = HueCompassSolver.classes(level, probes: [])
        #expect(empty == [HueCompassSolver.candidates(level)])
        let probeSets: [[Int]] = [[0], [17], [5, 80], [40, 41]]
        for probes in probeSets {
            let classes: [[Int]] = HueCompassSolver.classes(level, probes: probes)
            var all: [Int] = []
            for c in classes {
                #expect(!c.isEmpty && c == c.sorted())
                all.append(contentsOf: c)
                for t in c {
                    for probe in probes {
                        #expect(Self.bruteClue(level, probe: probe, target: t)
                                == Self.bruteClue(level, probe: probe, target: c[0]))
                    }
                }
            }
            #expect(all.sorted() == HueCompassSolver.candidates(level))
            for i in 1..<classes.count { #expect(classes[i - 1][0] < classes[i][0]) }
        }
    }

    @Test func theSmallestSelection() throws {
        let level: HueCompassLevel = try Self.level(fog: Self.halfFog, bearingTolerance: 2, bandTolerance: 0)
        #expect(HueCompassSolver.selection(for: [0, 1], in: level) == HueCompassSelection(bearing: 0, band: 0))
        #expect(HueCompassSolver.selection(for: [0, 3], in: level) == HueCompassSelection(bearing: 1, band: 0))
        #expect(HueCompassSolver.selection(for: [0, 4], in: level) == nil)
        #expect(HueCompassSolver.selection(for: [0, 5], in: level) == nil)
        #expect(HueCompassSolver.selection(for: [94, 1], in: level) == nil)
        #expect(HueCompassSolver.selection(for: [93, 94], in: level) == HueCompassSelection(bearing: 92, band: 23))
        let loose: HueCompassLevel = try Self.level(fog: Self.halfFog, bearingTolerance: 4, bandTolerance: 2)
        #expect(HueCompassSolver.selection(for: [94, 2], in: loose) == HueCompassSelection(bearing: 0, band: 0))
        #expect(HueCompassSolver.selection(for: [95, 4], in: loose) == HueCompassSelection(bearing: 0, band: 0))
        #expect(HueCompassSolver.selection(for: [20], in: loose) == HueCompassSelection(bearing: 16, band: 3))
    }

    @Test func aHandMadeLevelNeedsOneProbe() throws {
        // Probe 0 reads distinct depths across the fogged half and one hue gap per band across the clear half.
        let level: HueCompassLevel = try Self.level(fog: Self.halfFog, bearingTolerance: 2, bandTolerance: 0)
        let solution: HueCompassSolution = try #require(HueCompassSolver.solve(level))
        #expect(solution.probes == [0] && solution.smallest == 1 && solution.work == 2)
        #expect(solution.ambiguity == HueCompassAmbiguity(probes: [], targets: [0, 4]))
        let brute: (probes: [Int], work: Int)? = Self.bruteSolve(level)
        #expect(brute?.probes == [0] && brute?.work == 2)
        #expect(HueCompassSolver.solve(level, depth: 0) == nil)
    }

    @Test func aHandMadeLevelNeedsTwoProbes() throws {
        // Clear fog: one probe reads only a hue gap (two bands); two probes in different bands fix the band.
        let level: HueCompassLevel = try Self.level(fog: Array(repeating: 0, count: 96), target: 30, start: 50,
                                                    bearingTolerance: 2, bandTolerance: 0)
        let solution: HueCompassSolution = try #require(HueCompassSolver.solve(level))
        #expect(solution.probes == [0, 4] && solution.smallest == 2 && solution.work == 1 + 96 + 4)
        #expect(solution.bestSingle == 0 && solution.largestAfterBestSingle == 8)
        #expect(solution.ambiguity == HueCompassAmbiguity(probes: [0], targets: [4, 92]))
        #expect(HueCompassSolver.solve(level, depth: 1) == nil)
        let brute: (probes: [Int], work: Int)? = Self.bruteSolve(level)
        #expect(brute?.probes == [0, 4] && brute?.work == 101)
    }

    @Test func aHandMadeLevelNeedsMoreThanTwoProbes() throws {
        // Clear fog with a bearing tolerance of 1: a band's four bearings never share a selection.
        let level: HueCompassLevel = try Self.level(fog: Array(repeating: 0, count: 96), target: 30, start: 50,
                                                    bearingTolerance: 1, bandTolerance: 0)
        #expect(HueCompassSolver.solve(level) == nil)
        #expect(Self.bruteSolve(level) == nil)
    }

    @Test func theSolverEqualsTheBruteForceOnSeededLevels() throws {
        var counts: [Int] = [0, 0, 0, 0]
        for index in 0..<40 {
            let level: HueCompassLevel = try Self.randomLevel(index)
            let solution: HueCompassSolution? = HueCompassSolver.solve(level)
            let brute: (probes: [Int], work: Int)? = Self.bruteSolve(level)
            #expect(solution?.probes == brute?.probes, "level \(index)")
            #expect(solution?.work == brute?.work, "level \(index)")
            counts[solution?.smallest ?? 3] += 1
            guard let solution else { continue }
            #expect(solution.smallest >= 1, "no level needs zero probes")
            #expect(solution.work <= 4_657)
            // The best single: the smallest largest class over all 96 singles, lowest bearing on a tie.
            var best: Int = 0
            var bestLargest: Int = Int.max
            for a in 0..<96 {
                var groups: [[Int]: Int] = [:]
                for t in HueCompassSolver.candidates(level) {
                    groups[Self.bruteClue(level, probe: a, target: t), default: 0] += 1
                }
                var largest: Int = 0
                for (_, size) in groups where size > largest { largest = size }
                if largest < bestLargest {
                    bestLargest = largest
                    best = a
                }
            }
            #expect(solution.bestSingle == best && solution.largestAfterBestSingle == bestLargest, "level \(index)")
        }
        #expect(counts[0] == 0)
        #expect(counts[1] > 0 && counts[2] > 0)
    }

    @Test func theSettlingSetIsSoundAndTheAmbiguityIsReal() throws {
        for index in 0..<40 {
            let level: HueCompassLevel = try Self.randomLevel(index)
            guard let solution = HueCompassSolver.solve(level) else { continue }
            for c in HueCompassSolver.classes(level, probes: solution.probes) {
                let selection: HueCompassSelection = try #require(HueCompassSolver.selection(for: c, in: level))
                for t in c {
                    #expect(HueCompassWheel.bearingDistance(selection.bearing, t) <= level.bearingTolerance)
                    #expect(HueCompassWheel.bandDistance(selection.band, level.band(of: t)) <= level.bandTolerance)
                }
            }
            // The true target's class selection is accepted by the level itself.
            for c in HueCompassSolver.classes(level, probes: solution.probes) where c.contains(level.target) {
                let selection: HueCompassSelection = try #require(HueCompassSolver.selection(for: c, in: level))
                #expect(level.accepts(bearing: selection.bearing, band: selection.band))
            }
            let ambiguity: HueCompassAmbiguity = try #require(solution.ambiguity, "level \(index)")
            #expect(ambiguity.probes == (solution.smallest == 1 ? [] : [0]))
            #expect(ambiguity.targets.count == 2 && ambiguity.targets[0] < ambiguity.targets[1])
            let candidates: [Int] = HueCompassSolver.candidates(level)
            #expect(candidates.contains(ambiguity.targets[0]) && candidates.contains(ambiguity.targets[1]))
            for probe in ambiguity.probes {
                #expect(Self.bruteClue(level, probe: probe, target: ambiguity.targets[0])
                        == Self.bruteClue(level, probe: probe, target: ambiguity.targets[1]))
            }
            #expect(HueCompassSolver.selection(for: ambiguity.targets, in: level) == nil)
        }
    }

    @Test func theSolverIsDeterministic() throws {
        for index in 0..<10 {
            let level: HueCompassLevel = try Self.randomLevel(index)
            #expect(HueCompassSolver.solve(level) == HueCompassSolver.solve(level))
            #expect(HueCompassSolver.classes(level, probes: [3, 9]) == HueCompassSolver.classes(level, probes: [3, 9]))
        }
    }
}
