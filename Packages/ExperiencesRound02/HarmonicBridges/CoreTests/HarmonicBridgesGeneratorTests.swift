// HarmonicBridgesGeneratorTests — feature 412 (R02-G12-02) T-R02G1202-004 (FR-R02G1202-001, 005; SC-R02G1202-001, 003,
// 004). Host checks of the seeded level generator: the five band profiles equal the data model and out-of-range bands
// clamp; the frequencies; the level ids; candidate and generation determinism (level and fingerprint, twice); the
// drawing order of clarification Q1 re-implemented independently here and compared with `candidate` on 200 (entry,
// index) pairs, skipped draws included; every candidate value within its band; `generate` on sampled entries per band
// (minimal tunings in the band's range and at most budget − 1, never already won at the starting pegs, `skipped` equal
// to the first qualifying candidate, a winning witness, consistent difficulty metrics); the candidate bound and the
// refusal `.generation(number)` when no candidate can qualify; and the catalog digest's determinism and order
// sensitivity. Explicit types, plain loops, short runs.
import Testing
import VisualCoreSimulation
@testable import HarmonicBridgesCore

@Suite("HarmonicBridgesGenerator")
struct HarmonicBridgesGeneratorTests {
    /// The manifest numbers sampled for generation: two per band.
    static let sampledNumbers: [Int] = [1, 14, 21, 37, 41, 58, 61, 79, 81, 100]

    /// The manifest numbers sampled for the independent re-draw: four per band.
    static let redrawNumbers: [Int] = [1, 7, 13, 20, 21, 28, 35, 40, 41, 49, 52, 60, 61, 66, 73, 80, 81, 88, 94, 100]

    /// A candidate re-drawn independently of the generator, following clarification Q1's order.
    struct Drawn: Equatable {
        let islandCount: Int
        let path: [Int]
        let steps: [[HarmonicBridgesTone]]
        let threshold: Int
        let strings: [HarmonicBridgesString]
    }

    /// The manifest entry numbered `number`.
    static func entry(_ number: Int) -> HarmonicBridgesManifestEntry {
        HarmonicBridgesManifest.entries[number - 1]
    }

    /// Whether a string of `length` at `peg` is a bridge in every step, judged through the public resonance.
    static func solidEverywhere(length: Int, peg: Int, steps: [[HarmonicBridgesTone]], threshold: Int) -> Bool {
        let probe: HarmonicBridgesString = HarmonicBridgesString(a: 0, b: 1, length: length, peg: peg)
        var step: Int = 0
        while step < steps.count {
            let resonance: HarmonicBridgesResonance =
                HarmonicBridgesResonance(string: probe, index: 0, step: step, tones: steps[step], peg: peg,
                                         threshold: threshold)
            if !resonance.bridge { return false }
            step += 1
        }
        return true
    }

