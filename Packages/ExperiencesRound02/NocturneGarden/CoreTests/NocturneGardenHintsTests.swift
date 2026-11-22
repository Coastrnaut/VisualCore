// NocturneGardenHintsTests — feature 385 (R02-G09-05) T-R02G0905-002 (FR-R02G0905-002, 003; SC-R02G0905-002, 003;
// clarifications Q1, Q5). Hints and failure explanations on the 100 certified levels (generated once per process
// through the adapter's cache, prewarmed concurrently): from every opening the continuation search finds a solution of
// exactly the certified smallest move count within the work bound, and following exact hints (re-asked after every
// move) wins with exactly that many moves, in 20 groups of 5 levels; 200 seeded reachable states (seed 2_385, 20 groups
// of 10: certified moves, random plants, moves, resizes, removals, sun moves and undos from certified openings, about
// one in four paused) get a hint that the play accepts, from every state with a plan following hints wins within the
// moves left, and a hint never changes the play; a bloom that spoils the match is hinted away by a removal; the three
// hint levels read as clarification Q1 says; loading, tutorial, won and result-after-win plays get no hint, failed ones
// `stuck`; 500 seeded failures (leaks and budget runs, 10 groups of 50 on 10 levels each) are explained with the true
// reason, move and counts tracked independently here (own mask from the blooms' cells, own move index). Deterministic,
// explicit types, plain loops.
@testable import NocturneGardenCore
import Foundation
import Testing
import VisualCoreSimulation

/// The 100 certified levels and their solutions in manifest order, generated concurrently once per test process.
private let hintCatalogResult: Result<[NocturneGardenGenerated], any Error> = Result {
    DispatchQueue.concurrentPerform(iterations: 100) { (index: Int) in
        _ = try? NocturneGardenExperienceCore.generated(number: index + 1)
    }
    var catalog: [NocturneGardenGenerated] = []
    for number in 1...100 { catalog.append(try NocturneGardenExperienceCore.generated(number: number)) }
    return catalog
}

/// The certified catalog.
private func hintCatalog() throws -> [NocturneGardenGenerated] { try hintCatalogResult.get() }

/// The supply left of `play`, computed here: the level's count less the blooms planted, per kind with a supply.
private func ownSupply(_ play: NocturneGardenPlay) -> [NocturneGardenKind: Int] {
    var supply: [NocturneGardenKind: Int] = play.level.supply
    for bloom in play.blooms { supply[bloom.kind, default: 0] -= 1 }
    return supply
}

/// Follows exact (level 3) hints from `start` (resumed when paused; `first`, when given, is the hint already asked for
/// `start`) until the play ends; the problems found (empty: won, every hinted move accepted) and the moves spent
/// following them.
private func followHints(_ start: NocturneGardenPlay, label: String,
                         first: NocturneGardenHint? = nil) -> (problems: [String], spent: Int) {
    var play: NocturneGardenPlay = start
    if play.stage == .paused { try? play.handle(.resume) }
    var spent: Int = 0
    var given: NocturneGardenHint? = first
    for _ in 0..<64 {
        if play.stage == .won { return ([], spent) }
        let asked: NocturneGardenHint? = given ?? NocturneGardenHints.hint(level: 3, play: play)
        given = nil
        guard let hint = asked else {
            return (["\(label): no hint in \(play.stage)"], spent)
        }
        guard let action = hint.action else { return (["\(label): stuck at move \(play.moves)"], spent) }
        do {
            try play.apply(action, expecting: play.fingerprint)
        } catch {
            return (["\(label): hinted \(action) refused: \(error)"], spent)
        }
        spent += 1
    }
    return (play.stage == .won ? [] : ["\(label): not won, stage \(play.stage)"], spent)
}

