// HarmonicBridgesSolver — feature 412 (R02-G12-02) T-R02G1202-003 (FR-R02G1202-002; SC-R02G1202-001, 002, 005;
// clarification Q2). The minimal-plan solver of Harmonic Bridges. For every string and peg, the bridge pattern is the
// set of window steps in which the string is a bridge at that peg. A string kept at its starting peg keeps its current
// pattern; a retuned unlocked string's useful options are the maximal patterns, among its other pegs, that are not
// contained in its current pattern, each realised by its lowest peg (reachability only grows with more bridges, so a
// minimal plan never needs a non-maximal or a contained pattern); a locked string has none. The solver tries k = 1 … 6
// retuned strings: the subsets of the useful strings (those with an option) in lexicographic index order and, for
// each, the product of their options in order (the last string's option varies fastest); the first choice after which
// the start reaches the goal in every step is the plan. Work is the choices tried, counted and bounded at 400 000;
// over the bound there is no plan. The minimality proof is that every choice of every smaller size was tried and
// failed: their count is stored as `smallerChoices`. The witness is the plan's tunings in string order followed by one
// test, replayed through the kernel's play. Integers only; no clock, no random source.
import Foundation

/// One tuning of a plan: a string (0-based) and the peg it is set to.
public struct HarmonicBridgesTuning: Sendable, Hashable, Codable {
    /// The string, 0-based.
    public let string: Int
    /// The peg, 1 … 12.
    public let peg: Int

    /// A tuning of the given values (not checked).
    public init(string: Int, peg: Int) {
        self.string = string
        self.peg = peg
    }
}

/// A certified minimal plan: its tunings, the choices of smaller sizes tried (all failing) and the work spent.
public struct HarmonicBridgesPlan: Sendable, Equatable, Codable {
    /// The tunings, in string order; empty when the starting pegs already win.
    public let tunings: [HarmonicBridgesTuning]
    /// The choices of fewer tunings that were tried, none of which wins (the minimality proof).
    public let smallerChoices: Int
    /// The choices tried in all, the winning one included.
    public let work: Int

    /// A plan of the given values (not checked).
    public init(tunings: [HarmonicBridgesTuning], smallerChoices: Int, work: Int) {
        self.tunings = tunings
        self.smallerChoices = smallerChoices
        self.work = work
    }
}

/// The minimal-plan solver (clarification Q2).
public enum HarmonicBridgesSolver {
    /// The most choices a plan may try.
    public static let workBound: Int = 400_000
    /// The most strings a plan retunes.
    public static let maxTunings: Int = 6

    /// The bridge pattern of string `string` at `peg`: whether it is a bridge in each step of the crossing window.
    public static func pattern(_ level: HarmonicBridgesLevel, string: Int, peg: Int) -> [Bool] {
        var result: [Bool] = []
        for step in 0..<level.steps.count {
            result.append(level.resonance(string, step: step, peg: peg).bridge)
        }
        return result
    }

    /// The useful options of string `string`: the maximal patterns among its pegs other than its starting peg that are
    /// not contained in its starting pattern, each realised by its lowest peg, in ascending peg order. A locked string
    /// has none.
    public static func options(_ level: HarmonicBridgesLevel, string: Int) -> [HarmonicBridgesTuning] {
        let entry: HarmonicBridgesString = level.strings[string]
        guard !entry.locked else { return [] }
        let current: Int = mask(pattern(level, string: string, peg: entry.peg))
        var masks: [Int] = []
        var pegs: [Int] = []
        for peg in HarmonicBridgesLevel.pegs where peg != entry.peg {
            let value: Int = mask(pattern(level, string: string, peg: peg))
            if masks.contains(value) { continue }
            if value & ~current == 0 { continue }
            masks.append(value)
            pegs.append(peg)
        }
        var result: [HarmonicBridgesTuning] = []
        for index in masks.indices {
            var dominated: Bool = false
            for other in masks where other != masks[index] && masks[index] & ~other == 0 { dominated = true }
            if !dominated { result.append(HarmonicBridgesTuning(string: string, peg: pegs[index])) }
        }
        return result
    }

