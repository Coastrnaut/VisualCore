// CelestialEclipseLabHintsTests — feature 465 (R02-G17-05) T-R02G1705-002 (FR-R02G1705-002, 003, 007; SC-R02G1705-002,
// 003; clarifications Q1, Q5). Hints and failure explanations on the 100 certified levels, read from the stored
// witnesses in docs/games/celestial-eclipse-lab/levels/ with the plain decoder (as CelestialEclipseLabCatalogTests
// reads them): on every level `plan(_:)` equals the new entry `plan(_:from:)` at the level's starting phases and the
// witness's phase changes; the hint plan from the opening is those changes and following exact (level 3) hints,
// re-asked after every action, then the hinted run wins spending exactly the witness's changes, within the budget, in
// 10 groups of 10 levels; the new solver entry refuses a phase vector of the wrong length or out of range, gives a plan
// of no changes for phases that already win, and one witness change in, the plan from there is one change shorter; 200
// seeded reachable states (seed 2_465, 20 groups of 10: 0 … 2 random accepted phase changes from a random opening) get
// a hint the kernel accepts whenever a plan exists (the run when the phases already win), following hints from there
// wins within the actions left, and no hint, plan or explanation changes the play; the three hint levels read as
// clarification Q1 says; loading, tutorial, paused, won and result-after-win plays get no hint, failed and
// result-after-failure ones the failed advice, a play with no way left `stuck`; 500 seeded failures (seed 2_465, 25
// groups of 20: random accepted changes, about one in five a state with a horizon failure found by a search of the
// openings, some runs undone and redone, some shown as a result) are explained with the true planets, target number and
// ticks, the expectation built here from phases tracked independently of the play and a judge written here over the
// kernel's intervals; every one of the three failures is explained at least once. Each test prints its duration (no
// wall-clock assertion). Deterministic, explicit types, plain loops.
import Foundation
import Testing
import VisualCoreSimulation
@testable import CelestialEclipseLabCore

/// The repository's witness directory, found from this file (five levels up: CoreTests, CelestialEclipseLab, the
/// package, Packages).
private let hintWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/celestial-eclipse-lab/levels", isDirectory: true)

