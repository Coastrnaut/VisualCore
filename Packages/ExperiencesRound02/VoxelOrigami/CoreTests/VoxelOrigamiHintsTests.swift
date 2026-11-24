// VoxelOrigamiHintsTests — feature 445 (R02-G15-05) T-R02G1505-002 (FR-R02G1505-002, 003, 007; SC-R02G1505-002, 003;
// clarifications Q1, Q5). Hints and failure explanations on the 100 certified levels (certified once per process
// through the experience core's cache, prewarmed concurrently): on every level `plan(_:turns:)` at the start turns
// equals `plan(_:)` and the certified plan, the hint plan from the opening is the certified plan's turns and
// following exact (level 3) hints (re-asked after every turn) wins spending exactly the certified plan's turns, within
// the budget, one level per test case; the new solver entry refuses turns of the wrong count or out of range, a
// colliding pose and a matching pose; 200 seeded reachable states (seed 2_445, 100 groups of 2: random accepted turns
// from openings, failing and winning ones skipped, about one in five paused) get a hint the kernel accepts whenever a
// plan exists, following hints from there wins within the actions left, and a hint never changes the play; the three
// hint levels read as clarification Q1 says (on ten levels, two per band); loading, tutorial, won and
// result-after-win plays get no hint, failed ones `stuck`; 500 seeded failures (25 groups of 20: random turns with
// undos, collisions, sweeps and budget-outs, some undone and redone back into the failure, some shown as a result)
// are explained with the true action number, hinge, step, cubes and cell, the expectation built here from the actions
// tracked independently of the play and the kernel's failure payload. Each test prints its duration (no wall-clock
// assertion). Deterministic, explicit types, plain loops.
import Foundation
import Testing
import VisualCoreSimulation
@testable import VoxelOrigamiCore

/// The 100 certified levels and plans in manifest order, certified concurrently once per test process.
private let hintCatalogResult: Result<[VoxelOrigamiGenerated], any Error> = Result {
    DispatchQueue.concurrentPerform(iterations: 100) { (index: Int) in
        _ = try? VoxelOrigamiExperienceCore.generated(number: index + 1)
    }
    var catalog: [VoxelOrigamiGenerated] = []
    for number in 1...100 { catalog.append(try VoxelOrigamiExperienceCore.generated(number: number)) }
    return catalog
}

/// The certified catalog.
private func hintCatalog() throws -> [VoxelOrigamiGenerated] { try hintCatalogResult.get() }

/// The opening play of manifest number `number` (begun, past its tutorial).
private func openingPlay(_ number: Int) throws -> VoxelOrigamiPlay {
    try VoxelOrigamiExperienceCore.opening(number: number).play
}

/// Follows exact (level 3) hints from `start` (resumed when paused) until the play ends; the problems found (empty:
/// won, every hinted turn accepted, the play unchanged by every hint) and the actions spent following them.
private func followHints(_ start: VoxelOrigamiPlay, label: String) -> (problems: [String], spent: Int) {
    var play: VoxelOrigamiPlay = start
    if play.stage == .paused { try? play.handle(.resume) }
    let spentBefore: Int = play.actionsSpent
    for _ in 0..<64 {
        if play.stage == .won { return ([], play.actionsSpent - spentBefore) }
        let before: VoxelOrigamiPlay = play
        guard let hint = VoxelOrigamiHints.hint(level: 3, play: play) else {
            return (["\(label): no hint in \(play.stage)"], play.actionsSpent - spentBefore)
        }
        guard play == before else { return (["\(label): the hint changed the play"], play.actionsSpent - spentBefore) }
        guard let action = hint.action else {
            return (["\(label): stuck with \(play.actionsLeft) actions left"], play.actionsSpent - spentBefore)
        }
        do {
            try play.apply(action, expecting: play.fingerprint)
        } catch {
            return (["\(label): hinted \(action) refused: \(error)"], play.actionsSpent - spentBefore)
        }
    }
    return (play.stage == .won ? [] : ["\(label): not won, stage \(play.stage)"], play.actionsSpent - spentBefore)
}

