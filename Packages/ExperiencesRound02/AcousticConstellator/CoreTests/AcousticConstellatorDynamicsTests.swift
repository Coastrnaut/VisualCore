// AcousticConstellatorDynamicsTests — feature 421 (R02-G13-01) T-R02G1301-003 (FR-R02G1301-002, 003, 005, 014;
// SC-R02G1301-003, 004; clarifications Q2, Q4). The exact phase rules against independent references written here,
// never calling the Core's helpers inside a reference: the coupling table equals 2·sin(πd/6) rounded (computed at run
// time); on 500 seeded levels (the fixtures of seed 2_421) with random link sets within the degree and link limits and
// random starting phases drawn with seed 2_421, every tick equals an independent step (pulls from the rounded sine,
// floor division by Double floor, the step clamped to −1 … 1), every order parameter (A, B) gives A + B√3 equal to
// |Σ e^{iπφ/6}|² within 10⁻⁹, every exact comparison agrees with a floating-point comparison away from the boundary
// and with rational bounds of √3 (989/571 < √3 < 1351/780) where they decide, every connectivity verdict equals
// repeated relaxation to a fixed point, and every listen (outcome, longest run, per-tick phases, snapped links, order
// and coherence) equals an independent listen loop written from the spec text. Labels equal a brute force over all
// orderings, are equal under random relabelling of the stars and differ for known non-isomorphic pairs. Hand cases:
// rates 1 and 3 lock at gap 2 with K = 2, a gap of σ holds and σ + 1 snaps, coherence exactly at θ and one below, a
// hold reached on the last tick wins and one tick short fails incoherent. Explicit types, plain loops, short runs.
import Foundation
import Testing
import VisualCoreSimulation
@testable import AcousticConstellatorCore

struct AcousticConstellatorDynamicsTests {
    typealias Link = AcousticConstellatorLink

    /// The test seed.
    static let seed: UInt64 = 2_421
    /// The number of seeded levels.
    static let caseCount: Int = 500
    /// The 500 seeded fixture levels, built once.
    static let fixtures: [AcousticConstellatorFixture] = AcousticConstellatorFixtures.fixtures(caseCount)

    // MARK: - Independent reference

    /// 2·sin(π·d/6) rounded to the nearest whole number, computed in floating point at run time.
    static func referenceCoupling(_ gap: Int) -> Int {
        Int((2.0 * sin(Double.pi * Double(gap) / 6.0)).rounded())
    }

    /// `value` modulo 12 in 0 … 11.
    static func referenceReduce(_ value: Int) -> Int {
        ((value % 12) + 12) % 12
    }

    /// The signed gap from phase `from` to phase `to`, reduced to −5 … 6.
    static func referenceGap(_ from: Int, _ to: Int) -> Int {
        let d: Int = referenceReduce(to - from)
        return d > 6 ? d - 12 : d
    }

    /// One reference tick: every pull from the phases before the tick, c = floor(K·P / 4) by Double floor, clamped.
    static func referenceTick(phases: [Int], rates: [Int], links: [Link], coupling: Int) -> [Int] {
        var pulls: [Int] = Array(repeating: 0, count: phases.count)
        for link in links {
            pulls[link.a] += referenceCoupling(referenceGap(phases[link.a], phases[link.b]))
            pulls[link.b] += referenceCoupling(referenceGap(phases[link.b], phases[link.a]))
        }
        var next: [Int] = []
        for star in 0..<phases.count {
            let raw: Int = Int(floor(Double(coupling * pulls[star]) / 4.0))
            let step: Int = raw < -1 ? -1 : (raw > 1 ? 1 : raw)
            next.append(referenceReduce(phases[star] + rates[star] + step))
        }
        return next
    }

    /// |Σ e^{iπφ/6}|² in floating point.
    static func referenceOrderSquared(_ phases: [Int]) -> Double {
        var re: Double = 0
        var im: Double = 0
        for phase in phases {
            re += cos(Double.pi * Double(phase) / 6.0)
            im += sin(Double.pi * Double(phase) / 6.0)
        }
        return re * re + im * im
    }

