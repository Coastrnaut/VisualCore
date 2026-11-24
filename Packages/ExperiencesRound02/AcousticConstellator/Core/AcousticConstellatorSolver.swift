// AcousticConstellatorSolver — feature 422 (R02-G13-02) T-R02G1302-003 (FR-R02G1302-002; SC-R02G1302-001, 002, 005;
// clarification Q2). The minimal-plan solver of Acoustic Constellator. A listen loses `missing` while any symbol pair is
// unlinked, so every winning plan links every missing symbol pair (the symbol pairs that are not fixed links); those
// are always in the plan. The other useful actions are the options: helper links (the pairs not linked by the fixed
// links and the missing symbol pairs, in pair order) and then nudges (star order, −1 then +1). Unlinking is never
// useful (the player starts with no links of their own) and opposite nudges on one star cancel, so a minimal plan holds
// neither. The solver tries e = 0, 1, 2, … extra actions: every multiset of e options in option order (the option
// indices non-decreasing, the last fastest), skipping a set that repeats a helper link, holds opposite nudges on one
// star, or whose links (fixed, missing and helper) take a star above the degree limit or number more than the link
// limit. Each remaining set is one listen: the kernel's listen of all its links, sorted, from the starting phases
// nudged by the set (modulo 12). The first set whose listen wins is the plan. A plan has at most `maxActions` actions
// (the missing links included); work is the listens run, counted and bounded at 400 000; over either bound there is
// no plan. Every pruned set extends only to pruned sets (links only add degree and count; a repeat or an opposite pair
// stays), so the sets are walked depth first with pruning, which visits exactly the remaining sets in that order; a
// helper link whose star is already at the degree limit, or any helper link when the link limit is already reached,
// can never be in a remaining set and is left out of the options without changing the walk. The minimality proof is
// that every remaining set of every smaller size was listened to and lost: their count (the listens run before the
// plan's size was reached) is stored as `smallerSets`. The witness is the plan's links in pair order, then its nudges
// in star order (one action per step), then one listen, replayed through the kernel's play. Integers only; no clock,
// no random source.
//
// Feature 425 (R02-G13-05) T-R02G1305-002 (FR-R02G1305-002; clarification Q1, research R1): the same search runs from a
// state of play through `plan(_:links:phases:maxActions:workBound:)` — the given links (fixed and placed) in place of
// the fixed links and the given phases in place of the starting phases; the plan's links exclude the given ones.
// `plan(_:maxActions:workBound:)` is that entry at the level's fixed links and starting phases, so certified plans and
// witnesses are unchanged.
import Foundation

/// One nudge of a plan: a star (0-based) and a step of −1 or +1.
public struct AcousticConstellatorNudge: Sendable, Hashable, Codable {
    /// The star, 0-based.
    public let star: Int
    /// The step, −1 or +1.
    public let step: Int

    /// A nudge of the given values (not checked).
    public init(star: Int, step: Int) {
        self.star = star
        self.step = step
    }
}

/// A certified minimal plan: its links and nudges, the sets of smaller sizes tried (all losing) and the work spent.
public struct AcousticConstellatorPlan: Sendable, Equatable, Codable {
    /// The links the player makes: every missing symbol pair and the helper links, together in pair order.
    public let links: [AcousticConstellatorLink]
    /// The nudges, one per step, in star order (a star nudged twice the same way appears twice).
    public let nudges: [AcousticConstellatorNudge]
    /// The sets of smaller sizes that were listened to, none of which wins (the minimality proof).
    public let smallerSets: Int
    /// The listens run in all, the winning one included.
    public let work: Int

    /// A plan of the given values (not checked).
    public init(links: [AcousticConstellatorLink], nudges: [AcousticConstellatorNudge], smallerSets: Int, work: Int) {
        self.links = links
        self.nudges = nudges
        self.smallerSets = smallerSets
        self.work = work
    }

    /// The actions of the plan before the listen: its links plus its nudges.
    public var size: Int { links.count + nudges.count }
}

/// The minimal-plan solver (clarification Q2).
public enum AcousticConstellatorSolver {
    /// The most listens a plan may run.
    public static let workBound: Int = 400_000
    /// The most actions a plan holds before the listen (the missing links included).
    public static let maxActions: Int = 6

    /// One extra option: a helper link or a nudge.
    enum Option: Equatable {
        /// A helper link.
        case link(AcousticConstellatorLink)
        /// A nudge of `star` by `step`.
        case nudge(star: Int, step: Int)
    }

    /// The symbol pairs that are not fixed links, in pair order: every winning plan links them.
    public static func missing(_ level: AcousticConstellatorLevel) -> [AcousticConstellatorLink] {
        let fixed: Set<AcousticConstellatorLink> = Set(level.fixedLinks)
        return level.symbol.filter { !fixed.contains($0) }.sorted()
    }

