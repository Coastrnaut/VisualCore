// StarlitCartoucheHintsTests — feature 455 (R02-G16-05) T-R02G1605-002 (FR-R02G1605-002, 003, 007; SC-R02G1605-002,
// 003; clarifications Q1, Q5). Hints and failure explanations on the 100 certified levels (certified once per process
// through the experience core's cache, prewarmed concurrently): on every level `plan(_:)` equals the new entry
// `plan(_:from:beat:drawn:)` at the start star, beat 0 and nothing drawn, and the certified plan; the hint plan from
// the opening is the certified plan's legs and following exact (level 3) hints (re-asked after every leg) wins
// spending exactly the certified plan's legs, within the budget, in 10 groups of 10 levels; the new solver entry
// refuses an unknown star, a negative beat, a stray drawn corridor and a state that already wins, and one certified
// leg in, the plan from there is one leg shorter; 200 seeded reachable states (seed 2_455, 20 groups of 10: random
// clear legs from openings, winning ones skipped, about one in five paused) get a hint the kernel accepts whenever a
// plan exists, following hints from there wins within the actions left, and a hint never changes the play; the three
// hint levels read as clarification Q1 says; loading, tutorial, won and result-after-win plays get no hint, failed
// ones `stuck`; 500 seeded failures (25 groups of 20: random legs with undos and redos aiming in turn at each of the
// six failures — a budget-out flies a whole budget of clear legs found by a bounded depth-first search on the levels
// whose deadline and windows allow one — some undone and redone back into the failure, some shown as a result) are
// explained with the true action number, destination, wait and the kernel's values, the expectation built here from
// the legs tracked independently of the play and the failure payload; every one of the six failures is explained at
// least once. Each test prints its duration (no wall-clock assertion). Deterministic, explicit types, plain loops.
import Foundation
import Testing
import VisualCoreSimulation
@testable import StarlitCartoucheCore

/// The 100 certified levels and plans in manifest order, certified concurrently once per test process.
private let hintCatalogResult: Result<[StarlitCartoucheGenerated], any Error> = Result {
    DispatchQueue.concurrentPerform(iterations: 100) { (index: Int) in
        _ = try? StarlitCartoucheExperienceCore.generated(number: index + 1)
    }
    var catalog: [StarlitCartoucheGenerated] = []
    for number in 1...100 { catalog.append(try StarlitCartoucheExperienceCore.generated(number: number)) }
    return catalog
}

/// The certified catalog.
private func hintCatalog() throws -> [StarlitCartoucheGenerated] { try hintCatalogResult.get() }

/// The opening play of manifest number `number` (begun, past its tutorial).
private func openingPlay(_ number: Int) throws -> StarlitCartouchePlay {
    try StarlitCartoucheExperienceCore.opening(number: number).play
}

