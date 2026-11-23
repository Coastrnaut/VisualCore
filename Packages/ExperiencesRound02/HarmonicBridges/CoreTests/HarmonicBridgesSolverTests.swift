// HarmonicBridgesSolverTests — feature 412 (R02-G12-02) T-R02G1202-003 (FR-R02G1202-002; SC-R02G1202-001, 002, 005;
// clarifications Q2, Q5). The minimal-plan solver of Harmonic Bridges. Hand levels with minima worked out by hand: the
// shared hand level (one tuning, string 3 to peg 1, after four choices), a level that already wins (the empty plan), a
// chain needing two and one needing three tunings, the hand level with its last string locked (no plan at all) and a
// seven-string chain beyond `maxTunings` (no plan). Bridge patterns and options by hand: maximal patterns only, never
// one contained in the current pattern, the lowest peg of a repeated pattern, none for a locked string. Then an
// independent brute force on seeded small levels (fixtures from seed 2_412 and generator candidates of bands 1 … 3):
// every subset of the unlocked strings of every size below the plan's, each with EVERY peg 1 … 12 (no pattern pruning),
// judged by the real `HarmonicBridgesLevel.report` bridges and `HarmonicBridgesReport.reachable`; none wins, the plan
// wins (by report and through the kernel's play) so its size is the brute-force minimum, `smallerChoices` equals the
// choices of smaller sizes recounted from the options alone, the plan is the first winning choice of its size in the
// documented order and its work is that position. The work bound is honoured. Deterministic, explicit types, plain
// loops.
import Foundation
import Testing
import VisualCoreSimulation
@testable import HarmonicBridgesCore

@Suite struct HarmonicBridgesSolverTests {
    /// The fixture seed of this feature.
    static let seed: UInt64 = 2_412
    /// The most brute-force choices one level may cost before it is left out (keeps each test well under 10 s; at most
    /// 1.7 s measured locally).
    static let bruteCap: Int = 200_000

    // MARK: - Hand levels

    /// A level of `islandCount` islands in a row, start 0, the goal the last island, the given strings and steps,
    /// threshold `threshold` and budget 12.
    static func level(_ id: String, islandCount: Int, strings: [HarmonicBridgesString],
                      steps: [[HarmonicBridgesTone]], threshold: Int = 2) -> HarmonicBridgesLevel {
        var islands: [HarmonicBridgesIsland] = []
        for index in 0..<islandCount { islands.append(HarmonicBridgesIsland(x: index * 2, y: 4)) }
        do {
            return try HarmonicBridgesLevel(id: id, seed: 1, difficulty: 1, islands: islands, strings: strings,
                                            start: 0, goal: islandCount - 1, steps: steps, threshold: threshold,
                                            budget: 12)
        } catch {
            preconditionFailure("hand level \(id) is valid: \(error)")
        }
    }

    /// One step sounding tone 2 at strength 2: a string of length 1 is a bridge only at peg 2 (mode 1, swing 2 6 8 6
    /// 2); at peg 1 it rings mode 2 (a zero in the middle) and at any other peg nothing.
    static let toneTwo: [[HarmonicBridgesTone]] = [[HarmonicBridgesTone(frequency: 2, strength: 2)]]

    /// A chain of `count` strings of length 1 at peg 5 from island 0 to island `count`, plus a locked string of length
    /// 1 at peg 5 from island 0 to the goal; under ``toneTwo`` every chain string must be retuned to peg 2.
    static func chain(_ count: Int) -> HarmonicBridgesLevel {
        var strings: [HarmonicBridgesString] = []
        for index in 0..<count { strings.append(HarmonicBridgesString(a: index, b: index + 1, length: 1, peg: 5)) }
        if count > 1 { strings.append(HarmonicBridgesString(a: 0, b: count, length: 1, peg: 5, locked: true)) }
        return level("chain-\(count)", islandCount: count + 1, strings: strings, steps: toneTwo)
    }