    /// The minimal plan of `level`: the first winning set of the smallest size, with the count of every set of a
    /// smaller size listened to. Nil when the fixed links and the missing symbol pairs already break the degree or link
    /// limit, when no set of at most `maxActions` actions wins, or when more than `workBound` listens would be run. It is
    /// ``plan(_:links:phases:maxActions:workBound:)`` at the level's fixed links and starting phases.
    public static func plan(_ level: AcousticConstellatorLevel, maxActions: Int = maxActions,
                            workBound: Int = workBound) -> AcousticConstellatorPlan? {
        plan(level, links: level.fixedLinks, phases: level.startingPhases, maxActions: maxActions,
             workBound: workBound)
    }

    /// The minimal plan of `level` from a state of play (feature 425 (R02-G13-05) T-R02G1305-002, clarification Q1):
    /// the search of ``plan(_:maxActions:workBound:)`` with `links` (the fixed links and any links already placed) in
    /// place of the fixed links and `phases` (one per star, 0 … 11) in place of the starting phases. The base is `links`
    /// plus the symbol pairs they lack (always in the plan, in pair order); the options are the helper links the degree
    /// and link limits still allow and the ±1 nudges; every listen runs from `phases` nudged by the set. The plan's links
    /// are the links to add (they exclude `links`), in pair order; nudges are relative to `phases`. Nil when `phases`
    /// does not hold one phase per star in 0 … 11, when `links` names a star out of range or a repeated pair, when the
    /// base breaks the degree or link limit, when no set of at most `maxActions` actions wins, or when more than
    /// `workBound` listens would be run. Not limited to six links: a play may hold more than a level's fixed links.
    public static func plan(_ level: AcousticConstellatorLevel, links given: [AcousticConstellatorLink], phases: [Int],
                            maxActions: Int = maxActions, workBound: Int = workBound) -> AcousticConstellatorPlan? {
        let n: Int = level.stars.count
        guard phases.count == n, phases.allSatisfy({ AcousticConstellatorLevel.phases.contains($0) }) else { return nil }
        let givenSet: Set<AcousticConstellatorLink> = Set(given)
        guard givenSet.count == given.count,
              given.allSatisfy({ $0.a >= 0 && $0.a < $0.b && $0.b < n }) else { return nil }
        let required: [AcousticConstellatorLink] = level.symbol.filter { !givenSet.contains($0) }.sorted()
        let base: [AcousticConstellatorLink] = (given + required).sorted()
        let baseSet: Set<AcousticConstellatorLink> = Set(base)
        var degrees: [Int] = Array(repeating: 0, count: n)
        for link in base {
            degrees[link.a] += 1
            degrees[link.b] += 1
        }
        guard base.count <= level.linkLimit, degrees.allSatisfy({ $0 <= level.degreeLimit }) else { return nil }
        guard maxActions >= 0, required.count <= maxActions else { return nil }
        var options: [Option] = []
        if base.count < level.linkLimit {
            for a in 0..<n {
                for b in (a + 1)..<max(a + 1, n) {
                    let link = AcousticConstellatorLink(a: a, b: b)
                    if baseSet.contains(link) { continue }
                    if degrees[a] >= level.degreeLimit || degrees[b] >= level.degreeLimit { continue }
                    options.append(.link(link))
                }
            }
        }
        for star in 0..<n {
            options.append(.nudge(star: star, step: -1))
            options.append(.nudge(star: star, step: 1))
        }
        var search = Search(level: level, phases: phases, base: base, degrees: degrees, options: options,
                            workBound: workBound)
        for extra in 0...(maxActions - required.count) {
            let smaller: Int = search.work
            switch search.walk(size: extra) {
            case .over:
                return nil
            case .won(let chosen):
                var links: [AcousticConstellatorLink] = required
                var nudges: [AcousticConstellatorNudge] = []
                for index in chosen {
                    switch options[index] {
                    case .link(let link): links.append(link)
                    case .nudge(let star, let step): nudges.append(AcousticConstellatorNudge(star: star, step: step))
                    }
                }
                links.sort()
                nudges.sort { ($0.star, $0.step) < ($1.star, $1.step) }
                return AcousticConstellatorPlan(links: links, nudges: nudges, smallerSets: smaller, work: search.work)
            case .lost:
                continue
            }
        }
        return nil
    }

    /// The witness actions of `plan`: its links in pair order, then its nudges in star order (one per step), then one
    /// listen.
    public static func actions(_ plan: AcousticConstellatorPlan) -> [AcousticConstellatorAction] {
        var result: [AcousticConstellatorAction] = []
        for link in plan.links.sorted() { result.append(.link(link.a, link.b)) }
        for nudge in plan.nudges.sorted(by: { ($0.star, $0.step) < ($1.star, $1.step) }) {
            result.append(.nudge(nudge.star, nudge.step))
        }
        result.append(.listen)
        return result
    }

