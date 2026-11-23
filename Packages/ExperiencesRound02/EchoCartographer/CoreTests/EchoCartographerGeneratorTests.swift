// EchoCartographerGeneratorTests — feature 402 (R02-G11-02) T-R02G1102-004 (FR-R02G1102-001, 005; SC-R02G1102-003,
// 004). Host checks of the seeded level generator: the five band profiles equal clarification Q1 and out-of-range bands
// clamp; the level ids; candidate determinism and the drawing order of clarification Q1 re-implemented independently
// here (width, height, walls in index order, entry among the open cells, region of at least 12 cells, beacon count,
// beacons drawn by removal) and compared with `candidate` on 200 (entry, index) pairs; every candidate value within its
// band; `generate` on four sampled entries per band (pulses in the band's range and at most energy − 1, `skipped`
// equal to the first qualifying candidate, a winning witness, consistent difficulty metrics); the refusal
// `.generation(number)` when no candidate can qualify; and the catalog digest's determinism and order sensitivity.
// Explicit types, plain loops, short runs.
import Testing
import VisualCoreSimulation
@testable import EchoCartographerCore

@Suite("EchoCartographerGenerator")
struct EchoCartographerGeneratorTests {
    /// The manifest numbers sampled for generation: four per band.
    static let sampledNumbers: [Int] = [1, 4, 12, 20, 21, 30, 33, 40, 41, 50, 55, 60, 61, 70, 77, 80, 81, 90, 95, 100]

    /// A candidate re-drawn independently of the generator, following clarification Q1's order.
    struct Drawn: Equatable {
        let width: Int
        let height: Int
        let walls: Set<Int>
        let entry: EchoCartographerCell
        let beacons: [EchoCartographerCell]
    }

    /// The cells reachable from `start` through open cells by side steps (4-neighbour flood fill), `start` included.
    static func reachable(width: Int, height: Int, walls: Set<Int>, start: Int) -> Set<Int> {
        var seen: Set<Int> = [start]
        var stack: [Int] = [start]
        while let here = stack.popLast() {
            let x: Int = here % width
            let y: Int = here / width
            var neighbours: [Int] = []
            if y > 0 { neighbours.append(here - width) }
            if x < width - 1 { neighbours.append(here + 1) }
            if y < height - 1 { neighbours.append(here + width) }
            if x > 0 { neighbours.append(here - 1) }
            for n in neighbours where !walls.contains(n) && !seen.contains(n) {
                seen.insert(n)
                stack.append(n)
            }
        }
        return seen
    }

    /// Candidate `index` of `entry` drawn independently, or nil when the region is too small or too few cells remain.
    static func redraw(_ entry: EchoCartographerManifestEntry, index: Int) -> Drawn? {
        let profile: EchoCartographerBandProfile = .of(band: entry.band)
        var random: SeededRandom = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        let width: Int = random.int(profile.sizes)
        let height: Int = random.int(profile.sizes)
        var walls: Set<Int> = []
        for cell in 0..<(width * height) {
            if random.int(0...(profile.wallOneIn - 1)) == 0 { walls.insert(cell) }
        }
        var open: [Int] = []
        for cell in 0..<(width * height) {
            if !walls.contains(cell) { open.append(cell) }
        }
        if open.isEmpty { return nil }
        let entryIndex: Int = open[random.int(0...(open.count - 1))]
        let region: Set<Int> = reachable(width: width, height: height, walls: walls, start: entryIndex)
        if region.count < 12 { return nil }
        var pool: [Int] = []
        for cell in region.sorted() where cell != entryIndex { pool.append(cell) }
        let count: Int = random.int(profile.beacons)
        if pool.count < count { return nil }
        var beacons: [EchoCartographerCell] = []
        for _ in 0..<count {
            let picked: Int = pool.remove(at: random.int(0...(pool.count - 1)))
            beacons.append(EchoCartographerCell(x: picked % width, y: picked / width))
        }
        beacons.sort()
        return Drawn(width: width, height: height, walls: walls,
                     entry: EchoCartographerCell(x: entryIndex % width, y: entryIndex / width), beacons: beacons)
    }

    /// The manifest entry numbered `number`.
    static func entry(_ number: Int) -> EchoCartographerManifestEntry {
        EchoCartographerManifest.entries[number - 1]
    }

    /// Whether candidate `index` of `entry` fails one of the conditions `generate` requires.
    static func unqualified(_ entry: EchoCartographerManifestEntry, index: Int) -> Bool {
        let profile: EchoCartographerBandProfile = .of(band: entry.band)
        guard let level = EchoCartographerGenerator.candidate(entry, index: index) else { return true }
        guard let plan = EchoCartographerSolver.plan(level) else { return true }
        let pulses: Int = plan.pulses.count
        if !profile.pulses.contains(pulses) || pulses > level.energy - 1 { return true }
        return !EchoCartographerSolver.wins(level, actions: EchoCartographerSolver.actions(level, plan: plan))
    }

