// AcousticConstellatorGeneratorTests — feature 422 (R02-G13-02) T-R02G1302-004 (FR-R02G1302-001, 005; SC-R02G1302-001,
// 003, 004). Host checks of the seeded level generator: the five band profiles equal the data model and out-of-range
// bands clamp; the derived limits (degree limit, link limit, threshold) and the level ids; candidate determinism; the
// drawing order of clarification Q1 re-implemented independently here and compared with `candidate` on (entry, index)
// pairs of every band, skipped draws included; every candidate value within its band (stars, a spanning tree of all
// stars plus one cycle pair from band 3, rates base or base + 1 modulo 12, phases, missing count, K, σ, H, window, the
// limits, tutorial, id, budget); the bare level never wins (a symbol pair is missing); `generate` on sampled entries
// (deterministic, a minimal plan in the band's range and at most budget − 1, `skipped` equal to the first qualifying
// candidate, every earlier candidate failing a filter, a winning witness, consistent difficulty metrics); the
// candidate bound and the refusal `.generation(number)` when no candidate can qualify; and the catalog digest's
// determinism and order sensitivity. Explicit types, plain loops, short runs.
import Testing
import VisualCoreSimulation
@testable import AcousticConstellatorCore

@Suite("AcousticConstellatorGenerator")
struct AcousticConstellatorGeneratorTests {
    /// The manifest numbers sampled for generation.
    static let sampledNumbers: [Int] = [1, 2, 21, 41, 61, 81]

    /// The manifest numbers sampled for the independent re-draw and the band values: four per band.
    static let redrawNumbers: [Int] = [1, 3, 13, 20, 21, 28, 35, 40, 41, 49, 52, 60, 61, 66, 73, 80, 81, 88, 94, 100]

    /// A candidate re-drawn independently of the generator, following clarification Q1's order.
    struct Drawn: Equatable {
        let starCount: Int
        let order: [Int]
        let symbol: [AcousticConstellatorLink]
        let rates: [Int]
        let phases: [Int]
        let fixed: [AcousticConstellatorLink]
        let coupling: Int
        let snapLimit: Int
        let hold: Int
    }

    /// The manifest entry numbered `number`.
    static func entry(_ number: Int) -> AcousticConstellatorManifestEntry {
        AcousticConstellatorManifest.entries[number - 1]
    }

    /// Candidate `index` of `entry` drawn independently, in clarification Q1's order (the draws only; no level is
    /// built).
    static func redraw(_ entry: AcousticConstellatorManifestEntry, index: Int) -> Drawn {
        let starRanges: [ClosedRange<Int>] = [3...4, 4...5, 5...6, 6...7, 7...8]
        let missingRanges: [ClosedRange<Int>] = [1...2, 1...2, 2...3, 2...3, 3...4]
        let band: Int = min(5, max(1, entry.band))
        var random: SeededRandom = SeededRandom(seed: SeedDerivation.derive(entry.seed, index: UInt64(index)))
        // The star count by band.
        let n: Int = random.int(starRanges[band - 1])
        // The spanning tree: a shuffled order of the stars, each star after the first joined to a drawn earlier one.
        var order: [Int] = []
        for star in 0..<n { order.append(star) }
        random.shuffle(&order)
        var symbol: [AcousticConstellatorLink] = []
        var position: Int = 1
        while position < n {
            let earlier: Int = order[random.int(0...(position - 1))]
            let u: Int = order[position]
            symbol.append(AcousticConstellatorLink(a: u < earlier ? u : earlier, b: u < earlier ? earlier : u))
            position += 1
        }
        // From band 3, one extra pair not already in the symbol, drawn from the absent pairs in pair order.
        if band >= 3 {
            var absent: [AcousticConstellatorLink] = []
            for a in 0..<n {
                var b: Int = a + 1
                while b < n {
                    let pair: AcousticConstellatorLink = AcousticConstellatorLink(a: a, b: b)
                    if !symbol.contains(pair) { absent.append(pair) }
                    b += 1
                }
            }
            symbol.append(absent[random.int(0...(absent.count - 1))])
        }
        symbol.sort()
        // A base rate 0 … 11 and each star's rate base + 0 or 1 (1 with chance 1 in 3), modulo 12.
        let base: Int = random.int(0...11)
        var rates: [Int] = []
        for _ in 0..<n {
            let faster: Int = random.int(0...2) < 1 ? 1 : 0
            rates.append((base + faster) % 12)
        }
        // Each star's starting phase 0 … 11.
        var phases: [Int] = []
        for _ in 0..<n { phases.append(random.int(0...11)) }
        // The missing count by band (at most the symbol's size) and the missing pairs as a drawn subset.
        let missingCount: Int = min(random.int(missingRanges[band - 1]), symbol.count)
        var shuffled: [AcousticConstellatorLink] = symbol
        random.shuffle(&shuffled)
        var missing: [AcousticConstellatorLink] = []
        var taken: Int = 0
        while taken < missingCount {
            missing.append(shuffled[taken])
            taken += 1
        }
        var fixed: [AcousticConstellatorLink] = []
        for pair in symbol where !missing.contains(pair) { fixed.append(pair) }
        // K 2 … 8, σ 3 … 5, H 4 … 8.
        let coupling: Int = random.int(2...8)
        let snapLimit: Int = random.int(3...5)
        let hold: Int = random.int(4...8)
        return Drawn(starCount: n, order: order, symbol: symbol, rates: rates, phases: phases, fixed: fixed,
                     coupling: coupling, snapLimit: snapLimit, hold: hold)
    }