/// The 100 stored witnesses in manifest order, read once per test process with the plain decoder.
private let hintWitnessesResult: Result<[CelestialEclipseLabWitness], any Error> = Result {
    var result: [CelestialEclipseLabWitness] = []
    for entry in CelestialEclipseLabManifest.entries {
        let name: String = String(CelestialEclipseLabGenerator.levelID(entry.number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: hintWitnessDirectory.appendingPathComponent(name))
        result.append(try JSONDecoder().decode(CelestialEclipseLabWitness.self, from: data))
    }
    return result
}

/// The stored witnesses.
private func hintWitnesses() throws -> [CelestialEclipseLabWitness] { try hintWitnessesResult.get() }

/// The phase changes of a witness (its actions without the closing run).
private func witnessChanges(_ witness: CelestialEclipseLabWitness) -> [CelestialEclipseLabAction] {
    var result: [CelestialEclipseLabAction] = []
    for action in witness.actions where action != .run { result.append(action) }
    return result
}

/// The opening play of `level`: begun, past its tutorial.
private func openingPlay(_ level: CelestialEclipseLabLevel) throws -> CelestialEclipseLabPlay {
    try CelestialEclipseLabExperienceCore.freshPlay(of: level)
}

/// Follows exact (level 3) hints from `start` until the play ends; the problems found (empty: won, every hinted action
/// accepted, the play unchanged by every hint) and the phase changes spent following them.
private func followHints(_ start: CelestialEclipseLabPlay, label: String) -> (problems: [String], spent: Int) {
    var play: CelestialEclipseLabPlay = start
    let spentBefore: Int = play.actionsSpent
    for _ in 0..<12 {
        if play.stage == .won { return ([], play.actionsSpent - spentBefore) }
        let before: CelestialEclipseLabPlay = play
        guard let hint = CelestialEclipseLabHints.hint(level: 3, play: play) else {
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
    print("CelestialEclipseLabHintsTests \(name): \(elapsed)")
}

/// A whole random number 0 ..< `count`.
private func below(_ count: Int, _ random: inout SeededRandom) -> Int {
    min(Int(random.double() * Double(count)), max(count - 1, 0))
}

/// A random phase change the kernel accepts from `play`'s phases (a movable body, another offset), or nil when the
/// level has no movable body.
private func randomChange(_ play: CelestialEclipseLabPlay, _ random: inout SeededRandom) -> (body: Int, offset: Int)? {
    var movable: [Int] = []
    for body in play.level.bodies.indices where !play.level.bodies[body].fixed { movable.append(body) }
    guard !movable.isEmpty else { return nil }
    let body: Int = movable[below(movable.count, &random)]
    let period: Int = play.level.bodies[body].period
    let offset: Int = (play.phases[body] + 1 + below(period - 1, &random)) % period
    return (body, offset)
}

/// "k steps", or "1 step" (written here independently of the hint engine).
private func stepWords(_ steps: Int) -> String { steps == 1 ? "1 step" : "\(steps) steps" }

/// The level-2 text for moving `body` from `from` to `to` on an orbit of `period` (written here independently: the
/// forward distance and the backward distance compared, forward on a tie).
private func wayText(body: Int, from: Int, to: Int, period: Int) -> String {
    var forward: Int = to - from
    while forward < 0 { forward += period }
    forward %= period
    let backward: Int = forward == 0 ? 0 : period - forward
    if forward <= backward { return "Move planet \(body) " + stepWords(forward) + " forward" }
    return "Move planet \(body) " + stepWords(backward) + " back"
}

/// The failure of `level` with `phases` and its explanation text, by a judge written here over the kernel's intervals
/// (a match advances, the next target's pair outside its window fails `window`, any other eclipse `unwanted`, targets
/// left at the end `horizon`); nil when the phases win.
private func expectedExplanation(_ level: CelestialEclipseLabLevel,
                                 _ phases: [Int]) -> (failure: CelestialEclipseLabFailure, text: String)? {
    let advice: String = " Undo the last action or retry the level."
    var index: Int = 0
    for interval in CelestialEclipseLabSky.intervals(level, phases: phases) where index < level.target.count {
        let next: CelestialEclipseLabTarget = level.target[index]
        let samePair: Bool = interval.front == next.front && interval.back == next.back
        if samePair && interval.first >= next.open && interval.first <= next.close {
            index += 1
            continue
        }
        if samePair {
            let text: String = "Target \(index + 1) (planet \(next.front) in front of planet \(next.back)) began at "
                + "tick \(interval.first), outside its window from tick \(next.open) to tick \(next.close)." + advice
            return (failure: .window(front: next.front, back: next.back, tick: interval.first, open: next.open,
                                     close: next.close), text: text)
        }
        let text: String = "The run met an unwanted eclipse first: planet \(interval.front) in front of planet "
            + "\(interval.back) at tick \(interval.first), before target \(index + 1) (planet \(next.front) in front "
            + "of planet \(next.back))." + advice
        return (failure: .unwanted(front: interval.front, back: interval.back, tick: interval.first), text: text)
    }
    guard index < level.target.count else { return nil }
    let next: CelestialEclipseLabTarget = level.target[index]
    let text: String = "The clock reached tick \(level.horizon - 1) before target \(index + 1) (planet \(next.front) "
        + "in front of planet \(next.back), window \(next.open) … \(next.close)) happened." + advice
    return (failure: .horizon(front: next.front, back: next.back, open: next.open, close: next.close), text: text)
}

/// The code of a failure: unwanted, window or horizon (written here).
private func failureName(_ failure: CelestialEclipseLabFailure) -> String {
    switch failure {
    case .unwanted: "unwanted"
    case .window: "window"
    case .horizon: "horizon"
    }
}

/// One seeded reachable state: the level number and the play.
private struct HintSample: Sendable {
    /// The manifest number.
    let number: Int
    /// The play (playing).
    let play: CelestialEclipseLabPlay
}

/// The 200 seeded reachable states (seed 2_465): a random level's opening, then 0 … 2 random accepted phase changes.
private let hintSamplesResult: Result<[HintSample], any Error> = Result {
    let witnesses: [CelestialEclipseLabWitness] = try hintWitnesses()
    var random = SeededRandom(seed: CelestialEclipseLabHintsTests.seed)
    var samples: [HintSample] = []
    while samples.count < 200 {
        let number: Int = below(100, &random) + 1
        var play: CelestialEclipseLabPlay = try openingPlay(witnesses[number - 1].level)
        let wanted: Int = below(3, &random)
        for _ in 0..<wanted {
            guard let change = randomChange(play, &random) else { break }
            try play.apply(.phase(change.body, change.offset), expecting: play.fingerprint)
        }
        samples.append(HintSample(number: number, play: play))
    }
    return samples
}

/// The seeded reachable states.
private func hintSamples() throws -> [HintSample] { try hintSamplesResult.get() }

/// The phase changes from `level`'s start, on one or two movable bodies, in body then phase order, of every phase
/// vector whose kernel timeline fails `horizon`.
private func horizonChanges(_ level: CelestialEclipseLabLevel) -> [[CelestialEclipseLabAction]] {
    var movable: [Int] = []
    for body in level.bodies.indices where !level.bodies[body].fixed { movable.append(body) }
    var found: [[CelestialEclipseLabAction]] = []
    for first in movable.indices {
        let a: Int = movable[first]
        for pa in 0..<level.bodies[a].period where pa != level.phases[a] {
            var single: [Int] = level.phases
            single[a] = pa
            if case .horizon? = CelestialEclipseLabSky.timeline(level, phases: single).failure {
                found.append([.phase(a, pa)])
            }
            for second in (first + 1)..<max(movable.count, first + 1) {
                let b: Int = movable[second]
                for pb in 0..<level.bodies[b].period where pb != level.phases[b] {
                    var pair: [Int] = single
                    pair[b] = pb
                    if case .horizon? = CelestialEclipseLabSky.timeline(level, phases: pair).failure {
                        found.append([.phase(a, pa), .phase(b, pb)])
                    }
                }
            }
        }
    }
    return found
}

/// The states with a horizon failure found by a search of the openings of levels 1 … 40 (``horizonChanges(_:)``),
/// each as the level number and the phase changes from the opening.
private let horizonStatesResult: Result<[(Int, [CelestialEclipseLabAction])], any Error> = Result {
    let witnesses: [CelestialEclipseLabWitness] = try hintWitnesses()
    var states: [(Int, [CelestialEclipseLabAction])] = []
    for number in 1...40 {
        for changes in horizonChanges(witnesses[number - 1].level) { states.append((number, changes)) }
    }
    return states
}

/// One seeded failure: the level number, the failed play (failed or result) and the phases tracked independently.
private struct FailureSample: Sendable {
    /// The manifest number.
    let number: Int
    /// The play after the failing run (`failed`, or `result`).
    let play: CelestialEclipseLabPlay
    /// The phases of the failing run, tracked here from the changes applied (not read from the play).
    let phases: [Int]
}

/// Applies `change` to `play` and to the tracked `phases`.
private func applyTracked(_ change: (body: Int, offset: Int), _ play: inout CelestialEclipseLabPlay,
                          _ phases: inout [Int]) throws {
    try play.apply(.phase(change.body, change.offset), expecting: play.fingerprint)
    phases[change.body] = change.offset
}

/// The 500 seeded failures (seed 2_465): about one in five a horizon state from ``horizonStatesResult``, the others a
/// random opening with 0 … 2 random accepted changes and more while the phases win (up to 8, else the draw is
/// skipped); one in four first applies and undoes a stray change; then the run fails; one in four runs is then undone
/// and redone, one in four shown as a result.
private let failureSamplesResult: Result<[FailureSample], any Error> = Result {
    let witnesses: [CelestialEclipseLabWitness] = try hintWitnesses()
    let horizons: [(Int, [CelestialEclipseLabAction])] = try horizonStatesResult.get()
    var random = SeededRandom(seed: CelestialEclipseLabHintsTests.seed)
    var samples: [FailureSample] = []
    var draws: Int = 0
    while samples.count < 500 && draws < 5_000 {
        draws += 1
        let aimHorizon: Bool = samples.count % 5 == 4 && !horizons.isEmpty
        var number: Int = below(100, &random) + 1
        var changes: [CelestialEclipseLabAction] = []
        if aimHorizon {
            let chosen: (Int, [CelestialEclipseLabAction]) = horizons[below(horizons.count, &random)]
            number = chosen.0
            changes = chosen.1
        }
        let level: CelestialEclipseLabLevel = witnesses[number - 1].level
        var play: CelestialEclipseLabPlay = try openingPlay(level)
        var phases: [Int] = level.phases
        for action in changes {
            guard case .phase(let body, let offset) = action else { continue }
            try applyTracked((body: body, offset: offset), &play, &phases)
        }
        if !aimHorizon {
            let wanted: Int = below(3, &random)
            for _ in 0..<wanted {
                if let change = randomChange(play, &random) { try applyTracked(change, &play, &phases) }
            }
            var extra: Int = 0
            while play.timeline.wins && extra < 8 && play.actionsLeft > 1 {
                if let change = randomChange(play, &random) { try applyTracked(change, &play, &phases) }
                extra += 1
            }
        }
        if play.timeline.wins { continue }
        if below(4, &random) == 0, play.actionsLeft > 0, let stray = randomChange(play, &random) {
            try play.apply(.phase(stray.body, stray.offset), expecting: play.fingerprint)
            try play.undo()
        }
        try play.apply(.run, expecting: play.fingerprint)
        let variant: Int = below(4, &random)
        if variant == 1 {
            try play.undo()
            try play.redo()
        } else if variant == 2 {
            try play.handle(.showResult)
        }
        samples.append(FailureSample(number: number, play: play, phases: phases))
    }
    return samples
}

/// The seeded failures.
private func failureSamples() throws -> [FailureSample] { try failureSamplesResult.get() }

@Suite struct CelestialEclipseLabHintsTests {
    /// The test seed of this feature.
    static let seed: UInt64 = 2_465

    // MARK: Openings

    /// On every certified level (10 groups of 10): `plan(_:)` equals the new entry at the level's starting phases and
    /// the witness's changes; the hint plan from the opening is those changes; following exact hints, then the hinted
    /// run, wins spending exactly the witness's changes, within the budget.
    @Test(arguments: Array(0..<10))
    func followingHintsFromTheOpeningWins(group: Int) throws {
        let started: ContinuousClock.Instant = ContinuousClock.now
        defer { report("openings group \(group)", since: started) }
        let witnesses: [CelestialEclipseLabWitness] = try hintWitnesses()
        for number in (10 * group + 1)...(10 * group + 10) {
            let witness: CelestialEclipseLabWitness = witnesses[number - 1]
            let level: CelestialEclipseLabLevel = witness.level
            let changes: [CelestialEclipseLabAction] = witnessChanges(witness)
            let certifying: CelestialEclipseLabPlan? = CelestialEclipseLabSolver.plan(level)
            let atStart: CelestialEclipseLabPlan? = CelestialEclipseLabSolver.plan(level, from: level.phases)
            #expect(certifying != nil && atStart == certifying, "level \(number)")
            #expect(certifying?.actions == changes, "level \(number)")
            let opening: CelestialEclipseLabPlay = try openingPlay(level)
            #expect(CelestialEclipseLabHints.plan(opening)?.changes == changes, "level \(number)")
            let outcome: (problems: [String], spent: Int) = followHints(opening, label: "level \(number)")
            #expect(outcome.problems.isEmpty, "\(outcome.problems)")
            #expect(outcome.spent == changes.count && outcome.spent <= level.budget, "level \(number)")
        }
    }

    /// The new solver entry refuses a phase vector of the wrong length or out of range, gives a plan of no changes
    /// (no settings by depth, work 1) for phases that already win, and one witness change in, the plan from there is
    /// one change shorter and wins after that change.
    @Test func planFromPhasesChecksItsInputs() throws {
        let started: ContinuousClock.Instant = ContinuousClock.now
        defer { report("plan inputs", since: started) }
        let witnesses: [CelestialEclipseLabWitness] = try hintWitnesses()
        let witness: CelestialEclipseLabWitness = witnesses[60]
        let level: CelestialEclipseLabLevel = witness.level
        let changes: [CelestialEclipseLabAction] = witnessChanges(witness)
        #expect(CelestialEclipseLabSolver.plan(level, from: Array(level.phases.dropLast())) == nil)
        #expect(CelestialEclipseLabSolver.plan(level, from: level.phases + [0]) == nil)
        var negative: [Int] = level.phases
        negative[1] = -1
        #expect(CelestialEclipseLabSolver.plan(level, from: negative) == nil)
        var outside: [Int] = level.phases
        outside[1] = level.bodies[1].period
        #expect(CelestialEclipseLabSolver.plan(level, from: outside) == nil)
        var winning: [Int] = level.phases
        for action in changes {
            if case .phase(let body, let offset) = action { winning[body] = offset }
        }
        let done: CelestialEclipseLabPlan? = CelestialEclipseLabSolver.plan(level, from: winning)
        #expect(done == CelestialEclipseLabPlan(actions: [], settingsByDepth: [], work: 1))
        var after: [Int] = level.phases
        if case .phase(let body, let offset) = changes[0] { after[body] = offset }
        let rest: CelestialEclipseLabPlan? = CelestialEclipseLabSolver.plan(level, from: after)
        #expect(rest?.size == changes.count - 1)
        #expect(rest.map { CelestialEclipseLabSolver.wins(level, actions: [changes[0]] + $0.actions) } == true)
    }

    // MARK: Seeded reachable states

    /// 200 seeded reachable states (20 groups of 10): the exact hint is a change the kernel accepts whenever a plan
    /// exists (the run, winning, when the plan is empty), the plan fits the actions left, following hints (after the
    /// hinted change) wins within them, the hints of levels 1 and 2 suggest the same action with the texts of
    /// clarification Q1, and no hint, plan or explanation changes the play.
    @Test(arguments: Array(0..<20))
    func seededStatesGetAcceptedHints(group: Int) throws {
        let started: ContinuousClock.Instant = ContinuousClock.now
        defer { report("seeded states group \(group)", since: started) }
        let samples: [HintSample] = try hintSamples()
        for offset in 0..<10 {
            let sample: HintSample = samples[10 * group + offset]
            let label: String = "sample \(10 * group + offset) (level \(sample.number))"
            let play: CelestialEclipseLabPlay = sample.play
            let plan: CelestialEclipseLabHintPlan? = CelestialEclipseLabHints.plan(play)
            let first: CelestialEclipseLabHint? = CelestialEclipseLabHints.hint(level: 1, play: play)
            let second: CelestialEclipseLabHint? = CelestialEclipseLabHints.hint(level: 2, play: play)
            let explanation: CelestialEclipseLabFailureExplanation? = CelestialEclipseLabFailureExplanation(play: play)
            guard let hint = CelestialEclipseLabHints.hint(level: 3, play: play) else {
                Issue.record("\(label): no hint while \(play.stage)")
                continue
            }
            #expect(play == sample.play, "\(label): a hint changed the play")
            #expect(explanation == nil, "\(label)")
            #expect(first?.action == hint.action && first?.kind == hint.kind && first?.level == 1, "\(label)")
            #expect(second?.action == hint.action && second?.kind == hint.kind && second?.level == 2, "\(label)")
            guard let plan else {
                #expect(hint.kind == .stuck && hint.action == nil && hint.text == CelestialEclipseLabHint.stuckText,
                        "\(label)")
                continue
            }
            #expect(plan.changes.count <= play.actionsLeft, "\(label)")
            var copy: CelestialEclipseLabPlay = play
            guard let action = plan.changes.first else {
                #expect(hint.kind == .run && hint.action == .run, "\(label)")
                #expect(hint.text == "The eclipses are in order: run the clock", "\(label)")
                try copy.apply(.run, expecting: copy.fingerprint)
                #expect(copy.stage == .won, "\(label)")
                continue
            }
            #expect(hint.kind == .change && hint.action == action, "\(label)")
            if case .phase(let body, let target) = action {
                let period: Int = play.level.bodies[body].period
                #expect(hint.text == "Set planet \(body) to phase \(target)", "\(label)")
                #expect(first?.text == "Move planet \(body) next", "\(label)")
                #expect(second?.text == wayText(body: body, from: play.phases[body], to: target, period: period),
                        "\(label)")
            }
            do {
                try copy.apply(action, expecting: copy.fingerprint)
            } catch {
                Issue.record("\(label): hinted \(action) refused: \(error)")
                continue
            }
            let outcome: (problems: [String], spent: Int) = followHints(copy, label: label)
            #expect(outcome.problems.isEmpty, "\(outcome.problems)")
            #expect(outcome.spent + 1 == plan.changes.count && outcome.spent + 1 <= play.actionsLeft, "\(label)")
        }
    }

    // MARK: Texts and stages

    /// The three hint levels read as clarification Q1 says (levels clamped to 1 … 3) at the openings of levels 1, 11,
    /// … 91, and the step texts on literal cases (the shorter way, forward on a tie, "1 step" singular).
    @Test func hintLevelsReadAsClarified() throws {
        let started: ContinuousClock.Instant = ContinuousClock.now
        defer { report("hint levels", since: started) }
        let witnesses: [CelestialEclipseLabWitness] = try hintWitnesses()
        for number in stride(from: 1, through: 100, by: 10) {
            let play: CelestialEclipseLabPlay = try openingPlay(witnesses[number - 1].level)
            guard case .phase(let body, let target) = witnessChanges(witnesses[number - 1])[0] else { continue }
            let period: Int = play.level.bodies[body].period
            let exact: String = "Set planet \(body) to phase \(target)"
            #expect(CelestialEclipseLabHints.hint(level: 1, play: play)?.text == "Move planet \(body) next")
            #expect(CelestialEclipseLabHints.hint(level: 0, play: play)?.level == 1)
            #expect(CelestialEclipseLabHints.hint(level: 2, play: play)?.text
                == wayText(body: body, from: play.phases[body], to: target, period: period))
            #expect(CelestialEclipseLabHints.hint(level: 3, play: play)?.text == exact)
            #expect(CelestialEclipseLabHints.hint(level: 9, play: play)?.text == exact)
            #expect(CelestialEclipseLabHints.hint(level: 9, play: play)?.level == 3)
        }
        #expect(CelestialEclipseLabHint.changeText(level: 2, body: 2, from: 1, to: 3, period: 8)
            == "Move planet 2 2 steps forward")
        #expect(CelestialEclipseLabHint.changeText(level: 2, body: 2, from: 3, to: 1, period: 8)
            == "Move planet 2 2 steps back")
        #expect(CelestialEclipseLabHint.changeText(level: 2, body: 1, from: 0, to: 4, period: 8)
            == "Move planet 1 4 steps forward")
        #expect(CelestialEclipseLabHint.changeText(level: 2, body: 1, from: 0, to: 7, period: 8)
            == "Move planet 1 1 step back")
        #expect(CelestialEclipseLabHint.changeText(level: 2, body: 1, from: 6, to: 0, period: 7)
            == "Move planet 1 1 step forward")
        #expect(CelestialEclipseLabHint.changeText(level: 1, body: 3, from: 6, to: 0, period: 7)
            == "Move planet 3 next")
        #expect(CelestialEclipseLabHint.changeText(level: 3, body: 3, from: 6, to: 0, period: 7)
            == "Set planet 3 to phase 0")
    }

    /// Loading, tutorial, paused, won and result-after-win plays get no hint and no plan; already in order the hint is
    /// the run; failed and result-after-failure plays get `stuck` with the failed advice; a play whose phases are back
    /// at the start with one action left (the witness needs two) is `stuck`; no explanation without a failure.
    @Test func hintsByStage() throws {
        let started: ContinuousClock.Instant = ContinuousClock.now
        defer { report("stages", since: started) }
        let witnesses: [CelestialEclipseLabWitness] = try hintWitnesses()
        let level: CelestialEclipseLabLevel = witnesses[0].level
        let changes: [CelestialEclipseLabAction] = witnessChanges(witnesses[0])
        #expect(level.tutorial)
        var play = CelestialEclipseLabPlay(level: level)
        #expect(CelestialEclipseLabHints.hint(level: 1, play: play) == nil)
        #expect(CelestialEclipseLabHints.plan(play) == nil)
        try play.handle(.begin)
        #expect(play.stage == .tutorial)
        #expect(CelestialEclipseLabHints.hint(level: 1, play: play) == nil)
        try play.handle(.dismissTutorial)
        #expect(CelestialEclipseLabHints.hint(level: 2, play: play)?.kind == .change)
        #expect(CelestialEclipseLabFailureExplanation(play: play) == nil)
        try play.handle(.pause)
        #expect(CelestialEclipseLabHints.hint(level: 2, play: play) == nil)
        #expect(CelestialEclipseLabHints.plan(play) == nil)
        try play.handle(.resume)
        for action in changes { try play.apply(action, expecting: play.fingerprint) }
        let ready: CelestialEclipseLabHint? = CelestialEclipseLabHints.hint(level: 1, play: play)
        #expect(ready?.kind == .run && ready?.action == .run)
        #expect(ready?.text == "The eclipses are in order: run the clock")
        #expect(CelestialEclipseLabHints.plan(play) == CelestialEclipseLabHintPlan(changes: []))
        try play.apply(.run, expecting: play.fingerprint)
        #expect(play.stage == .won)
        #expect(CelestialEclipseLabHints.hint(level: 3, play: play) == nil)
        #expect(CelestialEclipseLabFailureExplanation(play: play) == nil)
        try play.handle(.showResult)
        #expect(CelestialEclipseLabHints.hint(level: 3, play: play) == nil)
        #expect(CelestialEclipseLabFailureExplanation(play: play) == nil)
        // A failure: the opening's run (no valid level wins at its start).
        var failed: CelestialEclipseLabPlay = try openingPlay(level)
        try failed.apply(.run, expecting: failed.fingerprint)
        #expect(failed.stage == .failed)
        let advice: CelestialEclipseLabHint? = CelestialEclipseLabHints.hint(level: 2, play: failed)
        #expect(advice?.kind == .stuck && advice?.action == nil)
        #expect(advice?.text == "Undo the last action or retry the level.")
        #expect(CelestialEclipseLabFailureExplanation(play: failed) != nil)
        try failed.handle(.showResult)
        #expect(CelestialEclipseLabHints.hint(level: 1, play: failed)?.text
            == "Undo the last action or retry the level.")
        #expect(CelestialEclipseLabFailureExplanation(play: failed) != nil)
        // Stuck: back at the start phases with one action left.
        var stuck: CelestialEclipseLabPlay = try openingPlay(level)
        guard case .phase(let body, _) = changes[0] else { return }
        let start: Int = level.phases[body]
        let total: Int = level.budget - 1
        for step in 0..<total {
            var next: Int = start
            if step < total - 1 {
                next = 0
                while next == start || next == stuck.phases[body] { next += 1 }
            }
            try stuck.apply(.phase(body, next), expecting: stuck.fingerprint)
        }
        #expect(stuck.phases == level.phases && stuck.actionsLeft == 1)
        #expect(CelestialEclipseLabHints.plan(stuck) == nil)
        let none: CelestialEclipseLabHint? = CelestialEclipseLabHints.hint(level: 3, play: stuck)
        #expect(none?.kind == .stuck && none?.action == nil)
        #expect(none?.text == "No way to win was found in the actions left: undo the last action or retry the level.")
    }

    // MARK: Failures

    /// 500 seeded failures (25 groups of 20) are explained with the true planets, target number and ticks: the
    /// explanation's failure is the play's and the one the independent judge finds for the tracked phases, its text
    /// the one built here; the hint is the failed advice; nothing changes the play.
    @Test(arguments: Array(0..<25))
    func seededFailuresAreExplained(group: Int) throws {
        let started: ContinuousClock.Instant = ContinuousClock.now
        defer { report("failures group \(group)", since: started) }
        let samples: [FailureSample] = try failureSamples()
        try #require(samples.count == 500)
        for offset in 0..<20 {
            let sample: FailureSample = samples[20 * group + offset]
            let label: String = "failure \(20 * group + offset) (level \(sample.number))"
            let play: CelestialEclipseLabPlay = sample.play
            #expect(play.stage == .failed || play.stage == .result, "\(label)")
            let explanation: CelestialEclipseLabFailureExplanation? = CelestialEclipseLabFailureExplanation(play: play)
            let hint: CelestialEclipseLabHint? = CelestialEclipseLabHints.hint(level: 3, play: play)
            #expect(play == sample.play, "\(label): an explanation or hint changed the play")
            #expect(play.phases == sample.phases, "\(label)")
            #expect(hint?.kind == .stuck && hint?.text == CelestialEclipseLabHint.failedText, "\(label)")
            guard let expected = expectedExplanation(play.level, sample.phases) else {
                Issue.record("\(label): the tracked phases win")
                continue
            }
            #expect(play.failure == expected.failure, "\(label)")
            #expect(explanation?.failure == expected.failure, "\(label)")
            #expect(explanation?.text == expected.text, "\(label): \(explanation?.text ?? "nil")")
        }
    }

    /// Every one of the three failures (unwanted, window, horizon) is among the 500 seeded failures, so each text is
    /// checked at least once.
    @Test func everyFailureIsExplained() throws {
        let started: ContinuousClock.Instant = ContinuousClock.now
        defer { report("failure kinds", since: started) }
        let samples: [FailureSample] = try failureSamples()
        var counts: [String: Int] = [:]
        for sample in samples {
            if let failure = sample.play.failure { counts[failureName(failure), default: 0] += 1 }
        }
        print("CelestialEclipseLabHintsTests failure kinds: \(counts.sorted { $0.key < $1.key })")
        for name in ["unwanted", "window", "horizon"] {
            #expect(counts[name, default: 0] > 0, "no \(name) failure")
        }
    }
}