    @Test("the five band profiles equal clarification Q1")
    func bandProfiles() {
        let sizes: [ClosedRange<Int>] = [6...7, 7...9, 8...10, 9...12, 10...14]
        let wallOneIn: [Int] = [5, 5, 4, 4, 4]
        let beacons: [ClosedRange<Int>] = [1...1, 1...2, 2...2, 2...3, 3...4]
        let tolerance: [Int] = [1, 1, 1, 0, 0]
        let missCost: [Int] = [1, 1, 2, 2, 3]
        let pulses: [ClosedRange<Int>] = [1...2, 2...3, 3...4, 4...5, 5...6]
        for band in 1...5 {
            let profile: EchoCartographerBandProfile = .of(band: band)
            let i: Int = band - 1
            #expect(profile.band == band)
            #expect(profile.sizes == sizes[i], "band \(band) sizes")
            #expect(profile.wallOneIn == wallOneIn[i], "band \(band) wallOneIn")
            #expect(profile.beacons == beacons[i], "band \(band) beacons")
            #expect(profile.tolerance == tolerance[i], "band \(band) tolerance")
            #expect(profile.missCost == missCost[i], "band \(band) miss cost")
            #expect(profile.pulses == pulses[i], "band \(band) pulses")
            #expect(profile.pulses.upperBound <= EchoCartographerSolver.maxPulses)
            #expect(EchoCartographerChamber.sizeRange.contains(profile.sizes.lowerBound))
            #expect(EchoCartographerChamber.sizeRange.contains(profile.sizes.upperBound))
        }
        #expect(EchoCartographerBandProfile.of(band: 0) == EchoCartographerBandProfile.of(band: 1))
        #expect(EchoCartographerBandProfile.of(band: -7) == EchoCartographerBandProfile.of(band: 1))
        #expect(EchoCartographerBandProfile.of(band: 6) == EchoCartographerBandProfile.of(band: 5))
        #expect(EchoCartographerBandProfile.of(band: 99) == EchoCartographerBandProfile.of(band: 5))
        #expect(EchoCartographerGenerator.maxCandidates == 256)
        #expect(EchoCartographerGenerator.minimumRegion == 12)
        #expect(EchoCartographerGenerator.catalogID == "echo-cartographer")
    }

    @Test("level ids are echo-cartographer-NNN")
    func levelIDs() {
        #expect(EchoCartographerGenerator.levelID(1) == "echo-cartographer-001")
        #expect(EchoCartographerGenerator.levelID(42) == "echo-cartographer-042")
        #expect(EchoCartographerGenerator.levelID(100) == "echo-cartographer-100")
    }

    @Test("candidates are deterministic and vary with the index")
    func candidateDeterminism() {
        var differing: Int = 0
        var compared: Int = 0
        for number in Self.sampledNumbers {
            let entry: EchoCartographerManifestEntry = Self.entry(number)
            for index in 0..<8 {
                let first: EchoCartographerLevel? = EchoCartographerGenerator.candidate(entry, index: index)
                let second: EchoCartographerLevel? = EchoCartographerGenerator.candidate(entry, index: index)
                #expect(first == second, "entry \(number) candidate \(index)")
                let next: EchoCartographerLevel? = EchoCartographerGenerator.candidate(entry, index: index + 1)
                if let first, let next {
                    compared += 1
                    if first.fingerprint != next.fingerprint { differing += 1 }
                }
            }
        }
        #expect(compared > 0)
        #expect(differing == compared, "\(differing) of \(compared) neighbouring candidates differ")
    }

    @Test("candidate follows the drawing order of clarification Q1 on 200 (entry, index) pairs")
    func drawingOrder() {
        var pairs: Int = 0
        var levels: Int = 0
        var refused: Int = 0
        for entry in EchoCartographerManifest.entries {
            for offset in 0..<2 {
                let index: Int = (entry.number * 7 + offset * 31) % EchoCartographerGenerator.maxCandidates
                pairs += 1
                let drawn: Drawn? = Self.redraw(entry, index: index)
                let level: EchoCartographerLevel? = EchoCartographerGenerator.candidate(entry, index: index)
                #expect((drawn == nil) == (level == nil), "entry \(entry.number) index \(index) nil agreement")
                guard let drawn, let level else {
                    refused += 1
                    continue
                }
                levels += 1
                #expect(level.chamber.width == drawn.width, "entry \(entry.number) index \(index) width")
                #expect(level.chamber.height == drawn.height, "entry \(entry.number) index \(index) height")
                #expect(level.chamber.walls == drawn.walls, "entry \(entry.number) index \(index) walls")
                #expect(level.entry == drawn.entry, "entry \(entry.number) index \(index) entry")
                #expect(level.beacons == drawn.beacons, "entry \(entry.number) index \(index) beacons")
            }
        }
        #expect(pairs == 200)
        #expect(levels > 100, "\(levels) levels, \(refused) refused")
    }

