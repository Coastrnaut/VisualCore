// EchoCartographerHintsTests — feature 405 (R02-G11-05) T-R02G1105-002 (FR-R02G1105-002, 003; SC-R02G1105-002, 003;
// clarifications Q1, Q5). Hints and failure explanations on the 100 certified levels (certified once per process
// through the adapter's cache, prewarmed concurrently): from every opening the continuation is exactly the certified
// plan's pulses and following exact hints (re-asked after every action) wins within the energy, in 10 groups of 10
// levels; on fixture levels the continuation from the opening equals `plan(_:)`; 200 seeded reachable states (seed
// 2_405, 20 groups of 10: random legal pulses, claims, marks and undos from certified openings, a failing action undone,
// about one in five paused) get a hint the play accepts, from every state with a plan following hints wins within the
// energy left, and a hint never changes the play; a level whose energy is the certified pulse count is stuck; the three
// hint levels read as clarification Q1 says; loading, tutorial, won and result-after-win plays get no hint, failed ones
// `stuck`; 500 seeded failures (random pulses and claims, some undone, 10 groups of 50) are explained with the true
// action index, kind, cell and counts tracked independently here. Deterministic, explicit types, plain loops.
@testable import EchoCartographerCore
import Foundation
import Synchronization
import Testing
import VisualCoreSimulation

/// The 100 certified levels and plans in manifest order, certified concurrently once per test process.
private let hintCatalogResult: Result<[EchoCartographerGenerated], any Error> = Result {
    DispatchQueue.concurrentPerform(iterations: 100) { (index: Int) in
        _ = try? EchoCartographerExperienceCore.generated(number: index + 1)
    }
    var catalog: [EchoCartographerGenerated] = []
    for number in 1...100 { catalog.append(try EchoCartographerExperienceCore.generated(number: number)) }
    return catalog
}

/// The certified catalog.
private func hintCatalog() throws -> [EchoCartographerGenerated] { try hintCatalogResult.get() }

/// The largest work one continuation search spent in this process (openings and samples).
private let mostHintWork = Mutex<Int>(0)

/// Records `work` in ``mostHintWork``.
private func noteHintWork(_ work: Int) {
    mostHintWork.withLock { $0 = max($0, work) }
}

/// The search work of `play`'s continuation (its current pulses, its knowledge and energy), recorded.
private func measure(_ play: EchoCartographerPlay) {
    var pulses: [EchoCartographerCell] = []
    for action in EchoCartographerHints.appliedActions(play.records) {
        if case .pulse = action { pulses.append(action.cell) }
    }
    let search: (pulses: [EchoCartographerCell]?, work: Int) = EchoCartographerSolver.continuationSearch(
        play.level, knowledge: play.knowledge, pulsed: pulses, energyLeft: play.energy)
    noteHintWork(search.work)
}

/// Follows exact (level 3) hints from `start` (resumed when paused) until the play ends; the problems found (empty:
/// won, every hinted action accepted) and the energy spent following them.
private func followHints(_ start: EchoCartographerPlay, label: String) -> (problems: [String], spent: Int) {
    var play: EchoCartographerPlay = start
    if play.stage == .paused { try? play.handle(.resume) }
    let energy: Int = play.energy
    for _ in 0..<64 {
        if play.stage == .won { return ([], energy - play.energy) }
        measure(play)
        guard let hint = EchoCartographerHints.hint(level: 3, play: play) else {
            return (["\(label): no hint in \(play.stage)"], energy - play.energy)
        }
        guard let action = hint.action else {
            return (["\(label): stuck with \(play.energy) energy"], energy - play.energy)
        }
        do {
            try play.apply(action, expecting: play.fingerprint)
        } catch {
            return (["\(label): hinted \(action) refused: \(error)"], energy - play.energy)
        }
    }
    return (play.stage == .won ? [] : ["\(label): not won, stage \(play.stage)"], energy - play.energy)
}

/// The cells of `play`'s chamber known open, in cell-index order.
private func knownOpen(_ play: EchoCartographerPlay) -> [EchoCartographerCell] {
    let chamber: EchoCartographerChamber = play.level.chamber
    var cells: [EchoCartographerCell] = []
    for index in 0..<chamber.cellCount where play.knowledge[index] == .open { cells.append(chamber.cell(index)) }
    return cells
}

