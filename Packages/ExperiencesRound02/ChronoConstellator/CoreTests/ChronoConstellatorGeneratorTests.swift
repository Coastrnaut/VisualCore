// ChronoConstellatorGeneratorTests — feature 352 (R02-G06-02) T-R02G0602-004 (FR-R02G0602-001, 005; clarifications Q1,
// Q3, Q5). Host checks of the generator: the band profiles and their clamping, the rectangle loop, determinism of
// candidates and of generation, the generated levels' shape (grid, star count, rectangle loops of width 2 … 5 and height
// 2 … 4, distinct targets, tick limit, budget, id, tutorial, difficulty), the solution's lower bound and blocked windows
// within the band, the witness timeline winning where the default timeline does not, skipped candidates re-checked as
// not qualifying, consistent difficulty fields and the refusal `.generation(n)` when no candidate can qualify. Sampled
// entries of every band; explicit types, plain loops; each test well under 10 s.
import Testing
import VisualCoreSimulation
@testable import ChronoConstellatorCore

@Suite struct ChronoConstellatorGeneratorTests {
    /// Two entries of every band.
    static let sampled: [ChronoConstellatorManifestEntry] = [1, 4, 21, 24, 41, 44, 61, 64, 81, 84].map {
        ChronoConstellatorManifest.entries[$0 - 1]
    }

    /// Whether candidate `index` of `entry` would be kept by the rules of clarification Q1.
    static func qualifies(_ entry: ChronoConstellatorManifestEntry, index: Int) -> Bool {
        let profile: ChronoConstellatorBandProfile = ChronoConstellatorBandProfile.of(band: entry.band)
        guard let level = ChronoConstellatorGenerator.candidate(entry, index: index),
              let solution = ChronoConstellatorSolver.solve(level) else { return false }
        guard profile.smallest.contains(solution.lowerBound), solution.blocked >= profile.blocked,
              solution.lowerBound <= level.budget else { return false }
        guard ChronoConstellatorGenerator.winTick(level, timeline: ChronoConstellatorTimeline(level: level)) == nil
        else { return false }
        guard let witness = ChronoConstellatorGenerator.timeline(level, solution: solution) else { return false }
        return ChronoConstellatorGenerator.winTick(level, timeline: witness) != nil
    }

    /// Whether `loop` is the perimeter of a `width` × `height` rectangle with width 2 … 5 and height 2 … 4 inside the
    /// grid, travelled clockwise from its top-left cell or exactly reversed.
    static func isRectangleLoop(_ loop: [Int], columns: Int, rows: Int) -> Bool {
        guard !loop.isEmpty else { return false }
        var minColumn: Int = Int.max
        var maxColumn: Int = Int.min
        var minRow: Int = Int.max
        var maxRow: Int = Int.min
        for cell in loop {
            minColumn = min(minColumn, cell % columns)
            maxColumn = max(maxColumn, cell % columns)
            minRow = min(minRow, cell / columns)
            maxRow = max(maxRow, cell / columns)
        }
        let width: Int = maxColumn - minColumn + 1
        let height: Int = maxRow - minRow + 1
        guard (2...5).contains(width), (2...4).contains(height), maxColumn < columns, maxRow < rows else { return false }
        let clockwise: [Int] = ChronoConstellatorGenerator.rectangle(column: minColumn, row: minRow, width: width,
                                                                     height: height, columns: columns)
        return loop == clockwise || loop == Array(clockwise.reversed())
    }