    /// The shared hand level with string 3 already at peg 1: both steps reach the goal at the start.
    static func alreadyWon() -> HarmonicBridgesLevel {
        let hand: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel()
        var strings: [HarmonicBridgesString] = hand.strings
        strings[3] = HarmonicBridgesString(a: 2, b: 3, length: 1, peg: 1)
        do {
            return try HarmonicBridgesLevel(id: "won", seed: 1, difficulty: 1, islands: hand.islands, strings: strings,
                                            start: hand.start, goal: hand.goal, steps: hand.steps,
                                            threshold: hand.threshold, budget: hand.budget)
        } catch {
            preconditionFailure("the won level is valid: \(error)")
        }
    }

    @Test func handLevelNeedsOneTuningFoundOnTheFourthChoice() throws {
        let level: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel()
        let plan: HarmonicBridgesPlan = try #require(HarmonicBridgesSolver.plan(level))
        // Strings 0, 1 and 2 each have one option and break a step; string 3 to peg 1 wins.
        #expect(plan.tunings == [HarmonicBridgesTuning(string: 3, peg: 1)])
        #expect(plan.smallerChoices == 0)
        #expect(plan.work == 4)
        let actions: [HarmonicBridgesAction] = HarmonicBridgesSolver.actions(plan)
        #expect(actions == [.tune(3, 1), .test])
        #expect(HarmonicBridgesSolver.wins(level, actions: actions))
        #expect(!HarmonicBridgesSolver.wins(level, actions: [.test]))
    }

    @Test func alreadyWinningStartGivesTheEmptyPlan() throws {
        let level: HarmonicBridgesLevel = Self.alreadyWon()
        #expect(level.report(pegs: level.startingPegs).goalReachedInEveryStep)
        let plan: HarmonicBridgesPlan = try #require(HarmonicBridgesSolver.plan(level))
        #expect(plan.tunings.isEmpty)
        #expect(plan.smallerChoices == 0)
        #expect(plan.work == 0)
        #expect(HarmonicBridgesSolver.actions(plan) == [.test])
        #expect(HarmonicBridgesSolver.wins(level, actions: HarmonicBridgesSolver.actions(plan)))
        // The empty plan costs no work, so even a zero bound returns it.
        #expect(HarmonicBridgesSolver.plan(level, workBound: 0) == plan)
    }