    /// A + B√3 ≥ θ: exact for B = 0 (integers), floating point otherwise (A + B√3 = θ only when B = 0, and for
    /// |A|, |B| ≤ 128 the value is never within 10⁻³ of an integer when B ≠ 0).
    static func referenceAtLeast(a: Int, b: Int, threshold: Int) -> Bool {
        if b == 0 { return a >= threshold }
        return Double(a) + Double(b) * 3.0.squareRoot() >= Double(threshold)
    }

    /// The verdict of rational bounds 989/571 < √3 < 1351/780, or nil when they do not decide.
    static func rationalAtLeast(a: Int, b: Int, threshold: Int) -> Bool? {
        // Lowest and highest values of A + B·r for r in (989/571, 1351/780), scaled by 571·780.
        let scale: Int = 571 * 780
        let low: Int = b >= 0 ? a * scale + b * 989 * 780 : a * scale + b * 1351 * 571
        let high: Int = b >= 0 ? a * scale + b * 1351 * 571 : a * scale + b * 989 * 780
        if low >= threshold * scale { return true }
        if high < threshold * scale { return false }
        return nil
    }

    /// Whether `links` join every star of `stars`, by repeated relaxation to a fixed point (no queue).
    static func referenceJoins(_ stars: [Int], links: [Link], count: Int) -> Bool {
        guard let first = stars.first else { return true }
        var reached: [Bool] = Array(repeating: false, count: count)
        reached[first] = true
        var changed: Bool = true
        while changed {
            changed = false
            for link in links where reached[link.a] != reached[link.b] {
                reached[link.a] = true
                reached[link.b] = true
                changed = true
            }
        }
        for star in stars where !reached[star] { return false }
        return true
    }

    /// A reference listen, written from clarification Q4.
    struct ExpectedListen {
        var phases: [[Int]] = []
        var snapped: [[Int]] = []
        var coherent: [Bool] = []
        var longestRun: Int = 0
        var outcome: AcousticConstellatorOutcome = .incoherent(longestRun: 0)
    }

    static func referenceListen(rates: [Int], phases start: [Int], links: [Link], symbol: [Link], coupling: Int,
                                snapLimit: Int, threshold: Int, hold: Int, window: Int) -> ExpectedListen {
        var expected = ExpectedListen()
        expected.phases = [start]
        expected.snapped = [[]]
        expected.coherent = [false]
        // Missing symbol pairs first: the lowest pair by (a, b).
        var lowestMissing: Link? = nil
        for pair in symbol where !links.contains(pair) {
            if let current = lowestMissing {
                if pair.a < current.a || (pair.a == current.a && pair.b < current.b) { lowestMissing = pair }
            } else {
                lowestMissing = pair
            }
        }
        if let missing = lowestMissing {
            expected.outcome = .missing(missing)
            return expected
        }
        var symbolStars: [Int] = []
        for pair in symbol {
            if !symbolStars.contains(pair.a) { symbolStars.append(pair.a) }
            if !symbolStars.contains(pair.b) { symbolStars.append(pair.b) }
        }
        symbolStars.sort()
        var alive: [Bool] = Array(repeating: true, count: links.count)
        var current: [Int] = start
        var run: Int = 0
        for tick in 1...window {
            var live: [Link] = []
            for index in 0..<links.count where alive[index] { live.append(links[index]) }
            current = referenceTick(phases: current, rates: rates, links: live, coupling: coupling)
            var snappedNow: [Int] = []
            for index in 0..<links.count where alive[index] {
                let gap: Int = referenceGap(current[links[index].a], current[links[index].b])
                if abs(gap) > snapLimit { snappedNow.append(index) }
            }
            for index in snappedNow { alive[index] = false }
            var left: [Link] = []
            for index in 0..<links.count where alive[index] { left.append(links[index]) }
            expected.phases.append(current)
            expected.snapped.append(snappedNow)
            if !referenceJoins(symbolStars, links: left, count: current.count) {
                expected.coherent.append(false)
                // The lowest list index snapped on this tick.
                expected.outcome = .disconnected(tick: tick, link: links[snappedNow.min() ?? 0])
                return expected
            }
            var whole: Bool = true
            for pair in symbol where !left.contains(pair) { whole = false }
            // A and B from the floating-point order parameter: A + B√3 is rounded back to its exact pair by
            // searching the small range (unique because √3 is irrational and the values are bounded).
            let value: Double = referenceOrderSquared(current)
            let coherent: Bool = whole && value >= Double(threshold) - 1e-9
                && (abs(value - Double(threshold)) > 1e-6 || exactAtLeastFromValue(value, threshold: threshold))
            expected.coherent.append(coherent)
            run = coherent ? run + 1 : 0
            expected.longestRun = max(expected.longestRun, run)
            if run >= hold {
                expected.outcome = .won(tick: tick)
                return expected
            }
        }
        expected.outcome = .incoherent(longestRun: expected.longestRun)
        return expected
    }

