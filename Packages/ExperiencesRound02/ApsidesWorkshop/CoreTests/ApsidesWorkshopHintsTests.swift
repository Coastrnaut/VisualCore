// ApsidesWorkshopHintsTests — feature 475 (R02-G18-05) T-R02G1805-003 (FR-R02G1805-002, 003, 007; SC-R02G1805-002,
// 003; clarifications Q1, Q5). Hints and failure explanations of Apsides Workshop. On the 100 certified levels, read
// from the stored witnesses in docs/games/apsides-workshop/levels/ with the plain decoder (as
// ApsidesWorkshopCatalogTests reads them), in 20 groups of 5 levels: `plan(_:)` equals the new entry `plan(_:from:)` at
// the level's starting orbit and the witness's tunings, orbits searched and work; the hint plan from the opening is
// those tunings; the level 1 and 2 texts of the first hint match texts written here; following exact (level 3) hints,
// re-asked after every action, then the hinted play wins spending exactly the witness's tunings, within the budget.
// The new entry gives a plan of no tunings (work 1) from the witness's winning orbit, nil from an invalid orbit, nil
// with `maxTunings` 0, and nil with `maxTunings` 1 on a two-tuning level. 200 seeded reachable states (seed 2_475 plus
// the group, 20 groups of 10: 0 … 2 random accepted tunings from a random certified opening) get a hint the kernel
// accepts (the play when the orbit already wins; never `stuck` while two actions are left, since every orbit is two
// levers from the witness's winning orbit), following hints from there wins within the actions left, and no hint,
// plan or explanation changes the play. Hand levels (period 16, apsis targets of one distance, budget 4) check the
// three hint levels for both levers, both turning ways, the 12-step tie (counterclockwise), single steps and units, and
// a knob-first plan; loading, paused, won and result-after-win plays get no hint, failed and result-after-failure ones
// the failed advice, the already-winning orbit the play, a budget too small for the minimal plan `stuck`. Each failure
// kind is explained on a hand level; 500 seeded failures (seed 2_475 plus 100 plus the group, 25 groups of 20: random
// accepted tunings, some undone and redone, some plays undone and redone, some shown as a result) are explained with
// the true planet or target, tick and reading, the expectation built here from an orbit tracked independently of the
// play and a judge written here over the kernel's positions. Each test prints its duration (no wall-clock assertion).
// Deterministic, explicit types, plain loops.
import Foundation
import Testing
import VisualCoreSimulation
@testable import ApsidesWorkshopCore

/// The repository's witness directory, found from this file (five levels up: CoreTests, ApsidesWorkshop, the
/// package, Packages).
private let hintWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/apsides-workshop/levels", isDirectory: true)