    /// Candidate `index` of `entry` drawn independently, word for word in clarification Q1's order, or nil for a
    /// skipped draw.
    static func redraw(_ entry: HarmonicBridgesManifestEntry, index: Int) -> Drawn? {
        let profile: HarmonicBridgesBandProfile = .of(band: entry.band)
        var random: SeededRandom = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        // The scrambled count k in the band's range.
        let k: Int = random.int(profile.scrambled)
        // The path length P = k + (0 or 1), at most 7.
        var p: Int = k + random.int(0...1)
        if p > 7 { p = 7 }
        // The island count min(8, P + 1 + (0 or 1)).
        var islands: Int = p + 1 + random.int(0...1)
        if islands > 8 { islands = 8 }
        // The steps by band, each with its tones drawn without repeat, each with a strength 1 … 3.
        let stepCount: Int = random.int(profile.steps)
        var steps: [[HarmonicBridgesTone]] = []
        for _ in 0..<stepCount {
            let toneCount: Int = random.int(profile.tones)
            var remaining: [Int] = [6, 12, 18, 24, 30, 36, 48, 60, 72]
            var tones: [HarmonicBridgesTone] = []
            for _ in 0..<toneCount {
                let at: Int = random.int(0...(remaining.count - 1))
                let frequency: Int = remaining[at]
                remaining.remove(at: at)
                let strength: Int = random.int(1...3)
                tones.append(HarmonicBridgesTone(frequency: frequency, strength: strength))
            }
            steps.append(tones)
        }
        // The threshold by band.
        let threshold: Int = random.int(profile.thresholds)
        // The path from island 0 through P − 1 distinct interior islands (a shuffled draw) to the last island.
        if islands - 2 < p - 1 { return nil }
        var interior: [Int] = []
        var island: Int = 1
        while island <= islands - 2 {
            interior.append(island)
            island += 1
        }
        random.shuffle(&interior)
        var path: [Int] = [0]
        var taken: Int = 0
        while taken < p - 1 {
            path.append(interior[taken])
            taken += 1
        }
        path.append(islands - 1)
        // For each path string a (length, peg) drawn from the pairs that are a bridge in every step (none: skipped).
        var solid: [(Int, Int)] = []
        for length in 1...6 {
            for peg in 1...12 {
                if solidEverywhere(length: length, peg: peg, steps: steps, threshold: threshold) {
                    solid.append((length, peg))
                }
            }
        }
        if solid.isEmpty { return nil }
        var lengths: [Int] = []
        var pegs: [Int] = []
        for _ in 0..<p {
            let pick: (Int, Int) = solid[random.int(0...(solid.count - 1))]
            lengths.append(pick.0)
            pegs.append(pick.1)
        }
        // The k scrambled path strings (a drawn subset) get instead a peg that is not a bridge in every step.
        var indices: [Int] = []
        for position in 0..<p { indices.append(position) }
        random.shuffle(&indices)
        var isScrambled: [Bool] = []
        for _ in 0..<p { isScrambled.append(false) }
        for chosen in 0..<k { isScrambled[indices[chosen]] = true }
        for position in 0..<p {
            if !isScrambled[position] { continue }
            var breaking: [Int] = []
            for peg in 1...12 {
                if !solidEverywhere(length: lengths[position], peg: peg, steps: steps, threshold: threshold) {
                    breaking.append(peg)
                }
            }
            if breaking.isEmpty { return nil }
            pegs[position] = breaking[random.int(0...(breaking.count - 1))]
        }
        var strings: [HarmonicBridgesString] = []
        var usedPairs: [[Int]] = []
        for position in 0..<p {
            let first: Int = path[position]
            let second: Int = path[position + 1]
            let low: Int = first < second ? first : second
            let high: Int = first < second ? second : first
            usedPairs.append([low, high])
            strings.append(HarmonicBridgesString(a: low, b: high, length: lengths[position], peg: pegs[position]))
        }
        // Decoy strings by band on unused island pairs (shuffled), each with a length, a peg and locked 3 in 10.
        let decoys: Int = random.int(profile.decoys)
        var free: [[Int]] = []
        for a in 0..<islands {
            var b: Int = a + 1
            while b < islands {
                if !usedPairs.contains([a, b]) { free.append([a, b]) }
                b += 1
            }
        }
        random.shuffle(&free)
        var placed: Int = 0
        while placed < decoys && placed < free.count {
            let length: Int = random.int(1...6)
            let peg: Int = random.int(1...12)
            let locked: Bool = random.int(0...9) < 3
            strings.append(HarmonicBridgesString(a: free[placed][0], b: free[placed][1], length: length, peg: peg,
                                                 locked: locked))
            placed += 1
        }
        // The strings are shuffled.
        random.shuffle(&strings)
        return Drawn(islandCount: islands, path: path, steps: steps, threshold: threshold, strings: strings)
    }

    /// Whether candidate `index` of `entry` fails one of the conditions `generate` requires.
    static func unqualified(_ entry: HarmonicBridgesManifestEntry, index: Int) -> Bool {
        let profile: HarmonicBridgesBandProfile = .of(band: entry.band)
        guard let level = HarmonicBridgesGenerator.candidate(entry, index: index) else { return true }
        guard let plan = HarmonicBridgesSolver.plan(level) else { return true }
        let tunings: Int = plan.tunings.count
        if tunings < 1 || !profile.scrambled.contains(tunings) || tunings > level.budget - 1 { return true }
        return !HarmonicBridgesSolver.wins(level, actions: HarmonicBridgesSolver.actions(plan))
    }