    /// The exact (A, B) with A + B√3 within 10⁻⁷ of `value`, by search over |A|, |B| ≤ 80.
    static func exactPair(_ value: Double) -> (a: Int, b: Int)? {
        for b in -80...80 {
            let a: Double = (value - Double(b) * 3.0.squareRoot()).rounded()
            if abs(a + Double(b) * 3.0.squareRoot() - value) < 1e-7 { return (Int(a), b) }
        }
        return nil
    }

    /// The exact comparison for a value within 10⁻⁶ of the threshold: decided on its exact pair.
    static func exactAtLeastFromValue(_ value: Double, threshold: Int) -> Bool {
        guard let pair = exactPair(value) else { return value >= Double(threshold) }
        return referenceAtLeast(a: pair.a, b: pair.b, threshold: threshold)
    }

    /// A random link list within the level's degree and link limits: the fixed links first, then (half the time)
    /// the symbol pairs that fit, then random pairs, in random order of addition.
    static func randomLinks(_ level: AcousticConstellatorLevel, _ random: inout SeededRandom) -> [Link] {
        let n: Int = level.stars.count
        var links: [Link] = level.fixedLinks
        var degrees: [Int] = Array(repeating: 0, count: n)
        for link in links {
            degrees[link.a] += 1
            degrees[link.b] += 1
        }
        func tryAdd(_ link: Link) {
            guard link.a != link.b, !links.contains(link), links.count < level.linkLimit,
                  degrees[link.a] < level.degreeLimit, degrees[link.b] < level.degreeLimit else { return }
            links.append(link)
            degrees[link.a] += 1
            degrees[link.b] += 1
        }
        if random.int(0...1) == 0 {
            for pair in random.shuffled(level.symbol) { tryAdd(pair) }
        }
        let extra: Int = random.int(0...6)
        for _ in 0..<extra {
            let u: Int = random.int(0...(n - 1))
            let v: Int = random.int(0...(n - 1))
            if u != v { tryAdd(Link(a: min(u, v), b: max(u, v))) }
        }
        return links
    }

    /// Random starting phases, one per star.
    static func randomPhases(_ count: Int, _ random: inout SeededRandom) -> [Int] {
        var phases: [Int] = []
        for _ in 0..<count { phases.append(random.int(0...11)) }
        return phases
    }

    /// The brute-force label: the smallest upper-triangle adjacency string over every ordering, by recursion.
    static func bruteLabel(stars: Int, links: [Link]) -> String {
        var adjacent: [[UInt8]] = Array(repeating: Array(repeating: 48, count: stars), count: stars)
        for link in links {
            adjacent[link.a][link.b] = 49
            adjacent[link.b][link.a] = 49
        }
        var best: [UInt8]? = nil
        var order: [Int] = []
        var used: [Bool] = Array(repeating: false, count: stars)
        var text: [UInt8] = []
        func visit() {
            if order.count == stars {
                text.removeAll(keepingCapacity: true)
                for i in 0..<stars {
                    for j in (i + 1)..<max(i + 1, stars) { text.append(adjacent[order[i]][order[j]]) }
                }
                if best == nil || text.lexicographicallyPrecedes(best!) { best = text }
                return
            }
            for star in 0..<stars where !used[star] {
                used[star] = true
                order.append(star)
                visit()
                order.removeLast()
                used[star] = false
            }
        }
        visit()
        return String(decoding: best ?? [], as: UTF8.self)
    }