    /// The minimal plan of `level`: an empty plan when the starting pegs already win; otherwise the first winning
    /// choice of the smallest size k in 1 … ``maxTunings``, with the count of every smaller choice tried. Nil when no
    /// choice of at most ``maxTunings`` tunings wins or when more than `workBound` choices would be tried.
    public static func plan(_ level: HarmonicBridgesLevel, workBound: Int = workBound) -> HarmonicBridgesPlan? {
        let stringCount: Int = level.strings.count
        var current: [Int] = []
        for string in 0..<stringCount {
            current.append(mask(pattern(level, string: string, peg: level.strings[string].peg)))
        }
        if winsAll(level, masks: current) { return HarmonicBridgesPlan(tunings: [], smallerChoices: 0, work: 0) }
        var useful: [Int] = []
        var optionPegs: [[Int]] = []
        var optionMasks: [[Int]] = []
        for string in 0..<stringCount {
            let choices: [HarmonicBridgesTuning] = options(level, string: string)
            if choices.isEmpty { continue }
            useful.append(string)
            var pegs: [Int] = []
            var masks: [Int] = []
            for choice in choices {
                pegs.append(choice.peg)
                masks.append(mask(pattern(level, string: string, peg: choice.peg)))
            }
            optionPegs.append(pegs)
            optionMasks.append(masks)
        }
        var work: Int = 0
        let largest: Int = min(maxTunings, useful.count)
        if largest < 1 { return nil }
        for size in 1...largest {
            let smaller: Int = work
            var subset: [Int] = Array(0..<size)
            while true {
                var digits: [Int] = Array(repeating: 0, count: size)
                while true {
                    work += 1
                    if work > workBound { return nil }
                    var trial: [Int] = current
                    for position in 0..<size {
                        let slot: Int = subset[position]
                        trial[useful[slot]] = optionMasks[slot][digits[position]]
                    }
                    if winsAll(level, masks: trial) {
                        var tunings: [HarmonicBridgesTuning] = []
                        for position in 0..<size {
                            let slot: Int = subset[position]
                            tunings.append(HarmonicBridgesTuning(string: useful[slot],
                                                                 peg: optionPegs[slot][digits[position]]))
                        }
                        return HarmonicBridgesPlan(tunings: tunings, smallerChoices: smaller, work: work)
                    }
                    if !advance(&digits, limits: subset, counts: optionPegs) { break }
                }
                if !nextSubset(&subset, of: useful.count) { break }
            }
        }
        return nil
    }

    /// The witness actions of `plan`: its tunings in string order, then one test.
    public static func actions(_ plan: HarmonicBridgesPlan) -> [HarmonicBridgesAction] {
        var result: [HarmonicBridgesAction] = []
        for tuning in plan.tunings { result.append(.tune(tuning.string, tuning.peg)) }
        result.append(.test)
        return result
    }

    /// Whether `actions`, applied to a new play of `level` (after `begin`, and `dismissTutorial` when the level has a
    /// tutorial), are all accepted and win on the last one.
    public static func wins(_ level: HarmonicBridgesLevel, actions: [HarmonicBridgesAction]) -> Bool {
        var play = HarmonicBridgesPlay(level: level)
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

    /// The bit set of a pattern: bit t is set when the string is a bridge in step t.
    static func mask(_ pattern: [Bool]) -> Int {
        var result: Int = 0
        for (step, bridge) in pattern.enumerated() where bridge { result |= 1 << step }
        return result
    }

    /// Whether the start reaches the goal in every step when string s has bridge pattern `masks[s]`.
    static func winsAll(_ level: HarmonicBridgesLevel, masks: [Int]) -> Bool {
        for step in 0..<level.steps.count {
            var reached: Int = 1 << level.start
            var grew: Bool = true
            while grew {
                grew = false
                for (index, string) in level.strings.enumerated() where masks[index] & (1 << step) != 0 {
                    let a: Int = 1 << string.a
                    let b: Int = 1 << string.b
                    if (reached & a != 0) != (reached & b != 0) {
                        reached |= a | b
                        grew = true
                    }
                }
            }
            if reached & (1 << level.goal) == 0 { return false }
        }
        return true
    }

    /// Advances the option digits of the subset like an odometer, the last position fastest; false after the last.
    static func advance(_ digits: inout [Int], limits subset: [Int], counts: [[Int]]) -> Bool {
        var position: Int = digits.count - 1
        while position >= 0 {
            digits[position] += 1
            if digits[position] < counts[subset[position]].count { return true }
            digits[position] = 0
            position -= 1
        }
        return false
    }

    /// Advances `subset` (ascending indices below `count`) to the next subset of its size in lexicographic order;
    /// false after the last.
    static func nextSubset(_ subset: inout [Int], of count: Int) -> Bool {
        let size: Int = subset.count
        var position: Int = size - 1
        while position >= 0 && subset[position] == count - size + position { position -= 1 }
        if position < 0 { return false }
        subset[position] += 1
        var next: Int = position + 1
        while next < size {
            subset[next] = subset[next - 1] + 1
            next += 1
        }
        return true
    }
}