    @Test("the five band profiles equal the data model")
    func bandProfiles() {
        let scrambled: [ClosedRange<Int>] = [1...2, 2...3, 3...4, 4...5, 5...6]
        let steps: [ClosedRange<Int>] = [1...1, 1...2, 2...2, 2...3, 3...4]
        let tones: [ClosedRange<Int>] = [2...2, 2...3, 2...3, 2...3, 3...3]
        let thresholds: [ClosedRange<Int>] = [1...3, 2...4, 2...5, 3...6, 3...6]
        let decoys: [ClosedRange<Int>] = [1...2, 2...3, 2...4, 3...4, 3...5]
        for band in 1...5 {
            let profile: HarmonicBridgesBandProfile = .of(band: band)
            let i: Int = band - 1
            #expect(profile.band == band)
            #expect(profile.scrambled == scrambled[i], "band \(band) scrambled")
            #expect(profile.steps == steps[i], "band \(band) steps")
            #expect(profile.tones == tones[i], "band \(band) tones")
            #expect(profile.thresholds == thresholds[i], "band \(band) thresholds")
            #expect(profile.decoys == decoys[i], "band \(band) decoys")
            #expect(profile.scrambled.upperBound <= HarmonicBridgesSolver.maxTunings)
            #expect(HarmonicBridgesLevel.stepCounts.contains(profile.steps.upperBound))
            #expect(HarmonicBridgesLevel.toneCounts.contains(profile.tones.upperBound))
            #expect(HarmonicBridgesLevel.thresholds.contains(profile.thresholds.upperBound))
        }
        #expect(HarmonicBridgesBandProfile.of(band: 0) == HarmonicBridgesBandProfile.of(band: 1))
        #expect(HarmonicBridgesBandProfile.of(band: -7) == HarmonicBridgesBandProfile.of(band: 1))
        #expect(HarmonicBridgesBandProfile.of(band: 6) == HarmonicBridgesBandProfile.of(band: 5))
        #expect(HarmonicBridgesBandProfile.of(band: 99) == HarmonicBridgesBandProfile.of(band: 5))
        #expect(HarmonicBridgesGenerator.maxCandidates == 256)
        #expect(HarmonicBridgesGenerator.maxPath == 7)
        #expect(HarmonicBridgesGenerator.lockedInTen == 3)
        #expect(HarmonicBridgesGenerator.catalogID == "harmonic-bridges")
    }

    @Test("the frequencies are the nine of clarification Q1")
    func frequencies() {
        let expected: [Int] = [6, 12, 18, 24, 30, 36, 48, 60, 72]
        #expect(HarmonicBridgesGenerator.frequencies == expected)
        for frequency in HarmonicBridgesGenerator.frequencies {
            #expect(HarmonicBridgesLevel.frequencies.contains(frequency))
        }
        #expect(Set(HarmonicBridgesGenerator.frequencies).count == HarmonicBridgesGenerator.frequencies.count)
    }

    @Test("level ids are harmonic-bridges-NNN")
    func levelIDs() {
        #expect(HarmonicBridgesGenerator.levelID(1) == "harmonic-bridges-001")
        #expect(HarmonicBridgesGenerator.levelID(9) == "harmonic-bridges-009")
        #expect(HarmonicBridgesGenerator.levelID(42) == "harmonic-bridges-042")
        #expect(HarmonicBridgesGenerator.levelID(100) == "harmonic-bridges-100")
    }

    @Test("candidates are deterministic and vary with the index")
    func candidateDeterminism() {
        var differing: Int = 0
        var compared: Int = 0
        for number in Self.redrawNumbers {
            let entry: HarmonicBridgesManifestEntry = Self.entry(number)
            var previous: String? = nil
            for index in 0..<8 {
                let first: HarmonicBridgesLevel? = HarmonicBridgesGenerator.candidate(entry, index: index)
                let second: HarmonicBridgesLevel? = HarmonicBridgesGenerator.candidate(entry, index: index)
                #expect(first == second, "entry \(number) candidate \(index)")
                #expect(first?.fingerprint == second?.fingerprint, "entry \(number) candidate \(index) fingerprint")
                if let level = first {
                    if let earlier = previous {
                        compared += 1
                        if earlier != level.fingerprint { differing += 1 }
                    }
                    previous = level.fingerprint
                }
            }
        }
        #expect(compared > 0)
        #expect(differing == compared)
    }

