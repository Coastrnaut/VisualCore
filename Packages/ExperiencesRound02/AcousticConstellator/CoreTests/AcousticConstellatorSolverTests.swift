// AcousticConstellatorSolverTests — feature 422 (R02-G13-02) T-R02G1302-003 (FR-R02G1302-002; SC-R02G1302-001, 002,
// 005; clarifications Q2, Q5). The minimal-plan solver of Acoustic Constellator. Hand levels with minima worked out by
// hand: three stars already in step that need only their missing link (size 1); a fourth, unlinkable star one phase
// off (link limit = symbol size, so no helper link fits) that needs the missing link and one nudge (size 2); the same
// star two phases off with room for one helper link, which pulls it in at K 1 where one nudge cannot (size 2, a helper
// link); the fourth star six phases off (size 7: over `maxActions`, nil, found with `maxActions: 7`); the nudge level
// under a work bound one listen short of its plan (nil) and exactly at it; a symbol that breaks the degree limit (nil).
// Then an independent brute force on 20 seeded small generator candidates (bands 1 and 2, `SeededRandom(seed: 2_422)`):
// every multiset of plan − 1 actions over every action the play accepts (a link of every pair that is not a fixed link,
// an unlink of each of those pairs, a nudge −1 and +1 of every star; no pruning of repeats or opposite nudges), applied
// through `AcousticConstellatorPlay` (links, then unlinks, then nudges; refused actions skipped) and then a listen: none
// wins, while the plan wins (by `wins` and by the same replay), so the plan's size is the brute-force minimum.
// `smallerSets` is recounted from the option rules alone (helper links = every non-base pair, nudges ±1, filters: a
// repeated helper link, opposite nudges on one star, the degree and link limits), and `work` = `smallerSets` + the
// position of the first winning set of the plan's size in option order, judged by the level's listen. Work ≤ the work
// bound, and the plan is deterministic. Explicit types, plain loops.
import Foundation
import Testing
import VisualCoreSimulation
@testable import AcousticConstellatorCore

@Suite struct AcousticConstellatorSolverTests {
    /// The fixture seed of this feature.
    static let seed: UInt64 = 2_422
    /// The seeded candidates brute-forced.
    static let bruteCount: Int = 20
    /// The largest plan size brute-forced (multisets of at most 3 actions over at most 30 play actions).
    static let bruteMaxPlan: Int = 4

    // MARK: - Hand levels

    /// A level of the given stars (rate, phase) with symbol 0–1, 1–2 and fixed link 0–1 (the missing pair 1–2),
    /// K `coupling`, D 2, E `linkLimit`, σ 2, θ n², H 2, W 6, budget 12.
    static func level(_ id: String, _ stars: [(rate: Int, phase: Int)], coupling: Int = 1, linkLimit: Int = 2,
                      degreeLimit: Int = 2,
                      symbol: [AcousticConstellatorLink] = [AcousticConstellatorLink(a: 0, b: 1),
                                                            AcousticConstellatorLink(a: 1, b: 2)])
        -> AcousticConstellatorLevel {
        var built: [AcousticConstellatorStar] = []
        for (index, star) in stars.enumerated() {
            built.append(AcousticConstellatorStar(x: index, y: index, z: index, rate: star.rate, phase: star.phase))
        }
        let n: Int = stars.count
        do {
            return try AcousticConstellatorLevel(id: id, seed: 7, difficulty: 1, stars: built,
                                                 fixedLinks: [AcousticConstellatorLink(a: 0, b: 1)], symbol: symbol,
                                                 coupling: coupling, degreeLimit: degreeLimit, linkLimit: linkLimit,
                                                 snapLimit: 2, threshold: n * n, hold: 2, window: 6, budget: 12)
        } catch {
            preconditionFailure("hand level \(id) is valid: \(error)")
        }
    }

    /// Three stars of rate 0 at phase 0: only the missing link 1–2 is needed (a bare listen fails `missing`).
    static func onlyMissing() -> AcousticConstellatorLevel { level("only-missing", [(0, 0), (0, 0), (0, 0)]) }