    /// Whether `pairs` on `n` stars connect all of them (union–find).
    static func connects(_ pairs: [AcousticConstellatorLink], stars n: Int) -> Bool {
        var parent: [Int] = []
        for star in 0..<n { parent.append(star) }
        func root(_ star: Int) -> Int {
            var current: Int = star
            while parent[current] != current { current = parent[current] }
            return current
        }
        for pair in pairs {
            let ra: Int = root(pair.a)
            let rb: Int = root(pair.b)
            if ra != rb { parent[ra] = rb }
        }
        let first: Int = root(0)
        for star in 0..<n where root(star) != first { return false }
        return true
    }

    /// The largest symbol degree of `pairs` on `n` stars.
    static func maxDegree(_ pairs: [AcousticConstellatorLink], stars n: Int) -> Int {
        var degrees: [Int] = Array(repeating: 0, count: n)
        for pair in pairs {
            degrees[pair.a] += 1
            degrees[pair.b] += 1
        }
        return degrees.max() ?? 0
    }

    /// Whether candidate `index` of `entry` fails one of the conditions `generate` requires.
    static func unqualified(_ entry: AcousticConstellatorManifestEntry, index: Int) -> Bool {
        let profile: AcousticConstellatorBandProfile = .of(band: entry.band)
        guard let level = AcousticConstellatorGenerator.candidate(entry, index: index) else { return true }
        guard let plan = AcousticConstellatorSolver.plan(level) else { return true }
        let size: Int = plan.size
        if size < 1 || !profile.planRange.contains(size) || size > level.budget - 1 { return true }
        return !AcousticConstellatorSolver.wins(level, actions: AcousticConstellatorSolver.actions(plan))
    }

    @Test("the five band profiles equal the data model")
    func bandProfiles() {
        let stars: [ClosedRange<Int>] = [3...4, 4...5, 5...6, 6...7, 7...8]
        let missing: [ClosedRange<Int>] = [1...2, 1...2, 2...3, 2...3, 3...4]
        let windows: [Int] = [24, 24, 32, 40, 48]
        let plans: [ClosedRange<Int>] = [1...2, 2...3, 3...4, 4...5, 5...6]
        let cycles: [Bool] = [false, false, true, true, true]
        for band in 1...5 {
            let profile: AcousticConstellatorBandProfile = .of(band: band)
            let i: Int = band - 1
            #expect(profile.band == band)
            #expect(profile.stars == stars[i], "band \(band) stars")
            #expect(profile.missing == missing[i], "band \(band) missing")
            #expect(profile.window == windows[i], "band \(band) window")
            #expect(profile.planRange == plans[i], "band \(band) plan range")
            #expect(profile.cycle == cycles[i], "band \(band) cycle")
            #expect(AcousticConstellatorLevel.starCounts.contains(profile.stars.upperBound))
            #expect(profile.window <= AcousticConstellatorLevel.maxWindow)
            #expect(profile.planRange.upperBound <= AcousticConstellatorSolver.maxActions)
            #expect(profile.missing.upperBound <= profile.planRange.upperBound)
        }
        #expect(AcousticConstellatorBandProfile.of(band: 0) == AcousticConstellatorBandProfile.of(band: 1))
        #expect(AcousticConstellatorBandProfile.of(band: -3) == AcousticConstellatorBandProfile.of(band: 1))
        #expect(AcousticConstellatorBandProfile.of(band: 6) == AcousticConstellatorBandProfile.of(band: 5))
        #expect(AcousticConstellatorBandProfile.of(band: 99) == AcousticConstellatorBandProfile.of(band: 5))
        #expect(AcousticConstellatorGenerator.maxCandidates == 256)
        #expect(AcousticConstellatorGenerator.fasterInThree == 1)
        #expect(AcousticConstellatorGenerator.couplings == 2...8)
        #expect(AcousticConstellatorGenerator.snapLimits == 3...5)
        #expect(AcousticConstellatorGenerator.holds == 4...8)
        #expect(AcousticConstellatorGenerator.catalogID == "acoustic-constellator")
    }

