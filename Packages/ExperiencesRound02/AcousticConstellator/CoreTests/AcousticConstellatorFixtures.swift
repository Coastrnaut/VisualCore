// AcousticConstellatorFixtures — feature 421 (R02-G13-01) T-R02G1301-002 (SC-R02G1301-001 … 005). Seeded test levels
// shared by the Acoustic Constellator kernel tests. Deterministic: `SeededRandom`, no clock. Fixture seed 2_421.
//
// `fixture(_:)` builds a level around a chosen winning state. It draws 3 … 8 stars on the 12 × 12 × 12 grid, picks 3 …
// n symbol stars and joins them by a random spanning tree (each new star attached to an earlier one) plus 0 … 2 extra
// pairs among them, at most 10 pairs. The symbol stars share one natural rate and get target phases within one step of
// each other; the other stars get random rates and phases. Some (never all) symbol pairs become fixed links, with 0 … 2
// further fixed links on unused pairs, at most 6 fixed links. The degree limit is drawn from the largest degree of the
// winning graph (fixed links plus every symbol pair) to 4, the link limit from that graph's size to at most 2 more
// (never above 16); K, σ, H and W are drawn. The threshold is the largest θ in 1 … n² for which a listen of the winning
// graph from the target phases wins (on a tick in H … W); an attempt without such a θ is dropped. The starting phases
// shift 0 … 3 random stars away from their target phases by ±1 or ±2. The known winning actions are: link every symbol
// pair that is not fixed (in symbol order), nudge every shifted star back one step at a time (star order), then listen;
// the budget is that count + 0 … 5 (at most 40). Because at least one symbol pair is never fixed, a bare listen of the
// level as loaded fails `missing`, so at least one action is needed before a win. Actions are fixture tuples (`kind`
// "link" with stars a, b; "nudge" with star a and step b = ±1; "listen"), since the play's action type lives in the
// play file; `apply(_:to:)` replays them on (links, phases) and runs the level's listen.
import Foundation
import VisualCoreSimulation
@testable import AcousticConstellatorCore

/// A fixture level with its known winning actions.
struct AcousticConstellatorFixture {
    /// The level, with its starting phases and fixed links.
    let level: AcousticConstellatorLevel
    /// The known actions: links, nudges, then a listen that wins.
    let winningActions: [(kind: String, a: Int, b: Int)]
    /// The links after the known actions: the fixed links, then the placed symbol pairs.
    let winningLinks: [AcousticConstellatorLink]
    /// The starting phases after the known nudges.
    let winningPhases: [Int]
}

enum AcousticConstellatorFixtures {
    /// The fixture seed.
    static let seed: UInt64 = 2_421

    /// The fixture of seed `seed`.
    static func fixture(_ seed: UInt64) -> AcousticConstellatorFixture {
        var random = SeededRandom(seed: seed)
        for _ in 0..<512 {
            if let fixture = attempt(seed, &random) { return fixture }
        }
        preconditionFailure("fixture \(seed): no level after 512 attempts")
    }

    /// The fixtures of seeds `seed` … `seed + count − 1`.
    static func fixtures(_ count: Int, from seed: UInt64 = seed) -> [AcousticConstellatorFixture] {
        var result: [AcousticConstellatorFixture] = []
        for offset in 0..<UInt64(count) { result.append(fixture(seed &+ offset)) }
        return result
    }

    /// Replays fixture `actions` on the level's fixed links and starting phases: a link appends the pair (lower star
    /// first), a nudge shifts a starting phase by its step modulo 12, a listen runs the level's listen of the current
    /// links and phases. Returns the final links, phases and the last listen (nil when no listen was made).
    static func apply(_ actions: [(kind: String, a: Int, b: Int)], to level: AcousticConstellatorLevel)
        -> (links: [AcousticConstellatorLink], phases: [Int], listen: AcousticConstellatorListen?) {
        var links: [AcousticConstellatorLink] = level.fixedLinks
        var phases: [Int] = level.startingPhases
        var listen: AcousticConstellatorListen? = nil
        for action in actions {
            switch action.kind {
            case "link": links.append(AcousticConstellatorLink.between(action.a, action.b))
            case "unlink": links.removeAll { $0 == AcousticConstellatorLink.between(action.a, action.b) }
            case "nudge": phases[action.a] = AcousticConstellatorClock.reduce(phases[action.a] + action.b)
            case "listen": listen = level.listen(links: links, phases: phases)
            default: preconditionFailure("unknown fixture action \(action.kind)")
            }
        }
        return (links, phases, listen)
    }