    /// A fourth star of rate 0 at phase `offset`, outside the symbol; with the link limit at the symbol's size no
    /// helper link fits, so it must be nudged `offset` times (θ = 16 asks every phase to agree).
    static func fourth(_ offset: Int, linkLimit: Int = 2) -> AcousticConstellatorLevel {
        level("fourth-\(offset)-\(linkLimit)", [(0, 0), (0, 0), (0, 0), (0, offset)], linkLimit: linkLimit)
    }

    @Test func missingLinkOnly() {
        let level: AcousticConstellatorLevel = Self.onlyMissing()
        #expect(level.listen(links: level.fixedLinks, phases: level.startingPhases).won == false)
        let plan: AcousticConstellatorPlan? = AcousticConstellatorSolver.plan(level)
        #expect(plan?.links == [AcousticConstellatorLink(a: 1, b: 2)])
        #expect(plan?.nudges == [])
        #expect(plan?.size == 1)
        #expect(plan?.smallerSets == 0)
        #expect(plan?.work == 1)
        guard let plan else { return }
        #expect(AcousticConstellatorSolver.actions(plan) == [.link(1, 2), .listen])
        #expect(AcousticConstellatorSolver.wins(level, actions: AcousticConstellatorSolver.actions(plan)))
        #expect(Self.playWins(level, AcousticConstellatorSolver.actions(plan)))
        #expect(AcousticConstellatorSolver.wins(level, actions: [.listen]) == false)
    }

    @Test func oneNudge() {
        let level: AcousticConstellatorLevel = Self.fourth(1)
        let plan: AcousticConstellatorPlan? = AcousticConstellatorSolver.plan(level)
        #expect(plan?.links == [AcousticConstellatorLink(a: 1, b: 2)])
        #expect(plan?.nudges == [AcousticConstellatorNudge(star: 3, step: -1)])
        #expect(plan?.size == 2)
        // Size 0 extra: the bare missing link (1 listen, losing). Size 1: nudges (0,−1) … (3,−1) in order, the 7th wins.
        #expect(plan?.smallerSets == 1)
        #expect(plan?.work == 8)
        guard let plan else { return }
        let actions: [AcousticConstellatorAction] = AcousticConstellatorSolver.actions(plan)
        #expect(actions == [.link(1, 2), .nudge(3, -1), .listen])
        #expect(AcousticConstellatorSolver.wins(level, actions: actions))
        #expect(Self.playWins(level, actions))
        #expect(AcousticConstellatorSolver.wins(level, actions: [.link(1, 2), .listen]) == false)
        #expect(AcousticConstellatorSolver.wins(level, actions: [.nudge(3, -1), .listen]) == false)
        #expect(Self.bruteWins(level, size: 1) == false)
        #expect(Self.bruteWins(level, size: 2))
    }