    /// Whether `actions`, applied to a new play of `level` (after `begin`, and `dismissTutorial` when the level has a
    /// tutorial), are all accepted and win on the last one.
    public static func wins(_ level: AcousticConstellatorLevel, actions: [AcousticConstellatorAction]) -> Bool {
        var play = AcousticConstellatorPlay(level: level)
        do {
            try play.handle(.begin)
            if play.stage == .tutorial { try play.handle(.dismissTutorial) }
            for (index, action) in actions.enumerated() {
                guard play.stage == .playing else { return false }
                try play.apply(action, expecting: play.fingerprint)
                if play.stage == .won { return index == actions.count - 1 }
            }
        } catch {
            return false
        }
        return false
    }

    /// What one size of the walk found.
    enum Step: Equatable {
        /// A set won; its option indices, non-decreasing.
        case won([Int])
        /// Every remaining set of the size lost.
        case lost
        /// The work bound was passed.
        case over
    }

    /// The depth-first walk over the remaining sets of one size, in option order, with the listens counted.
    struct Search {
        /// The level.
        let level: AcousticConstellatorLevel
        /// The phases every listen starts from before the set's nudges, one per star.
        let phases: [Int]
        /// The given links and the missing symbol pairs, sorted.
        let base: [AcousticConstellatorLink]
        /// The degree of every star under `base`.
        let degrees: [Int]
        /// The extra options, helper links then nudges.
        let options: [Option]
        /// The most listens allowed.
        let workBound: Int
        /// The listens run so far.
        private(set) var work: Int = 0

        /// A walk of the given values.
        init(level: AcousticConstellatorLevel, phases: [Int], base: [AcousticConstellatorLink], degrees: [Int],
             options: [Option], workBound: Int) {
            self.level = level
            self.phases = phases
            self.base = base
            self.degrees = degrees
            self.options = options
            self.workBound = workBound
        }

        /// A walk from the level's starting phases (the certifying search, as the witness's counterexample uses it).
        init(level: AcousticConstellatorLevel, base: [AcousticConstellatorLink], degrees: [Int], options: [Option],
             workBound: Int) {
            self.level = level
            self.phases = level.startingPhases
            self.base = base
            self.degrees = degrees
            self.options = options
            self.workBound = workBound
        }

        /// Listens to every remaining set of `size` options in order until one wins.
        mutating func walk(size: Int) -> Step {
            var chosen: [Int] = []
            var links: [AcousticConstellatorLink] = base
            var degree: [Int] = degrees
            var shift: [Int] = Array(repeating: 0, count: level.stars.count)
            return descend(size: size, from: 0, chosen: &chosen, links: &links, degree: &degree, shift: &shift)
        }

        /// Extends `chosen` by options at index `from` or later, depth first.
        private mutating func descend(size: Int, from start: Int, chosen: inout [Int],
                                      links: inout [AcousticConstellatorLink], degree: inout [Int],
                                      shift: inout [Int]) -> Step {
            if chosen.count == size {
                work += 1
                if work > workBound { return .over }
                var nudged: [Int] = phases
                for star in nudged.indices {
                    nudged[star] = AcousticConstellatorClock.reduce(nudged[star] + shift[star])
                }
                return level.listen(links: links.sorted(), phases: nudged).won ? .won(chosen) : .lost
            }
            var index: Int = start
            while index < options.count {
                switch options[index] {
                case .link(let link):
                    let repeated: Bool = chosen.last == index
                    let fits: Bool = links.count < level.linkLimit && degree[link.a] < level.degreeLimit
                        && degree[link.b] < level.degreeLimit
                    if !repeated && fits {
                        links.append(link)
                        degree[link.a] += 1
                        degree[link.b] += 1
                        chosen.append(index)
                        let step: Step = descend(size: size, from: index, chosen: &chosen, links: &links,
                                                 degree: &degree, shift: &shift)
                        chosen.removeLast()
                        degree[link.a] -= 1
                        degree[link.b] -= 1
                        links.removeLast()
                        if step != .lost { return step }
                    }
                case .nudge(let star, let stepSize):
                    if shift[star] * stepSize >= 0 {
                        shift[star] += stepSize
                        chosen.append(index)
                        let step: Step = descend(size: size, from: index, chosen: &chosen, links: &links,
                                                 degree: &degree, shift: &shift)
                        chosen.removeLast()
                        shift[star] -= stepSize
                        if step != .lost { return step }
                    }
                }
                index += 1
            }
            return .lost
        }
    }
}