    /// `links` relabelled by the star permutation `map`.
    static func relabel(_ links: [Link], _ map: [Int]) -> [Link] {
        var result: [Link] = []
        for link in links { result.append(Link(a: min(map[link.a], map[link.b]), b: max(map[link.a], map[link.b]))) }
        return result
    }

    /// Whether a Core listen equals a reference listen in every reported part.
    static func agree(_ core: AcousticConstellatorListen, _ expected: ExpectedListen) -> Bool {
        core.outcome == expected.outcome && core.longestRun == expected.longestRun
            && core.phases == expected.phases && core.snapped == expected.snapped
            && core.coherent == expected.coherent && core.order.count == expected.phases.count
    }

    // MARK: - Tables and comparisons

    /// The coupling table equals 2·sin(πd/6) rounded for every gap −5 … 6 (and its reduced aliases).
    @Test func couplingTableMatchesRoundedSine() {
        var table: [Int] = []
        for d in 0...6 { table.append(Self.referenceCoupling(d)) }
        #expect(table == [0, 1, 2, 2, 2, 1, 0])
        for d in -11...23 {
            let expected: Int = Self.referenceCoupling(Self.referenceGap(0, d))
            #expect(AcousticConstellatorClock.coupling(d) == expected, "gap \(d)")
        }
        for from in 0...11 {
            for to in 0...11 {
                #expect(AcousticConstellatorClock.gap(from, to) == Self.referenceGap(from, to))
            }
        }
    }

    /// The exact comparison over every A in −70 … 70, B in −70 … 70, θ in 1 … 64 agrees with the reference and
    /// with rational bounds of √3 wherever they decide; the hand cases on and near the boundary.
    @Test func exactComparisonAgreesEverywhere() {
        var mismatches: Int = 0
        var decidedByBounds: Int = 0
        for a in -70...70 {
            for b in -70...70 {
                for threshold in 1...64 {
                    let core: Bool = AcousticConstellatorClock.atLeast(a: a, b: b, threshold: threshold)
                    if core != Self.referenceAtLeast(a: a, b: b, threshold: threshold) { mismatches += 1 }
                    if let bound = Self.rationalAtLeast(a: a, b: b, threshold: threshold) {
                        decidedByBounds += 1
                        if bound != core { mismatches += 1 }
                    }
                    let value: Double = Double(a) + Double(b) * 3.0.squareRoot()
                    if abs(value - Double(threshold)) > 1e-6 && core != (value >= Double(threshold)) {
                        mismatches += 1
                    }
                }
            }
        }
        #expect(mismatches == 0)
        #expect(decidedByBounds > 1_200_000)
        #expect(AcousticConstellatorClock.atLeast(a: 3, b: 0, threshold: 3))
        #expect(!AcousticConstellatorClock.atLeast(a: 2, b: 0, threshold: 3))
        #expect(!AcousticConstellatorClock.atLeast(a: 1, b: 1, threshold: 3))
        #expect(AcousticConstellatorClock.atLeast(a: 2, b: 1, threshold: 3))
        #expect(AcousticConstellatorClock.atLeast(a: 4, b: -1, threshold: 2))
        #expect(!AcousticConstellatorClock.atLeast(a: 5, b: -2, threshold: 2))
        #expect(AcousticConstellatorClock.atLeast(a: 0, b: 2, threshold: 3))
        #expect(!AcousticConstellatorClock.atLeast(a: 0, b: 1, threshold: 2))
    }

    // MARK: - Seeded levels