    @Test("candidate values lie within the band and the manifest entry")
    func candidateValues() {
        for entry in EchoCartographerManifest.entries {
            let profile: EchoCartographerBandProfile = .of(band: entry.band)
            for index in 0..<3 {
                guard let level = EchoCartographerGenerator.candidate(entry, index: index) else { continue }
                let tag: String = "entry \(entry.number) index \(index)"
                #expect(profile.sizes.contains(level.chamber.width), "\(tag) width")
                #expect(profile.sizes.contains(level.chamber.height), "\(tag) height")
                #expect(profile.beacons.contains(level.beacons.count), "\(tag) beacons")
                #expect(level.tolerance == profile.tolerance, "\(tag) tolerance")
                #expect(level.missCost == profile.missCost, "\(tag) miss cost")
                #expect(level.energy == entry.energy, "\(tag) energy")
                #expect(level.tutorial == (entry.number <= 3), "\(tag) tutorial")
                #expect(level.difficulty == entry.band, "\(tag) difficulty")
                #expect(level.seed == entry.seed, "\(tag) seed")
                #expect(level.id == EchoCartographerGenerator.levelID(entry.number), "\(tag) id")
                let region: Int = EchoCartographerSolver.region(level).count + 1
                #expect(region >= EchoCartographerGenerator.minimumRegion, "\(tag) region \(region)")
            }
        }
    }

    @Test("generate on four sampled entries per band certifies the first qualifying candidate")
    func generateSampled() throws {
        for number in Self.sampledNumbers {
            let entry: EchoCartographerManifestEntry = Self.entry(number)
            let profile: EchoCartographerBandProfile = .of(band: entry.band)
            let generated: EchoCartographerGenerated = try EchoCartographerGenerator.generate(entry)
            let level: EchoCartographerLevel = generated.level
            let pulses: Int = generated.plan.pulses.count
            #expect(generated.entry == entry)
            #expect(profile.pulses.contains(pulses), "entry \(number) pulses \(pulses)")
            #expect(pulses <= level.energy - 1, "entry \(number) pulses \(pulses) energy \(level.energy)")
            #expect(generated.skipped >= 0 && generated.skipped < EchoCartographerGenerator.maxCandidates)
            #expect(level == EchoCartographerGenerator.candidate(entry, index: generated.skipped),
                    "entry \(number) level is candidate \(generated.skipped)")
            for earlier in 0..<generated.skipped {
                #expect(Self.unqualified(entry, index: earlier), "entry \(number) candidate \(earlier) qualifies")
            }
            #expect(!Self.unqualified(entry, index: generated.skipped))
            #expect(EchoCartographerSolver.wins(level, actions: generated.actions), "entry \(number) witness wins")
            let difficulty: EchoCartographerDifficulty = generated.difficulty
            #expect(difficulty == EchoCartographerDifficulty(level: level, plan: generated.plan))
            #expect(difficulty.pulses == pulses)
            #expect(difficulty.width == level.chamber.width)
            #expect(difficulty.height == level.chamber.height)
            #expect(difficulty.region == EchoCartographerSolver.region(level).count + 1)
            #expect(difficulty.beacons == level.beacons.count)
            #expect(difficulty.tolerance == level.tolerance)
            #expect(difficulty.work == generated.plan.work)
        }
        let again: EchoCartographerGenerated = try EchoCartographerGenerator.generate(Self.entry(1))
        #expect(again == (try EchoCartographerGenerator.generate(Self.entry(1))))
    }

    @Test("an entry no candidate can satisfy is refused with generation(number)")
    func refusal() {
        let base: EchoCartographerManifestEntry = Self.entry(1)
        let impossible: EchoCartographerManifestEntry =
            EchoCartographerManifestEntry(number: base.number, seed: base.seed, band: base.band, energy: 1)
        var thrown: EchoCartographerError? = nil
        do {
            _ = try EchoCartographerGenerator.generate(impossible)
        } catch {
            thrown = error
        }
        #expect(thrown == .generation(1))
        #expect(thrown?.reasonCode == "r02-g11.generation")
        #expect(EchoCartographerError.generation(57).reasonCode == "r02-g11.generation")
    }

    @Test("the catalog digest is deterministic and order-sensitive")
    func catalogDigest() {
        var levels: [EchoCartographerLevel] = []
        for number in [1, 21, 41] {
            let entry: EchoCartographerManifestEntry = Self.entry(number)
            for index in 0..<32 {
                if let level = EchoCartographerGenerator.candidate(entry, index: index) {
                    levels.append(level)
                    break
                }
            }
        }
        #expect(levels.count == 3)
        let digest: String = EchoCartographerGenerator.catalogDigest(levels)
        #expect(!digest.isEmpty)
        #expect(digest == EchoCartographerGenerator.catalogDigest(levels))
        var swapped: [EchoCartographerLevel] = levels
        swapped.swapAt(0, 2)
        #expect(digest != EchoCartographerGenerator.catalogDigest(swapped))
        #expect(digest != EchoCartographerGenerator.catalogDigest(Array(levels.prefix(2))))
    }
}