/// The 100 stored witnesses in manifest order, read once per test process with the plain decoder.
private let hintWitnessesResult: Result<[ApsidesWorkshopWitness], any Error> = Result {
    var result: [ApsidesWorkshopWitness] = []
    for entry in ApsidesWorkshopManifest.entries {
        let name: String = String(ApsidesWorkshopGenerator.levelID(entry.number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: hintWitnessDirectory.appendingPathComponent(name))
        result.append(try JSONDecoder().decode(ApsidesWorkshopWitness.self, from: data))
    }
    return result
}

/// The stored witnesses.
private func hintWitnesses() throws -> [ApsidesWorkshopWitness] { try hintWitnessesResult.get() }

/// The tunings of a witness (its actions without the closing play).
private func witnessTunings(_ witness: ApsidesWorkshopWitness) -> [ApsidesWorkshopAction] {
    var result: [ApsidesWorkshopAction] = []
    for action in witness.actions where action != .play { result.append(action) }
    return result
}

/// The opening play of `level`: begun, past its tutorial.
private func openingPlay(_ level: ApsidesWorkshopLevel) throws -> ApsidesWorkshopPlay {
    try ApsidesWorkshopExperienceCore.freshPlay(of: level)
}

/// Prints the seconds since `start` for `name` (evidence of the test's duration; never asserted).
private func report(_ name: String, since start: ContinuousClock.Instant) {
    let elapsed: Duration = ContinuousClock.now - start
    print("ApsidesWorkshopHintsTests \(name): \(elapsed)")
}

/// Validity written out from the rules (steps in range, a(20 − k) ≥ 60, a(20 + k) ≤ 1280).
private func validOrbit(_ a: Int, _ k: Int, _ d: Int) -> Bool {
    a >= 8 && a <= 48 && k >= 0 && k <= 15 && d >= 0 && d <= 23 && a * (20 - k) >= 60 && a * (20 + k) <= 1280
}

/// The orbit after the tuning `action` from `orbit` (the play leaves it unchanged), tracked here.
private func orbitAfter(_ orbit: ApsidesWorkshopOrbit, _ action: ApsidesWorkshopAction) -> ApsidesWorkshopOrbit {
    switch action {
    case .periapsis(let k, let d): return ApsidesWorkshopOrbit(size: orbit.size, eccentricity: k, direction: d)
    case .size(let a):
        return ApsidesWorkshopOrbit(size: a, eccentricity: orbit.eccentricity, direction: orbit.direction)
    case .play: return orbit
    }
}

/// A random tuning the rules accept from `orbit` (a valid orbit that differs in the tuned lever), or nil after 100
/// tries.
private func randomTuning(_ orbit: ApsidesWorkshopOrbit, _ random: inout SeededRandom) -> ApsidesWorkshopAction? {
    for _ in 0..<100 {
        if random.int(0...1) == 0 {
            let k: Int = random.int(0...15)
            let d: Int = random.int(0...23)
            let differs: Bool = k != orbit.eccentricity || d != orbit.direction
            if differs && validOrbit(orbit.size, k, d) { return .periapsis(k, d) }
        } else {
            let a: Int = random.int(8...48)
            if a != orbit.size && validOrbit(a, orbit.eccentricity, orbit.direction) { return .size(a) }
        }
    }
    return nil
}

/// "n steps" or "1 step", written here.
private func stepWords(_ count: Int) -> String { count == 1 ? "1 step" : "\(count) steps" }

/// The texts of a tuning hint from `orbit` at levels 1, 2 and 3, written here independently of the hint engine (the
/// counterclockwise and clockwise distances compared, counterclockwise on a tie).
private func expectedTexts(_ action: ApsidesWorkshopAction, from orbit: ApsidesWorkshopOrbit) -> [String] {
    switch action {
    case .periapsis(let k, let d):
        var second: String = ""
        if k > orbit.eccentricity { second = "Raise the eccentricity by " + stepWords(k - orbit.eccentricity) }
        if k < orbit.eccentricity { second = "Lower the eccentricity by " + stepWords(orbit.eccentricity - k) }
        if d != orbit.direction {
            var counterclockwise: Int = d - orbit.direction
            if counterclockwise < 0 { counterclockwise += 24 }
            let clockwise: Int = 24 - counterclockwise
            let turn: String = counterclockwise <= clockwise
                ? "turn the periapsis " + stepWords(counterclockwise) + " counterclockwise"
                : "turn the periapsis " + stepWords(clockwise) + " clockwise"
            if second.isEmpty {
                second = "T" + String(turn.dropFirst())
            } else {
                second += " and " + turn
            }
        }
        return ["Turn the periapsis knob next", second,
                "Set the periapsis to eccentricity \(k), direction \(d * 15)°"]
    case .size(let a):
        let change: Int = a > orbit.size ? a - orbit.size : orbit.size - a
        let units: String = change == 1 ? "1 unit" : "\(change) units"
        let second: String = (a > orbit.size ? "Grow" : "Shrink") + " the orbit by " + units
        return ["Change the size next", second, "Set the size to \(a)"]
    case .play:
        return []
    }
}

/// Follows exact (level 3) hints from `start` until the play ends; the problems found (empty: won, every hinted action
/// accepted, the play unchanged by every hint) and the tunings spent following them.
private func followHints(_ start: ApsidesWorkshopPlay, label: String) -> (problems: [String], spent: Int) {
    var play: ApsidesWorkshopPlay = start
    let spentBefore: Int = play.actionsSpent
    for _ in 0..<6 {
        if play.stage == .won { return ([], play.actionsSpent - spentBefore) }
        let before: ApsidesWorkshopPlay = play
        guard let hint = ApsidesWorkshopHints.hint(level: 3, play: play) else {
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

/// A share in words, written here: 184 → "18.4 %".
private func shareText(_ share: Int) -> String { "\(share / 10).\(share % 10) %" }

/// A distance in twentieths in words, written here: 131 → "6.55 units".
private func distanceText(_ twentieths: Int) -> String {
    let hundredths: Int = twentieths % 20 * 5
    let padded: String = hundredths < 10 ? "0\(hundredths)" : "\(hundredths)"
    return "\(twentieths / 20).\(padded) units"
}

/// The failure of `orbit` in `level` and its explanation text, by a judge written here over the kernel's positions
/// (contact first, lowest tick then lowest planet; then the targets in order: order, share, apsis sector, apsis
/// distance); nil when the orbit wins.
private func expectedExplanation(_ level: ApsidesWorkshopLevel,
                                 _ orbit: ApsidesWorkshopOrbit) -> (failure: ApsidesWorkshopFailure, text: String)? {
    let advice: String = " Undo the last action or retry the level."
    let points: [ApsidesWorkshopPoint] = ApsidesWorkshopSky.positions(orbit, period: level.period).points
    for tick in 0..<level.period {
        for planet in 0..<level.planets.count {
            let next: ApsidesWorkshopPoint = points[(tick + 1) % level.period]
            if ApsidesWorkshopSky.touches(level.planets[planet], from: points[tick], to: next) {
                return (.contact(planet: planet, tick: tick),
                        "The orbit struck planet \(planet) after tick \(tick)." + advice)
            }
        }
    }
    let shares: [Int] = ApsidesWorkshopSky.shares(points)
    var previousTick: Int = -1
    for index in 0..<level.targets.count {
        let target: ApsidesWorkshopTarget = level.targets[index]
        var tick: Int = level.period
        if target.kind == .periapsis { tick = 0 }
        if target.kind == .apoapsis { tick = level.period / 2 }
        if target.kind == .sweep {
            for position in 0..<points.count where ApsidesWorkshopSky.sector(of: points[position]) == target.sector {
                tick = position
                break
            }
        }
        let number: Int = index + 1
        if index > 0 && tick < previousTick {
            return (.order(target: index, tick: tick),
                    "Target \(number) was reached at tick \(tick), before the target before it." + advice)
        }
        previousTick = tick
        if target.kind == .sweep {
            let share: Int = shares[target.sector]
            if share < target.low || share > target.high {
                let text: String = "Target \(number) (sector \(target.sector), reached at tick \(tick)) swept "
                    + shareText(share) + ", outside its band from " + shareText(target.low) + " to "
                    + shareText(target.high) + "." + advice
                return (.share(target: index, tick: tick, share: share), text)
            }
            continue
        }
        let periapsis: Bool = target.kind == .periapsis
        let name: String = periapsis ? "periapsis" : "apoapsis"
        let sector: Int = periapsis ? orbit.direction / 3 : (orbit.direction + 12) / 3 % 8
        let distance: Int = periapsis ? orbit.size * (20 - orbit.eccentricity) : orbit.size * (20 + orbit.eccentricity)
        if sector != target.sector {
            return (.apsisSector(target: index, sector: sector),
                    "Target \(number): the \(name) lies in sector \(sector), not in sector \(target.sector)." + advice)
        }
        if distance < target.low || distance > target.high {
            let text: String = "Target \(number): the \(name) lies at " + distanceText(distance)
                + ", outside its range from " + distanceText(target.low) + " to " + distanceText(target.high) + "."
                + advice
            return (.apsisDistance(target: index, distance: distance), text)
        }
    }
    return nil
}

@Suite struct ApsidesWorkshopHintsTests {
    typealias Level = ApsidesWorkshopLevel
    typealias Orbit = ApsidesWorkshopOrbit
    typealias Target = ApsidesWorkshopTarget
    typealias Action = ApsidesWorkshopAction
    typealias Play = ApsidesWorkshopPlay
    typealias Hints = ApsidesWorkshopHints
    typealias Hint = ApsidesWorkshopHint
    typealias Solver = ApsidesWorkshopSolver

    /// The seed of the feature's seeded tests.
    static let seed: UInt64 = 2_475

    /// The usual hand start: size 20, eccentricity step 5, direction 0.
    static let start: Orbit = Orbit(size: 20, eccentricity: 5, direction: 0)

    /// A hand level: period 16, the given planets and targets, budget `budget`.
    static func hand(_ id: String, _ targets: [Target], start: Orbit = start, budget: Int = 4,
                     planets: [ApsidesWorkshopPlanet] = []) throws -> Level {
        try Level(id: id, seed: seed, difficulty: 1, period: 16, planets: planets, targets: targets, orbit: start,
                  budget: budget)
    }

    /// A periapsis target of one distance.
    static func periapsis(_ sector: Int, _ distance: Int) -> Target {
        Target(kind: .periapsis, sector: sector, low: distance, high: distance)
    }

    /// An apoapsis target of one distance.
    static func apoapsis(_ sector: Int, _ distance: Int) -> Target {
        Target(kind: .apoapsis, sector: sector, low: distance, high: distance)
    }

    /// The hint texts at levels 1, 2 and 3 for `play`.
    static func texts(_ play: Play) -> [String] {
        var result: [String] = []
        for level in 1...3 {
            if let hint = Hints.hint(level: level, play: play) { result.append(hint.text) }
        }
        return result
    }

    // MARK: - Certified levels

    /// SC-R02G1805-002: on every certified level the certifying plan equals the new entry at the starting orbit and
    /// the witness; the first hint's texts read as written here; following exact hints then the play wins with the
    /// witness's tunings, within the budget. 20 groups of 5 levels.
    @Test(arguments: 0..<20) func exactHintsWinEveryCertifiedLevel(group: Int) throws {
        let start: ContinuousClock.Instant = ContinuousClock.now
        let witnesses: [ApsidesWorkshopWitness] = try hintWitnesses()
        #expect(witnesses.count == 100)
        for index in (group * 5)..<(group * 5 + 5) {
            let witness: ApsidesWorkshopWitness = witnesses[index]
            let level: Level = witness.level
            let tunings: [Action] = witnessTunings(witness)
            let certifying: ApsidesWorkshopPlan? = Solver.plan(level)
            let fromStart: ApsidesWorkshopPlan? = Solver.plan(level, from: level.orbit)
            #expect(certifying == fromStart, "level \(witness.number)")
            #expect(fromStart?.actions == tunings, "level \(witness.number)")
            #expect(fromStart?.orbitsSearched == witness.difficulty.orbitsSearched, "level \(witness.number)")
            #expect(fromStart?.work == witness.difficulty.work, "level \(witness.number)")
            let opening: Play = try openingPlay(level)
            #expect(Hints.plan(opening)?.tunings == tunings, "level \(witness.number)")
            if let first = tunings.first {
                #expect(Self.texts(opening) == expectedTexts(first, from: level.orbit), "level \(witness.number)")
            }
            let followed: (problems: [String], spent: Int) = followHints(opening, label: "level \(witness.number)")
            #expect(followed.problems.isEmpty, "\(followed.problems)")
            #expect(followed.spent == tunings.count, "level \(witness.number)")
            #expect(followed.spent <= level.budget, "level \(witness.number)")
        }
        report("exactHintsWinEveryCertifiedLevel(\(group))", since: start)
    }

    /// The new entry from other orbits: a winning orbit gives no tunings (work 1, no depths); an invalid orbit, a
    /// depth limit of 0, or a depth limit of 1 on a two-tuning level gives nil; one witness tuning in, the plan from
    /// there is one tuning shorter. Levels 1, 21, 41, 61 and 81.
    @Test func planFromOtherOrbits() throws {
        let start: ContinuousClock.Instant = ContinuousClock.now
        let witnesses: [ApsidesWorkshopWitness] = try hintWitnesses()
        let picks: [Int] = [0, 20, 40, 60, 80]
        for index in picks {
            let witness: ApsidesWorkshopWitness = witnesses[index]
            let level: Level = witness.level
            let tunings: [Action] = witnessTunings(witness)
            var winning: Orbit = level.orbit
            for action in tunings { winning = orbitAfter(winning, action) }
            let won: ApsidesWorkshopPlan? = Solver.plan(level, from: winning)
            #expect(won == ApsidesWorkshopPlan(actions: [], orbit: winning, orbitsByDepth: [], work: 1))
            let invalid: Orbit = Orbit(size: 48, eccentricity: 15, direction: 0)
            #expect(Solver.plan(level, from: invalid) == nil)
            #expect(Solver.plan(level, from: level.orbit, maxTunings: 0) == nil)
            if tunings.count == 2 {
                #expect(Solver.plan(level, from: level.orbit, maxTunings: 1) == nil, "level \(witness.number)")
            }
            if let first = tunings.first {
                let after: Orbit = orbitAfter(level.orbit, first)
                let rest: ApsidesWorkshopPlan? = Solver.plan(level, from: after)
                #expect(rest?.size == tunings.count - 1, "level \(witness.number)")
            }
        }
        // A two-tuning hand level, in case the picks hold none.
        let both: Level = try Self.hand("both-levers", [Self.periapsis(2, 300), Self.apoapsis(6, 900)])
        #expect(Solver.plan(both, from: both.orbit, maxTunings: 1) == nil)
        #expect(Solver.plan(both, from: both.orbit)?.actions == [.size(30), .periapsis(10, 6)])
        report("planFromOtherOrbits", since: start)
    }

    // MARK: - Seeded reachable states

    /// SC-R02G1805-002: 200 seeded reachable states (20 groups of 10) get a hint the kernel accepts; following hints
    /// from there wins within the actions left; no hint, plan or explanation changes the play.
    @Test(arguments: 0..<20) func everyExactHintIsAccepted(group: Int) throws {
        let start: ContinuousClock.Instant = ContinuousClock.now
        let witnesses: [ApsidesWorkshopWitness] = try hintWitnesses()
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ UInt64(group))
        for state in 0..<10 {
            let label: String = "group \(group) state \(state)"
            let level: Level = witnesses[random.int(0...99)].level
            var play: Play = try openingPlay(level)
            let count: Int = random.int(0...2)
            for _ in 0..<count {
                guard let action = randomTuning(play.orbit, &random) else { continue }
                try play.apply(action, expecting: play.fingerprint)
            }
            let before: Play = play
            let plan: ApsidesWorkshopHintPlan? = Hints.plan(play)
            let hint: Hint? = Hints.hint(level: 3, play: play)
            let explanation: ApsidesWorkshopFailureExplanation? = ApsidesWorkshopFailureExplanation(play: play)
            #expect(play == before, "\(label): read-only")
            #expect(explanation == nil, "\(label)")
            guard let hint else {
                Issue.record("\(label): no hint while playing")
                continue
            }
            if play.actionsLeft >= 2 { #expect(hint.kind != .stuck, "\(label): stuck") }
            guard let action = hint.action, let plan else {
                #expect(plan == nil && hint.kind == .stuck, "\(label)")
                continue
            }
            if plan.tunings.isEmpty {
                #expect(hint.kind == .play && action == .play, "\(label)")
            } else {
                #expect(hint.kind == .tune && action == plan.tunings[0], "\(label)")
                #expect(plan.tunings.count <= play.actionsLeft, "\(label)")
            }
            var probe: Play = play
            do {
                try probe.apply(action, expecting: probe.fingerprint)
            } catch {
                Issue.record("\(label): hinted \(action) refused: \(error)")
                continue
            }
            if action == .play { #expect(probe.stage == .won, "\(label)") }
            let followed: (problems: [String], spent: Int) = followHints(play, label: label)
            #expect(followed.problems.isEmpty, "\(followed.problems)")
            #expect(followed.spent <= play.actionsLeft, "\(label)")
        }
        report("everyExactHintIsAccepted(\(group))", since: start)
    }

    // MARK: - Hint texts

    /// Clarification Q1: the three levels on hand levels — a size plan (grow, then raise and turn), a knob-first plan
    /// (lower and turn, then grow), the shrink by one unit, the clockwise turn, the 12-step tie, one step each way of
    /// the eccentricity and the direction alone.
    @Test func hintTextsReadAsClarified() throws {
        let sizeFirst: Level = try Self.hand("size-first", [Self.periapsis(2, 300), Self.apoapsis(6, 900)])
        var play: Play = try openingPlay(sizeFirst)
        #expect(Self.texts(play) == ["Change the size next", "Grow the orbit by 10 units", "Set the size to 30"])
        try play.apply(.size(30), expecting: play.fingerprint)
        #expect(Self.texts(play) == ["Turn the periapsis knob next",
                                     "Raise the eccentricity by 5 steps and turn the periapsis 6 steps "
                                         + "counterclockwise",
                                     "Set the periapsis to eccentricity 10, direction 90°"])
        let knobFirst: Level = try Self.hand("knob-first", [Self.periapsis(2, 768), Self.apoapsis(6, 1_152)],
                                             start: Orbit(size: 40, eccentricity: 8, direction: 0))
        play = try openingPlay(knobFirst)
        #expect(Self.texts(play) == ["Turn the periapsis knob next",
                                     "Lower the eccentricity by 4 steps and turn the periapsis 6 steps "
                                         + "counterclockwise",
                                     "Set the periapsis to eccentricity 4, direction 90°"])
        try play.apply(.periapsis(4, 6), expecting: play.fingerprint)
        #expect(Self.texts(play) == ["Change the size next", "Grow the orbit by 8 units", "Set the size to 48"])
        let shrink: Level = try Self.hand("shrink", [Self.apoapsis(4, 475)])
        #expect(Self.texts(try openingPlay(shrink)) == ["Change the size next", "Shrink the orbit by 1 unit",
                                                        "Set the size to 19"])
        let clockwise: Level = try Self.hand("clockwise", [Self.periapsis(7, 300)])
        #expect(Self.texts(try openingPlay(clockwise)) == ["Turn the periapsis knob next",
                                                           "Turn the periapsis 3 steps clockwise",
                                                           "Set the periapsis to eccentricity 5, direction 315°"])
        let tie: Level = try Self.hand("tie", [Self.periapsis(4, 300)])
        #expect(Self.texts(try openingPlay(tie)) == ["Turn the periapsis knob next",
                                                     "Turn the periapsis 12 steps counterclockwise",
                                                     "Set the periapsis to eccentricity 5, direction 180°"])
        let oneStep: Level = try Self.hand("one-step", [Self.periapsis(1, 300)],
                                           start: Orbit(size: 20, eccentricity: 5, direction: 2))
        #expect(Self.texts(try openingPlay(oneStep)) == ["Turn the periapsis knob next",
                                                         "Turn the periapsis 1 step counterclockwise",
                                                         "Set the periapsis to eccentricity 5, direction 45°"])
        let lower: Level = try Self.hand("lower", [Self.periapsis(0, 320)])
        #expect(Self.texts(try openingPlay(lower)) == ["Turn the periapsis knob next",
                                                       "Lower the eccentricity by 1 step",
                                                       "Set the periapsis to eccentricity 4, direction 0°"])
        let raise: Level = try Self.hand("raise", [Self.periapsis(0, 280)])
        #expect(Self.texts(try openingPlay(raise)) == ["Turn the periapsis knob next",
                                                       "Raise the eccentricity by 1 step",
                                                       "Set the periapsis to eccentricity 6, direction 0°"])
        // The texts helper on its own: levels outside 1 … 3 clamp, the play has no tuning text.
        #expect(Hint.tuneText(level: 0, action: .size(30), orbit: Self.start) == "Change the size next")
        #expect(Hint.tuneText(level: 9, action: .size(30), orbit: Self.start) == "Set the size to 30")
        #expect(Hint.tuneText(level: 2, action: .play, orbit: Self.start) == nil)
        #expect(Hint.turn(from: 0, to: 12).steps == 12 && Hint.turn(from: 0, to: 12).counterclockwise)
        #expect(Hint.turn(from: 23, to: 1).steps == 2 && Hint.turn(from: 23, to: 1).counterclockwise)
        #expect(Hint.turn(from: 1, to: 23).steps == 2 && !Hint.turn(from: 1, to: 23).counterclockwise)
    }

    /// Clarification Q1: the hint in every stage — loading and paused none; the already-winning orbit the play at
    /// every level; won none; failed and result after a failure the failed advice; result after a win none; a budget
    /// too small for the minimal plan, and no action left, `stuck`.
    @Test func hintsInEveryStage() throws {
        let level: Level = try Self.hand("stages", [Self.periapsis(2, 300), Self.apoapsis(6, 900)])
        #expect(Hints.hint(level: 1, play: Play(level: level)) == nil)
        var paused: Play = try openingPlay(level)
        try paused.handle(.pause)
        #expect(Hints.hint(level: 1, play: paused) == nil)
        #expect(Hints.plan(paused) == nil)
        var winning: Play = try openingPlay(level)
        try winning.apply(.size(30), expecting: winning.fingerprint)
        try winning.apply(.periapsis(10, 6), expecting: winning.fingerprint)
        #expect(Hints.plan(winning) == ApsidesWorkshopHintPlan(tunings: []))
        for hintLevel in 1...3 {
            let hint: Hint? = Hints.hint(level: hintLevel, play: winning)
            #expect(hint?.kind == .play && hint?.action == .play && hint?.level == hintLevel)
            #expect(hint?.text == "Every target reads in its band: play the revolution")
        }
        try winning.apply(.play, expecting: winning.fingerprint)
        #expect(winning.stage == .won)
        #expect(Hints.hint(level: 2, play: winning) == nil)
        try winning.handle(.showResult)
        #expect(Hints.hint(level: 2, play: winning) == nil)
        #expect(ApsidesWorkshopFailureExplanation(play: winning) == nil)
        var failed: Play = try openingPlay(level)
        try failed.apply(.play, expecting: failed.fingerprint)
        #expect(failed.stage == .failed)
        let failedHint: Hint? = Hints.hint(level: 3, play: failed)
        #expect(failedHint?.kind == .stuck && failedHint?.action == nil)
        #expect(failedHint?.text == "Undo the last action or retry the level.")
        try failed.handle(.showResult)
        #expect(Hints.hint(level: 1, play: failed)?.text == "Undo the last action or retry the level.")
        let stuckText: String =
            "No way to win was found in the actions left: undo the last action or retry the level."
        let tight: Level = try Self.hand("tight", [Self.periapsis(2, 300), Self.apoapsis(6, 900)], budget: 1)
        var stuck: Play = try openingPlay(tight)
        #expect(Hints.plan(stuck) == nil)
        let stuckHint: Hint? = Hints.hint(level: 2, play: stuck)
        #expect(stuckHint?.kind == .stuck && stuckHint?.action == nil && stuckHint?.text == stuckText)
        try stuck.apply(.size(30), expecting: stuck.fingerprint)
        #expect(stuck.actionsLeft == 0)
        #expect(Hints.hint(level: 1, play: stuck)?.text == stuckText)
    }

    // MARK: - Failure explanations

    /// Clarification Q5: every failure kind on a hand level, with the level's words and the advice.
    @Test func everyFailureKindIsExplained() throws {
        let advice: String = " Undo the last action or retry the level."
        let anywhere: Target = Target.sweep(sector: 0, low: 0, high: 1_000)
        let contact: Level = try Self.hand("contact", [anywhere],
                                           planets: [ApsidesWorkshopPlanet(x: 15, y: 0, radius: 2)])
        #expect(try Self.explain(contact) == "The orbit struck planet 0 after tick 0." + advice)
        let order: Level = try Self.hand("order", [Target.sweep(sector: 4, low: 0, high: 1_000), anywhere])
        #expect(try Self.explain(order) == "Target 2 was reached at tick 0, before the target before it." + advice)
        let points: [ApsidesWorkshopPoint] = ApsidesWorkshopSky.positions(Self.start, period: 16).points
        let share: Int = ApsidesWorkshopSky.shares(points)[0]
        let low: Int = share >= 10 ? 0 : share + 10
        let high: Int = share >= 10 ? share - 10 : share + 20
        let band: Level = try Self.hand("share", [Target.sweep(sector: 0, low: low, high: high)])
        #expect(try Self.explain(band) == "Target 1 (sector 0, reached at tick 0) swept " + shareText(share)
            + ", outside its band from " + shareText(low) + " to " + shareText(high) + "." + advice)
        let sector: Level = try Self.hand("sector", [Self.periapsis(2, 300)])
        #expect(try Self.explain(sector) == "Target 1: the periapsis lies in sector 0, not in sector 2." + advice)
        let apoapsisSector: Level = try Self.hand("apoapsis-sector", [Self.periapsis(0, 300), Self.apoapsis(6, 500)])
        #expect(try Self.explain(apoapsisSector)
            == "Target 2: the apoapsis lies in sector 4, not in sector 6." + advice)
        let near: Level = try Self.hand("near", [Target(kind: .periapsis, sector: 0, low: 320, high: 340)])
        #expect(try Self.explain(near)
            == "Target 1: the periapsis lies at 15.00 units, outside its range from 16.00 units to 17.00 units."
            + advice)
        let far: Level = try Self.hand("far", [Target(kind: .apoapsis, sector: 4, low: 503, high: 540)])
        #expect(try Self.explain(far)
            == "Target 1: the apoapsis lies at 25.00 units, outside its range from 25.15 units to 27.00 units."
            + advice)
        // Not failed: none.
        #expect(ApsidesWorkshopFailureExplanation(play: try openingPlay(far)) == nil)
    }

    /// The explanation text of `level`'s start played at once ("" when there is none).
    static func explain(_ level: Level) throws -> String {
        var play: Play = try openingPlay(level)
        try play.apply(.play, expecting: play.fingerprint)
        return ApsidesWorkshopFailureExplanation(play: play)?.text ?? ""
    }

    /// SC-R02G1805-003: 500 seeded failures (25 groups of 20) are explained with the true planet or target, tick and
    /// reading, as the judge written here says from the orbit tracked here.
    @Test(arguments: 0..<25) func seededFailuresAreExplained(group: Int) throws {
        let start: ContinuousClock.Instant = ContinuousClock.now
        let witnesses: [ApsidesWorkshopWitness] = try hintWitnesses()
        var random: SeededRandom = SeededRandom(seed: Self.seed &+ 100 &+ UInt64(group))
        var explained: Int = 0
        var attempts: Int = 0
        while explained < 20 && attempts < 400 {
            attempts += 1
            let level: Level = witnesses[random.int(0...99)].level
            var play: Play = try openingPlay(level)
            var orbit: Orbit = level.orbit
            var history: [Orbit] = []
            let count: Int = random.int(0...3)
            for _ in 0..<count {
                guard let action = randomTuning(orbit, &random) else { continue }
                try play.apply(action, expecting: play.fingerprint)
                history.append(orbit)
                orbit = orbitAfter(orbit, action)
            }
            if !history.isEmpty && random.int(0...3) == 0 {
                try play.undo()
                let undone: Orbit = orbit
                orbit = history.removeLast()
                if random.int(0...1) == 0 {
                    try play.redo()
                    history.append(orbit)
                    orbit = undone
                }
            }
            guard let expected = expectedExplanation(level, orbit) else { continue }
            try play.apply(.play, expecting: play.fingerprint)
            #expect(play.stage == .failed)
            if random.int(0...3) == 0 {
                try play.undo()
                try play.redo()
            }
            if random.int(0...2) == 0 { try play.handle(.showResult) }
            let before: Play = play
            let explanation: ApsidesWorkshopFailureExplanation? = ApsidesWorkshopFailureExplanation(play: play)
            #expect(play == before)
            #expect(explanation?.failure == expected.failure, "group \(group) attempt \(attempts)")
            #expect(explanation?.text == expected.text, "group \(group) attempt \(attempts)")
            #expect(Hints.hint(level: 2, play: play)?.text == "Undo the last action or retry the level.")
            explained += 1
        }
        #expect(explained == 20)
        report("seededFailuresAreExplained(\(group))", since: start)
    }
}
