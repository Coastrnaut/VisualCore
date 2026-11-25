// ApsidesWorkshopGeneratorTests — feature 472 (R02-G18-02) T-R02G1802-004 (FR-R02G1802-001, 005, 007;
// SC-R02G1802-001, 003, 004; clarification Q1). Host checks of the constructive level generator: the five band profiles
// exactly as data-model.md writes them and the clamp of other bands to band 5's; the level ids; candidate and
// generation determinism; the drawing order of clarification Q1 re-drawn independently here from
// `SeededRandom(seed: SeedDerivation.derive(seed, index: c))` (the period, the winning orbit, the target count and the
// apsis-target count) on sampled candidates of every band; every candidate of the first indices of every band against
// its band and the kernel ranges (period, target and apsis counts, share bands and distance ranges with their widths,
// planets, radii, centres clear of the star); the targets taken from the winning orbit's shares and apsides with a
// drawn half-width, ordered by event tick; the planets clear of the winning orbit; the levers moved from the winning
// orbit; the filters of `generate` (`skipped` is the first candidate with a certified plan in the band's range and
// within the budget); the neighbour rule (FR-R02G1802-007); and the candidate bound with its refusal. The refusal
// `.generation(number)` cannot be provoked from the real manifest (every entry yields a level well inside the bound and
// a band profile cannot be replaced from outside), so its bound and its stable reason code are checked instead.
// Tutorial on levels 1 … 3 and difficulty = band. Only a few entries are generated here, so every test stays short.
// Explicit types and plain loops keep the type checker fast on CI.
import Foundation
import Testing
import VisualCoreSimulation
@testable import ApsidesWorkshopCore

@Suite("ApsidesWorkshopGenerator")
struct ApsidesWorkshopGeneratorTests {
    /// The manifest numbers sampled for the independent re-draw: three per band.
    static let redrawNumbers: [Int] = [1, 3, 8, 21, 27, 36, 41, 50, 59, 61, 70, 79, 81, 90, 100]

    /// The candidate indices re-drawn per sampled entry.
    static let redrawIndices: [Int] = [0, 1, 4, 9, 17]

    /// The first manifest number of every band (20 entries per band).
    static let bandFirsts: [Int] = [1, 21, 41, 61, 81]

    /// The candidate indices checked against their band per sampled entry.
    static let rangeIndices: Range<Int> = 0..<24

    /// The manifest numbers generated here (two per band).
    static let generateNumbers: [Int] = [1, 4, 21, 30, 41, 55, 61, 77, 81, 99]

    /// The band profiles exactly as data-model.md writes them.
    static let documented: [ApsidesWorkshopBandProfile] = [
        ApsidesWorkshopBandProfile(periods: [24], targets: 1...2, apsisTargets: 0...0, sweepHalfWidth: 60...90,
                                   apsisHalfWidth: 40...60, planets: 0...0, levers: 1...1, planRange: 1...1),
        ApsidesWorkshopBandProfile(periods: [24, 32], targets: 2...2, apsisTargets: 0...1, sweepHalfWidth: 45...70,
                                   apsisHalfWidth: 40...60, planets: 0...1, levers: 1...1, planRange: 1...1),
        ApsidesWorkshopBandProfile(periods: [32], targets: 2...3, apsisTargets: 1...1, sweepHalfWidth: 35...55,
                                   apsisHalfWidth: 25...45, planets: 1...1, levers: 1...2, planRange: 1...2),
        ApsidesWorkshopBandProfile(periods: [32, 48], targets: 3...3, apsisTargets: 1...1, sweepHalfWidth: 25...40,
                                   apsisHalfWidth: 20...35, planets: 1...2, levers: 2...2, planRange: 2...2),
        ApsidesWorkshopBandProfile(periods: [48], targets: 3...4, apsisTargets: 1...2, sweepHalfWidth: 18...30,
                                   apsisHalfWidth: 15...25, planets: 2...3, levers: 2...2, planRange: 2...2),
    ]

    /// The manifest entry numbered `number`.
    static func entry(_ number: Int) -> ApsidesWorkshopManifestEntry {
        ApsidesWorkshopManifest.entries[number - 1]
    }

    /// The first draws of candidate `index` of `entry`, re-drawn here in the order of clarification Q1.
    struct FirstDraws: Equatable {
        let period: Int
        let winning: ApsidesWorkshopOrbit
        let count: Int
        let apsides: Int
    }