    /// A random element of `values` (not empty).
    static func pick<T>(_ values: [T], _ random: inout SeededRandom) -> T {
        values[random.int(0...(values.count - 1))]
    }

    /// One attempt at a fixture of seed `seed`; nil when the drawn values do not make a winnable level.
    static func attempt(_ seed: UInt64, _ random: inout SeededRandom) -> AcousticConstellatorFixture? {
        let n: Int = random.int(3...8)
        // Symbol stars: a random subset of 3 … n stars, in a random order.
        var pool: [Int] = Array(0..<n)
        var chosen: [Int] = []
        let m: Int = random.int(3...n)
        while chosen.count < m { chosen.append(pool.remove(at: random.int(0...(pool.count - 1)))) }
        // The symbol: a spanning tree over the chosen stars, then 0 … 2 extra pairs among them.
        var symbol: [AcousticConstellatorLink] = []
        var used: Set<AcousticConstellatorLink> = []
        for index in 1..<chosen.count {
            let pair = AcousticConstellatorLink.between(chosen[index], chosen[random.int(0...(index - 1))])
            used.insert(pair)
            symbol.append(pair)
        }
        let extra: Int = random.int(0...2)
        var tries: Int = 0
        while symbol.count < min(10, chosen.count - 1 + extra) && tries < 50 {
            tries += 1
            let u: Int = pick(chosen, &random)
            let v: Int = pick(chosen, &random)
            guard u != v else { continue }
            let pair = AcousticConstellatorLink.between(u, v)
            if used.insert(pair).inserted { symbol.append(pair) }
        }
        // Rates and target phases: symbol stars share a rate and sit within one step of a base phase.
        let sharedRate: Int = random.int(0...11)
        let base: Int = random.int(0...11)
        var rates: [Int] = []
        var targets: [Int] = []
        for star in 0..<n {
            if chosen.contains(star) {
                rates.append(sharedRate)
                targets.append(AcousticConstellatorClock.reduce(base + random.int(0...1)))
            } else {
                rates.append(random.int(0...11))
                targets.append(random.int(0...11))
            }
        }
        // Fixed links: 0 … symbol.count − 1 symbol pairs (never all), then 0 … 2 unused pairs; at most 6.
        var fixedSymbol: Set<AcousticConstellatorLink> = []
        let fixedFromSymbol: Int = random.int(0...min(5, symbol.count - 1))
        var order: [AcousticConstellatorLink] = symbol
        while fixedSymbol.count < fixedFromSymbol {
            fixedSymbol.insert(order.remove(at: random.int(0...(order.count - 1))))
        }
        var fixed: [AcousticConstellatorLink] = []
        for pair in symbol where fixedSymbol.contains(pair) { fixed.append(pair) }
        let extraFixed: Int = random.int(0...2)
        tries = 0
        while fixed.count < min(6, fixedFromSymbol + extraFixed) && tries < 50 {
            tries += 1
            let u: Int = random.int(0...(n - 1))
            let v: Int = random.int(0...(n - 1))
            guard u != v else { continue }
            let pair = AcousticConstellatorLink.between(u, v)
            if used.insert(pair).inserted { fixed.append(pair) }
        }
        // The winning graph: fixed links, then the placed symbol pairs in symbol order.
        var placed: [AcousticConstellatorLink] = []
        for pair in symbol where !fixedSymbol.contains(pair) { placed.append(pair) }
        let winningLinks: [AcousticConstellatorLink] = fixed + placed
        var degrees: [Int] = Array(repeating: 0, count: n)
        for link in winningLinks {
            degrees[link.a] += 1
            degrees[link.b] += 1
        }
        let largest: Int = degrees.max() ?? 0
        guard largest <= 4 else { return nil }
        let degreeLimit: Int = random.int(max(2, largest)...4)
        let linkLimit: Int = min(16, winningLinks.count + random.int(0...2))
        let coupling: Int = random.int(1...8)
        let snapLimit: Int = random.int(2...5)
        let hold: Int = random.int(2...6)
        let window: Int = random.int(hold...min(48, hold + 12))
        // Starting phases: 0 … 3 stars shifted by ±1 or ±2 from their targets.
        var starting: [Int] = targets
        var shifts: [Int] = Array(repeating: 0, count: n)
        for _ in 0..<random.int(0...3) {
            let star: Int = random.int(0...(n - 1))
            guard shifts[star] == 0 else { continue }
            let shift: Int = pick([-2, -1, 1, 2], &random)
            shifts[star] = shift
            starting[star] = AcousticConstellatorClock.reduce(targets[star] + shift)
        }
        var actions: [(kind: String, a: Int, b: Int)] = []
        for pair in placed { actions.append(("link", pair.a, pair.b)) }
        for star in 0..<n where shifts[star] != 0 {
            let step: Int = shifts[star] > 0 ? -1 : 1
            for _ in 0..<abs(shifts[star]) { actions.append(("nudge", star, step)) }
        }
        actions.append(("listen", 0, 0))
        guard actions.count <= 40 else { return nil }
        let budget: Int = min(40, actions.count + random.int(0...5))
        var stars: [AcousticConstellatorStar] = []
        for star in 0..<n {
            stars.append(AcousticConstellatorStar(x: random.int(0...11), y: random.int(0...11), z: random.int(0...11),
                                                  rate: rates[star], phase: starting[star]))
        }
        let difficulty: Int = random.int(1...5)
        let tutorial: Bool = random.int(0...3) == 0
        // The largest threshold for which the winning state wins.
        var threshold: Int = n * n
        while threshold >= 1 {
            let trial = AcousticConstellatorListen.run(rates: rates, phases: targets, links: winningLinks,
                                                       symbol: symbol, coupling: coupling, snapLimit: snapLimit,
                                                       threshold: threshold, hold: hold, window: window)
            if trial.won { break }
            threshold -= 1
        }
        guard threshold >= 1 else { return nil }
        let level: AcousticConstellatorLevel
        do {
            level = try AcousticConstellatorLevel(
                id: "fixture-\(seed)", seed: seed, difficulty: difficulty, stars: stars, fixedLinks: fixed,
                symbol: symbol, coupling: coupling, degreeLimit: degreeLimit, linkLimit: linkLimit,
                snapLimit: snapLimit, threshold: threshold, hold: hold, window: window, budget: budget,
                tutorial: tutorial)
        } catch {
            return nil
        }
        let replay = apply(actions, to: level)
        guard replay.links == winningLinks, replay.phases == targets, replay.listen?.won == true else { return nil }
        guard level.listen(links: level.fixedLinks, phases: level.startingPhases).won == false else { return nil }
        return AcousticConstellatorFixture(level: level, winningActions: actions, winningLinks: winningLinks,
                                           winningPhases: targets)
    }