    @Test("the derived limits and the level ids follow clarification Q1")
    func derivedValues() {
        #expect(AcousticConstellatorGenerator.levelID(1) == "acoustic-constellator-001")
        #expect(AcousticConstellatorGenerator.levelID(9) == "acoustic-constellator-009")
        #expect(AcousticConstellatorGenerator.levelID(42) == "acoustic-constellator-042")
        #expect(AcousticConstellatorGenerator.levelID(100) == "acoustic-constellator-100")
        let expectedThresholds: [Int] = [5, 9, 15, 21, 29, 38]
        for n in 3...8 {
            #expect(AcousticConstellatorGenerator.threshold(stars: n) == expectedThresholds[n - 3], "θ of \(n)")
            #expect(AcousticConstellatorGenerator.threshold(stars: n) == (3 * n * n) / 5)
        }
        for size in 2...10 {
            #expect(AcousticConstellatorGenerator.linkLimit(symbolSize: size) == min(16, size + 2))
        }
        #expect(AcousticConstellatorGenerator.linkLimit(symbolSize: 15) == 16)
        // A path 0–1–2: largest degree 2, limit 3. A star of degree 1 only: limit 2. A star of degree 4: limit 4.
        let path: [AcousticConstellatorLink] = [AcousticConstellatorLink(a: 0, b: 1), AcousticConstellatorLink(a: 1, b: 2)]
        #expect(AcousticConstellatorGenerator.degreeLimit(symbol: path, stars: 3) == 3)
        #expect(AcousticConstellatorGenerator.degreeLimit(symbol: [AcousticConstellatorLink(a: 0, b: 1)], stars: 2) == 2)
        var hub: [AcousticConstellatorLink] = []
        for leaf in 1...4 { hub.append(AcousticConstellatorLink(a: 0, b: leaf)) }
        #expect(AcousticConstellatorGenerator.degreeLimit(symbol: hub, stars: 5) == 4)
        hub.append(AcousticConstellatorLink(a: 0, b: 5))
        #expect(AcousticConstellatorGenerator.degreeLimit(symbol: hub, stars: 6) == 4)
    }

