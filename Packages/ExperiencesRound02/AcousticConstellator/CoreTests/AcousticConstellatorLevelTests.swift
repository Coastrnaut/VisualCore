// AcousticConstellatorLevelTests — feature 421 (R02-G13-01) T-R02G1301-002 (FR-R02G1301-001, 002, 003, 005, 009, 011,
// 013, 014; SC-R02G1301-001, 003, 004, 005; clarifications Q1, Q2, Q4, Q5). Levels and the exact dynamics: the reason
// codes, every range and structural refusal, the gap reduction, the coupling table against 2·sin(πd/6), the order
// parameter against |Σ e^{iπφ/6}|² in floating point, the exact comparison on its boundaries, the floored and clamped
// coupling step, snapping at σ and σ + 1, the hold reached on the last tick and one short, disconnection and missing
// pairs named, the isomorphism label, names in words, the stored form's round trip with damaged, edited and newer
// forms refused, and the seeded fixtures valid (the bare level does not win, the known actions do). Explicit types,
// plain loops, short runs.
import Foundation
import Testing
import VisualCoreSimulation
@testable import AcousticConstellatorCore

struct AcousticConstellatorLevelTests {
    typealias Link = AcousticConstellatorLink

    static func star(rate: Int = 1, phase: Int = 0, x: Int = 0, y: Int = 0, z: Int = 0) -> AcousticConstellatorStar {
        AcousticConstellatorStar(x: x, y: y, z: z, rate: rate, phase: phase)
    }

    static let threeStars: [AcousticConstellatorStar] = [star(), star(), star()]
    static let pathSymbol: [Link] = [Link(a: 0, b: 1), Link(a: 1, b: 2)]

    /// `count` stars of rate 1 at phase 0.
    static func stars(_ count: Int) -> [AcousticConstellatorStar] {
        var result: [AcousticConstellatorStar] = []
        for _ in 0..<count { result.append(star()) }
        return result
    }

    /// A valid three-star level with the given overrides.
    static func level(id: String = "constellation-one", difficulty: Int = 1,
                      stars: [AcousticConstellatorStar] = threeStars, fixed: [Link] = [], symbol: [Link] = pathSymbol,
                      coupling: Int = 2, degreeLimit: Int = 2, linkLimit: Int = 2, snapLimit: Int = 2,
                      threshold: Int = 9, hold: Int = 2, window: Int = 2,
                      budget: Int = 5) throws -> AcousticConstellatorLevel {
        try AcousticConstellatorLevel(id: id, seed: 9, difficulty: difficulty, stars: stars, fixedLinks: fixed,
                                      symbol: symbol, coupling: coupling, degreeLimit: degreeLimit,
                                      linkLimit: linkLimit, snapLimit: snapLimit, threshold: threshold, hold: hold,
                                      window: window, budget: budget)
    }

    /// Every pair (a < b) of `count` stars, row by row, up to `limit` pairs.
    static func pairs(_ count: Int, limit: Int) -> [Link] {
        var result: [Link] = []
        for a in 0..<count {
            for b in (a + 1)..<max(a + 1, count) where result.count < limit { result.append(Link(a: a, b: b)) }
        }
        return result
    }