    @Test func bandProfilesFollowClarificationQ1AndClamp() {
        let expected: [ChronoConstellatorBandProfile] = [
            ChronoConstellatorBandProfile(columns: 6, rows: 5, stars: 2, smallest: 1...1, blocked: 0),
            ChronoConstellatorBandProfile(columns: 6, rows: 5, stars: 3, smallest: 2...2, blocked: 1),
            ChronoConstellatorBandProfile(columns: 7, rows: 6, stars: 3, smallest: 2...2, blocked: 2),
            ChronoConstellatorBandProfile(columns: 7, rows: 6, stars: 4, smallest: 3...3, blocked: 2),
            ChronoConstellatorBandProfile(columns: 8, rows: 7, stars: 5, smallest: 3...4, blocked: 3),
        ]
        for band in 1...5 { #expect(ChronoConstellatorBandProfile.of(band: band) == expected[band - 1]) }
        #expect(ChronoConstellatorBandProfile.of(band: 0) == expected[0])
        #expect(ChronoConstellatorBandProfile.of(band: -4) == expected[0])
        #expect(ChronoConstellatorBandProfile.of(band: 6) == expected[4])
        #expect(ChronoConstellatorBandProfile.of(band: 99) == expected[4])
        #expect(ChronoConstellatorGenerator.maxCandidates == 512)
        #expect(ChronoConstellatorGenerator.catalogID == "chrono-constellator")
    }

    @Test func rectangleIsAClosedFourNeighbourLoop() {
        let columns: Int = 8
        for width in 2...5 {
            for height in 2...4 {
                let loop: [Int] = ChronoConstellatorGenerator.rectangle(column: 1, row: 2, width: width, height: height,
                                                                        columns: columns)
                #expect(loop.count == 2 * (width + height) - 4)
                #expect(Set(loop).count == loop.count)
                #expect(loop[0] == 2 * columns + 1)
                for index in loop.indices {
                    let next: Int = loop[(index + 1) % loop.count]
                    #expect(ChronoConstellatorLevel.isNeighbour(loop[index], next, columns: columns))
                }
                #expect(Self.isRectangleLoop(loop, columns: columns, rows: 7))
            }
        }
        // The smallest loop, spelled out: clockwise round a 2 × 2 square.
        #expect(ChronoConstellatorGenerator.rectangle(column: 0, row: 0, width: 2, height: 2, columns: 6) == [0, 1, 7, 6])
    }

    @Test func candidatesAreDeterministic() {
        for entry in Self.sampled {
            var fingerprints: [String] = []
            for index in 0..<4 {
                let a: ChronoConstellatorLevel? = ChronoConstellatorGenerator.candidate(entry, index: index)
                let b: ChronoConstellatorLevel? = ChronoConstellatorGenerator.candidate(entry, index: index)
                #expect(a == b)
                if let a { fingerprints.append(a.fingerprint) }
            }
            // Different candidate indices draw different levels.
            #expect(Set(fingerprints).count == fingerprints.count)
        }
    }

    @Test func generationIsDeterministic() throws {
        for entry in [Self.sampled[0], Self.sampled[4], Self.sampled[8]] {
            let a: ChronoConstellatorGenerated = try ChronoConstellatorGenerator.generate(entry)
            let b: ChronoConstellatorGenerated = try ChronoConstellatorGenerator.generate(entry)
            #expect(a == b)
            #expect(a.level.fingerprint == b.level.fingerprint)
        }
    }

    @Test func generatedLevelsHaveTheBandShape() throws {
        for entry in Self.sampled {
            let generated: ChronoConstellatorGenerated = try ChronoConstellatorGenerator.generate(entry)
            let level: ChronoConstellatorLevel = generated.level
            let profile: ChronoConstellatorBandProfile = ChronoConstellatorBandProfile.of(band: entry.band)
            #expect(generated.entry == entry)
            #expect(level.columns == profile.columns)
            #expect(level.rows == profile.rows)
            #expect(level.stars.count == profile.stars)
            var targets: [Int] = []
            for star in level.stars {
                #expect(Self.isRectangleLoop(star.loop, columns: level.columns, rows: level.rows))
                #expect(star.loop.contains(star.target))
                #expect((0..<star.length).contains(star.phase))
                targets.append(star.target)
            }
            #expect(Set(targets).count == targets.count)
            #expect((120...360).contains(level.tickLimit))
            #expect(level.budget == entry.budget)
            #expect(level.seed == entry.seed)
            let number: String = String(String(entry.number + 1_000).dropFirst())
            #expect(level.id == "chrono-constellator-" + number)
            #expect(level.tutorial == (1...3).contains(entry.number))
            #expect(level.difficulty == entry.band)
        }
        // Levels 1 … 3 are the tutorial levels; the first entry is formatted with three digits.
        let first: ChronoConstellatorGenerated = try ChronoConstellatorGenerator.generate(
            ChronoConstellatorManifest.entries[0])
        #expect(first.level.id == "chrono-constellator-001")
        #expect(first.level.tutorial)
    }

    @Test func solutionsMeetTheBandAndTheWitnessWins() throws {
        for entry in Self.sampled {
            let generated: ChronoConstellatorGenerated = try ChronoConstellatorGenerator.generate(entry)
            let level: ChronoConstellatorLevel = generated.level
            let solution: ChronoConstellatorSolution = generated.solution
            let profile: ChronoConstellatorBandProfile = ChronoConstellatorBandProfile.of(band: entry.band)
            #expect(profile.smallest.contains(solution.lowerBound))
            #expect(solution.blocked >= profile.blocked)
            #expect(solution.lowerBound <= level.budget)
            #expect(ChronoConstellatorSolver.solve(level) == solution)
            let unedited: ChronoConstellatorTimeline = ChronoConstellatorTimeline(level: level)
            #expect(ChronoConstellatorGenerator.winTick(level, timeline: unedited) == nil)
            let witness: ChronoConstellatorTimeline? = ChronoConstellatorGenerator.timeline(level, solution: solution)
            #expect(witness != nil)
            guard let witness else { continue }
            #expect(witness.phases == solution.phases)
            #expect(witness.holds.isEmpty)
            #expect(witness.editsInUse(level: level) == solution.lowerBound)
            let win: Int? = ChronoConstellatorGenerator.winTick(level, timeline: witness)
            #expect(win != nil)
            if let win { #expect(win <= solution.window) }
        }
    }

    @Test func skippedCandidatesTrulyFail() throws {
        for entry in Self.sampled {
            let generated: ChronoConstellatorGenerated = try ChronoConstellatorGenerator.generate(entry)
            #expect((0..<ChronoConstellatorGenerator.maxCandidates).contains(generated.skipped))
            #expect(ChronoConstellatorGenerator.candidate(entry, index: generated.skipped) == generated.level)
            #expect(Self.qualifies(entry, index: generated.skipped))
            for index in 0..<generated.skipped { #expect(!Self.qualifies(entry, index: index)) }
        }
    }

    @Test func difficultyFieldsAreConsistent() throws {
        for entry in Self.sampled {
            let generated: ChronoConstellatorGenerated = try ChronoConstellatorGenerator.generate(entry)
            let level: ChronoConstellatorLevel = generated.level
            let difficulty: ChronoConstellatorDifficulty = generated.difficulty
            #expect(difficulty.smallest == generated.solution.lowerBound)
            #expect(difficulty.stars == level.stars.count)
            var lengths: [Int] = []
            for star in level.stars { lengths.append(star.length) }
            #expect(difficulty.loopLengths == lengths)
            #expect(difficulty.windows == generated.solution.windows)
            #expect(difficulty.blocked == generated.solution.blocked)
            #expect(difficulty.blocked <= difficulty.windows)
            let witness: ChronoConstellatorTimeline? = ChronoConstellatorGenerator.timeline(level,
                                                                                            solution: generated.solution)
            #expect(witness != nil)
            if let witness { #expect(ChronoConstellatorGenerator.winTick(level, timeline: witness) == difficulty.winTick) }
        }
    }

    @Test func anEntryThatCannotQualifyIsRefused() {
        // Band 4 needs a smallest edit count of exactly 3, and a kept candidate needs its lower bound within the budget:
        // with a budget of 2 no candidate can qualify, so all 512 are tried and the entry is refused.
        let tight: ChronoConstellatorManifestEntry = ChronoConstellatorManifestEntry(number: 61, seed: 0x6633915ce090c55f,
                                                                                    band: 4, budget: 2)
        #expect(throws: ChronoConstellatorError.generation(61)) { try ChronoConstellatorGenerator.generate(tight) }
        // A budget of 0 is outside the level's budget range, so every candidate is refused by the level itself.
        let empty: ChronoConstellatorManifestEntry = ChronoConstellatorManifestEntry(number: 7, seed: 0xc23ae388700b29c7,
                                                                                    band: 1, budget: 0)
        #expect(ChronoConstellatorGenerator.candidate(empty, index: 0) == nil)
        #expect(throws: ChronoConstellatorError.generation(7)) { try ChronoConstellatorGenerator.generate(empty) }
        #expect(ChronoConstellatorError.generation(7).reasonCode == "r02-g06.generation")
    }
}