/// Prints the seconds since `start` for `name` (evidence of the test's duration; never asserted).
private func report(_ name: String, since start: ContinuousClock.Instant) {
    let elapsed: Duration = ContinuousClock.now - start
    print("VoxelOrigamiHintsTests \(name): \(elapsed)")
}

/// A whole random number 0 ..< `count`.
private func below(_ count: Int, _ random: inout SeededRandom) -> Int {
    min(Int(random.double() * Double(count)), max(count - 1, 0))
}

/// The turns of `play` sorted by what they would do now (each as (hinge, step)).
private struct TurnOptions {
    /// Turns the lattice check refuses with a collision.
    var collisions: [(Int, Int)] = []
    /// Turns the lattice check refuses with a sweep.
    var sweeps: [(Int, Int)] = []
    /// Clear turns that win.
    var winning: [(Int, Int)] = []
    /// Clear turns that do not win.
    var plain: [(Int, Int)] = []
}

/// The turns of `play` sorted by what they would do now: refused by the lattice check with a collision or a sweep,
/// clear and winning, clear and not winning. Idle hinges are left out.
private func classifiedTurns(_ play: VoxelOrigamiPlay) -> TurnOptions {
    var options = TurnOptions()
    var winning: [(Int, Int)] = []
    var plain: [(Int, Int)] = []
    let level: VoxelOrigamiLevel = play.level
    for hinge in 1..<level.cubes.count where level.canTurn(hinge, turns: play.turns) {
        for step in [-1, 1] {
            switch VoxelOrigamiLattice.check(level.cubes, turns: play.turns, hinge: hinge, step: step) {
            case .collision?:
                options.collisions.append((hinge, step))
                continue
            case .sweep?:
                options.sweeps.append((hinge, step))
                continue
            case .budget?, nil:
                break
            }
            let next: [Int] = VoxelOrigamiLattice.turned(play.turns, hinge: hinge, step: step)
            if level.report(turns: next).matched {
                winning.append((hinge, step))
            } else {
                plain.append((hinge, step))
            }
        }
    }
    options.winning = winning
    options.plain = plain
    return options
}

/// One seeded reachable state: the level number and the play.
private struct HintSample: Sendable {
    /// The manifest number.
    let number: Int
    /// The play (playing or paused, actions left).
    let play: VoxelOrigamiPlay
}

/// The 200 seeded reachable states (seed 2_445): a random level's opening, then 0 … 6 random accepted turns (refused
/// and winning ones skipped, at least one action left), about one in five then paused.
private let hintSamplesResult: Result<[HintSample], any Error> = Result {
    _ = try hintCatalog()
    var random = SeededRandom(seed: VoxelOrigamiHintsTests.seed)
    var samples: [HintSample] = []
    while samples.count < 200 {
        let number: Int = below(100, &random) + 1
        var play: VoxelOrigamiPlay = try openingPlay(number)
        let wanted: Int = below(7, &random)
        var applied: Int = 0
        var tries: Int = 0
        while applied < wanted, play.actionsLeft > 1, tries < 64 {
            tries += 1
            let hinge: Int = below(play.level.cubes.count - 1, &random) + 1
            let step: Int = below(2, &random) == 0 ? -1 : 1
            guard play.level.canTurn(hinge, turns: play.turns),
                  VoxelOrigamiLattice.check(play.level.cubes, turns: play.turns, hinge: hinge, step: step) == nil,
                  !play.level.report(turns: VoxelOrigamiLattice.turned(play.turns, hinge: hinge, step: step)).matched
            else { continue }
            try play.apply(.turn(hinge, step), expecting: play.fingerprint)
            applied += 1
        }
        if below(5, &random) == 0 { try play.handle(.pause) }
        samples.append(HintSample(number: number, play: play))
    }
    return samples
}

/// The seeded reachable states.
private func hintSamples() throws -> [HintSample] { try hintSamplesResult.get() }

@Suite struct VoxelOrigamiHintsTests {
    /// The test seed of this feature.
    static let seed: UInt64 = 2_445

    // MARK: Openings

