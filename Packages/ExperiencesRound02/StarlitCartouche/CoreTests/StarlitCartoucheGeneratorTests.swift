// StarlitCartoucheGeneratorTests — feature 452 (R02-G16-02) T-R02G1602-004 (FR-R02G1602-001, 005; SC-R02G1602-001,
// 003, 004; clarification Q1). Host checks of the constructive level generator: the five band profiles of clarification
// Q1 and the clamp of out-of-range bands; the level ids; candidate and generation determinism; the drawing order of
// clarification Q1 re-implemented independently here (star count, glyph points redrawn until distinct, orbits, range,
// start star, route legs with up to eight draws and a drawn wait offset, decoys, hazards, deadline, windows) and
// compared with `candidate` on sampled (entry, index) pairs of every band; every candidate's values against its band;
// hazards and windows by control emphasis; hazards never meeting the constructed route nor the certified plan; the
// filters of `generate` (`skipped` is the first candidate with a minimal plan in the band's range and within the
// budget); the refusal `.generation(number)` past the candidate bound; and all 100 manifest entries generating with
// fewer than 256 candidates skipped. Explicit types, plain loops, short runs, no clocks.
import Testing
import VisualCoreSimulation
@testable import StarlitCartoucheCore

@Suite("StarlitCartoucheGenerator")
struct StarlitCartoucheGeneratorTests {
    /// The manifest numbers sampled for the independent re-draw: four per band, every emphasis.
    static let redrawNumbers: [Int] = [1, 4, 9, 15, 21, 24, 32, 38, 41, 44, 53, 60, 61, 64, 72, 78, 81, 84, 92, 100]

    /// The candidate indices re-drawn per sampled entry.
    static let redrawIndices: [Int] = [0, 3, 11]

    /// All 100 manifest entries generated once (about 0.3 s); an entry that throws is missing.
    static let generated: [StarlitCartoucheGenerated] = {
        var levels: [StarlitCartoucheGenerated] = []
        for entry in StarlitCartoucheManifest.entries {
            if let level = try? StarlitCartoucheGenerator.generate(entry) { levels.append(level) }
        }
        return levels
    }()

    /// The manifest entry numbered `number`.
    static func entry(_ number: Int) -> StarlitCartoucheManifestEntry {
        StarlitCartoucheManifest.entries[number - 1]
    }

    /// One leg of the independently re-drawn route.
    struct DrawnLeg: Equatable {
        let corridor: Int
        let depart: Int
        let arrive: Int
    }

    /// A candidate re-drawn independently of the generator: its first draws, its route and the level (nil when the
    /// level rules refuse the values).
    struct Drawn {
        let count: Int
        let range: Int
        let start: Int
        let route: [DrawnLeg]
        let level: StarlitCartoucheLevel?
    }

    /// The position of `orbit` at `beat`, computed here.
    static func position(_ orbit: [StarlitCartoucheVector], _ beat: Int) -> StarlitCartoucheVector {
        orbit[beat % orbit.count]
    }

    /// The squared distance of two positions, computed here.
    static func distance(_ p: StarlitCartoucheVector, _ q: StarlitCartoucheVector) -> Int {
        (p.x - q.x) * (p.x - q.x) + (p.y - q.y) * (p.y - q.y) + (p.z - q.z) * (p.z - q.z)
    }