    /// On 500 seeded levels with random links and phases: every tick equals the reference step over the whole
    /// window, every order parameter matches |Σ e^{iπφ/6}|² within 10⁻⁹, and every comparison agrees.
    @Test func ticksAndOrderMatchReference() {
        var random = SeededRandom(seed: Self.seed)
        var ticks: Int = 0
        var tickMismatches: Int = 0
        var orderMismatches: Int = 0
        var compareMismatches: Int = 0
        for fixture in Self.fixtures {
            let level: AcousticConstellatorLevel = fixture.level
            let links: [Link] = Self.randomLinks(level, &random)
            var phases: [Int] = Self.randomPhases(level.stars.count, &random)
            for _ in 0..<level.window {
                let core: [Int] = AcousticConstellatorClock.tick(phases: phases, rates: level.naturalRates,
                                                                 links: links, coupling: level.coupling)
                let expected: [Int] = Self.referenceTick(phases: phases, rates: level.naturalRates, links: links,
                                                    coupling: level.coupling)
                if core != expected { tickMismatches += 1 }
                ticks += 1
                phases = expected
                let parts: (a: Int, b: Int) = AcousticConstellatorClock.orderParts(phases)
                let value: Double = Double(parts.a) + Double(parts.b) * 3.0.squareRoot()
                if abs(value - Self.referenceOrderSquared(phases)) > 1e-9 { orderMismatches += 1 }
                for threshold in 1...(level.stars.count * level.stars.count) {
                    let core: Bool = AcousticConstellatorClock.atLeast(a: parts.a, b: parts.b, threshold: threshold)
                    if abs(value - Double(threshold)) > 1e-6 && core != (value >= Double(threshold)) {
                        compareMismatches += 1
                    }
                    if core != Self.referenceAtLeast(a: parts.a, b: parts.b, threshold: threshold) {
                        compareMismatches += 1
                    }
                }
            }
        }
        #expect(ticks > 2_000)
        #expect(tickMismatches == 0)
        #expect(orderMismatches == 0)
        #expect(compareMismatches == 0)
    }

    /// On 500 seeded levels every connectivity verdict equals repeated relaxation: the symbol's stars and random star
    /// sets over random subsets of random links.
    @Test func connectivityMatchesRelaxation() {
        var random = SeededRandom(seed: Self.seed &+ 1)
        var joined: Int = 0
        var split: Int = 0
        for fixture in Self.fixtures {
            let level: AcousticConstellatorLevel = fixture.level
            let n: Int = level.stars.count
            let links: [Link] = Self.randomLinks(level, &random) + level.symbol
            for _ in 0..<4 {
                var subset: [Link] = []
                for link in links where random.int(0...3) != 0 { subset.append(link) }
                var stars: [Int] = level.symbolStars
                if random.int(0...1) == 0 {
                    stars = []
                    for star in 0..<n where random.int(0...1) == 0 { stars.append(star) }
                }
                let core: Bool = AcousticConstellatorClock.joins(stars, links: subset, count: n)
                let expected: Bool = Self.referenceJoins(stars, links: subset, count: n)
                #expect(core == expected, "level \(level.seed) stars \(stars) links \(subset)")
                if expected { joined += 1 } else { split += 1 }
            }
        }
        #expect(joined > 100 && split > 100)
    }