/// A random cell of `play`'s chamber.
private func randomCell(_ play: EchoCartographerPlay, _ random: inout SeededRandom) -> EchoCartographerCell {
    let chamber: EchoCartographerChamber = play.level.chamber
    return chamber.cell(random.int(0...(chamber.cellCount - 1)))
}

/// A seeded reachable state of the hint sample.
private struct HintSample {
    let number: Int
    let play: EchoCartographerPlay
}

/// The 200 seeded reachable states, drawn once per test process.
private let hintSamplesResult: Result<[HintSample], any Error> = Result { try drawHintSamples() }

/// The 200 seeded reachable states.
private func hintSamples() throws -> [HintSample] { try hintSamplesResult.get() }

/// 200 seeded reachable states (seed 2_405): from a certified opening, 0 … plan − 1 certified pulses (so many states
/// stay on the certified path), then 0 … 6 random steps — a pulse from a random known-open cell (most often), a claim on
/// a random cell or a beacon's own cell, a mark or an undo — where a refused action is skipped, an action that fails the
/// play is undone and a won play is drawn again; about one in five samples ends paused.
private func drawHintSamples() throws -> [HintSample] {
    let catalog: [EchoCartographerGenerated] = try hintCatalog()
    var random = SeededRandom(seed: EchoCartographerHintsTests.seed)
    var samples: [HintSample] = []
    while samples.count < 200 {
        let number: Int = random.int(1...100)
        let generated: EchoCartographerGenerated = catalog[number - 1]
        let level: EchoCartographerLevel = generated.level
        var play: EchoCartographerPlay = try EchoCartographerExperienceCore.freshPlay(of: level)
        let certified: Int = random.int(0...(generated.plan.pulses.count - 1))
        for index in 0..<certified {
            let cell: EchoCartographerCell = generated.plan.pulses[index]
            try play.apply(EchoCartographerAction.pulse(cell.x, cell.y), expecting: play.fingerprint)
        }
        let steps: Int = random.int(0...6)
        for _ in 0..<steps {
            if play.stage != .playing { break }
            let roll: Int = random.int(0...9)
            var action: EchoCartographerAction
            if roll <= 4 {
                let open: [EchoCartographerCell] = knownOpen(play)
                let cell: EchoCartographerCell = open[random.int(0...(open.count - 1))]
                action = EchoCartographerAction.pulse(cell.x, cell.y)
            } else if roll == 5 {
                let beacon: EchoCartographerCell = level.beacons[random.int(0...(level.beacons.count - 1))]
                action = EchoCartographerAction.claim(beacon.x, beacon.y)
            } else if roll == 6 {
                let cell: EchoCartographerCell = randomCell(play, &random)
                action = EchoCartographerAction.claim(cell.x, cell.y)
            } else if roll == 7 {
                let cell: EchoCartographerCell = randomCell(play, &random)
                action = EchoCartographerAction.mark(cell.x, cell.y)
            } else {
                if play.canUndo { try play.undo() }
                continue
            }
            do {
                try play.apply(action, expecting: play.fingerprint)
            } catch {
                continue
            }
            if play.stage == .failed { try play.undo() }
        }
        guard play.stage == .playing else { continue }
        if random.int(0...4) == 0 { try play.handle(.pause) }
        samples.append(HintSample(number: number, play: play))
    }
    return samples
}

/// The states with no plan among the samples (counted once per group).
private let stuckSamples = Mutex<Int>(0)

@Suite struct EchoCartographerHintsTests {
    /// The test seed of this feature.
    static let seed: UInt64 = 2_405

    // MARK: Openings