/// A random action for `play`: a plant (kinds with supply, any anchor, allowed sizes), a move, a resize, a removal or a
/// sun move; it may be refused.
private func randomAction(_ play: NocturneGardenPlay, _ random: inout SeededRandom) -> NocturneGardenAction {
    let level: NocturneGardenLevel = play.level
    let sizes: [Int] = level.sizes.sorted()
    let elevations: [Int] = level.elevations.sorted()
    var kinds: [NocturneGardenKind] = []
    for kind in NocturneGardenKind.allCases where level.supplyCount(kind) > 0 { kinds.append(kind) }
    let count: Int = play.blooms.count
    let choice: Int = random.int(0...9)
    if count > 0 && choice == 0 {
        return .move(random.int(0...(count - 1)), random.int(0...(level.width - 1)),
                     random.int(0...(level.height - 1)))
    }
    if count > 0 && choice == 1 {
        return .resize(random.int(0...(count - 1)), sizes[random.int(0...(sizes.count - 1))])
    }
    if count > 0 && choice == 2 { return .remove(random.int(0...(count - 1))) }
    if choice == 3 { return .sun(elevations[random.int(0...(elevations.count - 1))]) }
    return .plant(kinds[random.int(0...(kinds.count - 1))], random.int(0...(level.width - 1)),
                  random.int(0...(level.height - 1)), sizes[random.int(0...(sizes.count - 1))])
}

/// A seeded reachable state of the hint sample.
private struct HintSample {
    let number: Int
    let play: NocturneGardenPlay
}

/// The 200 seeded reachable states, drawn once per test process.
private let hintSamplesResult: Result<[HintSample], any Error> = Result { try drawHintSamples() }

/// The 200 seeded reachable states.
private func hintSamples() throws -> [HintSample] { try hintSamplesResult.get() }

/// 200 seeded reachable states (seed 2_385): from a certified opening, 0 … smallest − 1 certified moves (so many states
/// stay on a winning path), then 0 … 3 random steps — a random action (most often) or an undo — where an action that
/// fails the play is undone and a won play is drawn again; about one in four samples ends paused.
private func drawHintSamples() throws -> [HintSample] {
    let catalog: [NocturneGardenGenerated] = try hintCatalog()
    var random = SeededRandom(seed: 2_385)
    var samples: [HintSample] = []
    while samples.count < 200 {
        let number: Int = random.int(1...100)
        let generated: NocturneGardenGenerated = catalog[number - 1]
        var play: NocturneGardenPlay = try NocturneGardenExperienceCore.freshPlay(of: generated.level)
        let certified: Int = random.int(0...(generated.solution.actions.count - 1))
        for index in 0..<certified { try play.apply(generated.solution.actions[index], expecting: play.fingerprint) }
        let steps: Int = random.int(0...3)
        for _ in 0..<steps {
            if play.stage != .playing { break }
            if random.int(0...4) == 0 {
                if play.canUndo { try play.undo() }
                continue
            }
            let action: NocturneGardenAction = randomAction(play, &random)
            do {
                try play.apply(action, expecting: play.fingerprint)
            } catch {
                continue
            }
            if play.stage == .failed { try play.undo() }
        }
        guard play.stage == .playing else { continue }
        if random.int(0...3) == 0 { try play.handle(.pause) }
        samples.append(HintSample(number: number, play: play))
    }
    return samples
}

/// The mask of `play` computed here from the blooms' own cells.
private func ownMask(_ play: NocturneGardenPlay) -> Set<Int> {
    var cells: Set<Int> = []
    for bloom in play.blooms {
        cells.formUnion(bloom.cells(elevation: play.elevation, width: play.level.width, height: play.level.height))
    }
    return cells
}

@Suite struct NocturneGardenHintsTests {
    /// The test seed of this feature.
    static let seed: UInt64 = 2_385

    // MARK: Openings