    /// On 500 seeded levels every listen equals the reference listen: the random state, the fixture's starting state
    /// and its winning state; every reported order pair matches the floating-point order parameter.
    @Test func listensMatchReference() {
        var random = SeededRandom(seed: Self.seed &+ 2)
        var outcomes: [String: Int] = [:]
        var mismatches: Int = 0
        var orderMismatches: Int = 0
        for fixture in Self.fixtures {
            let level: AcousticConstellatorLevel = fixture.level
            let states: [(links: [Link], phases: [Int])] = [
                (Self.randomLinks(level, &random), Self.randomPhases(level.stars.count, &random)),
                (Self.randomLinks(level, &random), level.startingPhases),
                (level.fixedLinks, level.startingPhases),
                (fixture.winningLinks, fixture.winningPhases),
            ]
            for state in states {
                let core: AcousticConstellatorListen = level.listen(links: state.links, phases: state.phases)
                let expected: ExpectedListen = Self.referenceListen(
                    rates: level.naturalRates, phases: state.phases, links: state.links, symbol: level.symbol,
                    coupling: level.coupling, snapLimit: level.snapLimit, threshold: level.threshold,
                    hold: level.hold, window: level.window)
                if !Self.agree(core, expected) {
                    mismatches += 1
                    let where_: String = "level \(level.seed) links \(state.links) phases \(state.phases)"
                    let note: String = "\(where_): core \(core.outcome) expected \(expected.outcome)"
                    Issue.record(Comment(rawValue: note))
                }
                for (index, pair) in core.order.enumerated() where index < core.phases.count {
                    let value: Double = Double(pair[0]) + Double(pair[1]) * 3.0.squareRoot()
                    if abs(value - Self.referenceOrderSquared(core.phases[index])) > 1e-9 { orderMismatches += 1 }
                }
                let key: String
                switch core.outcome {
                case .won: key = "won"
                case .missing: key = "missing"
                case .disconnected: key = "disconnected"
                case .incoherent: key = "incoherent"
                }
                outcomes[key, default: 0] += 1
            }
            let winning: AcousticConstellatorListen = level.listen(links: fixture.winningLinks,
                                                                   phases: fixture.winningPhases)
            #expect(winning.won, "fixture \(level.seed)")
        }
        #expect(mismatches == 0)
        #expect(orderMismatches == 0)
        #expect((outcomes["won"] ?? 0) >= 500)
        #expect((outcomes["missing"] ?? 0) > 50)
        #expect((outcomes["disconnected"] ?? 0) > 10)
        #expect((outcomes["incoherent"] ?? 0) > 10)
    }

    // MARK: - Labels