    @Test("an independent re-draw in clarification Q1's order matches candidate on 200 pairs")
    func drawingOrder() {
        var pairs: Int = 0
        var skipped: Int = 0
        for number in Self.redrawNumbers {
            let entry: HarmonicBridgesManifestEntry = Self.entry(number)
            for index in 0..<10 {
                pairs += 1
                let drawn: Drawn? = Self.redraw(entry, index: index)
                let level: HarmonicBridgesLevel? = HarmonicBridgesGenerator.candidate(entry, index: index)
                guard let drawn else {
                    skipped += 1
                    #expect(level == nil, "entry \(number) candidate \(index) should be skipped")
                    continue
                }
                guard let level else {
                    Issue.record("entry \(number) candidate \(index): core skipped, re-draw did not")
                    continue
                }
                #expect(level.islands.count == drawn.islandCount, "entry \(number) candidate \(index) islands")
                #expect(level.steps == drawn.steps, "entry \(number) candidate \(index) steps")
                #expect(level.threshold == drawn.threshold, "entry \(number) candidate \(index) threshold")
                #expect(level.strings == drawn.strings, "entry \(number) candidate \(index) strings")
                #expect(level.start == 0)
                #expect(level.goal == drawn.islandCount - 1)
                // The drawing positions follow the path order: column i · 15 / P, rows 3 and 6 alternating.
                let span: Int = max(1, drawn.path.count - 1)
                var position: Int = 0
                while position < drawn.path.count {
                    let island: HarmonicBridgesIsland = level.islands[drawn.path[position]]
                    #expect(island.x == position * 15 / span, "entry \(number) candidate \(index) column")
                    #expect(island.y == (position % 2 == 0 ? 3 : 6), "entry \(number) candidate \(index) row")
                    position += 1
                }
            }
        }
        #expect(pairs == 200)
        #expect(skipped < pairs)
    }

    @Test("every candidate value lies within its band")
    func bandValues() {
        for number in Self.redrawNumbers {
            let entry: HarmonicBridgesManifestEntry = Self.entry(number)
            let profile: HarmonicBridgesBandProfile = .of(band: entry.band)
            for index in 0..<12 {
                guard let level = HarmonicBridgesGenerator.candidate(entry, index: index) else { continue }
                #expect(level.id == HarmonicBridgesGenerator.levelID(number))
                #expect(level.seed == entry.seed)
                #expect(level.difficulty == entry.band)
                #expect(level.budget == entry.budget)
                #expect(level.tutorial == (number <= 3), "entry \(number) tutorial")
                #expect(level.start == 0)
                #expect(level.goal == level.islands.count - 1)
                #expect(HarmonicBridgesLevel.islandCounts.contains(level.islands.count))
                #expect(level.islands.count >= profile.scrambled.lowerBound + 1, "entry \(number) islands")
                #expect(level.islands.count <= min(8, profile.scrambled.upperBound + 3), "entry \(number) islands")
                #expect(profile.steps.contains(level.steps.count), "entry \(number) steps")
                for tones in level.steps {
                    #expect(profile.tones.contains(tones.count), "entry \(number) tones")
                    for tone in tones {
                        #expect(HarmonicBridgesGenerator.frequencies.contains(tone.frequency))
                        #expect(HarmonicBridgesLevel.strengths.contains(tone.strength))
                    }
                }
                #expect(profile.thresholds.contains(level.threshold), "entry \(number) threshold")
                var locked: Int = 0
                for string in level.strings where string.locked { locked += 1 }
                // Path strings are never locked, so the decoys are at least the locked strings and at most the band's.
                #expect(locked <= profile.decoys.upperBound, "entry \(number) locked")
                let pathMin: Int = profile.scrambled.lowerBound
                let pathMax: Int = min(7, profile.scrambled.upperBound + 1)
                #expect(level.strings.count >= pathMin, "entry \(number) strings")
                #expect(level.strings.count <= pathMax + profile.decoys.upperBound, "entry \(number) strings")
                let drawn: Drawn? = Self.redraw(entry, index: index)
                if let drawn {
                    let pathLength: Int = drawn.path.count - 1
                    let decoys: Int = level.strings.count - pathLength
                    #expect(decoys >= 0, "entry \(number) decoys")
                    #expect(decoys <= profile.decoys.upperBound, "entry \(number) decoys")
                    #expect(pathLength >= profile.scrambled.lowerBound, "entry \(number) path")
                    #expect(pathLength <= pathMax, "entry \(number) path")
                }
            }
        }
    }

