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
    /// limit, when no set of at most `maxActions` actions wins, or when more than `workBound` listens would be run.
    public static func plan(_ level: AcousticConstellatorLevel, maxActions: Int = maxActions,
                            workBound: Int = workBound) -> AcousticConstellatorPlan? {
        let n: Int = level.stars.count
        let required: [AcousticConstellatorLink] = missing(level)
        let base: [AcousticConstellatorLink] = (level.fixedLinks + required).sorted()
        let baseSet: Set<AcousticConstellatorLink> = Set(base)
        var degrees: [Int] = Array(repeating: 0, count: n)
        for link in base {
            degrees[link.a] += 1
            degrees[link.b] += 1
        }
        guard base.count <= level.linkLimit, degrees.allSatisfy({ $0 <= level.degreeLimit }) else { return nil }
        guard required.count <= maxActions else { return nil }
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
        var search = Search(level: level, base: base, degrees: degrees, options: options, workBound: workBound)
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
        /// The fixed links and the missing symbol pairs, sorted.
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
        init(level: AcousticConstellatorLevel, base: [AcousticConstellatorLink], degrees: [Int], options: [Option],
             workBound: Int) {
            self.level = level
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
                var phases: [Int] = level.startingPhases
                for star in phases.indices {
                    phases[star] = AcousticConstellatorClock.reduce(phases[star] + shift[star])
                }
                return level.listen(links: links.sorted(), phases: phases).won ? .won(chosen) : .lost
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