/// Follows exact (level 3) hints from `start` (resumed when paused) until the play ends; the problems found (empty:
/// won, every hinted leg accepted, the play unchanged by every hint) and the actions spent following them.
private func followHints(_ start: StarlitCartouchePlay, label: String) -> (problems: [String], spent: Int) {
    var play: StarlitCartouchePlay = start
    if play.stage == .paused { try? play.handle(.resume) }
    let spentBefore: Int = play.actionsSpent
    for _ in 0..<32 {
        if play.stage == .won { return ([], play.actionsSpent - spentBefore) }
        let before: StarlitCartouchePlay = play
        guard let hint = StarlitCartoucheHints.hint(level: 3, play: play) else {
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
    print("StarlitCartoucheHintsTests \(name): \(elapsed)")
}

/// A whole random number 0 ..< `count`.
private func below(_ count: Int, _ random: inout SeededRandom) -> Int {
    min(Int(random.double() * Double(count)), max(count - 1, 0))
}

/// "w beats", or "1 beat" (written here independently of the hint engine).
private func beatWords(_ wait: Int) -> String { wait == 1 ? "1 beat" : "\(wait) beats" }

/// The code of a failure, one of departure, hazard, arrival, deadline, stroke, budget.
private func code(_ failure: StarlitCartoucheFailure) -> String {
    switch failure {
    case .departure: "departure"
    case .hazard: "hazard"
    case .arrival: "arrival"
    case .deadline: "deadline"
    case .stroke: "stroke"
    case .budget: "budget"
    }
}

/// The six failure codes, in the order the seeded failures aim at them.
private let failureCodes: [String] = ["departure", "hazard", "arrival", "deadline", "stroke", "budget"]

/// The legs the chart accepts from the play's star and beat, sorted by what they would do now.
private struct LegOptions {
    /// Legs the chart's check fails, by failure code.
    var failing: [String: [(Int, Int)]] = [:]
    /// Clear legs that win.
    var winning: [(Int, Int)] = []
    /// Clear legs that do not win.
    var plain: [(Int, Int)] = []

    /// Every failing leg, codes in ``failureCodes`` order.
    var allFailing: [(Int, Int)] {
        var all: [(Int, Int)] = []
        for name in failureCodes { all += failing[name, default: []] }
        return all
    }
}

/// The legs (star, wait) the chart accepts from `play`'s star and beat — corridors by index, then waits 0 … 8 —
/// sorted into failing (by failure code), clear and winning, clear and not winning.
private func classifiedLegs(_ play: StarlitCartouchePlay) -> LegOptions {
    var options = LegOptions()
    let level: StarlitCartoucheLevel = play.level
    for corridor in level.corridors where corridor.a == play.star || corridor.b == play.star {
        let destination: Int = corridor.a == play.star ? corridor.b : corridor.a
        for wait in StarlitCartoucheChart.waits {
            guard let leg = try? StarlitCartoucheChart.leg(level, from: play.star, at: play.beat, to: destination,
                                                           wait: wait) else { continue }
            if let failure = StarlitCartoucheChart.check(level, leg: leg) {
                options.failing[code(failure), default: []].append((destination, wait))
                continue
            }
            var drawn: Set<Int> = play.drawn
            drawn.insert(leg.corridor)
            if drawn == Set(level.symbol) && destination == level.beacon {
                options.winning.append((destination, wait))
            } else {
                options.plain.append((destination, wait))
            }
        }
    }
    return options
}

/// A route of exactly `level.budget` clear legs from the start that never wins (so its last leg spends the budget
/// and fails `budget`), found by a depth-first search over (star, beat, drawn strokes) — corridors by index, waits
/// 0 … 8 — with dead states remembered per depth; nil when none is found within `nodes` states.
private func budgetRoute(_ level: StarlitCartoucheLevel, nodes: Int = 20_000) -> [(Int, Int)]? {
    var strokeBit: [Int: Int] = [:]
    for (bit, corridor) in level.symbol.enumerated() { strokeBit[corridor] = bit }
    let full: Int = (1 << level.symbol.count) - 1
    var dead: Set<[Int]> = []
    var visited: Int = 0
    var route: [(Int, Int)] = []
    func search(star: Int, beat: Int, mask: Int) -> Bool {
        if route.count == level.budget { return true }
        let key: [Int] = [star, beat, mask, route.count]
        if dead.contains(key) { return false }
        visited += 1
        if visited > nodes { return false }
        for corridor in level.corridors where corridor.a == star || corridor.b == star {
            let destination: Int = corridor.a == star ? corridor.b : corridor.a
            for wait in StarlitCartoucheChart.waits {
                guard let leg = try? StarlitCartoucheChart.leg(level, from: star, at: beat, to: destination,
                                                               wait: wait),
                      StarlitCartoucheChart.check(level, leg: leg) == nil,
                      let bit = strokeBit[leg.corridor] else { continue }
                let next: Int = mask | (1 << bit)
                if next == full && destination == level.beacon { continue }
                route.append((destination, wait))
                if search(star: destination, beat: leg.arrive, mask: next) { return true }
                route.removeLast()
                if visited > nodes { return false }
            }
        }
        dead.insert(key)
        return false
    }
    return search(star: level.start, beat: 0, mask: 0) ? route : nil
}

/// The manifest numbers whose level has a budget-out route (``budgetRoute(_:nodes:)``), with the route (most
/// certified levels' deadlines and windows leave no room for a whole budget of legs).
private let budgetRoutes: [(Int, [(Int, Int)])] = {
    var routes: [(Int, [(Int, Int)])] = []
    for number in 1...100 {
        guard let level = try? StarlitCartoucheExperienceCore.level(number: number),
              let route = budgetRoute(level) else { continue }
        routes.append((number, route))
    }
    return routes
}()

/// One seeded reachable state: the level number and the play.
private struct HintSample: Sendable {
    /// The manifest number.
    let number: Int
    /// The play (playing or paused, actions left).
    let play: StarlitCartouchePlay
}

/// The 200 seeded reachable states (seed 2_455): a random level's opening, then 0 … 6 random clear legs (winning
/// ones skipped, at least one action left), about one in five then paused.
private let hintSamplesResult: Result<[HintSample], any Error> = Result {
    _ = try hintCatalog()
    var random = SeededRandom(seed: StarlitCartoucheHintsTests.seed)
    var samples: [HintSample] = []
    while samples.count < 200 {
        let number: Int = below(100, &random) + 1
        var play: StarlitCartouchePlay = try openingPlay(number)
        let wanted: Int = below(7, &random)
        var applied: Int = 0
        while applied < wanted, play.actionsLeft > 1 {
            let plain: [(Int, Int)] = classifiedLegs(play).plain
            guard !plain.isEmpty else { break }
            let (star, wait): (Int, Int) = plain[below(plain.count, &random)]
            try play.apply(.leg(star, wait), expecting: play.fingerprint)
            applied += 1
        }
        if below(5, &random) == 0 { try play.handle(.pause) }
        samples.append(HintSample(number: number, play: play))
    }
    return samples
}

/// The seeded reachable states.
private func hintSamples() throws -> [HintSample] { try hintSamplesResult.get() }

@Suite struct StarlitCartoucheHintsTests {
    /// The test seed of this feature.
    static let seed: UInt64 = 2_455

    // MARK: Openings

    /// On every certified level (10 groups of 10): `plan(_:)` equals the new entry at the start star, beat 0 and
    /// nothing drawn, and the certified plan; the hint plan from the opening is the certified plan's legs; following
    /// exact hints wins spending exactly the certified plan's legs, within the budget.
    @Test(arguments: Array(0..<10))
    func followingHintsFromTheOpeningWins(group: Int) throws {
        let started: ContinuousClock.Instant = ContinuousClock.now
        defer { report("openings group \(group)", since: started) }
        let catalog: [StarlitCartoucheGenerated] = try hintCatalog()
        for number in (10 * group + 1)...(10 * group + 10) {
            let generated: StarlitCartoucheGenerated = catalog[number - 1]
            let level: StarlitCartoucheLevel = generated.level
            let certifying: StarlitCartouchePlan? = StarlitCartoucheSolver.plan(level)
            let atStart: StarlitCartouchePlan? = StarlitCartoucheSolver.plan(level, from: level.start, beat: 0,
                                                                             drawn: [])
            #expect(atStart != nil && atStart == certifying, "level \(number)")
            #expect(certifying?.legs == generated.plan.legs, "level \(number)")
            #expect(certifying?.statesByDepth == generated.plan.statesByDepth, "level \(number)")
            let opening: StarlitCartouchePlay = try openingPlay(number)
            #expect(StarlitCartoucheHints.plan(opening)?.legs == generated.plan.legs, "level \(number)")
            let outcome: (problems: [String], spent: Int) = followHints(opening, label: "level \(number)")
            #expect(outcome.problems.isEmpty, "\(outcome.problems)")
            #expect(outcome.spent == generated.plan.size && outcome.spent <= level.budget, "level \(number)")
        }
    }

    /// The new solver entry refuses an unknown star, a negative beat, a drawn corridor outside the symbol and a state
    /// that already wins; one certified leg in, the plan from there is one leg shorter and the certified plan's rest.
    @Test func planFromAStateChecksItsInputs() throws {
        let started: ContinuousClock.Instant = ContinuousClock.now
        defer { report("plan inputs", since: started) }
        let catalog: [StarlitCartoucheGenerated] = try hintCatalog()
        let generated: StarlitCartoucheGenerated = catalog[60]
        let level: StarlitCartoucheLevel = generated.level
        #expect(StarlitCartoucheSolver.plan(level, from: -1, beat: 0, drawn: []) == nil)
        #expect(StarlitCartoucheSolver.plan(level, from: level.stars.count, beat: 0, drawn: []) == nil)
        #expect(StarlitCartoucheSolver.plan(level, from: level.start, beat: -1, drawn: []) == nil)
        var stray: Int?
        for index in level.corridors.indices where !level.symbol.contains(index) { stray = index }
        if let stray { #expect(StarlitCartoucheSolver.plan(level, from: level.start, beat: 0, drawn: [stray]) == nil) }
        #expect(StarlitCartoucheSolver.plan(level, from: level.beacon, beat: 5, drawn: Set(level.symbol)) == nil)
        var play: StarlitCartouchePlay = try openingPlay(61)
        try play.apply(generated.plan.legs[0], expecting: play.fingerprint)
        let rest: StarlitCartouchePlan? = StarlitCartoucheSolver.plan(level, from: play.star, beat: play.beat,
                                                                      drawn: play.drawn)
        #expect(rest?.size == generated.plan.size - 1)
        #expect(rest.map { StarlitCartoucheSolver.wins(level, actions: [generated.plan.legs[0]] + $0.legs) } == true)
    }

    // MARK: Seeded reachable states

    /// 200 seeded reachable states (20 groups of 10): the exact hint is a leg the kernel accepts whenever a plan
    /// exists, the plan fits the actions left, following hints (after the hinted leg) wins within them, and no hint
    /// changes the play; on the first state of each group the hints of levels 1 and 2 suggest the same leg.
    @Test(arguments: Array(0..<20))
    func seededStatesGetAcceptedHints(group: Int) throws {
        let started: ContinuousClock.Instant = ContinuousClock.now
        defer { report("seeded states group \(group)", since: started) }
        let samples: [HintSample] = try hintSamples()
        for offset in 0..<10 {
            let sample: HintSample = samples[10 * group + offset]
            let label: String = "sample \(10 * group + offset) (level \(sample.number))"
            let play: StarlitCartouchePlay = sample.play
            let plan: StarlitCartoucheHintPlan? = StarlitCartoucheHints.plan(play)
            guard let hint = StarlitCartoucheHints.hint(level: 3, play: play) else {
                Issue.record("\(label): no hint while \(play.stage)")
                continue
            }
            for level in 1...2 where offset == 0 {
                let other: StarlitCartoucheHint? = StarlitCartoucheHints.hint(level: level, play: play)
                #expect(other?.action == hint.action && other?.kind == hint.kind && other?.level == level, "\(label)")
            }
            #expect(play == sample.play, "\(label): the hint changed the play")
            guard let plan, let action = hint.action else {
                #expect(plan == nil && hint.kind == .stuck && hint.text == StarlitCartoucheHint.stuckText, "\(label)")
                continue
            }
            #expect(hint.kind == .leg && plan.legs.first == action, "\(label)")
            #expect(plan.legs.count <= play.actionsLeft, "\(label)")
            var copy: StarlitCartouchePlay = play
            if copy.stage == .paused { try copy.handle(.resume) }
            do {
                try copy.apply(action, expecting: copy.fingerprint)
            } catch {
                Issue.record("\(label): hinted \(action) refused: \(error)")
            }
            #expect(copy.failure == nil, "\(label): hinted \(action) failed the play")
            let outcome: (problems: [String], spent: Int) = followHints(copy, label: label)
            #expect(outcome.problems.isEmpty, "\(outcome.problems)")
            #expect(outcome.spent + 1 == plan.legs.count && outcome.spent + 1 <= play.actionsLeft, "\(label)")
        }
    }

    // MARK: Texts and stages

    /// The three hint levels read as clarification Q1 says (levels clamped to 1 … 3) at the openings of levels 1, 11,
    /// … 91, the corridor of level 1 being the one joining the ship's star and the destination.
    @Test func hintLevelsReadAsClarified() throws {
        let started: ContinuousClock.Instant = ContinuousClock.now
        defer { report("hint levels", since: started) }
        let catalog: [StarlitCartoucheGenerated] = try hintCatalog()
        for number in stride(from: 1, through: 100, by: 10) {
            let play: StarlitCartouchePlay = try openingPlay(number)
            guard case .leg(let star, let wait) = catalog[number - 1].plan.legs[0] else { continue }
            var index: Int = -1
            for candidate in play.level.corridors.indices
            where play.level.corridors[candidate].joins(play.star, star) && index < 0 {
                index = candidate
            }
            let corridor: StarlitCartoucheCorridor = play.level.corridors[index]
            let exact: String = "Fly to star \(star) after waiting " + beatWords(wait)
            #expect(StarlitCartoucheHints.hint(level: 1, play: play)?.text
                == "The next leg flies corridor \(index), between star \(corridor.a) and star \(corridor.b)")
            #expect(StarlitCartoucheHints.hint(level: 0, play: play)?.level == 1)
            #expect(StarlitCartoucheHints.hint(level: 2, play: play)?.text == "Fly to star \(star)")
            #expect(StarlitCartoucheHints.hint(level: 3, play: play)?.text == exact)
            #expect(StarlitCartoucheHints.hint(level: 9, play: play)?.text == exact)
            #expect(StarlitCartoucheHints.hint(level: 9, play: play)?.level == 3)
        }
        #expect(StarlitCartoucheHint.legText(level: 3, star: 4, wait: 1, corridor: 2, a: 0, b: 4)
            == "Fly to star 4 after waiting 1 beat")
        #expect(StarlitCartoucheHint.legText(level: 3, star: 4, wait: 0, corridor: 2, a: 0, b: 4)
            == "Fly to star 4 after waiting 0 beats")
        #expect(StarlitCartoucheHint.legText(level: 3, star: 4, wait: 5, corridor: 2, a: 0, b: 4)
            == "Fly to star 4 after waiting 5 beats")
        #expect(StarlitCartoucheHint.legText(level: 1, star: 4, wait: 5, corridor: 2, a: 0, b: 4)
            == "The next leg flies corridor 2, between star 0 and star 4")
    }

    /// Loading, tutorial, won and result-after-win plays get no hint; failed and result-after-failure plays get
    /// `stuck` with the failed text; a paused play is hinted as playing; no explanation without a failure.
    @Test func hintsByStage() throws {
        let started: ContinuousClock.Instant = ContinuousClock.now
        defer { report("stages", since: started) }
        let catalog: [StarlitCartoucheGenerated] = try hintCatalog()
        let level: StarlitCartoucheLevel = catalog[0].level
        #expect(level.tutorial)
        var play = StarlitCartouchePlay(level: level)
        #expect(StarlitCartoucheHints.hint(level: 1, play: play) == nil)
        #expect(StarlitCartoucheHints.plan(play) == nil)
        try play.handle(.begin)
        #expect(play.stage == .tutorial)
        #expect(StarlitCartoucheHints.hint(level: 1, play: play) == nil)
        try play.handle(.dismissTutorial)
        let playing: StarlitCartoucheHint? = StarlitCartoucheHints.hint(level: 2, play: play)
        #expect(playing?.kind == .leg)
        #expect(StarlitCartoucheFailureExplanation(play: play) == nil)
        try play.handle(.pause)
        #expect(StarlitCartoucheHints.hint(level: 2, play: play) == playing)
        try play.handle(.resume)
        for action in catalog[0].plan.legs { try play.apply(action, expecting: play.fingerprint) }
        #expect(play.stage == .won)
        #expect(StarlitCartoucheHints.hint(level: 3, play: play) == nil)
        #expect(StarlitCartoucheFailureExplanation(play: play) == nil)
        try play.handle(.showResult)
        #expect(StarlitCartoucheHints.hint(level: 3, play: play) == nil)
        #expect(StarlitCartoucheFailureExplanation(play: play) == nil)
        // A failure: any failing leg from the opening of a level that offers one.
        var failing: StarlitCartouchePlay?
        for number in 1...100 where failing == nil {
            var candidate: StarlitCartouchePlay = try openingPlay(number)
            if let (star, wait) = classifiedLegs(candidate).allFailing.first {
                try candidate.apply(.leg(star, wait), expecting: candidate.fingerprint)
                failing = candidate
            }
        }
        guard var failed = failing else {
            Issue.record("no failing leg at any opening")
            return
        }
        #expect(failed.stage == .failed)
        let hint: StarlitCartoucheHint? = StarlitCartoucheHints.hint(level: 2, play: failed)
        #expect(hint?.kind == .stuck && hint?.action == nil && hint?.text == StarlitCartoucheHint.failedText)
        #expect(StarlitCartoucheHint.failedText == "Undo the last action or retry the level.")
        #expect(StarlitCartoucheHint.stuckText
            == "No way to win was found in the actions left: undo the last action or retry the level.")
        try failed.handle(.showResult)
        #expect(StarlitCartoucheHints.hint(level: 1, play: failed)?.text == StarlitCartoucheHint.failedText)
        #expect(StarlitCartoucheFailureExplanation(play: failed) != nil)
    }

    // MARK: Seeded failures

    /// 500 seeded failures (25 groups of 20): each is explained with the true action number, destination, wait and
    /// the kernel's values, built here from the legs tracked independently of the play and the failure payload; every
    /// group holds budget-outs and failed legs.
    @Test(arguments: Array(0..<25))
    func seededFailuresAreExplained(group: Int) throws {
        let started: ContinuousClock.Instant = ContinuousClock.now
        defer { report("failures group \(group)", since: started) }
        let counts: [String: Int] = try explainFailures(seed: Self.seed &* 1_000 &+ UInt64(group), count: 20,
                                                        label: "group \(group)")
        #expect(counts["budget", default: 0] > 0, "group \(group): \(counts)")
        #expect(counts.values.reduce(0, +) - counts["budget", default: 0] > 0, "group \(group): \(counts)")
    }

    /// Every one of the six failures is explained at least once (seeded failures aimed at each in turn, seed
    /// 2_455 · 1000 + 999, up to 120).
    @Test func everyFailureKindIsExplained() throws {
        let started: ContinuousClock.Instant = ContinuousClock.now
        defer { report("every failure kind", since: started) }
        let counts: [String: Int] = try explainFailures(seed: Self.seed &* 1_000 &+ 999, count: 120,
                                                        label: "kinds")
        for name in failureCodes { #expect(counts[name, default: 0] > 0, "\(name): \(counts)") }
    }

    /// Drives `count` seeded failures (from `seed`) and checks each explanation; returns the count of each failure
    /// code.
    func explainFailures(seed: UInt64, count: Int, label: String) throws -> [String: Int] {
        _ = try hintCatalog()
        var random = SeededRandom(seed: seed)
        var counts: [String: Int] = [:]
        var made: Int = 0
        var attempts: Int = 0
        while made < count, attempts < 10 * count {
            attempts += 1
            let aim: String = failureCodes[made % failureCodes.count]
            var number: Int = below(100, &random) + 1
            var route: [(Int, Int)] = []
            if aim == "budget" {
                guard !budgetRoutes.isEmpty else { continue }
                (number, route) = budgetRoutes[below(budgetRoutes.count, &random)]
            }
            var play: StarlitCartouchePlay = try openingPlay(number)
            var applied: [(Int, Int)] = []
            var undone: [(Int, Int)] = []
            var failing: (Int, Int)?
            var moves: Int = 0
            // A budget-out flies its route, now and then undoing a leg and redoing it.
            for leg in route where play.stage == .playing {
                if below(6, &random) == 0, play.canUndo {
                    try play.undo()
                    try play.redo()
                    #expect(play.stage == .playing)
                }
                try play.apply(.leg(leg.0, leg.1), expecting: play.fingerprint)
                applied.append(leg)
                if play.stage == .failed { failing = leg }
            }
            while route.isEmpty, play.stage == .playing, moves < 200 {
                moves += 1
                let options: LegOptions = classifiedLegs(play)
                let roll: Int = below(10, &random)
                if roll == 0, play.canUndo {
                    try play.undo()
                    if let last = applied.popLast() { undone.append(last) }
                    continue
                }
                if roll == 1, play.canRedo, let back = undone.last {
                    try play.redo()
                    applied.append(back)
                    undone.removeLast()
                    if play.stage != .playing { break }
                    continue
                }
                let aimed: [(Int, Int)] = aim == "budget" ? [] : options.failing[aim, default: []]
                let pick: (Int, Int)
                if !aimed.isEmpty, roll >= 5 {
                    pick = aimed[below(aimed.count, &random)]
                } else if aim != "budget", aimed.isEmpty, roll == 9, !options.allFailing.isEmpty {
                    let any: [(Int, Int)] = options.allFailing
                    pick = any[below(any.count, &random)]
                } else if !options.plain.isEmpty {
                    pick = options.plain[below(options.plain.count, &random)]
                } else if !options.allFailing.isEmpty {
                    let any: [(Int, Int)] = options.allFailing
                    pick = any[below(any.count, &random)]
                } else {
                    break
                }
                try play.apply(.leg(pick.0, pick.1), expecting: play.fingerprint)
                applied.append(pick)
                undone.removeAll()
                if play.stage == .failed { failing = pick }
            }
            guard play.stage == .failed, let failure = play.failure, let (star, wait) = failing else { continue }
            let number1: Int = applied.count
            // Some failures are undone and redone back into the failure, some shown as a result.
            let extra: Int = below(4, &random)
            if extra == 0 {
                try play.undo()
                #expect(StarlitCartoucheFailureExplanation(play: play) == nil)
                try play.redo()
                #expect(play.stage == .failed)
            } else if extra == 1 {
                try play.handle(.showResult)
            }
            let head: String = "Action \(number1) (a leg to star \(star) after " + beatWords(wait) + ")"
            let expected: String
            switch failure {
            case .departure(let origin, let beat, let close):
                expected = head + " leaves star \(origin) at beat \(beat), after its window closed at beat \(close)."
            case .hazard(let corridor, let hazard, let from, let to):
                expected = head + " flies corridor \(corridor) through hazard \(hazard), active from beat \(from)"
                    + " to beat \(to)."
            case .arrival(let target, let beat, let open, let close):
                #expect(target == star)
                expected = head + " reaches star \(target) at beat \(beat), outside its window from beat \(open)"
                    + " to beat \(close)."
            case .deadline(let beat, let deadline):
                expected = head + " arrives at beat \(beat), after the deadline at beat \(deadline)."
            case .stroke(let corridor):
                #expect(!play.level.symbol.contains(corridor))
                expected = head + " flies corridor \(corridor), which is not part of the symbol."
            case .budget(let spent):
                #expect(spent == number1 && number1 == play.level.budget)
                expected = head + " spent the last action without completing the symbol at the beacon."
            }
            let explanation: StarlitCartoucheFailureExplanation? = StarlitCartoucheFailureExplanation(play: play)
            let name: String = code(failure)
            let context: String = "\(label) failure \(made) (level \(number), \(name))"
            #expect(explanation?.failure == failure, "\(context)")
            #expect(explanation?.action == number1, "\(context)")
            #expect(explanation?.text == expected + " Undo the last action or retry the level.", "\(context)")
            counts[name, default: 0] += 1
            made += 1
        }
        #expect(made == count, "\(label): only \(made) failures")
        return counts
    }
}