    /// Candidate `index` of `entry` drawn independently in the order of clarification Q1; nil when a route leg finds no
    /// flyable next star within eight draws.
    static func redraw(_ entry: StarlitCartoucheManifestEntry, index: Int) -> Drawn? {
        let band: Int = min(5, max(1, entry.band))
        var random: SeededRandom = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        // 1. The star count, then per star a distinct glyph point and an orbit.
        let count: Int = random.int((band + 4)...(band + 5))
        var glyphs: [StarlitCartoucheGlyphPoint] = []
        var orbits: [[StarlitCartoucheVector]] = []
        while glyphs.count < count {
            let gx: Int = random.int(0...4)
            let gy: Int = random.int(0...4)
            let glyph: StarlitCartoucheGlyphPoint = StarlitCartoucheGlyphPoint(gx, gy)
            if glyphs.contains(glyph) { continue }
            glyphs.append(glyph)
            let length: Int = random.int(1...3)
            var orbit: [StarlitCartoucheVector] = []
            for _ in 0..<length {
                let x: Int = random.int(-5...5)
                let y: Int = random.int(-5...5)
                let z: Int = random.int(-5...5)
                orbit.append(StarlitCartoucheVector(x, y, z))
            }
            orbits.append(orbit)
        }
        // 2. The range and the start star.
        let range: Int = random.int(6...8)
        let start: Int = random.int(0...(count - 1))
        // 3. The route.
        var pairs: [(Int, Int)] = []
        var travels: [Int] = []
        var route: [DrawnLeg] = []
        var flownCorridors: [Int] = []
        var firstArrival: [Int: Int] = [start: 0]
        var lastVisit: [Int: Int] = [start: 0]
        var star: Int = start
        var beat: Int = 0
        let legs: Int = random.int((band + 1)...(band + 2))
        for _ in 0..<legs {
            var flown: Bool = false
            var attempt: Int = 0
            while attempt < 8 && !flown {
                attempt += 1
                let next: Int = random.int(0...(count - 1))
                if next == star { continue }
                let offset: Int = random.int(0...3)
                var wait: Int = -1
                var k: Int = 0
                while k <= 8 && wait < 0 {
                    let w: Int = (k + offset) % 9
                    let d: Int = distance(position(orbits[star], beat + w), position(orbits[next], beat + w))
                    if d <= range * range { wait = w }
                    k += 1
                }
                if wait < 0 { continue }
                var used: Int = -1
                for i in 0..<pairs.count {
                    let pair: (Int, Int) = pairs[i]
                    if (pair.0 == star && pair.1 == next) || (pair.0 == next && pair.1 == star) { used = i }
                }
                if used < 0 {
                    pairs.append((star, next))
                    travels.append(random.int(1...3))
                    used = pairs.count - 1
                }
                let depart: Int = beat + wait
                let arrive: Int = depart + travels[used]
                route.append(DrawnLeg(corridor: used, depart: depart, arrive: arrive))
                if !flownCorridors.contains(used) { flownCorridors.append(used) }
                lastVisit[star] = max(lastVisit[star] ?? 0, depart)
                if firstArrival[next] == nil { firstArrival[next] = arrive }
                lastVisit[next] = max(lastVisit[next] ?? 0, arrive)
                star = next
                beat = arrive
                flown = true
            }
            if !flown { return nil }
        }
        // 4. The decoys.
        for _ in 0..<(band + 1) {
            let a: Int = random.int(0...(count - 1))
            let b: Int = random.int(0...(count - 1))
            if a == b || pairs.count >= 24 { continue }
            var known: Bool = false
            for pair in pairs where (pair.0 == a && pair.1 == b) || (pair.0 == b && pair.1 == a) { known = true }
            if known { continue }
            pairs.append((a, b))
            travels.append(random.int(1...3))
        }
        // 5. The hazards.
        var hazards: [StarlitCartoucheHazard] = []
        let hazardCount: Int = entry.emphasis == "avoid hazard" ? band + 2 : random.int(0...band)
        var h: Int = 0
        while h < hazardCount && hazards.count < 8 {
            h += 1
            let corridor: Int = random.int(0...(pairs.count - 1))
            let from: Int = random.int(0...(beat + 2))
            let to: Int = from + random.int(0...3)
            var meets: Bool = false
            for leg in route where leg.corridor == corridor && from <= leg.arrive && leg.depart <= to { meets = true }
            if meets { continue }
            hazards.append(StarlitCartoucheHazard(corridor: corridor, from: from, to: to))
        }
        // 6. The deadline.
        let deadline: Int = min(64, beat + random.int(0...max(0, 5 - band)))
        // 7. The windows.
        var stars: [StarlitCartoucheStar] = []
        for i in 0..<count {
            var open: Int = 0
            var close: Int = 64
            var windowed: Bool = entry.emphasis == "time launch"
            if !windowed { windowed = random.int(0...2) == 0 }
            if windowed, let earliest = firstArrival[i], let latest = lastVisit[i] {
                open = max(0, earliest - random.int(0...2))
                close = min(64, latest + random.int(0...2))
                if i == start { open = 0 }
            }
            stars.append(StarlitCartoucheStar(orbit: orbits[i], glyph: glyphs[i], open: open, close: close))
        }
        var corridors: [StarlitCartoucheCorridor] = []
        for i in 0..<pairs.count {
            corridors.append(StarlitCartoucheCorridor(pairs[i].0, pairs[i].1, travel: travels[i]))
        }
        let level: StarlitCartoucheLevel? = try? StarlitCartoucheLevel(
            id: StarlitCartoucheGenerator.levelID(entry.number), seed: entry.seed, difficulty: band, stars: stars,
            range: range, corridors: corridors, hazards: hazards, start: start, beacon: star, deadline: deadline,
            symbol: flownCorridors.sorted(), budget: entry.budget, tutorial: entry.number <= 3)
        return Drawn(count: count, range: range, start: start, route: route, level: level)
    }