    @Test func chainsNeedEveryLinkRetuned() throws {
        let two: HarmonicBridgesPlan = try #require(HarmonicBridgesSolver.plan(Self.chain(2)))
        #expect(two.tunings == [HarmonicBridgesTuning(string: 0, peg: 2), HarmonicBridgesTuning(string: 1, peg: 2)])
        // Two single choices fail, then the one pair wins.
        #expect(two.smallerChoices == 2)
        #expect(two.work == 3)
        let three: HarmonicBridgesPlan = try #require(HarmonicBridgesSolver.plan(Self.chain(3)))
        #expect(three.tunings.count == 3)
        for tuning in three.tunings { #expect(tuning.peg == 2) }
        // Three singles and three pairs fail, then the one triple wins.
        #expect(three.smallerChoices == 6)
        #expect(three.work == 7)
        #expect(HarmonicBridgesSolver.wins(Self.chain(3), actions: HarmonicBridgesSolver.actions(three)))
        // Dropping any one tuning of the witness no longer wins.
        for skipped in 0..<3 {
            var actions: [HarmonicBridgesAction] = []
            for (index, tuning) in three.tunings.enumerated() where index != skipped {
                actions.append(.tune(tuning.string, tuning.peg))
            }
            actions.append(.test)
            #expect(!HarmonicBridgesSolver.wins(Self.chain(3), actions: actions))
        }
    }

    @Test func lockedNeededStringMeansNoPlan() {
        // Step 0 needs strings 0 and 1 at pegs 2 and 4, step 1 needs them at pegs 1 and 2; string 3 is locked.
        let level: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel(lockedLast: true)
        #expect(HarmonicBridgesSolver.options(level, string: 3).isEmpty)
        #expect(HarmonicBridgesSolver.plan(level) == nil)
        let brute: BruteForce = BruteForce(level)
        for size in 0...3 { #expect(brute.firstWin(size: size) == nil) }
    }

    @Test func moreThanMaxTuningsMeansNoPlan() {
        // Seven links must all be retuned; the solver stops at six.
        let level: HarmonicBridgesLevel = Self.chain(7)
        #expect(HarmonicBridgesSolver.maxTunings == 6)
        #expect(HarmonicBridgesSolver.plan(level) == nil)
        var actions: [HarmonicBridgesAction] = []
        for string in 0..<7 { actions.append(.tune(string, 2)) }
        actions.append(.test)
        #expect(HarmonicBridgesSolver.wins(level, actions: actions))
    }

    @Test func workBoundIsHonoured() throws {
        let hand: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel()
        #expect(HarmonicBridgesSolver.workBound == 400_000)
        #expect(HarmonicBridgesSolver.plan(hand, workBound: 3) == nil)
        let exact: HarmonicBridgesPlan = try #require(HarmonicBridgesSolver.plan(hand, workBound: 4))
        #expect(exact.work == 4)
        #expect(HarmonicBridgesSolver.plan(Self.chain(3), workBound: 6) == nil)
        #expect(HarmonicBridgesSolver.plan(Self.chain(3), workBound: 7) != nil)
        #expect(HarmonicBridgesSolver.plan(Self.chain(3), workBound: 1) == nil)
    }

    // MARK: - Patterns and options

    @Test func patternsOfTheHandLevel() {
        let level: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel()
        // String 3 (length 1): peg 1 rings modes 1 and 3 in step 1; peg 2 rings mode 1 at strength 2 in step 0.
        #expect(HarmonicBridgesSolver.pattern(level, string: 3, peg: 1) == [false, true])
        #expect(HarmonicBridgesSolver.pattern(level, string: 3, peg: 2) == [true, false])
        #expect(HarmonicBridgesSolver.pattern(level, string: 3, peg: 5) == [false, false])
        #expect(HarmonicBridgesSolver.pattern(level, string: 0, peg: 2) == [true, false])
        #expect(HarmonicBridgesSolver.pattern(level, string: 1, peg: 2) == [false, true])
        #expect(HarmonicBridgesSolver.pattern(level, string: 2, peg: 6) == [true, false])
    }

    @Test func optionsOfTheHandLevel() {
        let level: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel()
        #expect(HarmonicBridgesSolver.options(level, string: 0) == [HarmonicBridgesTuning(string: 0, peg: 1)])
        #expect(HarmonicBridgesSolver.options(level, string: 1) == [HarmonicBridgesTuning(string: 1, peg: 2)])
        #expect(HarmonicBridgesSolver.options(level, string: 2) == [HarmonicBridgesTuning(string: 2, peg: 6)])
        // Two incomparable patterns, both kept, ascending pegs.
        #expect(HarmonicBridgesSolver.options(level, string: 3)
                == [HarmonicBridgesTuning(string: 3, peg: 1), HarmonicBridgesTuning(string: 3, peg: 2)])
    }

    @Test func optionsKeepOnlyMaximalPatterns() {
        // Step 0: tones 2 and 4; step 1: tone 2 (strength 2 each). Length 1: peg 2 bridges both steps, peg 4 only
        // step 0, peg 1 rings modes 2 and 4 (a zero in the middle) and bridges neither.
        let steps: [[HarmonicBridgesTone]] = [
            [HarmonicBridgesTone(frequency: 2, strength: 2), HarmonicBridgesTone(frequency: 4, strength: 2)],
            [HarmonicBridgesTone(frequency: 2, strength: 2)],
        ]
        let level: HarmonicBridgesLevel = Self.level(
            "maximal", islandCount: 2, strings: [HarmonicBridgesString(a: 0, b: 1, length: 1, peg: 5)], steps: steps)
        #expect(HarmonicBridgesSolver.pattern(level, string: 0, peg: 2) == [true, true])
        #expect(HarmonicBridgesSolver.pattern(level, string: 0, peg: 4) == [true, false])
        #expect(HarmonicBridgesSolver.options(level, string: 0) == [HarmonicBridgesTuning(string: 0, peg: 2)])
    }

    @Test func optionsTakeTheLowestPegAndSkipContainedPatterns() {
        // One step: tones 6 and 12 (strength 2). Length 1: peg 6 rings modes 1 and 2, peg 12 mode 1; both bridge.
        let steps: [[HarmonicBridgesTone]] = [
            [HarmonicBridgesTone(frequency: 6, strength: 2), HarmonicBridgesTone(frequency: 12, strength: 2)],
        ]
        let fresh: HarmonicBridgesLevel = Self.level(
            "lowest", islandCount: 2, strings: [HarmonicBridgesString(a: 0, b: 1, length: 1, peg: 1)], steps: steps)
        #expect(HarmonicBridgesSolver.pattern(fresh, string: 0, peg: 6) == [true])
        #expect(HarmonicBridgesSolver.pattern(fresh, string: 0, peg: 12) == [true])
        #expect(HarmonicBridgesSolver.options(fresh, string: 0) == [HarmonicBridgesTuning(string: 0, peg: 6)])
        // Starting at peg 6 the pattern of peg 12 is contained in the current one: no option.
        let tuned: HarmonicBridgesLevel = Self.level(
            "contained", islandCount: 2, strings: [HarmonicBridgesString(a: 0, b: 1, length: 1, peg: 6)], steps: steps)
        #expect(HarmonicBridgesSolver.options(tuned, string: 0).isEmpty)
        // A locked string has none, whatever its pegs could do.
        let locked: HarmonicBridgesLevel = Self.level(
            "locked", islandCount: 2, strings: [HarmonicBridgesString(a: 0, b: 1, length: 1, peg: 1, locked: true)],
            steps: steps)
        #expect(HarmonicBridgesSolver.options(locked, string: 0).isEmpty)
    }

    @Test func optionsMatchTheirDefinitionOnSeededLevels() {
        for fixture in HarmonicBridgesFixtures.fixtures(40, from: Self.seed) {
            let brute: BruteForce = BruteForce(fixture.level)
            for string in 0..<fixture.level.strings.count {
                let expected: [HarmonicBridgesTuning] = brute.expectedOptions(string)
                #expect(HarmonicBridgesSolver.options(fixture.level, string: string) == expected,
                        "\(fixture.level.id) string \(string)")
                for peg in HarmonicBridgesLevel.pegs {
                    #expect(HarmonicBridgesSolver.pattern(fixture.level, string: string, peg: peg)
                            == brute.table[string][peg])
                }
            }
        }
    }

    // MARK: - Independent brute force

    /// Every-peg brute force over the real report and reachability. `table[string][peg][step]` is the bridge of a
    /// string at a peg, read from `level.report(pegs:)` with every string at that peg.
    struct BruteForce {
        let level: HarmonicBridgesLevel
        /// Bridges per string, peg (index 1 … 12; index 0 unused) and step.
        let table: [[[Bool]]]
        /// The unlocked strings, ascending.
        let unlocked: [Int]

        init(_ level: HarmonicBridgesLevel) {
            self.level = level
            let count: Int = level.strings.count
            var table: [[[Bool]]] = Array(repeating: Array(repeating: [], count: 13), count: count)
            for peg in HarmonicBridgesLevel.pegs {
                let report: HarmonicBridgesReport = level.report(pegs: Array(repeating: peg, count: count))
                for string in 0..<count {
                    var steps: [Bool] = []
                    for step in 0..<level.steps.count { steps.append(report.bridges[step][string]) }
                    table[string][peg] = steps
                }
            }
            self.table = table
            var unlocked: [Int] = []
            for (index, string) in level.strings.enumerated() where !string.locked { unlocked.append(index) }
            self.unlocked = unlocked
        }

        /// Whether the pegs reach the goal in every step, by the table and the real reachability.
        func wins(_ pegs: [Int]) -> Bool {
            for step in 0..<level.steps.count {
                var bridges: [Bool] = []
                for string in 0..<pegs.count { bridges.append(table[string][pegs[string]][step]) }
                let reached: [Bool] = HarmonicBridgesReport.reachable(strings: level.strings, bridges: bridges,
                                                                      islandCount: level.islands.count,
                                                                      start: level.start)
                if !reached[level.goal] { return false }
            }
            return true
        }

        /// C(n, k), saturating far above any cap.
        static func binomial(_ n: Int, _ k: Int) -> Int {
            if k < 0 || k > n { return 0 }
            var result: Int = 1
            var i: Int = 0
            while i < k {
                result = result * (n - i) / (i + 1)
                i += 1
            }
            return result
        }

        /// The choices of `size` strings with every peg: C(unlocked, size) · 12^size.
        func cost(size: Int) -> Int {
            var result: Int = Self.binomial(unlocked.count, size)
            for _ in 0..<size { result *= 12 }
            return result
        }

        /// The first winning pegs found with exactly `size` unlocked strings set to any pegs 1 … 12 (the rest at their
        /// starting pegs), or nil when none wins. Subsets by an explicit index list, pegs by an odometer.
        func firstWin(size: Int) -> [Int]? {
            let start: [Int] = level.startingPegs
            if size == 0 { return wins(start) ? start : nil }
            if size > unlocked.count { return nil }
            var chosen: [Int] = []
            for index in 0..<size { chosen.append(index) }
            while true {
                var pegs: [Int] = Array(repeating: 1, count: size)
                while true {
                    var trial: [Int] = start
                    for position in 0..<size { trial[unlocked[chosen[position]]] = pegs[position] }
                    if wins(trial) { return trial }
                    var position: Int = size - 1
                    while position >= 0 && pegs[position] == 12 {
                        pegs[position] = 1
                        position -= 1
                    }
                    if position < 0 { break }
                    pegs[position] += 1
                }
                var slot: Int = size - 1
                while slot >= 0 && chosen[slot] == unlocked.count - size + slot { slot -= 1 }
                if slot < 0 { return nil }
                chosen[slot] += 1
                var next: Int = slot + 1
                while next < size {
                    chosen[next] = chosen[next - 1] + 1
                    next += 1
                }
            }
        }

        /// The options by definition: pegs other than the start whose pattern is not contained in the current pattern
        /// and not strictly inside another such peg's pattern, each the lowest peg giving its pattern.
        func expectedOptions(_ string: Int) -> [HarmonicBridgesTuning] {
            let entry: HarmonicBridgesString = level.strings[string]
            if entry.locked { return [] }
            let current: [Bool] = table[string][entry.peg]
            var result: [HarmonicBridgesTuning] = []
            for peg in HarmonicBridgesLevel.pegs where peg != entry.peg {
                let pattern: [Bool] = table[string][peg]
                if Self.contains(current, pattern) { continue }
                var lowest: Bool = true
                for lower in 1..<peg where lower != entry.peg && table[string][lower] == pattern { lowest = false }
                if !lowest { continue }
                var dominated: Bool = false
                for other in HarmonicBridgesLevel.pegs where other != entry.peg {
                    let wider: [Bool] = table[string][other]
                    if wider != pattern && Self.contains(wider, pattern) { dominated = true }
                }
                if !dominated { result.append(HarmonicBridgesTuning(string: string, peg: peg)) }
            }
            return result
        }

        /// Whether every step set in `inner` is set in `outer`.
        static func contains(_ outer: [Bool], _ inner: [Bool]) -> Bool {
            for step in 0..<inner.count where inner[step] && !outer[step] { return false }
            return true
        }
    }

    /// The choices the solver's order has at each size, from the option counts of the useful strings alone: the
    /// elementary symmetric sums e[0 … n] of the counts.
    static func choicesPerSize(_ level: HarmonicBridgesLevel) -> [Int] {
        var counts: [Int] = []
        for string in 0..<level.strings.count {
            let options: Int = HarmonicBridgesSolver.options(level, string: string).count
            if options > 0 { counts.append(options) }
        }
        var sums: [Int] = Array(repeating: 0, count: counts.count + 1)
        sums[0] = 1
        for count in counts {
            var size: Int = sums.count - 1
            while size >= 1 {
                sums[size] += sums[size - 1] * count
                size -= 1
            }
        }
        return sums
    }

    /// The first winning choice of `size` in the documented order (subsets of the useful strings lexicographically,
    /// options in order, the last string fastest), judged by the real report, and its 1-based position; nil if none.
    static func firstInOrder(_ level: HarmonicBridgesLevel,
                             size: Int) -> (tunings: [HarmonicBridgesTuning], position: Int)? {
        var useful: [[HarmonicBridgesTuning]] = []
        for string in 0..<level.strings.count {
            let options: [HarmonicBridgesTuning] = HarmonicBridgesSolver.options(level, string: string)
            if !options.isEmpty { useful.append(options) }
        }
        if size < 1 || size > useful.count { return nil }
        var chosen: [Int] = []
        for index in 0..<size { chosen.append(index) }
        var position: Int = 0
        while true {
            var digits: [Int] = Array(repeating: 0, count: size)
            while true {
                position += 1
                var pegs: [Int] = level.startingPegs
                var tunings: [HarmonicBridgesTuning] = []
                for slot in 0..<size {
                    let tuning: HarmonicBridgesTuning = useful[chosen[slot]][digits[slot]]
                    pegs[tuning.string] = tuning.peg
                    tunings.append(tuning)
                }
                if level.report(pegs: pegs).goalReachedInEveryStep { return (tunings, position) }
                var slot: Int = size - 1
                while slot >= 0 && digits[slot] == useful[chosen[slot]].count - 1 {
                    digits[slot] = 0
                    slot -= 1
                }
                if slot < 0 { break }
                digits[slot] += 1
            }
            var slot: Int = size - 1
            while slot >= 0 && chosen[slot] == useful.count - size + slot { slot -= 1 }
            if slot < 0 { return nil }
            chosen[slot] += 1
            var next: Int = slot + 1
            while next < size {
                chosen[next] = chosen[next - 1] + 1
                next += 1
            }
        }
    }

    /// Checks one level's plan against the brute force; returns false (and checks nothing) when the brute force
    /// would cost more than ``bruteCap`` choices.
    static func certify(_ level: HarmonicBridgesLevel) -> Bool {
        guard let plan = HarmonicBridgesSolver.plan(level) else {
            // No plan: with at most six tunings nothing small enough to search may win either.
            let brute: BruteForce = BruteForce(level)
            var size: Int = 0
            let largest: Int = min(HarmonicBridgesSolver.maxTunings, brute.unlocked.count)
            while size <= largest && brute.cost(size: size) <= bruteCap {
                #expect(brute.firstWin(size: size) == nil, "\(level.id) size \(size)")
                size += 1
            }
            return size > 0
        }
        let k: Int = plan.tunings.count
        let brute: BruteForce = BruteForce(level)
        var total: Int = 0
        for size in 0..<max(k, 1) { total += brute.cost(size: size) }
        if total > bruteCap { return false }
        // Every choice of fewer tunings, every peg, fails.
        for size in 0..<k { #expect(brute.firstWin(size: size) == nil, "\(level.id) size \(size) of \(k)") }
        // The plan wins by the report and through the kernel: k is the brute-force minimum.
        var pegs: [Int] = level.startingPegs
        for tuning in plan.tunings { pegs[tuning.string] = tuning.peg }
        #expect(level.report(pegs: pegs).goalReachedInEveryStep, "\(level.id)")
        #expect(brute.wins(pegs), "\(level.id)")
        #expect(HarmonicBridgesSolver.wins(level, actions: HarmonicBridgesSolver.actions(plan)), "\(level.id)")
        // Tunings in string order, each to an unlocked string and a different peg.
        var previous: Int = -1
        for tuning in plan.tunings {
            #expect(tuning.string > previous)
            #expect(!level.strings[tuning.string].locked)
            #expect(tuning.peg != level.strings[tuning.string].peg)
            previous = tuning.string
        }
        // The minimality proof recounted from the options alone; the plan is the first winner of its size.
        let sums: [Int] = choicesPerSize(level)
        var smaller: Int = 0
        if k >= 2 {
            for size in 1..<k where size < sums.count { smaller += sums[size] }
        }
        #expect(plan.smallerChoices == smaller, "\(level.id)")
        if k >= 1 {
            let first: (tunings: [HarmonicBridgesTuning], position: Int)? = firstInOrder(level, size: k)
            #expect(first?.tunings == plan.tunings, "\(level.id)")
            #expect(plan.work == smaller + (first?.position ?? -1), "\(level.id)")
            #expect(plan.work <= smaller + sums[k])
            // One tuning fewer of the witness never wins through the kernel.
            for skipped in 0..<k {
                var actions: [HarmonicBridgesAction] = []
                for (index, tuning) in plan.tunings.enumerated() where index != skipped {
                    actions.append(.tune(tuning.string, tuning.peg))
                }
                actions.append(.test)
                #expect(!HarmonicBridgesSolver.wins(level, actions: actions), "\(level.id) without \(skipped)")
            }
        } else {
            #expect(plan.work == 0)
        }
        return true
    }

    @Test func handLevelsAgreeWithTheBruteForce() {
        #expect(Self.certify(HarmonicBridgesFixtures.handLevel()))
        #expect(Self.certify(HarmonicBridgesFixtures.handLevel(threshold: 3)))
        #expect(Self.certify(Self.alreadyWon()))
        #expect(Self.certify(Self.chain(2)))
        #expect(Self.certify(Self.chain(3)))
        #expect(Self.certify(HarmonicBridgesFixtures.handLevel(lockedLast: true)))
    }

    @Test func seededFixturesAgreeWithTheBruteForce() {
        var checked: Int = 0
        var sizes: [Int] = Array(repeating: 0, count: 7)
        for fixture in HarmonicBridgesFixtures.fixtures(120, from: Self.seed) {
            // A fixture always has a winning plan of at most its scrambled path strings (never locked).
            let plan: HarmonicBridgesPlan? = HarmonicBridgesSolver.plan(fixture.level)
            #expect(plan != nil, "\(fixture.level.id)")
            #expect((plan?.tunings.count ?? 99) <= fixture.winningActions.count, "\(fixture.level.id)")
            if Self.certify(fixture.level) {
                checked += 1
                sizes[min(6, plan?.tunings.count ?? 6)] += 1
            }
        }
        #expect(checked >= 110, "checked \(checked) of 120")
        #expect(sizes[2] > 0 && sizes[3] > 0)
    }

    @Test(arguments: [1, 2, 3])
    func generatorCandidatesAgreeWithTheBruteForce(band: Int) {
        var checked: Int = 0
        var planned: Int = 0
        var seen: Int = 0
        for entry in HarmonicBridgesManifest.entries where entry.band == band {
            if seen >= 6 { break }
            seen += 1
            for index in 0..<8 {
                guard let level = HarmonicBridgesGenerator.candidate(entry, index: index) else { continue }
                if Self.certify(level) {
                    checked += 1
                    if HarmonicBridgesSolver.plan(level) != nil { planned += 1 }
                }
            }
        }
        #expect(checked >= 12, "band \(band): checked \(checked)")
        #expect(planned >= 8, "band \(band): planned \(planned)")
    }
}