    /// Labels equal the brute force for 500 random graphs on 3 … 6 stars, are invariant under random relabelling
    /// (those graphs, 40 level symbols on 3 … 6 stars, four graphs on 7 and 8 stars), and differ for known
    /// non-isomorphic pairs.
    @Test func labelsMatchBruteForceAndRelabelling() {
        var random = SeededRandom(seed: Self.seed &+ 3)
        for index in 0..<Self.caseCount {
            let n: Int = 3 + index % 4
            var links: [Link] = []
            for u in 0..<n {
                for v in (u + 1)..<n where random.int(0...2) == 0 { links.append(Link(a: u, b: v)) }
            }
            let core: String = AcousticConstellatorLabel.label(stars: n, links: links)
            #expect(core == Self.bruteLabel(stars: n, links: links), "stars \(n) links \(links)")
            #expect(core.count == n * (n - 1) / 2)
            #expect(core.filter { $0 == "1" }.count == links.count)
            let map: [Int] = random.shuffled(Array(0..<n))
            #expect(AcousticConstellatorLabel.label(stars: n, links: Self.relabel(links, map)) == core)
        }
        // The levels' symbols on 3 … 6 stars (a label on 8 stars takes ~0.15 s in a debug build).
        var symbolChecks: Int = 0
        for fixture in Self.fixtures where fixture.level.stars.count <= 6 && symbolChecks < 40 {
            symbolChecks += 1
            let level: AcousticConstellatorLevel = fixture.level
            let map: [Int] = random.shuffled(Array(0..<level.stars.count))
            #expect(AcousticConstellatorLabel.label(stars: level.stars.count, links: Self.relabel(level.symbol, map))
                    == level.symbolLabel, "fixture \(level.seed)")
        }
        #expect(symbolChecks == 40)
        // Relabelling on 7 and 8 stars: two random graphs each.
        for n in [7, 7, 8, 8] {
            var links: [Link] = []
            for u in 0..<n {
                for v in (u + 1)..<n where random.int(0...3) == 0 { links.append(Link(a: u, b: v)) }
            }
            let map: [Int] = random.shuffled(Array(0..<n))
            #expect(AcousticConstellatorLabel.label(stars: n, links: Self.relabel(links, map))
                    == AcousticConstellatorLabel.label(stars: n, links: links), "stars \(n) links \(links)")
        }
        // Path versus star on four stars (three links each).
        let path4: [Link] = [Link(a: 0, b: 1), Link(a: 1, b: 2), Link(a: 2, b: 3)]
        let star4: [Link] = [Link(a: 0, b: 1), Link(a: 0, b: 2), Link(a: 0, b: 3)]
        #expect(AcousticConstellatorLabel.label(stars: 4, links: path4)
                != AcousticConstellatorLabel.label(stars: 4, links: star4))
        // A four-cycle versus a triangle with a pendant (four links each).
        let cycle4: [Link] = [Link(a: 0, b: 1), Link(a: 1, b: 2), Link(a: 2, b: 3), Link(a: 0, b: 3)]
        let paw: [Link] = [Link(a: 0, b: 1), Link(a: 1, b: 2), Link(a: 0, b: 2), Link(a: 2, b: 3)]
        #expect(AcousticConstellatorLabel.label(stars: 4, links: cycle4)
                != AcousticConstellatorLabel.label(stars: 4, links: paw))
        // A six-cycle versus two triangles (same degree sequence).
        let cycle6: [Link] = [Link(a: 0, b: 1), Link(a: 1, b: 2), Link(a: 2, b: 3), Link(a: 3, b: 4),
                              Link(a: 4, b: 5), Link(a: 0, b: 5)]
        let triangles: [Link] = [Link(a: 0, b: 1), Link(a: 1, b: 2), Link(a: 0, b: 2), Link(a: 3, b: 4),
                                 Link(a: 4, b: 5), Link(a: 3, b: 5)]
        #expect(AcousticConstellatorLabel.label(stars: 6, links: cycle6)
                != AcousticConstellatorLabel.label(stars: 6, links: triangles))
        #expect(AcousticConstellatorLabel.label(stars: 6, links: cycle6) == Self.bruteLabel(stars: 6, links: cycle6))
        #expect(AcousticConstellatorLabel.label(stars: 6, links: triangles)
                == Self.bruteLabel(stars: 6, links: triangles))
    }

    // MARK: - Hand cases

    /// Two linked stars of rates 1 and 3 lock at a gap of 2 with K = 2: the gap opens 0 → 2 and stays.
    @Test func ratesOneAndThreeLockAtGapTwo() {
        let links: [Link] = [Link(a: 0, b: 1)]
        var phases: [Int] = [0, 0]
        for tick in 1...12 {
            let core: [Int] = AcousticConstellatorClock.tick(phases: phases, rates: [1, 3], links: links, coupling: 2)
            #expect(core == Self.referenceTick(phases: phases, rates: [1, 3], links: links, coupling: 2))
            phases = core
            #expect(Self.referenceGap(phases[0], phases[1]) == 2, "tick \(tick)")
            #expect(phases[0] == Self.referenceReduce(2 * tick - 1), "tick \(tick)")
        }
    }

    /// A gap of σ holds for the whole window; a gap of σ + 1 snaps on tick 1 and disconnects the symbol.
    @Test func snapAtSigmaAndOneMore() {
        let symbol: [Link] = [Link(a: 0, b: 1)]
        for sigma in 2...5 {
            // Rates (0, 1), K = 1: star 1's pull is negative, its step −1 cancels its rate; the gap stays.
            let holding = AcousticConstellatorListen.run(rates: [0, 1], phases: [0, sigma], links: symbol,
                                                         symbol: symbol, coupling: 1, snapLimit: sigma,
                                                         threshold: 1, hold: 7, window: 6)
            #expect(holding.snappedCount == 0, "σ \(sigma)")
            #expect(holding.outcome == .incoherent(longestRun: holding.longestRun))
            #expect(holding.phases.last == [0, sigma])
            // σ + 1 ≤ 5 stays the same way; a gap of 6 has no pull, so rates (0, 0) keep it.
            let rates: [Int] = sigma + 1 == 6 ? [0, 0] : [0, 1]
            let snapping = AcousticConstellatorListen.run(rates: rates, phases: [0, sigma + 1], links: symbol,
                                                          symbol: symbol, coupling: 1, snapLimit: sigma,
                                                          threshold: 1, hold: 7, window: 6)
            #expect(snapping.outcome == .disconnected(tick: 1, link: Link(a: 0, b: 1)), "σ \(sigma)")
            #expect(snapping.snapped == [[], [0]])
            #expect(AcousticConstellatorClock.snaps(Link(a: 0, b: 1), phases: [0, sigma], limit: sigma) == false)
            #expect(AcousticConstellatorClock.snaps(Link(a: 0, b: 1), phases: [0, sigma + 1], limit: sigma))
        }
    }

    /// Coherence exactly at θ counts; one unit above the value (θ one higher) does not. Phases 0, 0, 6 (star 2
    /// unlinked, all rates 0) give A = 1, B = 0; equal phases give A = 9.
    @Test func coherenceAtThresholdAndOneBelow() {
        let symbol: [Link] = [Link(a: 0, b: 1)]
        let at = AcousticConstellatorListen.run(rates: [0, 0, 0], phases: [0, 0, 6], links: symbol, symbol: symbol,
                                                coupling: 4, snapLimit: 2, threshold: 1, hold: 3, window: 5)
        #expect(at.order[1] == [1, 0])
        #expect(at.outcome == .won(tick: 3))
        let below = AcousticConstellatorListen.run(rates: [0, 0, 0], phases: [0, 0, 6], links: symbol, symbol: symbol,
                                                   coupling: 4, snapLimit: 2, threshold: 2, hold: 3, window: 5)
        #expect(below.outcome == .incoherent(longestRun: 0))
        let path: [Link] = [Link(a: 0, b: 1), Link(a: 1, b: 2)]
        let full = AcousticConstellatorListen.run(rates: [5, 5, 5], phases: [3, 3, 3], links: path, symbol: path,
                                                  coupling: 1, snapLimit: 2, threshold: 9, hold: 2, window: 2)
        #expect(full.order[2] == [9, 0])
        #expect(full.outcome == .won(tick: 2))
        let level: AcousticConstellatorLevel = AcousticConstellatorFixtures.handLevel(threshold: 9, hold: 2, window: 4)
        let equal = level.listen(links: path, phases: [0, 0, 0])
        #expect(equal.outcome == .won(tick: 2))
        let short = AcousticConstellatorListen.run(rates: [1, 1, 1], phases: [0, 0, 0], links: path, symbol: path,
                                                   coupling: 2, snapLimit: 2, threshold: 10, hold: 2, window: 4)
        #expect(short.outcome == .incoherent(longestRun: 0))
    }

    /// The hold reached on the last tick wins; with one tick fewer in the window the listen fails incoherent with
    /// the run it reached. Rates 1 and 3 lock at gap 2 from tick 1, where A + B√3 = 2 + 1 = 3.
    @Test func holdOnLastTickWinsAndOneShortFails() {
        let symbol: [Link] = [Link(a: 0, b: 1)]
        for hold in 2...6 {
            let win = AcousticConstellatorListen.run(rates: [1, 3], phases: [0, 0], links: symbol, symbol: symbol,
                                                     coupling: 2, snapLimit: 2, threshold: 3, hold: hold,
                                                     window: hold)
            #expect(win.outcome == .won(tick: hold), "hold \(hold)")
            #expect(win.order[1] == [3, 0])
            let short = AcousticConstellatorListen.run(rates: [1, 3], phases: [0, 0], links: symbol, symbol: symbol,
                                                       coupling: 2, snapLimit: 2, threshold: 3, hold: hold,
                                                       window: hold - 1)
            #expect(short.outcome == .incoherent(longestRun: hold - 1), "hold \(hold)")
            let expected: ExpectedListen = Self.referenceListen(rates: [1, 3], phases: [0, 0], links: symbol,
                                                           symbol: symbol, coupling: 2, snapLimit: 2, threshold: 3,
                                                           hold: hold, window: hold - 1)
            #expect(Self.agree(short, expected))
        }
    }
}