    /// From every certified opening (20 groups of 5 levels) the continuation search finds exactly the certified
    /// smallest move count within the work bound, and following exact hints wins with exactly that many moves, within
    /// the budget.
    @Test(arguments: Array(0..<20))
    func followingHintsFromTheOpeningWins(group: Int) throws {
        let catalog: [NocturneGardenGenerated] = try hintCatalog()
        var most: Int = 0
        for number in (5 * group + 1)...(5 * group + 5) {
            let generated: NocturneGardenGenerated = catalog[number - 1]
            let level: NocturneGardenLevel = generated.level
            let found: NocturneGardenSolution? = NocturneGardenSolver.solve(
                level, from: [], sun: level.sun, movesLeft: level.budget, supplyLeft: level.supply)
            let solution: NocturneGardenSolution = try #require(found, "level \(number): no continuation")
            #expect(solution.actions.count == generated.solution.smallest, "level \(number)")
            #expect(solution.smallest == solution.actions.count && solution.work <= NocturneGardenSolver.workBound)
            #expect(NocturneGardenSolver.wins(level, actions: solution.actions), "level \(number)")
            most = max(most, solution.work)
            let opening: NocturneGardenPlay = try NocturneGardenExperienceCore.freshPlay(of: level)
            let hint: NocturneGardenHint? = NocturneGardenHints.hint(level: 3, play: opening)
            #expect(hint?.kind == .move && hint?.action == solution.actions.first, "level \(number)")
            let outcome: (problems: [String], spent: Int) = followHints(opening, label: "level \(number)", first: hint)
            #expect(outcome.problems.isEmpty, "\(outcome.problems)")
            #expect(outcome.spent == generated.solution.smallest && outcome.spent <= level.budget, "level \(number)")
        }
        print("NocturneGardenHintsTests group \(group): most opening work \(most)")
    }

    /// The continuation's candidate list equals the certification's (`plants(_:elevation:)`): the same plants in the
    /// same order with the same cells and counts, on every allowed elevation of one level in ten.
    @Test func continuationPlantsEqualTheCertificationPlants() throws {
        let catalog: [NocturneGardenGenerated] = try hintCatalog()
        for number in stride(from: 1, through: 100, by: 10) {
            let level: NocturneGardenLevel = catalog[number - 1].level
            for elevation in level.elevations.sorted() {
                let fast: [NocturneGardenSolver.Plant] = NocturneGardenSolver.continuationPlants(level,
                                                                                               elevation: elevation)
                let slow: [NocturneGardenSolver.Plant] = NocturneGardenSolver.plants(level, elevation: elevation)
                #expect(fast.count == slow.count, "level \(number) sun \(elevation)")
                var same: Bool = fast.count == slow.count
                for index in fast.indices where same {
                    let a: NocturneGardenSolver.Plant = fast[index]
                    let b: NocturneGardenSolver.Plant = slow[index]
                    same = a.action == b.action && a.cells == b.cells && a.inside == b.inside
                        && a.outside == b.outside && a.leak == b.leak
                }
                #expect(same, "level \(number) sun \(elevation)")
            }
        }
    }

    // MARK: Reachable states

    /// 200 seeded reachable states in 20 groups of 10: the hint never changes the play; with a plan the hint is its
    /// first move at every level, the play accepts it and following hints wins within the moves left; without one the
    /// hint is `stuck` with the stuck text.
    @Test(arguments: Array(0..<20))
    func reachableStatesGetLegalHintsThatWin(group: Int) throws {
        let samples: [HintSample] = try hintSamples()
        var planned: Int = 0
        for index in (10 * group)..<(10 * group + 10) {
            let sample: HintSample = samples[index]
            let play: NocturneGardenPlay = sample.play
            let label: String = "sample \(index) (level \(sample.number), move \(play.moves))"
            let before: NocturneGardenPlay = play
            let hint: NocturneGardenHint = try #require(NocturneGardenHints.hint(level: 3, play: play), "\(label)")
            #expect(play == before && play.fingerprint == before.fingerprint, "\(label): the hint changed the play")
            guard let action = hint.action else {
                #expect(hint.kind == .stuck && hint.text == NocturneGardenHint.stuckText, "\(label)")
                #expect(NocturneGardenHints.plan(play) == nil, "\(label)")
                continue
            }
            planned += 1
            #expect(hint.kind == .move, "\(label)")
            for level in 1...2 { #expect(hint.at(level: level).action == action, "\(label)") }
            var copy: NocturneGardenPlay = play
            if copy.stage == .paused { try copy.handle(.resume) }
            #expect(throws: Never.self, "\(label): hinted \(action) refused") {
                try copy.apply(action, expecting: copy.fingerprint)
            }
            // Following hints from there (re-asked after every move) wins within the moves left.
            let outcome: (problems: [String], spent: Int) = followHints(copy, label: label)
            #expect(outcome.problems.isEmpty, "\(outcome.problems)")
            #expect(outcome.spent + 1 <= play.remaining, "\(label)")
        }
        #expect(planned >= 1, "group \(group): no sample has a plan")
        print("NocturneGardenHintsTests samples group \(group): \(planned) of 10 with a plan")
    }