    /// The period, winning orbit, target count and apsis-target count re-drawn independently.
    static func firstDraws(_ entry: ApsidesWorkshopManifestEntry, index: Int) -> FirstDraws {
        let profile: ApsidesWorkshopBandProfile = documented[min(max(entry.band, 1), 5) - 1]
        var random: SeededRandom = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        let period: Int = profile.periods[random.int(0...(profile.periods.count - 1))]
        var winning: ApsidesWorkshopOrbit = ApsidesWorkshopOrbit(size: 0, eccentricity: 0, direction: 0)
        var found: Bool = false
        while !found {
            let size: Int = random.int(8...48)
            let eccentricity: Int = random.int(0...15)
            let direction: Int = random.int(0...23)
            let periapsis: Int = size * (20 - eccentricity)
            let apoapsis: Int = size * (20 + eccentricity)
            if periapsis >= 60 && apoapsis <= 1280 {
                winning = ApsidesWorkshopOrbit(size: size, eccentricity: eccentricity, direction: direction)
                found = true
            }
        }
        let count: Int = random.int(profile.targets)
        let apsides: Int = min(random.int(profile.apsisTargets), count)
        return FirstDraws(period: period, winning: winning, count: count, apsides: apsides)
    }

    /// Whether `low … high` is `value` ± one half-width from `widths`, clipped to `bounds`.
    static func isBand(low: Int, high: Int, value: Int, widths: ClosedRange<Int>, bounds: ClosedRange<Int>) -> Bool {
        for half in widths {
            let expectedLow: Int = max(bounds.lowerBound, value - half)
            let expectedHigh: Int = min(bounds.upperBound, value + half)
            if low == expectedLow && high == expectedHigh { return true }
        }
        return false
    }

    /// The levers in which `start` differs from `winning`: the size and the knob (eccentricity with direction).
    static func leversMoved(_ start: ApsidesWorkshopOrbit, from winning: ApsidesWorkshopOrbit) -> Int {
        var moved: Int = 0
        if start.size != winning.size { moved += 1 }
        if start.eccentricity != winning.eccentricity || start.direction != winning.direction { moved += 1 }
        return moved
    }

    // MARK: - Band profiles and ids

    @Test("the band profiles are exactly data-model.md's and other bands take band 5's")
    func bandProfiles() {
        for band in 1...5 {
            #expect(ApsidesWorkshopBandProfile.of(band: band) == Self.documented[band - 1], "band \(band)")
        }
        #expect(ApsidesWorkshopBandProfile.of(band: 0) == Self.documented[4])
        #expect(ApsidesWorkshopBandProfile.of(band: 6) == Self.documented[4])
        for profile in Self.documented {
            #expect(profile.apsisTargets.upperBound <= profile.targets.upperBound)
            #expect(profile.levers.lowerBound >= 1 && profile.levers.upperBound <= 2)
            for period in profile.periods {
                #expect(ApsidesWorkshopLevel.periods.contains(period))
            }
        }
    }

    @Test("level ids are apsides-workshop-NNN and the catalog constants are fixed")
    func levelIDsAndConstants() {
        #expect(ApsidesWorkshopGenerator.levelID(1) == "apsides-workshop-001")
        #expect(ApsidesWorkshopGenerator.levelID(7) == "apsides-workshop-007")
        #expect(ApsidesWorkshopGenerator.levelID(42) == "apsides-workshop-042")
        #expect(ApsidesWorkshopGenerator.levelID(100) == "apsides-workshop-100")
        #expect(ApsidesWorkshopGenerator.catalogID == "apsides-workshop")
        #expect(ApsidesWorkshopGenerator.maxCandidates == 256)
        #expect(ApsidesWorkshopGenerator.planetTries == 60)
    }

    // MARK: - Determinism and drawing order

    @Test("the same entry and index give the identical candidate, and generate is deterministic")
    func determinism() throws {
        for number in Self.redrawNumbers {
            let entry: ApsidesWorkshopManifestEntry = Self.entry(number)
            for index in Self.redrawIndices {
                let first: ApsidesWorkshopLevel? = ApsidesWorkshopGenerator.candidate(entry, index: index)
                let second: ApsidesWorkshopLevel? = ApsidesWorkshopGenerator.candidate(entry, index: index)
                #expect(first == second, "entry \(number) candidate \(index)")
                #expect(first?.fingerprint == second?.fingerprint)
            }
        }
        for number in [1, 41, 81] {
            let entry: ApsidesWorkshopManifestEntry = Self.entry(number)
            let first: ApsidesWorkshopGenerated = try ApsidesWorkshopGenerator.generate(entry, previous: nil)
            let second: ApsidesWorkshopGenerated = try ApsidesWorkshopGenerator.generate(entry, previous: nil)
            #expect(first == second, "entry \(number)")
        }
    }