    /// The stars at either end of a symbol corridor: the stars any winning plan visits.
    static func routeStars(_ level: StarlitCartoucheLevel) -> Set<Int> {
        var stars: Set<Int> = []
        for index in level.symbol {
            stars.insert(level.corridors[index].a)
            stars.insert(level.corridors[index].b)
        }
        return stars
    }

    /// The values every candidate of `entry` must hold (clarification Q1).
    static func checkValues(_ level: StarlitCartoucheLevel, _ entry: StarlitCartoucheManifestEntry) {
        let profile: StarlitCartoucheBandProfile = .of(band: entry.band)
        #expect(profile.stars.contains(level.stars.count))
        #expect((6...8).contains(level.range))
        for star in level.stars {
            #expect((1...3).contains(star.orbit.count))
            for p in star.orbit {
                #expect((-5...5).contains(p.x) && (-5...5).contains(p.y) && (-5...5).contains(p.z))
            }
            #expect(star.open >= 0 && star.open <= star.close && star.close <= 64)
        }
        #expect(level.difficulty == entry.band)
        #expect(level.budget == entry.budget)
        #expect(level.id == StarlitCartoucheGenerator.levelID(entry.number))
        #expect(level.tutorial == (entry.number <= 3))
        #expect(!level.symbol.isEmpty)
        #expect(level.symbol == Array(Set(level.symbol)).sorted())
        #expect(level.hazards.count <= 8)
        #expect(level.deadline >= 1 && level.deadline <= 64)
        let visited: Set<Int> = routeStars(level)
        #expect(visited.contains(level.start) && visited.contains(level.beacon))
        for i in level.stars.indices where !visited.contains(i) {
            #expect(level.stars[i].open == 0 && level.stars[i].close == 64)
        }
        if entry.emphasis == "time launch" {
            for i in visited { #expect(level.stars[i].open != 0 || level.stars[i].close != 64) }
        }
        if entry.emphasis == "avoid hazard" {
            #expect(level.hazards.count <= entry.band + 2)
        } else {
            #expect(level.hazards.count <= entry.band)
        }
    }

    @Test("band profiles of clarification Q1 and the clamp")
    func bandProfiles() {
        for band in 1...5 {
            let profile: StarlitCartoucheBandProfile = .of(band: band)
            #expect(profile.stars == (band + 4)...(band + 5))
            #expect(profile.route == (band + 1)...(band + 2))
            #expect(profile.decoys == band + 1)
            #expect(profile.planRange == (band + 1)...(band + 2))
        }
        #expect(StarlitCartoucheBandProfile.of(band: 0) == .of(band: 1))
        #expect(StarlitCartoucheBandProfile.of(band: -3) == .of(band: 1))
        #expect(StarlitCartoucheBandProfile.of(band: 6) == .of(band: 5))
        #expect(StarlitCartoucheBandProfile.of(band: 99) == .of(band: 5))
        #expect(StarlitCartoucheBandProfile.of(band: 1).planRange == 2...3)
        #expect(StarlitCartoucheBandProfile.of(band: 5).planRange == 6...7)
    }

    @Test("level ids and bounds")
    func levelIDsAndBounds() {
        #expect(StarlitCartoucheGenerator.levelID(1) == "starlit-cartouche-001")
        #expect(StarlitCartoucheGenerator.levelID(42) == "starlit-cartouche-042")
        #expect(StarlitCartoucheGenerator.levelID(100) == "starlit-cartouche-100")
        #expect(StarlitCartoucheGenerator.maxCandidates == 256)
        #expect(StarlitCartoucheGenerator.drawsPerLeg == 8)
        #expect(StarlitCartoucheGenerator.catalogID == "starlit-cartouche")
    }

    @Test("candidates and generation are deterministic; indices differ")
    func determinism() throws {
        for number in Self.redrawNumbers {
            let entry: StarlitCartoucheManifestEntry = Self.entry(number)
            var fingerprints: Set<String> = []
            var valid: Int = 0
            for index in 0..<6 {
                let first: StarlitCartoucheLevel? = StarlitCartoucheGenerator.candidate(entry, index: index)
                let second: StarlitCartoucheLevel? = StarlitCartoucheGenerator.candidate(entry, index: index)
                #expect(first == second)
                #expect(first?.fingerprint == second?.fingerprint)
                if let level = first {
                    valid += 1
                    fingerprints.insert(level.fingerprint)
                }
            }
            #expect(fingerprints.count == valid)
            let a: StarlitCartoucheGenerated = try StarlitCartoucheGenerator.generate(entry)
            let b: StarlitCartoucheGenerated = try StarlitCartoucheGenerator.generate(entry)
            #expect(a == b)
            #expect(a.level.fingerprint == b.level.fingerprint)
        }
    }

    @Test("the drawing order of clarification Q1, re-drawn independently")
    func drawingOrder() {
        var compared: Int = 0
        for number in Self.redrawNumbers {
            let entry: StarlitCartoucheManifestEntry = Self.entry(number)
            for index in Self.redrawIndices {
                let drawn: Drawn? = Self.redraw(entry, index: index)
                let level: StarlitCartoucheLevel? = StarlitCartoucheGenerator.candidate(entry, index: index)
                #expect(drawn?.level == level, "entry \(number) candidate \(index)")
                guard let drawn, let level else { continue }
                compared += 1
                #expect(level.stars.count == drawn.count)
                #expect(level.range == drawn.range)
                #expect(level.start == drawn.start)
                #expect(level.fingerprint == drawn.level?.fingerprint)
                // The hazards never meet a leg of the constructed route.
                for leg in drawn.route {
                    for hazard in level.hazards where hazard.corridor == leg.corridor {
                        #expect(hazard.to < leg.depart || leg.arrive < hazard.from)
                    }
                }
            }
        }
        #expect(compared >= 50)
    }

    @Test("every candidate holds its band's values")
    func candidateValues() {
        var checked: Int = 0
        for entry in StarlitCartoucheManifest.entries where entry.number % 3 == 1 {
            for index in 0..<4 {
                guard let level = StarlitCartoucheGenerator.candidate(entry, index: index) else { continue }
                Self.checkValues(level, entry)
                checked += 1
            }
        }
        #expect(checked >= 100)
    }

    @Test("generated levels hold their band's values and certified plans")
    func generatedValues() {
        #expect(Self.generated.count == 100)
        for generated in Self.generated {
            let entry: StarlitCartoucheManifestEntry = generated.entry
            Self.checkValues(generated.level, entry)
            let profile: StarlitCartoucheBandProfile = .of(band: entry.band)
            #expect(profile.planRange.contains(generated.plan.size))
            #expect(generated.plan.size <= entry.budget)
            #expect(generated.difficulty == StarlitCartoucheDifficulty(level: generated.level, plan: generated.plan))
            #expect(generated.level == StarlitCartoucheGenerator.candidate(entry, index: generated.skipped))
        }
    }

    @Test("hazards and windows by control emphasis")
    func emphasis() {
        var hazardLevels: Int = 0
        var timedLevels: Int = 0
        for generated in Self.generated {
            let level: StarlitCartoucheLevel = generated.level
            let visited: Set<Int> = Self.routeStars(level)
            if generated.entry.emphasis == "avoid hazard" {
                hazardLevels += 1
                #expect(!level.hazards.isEmpty, "level \(generated.entry.number)")
                #expect(level.hazards.count <= min(8, generated.entry.band + 2))
            }
            if generated.entry.emphasis == "time launch" {
                timedLevels += 1
                for i in visited {
                    let star: StarlitCartoucheStar = level.stars[i]
                    #expect(star.open != 0 || star.close != 64, "level \(generated.entry.number) star \(i)")
                }
            }
            // The plan visits exactly the stars at the ends of the symbol's corridors.
            var planStars: Set<Int> = [level.start]
            for action in generated.plan.legs {
                if case let .leg(star, _) = action { planStars.insert(star) }
            }
            #expect(planStars == visited)
        }
        #expect(hazardLevels == 20)
        #expect(timedLevels == 20)
    }

    @Test("hazards never meet the certified plan, which wins through the play")
    func hazardsNeverMeetPlan() throws {
        for generated in Self.generated {
            let level: StarlitCartoucheLevel = generated.level
            var star: Int = level.start
            var beat: Int = 0
            for action in generated.plan.legs {
                guard case let .leg(next, wait) = action else { continue }
                let leg: StarlitCartoucheLeg = try StarlitCartoucheChart.leg(level, from: star, at: beat, to: next,
                                                                             wait: wait)
                #expect(StarlitCartoucheChart.check(level, leg: leg) == nil, "level \(generated.entry.number)")
                for hazard in level.hazards where hazard.corridor == leg.corridor {
                    #expect(hazard.to < leg.depart || leg.arrive < hazard.from)
                }
                star = next
                beat = leg.arrive
            }
            #expect(star == level.beacon)
            #expect(StarlitCartoucheSolver.wins(level, actions: generated.plan.legs))
        }
    }

    @Test("generate keeps the first qualifying candidate")
    func filters() {
        for generated in Self.generated {
            let entry: StarlitCartoucheManifestEntry = generated.entry
            let range: ClosedRange<Int> = StarlitCartoucheBandProfile.of(band: entry.band).planRange
            #expect(generated.skipped >= 0 && generated.skipped < StarlitCartoucheGenerator.maxCandidates)
            for index in 0..<generated.skipped {
                guard let level = StarlitCartoucheGenerator.candidate(entry, index: index) else { continue }
                if let plan = StarlitCartoucheSolver.plan(level, maxLegs: range.upperBound) {
                    let qualifies: Bool = range.contains(plan.size) && plan.size <= entry.budget
                    #expect(!qualifies, "level \(entry.number) candidate \(index)")
                }
            }
        }
    }

    @Test("past the candidate bound generate refuses with .generation(number)")
    func refusal() {
        // Budget 1 is below every band-1 plan (2 … 3 legs): the solver rejects all 256 candidates.
        let tight: StarlitCartoucheManifestEntry = StarlitCartoucheManifestEntry(
            number: 7, seed: 0x4916b774cc315678, band: 1, budget: 1, emphasis: "commit glyph")
        // Budget 30 is beyond the level rules (1 … 24): every candidate is refused.
        let wide: StarlitCartoucheManifestEntry = StarlitCartoucheManifestEntry(
            number: 55, seed: 0x5de98d4d25d2386d, band: 3, budget: 30, emphasis: "adjust arc")
        let cases: [StarlitCartoucheManifestEntry] = [tight, wide]
        for entry in cases {
            var refusal: StarlitCartoucheError? = nil
            do {
                _ = try StarlitCartoucheGenerator.generate(entry)
            } catch {
                refusal = error
            }
            #expect(refusal == .generation(entry.number))
            #expect(refusal?.reasonCode == "r02-g16.generation")
        }
    }

    @Test("all 100 manifest entries generate in order; the digest is stable")
    func allEntries() {
        #expect(Self.generated.count == 100)
        var numbers: [Int] = []
        var maxSkipped: Int = 0
        for generated in Self.generated {
            numbers.append(generated.entry.number)
            maxSkipped = max(maxSkipped, generated.skipped)
        }
        #expect(numbers == Array(1...100))
        #expect(maxSkipped < StarlitCartoucheGenerator.maxCandidates)
        var levels: [StarlitCartoucheLevel] = []
        for generated in Self.generated { levels.append(generated.level) }
        #expect(Set(levels.map(\.fingerprint)).count == 100)
        let digest: String = StarlitCartoucheGenerator.catalogDigest(levels)
        #expect(digest == StarlitCartoucheGenerator.catalogDigest(levels))
        #expect(digest != StarlitCartoucheGenerator.catalogDigest(levels.reversed()))
    }
}