    @Test("generated levels pass the filters and are deterministic")
    func generatedFilters() throws {
        for number in Self.sampledNumbers {
            let entry: HarmonicBridgesManifestEntry = Self.entry(number)
            let profile: HarmonicBridgesBandProfile = .of(band: entry.band)
            let generated: HarmonicBridgesGenerated = try HarmonicBridgesGenerator.generate(entry)
            let again: HarmonicBridgesGenerated = try HarmonicBridgesGenerator.generate(entry)
            #expect(generated == again, "entry \(number) determinism")
            #expect(generated.level.fingerprint == again.level.fingerprint, "entry \(number) fingerprint")
            #expect(generated.entry == entry)
            #expect(generated.skipped < HarmonicBridgesGenerator.maxCandidates)
            let level: HarmonicBridgesLevel = generated.level
            #expect(level == HarmonicBridgesGenerator.candidate(entry, index: generated.skipped))
            #expect(level.id == HarmonicBridgesGenerator.levelID(number))
            #expect(level.difficulty == entry.band)
            #expect(level.budget == entry.budget)
            #expect(level.tutorial == (number <= 3))
            let tunings: Int = generated.plan.tunings.count
            #expect(profile.scrambled.contains(tunings), "entry \(number) tunings \(tunings)")
            #expect(tunings <= level.budget - 1, "entry \(number) budget")
            #expect(generated.plan.work <= HarmonicBridgesSolver.workBound)
            let startReport: HarmonicBridgesReport = level.report(pegs: level.startingPegs)
            #expect(!startReport.goalReachedInEveryStep, "entry \(number) won at the start")
            #expect(HarmonicBridgesSolver.wins(level, actions: generated.actions), "entry \(number) witness")
            #expect(generated.actions.count == tunings + 1)
            #expect(generated.difficulty == HarmonicBridgesDifficulty(level: level, plan: generated.plan))
            #expect(generated.difficulty.tunings == tunings)
            #expect(generated.difficulty.islands == level.islands.count)
            #expect(generated.difficulty.strings == level.strings.count)
            #expect(generated.difficulty.steps == level.steps.count)
            #expect(generated.difficulty.threshold == level.threshold)
            var earlier: Int = 0
            while earlier < generated.skipped {
                #expect(Self.unqualified(entry, index: earlier), "entry \(number) candidate \(earlier) qualified")
                earlier += 1
            }
            #expect(!Self.unqualified(entry, index: generated.skipped))
        }
    }

    @Test("the candidate bound is 256 and an entry no candidate can satisfy is refused with generation(number)")
    func refusal() {
        #expect(HarmonicBridgesGenerator.maxCandidates == 256)
        let base: HarmonicBridgesManifestEntry = Self.entry(1)
        // A budget of 1 leaves no tuning before the test, so no candidate can qualify.
        let impossible: HarmonicBridgesManifestEntry =
            HarmonicBridgesManifestEntry(number: base.number, seed: base.seed, band: base.band, budget: 1)
        var thrown: HarmonicBridgesError? = nil
        do {
            _ = try HarmonicBridgesGenerator.generate(impossible)
        } catch {
            thrown = error
        }
        #expect(thrown == .generation(1))
        #expect(thrown?.reasonCode == "r02-g12.generation")
        #expect(HarmonicBridgesError.generation(57).reasonCode == "r02-g12.generation")
    }

    @Test("the catalog digest is deterministic and order-sensitive")
    func catalogDigest() {
        var levels: [HarmonicBridgesLevel] = []
        for number in [1, 21, 41] {
            let entry: HarmonicBridgesManifestEntry = Self.entry(number)
            for index in 0..<32 {
                if let level = HarmonicBridgesGenerator.candidate(entry, index: index) {
                    levels.append(level)
                    break
                }
            }
        }
        #expect(levels.count == 3)
        let digest: String = HarmonicBridgesGenerator.catalogDigest(levels)
        #expect(!digest.isEmpty)
        #expect(digest == HarmonicBridgesGenerator.catalogDigest(levels))
        var swapped: [HarmonicBridgesLevel] = levels
        swapped.swapAt(0, 2)
        #expect(digest != HarmonicBridgesGenerator.catalogDigest(swapped))
        #expect(digest != HarmonicBridgesGenerator.catalogDigest(Array(levels.prefix(2))))
    }
}