    @Test("an independent re-draw reproduces the period, winning orbit and target counts of clarification Q1")
    func drawingOrder() {
        var compared: Int = 0
        for number in Self.redrawNumbers {
            let entry: ApsidesWorkshopManifestEntry = Self.entry(number)
            for index in Self.redrawIndices {
                let expected: FirstDraws = Self.firstDraws(entry, index: index)
                guard let drawn = ApsidesWorkshopGenerator.draw(entry, index: index) else { continue }
                compared += 1
                let level: ApsidesWorkshopLevel = drawn.level
                #expect(drawn.winning == expected.winning, "entry \(number) candidate \(index)")
                #expect(level.period == expected.period, "entry \(number) candidate \(index)")
                var apsisCount: Int = 0
                for target in level.targets where target.kind != .sweep { apsisCount += 1 }
                #expect(apsisCount == expected.apsides, "entry \(number) candidate \(index)")
                let points: [ApsidesWorkshopPoint] = ApsidesWorkshopSky.positions(expected.winning,
                                                                                  period: expected.period).points
                let shares: [Int] = ApsidesWorkshopSky.shares(points)
                var visited: Int = 0
                for share in shares where share > 0 { visited += 1 }
                let sweeps: Int = min(expected.count - expected.apsides, visited)
                #expect(level.targets.count - apsisCount == sweeps, "entry \(number) candidate \(index)")
            }
        }
        #expect(compared >= Self.redrawNumbers.count, "too few candidates gave a level: \(compared)")
    }

    // MARK: - Candidates against their band and the kernel

    @Test("every candidate of the first indices of every band lies in its band and the kernel ranges")
    func candidateRanges() {
        for first in Self.bandFirsts {
            for number in [first, first + 7, first + 19] {
                let entry: ApsidesWorkshopManifestEntry = Self.entry(number)
                let profile: ApsidesWorkshopBandProfile = Self.documented[entry.band - 1]
                var levels: Int = 0
                for index in Self.rangeIndices {
                    guard let drawn = ApsidesWorkshopGenerator.draw(entry, index: index) else { continue }
                    levels += 1
                    let level: ApsidesWorkshopLevel = drawn.level
                    let tag: String = "entry \(number) candidate \(index)"
                    #expect(drawn.winning.isValid, "\(tag)")
                    #expect(level.orbit.isValid, "\(tag)")
                    #expect(profile.periods.contains(level.period), "\(tag)")
                    #expect(level.targets.count >= 1 && level.targets.count <= profile.targets.upperBound, "\(tag)")
                    var apsisCount: Int = 0
                    for target in level.targets {
                        if target.kind == .sweep {
                            #expect(ApsidesWorkshopLevel.shareBounds.contains(target.low), "\(tag)")
                            #expect(ApsidesWorkshopLevel.shareBounds.contains(target.high), "\(tag)")
                            #expect(target.low <= target.high, "\(tag)")
                            #expect(target.high - target.low <= 2 * profile.sweepHalfWidth.upperBound, "\(tag)")
                        } else {
                            apsisCount += 1
                            #expect(ApsidesWorkshopLevel.distanceBounds.contains(target.low), "\(tag)")
                            #expect(ApsidesWorkshopLevel.distanceBounds.contains(target.high), "\(tag)")
                            #expect(target.low <= target.high, "\(tag)")
                            #expect(target.high - target.low <= 2 * profile.apsisHalfWidth.upperBound, "\(tag)")
                        }
                        #expect(target.sector >= 0 && target.sector < ApsidesWorkshopSky.sectorCount, "\(tag)")
                    }
                    #expect(apsisCount <= profile.apsisTargets.upperBound, "\(tag)")
                    #expect(profile.planets.contains(level.planets.count), "\(tag)")
                    for planet in level.planets {
                        #expect((1...3).contains(planet.radius), "\(tag)")
                        #expect(ApsidesWorkshopLevel.coordinates.contains(planet.x), "\(tag)")
                        #expect(ApsidesWorkshopLevel.coordinates.contains(planet.y), "\(tag)")
                        let reach: Int = planet.radius + ApsidesWorkshopSky.starRadius
                        #expect(planet.x * planet.x + planet.y * planet.y > reach * reach, "\(tag)")
                    }
                    #expect(level.budget == entry.budget, "\(tag)")
                    #expect(level.seed == entry.seed, "\(tag)")
                    #expect(level.difficulty == entry.band, "\(tag)")
                    #expect(level.id == ApsidesWorkshopGenerator.levelID(number), "\(tag)")
                    #expect(level.tutorial == (number <= 3), "\(tag)")
                }
                #expect(levels > 0, "entry \(number) gave no candidate level in its first indices")
            }
        }
    }