    @Test func helperLink() {
        // Star 3 two phases ahead; one nudge leaves it one off. With room for one helper link, a link to star 0 (the
        // first option that fits: 0–2 leaves star 3 alone) pulls it back one step a tick at K 1.
        let level: AcousticConstellatorLevel = Self.fourth(2, linkLimit: 3)
        let plan: AcousticConstellatorPlan? = AcousticConstellatorSolver.plan(level)
        #expect(plan?.size == 2)
        #expect(plan?.nudges == [])
        #expect(plan?.links == [AcousticConstellatorLink(a: 0, b: 3), AcousticConstellatorLink(a: 1, b: 2)])
        #expect(plan?.smallerSets == 1)
        guard let plan else { return }
        let actions: [AcousticConstellatorAction] = AcousticConstellatorSolver.actions(plan)
        #expect(actions == [.link(0, 3), .link(1, 2), .listen])
        #expect(AcousticConstellatorSolver.wins(level, actions: actions))
        #expect(Self.playWins(level, actions))
        #expect(AcousticConstellatorSolver.wins(level, actions: [.link(1, 2), .nudge(3, -1), .listen]) == false)
        #expect(Self.bruteWins(level, size: 1) == false)
        // Without room for the helper, two nudges are needed: size 3.
        #expect(AcousticConstellatorSolver.plan(Self.fourth(2))?.size == 3)
        #expect(AcousticConstellatorSolver.plan(Self.fourth(2))?.nudges
            == [AcousticConstellatorNudge(star: 3, step: -1), AcousticConstellatorNudge(star: 3, step: -1)])
    }

    @Test func overMaxActionsHasNoPlan() {
        // Six phases apart: any common phase costs at least 6 nudges (3·d(0, t) + d(6, t) ≥ 6), plus the missing link.
        let level: AcousticConstellatorLevel = Self.fourth(6)
        #expect(AcousticConstellatorSolver.plan(level) == nil)
        let seven: AcousticConstellatorPlan? = AcousticConstellatorSolver.plan(level, maxActions: 7)
        #expect(seven?.size == 7)
        #expect(seven?.nudges.count == 6)
        if let seven { #expect(AcousticConstellatorSolver.wins(level, actions: AcousticConstellatorSolver.actions(seven))) }
        // The nudge level needs 2, so a limit of 1 finds nothing; the missing links alone over the limit: nil.
        #expect(AcousticConstellatorSolver.plan(Self.fourth(1), maxActions: 1) == nil)
        #expect(AcousticConstellatorSolver.plan(Self.onlyMissing(), maxActions: 0) == nil)
    }

    @Test func workBoundIsHonoured() {
        let level: AcousticConstellatorLevel = Self.fourth(1)
        #expect(AcousticConstellatorSolver.plan(level, workBound: 7) == nil)
        let exact: AcousticConstellatorPlan? = AcousticConstellatorSolver.plan(level, workBound: 8)
        #expect(exact?.work == 8)
        #expect(exact == AcousticConstellatorSolver.plan(level))
        #expect(AcousticConstellatorSolver.plan(Self.onlyMissing(), workBound: 0) == nil)
        #expect(AcousticConstellatorSolver.workBound == 400_000)
        #expect(AcousticConstellatorSolver.maxActions == 6)
    }

    @Test func symbolOverDegreeLimitHasNoPlan() {
        // Star 1 joins 0, 2 and 3 in the symbol: degree 3 above D 2, so no link set ever holds the symbol.
        let symbol: [AcousticConstellatorLink] = [AcousticConstellatorLink(a: 0, b: 1),
                                                  AcousticConstellatorLink(a: 1, b: 2),
                                                  AcousticConstellatorLink(a: 1, b: 3)]
        let level: AcousticConstellatorLevel = Self.level("star-hub", [(0, 0), (0, 0), (0, 0), (0, 0)], linkLimit: 3,
                                                          symbol: symbol)
        #expect(AcousticConstellatorSolver.plan(level) == nil)
    }

    @Test func missingPairsInPairOrder() {
        let level: AcousticConstellatorLevel = Self.fourth(1)
        #expect(AcousticConstellatorSolver.missing(level) == [AcousticConstellatorLink(a: 1, b: 2)])
    }

    // MARK: - Independent brute force on seeded generator candidates

    /// 20 generator candidates of band 1 and 2 entries with a plan of at most ``bruteMaxPlan`` actions, drawn from
    /// `SeededRandom(seed: 2_422)`: an entry of numbers 1 … 40 and a candidate index 0 … 15.
    static func seededCandidates() -> [(level: AcousticConstellatorLevel, plan: AcousticConstellatorPlan)] {
        var random = SeededRandom(seed: seed)
        var result: [(level: AcousticConstellatorLevel, plan: AcousticConstellatorPlan)] = []
        let entries: [AcousticConstellatorManifestEntry] = AcousticConstellatorManifest.entries.filter { $0.band <= 2 }
        var draws: Int = 0
        while result.count < bruteCount && draws < 2_000 {
            draws += 1
            let entry: AcousticConstellatorManifestEntry = entries[random.int(0...(entries.count - 1))]
            let index: Int = random.int(0...15)
            guard let level = AcousticConstellatorGenerator.candidate(entry, index: index),
                  let plan = AcousticConstellatorSolver.plan(level), plan.size <= bruteMaxPlan else { continue }
            result.append((level, plan))
        }
        return result
    }

    @Test func bruteForceFindsNothingSmaller() {
        let candidates = Self.seededCandidates()
        #expect(candidates.count == Self.bruteCount)
        for (level, plan) in candidates {
            let actions: [AcousticConstellatorAction] = AcousticConstellatorSolver.actions(plan)
            #expect(AcousticConstellatorSolver.wins(level, actions: actions), "\(level.fingerprint)")
            #expect(Self.playWins(level, actions), "\(level.fingerprint)")
            #expect(plan.size >= 1)
            #expect(Self.bruteWins(level, size: plan.size - 1) == false, "smaller win in \(level.fingerprint)")
            #expect(plan.work <= AcousticConstellatorSolver.workBound)
        }
    }

    @Test func smallerSetsAndWorkRecounted() {
        for (level, plan) in Self.seededCandidates() {
            let required: Int = AcousticConstellatorSolver.missing(level).count
            let extra: Int = plan.size - required
            var smaller: Int = 0
            for size in 0..<max(0, extra) { smaller += Self.validSets(level, size: size).count }
            #expect(plan.smallerSets == smaller, "\(level.fingerprint)")
            let sets: [[Int]] = Self.validSets(level, size: extra)
            var rank: Int = 0
            var first: [Int]? = nil
            for set in sets {
                rank += 1
                if Self.listenWins(level, set) {
                    first = set
                    break
                }
            }
            #expect(first != nil)
            #expect(plan.work == smaller + rank, "\(level.fingerprint)")
            if let first {
                let options: [Option] = Self.options(level)
                var links: [AcousticConstellatorLink] = AcousticConstellatorSolver.missing(level)
                var nudges: [AcousticConstellatorNudge] = []
                for index in first {
                    switch options[index] {
                    case .link(let link): links.append(link)
                    case .nudge(let star, let step): nudges.append(AcousticConstellatorNudge(star: star, step: step))
                    }
                }
                #expect(plan.links == links.sorted())
                #expect(plan.nudges == nudges.sorted { ($0.star, $0.step) < ($1.star, $1.step) })
            }
        }
    }

    @Test func deterministic() {
        for (level, plan) in Self.seededCandidates().prefix(8) {
            #expect(AcousticConstellatorSolver.plan(level) == plan)
            #expect(AcousticConstellatorSolver.plan(level) == AcousticConstellatorSolver.plan(level))
        }
        #expect(AcousticConstellatorSolver.plan(Self.fourth(2, linkLimit: 3))
            == AcousticConstellatorSolver.plan(Self.fourth(2, linkLimit: 3)))
    }

    // MARK: - Helpers (independent of the solver)

    /// Replays `actions` on a new play (begin, dismissTutorial when asked) and reports whether it ends won.
    static func playWins(_ level: AcousticConstellatorLevel, _ actions: [AcousticConstellatorAction]) -> Bool {
        var play = AcousticConstellatorPlay(level: level)
        do {
            try play.handle(.begin)
            if level.tutorial { try play.handle(.dismissTutorial) }
            for action in actions { try play.apply(action, expecting: play.fingerprint) }
        } catch {
            return false
        }
        return play.stage == .won
    }

    /// Every action the play can accept from the start: link and unlink of every pair that is not a fixed link, and
    /// a nudge −1 and +1 of every star.
    static func alphabet(_ level: AcousticConstellatorLevel) -> [AcousticConstellatorAction] {
        let n: Int = level.stars.count
        var links: [AcousticConstellatorAction] = []
        var unlinks: [AcousticConstellatorAction] = []
        for a in 0..<n {
            for b in (a + 1)..<max(a + 1, n) where !level.fixedLinks.contains(AcousticConstellatorLink(a: a, b: b)) {
                links.append(.link(a, b))
                unlinks.append(.unlink(a, b))
            }
        }
        var nudges: [AcousticConstellatorAction] = []
        for star in 0..<n {
            nudges.append(.nudge(star, -1))
            nudges.append(.nudge(star, 1))
        }
        return links + unlinks + nudges
    }

    /// Whether any multiset of `size` alphabet actions, applied through the play (in alphabet order: links, unlinks,
    /// nudges; a refused action is skipped) and followed by a listen, wins.
    static func bruteWins(_ level: AcousticConstellatorLevel, size: Int) -> Bool {
        let alphabet: [AcousticConstellatorAction] = alphabet(level)
        var indices: [Int] = Array(repeating: 0, count: size)
        guard !alphabet.isEmpty || size == 0 else { return false }
        while true {
            var play = AcousticConstellatorPlay(level: level)
            do {
                try play.handle(.begin)
                if level.tutorial { try play.handle(.dismissTutorial) }
            } catch {
                return false
            }
            for index in indices where play.stage == .playing {
                try? play.apply(alphabet[index], expecting: play.fingerprint)
            }
            if play.stage == .playing {
                try? play.apply(.listen, expecting: play.fingerprint)
                if play.stage == .won { return true }
            }
            // Next non-decreasing index tuple.
            var position: Int = size - 1
            while position >= 0 && indices[position] == alphabet.count - 1 { position -= 1 }
            if position < 0 { return false }
            let next: Int = indices[position] + 1
            for fill in position..<size { indices[fill] = next }
        }
    }

    /// An option of the recount: a helper link or a nudge.
    enum Option {
        /// A helper link.
        case link(AcousticConstellatorLink)
        /// A nudge.
        case nudge(star: Int, step: Int)
    }

    /// The fixed links and missing symbol pairs (the symbol plus the fixed links), sorted.
    static func base(_ level: AcousticConstellatorLevel) -> [AcousticConstellatorLink] {
        Array(Set(level.fixedLinks + level.symbol)).sorted()
    }

    /// Every pair not in the base (pair order), then nudges (star order, −1 then +1).
    static func options(_ level: AcousticConstellatorLevel) -> [Option] {
        let n: Int = level.stars.count
        let base: Set<AcousticConstellatorLink> = Set(base(level))
        var result: [Option] = []
        for a in 0..<n {
            for b in (a + 1)..<max(a + 1, n) where !base.contains(AcousticConstellatorLink(a: a, b: b)) {
                result.append(.link(AcousticConstellatorLink(a: a, b: b)))
            }
        }
        for star in 0..<n {
            result.append(.nudge(star: star, step: -1))
            result.append(.nudge(star: star, step: 1))
        }
        return result
    }

    /// Every multiset of `size` option indices (non-decreasing, last fastest) without a repeated helper link, without
    /// opposite nudges on one star, and whose links stay within the degree and link limits.
    static func validSets(_ level: AcousticConstellatorLevel, size: Int) -> [[Int]] {
        let options: [Option] = options(level)
        let base: [AcousticConstellatorLink] = base(level)
        var result: [[Int]] = []
        var indices: [Int] = Array(repeating: 0, count: size)
        if size > 0 && options.isEmpty { return [] }
        while true {
            var ok: Bool = true
            var links: [AcousticConstellatorLink] = base
            var shift: [Int: Set<Int>] = [:]
            for (position, index) in indices.enumerated() {
                switch options[index] {
                case .link(let link):
                    if position > 0 && indices[position - 1] == index { ok = false }
                    links.append(link)
                case .nudge(let star, let step):
                    shift[star, default: []].insert(step)
                }
            }
            for steps in shift.values where steps.count > 1 { ok = false }
            if links.count > level.linkLimit { ok = false }
            for star in 0..<level.stars.count {
                var degree: Int = 0
                for link in links where link.touches(star) { degree += 1 }
                if degree > level.degreeLimit { ok = false }
            }
            if ok { result.append(indices) }
            var position: Int = size - 1
            while position >= 0 && indices[position] == options.count - 1 { position -= 1 }
            if position < 0 { return result }
            let next: Int = indices[position] + 1
            for fill in position..<size { indices[fill] = next }
        }
    }

    /// The level's listen of the base plus the set's helper links, from the starting phases nudged by the set.
    static func listenWins(_ level: AcousticConstellatorLevel, _ set: [Int]) -> Bool {
        let options: [Option] = options(level)
        var links: [AcousticConstellatorLink] = base(level)
        var phases: [Int] = level.startingPhases
        for index in set {
            switch options[index] {
            case .link(let link): links.append(link)
            case .nudge(let star, let step): phases[star] = ((phases[star] + step) % 12 + 12) % 12
            }
        }
        return level.listen(links: links.sorted(), phases: phases).won
    }
}