    /// A bloom planted off the target spoils a whole match and uses up the only supply, so no plant can repair it: the
    /// hint is its removal first (then the right plant), the three levels read as clarification Q1 says and following
    /// hints wins in exactly two moves.
    @Test func aSpoilingBloomIsHintedAway() throws {
        let width: Int = 16
        let height: Int = 12
        let goal = NocturneGardenBloom(kind: .tulip, column: 4, row: 5, size: 1)
        let target: Set<Int> = goal.cells(elevation: 2, width: width, height: height)
        let level: NocturneGardenLevel = try NocturneGardenLevel(
            id: "hint-test", seed: Self.seed, difficulty: 1, width: width, height: height, target: target,
            forbidden: [], supply: [.tulip: 1], sizes: [1], elevations: [2], sun: 2, budget: 5, required: .whole,
            leakAllowance: 0)
        var play: NocturneGardenPlay = try NocturneGardenExperienceCore.freshPlay(of: level)
        try play.apply(.plant(.tulip, 11, 5, 1), expecting: play.fingerprint)
        try #require(play.stage == .playing)
        #expect(ownMask(play).isDisjoint(with: target))
        let hint: NocturneGardenHint = try #require(NocturneGardenHints.hint(level: 1, play: play))
        #expect(hint.kind == .move && hint.action == .remove(0))
        #expect(NocturneGardenHints.plan(play)?.actions == [.remove(0), .plant(.tulip, 4, 5, 1)])
        #expect(hint.text == "Remove bloom 1")
        #expect(hint.at(level: 2).text == "Remove bloom 1, a tulip of size 1")
        #expect(hint.at(level: 3).text == "Remove bloom 1, a tulip of size 1 at column 11, row 5")
        let outcome: (problems: [String], spent: Int) = followHints(play, label: "spoiled")
        #expect(outcome.problems.isEmpty && outcome.spent == 2, "\(outcome.problems)")
        // With one move left the removal and the plant no longer fit: stuck.
        var late: NocturneGardenPlay = play
        for column in [12, 11, 12] { try late.apply(.move(0, column, 5), expecting: late.fingerprint) }
        try #require(late.stage == .playing && late.remaining == 1)
        let stuck: NocturneGardenHint? = NocturneGardenHints.hint(level: 2, play: late)
        #expect(stuck?.kind == .stuck && stuck?.action == nil && stuck?.text == NocturneGardenHint.stuckText)
        #expect(NocturneGardenHints.plan(late) == nil)
    }

    // MARK: Texts and stages