    @Test("targets are the winning orbit's shares and apsides with a drawn half-width, ordered by event tick")
    func targetsFromWinningOrbit() {
        for first in Self.bandFirsts {
            for number in [first, first + 11] {
                let entry: ApsidesWorkshopManifestEntry = Self.entry(number)
                let profile: ApsidesWorkshopBandProfile = Self.documented[entry.band - 1]
                for index in Self.rangeIndices {
                    guard let drawn = ApsidesWorkshopGenerator.draw(entry, index: index) else { continue }
                    let level: ApsidesWorkshopLevel = drawn.level
                    let winning: ApsidesWorkshopOrbit = drawn.winning
                    let tag: String = "entry \(number) candidate \(index)"
                    let points: [ApsidesWorkshopPoint] = ApsidesWorkshopSky.positions(winning,
                                                                                      period: level.period).points
                    let shares: [Int] = ApsidesWorkshopSky.shares(points)
                    var sweepSectors: [Int] = []
                    var kinds: [ApsidesWorkshopTargetKind] = []
                    var previousTick: Int = Int.min
                    for target in level.targets {
                        switch target.kind {
                        case .sweep:
                            #expect(shares[target.sector] > 0, "\(tag)")
                            #expect(!sweepSectors.contains(target.sector), "\(tag)")
                            sweepSectors.append(target.sector)
                            #expect(Self.isBand(low: target.low, high: target.high, value: shares[target.sector],
                                                widths: profile.sweepHalfWidth,
                                                bounds: ApsidesWorkshopLevel.shareBounds), "\(tag)")
                        case .periapsis:
                            kinds.append(.periapsis)
                            #expect(target.sector == winning.periapsisSector, "\(tag)")
                            #expect(Self.isBand(low: target.low, high: target.high, value: winning.periapsisDistance,
                                                widths: profile.apsisHalfWidth,
                                                bounds: ApsidesWorkshopLevel.distanceBounds), "\(tag)")
                        case .apoapsis:
                            kinds.append(.apoapsis)
                            #expect(target.sector == winning.apoapsisSector, "\(tag)")
                            #expect(Self.isBand(low: target.low, high: target.high, value: winning.apoapsisDistance,
                                                widths: profile.apsisHalfWidth,
                                                bounds: ApsidesWorkshopLevel.distanceBounds), "\(tag)")
                        }
                        let tick: Int = ApsidesWorkshopSky.eventTick(target, points: points, period: level.period)
                        #expect(tick >= previousTick, "\(tag): targets not ordered by event tick")
                        previousTick = tick
                    }
                    if kinds.count == 2 {
                        #expect(kinds.contains(.periapsis) && kinds.contains(.apoapsis), "\(tag)")
                    }
                    #expect(ApsidesWorkshopSolver.wins(level, orbit: winning), "\(tag): the winning orbit loses")
                }
            }
        }
    }

    @Test("planets are not struck by the winning orbit")
    func planetsClearOfWinningOrbit() {
        var planetsSeen: Int = 0
        for first in [21, 41, 61, 81] {
            for number in [first, first + 9] {
                let entry: ApsidesWorkshopManifestEntry = Self.entry(number)
                for index in Self.rangeIndices {
                    guard let drawn = ApsidesWorkshopGenerator.draw(entry, index: index) else { continue }
                    let level: ApsidesWorkshopLevel = drawn.level
                    let points: [ApsidesWorkshopPoint] = ApsidesWorkshopSky.positions(drawn.winning,
                                                                                      period: level.period).points
                    for planet in level.planets {
                        planetsSeen += 1
                        for i in 0..<level.period {
                            let struck: Bool = ApsidesWorkshopSky.touches(planet, from: points[i],
                                                                          to: points[(i + 1) % level.period])
                            #expect(!struck, "entry \(number) candidate \(index) segment \(i)")
                        }
                    }
                }
            }
        }
        #expect(planetsSeen > 0)
    }

    @Test("the starting orbit differs from the winning one in at most its band's levers and does not win")
    func leversMoved() {
        for first in Self.bandFirsts {
            for number in [first, first + 13] {
                let entry: ApsidesWorkshopManifestEntry = Self.entry(number)
                let profile: ApsidesWorkshopBandProfile = Self.documented[entry.band - 1]
                for index in Self.rangeIndices {
                    guard let drawn = ApsidesWorkshopGenerator.draw(entry, index: index) else { continue }
                    let tag: String = "entry \(number) candidate \(index)"
                    let moved: Int = Self.leversMoved(drawn.level.orbit, from: drawn.winning)
                    #expect(drawn.level.orbit != drawn.winning, "\(tag)")
                    #expect(moved >= 1 && moved <= profile.levers.upperBound, "\(tag)")
                    if profile.levers.upperBound == 1 {
                        #expect(moved == 1, "\(tag)")
                    }
                    #expect(!drawn.level.startReport.wins, "\(tag): the start already wins")
                }
            }
        }
    }

    // MARK: - Generation, filters, neighbour rule and bound

    @Test("generate takes the first candidate with a plan in the band's range and within the budget")
    func generateFilters() throws {
        for number in Self.generateNumbers {
            let entry: ApsidesWorkshopManifestEntry = Self.entry(number)
            let profile: ApsidesWorkshopBandProfile = Self.documented[entry.band - 1]
            let generated: ApsidesWorkshopGenerated = try ApsidesWorkshopGenerator.generate(entry, previous: nil)
            let tag: String = "entry \(number)"
            #expect(generated.entry == entry, "\(tag)")
            #expect(generated.skipped >= 0 && generated.skipped < ApsidesWorkshopGenerator.maxCandidates, "\(tag)")
            #expect(generated.level == ApsidesWorkshopGenerator.candidate(entry, index: generated.skipped), "\(tag)")
            #expect(profile.planRange.contains(generated.plan.size), "\(tag)")
            #expect(generated.plan.size <= entry.budget, "\(tag)")
            #expect(ApsidesWorkshopSolver.wins(generated.level, orbit: generated.plan.orbit), "\(tag)")
            #expect(ApsidesWorkshopSolver.replayWins(generated.level, actions: generated.plan.actions), "\(tag)")
            #expect(generated.level.difficulty == entry.band, "\(tag)")
            #expect(generated.level.tutorial == (number <= 3), "\(tag)")
            #expect(generated.difficulty == ApsidesWorkshopDifficulty(level: generated.level, plan: generated.plan))
            #expect(generated.difficulty.tunings == generated.plan.size, "\(tag)")
            for index in 0..<generated.skipped {
                guard let level = ApsidesWorkshopGenerator.candidate(entry, index: index) else { continue }
                if let plan = ApsidesWorkshopSolver.plan(level) {
                    let accepted: Bool = profile.planRange.contains(plan.size) && plan.size <= entry.budget
                    #expect(!accepted, "\(tag): candidate \(index) qualified before \(generated.skipped)")
                }
            }
        }
    }

    @Test("the neighbour rule skips a candidate whose targets equal the previous level's")
    func neighbourRule() throws {
        for number in [2, 22, 42, 62, 82] {
            let entry: ApsidesWorkshopManifestEntry = Self.entry(number)
            let alone: ApsidesWorkshopGenerated = try ApsidesWorkshopGenerator.generate(entry, previous: nil)
            let after: ApsidesWorkshopGenerated = try ApsidesWorkshopGenerator.generate(entry, previous: alone.level)
            let tag: String = "entry \(number)"
            #expect(after.skipped > alone.skipped, "\(tag)")
            #expect(after.level.targets != alone.level.targets, "\(tag)")
            let unrelated: ApsidesWorkshopGenerated = try ApsidesWorkshopGenerator.generate(
                Self.entry(number - 1), previous: nil)
            if unrelated.level.targets != alone.level.targets {
                let kept: ApsidesWorkshopGenerated = try ApsidesWorkshopGenerator.generate(
                    entry, previous: unrelated.level)
                #expect(kept == alone, "\(tag): a different previous level changed the choice")
            }
        }
    }

    @Test("the candidate bound holds and its refusal carries the stable reason code")
    func candidateBoundAndRefusal() throws {
        var previous: ApsidesWorkshopLevel? = nil
        for number in 1...6 {
            let entry: ApsidesWorkshopManifestEntry = Self.entry(number)
            let generated: ApsidesWorkshopGenerated = try ApsidesWorkshopGenerator.generate(entry, previous: previous)
            #expect(generated.skipped < ApsidesWorkshopGenerator.maxCandidates, "entry \(number)")
            if let previous {
                #expect(generated.level.targets != previous.targets, "entry \(number)")
            }
            previous = generated.level
        }
        // The real manifest yields every level well inside the bound and a band profile cannot be replaced from
        // outside, so the refusal is checked by its value and stable reason code.
        let refusal: ApsidesWorkshopError = .generation(7)
        #expect(refusal.reasonCode == "r02-g18.generation")
        #expect(refusal == ApsidesWorkshopError.generation(7))
        #expect(refusal != ApsidesWorkshopError.generation(8))
    }
}