    @Test("candidates are deterministic and vary with the index")
    func candidateDeterminism() {
        var differing: Int = 0
        var compared: Int = 0
        for number in Self.redrawNumbers {
            let entry: AcousticConstellatorManifestEntry = Self.entry(number)
            var previous: String? = nil
            for index in 0..<10 {
                let first: AcousticConstellatorLevel? = AcousticConstellatorGenerator.candidate(entry, index: index)
                let second: AcousticConstellatorLevel? = AcousticConstellatorGenerator.candidate(entry, index: index)
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
        var built: Int = 0
        for number in Self.redrawNumbers {
            let entry: AcousticConstellatorManifestEntry = Self.entry(number)
            for index in 0..<10 {
                pairs += 1
                let drawn: Drawn = Self.redraw(entry, index: index)
                guard let level = AcousticConstellatorGenerator.candidate(entry, index: index) else {
                    // A candidate is refused only when a star of the symbol has degree 5 or more (limit 4).
                    #expect(Self.maxDegree(drawn.symbol, stars: drawn.starCount) >= 5,
                            "entry \(number) candidate \(index) refused without cause")
                    continue
                }
                built += 1
                #expect(level.stars.count == drawn.starCount, "entry \(number) candidate \(index) stars")
                #expect(level.symbol == drawn.symbol, "entry \(number) candidate \(index) symbol")
                #expect(level.naturalRates == drawn.rates, "entry \(number) candidate \(index) rates")
                #expect(level.startingPhases == drawn.phases, "entry \(number) candidate \(index) phases")
                #expect(level.fixedLinks == drawn.fixed, "entry \(number) candidate \(index) fixed links")
                #expect(level.coupling == drawn.coupling, "entry \(number) candidate \(index) K")
                #expect(level.snapLimit == drawn.snapLimit, "entry \(number) candidate \(index) σ")
                #expect(level.hold == drawn.hold, "entry \(number) candidate \(index) H")
                // The drawing positions follow the tree order: circle point k of n, depth 5 or 7 alternating.
                let points: [(x: Int, y: Int)] = AcousticConstellatorGenerator.circle[drawn.starCount - 3]
                var seen: Set<[Int]> = []
                for (position, star) in drawn.order.enumerated() {
                    let placed: AcousticConstellatorStar = level.stars[star]
                    #expect(placed.x == points[position].x, "entry \(number) candidate \(index) x")
                    #expect(placed.y == points[position].y, "entry \(number) candidate \(index) y")
                    #expect(placed.z == (position % 2 == 0 ? 5 : 7), "entry \(number) candidate \(index) z")
                    #expect(AcousticConstellatorLevel.coordinates.contains(placed.x))
                    #expect(AcousticConstellatorLevel.coordinates.contains(placed.y))
                    seen.insert([placed.x, placed.y, placed.z])
                }
                #expect(seen.count == drawn.starCount, "entry \(number) candidate \(index) distinct positions")
            }
        }
        #expect(pairs == 200)
        #expect(built > pairs / 2)
    }

    @Test("every candidate value lies within its band")
    func bandValues() {
        var checked: Int = 0
        for number in Self.redrawNumbers {
            let entry: AcousticConstellatorManifestEntry = Self.entry(number)
            let profile: AcousticConstellatorBandProfile = .of(band: entry.band)
            for index in 0..<10 {
                guard let level = AcousticConstellatorGenerator.candidate(entry, index: index) else { continue }
                checked += 1
                let n: Int = level.stars.count
                #expect(level.id == AcousticConstellatorGenerator.levelID(number))
                #expect(level.seed == entry.seed)
                #expect(level.difficulty == entry.band)
                #expect(level.budget == entry.budget)
                #expect(level.tutorial == (number <= 3), "entry \(number) tutorial")
                #expect(profile.stars.contains(n), "entry \(number) stars \(n)")
                // The symbol: a spanning tree of all stars (n − 1 pairs) plus one cycle pair from band 3.
                let expectedPairs: Int = n - 1 + (profile.cycle ? 1 : 0)
                #expect(level.symbol.count == expectedPairs, "entry \(number) symbol size")
                #expect(Set(level.symbol).count == level.symbol.count, "entry \(number) symbol repeats")
                #expect(level.symbol == level.symbol.sorted(), "entry \(number) symbol order")
                #expect(Self.connects(level.symbol, stars: n), "entry \(number) symbol spans")
                #expect(level.symbolStars.count == n, "entry \(number) symbol touches all stars")
                for pair in level.symbol {
                    #expect(pair.a < pair.b && pair.b < n, "entry \(number) pair \(pair)")
                }
                // Rates: one base, each star base or base + 1, modulo 12.
                let rates: [Int] = level.naturalRates
                var baseFound: Bool = false
                for base in 0...11 {
                    var all: Bool = true
                    for rate in rates where rate != base && rate != (base + 1) % 12 { all = false }
                    if all { baseFound = true }
                }
                #expect(baseFound, "entry \(number) rates \(rates)")
                for phase in level.startingPhases {
                    #expect(AcousticConstellatorLevel.phases.contains(phase), "entry \(number) phase")
                }
                // The missing pairs: within the band's count, the rest of the symbol fixed.
                let missing: [AcousticConstellatorLink] = AcousticConstellatorSolver.missing(level)
                #expect(profile.missing.contains(missing.count), "entry \(number) missing \(missing.count)")
                #expect(level.fixedLinks.count + missing.count == level.symbol.count)
                #expect(level.fixedLinks == level.fixedLinks.sorted(), "entry \(number) fixed order")
                for pair in level.fixedLinks { #expect(level.symbol.contains(pair)) }
                #expect(AcousticConstellatorGenerator.couplings.contains(level.coupling), "entry \(number) K")
                #expect(AcousticConstellatorGenerator.snapLimits.contains(level.snapLimit), "entry \(number) σ")
                #expect(AcousticConstellatorGenerator.holds.contains(level.hold), "entry \(number) H")
                #expect(level.window == profile.window, "entry \(number) window")
                let degree: Int = Self.maxDegree(level.symbol, stars: n)
                #expect(level.degreeLimit == min(4, max(2, degree + 1)), "entry \(number) D")
                #expect(level.linkLimit == min(16, level.symbol.count + 2), "entry \(number) E")
                #expect(level.threshold == (3 * n * n) / 5, "entry \(number) θ")
                // The bare level never wins: a symbol pair is missing.
                let bare: AcousticConstellatorListen = level.listen(links: level.fixedLinks,
                                                                    phases: level.startingPhases)
                #expect(bare.outcome == .missing(missing[0]), "entry \(number) bare level")
            }
        }
        #expect(checked > 100)
    }

    @Test("generated levels pass the filters and are deterministic")
    func generatedFilters() throws {
        for number in Self.sampledNumbers {
            let entry: AcousticConstellatorManifestEntry = Self.entry(number)
            let profile: AcousticConstellatorBandProfile = .of(band: entry.band)
            let generated: AcousticConstellatorGenerated = try AcousticConstellatorGenerator.generate(entry)
            let again: AcousticConstellatorGenerated = try AcousticConstellatorGenerator.generate(entry)
            #expect(generated == again, "entry \(number) determinism")
            #expect(generated.level.fingerprint == again.level.fingerprint, "entry \(number) fingerprint")
            #expect(generated.entry == entry)
            #expect(generated.skipped < AcousticConstellatorGenerator.maxCandidates)
            let level: AcousticConstellatorLevel = generated.level
            #expect(level == AcousticConstellatorGenerator.candidate(entry, index: generated.skipped))
            #expect(level.id == AcousticConstellatorGenerator.levelID(number))
            #expect(level.difficulty == entry.band)
            #expect(level.budget == entry.budget)
            #expect(level.tutorial == (number <= 3))
            let size: Int = generated.plan.size
            #expect(profile.planRange.contains(size), "entry \(number) plan size \(size)")
            #expect(size <= level.budget - 1, "entry \(number) budget")
            #expect(generated.plan.work <= AcousticConstellatorSolver.workBound)
            // The plan holds every missing pair.
            for pair in AcousticConstellatorSolver.missing(level) {
                #expect(generated.plan.links.contains(pair), "entry \(number) plan lacks \(pair)")
            }
            #expect(AcousticConstellatorSolver.wins(level, actions: generated.actions), "entry \(number) witness")
            #expect(generated.actions.count == size + 1)
            #expect(generated.actions.last == .listen)
            #expect(generated.difficulty == AcousticConstellatorDifficulty(level: level, plan: generated.plan))
            #expect(generated.difficulty.actions == size)
            #expect(generated.difficulty.stars == level.stars.count)
            #expect(generated.difficulty.symbolPairs == level.symbol.count)
            #expect(generated.difficulty.cycles == (profile.cycle ? 1 : 0), "entry \(number) cycles")
            #expect(generated.difficulty.window == profile.window)
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
        #expect(AcousticConstellatorGenerator.maxCandidates == 256)
        let base: AcousticConstellatorManifestEntry = Self.entry(1)
        // A budget of 1 leaves no action before the listen, so no plan of at least one action fits budget − 1.
        let impossible: AcousticConstellatorManifestEntry =
            AcousticConstellatorManifestEntry(number: base.number, seed: base.seed, band: base.band, budget: 1)
        var thrown: AcousticConstellatorError? = nil
        do {
            _ = try AcousticConstellatorGenerator.generate(impossible)
        } catch {
            thrown = error
        }
        #expect(thrown == .generation(1))
        #expect(thrown?.reasonCode == "r02-g13.generation")
        #expect(AcousticConstellatorError.generation(57).reasonCode == "r02-g13.generation")
    }

    @Test("the catalog digest is deterministic and order-sensitive")
    func catalogDigest() {
        var levels: [AcousticConstellatorLevel] = []
        for number in [1, 21, 41] {
            let entry: AcousticConstellatorManifestEntry = Self.entry(number)
            for index in 0..<32 {
                if let level = AcousticConstellatorGenerator.candidate(entry, index: index) {
                    levels.append(level)
                    break
                }
            }
        }
        #expect(levels.count == 3)
        let digest: String = AcousticConstellatorGenerator.catalogDigest(levels)
        #expect(!digest.isEmpty)
        #expect(digest == AcousticConstellatorGenerator.catalogDigest(levels))
        var swapped: [AcousticConstellatorLevel] = levels
        swapped.swapAt(0, 2)
        #expect(digest != AcousticConstellatorGenerator.catalogDigest(swapped))
        #expect(digest != AcousticConstellatorGenerator.catalogDigest(Array(levels.prefix(2))))
    }
}