    /// On every certified level (one per case): `plan(_:turns:)` at the start turns equals `plan(_:)` and the
    /// certified plan; the hint plan from the opening is the certified plan's turns; following exact hints wins
    /// spending exactly the certified plan's turns, within the budget.
    @Test(arguments: Array(1...100))
    func followingHintsFromTheOpeningWins(number: Int) throws {
        let started: ContinuousClock.Instant = ContinuousClock.now
        defer { report("opening of level \(number)", since: started) }
        let catalog: [VoxelOrigamiGenerated] = try hintCatalog()
        let generated: VoxelOrigamiGenerated = catalog[number - 1]
        let level: VoxelOrigamiLevel = generated.level
        let atStart: VoxelOrigamiPlan? = VoxelOrigamiSolver.plan(level, turns: level.startTurns)
        #expect(atStart == VoxelOrigamiSolver.plan(level), "level \(number)")
        #expect(atStart == generated.plan, "level \(number)")
        let opening: VoxelOrigamiPlay = try openingPlay(number)
        #expect(VoxelOrigamiHints.plan(opening)?.turns == generated.plan.turns, "level \(number)")
        let outcome: (problems: [String], spent: Int) = followHints(opening, label: "level \(number)")
        #expect(outcome.problems.isEmpty, "\(outcome.problems)")
        #expect(outcome.spent == generated.plan.size && outcome.spent <= level.budget, "level \(number)")
    }