    /// The texts of each hint kind at each level (clarification Q1).
    @Test func hintTextsAtEachLevel() throws {
        let rose = NocturneGardenBloom(kind: .rose, column: 5, row: 1, size: 2)
        let plant = NocturneGardenHint(level: 1, kind: .move, action: .plant(.rose, 5, 1, 2), elevation: 3)
        #expect(plant.text == "Plant a rose")
        #expect(plant.at(level: 2).text == "Plant a rose of size 2 under sun 3 of 4")
        #expect(plant.at(level: 3).text == "Plant a rose of size 2 under sun 3 of 4 at column 5, row 1")
        #expect(plant.at(level: 9).level == 3 && plant.at(level: -1).level == 1)
        let sun = NocturneGardenHint(level: 1, kind: .move, action: .sun(3), elevation: 2)
        #expect(sun.text == "Set the sun to 3 of 4")
        #expect(sun.at(level: 2).text == "Set the sun to 3 of 4, lower middle, shadows one and a half times as tall")
        #expect(sun.at(level: 3).text == sun.at(level: 2).text)
        let remove = NocturneGardenHint(level: 1, kind: .move, action: .remove(1), elevation: 3, bloom: rose)
        #expect(remove.text == "Remove bloom 2")
        #expect(remove.at(level: 2).text == "Remove bloom 2, a rose of size 2")
        #expect(remove.at(level: 3).text == "Remove bloom 2, a rose of size 2 at column 5, row 1")
        let move = NocturneGardenHint(level: 3, kind: .move, action: .move(1, 7, 2), elevation: 3, bloom: rose)
        #expect(move.at(level: 1).text == "Move bloom 2")
        #expect(move.text == "Move bloom 2, a rose of size 2 to column 7, row 2")
        let resize = NocturneGardenHint(level: 2, kind: .move, action: .resize(1, 3), elevation: 3, bloom: rose)
        #expect(resize.at(level: 1).text == "Resize bloom 2" && resize.text == "Resize bloom 2, a rose, to size 3")
        #expect(resize.at(level: 3).text == "Resize bloom 2, a rose at column 5, row 1, to size 3")
        for level in 1...3 {
            #expect(NocturneGardenHint(level: level, kind: .stuck).text
                    == "No way to match the target was found in the moves left: undo the last move or retry the level.")
            #expect(NocturneGardenHint(level: level, kind: .stuck, failed: true).text
                    == "Undo the last move or retry the level.")
        }
    }

    /// A real opening whose certified solution starts with a sun move is hinted that sun move; loading, tutorial, won
    /// and result-after-win plays get no hint; failed and result-after-failure plays get the failed `stuck` hint.
    @Test func hintsFollowTheStage() throws {
        let catalog: [NocturneGardenGenerated] = try hintCatalog()
        var sunHinted: Bool = false
        for generated in catalog where !sunHinted {
            guard case let .sun(value) = generated.solution.actions[0] else { continue }
            let opening: NocturneGardenPlay = try NocturneGardenExperienceCore.freshPlay(of: generated.level)
            let hint: NocturneGardenHint = try #require(NocturneGardenHints.hint(level: 1, play: opening))
            #expect(hint.kind == .move && hint.action == .sun(value))
            #expect(hint.text == "Set the sun to \(value) of 4")
            sunHinted = true
        }
        #expect(sunHinted)
        let generated: NocturneGardenGenerated = catalog[0]
        let level: NocturneGardenLevel = generated.level
        var play = NocturneGardenPlay(level: level)
        #expect(NocturneGardenHints.hint(level: 1, play: play) == nil && NocturneGardenHints.plan(play) == nil)
        try play.handle(.begin)
        if level.tutorial {
            #expect(NocturneGardenHints.hint(level: 1, play: play) == nil)
            try play.handle(.dismissTutorial)
        }
        let first: NocturneGardenHint = try #require(NocturneGardenHints.hint(level: 2, play: play))
        #expect(first.kind == .move && first.level == 2)
        try play.handle(.pause)
        #expect(NocturneGardenHints.hint(level: 2, play: play)?.action == first.action)
        try play.handle(.resume)
        for action in generated.solution.actions { try play.apply(action, expecting: play.fingerprint) }
        #expect(play.stage == .won && NocturneGardenHints.hint(level: 3, play: play) == nil)
        try play.handle(.showResult)
        #expect(NocturneGardenHints.hint(level: 3, play: play) == nil)
        // A failed play: sun moves (or plant-and-remove pairs) spend the budget on an empty bed.
        var failing: NocturneGardenPlay = try NocturneGardenExperienceCore.freshPlay(of: level)
        let elevations: [Int] = level.elevations.sorted()
        var guardCount: Int = 0
        while failing.stage == .playing && guardCount < 200 {
            guardCount += 1
            if elevations.count > 1 {
                let next: Int = failing.elevation == elevations[0] ? elevations[1] : elevations[0]
                try failing.apply(.sun(next), expecting: failing.fingerprint)
            } else if failing.blooms.isEmpty {
                let kind: NocturneGardenKind = NocturneGardenKind.allCases.first { level.supplyCount($0) > 0 } ?? .rose
                try failing.apply(.plant(kind, 0, 0, level.sizes.sorted()[0]), expecting: failing.fingerprint)
            } else {
                try failing.apply(.remove(0), expecting: failing.fingerprint)
            }
        }
        if failing.stage == .failed {
            let stuck: NocturneGardenHint = try #require(NocturneGardenHints.hint(level: 1, play: failing))
            #expect(stuck.kind == .stuck && stuck.action == nil)
            #expect(stuck.text == "Undo the last move or retry the level.")
            try failing.handle(.showResult)
            #expect(NocturneGardenHints.hint(level: 3, play: failing)?.text == NocturneGardenHint.failedText)
        }
    }

    // MARK: Failures

    /// 500 seeded failures in 10 groups of 50, group g on levels 10·g + 1 … 10·g + 10 (leak runs: random actions;
    /// budget runs: one random action, then sun moves): each is explained with its true reason, move and counts, tracked
    /// here (own move index, own mask, own leak and match).
    @Test(arguments: Array(0..<10))
    func failuresAreExplained(group: Int) throws {
        var random = SeededRandom(seed: Self.seed &+ 1_000 &+ UInt64(group))
        var explained: Int = 0
        var leaks: Int = 0
        var budgets: Int = 0
        var attempts: Int = 0
        while explained < 50 && attempts < 5_000 {
            attempts += 1
            let number: Int = 10 * group + random.int(1...10)
            let level: NocturneGardenLevel = try NocturneGardenExperienceCore.generated(number: number).level
            var play: NocturneGardenPlay = try NocturneGardenExperienceCore.freshPlay(of: level)
            let leakRun: Bool = random.int(0...1) == 0
            let elevations: [Int] = level.elevations.sorted()
            var failingMove: Int = -1
            for _ in 0..<200 {
                guard play.stage == .playing else { break }
                var action: NocturneGardenAction = randomAction(play, &random)
                if !leakRun && elevations.count > 1 && play.moves > 0 {
                    action = .sun(play.elevation == elevations[0] ? elevations[elevations.count - 1] : elevations[0])
                }
                let moveBefore: Int = play.moves
                do {
                    try play.apply(action, expecting: play.fingerprint)
                } catch {
                    continue
                }
                if play.stage == .failed { failingMove = moveBefore }
            }
            guard play.stage == .failed else { continue }
            if random.int(0...4) == 0 { try play.handle(.showResult) }
            let explanation: NocturneGardenFailureExplanation = try #require(
                NocturneGardenFailureExplanation(play: play))
            let mask: Set<Int> = ownMask(play)
            let leak: Int = mask.intersection(level.forbidden).count
            let shared: Int = mask.intersection(level.target).count
            let either: Int = mask.union(level.target).count
            let advice: String = " Undo the last move or retry the level."
            #expect(explanation.leak == leak && explanation.shared == shared && explanation.either == either)
            #expect(explanation.allowed == level.leakAllowance)
            if leak > level.leakAllowance {
                leaks += 1
                #expect(explanation.failure == .leak(failingMove) && explanation.move == failingMove + 1)
                let head: String = "The shadow leaked into \(NocturneGardenLevel.cellsText(leak)) of the forbidden "
                    + "regions at move \(failingMove + 1) ("
                let tail: String = "), \(level.leakAllowance) allowed." + advice
                #expect(explanation.text.hasPrefix(head) && explanation.text.hasSuffix(tail), "\(explanation.text)")
            } else {
                budgets += 1
                #expect(play.moves == level.budget && failingMove == level.budget - 1)
                #expect(explanation.failure == .budget && explanation.move == level.budget)
                #expect(explanation.text == "The moves ran out: \(level.budget) of \(level.budget) spent with a match "
                        + "of \(shared)/\(either); it needs \(level.required.text)." + advice)
            }
            // The explanation never changes the play.
            #expect(NocturneGardenFailureExplanation(play: play) == explanation)
            explained += 1
        }
        print("NocturneGardenHintsTests failures group \(group): \(explained) explained, \(leaks) leaks, "
              + "\(budgets) budgets")
        #expect(explained == 50 && leaks >= 5 && budgets >= 5, "group \(group): \(leaks) leaks, \(budgets) budgets")
        // No explanation outside a failure.
        let opening: NocturneGardenPlay = try NocturneGardenExperienceCore.freshPlay(
            of: try NocturneGardenExperienceCore.generated(number: 10 * group + 1).level)
        #expect(NocturneGardenFailureExplanation(play: opening) == nil)
    }
}