    /// The reason codes are the stable `r02-g13.*` set.
    @Test func reasonCodesAreStable() {
        let errors: [AcousticConstellatorError] = [.level("x"), .action("x"), .stage, .stale, .newerSchema(2),
                                                   .malformed("x")]
        var codes: [String] = []
        for error in errors { codes.append(error.reasonCode) }
        #expect(codes == ["r02-g13.level", "r02-g13.action", "r02-g13.stage", "r02-g13.stale",
                          "r02-g13.newer-schema", "r02-g13.malformed"])
    }

    /// Every range and structural rule is refused with its name; the boundaries themselves are accepted.
    @Test func everyRangeIsRefusedByName() throws {
        typealias E = AcousticConstellatorError
        #expect(throws: E.level("id")) { try Self.level(id: "Constellation") }
        #expect(throws: E.level("id")) { try Self.level(id: "a--b") }
        #expect(throws: E.level("difficulty")) { try Self.level(difficulty: 0) }
        #expect(throws: E.level("difficulty")) { try Self.level(difficulty: 6) }
        #expect(throws: E.level("stars")) { try Self.level(stars: Self.stars(2), symbol: [Link(a: 0, b: 1)]) }
        #expect(throws: E.level("stars")) { try Self.level(stars: Self.stars(9)) }
        let badStars: [AcousticConstellatorStar] = [Self.star(x: 12), Self.star(y: -1), Self.star(z: 12),
                                                    Self.star(rate: 12), Self.star(rate: -1), Self.star(phase: 12),
                                                    Self.star(phase: -1)]
        for bad in badStars {
            #expect(throws: E.level("stars")) { try Self.level(stars: [bad, Self.star(), Self.star()]) }
        }
        // Fixed links: count, order, self pair, range, repeats.
        let seven: [Link] = Self.pairs(8, limit: 7)
        #expect(throws: E.level("fixedLinks")) {
            try Self.level(stars: Self.stars(8), fixed: seven, degreeLimit: 4, linkLimit: 16)
        }
        #expect(throws: E.level("fixedLinks")) { try Self.level(fixed: [Link(a: 1, b: 0)], linkLimit: 3) }
        #expect(throws: E.level("fixedLinks")) { try Self.level(fixed: [Link(a: 1, b: 1)], linkLimit: 3) }
        #expect(throws: E.level("fixedLinks")) { try Self.level(fixed: [Link(a: 0, b: 3)], linkLimit: 3) }
        #expect(throws: E.level("fixedLinks")) { try Self.level(fixed: [Link(a: -1, b: 1)], linkLimit: 3) }
        #expect(throws: E.level("fixedLinks")) {
            try Self.level(fixed: [Link(a: 0, b: 1), Link(a: 0, b: 1)], linkLimit: 3)
        }
        // Symbol: size, order, self pair, range, repeats, connectivity.
        #expect(throws: E.level("symbol")) { try Self.level(symbol: [Link(a: 0, b: 1)]) }
        let eleven: [Link] = Self.pairs(8, limit: 11)
        #expect(throws: E.level("symbol")) { try Self.level(stars: Self.stars(8), symbol: eleven, linkLimit: 16) }
        #expect(throws: E.level("symbol")) { try Self.level(symbol: [Link(a: 1, b: 0), Link(a: 1, b: 2)]) }
        #expect(throws: E.level("symbol")) { try Self.level(symbol: [Link(a: 1, b: 1), Link(a: 1, b: 2)]) }
        #expect(throws: E.level("symbol")) { try Self.level(symbol: [Link(a: 0, b: 1), Link(a: 1, b: 3)]) }
        #expect(throws: E.level("symbol")) { try Self.level(symbol: [Link(a: 0, b: 1), Link(a: 0, b: 1)]) }
        #expect(throws: E.level("symbol")) {
            try Self.level(stars: Self.stars(4), symbol: [Link(a: 0, b: 1), Link(a: 2, b: 3)])
        }
        // Numbers.
        #expect(throws: E.level("coupling")) { try Self.level(coupling: 0) }
        #expect(throws: E.level("coupling")) { try Self.level(coupling: 9) }
        #expect(throws: E.level("degreeLimit")) { try Self.level(degreeLimit: 1) }
        #expect(throws: E.level("degreeLimit")) { try Self.level(degreeLimit: 5) }
        #expect(throws: E.level("linkLimit")) { try Self.level(linkLimit: 1) }
        #expect(throws: E.level("linkLimit")) { try Self.level(linkLimit: 17) }
        #expect(throws: E.level("snapLimit")) { try Self.level(snapLimit: 1) }
        #expect(throws: E.level("snapLimit")) { try Self.level(snapLimit: 6) }
        #expect(throws: E.level("threshold")) { try Self.level(threshold: 0) }
        #expect(throws: E.level("threshold")) { try Self.level(threshold: 10) }
        #expect(throws: E.level("hold")) { try Self.level(hold: 1, window: 2) }
        #expect(throws: E.level("hold")) { try Self.level(hold: 13, window: 13) }
        #expect(throws: E.level("window")) { try Self.level(hold: 3, window: 2) }
        #expect(throws: E.level("window")) { try Self.level(window: 49) }
        #expect(throws: E.level("budget")) { try Self.level(budget: 0) }
        #expect(throws: E.level("budget")) { try Self.level(budget: 41) }
        // Fixed links over the link limit or the degree limit.
        let triangle: [Link] = [Link(a: 0, b: 1), Link(a: 1, b: 2), Link(a: 0, b: 2)]
        #expect(throws: E.level("fixedLimits")) { try Self.level(fixed: triangle, linkLimit: 2) }
        let claw: [Link] = [Link(a: 0, b: 1), Link(a: 0, b: 2), Link(a: 0, b: 3)]
        #expect(throws: E.level("fixedLimits")) {
            try Self.level(stars: Self.stars(4), fixed: claw, degreeLimit: 2, linkLimit: 3)
        }
        #expect(try Self.level(stars: Self.stars(4), fixed: claw, degreeLimit: 3, linkLimit: 3).fixedLinks == claw)
        // Every upper boundary at once is accepted; a fixed link may also be a symbol pair.
        let edgeStars: [AcousticConstellatorStar] = [Self.star(rate: 11, phase: 11, x: 11, y: 11, z: 11)]
            + Self.stars(7)
        let six: [Link] = [Link(a: 0, b: 1), Link(a: 2, b: 3), Link(a: 4, b: 5), Link(a: 6, b: 7), Link(a: 0, b: 2),
                           Link(a: 4, b: 6)]
        let ten: [Link] = [Link(a: 0, b: 1), Link(a: 1, b: 2), Link(a: 2, b: 3), Link(a: 3, b: 4), Link(a: 4, b: 5),
                           Link(a: 5, b: 6), Link(a: 6, b: 7), Link(a: 0, b: 7), Link(a: 1, b: 3), Link(a: 5, b: 7)]
        let edge: AcousticConstellatorLevel = try Self.level(stars: edgeStars, fixed: six, symbol: ten, coupling: 8,
                                                             degreeLimit: 4, linkLimit: 16, snapLimit: 5,
                                                             threshold: 64, hold: 12, window: 48, budget: 40)
        #expect(edge.threshold == 64 && edge.window == 48 && edge.symbol.count == 10 && edge.fixedLinks.count == 6)
        // Lower boundaries: no fixed links, two symbol pairs, E equal to the symbol's size, W equal to H.
        let low: AcousticConstellatorLevel = try Self.level(coupling: 1, snapLimit: 2, threshold: 1, budget: 1)
        #expect(low.linkLimit == low.symbol.count && low.window == low.hold && low.fixedLinks.isEmpty)
    }

    /// The signed gap is reduced to −5 … 6; phases reduce to 0 … 11.
    @Test func gapReduction() {
        #expect(AcousticConstellatorClock.steps == 12)
        #expect(AcousticConstellatorClock.gap(3, 3) == 0)
        #expect(AcousticConstellatorClock.gap(0, 6) == 6)
        #expect(AcousticConstellatorClock.gap(6, 0) == 6)
        #expect(AcousticConstellatorClock.gap(0, 7) == -5)
        #expect(AcousticConstellatorClock.gap(0, 5) == 5)
        #expect(AcousticConstellatorClock.gap(11, 0) == 1)
        #expect(AcousticConstellatorClock.gap(0, 11) == -1)
        #expect(AcousticConstellatorClock.gap(2, 9) == -5)
        #expect(AcousticConstellatorClock.reduce(-1) == 11 && AcousticConstellatorClock.reduce(24) == 0)
        for from in 0..<12 {
            for to in 0..<12 {
                let d: Int = AcousticConstellatorClock.gap(from, to)
                #expect((-5...6).contains(d))
                #expect(AcousticConstellatorClock.reduce(from + d) == to)
            }
        }
    }

    /// The coupling table equals 2·sin(πd/6) rounded, for every signed gap −5 … 6, and is odd.
    @Test func couplingTableMatchesTheSine() {
        for d in -5...6 {
            let expected: Int = Int((2 * sin(Double.pi * Double(d) / 6)).rounded())
            #expect(AcousticConstellatorClock.coupling(d) == expected, "d \(d)")
        }
        #expect(AcousticConstellatorClock.pullTable == [0, 1, 2, 2, 2, 1, 0])
        #expect(AcousticConstellatorClock.coupling(7) == AcousticConstellatorClock.coupling(-5))
    }

    /// n²R² = A + B√3 equals |Σ e^{iπφ/6}|² in floating point, for 500 seeded phase sets of 1 … 8 stars.
    @Test func orderParametersMatchFloatingPoint() {
        var random = SeededRandom(seed: 2_421)
        for _ in 0..<500 {
            let count: Int = random.int(1...8)
            var phases: [Int] = []
            for _ in 0..<count { phases.append(random.int(0...11)) }
            var re: Double = 0
            var im: Double = 0
            for phase in phases {
                re += cos(Double.pi * Double(phase) / 6)
                im += sin(Double.pi * Double(phase) / 6)
            }
            let parts: (a: Int, b: Int) = AcousticConstellatorClock.orderParts(phases)
            let exact: Double = Double(parts.a) + Double(parts.b) * 3.0.squareRoot()
            #expect(abs(exact - (re * re + im * im)) < 1e-9, "phases \(phases)")
        }
        let hand: [[Int]] = [[0, 0, 0], [0, 6], [0, 1], [0, 5]]
        let expected: [[Int]] = [[9, 0], [0, 0], [2, 1], [2, -1]]
        for index in 0..<hand.count {
            let parts: (a: Int, b: Int) = AcousticConstellatorClock.orderParts(hand[index])
            #expect([parts.a, parts.b] == expected[index])
        }
    }

    /// The exact comparison on its boundaries: equal, one below, B ≥ 0 and B < 0, and agreement with floating point
    /// away from the boundary.
    @Test func exactComparisonBoundaries() {
        // B = 0: exactly equal holds, one more does not.
        #expect(AcousticConstellatorClock.atLeast(a: 5, b: 0, threshold: 5))
        #expect(AcousticConstellatorClock.atLeast(a: 5, b: 0, threshold: 6) == false)
        // 2 + √3 ≈ 3.73.
        #expect(AcousticConstellatorClock.atLeast(a: 2, b: 1, threshold: 3))
        #expect(AcousticConstellatorClock.atLeast(a: 2, b: 1, threshold: 4) == false)
        // 9 − 2√3 ≈ 5.54.
        #expect(AcousticConstellatorClock.atLeast(a: 9, b: -2, threshold: 5))
        #expect(AcousticConstellatorClock.atLeast(a: 9, b: -2, threshold: 6) == false)
        // 3 − √3 ≈ 1.27; −1 + 2√3 ≈ 2.46.
        #expect(AcousticConstellatorClock.atLeast(a: 3, b: -1, threshold: 1))
        #expect(AcousticConstellatorClock.atLeast(a: 3, b: -1, threshold: 2) == false)
        #expect(AcousticConstellatorClock.atLeast(a: -1, b: 2, threshold: 2))
        #expect(AcousticConstellatorClock.atLeast(a: -1, b: 2, threshold: 3) == false)
        // B < 0 with D > 0 never holds; a negative total never reaches 1.
        #expect(AcousticConstellatorClock.atLeast(a: 0, b: -1, threshold: 1) == false)
        for a in -64...64 {
            for b in -30...30 {
                for threshold in [1, 4, 9, 25, 40, 64] {
                    let value: Double = Double(a) + Double(b) * 3.0.squareRoot()
                    guard abs(value - Double(threshold)) > 1e-6 else { continue }
                    #expect(AcousticConstellatorClock.atLeast(a: a, b: b, threshold: threshold)
                            == (value >= Double(threshold)))
                }
            }
        }
    }

    /// The coupling step is ⌊K · P / 4⌋ toward minus infinity, clamped to −1 … 1; a tick moves all stars at once.
    @Test func tickFloorsAndClamps() {
        #expect(AcousticConstellatorClock.step(pull: 1, coupling: 1) == 0)
        #expect(AcousticConstellatorClock.step(pull: -1, coupling: 1) == -1)
        #expect(AcousticConstellatorClock.step(pull: 3, coupling: 1) == 0)
        #expect(AcousticConstellatorClock.step(pull: -4, coupling: 1) == -1)
        #expect(AcousticConstellatorClock.step(pull: 4, coupling: 1) == 1)
        #expect(AcousticConstellatorClock.step(pull: 8, coupling: 8) == 1)
        #expect(AcousticConstellatorClock.step(pull: -8, coupling: 8) == -1)
        #expect(AcousticConstellatorClock.step(pull: 0, coupling: 8) == 0)
        // Two stars of rates 1 and 3 linked with K = 2 lock at a gap of 2.
        let link: [Link] = [Link(a: 0, b: 1)]
        var phases: [Int] = [0, 0]
        phases = AcousticConstellatorClock.tick(phases: phases, rates: [1, 3], links: link, coupling: 2)
        #expect(phases == [1, 3])
        for _ in 0..<6 {
            phases = AcousticConstellatorClock.tick(phases: phases, rates: [1, 3], links: link, coupling: 2)
            #expect(AcousticConstellatorClock.gap(phases[0], phases[1]) == 2)
        }
        // A gap of 1 with K = 1: the leader is not pulled (⌊1/4⌋ = 0), the follower is pulled back (⌊−1/4⌋ = −1).
        let next: [Int] = AcousticConstellatorClock.tick(phases: [0, 1], rates: [0, 0], links: link, coupling: 1)
        #expect(next == [0, 0])
        // Unlinked stars only advance; the result wraps modulo 12.
        #expect(AcousticConstellatorClock.tick(phases: [11, 5], rates: [3, 0], links: [], coupling: 8) == [2, 5])
        // Pulls come from the phases before the tick: three stars in a row pull symmetrically.
        let row: [Link] = [Link(a: 0, b: 1), Link(a: 1, b: 2)]
        #expect(AcousticConstellatorClock.pull(1, phases: [10, 0, 2], links: row) == 0)
        #expect(AcousticConstellatorClock.tick(phases: [10, 0, 2], rates: [0, 0, 0], links: row, coupling: 4)
                == [11, 0, 1])
    }

    /// A gap of σ holds and σ + 1 snaps; the snapped link is named with its tick when the symbol comes apart.
    @Test func snapAtTheLimit() {
        let link: Link = Link(a: 0, b: 1)
        #expect(AcousticConstellatorClock.snaps(link, phases: [0, 2], limit: 2) == false)
        #expect(AcousticConstellatorClock.snaps(link, phases: [0, 3], limit: 2))
        #expect(AcousticConstellatorClock.snaps(link, phases: [0, 9], limit: 2))
        #expect(AcousticConstellatorClock.snaps(link, phases: [0, 10], limit: 2) == false)
        // Rates 0 and 3 from phase 0: tick 1 gives a gap of 3.
        let snapped = AcousticConstellatorListen.run(rates: [0, 3, 3], phases: [0, 0, 0],
                                                     links: [Link(a: 1, b: 2), link],
                                                     symbol: [link, Link(a: 1, b: 2)], coupling: 1, snapLimit: 2,
                                                     threshold: 1, hold: 2, window: 6)
        #expect(snapped.outcome == .disconnected(tick: 1, link: link))
        #expect(snapped.snapped == [[], [1]])
        #expect(snapped.phases == [[0, 0, 0], [0, 3, 3]])
        #expect(snapped.coherent == [false, false])
        // σ = 3: the gap of 3 holds on tick 1; tick 2 pulls star 1 back (⌊−2/4⌋ = −1) to a gap of 5, which snaps.
        let held = AcousticConstellatorListen.run(rates: [0, 3, 3], phases: [0, 0, 0],
                                                  links: [Link(a: 1, b: 2), link], symbol: [link, Link(a: 1, b: 2)],
                                                  coupling: 1, snapLimit: 3, threshold: 1, hold: 4, window: 6)
        #expect(held.snapped[1] == [])
        #expect(held.phases[2] == [0, 5, 6])
        #expect(held.outcome == .disconnected(tick: 2, link: link))
        // Two links snapped on the same tick: the lowest index is named.
        let both = AcousticConstellatorListen.run(rates: [0, 6, 0], phases: [0, 0, 0],
                                                  links: [Link(a: 1, b: 2), link], symbol: [link, Link(a: 1, b: 2)],
                                                  coupling: 1, snapLimit: 2, threshold: 1, hold: 2, window: 6)
        #expect(both.snapped[1] == [0, 1])
        #expect(both.outcome == .disconnected(tick: 1, link: Link(a: 1, b: 2)))
        // A snapped symbol pair with the symbol still joined through other links: not disconnected, not coherent.
        let bypass = AcousticConstellatorListen.run(rates: [0, 4, 2], phases: [0, 0, 0],
                                                    links: [Link(a: 0, b: 1), Link(a: 1, b: 2), Link(a: 0, b: 2)],
                                                    symbol: [Link(a: 0, b: 1), Link(a: 1, b: 2)], coupling: 1,
                                                    snapLimit: 2, threshold: 1, hold: 2, window: 1)
        #expect(bypass.snapped == [[], [0]])
        #expect(bypass.coherent == [false, false])
        #expect(bypass.outcome == .incoherent(longestRun: 0))
    }

    /// The hold reached on the last tick of the window wins; one tick short fails incoherent with the run.
    @Test func holdOnTheLastTick() {
        let level: AcousticConstellatorLevel = AcousticConstellatorFixtures.handLevel(threshold: 9, hold: 3, window: 3)
        let links: [Link] = [Link(a: 0, b: 1), Link(a: 1, b: 2)]
        let won: AcousticConstellatorListen = level.listen(links: links, phases: level.startingPhases)
        #expect(won.phases == [[0, 0, 1], [1, 1, 1], [2, 2, 2], [3, 3, 3]])
        #expect(won.order == [[5, 2], [9, 0], [9, 0], [9, 0]])
        #expect(won.coherent == [false, true, true, true])
        #expect(won.outcome == .won(tick: 3))
        #expect(won.longestRun == 3 && won.currentRun == 3 && won.won)
        let short = AcousticConstellatorListen.run(rates: level.naturalRates, phases: level.startingPhases,
                                                   links: links, symbol: level.symbol, coupling: level.coupling,
                                                   snapLimit: level.snapLimit, threshold: 9, hold: 4, window: 3)
        #expect(short.outcome == .incoherent(longestRun: 3))
        #expect(short.phases.count == 4 && short.won == false)
        // Coherence exactly at θ counts; one above never does.
        let above = AcousticConstellatorListen.run(rates: level.naturalRates, phases: level.startingPhases,
                                                   links: links, symbol: level.symbol, coupling: level.coupling,
                                                   snapLimit: level.snapLimit, threshold: 10, hold: 3, window: 3)
        #expect(above.outcome == .incoherent(longestRun: 0))
        #expect(above.coherent == [false, false, false, false])
        // An early win stops the arrays at the winning tick.
        let early: AcousticConstellatorListen = AcousticConstellatorFixtures.handLevel(hold: 2, window: 10)
            .listen(links: links, phases: level.startingPhases)
        #expect(early.outcome == .won(tick: 2) && early.phases.count == 3)
    }

    /// A missing symbol pair is named (the lowest), before any tick.
    @Test func missingPairIsNamed() {
        let level: AcousticConstellatorLevel = AcousticConstellatorFixtures.handLevel()
        let bare: AcousticConstellatorListen = level.listen(links: level.fixedLinks, phases: level.startingPhases)
        #expect(bare.outcome == .missing(Link(a: 1, b: 2)))
        #expect(bare.phases == [[0, 0, 1]] && bare.snapped == [[]] && bare.coherent == [false])
        #expect(bare.order == [[5, 2]] && bare.longestRun == 0)
        let none: AcousticConstellatorListen = level.listen(links: [], phases: level.startingPhases)
        #expect(none.outcome == .missing(Link(a: 0, b: 1)))
        let reversed = AcousticConstellatorListen.run(rates: [0, 0, 0], phases: [0, 0, 0], links: [],
                                                      symbol: [Link(a: 1, b: 2), Link(a: 0, b: 2)], coupling: 1,
                                                      snapLimit: 2, threshold: 1, hold: 2, window: 2)
        #expect(reversed.outcome == .missing(Link(a: 0, b: 2)))
    }

    /// The label is equal for isomorphic graphs and different for non-isomorphic ones.
    @Test func labelsAreCanonical() {
        typealias L = AcousticConstellatorLabel
        #expect(L.label(stars: 3, links: []) == "000")
        #expect(L.label(stars: 3, links: [Link(a: 0, b: 1), Link(a: 1, b: 2)]) == "011")
        #expect(L.label(stars: 3, links: [Link(a: 0, b: 1), Link(a: 0, b: 2)]) == "011")
        #expect(L.label(stars: 3, links: [Link(a: 0, b: 1), Link(a: 1, b: 2), Link(a: 0, b: 2)]) == "111")
        let path: [Link] = [Link(a: 0, b: 1), Link(a: 1, b: 2), Link(a: 2, b: 3)]
        let relabelled: [Link] = [Link(a: 2, b: 0), Link(a: 0, b: 3), Link(a: 3, b: 1)].map { Link.between($0.a, $0.b) }
        let claw: [Link] = [Link(a: 0, b: 1), Link(a: 0, b: 2), Link(a: 0, b: 3)]
        #expect(L.label(stars: 4, links: path) == L.label(stars: 4, links: relabelled))
        #expect(L.label(stars: 4, links: path) != L.label(stars: 4, links: claw))
        #expect(L.label(stars: 4, links: path).count == 6)
        // Eight stars: a ring relabelled by a seeded permutation keeps its label; a ring and two squares differ.
        var ring: [Link] = []
        for i in 0..<8 { ring.append(Link.between(i, (i + 1) % 8)) }
        var permutation: [Int] = Array(0..<8)
        var random = SeededRandom(seed: 2_421)
        var i: Int = 7
        while i > 0 {
            permutation.swapAt(i, random.int(0...i))
            i -= 1
        }
        var moved: [Link] = []
        for link in ring { moved.append(Link.between(permutation[link.a], permutation[link.b])) }
        var squares: [Link] = []
        for i in 0..<4 { squares.append(Link.between(i, (i + 1) % 4)) }
        for i in 0..<4 { squares.append(Link.between(4 + i, 4 + (i + 1) % 4)) }
        let ringLabel: String = L.label(stars: 8, links: ring)
        #expect(ringLabel == L.label(stars: 8, links: moved))
        #expect(ringLabel != L.label(stars: 8, links: squares))
        #expect(ringLabel.count == 28)
        #expect(ringLabel.filter { $0 == "1" }.count == 8)
    }

    /// Stars, links and progress in words (FR-R02G1301-013).
    @Test func namesAreWords() {
        let level: AcousticConstellatorLevel = AcousticConstellatorFixtures.handLevel(threshold: 9, hold: 3, window: 3)
        #expect(level.starName(2, phase: 7) == "star 2, rate 1, phase 7")
        #expect(level.linkName(Link(a: 0, b: 2), phases: [0, 0, 10]) == "link star 0 to star 2, gap 2")
        #expect(level.linkName(Link(a: 1, b: 2), phases: [0, 0, 1]) == "link star 1 to star 2, gap 1")
        let links: [Link] = [Link(a: 0, b: 1), Link(a: 1, b: 2)]
        let won: AcousticConstellatorListen = level.listen(links: links, phases: level.startingPhases)
        #expect(level.progressDescription(listen: won, actionsLeft: 3)
                == "tick 3 of 3: order 9, threshold 9, coherent, run 3 of 3, 0 links snapped; won on tick 3; "
                + "3 actions left")
        let bare: AcousticConstellatorListen = level.listen(links: level.fixedLinks, phases: level.startingPhases)
        #expect(level.progressDescription(listen: bare, actionsLeft: 1)
                == "tick 0 of 3: order 5 plus 2 root 3, threshold 9, not coherent, run 0 of 3, 0 links snapped; "
                + "missing link star 1 to star 2; 1 action left")
        let wide = AcousticConstellatorListen.run(rates: [0, 6, 0], phases: [0, 0, 0], links: links, symbol: links,
                                                  coupling: 1, snapLimit: 2, threshold: 1, hold: 2, window: 3)
        #expect(level.progressDescription(listen: wide, actionsLeft: 0)
                == "tick 1 of 3: order 1, threshold 9, not coherent, run 0 of 3, 2 links snapped; "
                + "disconnected on tick 1 by link star 0 to star 1; 0 actions left")
        let split = AcousticConstellatorListen.run(rates: [0, 0, 0], phases: [0, 5, 0], links: [], symbol: [],
                                                   coupling: 1, snapLimit: 5, threshold: 9, hold: 2, window: 2)
        #expect(level.progressDescription(listen: split, actionsLeft: 2).contains("order 5 minus 2 root 3"))
        #expect(level.progressDescription(listen: split, actionsLeft: 2).contains("incoherent, longest run 0"))
    }

    /// The stored form round-trips with its fingerprint; damaged, edited and newer forms are refused.
    @Test func storedFormRoundTripsAndRefusesDamage() throws {
        let level: AcousticConstellatorLevel = AcousticConstellatorFixtures.handLevel()
        let data: Data = level.encoded()
        #expect(try AcousticConstellatorLevel.decode(data) == level)
        let text: String = try #require(String(data: data, encoding: .utf8))
        #expect(text.hasPrefix("{\"budget\":5,\"coupling\":2,\"degreeLimit\":2,\"difficulty\":1,\"fingerprint\":"))
        #expect(text.contains("\"fixedLinks\":[[0,1]],\"hold\":3,\"id\":\"hand-three\",\"linkLimit\":3,\"schema\":1,"))
        #expect(text.contains("\"stars\":[[1,2,3,1,0],[4,5,6,1,0],[7,8,9,1,1]],\"symbol\":[[0,1],[1,2]]"))
        #expect(text.hasSuffix("\"threshold\":9,\"tutorial\":false,\"window\":6}"))
        #expect(level.fingerprint.count == 64)
        let decoded: AcousticConstellatorLevel = try JSONDecoder().decode(AcousticConstellatorLevel.self, from: data)
        #expect(decoded == level)
        typealias E = AcousticConstellatorError
        #expect(throws: E.malformed("unreadable")) { try AcousticConstellatorLevel.decode(Data("{".utf8)) }
        let newer: String = text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2")
        #expect(throws: E.newerSchema(2)) { try AcousticConstellatorLevel.decode(Data(newer.utf8)) }
        let older: String = text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":0")
        #expect(throws: E.malformed("schema 0")) { try AcousticConstellatorLevel.decode(Data(older.utf8)) }
        let edited: String = text.replacingOccurrences(of: "\"budget\":5", with: "\"budget\":6")
        #expect(throws: E.malformed("fingerprint")) { try AcousticConstellatorLevel.decode(Data(edited.utf8)) }
        let rephased: String = text.replacingOccurrences(of: "[7,8,9,1,1]", with: "[7,8,9,1,0]")
        #expect(throws: E.malformed("fingerprint")) { try AcousticConstellatorLevel.decode(Data(rephased.utf8)) }
        let broken: String = text.replacingOccurrences(of: "\"threshold\":9", with: "\"threshold\":10")
        #expect(throws: E.malformed("r02-g13.level")) { try AcousticConstellatorLevel.decode(Data(broken.utf8)) }
        let selfPair: String = text.replacingOccurrences(of: "[[0,1],[1,2]]", with: "[[0,1],[1,1]]")
        #expect(throws: E.malformed("r02-g13.level")) { try AcousticConstellatorLevel.decode(Data(selfPair.utf8)) }
        let repeated: String = text.replacingOccurrences(of: "[[0,1],[1,2]]", with: "[[0,1],[0,1]]")
        #expect(throws: E.malformed("r02-g13.level")) { try AcousticConstellatorLevel.decode(Data(repeated.utf8)) }
        let missing: String = text.replacingOccurrences(of: ",\"tutorial\":false", with: "")
        #expect(throws: E.malformed("unreadable")) { try AcousticConstellatorLevel.decode(Data(missing.utf8)) }
        let shortStar: String = text.replacingOccurrences(of: "[7,8,9,1,1]", with: "[7,8,9,1]")
        #expect(throws: E.malformed("unreadable")) { try AcousticConstellatorLevel.decode(Data(shortStar.utf8)) }
        let longLink: String = text.replacingOccurrences(of: "\"fixedLinks\":[[0,1]]", with: "\"fixedLinks\":[[0,1,2]]")
        #expect(throws: E.malformed("unreadable")) { try AcousticConstellatorLevel.decode(Data(longLink.utf8)) }
        let edits: [String] = [newer, edited, broken]
        for edit in edits {
            #expect(throws: DecodingError.self) {
                try JSONDecoder().decode(AcousticConstellatorLevel.self, from: Data(edit.utf8))
            }
        }
    }

    /// The 200 seeded fixtures are valid levels: a bare listen of the level as loaded does not win, the known actions
    /// fit the budget and win on their listen (on a tick in H … W), and each level round-trips.
    @Test func fixturesAreValid() throws {
        let fixtures: [AcousticConstellatorFixture] = AcousticConstellatorFixtures.fixtures(200)
        var starCounts: Set<Int> = []
        var withNudges: Int = 0
        var withFixed: Int = 0
        for fixture in fixtures {
            let level: AcousticConstellatorLevel = fixture.level
            let bare: AcousticConstellatorListen = level.listen(links: level.fixedLinks, phases: level.startingPhases)
            #expect(bare.won == false, "fixture \(level.seed) wins at load")
            #expect(fixture.winningActions.count >= 2)
            #expect(fixture.winningActions.last?.kind == "listen")
            #expect(fixture.winningActions.count <= level.budget)
            let replay = AcousticConstellatorFixtures.apply(fixture.winningActions, to: level)
            #expect(replay.links == fixture.winningLinks && replay.phases == fixture.winningPhases)
            var wonTick: Int = -1
            if case .won(let tick) = replay.listen?.outcome { wonTick = tick }
            #expect(wonTick >= level.hold && wonTick <= level.window, "fixture \(level.seed)")
            #expect(replay.links.count <= level.linkLimit)
            #expect(try AcousticConstellatorLevel.decode(level.encoded()) == level)
            starCounts.insert(level.stars.count)
            for action in fixture.winningActions where action.kind == "nudge" {
                #expect(action.b == 1 || action.b == -1)
            }
            if fixture.winningActions.contains(where: { $0.kind == "nudge" }) { withNudges += 1 }
            if !level.fixedLinks.isEmpty { withFixed += 1 }
        }
        #expect(starCounts == [3, 4, 5, 6, 7, 8])
        #expect(withNudges > 0 && withFixed > 0)
    }
}