    /// `plan(_:turns:)` refuses turns of the wrong count, a turn outside 0 … 3, a pose with two cubes on one cell and
    /// a pose that already matches; one certified turn in, the plan from there is one turn shorter and is the rest of
    /// the certified plan's length.
    @Test func planFromTurnsChecksItsInputs() throws {
        let started: ContinuousClock.Instant = ContinuousClock.now
        defer { report("plan inputs", since: started) }
        let catalog: [VoxelOrigamiGenerated] = try hintCatalog()
        let generated: VoxelOrigamiGenerated = catalog[60]
        let level: VoxelOrigamiLevel = generated.level
        let start: [Int] = level.startTurns
        var short: [Int] = start
        short.removeLast()
        #expect(VoxelOrigamiSolver.plan(level, turns: short) == nil)
        #expect(VoxelOrigamiSolver.plan(level, turns: start + [0]) == nil)
        var tooBig: [Int] = start
        tooBig[1] = 4
        #expect(VoxelOrigamiSolver.plan(level, turns: tooBig) == nil)
        var negative: [Int] = start
        negative[1] = -1
        #expect(VoxelOrigamiSolver.plan(level, turns: negative) == nil)
        // A colliding pose: the first quarter-turn vector (in counting order over 4^n) whose pose repeats a cell.
        var colliding: [Int]?
        var probe: [Int] = start
        var counter: Int = 0
        while colliding == nil, counter < 100_000 {
            var value: Int = counter
            for index in 1..<probe.count {
                probe[index] = value % 4
                value /= 4
            }
            if !level.pose(turns: probe).isCollisionFree { colliding = probe }
            counter += 1
        }
        #expect(colliding != nil)
        if let colliding { #expect(VoxelOrigamiSolver.plan(level, turns: colliding) == nil) }
        var turns: [Int] = start
        for action in generated.plan.turns {
            guard case .turn(let hinge, let step) = action else { continue }
            turns = VoxelOrigamiLattice.turned(turns, hinge: hinge, step: step)
        }
        #expect(level.report(turns: turns).matched)
        #expect(VoxelOrigamiSolver.plan(level, turns: turns) == nil)
        guard case .turn(let hinge, let step) = generated.plan.turns[0] else { return }
        let first: [Int] = VoxelOrigamiLattice.turned(start, hinge: hinge, step: step)
        #expect(VoxelOrigamiSolver.plan(level, turns: first)?.size == generated.plan.size - 1)
    }

    // MARK: Seeded reachable states

    /// 200 seeded reachable states (100 groups of 2): the exact hint is a turn the kernel accepts whenever a plan
    /// exists, the plan fits the actions left, following hints (after the hinted turn) wins within them, and no hint
    /// changes the play; on one state in eight (the first of every fourth group) the hints of levels 1 and 2 suggest
    /// the same turn.
    @Test(arguments: Array(0..<100))
    func seededStatesGetAcceptedHints(group: Int) throws {
        let started: ContinuousClock.Instant = ContinuousClock.now
        defer { report("seeded states group \(group)", since: started) }
        let samples: [HintSample] = try hintSamples()
        for offset in 0..<2 {
            let sample: HintSample = samples[2 * group + offset]
            let label: String = "sample \(2 * group + offset) (level \(sample.number))"
            let play: VoxelOrigamiPlay = sample.play
            let plan: VoxelOrigamiHintPlan? = VoxelOrigamiHints.plan(play)
            guard let hint = VoxelOrigamiHints.hint(level: 3, play: play) else {
                Issue.record("\(label): no hint while \(play.stage)")
                continue
            }
            for level in 1...2 where offset == 0 && group % 4 == 0 {
                let other: VoxelOrigamiHint? = VoxelOrigamiHints.hint(level: level, play: play)
                #expect(other?.action == hint.action && other?.kind == hint.kind && other?.level == level, "\(label)")
            }
            #expect(play == sample.play, "\(label): the hint changed the play")
            guard let plan, let action = hint.action else {
                #expect(plan == nil && hint.kind == .stuck && hint.text == VoxelOrigamiHint.stuckText, "\(label)")
                continue
            }
            #expect(hint.kind == .turn && plan.turns.first == action, "\(label)")
            #expect(plan.turns.count <= play.actionsLeft, "\(label)")
            var copy: VoxelOrigamiPlay = play
            if copy.stage == .paused { try copy.handle(.resume) }
            do {
                try copy.apply(action, expecting: copy.fingerprint)
            } catch {
                Issue.record("\(label): hinted \(action) refused: \(error)")
            }
            #expect(copy.failure == nil, "\(label): hinted \(action) failed the play")
            let outcome: (problems: [String], spent: Int) = followHints(copy, label: label)
            #expect(outcome.problems.isEmpty, "\(outcome.problems)")
            #expect(outcome.spent + 1 == plan.turns.count && outcome.spent + 1 <= play.actionsLeft, "\(label)")
        }
    }

    // MARK: Texts and stages

    /// The three hint levels read as clarification Q1 says (levels clamped to 1 … 3) at the openings of levels 1, 11,
    /// … 91 (two per band), the cube of level 1 being the hinge's tracked cube at the current pose.
    @Test func hintLevelsReadAsClarified() throws {
        let started: ContinuousClock.Instant = ContinuousClock.now
        defer { report("hint levels", since: started) }
        let catalog: [VoxelOrigamiGenerated] = try hintCatalog()
        var plus: Int = 0
        var minus: Int = 0
        for number in stride(from: 1, through: 100, by: 10) {
            let play: VoxelOrigamiPlay = try openingPlay(number)
            guard case .turn(let hinge, let step) = catalog[number - 1].plan.turns[0] else { continue }
            let moving: [Int] = VoxelOrigamiLattice.swinging(play.level.cubes, pose: play.pose, hinge: hinge)
            let cube: Int = VoxelOrigamiPicker.trackedCube(hinge, cubes: play.level.cubes, pose: play.pose,
                                                           moving: moving)
            #expect(moving.contains(cube), "level \(number)")
            let exact: String = step < 0 ? "Turn hinge \(hinge) back (\u{2212}1)" : "Turn hinge \(hinge) forward (+1)"
            if step < 0 { minus += 1 } else { plus += 1 }
            #expect(VoxelOrigamiHints.hint(level: 1, play: play)?.text == "The next turn swings cube \(cube)")
            #expect(VoxelOrigamiHints.hint(level: 0, play: play)?.level == 1)
            #expect(VoxelOrigamiHints.hint(level: 2, play: play)?.text == "Turn hinge \(hinge)")
            #expect(VoxelOrigamiHints.hint(level: 3, play: play)?.text == exact)
            #expect(VoxelOrigamiHints.hint(level: 9, play: play)?.text == exact)
            #expect(VoxelOrigamiHints.hint(level: 9, play: play)?.level == 3)
        }
        #expect(plus > 0 && minus > 0)
        #expect(VoxelOrigamiHint.turnText(level: 3, hinge: 4, step: -1, cube: 5) == "Turn hinge 4 back (−1)")
        #expect(VoxelOrigamiHint.turnText(level: 3, hinge: 2, step: 1, cube: 5) == "Turn hinge 2 forward (+1)")
    }

    /// Loading, tutorial, won and result-after-win plays get no hint; failed and result-after-failure plays get
    /// `stuck` with the failed text; a play with no room for its plan gets `stuck` with the stuck text; a paused play
    /// is hinted as playing. No explanation without a failure.
    @Test func hintsByStage() throws {
        let started: ContinuousClock.Instant = ContinuousClock.now
        defer { report("stages", since: started) }
        let catalog: [VoxelOrigamiGenerated] = try hintCatalog()
        let level: VoxelOrigamiLevel = catalog[0].level
        #expect(level.tutorial)
        var play = VoxelOrigamiPlay(level: level)
        #expect(VoxelOrigamiHints.hint(level: 1, play: play) == nil)
        #expect(VoxelOrigamiHints.plan(play) == nil)
        try play.handle(.begin)
        #expect(play.stage == .tutorial)
        #expect(VoxelOrigamiHints.hint(level: 1, play: play) == nil)
        try play.handle(.dismissTutorial)
        let playing: VoxelOrigamiHint? = VoxelOrigamiHints.hint(level: 2, play: play)
        #expect(playing?.kind == .turn)
        #expect(VoxelOrigamiFailureExplanation(play: play) == nil)
        try play.handle(.pause)
        #expect(VoxelOrigamiHints.hint(level: 2, play: play) == playing)
        try play.handle(.resume)
        for action in catalog[0].plan.turns { try play.apply(action, expecting: play.fingerprint) }
        #expect(play.stage == .won)
        #expect(VoxelOrigamiHints.hint(level: 3, play: play) == nil)
        #expect(VoxelOrigamiFailureExplanation(play: play) == nil)
        try play.handle(.showResult)
        #expect(VoxelOrigamiHints.hint(level: 3, play: play) == nil)
        #expect(VoxelOrigamiFailureExplanation(play: play) == nil)
        // A budget-out: plain turns until the budget is spent.
        var failing: VoxelOrigamiPlay = try openingPlay(1)
        while failing.stage == .playing {
            let options: TurnOptions = classifiedTurns(failing)
            guard let (hinge, step) = options.plain.first else { break }
            if failing.actionsLeft <= catalog[0].plan.size, failing.actionsLeft > 1 {
                // Few actions left and away from the target: the plan may not fit; either way the hint is honest.
                let hint: VoxelOrigamiHint? = VoxelOrigamiHints.hint(level: 3, play: failing)
                if VoxelOrigamiHints.plan(failing) == nil {
                    #expect(hint?.kind == .stuck && hint?.text == VoxelOrigamiHint.stuckText)
                }
            }
            try failing.apply(.turn(hinge, step), expecting: failing.fingerprint)
        }
        #expect(failing.stage == .failed)
        let failed: VoxelOrigamiHint? = VoxelOrigamiHints.hint(level: 2, play: failing)
        #expect(failed?.kind == .stuck && failed?.action == nil && failed?.text == VoxelOrigamiHint.failedText)
        #expect(VoxelOrigamiHint.failedText == "Undo the last action or retry the level.")
        #expect(VoxelOrigamiHint.stuckText
            == "No way to win was found in the actions left: undo the last action or retry the level.")
        try failing.handle(.showResult)
        #expect(VoxelOrigamiHints.hint(level: 1, play: failing)?.text == VoxelOrigamiHint.failedText)
        #expect(VoxelOrigamiFailureExplanation(play: failing) != nil)
    }