    /// The hand level: three stars of rate 1 at phases 0, 0, 1; symbol 0–1 and 1–2; fixed link 0–1; K 2, D 2, E 3,
    /// σ 2, θ `threshold`, H `hold`, W `window`, budget 5.
    static func handLevel(threshold: Int = 9, hold: Int = 3, window: Int = 6) -> AcousticConstellatorLevel {
        let stars: [AcousticConstellatorStar] = [AcousticConstellatorStar(x: 1, y: 2, z: 3, rate: 1, phase: 0),
                                                 AcousticConstellatorStar(x: 4, y: 5, z: 6, rate: 1, phase: 0),
                                                 AcousticConstellatorStar(x: 7, y: 8, z: 9, rate: 1, phase: 1)]
        do {
            return try AcousticConstellatorLevel(
                id: "hand-three", seed: 9, difficulty: 1, stars: stars,
                fixedLinks: [AcousticConstellatorLink(a: 0, b: 1)],
                symbol: [AcousticConstellatorLink(a: 0, b: 1), AcousticConstellatorLink(a: 1, b: 2)], coupling: 2,
                degreeLimit: 2, linkLimit: 3, snapLimit: 2, threshold: threshold, hold: hold, window: window,
                budget: 5)
        } catch {
            preconditionFailure("the hand level is valid: \(error)")
        }
    }
}