    /// From every certified opening (10 groups of 10 levels) the continuation is exactly the certified plan's pulses,
    /// the plan is those pulses then the claims, and following exact hints wins spending exactly the plan's pulse count,
    /// within the energy.
    @Test(arguments: Array(0..<10))
    func followingHintsFromTheOpeningWins(group: Int) throws {
        let catalog: [EchoCartographerGenerated] = try hintCatalog()
        let started: ContinuousClock.Instant = ContinuousClock.now
        var most: Int = 0
        for number in (10 * group + 1)...(10 * group + 10) {
            let generated: EchoCartographerGenerated = catalog[number - 1]
            let level: EchoCartographerLevel = generated.level
            let search: (pulses: [EchoCartographerCell]?, work: Int) = EchoCartographerSolver.continuationSearch(
                level, knowledge: level.openingKnowledge, pulsed: [], energyLeft: level.energy)
            #expect(search.pulses == generated.plan.pulses, "level \(number): the opening's continuation is the plan")
            #expect(EchoCartographerSolver.continuation(level, knowledge: level.openingKnowledge, pulsed: [],
                                                        energyLeft: level.energy) == generated.plan.pulses)
            #expect(search.work <= EchoCartographerSolver.workBound, "level \(number)")
            most = max(most, search.work)
            noteHintWork(search.work)
            let opening: EchoCartographerPlay = try EchoCartographerExperienceCore.freshPlay(of: level)
            let witness: [EchoCartographerAction] = EchoCartographerSolver.actions(level, plan: generated.plan)
            #expect(EchoCartographerHints.plan(opening)?.actions == witness, "level \(number)")
            let hint: EchoCartographerHint? = EchoCartographerHints.hint(level: 3, play: opening)
            #expect(hint?.kind == .pulse && hint?.action == witness.first, "level \(number)")
            let outcome: (problems: [String], spent: Int) = followHints(opening, label: "level \(number)")
            #expect(outcome.problems.isEmpty, "\(outcome.problems)")
            #expect(outcome.spent == generated.plan.pulses.count && outcome.spent < level.energy, "level \(number)")
        }
        let elapsed: Duration = ContinuousClock.now - started
        print("EchoCartographerHintsTests group \(group): \(elapsed), most opening work \(most); most so far "
              + "\(mostHintWork.withLock { $0 })")
    }

    /// The certification is unchanged: on 60 fixture levels, the continuation from the opening with energy to spare is
    /// `plan(_:)`'s pulses (both nil alike), or empty when one placement already fits at the opening.
    @Test func certificationEqualsTheOpeningContinuation() {
        for fixture in EchoCartographerFixtures.fixtures(60, from: Self.seed) {
            let level: EchoCartographerLevel = fixture.level
            var work: Int = 0
            let opening: Int = EchoCartographerSolver.fitting(level, observations: [], cap: 2, work: &work).count
            let continued: [EchoCartographerCell]? = EchoCartographerSolver.continuation(
                level, knowledge: level.openingKnowledge, pulsed: [], energyLeft: EchoCartographerSolver.maxPulses + 1)
            if opening == 1 {
                #expect(continued == [], "\(level.id)")
            } else {
                #expect(continued == EchoCartographerSolver.plan(level)?.pulses, "\(level.id)")
            }
            // No energy to spare: the further pulses would spend the last energy.
            if let pulses = continued, !pulses.isEmpty {
                #expect(EchoCartographerSolver.continuation(level, knowledge: level.openingKnowledge, pulsed: [],
                                                            energyLeft: pulses.count) == nil, "\(level.id)")
            }
        }
    }

    /// Pulses already heard count: after the plan's first k pulses the continuation is the rest of the plan; after all
    /// of them it is empty; a repeated pulse changes nothing.
    @Test func continuationResumesThePlan() throws {
        let catalog: [EchoCartographerGenerated] = try hintCatalog()
        for number in [1, 25, 50, 75, 100] {
            let generated: EchoCartographerGenerated = catalog[number - 1]
            let level: EchoCartographerLevel = generated.level
            var knowledge: EchoCartographerKnowledge = level.openingKnowledge
            var heard: [EchoCartographerCell] = []
            for (index, cell) in generated.plan.pulses.enumerated() {
                knowledge.reveal(level.echo(from: cell))
                heard.append(cell)
                let rest: [EchoCartographerCell] = Array(generated.plan.pulses[(index + 1)...])
                #expect(EchoCartographerSolver.continuation(level, knowledge: knowledge, pulsed: heard,
                                                            energyLeft: level.energy) == rest, "level \(number)")
                #expect(EchoCartographerSolver.continuation(level, knowledge: knowledge, pulsed: heard + heard,
                                                            energyLeft: level.energy) == rest, "level \(number)")
            }
        }
    }

    // MARK: Reachable states

    /// 200 seeded reachable states in 20 groups of 10: the hint never changes the play; with a plan the hint is its
    /// first action at every level, the play accepts it and following hints wins within the energy left; without one
    /// the hint is `stuck` with the stuck text.
    @Test(arguments: Array(0..<20))
    func reachableStatesGetLegalHintsThatWin(group: Int) throws {
        let samples: [HintSample] = try hintSamples()
        let started: ContinuousClock.Instant = ContinuousClock.now
        var planned: Int = 0
        for index in (10 * group)..<(10 * group + 10) {
            let sample: HintSample = samples[index]
            let play: EchoCartographerPlay = sample.play
            let label: String = "sample \(index) (level \(sample.number), energy \(play.energy))"
            let before: EchoCartographerPlay = play
            measure(play)
            let hint: EchoCartographerHint = try #require(EchoCartographerHints.hint(level: 3, play: play), "\(label)")
            #expect(play == before && play.fingerprint == before.fingerprint, "\(label): the hint changed the play")
            guard let action = hint.action else {
                #expect(hint.kind == .stuck && hint.text == EchoCartographerHint.stuckText, "\(label)")
                #expect(EchoCartographerHints.plan(play) == nil, "\(label)")
                continue
            }
            planned += 1
            for level in 1...2 { #expect(hint.at(level: level).action == action, "\(label)") }
            let plan: EchoCartographerHintPlan = try #require(EchoCartographerHints.plan(play), "\(label)")
            #expect(plan.actions.first == action, "\(label)")
            switch action {
            case .pulse: #expect(hint.kind == .pulse && play.knowledge[action.cell] == .open, "\(label)")
            case .claim:
                #expect(hint.kind == .claim, "\(label)")
                // The lowest-index beacon not yet located, on its own cell.
                var lowest: Int = -1
                for beacon in 0..<play.level.beacons.count where play.located[beacon] == nil && lowest < 0 {
                    lowest = beacon
                }
                #expect(lowest >= 0 && action.cell == play.level.beacons[lowest], "\(label)")
            case .mark: Issue.record("\(label): a mark hinted")
            }
            var copy: EchoCartographerPlay = play
            if copy.stage == .paused { try copy.handle(.resume) }
            #expect(throws: Never.self, "\(label): hinted \(action) refused") {
                try copy.apply(action, expecting: copy.fingerprint)
            }
            #expect(copy.failure == nil, "\(label): the hinted action failed the play")
            let outcome: (problems: [String], spent: Int) = followHints(copy, label: label)
            #expect(outcome.problems.isEmpty, "\(outcome.problems)")
            #expect(copy.stage == .won || copy.energy - outcome.spent >= 1, "\(label)")
        }
        stuckSamples.withLock { $0 += 10 - planned }
        let elapsed: Duration = ContinuousClock.now - started
        print("EchoCartographerHintsTests samples group \(group): \(planned) of 10 with a plan, \(elapsed); stuck so "
              + "far \(stuckSamples.withLock { $0 }); most work so far \(mostHintWork.withLock { $0 })")
    }

    /// A level whose energy is exactly the certified pulse count has no plan from its opening (the pulses would spend
    /// the last energy): the hint is stuck.
    @Test func tooLittleEnergyIsStuck() throws {
        let catalog: [EchoCartographerGenerated] = try hintCatalog()
        var checked: Int = 0
        for generated in catalog where checked < 5 {
            let level: EchoCartographerLevel = generated.level
            let pulses: Int = generated.plan.pulses.count
            let lowered: EchoCartographerLevel = try EchoCartographerLevel(
                id: level.id, seed: level.seed, difficulty: level.difficulty, chamber: level.chamber,
                entry: level.entry, beacons: level.beacons, tolerance: level.tolerance, energy: pulses,
                missCost: level.missCost, tutorial: level.tutorial)
            let play: EchoCartographerPlay = try EchoCartographerExperienceCore.freshPlay(of: lowered)
            #expect(EchoCartographerHints.plan(play) == nil)
            let hint: EchoCartographerHint? = EchoCartographerHints.hint(level: 2, play: play)
            #expect(hint?.kind == .stuck && hint?.action == nil && hint?.text == EchoCartographerHint.stuckText)
            checked += 1
        }
        #expect(checked == 5)
    }

    // MARK: Texts and stages

    /// The texts of each hint kind at each level (clarification Q1), and the level clamp.
    @Test func hintTextsAtEachLevel() {
        let pulse = EchoCartographerHint(level: 1, kind: .pulse, action: EchoCartographerAction.pulse(2, 3))
        #expect(pulse.text == "Send a pulse to narrow down where the beacons can be")
        #expect(pulse.at(level: 2).text == "Send a pulse to narrow down where the beacons can be from a known open cell "
                + "in row 3")
        #expect(pulse.at(level: 3).text == "Send a pulse from column 2, row 3")
        let claim = EchoCartographerHint(level: 1, kind: .claim, action: EchoCartographerAction.claim(2, 3))
        #expect(claim.text == "The echoes leave one place for the beacons: claim a beacon")
        #expect(claim.at(level: 2).text == "The echoes leave one place for the beacons: claim a beacon in row 3")
        #expect(claim.at(level: 3).text == "Claim column 2, row 3")
        #expect(claim.at(level: 9).level == 3 && claim.at(level: -1).level == 1)
        #expect(claim.at(level: 9).text == "Claim column 2, row 3")
        #expect(pulse.at(level: 0).text == "Send a pulse to narrow down where the beacons can be")
        for level in 1...3 {
            #expect(EchoCartographerHint(level: level, kind: .stuck).text
                    == "No way to locate every beacon was found in the energy left: undo the last action or retry the "
                    + "level.")
            #expect(EchoCartographerHint(level: level, kind: .stuck, failed: true).text
                    == "Undo the last action or retry the level.")
        }
        #expect(EchoCartographerHintKind.pulse.rawValue == "pulse")
        #expect(EchoCartographerHintKind.claim.rawValue == "claim")
        #expect(EchoCartographerHintKind.stuck.rawValue == "stuck")
    }

    /// Loading and tutorial plays get no hint; playing and paused plays the same action; a claim hint once one
    /// placement fits; won and result-after-win plays none; failed and result-after-failure plays the failed `stuck`
    /// hint; a hint never changes the play.
    @Test func hintsFollowTheStage() throws {
        let catalog: [EchoCartographerGenerated] = try hintCatalog()
        let generated: EchoCartographerGenerated = try #require(catalog.first { $0.level.tutorial })
        let level: EchoCartographerLevel = generated.level
        var play = EchoCartographerPlay(level: level)
        #expect(EchoCartographerHints.hint(level: 1, play: play) == nil && EchoCartographerHints.plan(play) == nil)
        try play.handle(.begin)
        #expect(play.stage == .tutorial && EchoCartographerHints.hint(level: 1, play: play) == nil)
        try play.handle(.dismissTutorial)
        let first: EchoCartographerHint = try #require(EchoCartographerHints.hint(level: 2, play: play))
        let cell: EchoCartographerCell = generated.plan.pulses[0]
        #expect(first.kind == .pulse && first.level == 2
                && first.action == EchoCartographerAction.pulse(cell.x, cell.y))
        #expect(first.text == "Send a pulse to narrow down where the beacons can be from a known open cell in row "
                + "\(cell.y)")
        try play.handle(.pause)
        let paused: EchoCartographerPlay = play
        #expect(EchoCartographerHints.hint(level: 2, play: play) == first)
        #expect(play == paused)
        try play.handle(.resume)
        for pulse in generated.plan.pulses {
            try play.apply(EchoCartographerAction.pulse(pulse.x, pulse.y), expecting: play.fingerprint)
        }
        let claim: EchoCartographerHint = try #require(EchoCartographerHints.hint(level: 3, play: play))
        let beacon: EchoCartographerCell = level.beacons[0]
        #expect(claim.kind == .claim && claim.action == EchoCartographerAction.claim(beacon.x, beacon.y))
        #expect(claim.text == "Claim column \(beacon.x), row \(beacon.y)")
        for target in level.beacons {
            try play.apply(EchoCartographerAction.claim(target.x, target.y), expecting: play.fingerprint)
        }
        #expect(play.stage == .won && EchoCartographerHints.hint(level: 3, play: play) == nil)
        #expect(EchoCartographerHints.plan(play) == nil)
        try play.handle(.showResult)
        #expect(EchoCartographerHints.hint(level: 3, play: play) == nil)
        // A failed play: pulses from the entry until the energy runs out.
        var failing: EchoCartographerPlay = try EchoCartographerExperienceCore.freshPlay(of: level)
        while failing.stage == .playing {
            try failing.apply(EchoCartographerAction.pulse(level.entry.x, level.entry.y), expecting: failing.fingerprint)
        }
        try #require(failing.stage == .failed)
        let stuck: EchoCartographerHint = try #require(EchoCartographerHints.hint(level: 1, play: failing))
        #expect(stuck.kind == .stuck && stuck.action == nil)
        #expect(stuck.text == "Undo the last action or retry the level.")
        #expect(EchoCartographerHints.plan(failing) == nil)
        try failing.handle(.showResult)
        #expect(EchoCartographerHints.hint(level: 3, play: failing)?.text == EchoCartographerHint.failedText)
        #expect(EchoCartographerFailureExplanation(play: play) == nil)
    }

    // MARK: Failures

    /// 500 seeded failures in 10 groups of 50, group g on levels g + 1, g + 11, … g + 91: random pulses from known-open
    /// cells and claims on random cells (most of them misses), about one action in eight undone, until the energy runs
    /// out; each is explained with its true action index, kind, cell and counts, tracked here on an own stack (own
    /// index, own hit or miss from the located count); about one in five is shown as a result, one in five is undone and
    /// redone first (the failure restored by redo).
    @Test(arguments: Array(0..<10))
    func failuresAreExplained(group: Int) throws {
        var random = SeededRandom(seed: Self.seed &+ 1_000 &+ UInt64(group))
        let started: ContinuousClock.Instant = ContinuousClock.now
        var explained: Int = 0
        var pulseFailures: Int = 0
        var claimFailures: Int = 0
        var attempts: Int = 0
        let advice: String = " Undo the last action or retry the level."
        while explained < 50 && attempts < 2_000 {
            attempts += 1
            let number: Int = 10 * random.int(0...9) + group + 1
            let level: EchoCartographerLevel = try EchoCartographerExperienceCore.generated(number: number).level
            var play: EchoCartographerPlay = try EchoCartographerExperienceCore.freshPlay(of: level)
            // Own stack of applied actions: (is pulse, is miss, cell).
            var own: [(pulse: Bool, miss: Bool, cell: EchoCartographerCell)] = []
            for _ in 0..<400 {
                guard play.stage == .playing else { break }
                if !own.isEmpty && random.int(0...7) == 0 {
                    try play.undo()
                    own.removeLast()
                    continue
                }
                let located: Int = play.located.count
                if random.int(0...2) == 0 {
                    let cell: EchoCartographerCell = randomCell(play, &random)
                    do {
                        try play.apply(EchoCartographerAction.claim(cell.x, cell.y), expecting: play.fingerprint)
                    } catch {
                        continue
                    }
                    own.append((false, play.located.count == located, cell))
                } else {
                    let open: [EchoCartographerCell] = knownOpen(play)
                    let cell: EchoCartographerCell = open[random.int(0...(open.count - 1))]
                    try play.apply(EchoCartographerAction.pulse(cell.x, cell.y), expecting: play.fingerprint)
                    own.append((true, false, cell))
                }
            }
            guard play.stage == .failed, let last = own.last else { continue }
            let index: Int = own.count - 1
            let mode: Int = random.int(0...4)
            if mode == 0 { try play.handle(.showResult) }
            if mode == 1 {
                try play.undo()
                #expect(play.stage == .playing)
                try play.redo()
                try #require(play.stage == .failed)
            }
            var pulses: Int = 0
            var missed: Int = 0
            for step in own {
                if step.pulse { pulses += 1 }
                if step.miss { missed += 1 }
            }
            let explanation: EchoCartographerFailureExplanation = try #require(
                EchoCartographerFailureExplanation(play: play))
            #expect(explanation.failure == .energy(index) && explanation.action == index)
            #expect(explanation.cell == last.cell && explanation.isPulse == last.pulse)
            #expect(last.pulse || last.miss, "a failing claim is a miss")
            #expect(explanation.located == play.located.count && explanation.beacons == level.beacons.count)
            #expect(explanation.pulses == pulses && explanation.missedClaims == missed)
            let what: String = last.pulse ? "a pulse from column \(last.cell.x), row \(last.cell.y)"
                : "a missed claim at column \(last.cell.x), row \(last.cell.y)"
            #expect(explanation.text == "Action \(index + 1) (\(what)) spent the last energy: \(play.located.count) of "
                    + "\(level.beacons.count) beacons located after \(pulses) pulses and \(missed) missed claims."
                    + advice, "\(explanation.text)")
            if last.pulse { pulseFailures += 1 } else { claimFailures += 1 }
            explained += 1
        }
        #expect(explained == 50 && pulseFailures >= 1 && claimFailures >= 1,
                "group \(group): \(explained) explained, \(pulseFailures) pulses, \(claimFailures) claims")
        let elapsed: Duration = ContinuousClock.now - started
        print("EchoCartographerHintsTests failures group \(group): \(pulseFailures) pulses, \(claimFailures) missed "
              + "claims, \(attempts) attempts, \(elapsed)")
    }
}