    // MARK: Seeded failures

    /// 500 seeded failures (25 groups of 20): each is explained with the true action number, hinge, step, cubes and
    /// cell, built here from the actions tracked independently of the play and the kernel's failure payload; every
    /// group holds collisions, sweeps and budget-outs.
    @Test(arguments: Array(0..<25))
    func seededFailuresAreExplained(group: Int) throws {
        let started: ContinuousClock.Instant = ContinuousClock.now
        defer { report("failures group \(group)", since: started) }
        let counts: [String: Int] = try explainFailures(group: group)
        #expect(counts["budget", default: 0] > 0, "group \(group): \(counts)")
        #expect(counts["collision", default: 0] > 0, "group \(group): \(counts)")
        #expect(counts["sweep", default: 0] > 0, "group \(group): \(counts)")
    }

    /// Drives 20 seeded failures of group `group` (seed 2_445 · 1000 + group) and checks each explanation; returns the
    /// count of each failure code.
    func explainFailures(group: Int) throws -> [String: Int] {
        _ = try hintCatalog()
        var random = SeededRandom(seed: Self.seed &* 1_000 &+ UInt64(group))
        var counts: [String: Int] = [:]
        var made: Int = 0
        var attempts: Int = 0
        while made < 20, attempts < 200 {
            attempts += 1
            let number: Int = below(100, &random) + 1
            var play: VoxelOrigamiPlay = try openingPlay(number)
            // In turn the failures aim at the budget (plain turns only), a collision and a sweep (either refused
            // kind when the aimed one is not on offer).
            let aim: Int = made % 3
            let aimBudget: Bool = aim == 0
            var applied: [(Int, Int)] = []
            var undone: [(Int, Int)] = []
            var failing: (Int, Int)?
            var moves: Int = 0
            while play.stage == .playing, moves < 200 {
                moves += 1
                let options: TurnOptions = classifiedTurns(play)
                let roll: Int = below(10, &random)
                if roll == 0, play.canUndo {
                    try play.undo()
                    if let last = applied.popLast() { undone.append(last) }
                    continue
                }
                if roll == 1, play.canRedo, let back = undone.last {
                    let wouldWin: Bool = play.level.report(
                        turns: VoxelOrigamiLattice.turned(play.turns, hinge: back.0, step: back.1)).matched
                    if !wouldWin {
                        try play.redo()
                        applied.append(back)
                        undone.removeLast()
                        continue
                    }
                }
                let pick: (Int, Int)
                let preferred: [(Int, Int)] = aim == 1 ? options.collisions : options.sweeps
                let refused: [(Int, Int)] = preferred.isEmpty ? options.collisions + options.sweeps : preferred
                if !aimBudget, !refused.isEmpty, roll >= 6 {
                    pick = refused[below(refused.count, &random)]
                } else if !options.plain.isEmpty {
                    pick = options.plain[below(options.plain.count, &random)]
                } else {
                    break
                }
                try play.apply(.turn(pick.0, pick.1), expecting: play.fingerprint)
                applied.append(pick)
                undone.removeAll()
                if play.stage == .failed { failing = pick }
            }
            guard play.stage == .failed, let failure = play.failure, let (hinge, step) = failing else { continue }
            let number1: Int = applied.count
            // Some failures are undone and redone back into the failure, some shown as a result.
            let extra: Int = below(4, &random)
            if extra == 0 {
                try play.undo()
                #expect(VoxelOrigamiFailureExplanation(play: play) == nil)
                try play.redo()
                #expect(play.stage == .failed)
            } else if extra == 1 {
                try play.handle(.showResult)
            }
            let way: String = step < 0 ? "\u{2212}1" : "+1"
            let head: String = "Action \(number1) (a turn of hinge \(hinge) by \(way))"
            let expected: String
            let code: String
            switch failure {
            case .collision(let failedHinge, let moving, let still, let cell):
                #expect(failedHinge == hinge)
                code = "collision"
                expected = head + " would put cube \(moving) on cube \(still) at (\(cell.x), \(cell.y), \(cell.z))."
            case .sweep(let failedHinge, let moving, let still, let cell):
                #expect(failedHinge == hinge)
                code = "sweep"
                expected = head + " would swing cube \(moving) through cube \(still) at"
                    + " (\(cell.x), \(cell.y), \(cell.z))."
            case .budget(let index):
                #expect(index + 1 == number1 && number1 == play.level.budget)
                code = "budget"
                expected = head + " spent the last action without a match."
            }
            let explanation: VoxelOrigamiFailureExplanation? = VoxelOrigamiFailureExplanation(play: play)
            let label: String = "group \(group) failure \(made) (level \(number), \(code))"
            #expect(explanation?.failure == failure, "\(label)")
            #expect(explanation?.action == number1, "\(label)")
            #expect(explanation?.text == expected + " Undo the last action or retry the level.", "\(label)")
            counts[code, default: 0] += 1
            made += 1
        }
        #expect(made == 20, "group \(group): only \(made) failures")
        return counts
    }
}
