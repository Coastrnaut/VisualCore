// MushroomWeatherHintsTests — feature 495 (R02-G20-05) T-R02G2005-002 (FR-R02G2005-002, 003; SC-R02G2005-002, 003;
// clarifications Q1, Q5). Hints and failure explanations of Mushroom Weather. The 100 certified levels and their
// certified plans are read from the stored witnesses in docs/games/mushroom-weather/levels/ with the plain decoder (as
// MushroomWeatherCatalogTests reads them; the environment variable MUSHROOM_WEATHER_LEVELS_DIR may name another
// directory holding the same files); a certified plan is the witness's actions without the closing run and the
// arrangement they reach, replayed through the play. In 25 groups of 4 levels: the hint plan from the opening is the
// witness's actions; the level 1, 2 and 3 texts of the first hint match texts written here; following exact (level 3)
// hints, re-asked after every action, then the hinted run wins spending exactly the witness's actions, within the
// budget, and no hint changes the play. 200 seeded reachable states (seed 2_495 plus the case, 200 cases of one: 0 … 4
// random accepted pod, vent and moonlight actions from a random certified opening) get a hint the kernel accepts (the
// run only when the arrangement already wins), following hints from a non-stuck state wins within the actions left,
// and no hint or explanation changes the play (fingerprint and value). Off the certified path (a pod on a site the
// witness does not use, alone, on level 8g + 1; the witness's arrangement plus such a pod on level 10g + 10; the
// witness's actions but the last plus such a pod on level 10g + 5; 10 groups of 3), an independent brute force over
// every arrangement reachable within min(actions left, 2) actions decides whether a win exists and its shortest
// length; the bounded plan (and, were it to give up, the unbounded one) exists exactly then, has that length, wins
// through the kernel and does not change the play. Hand plays check the stages (loading, paused, won and result after
// a win: no hint; failed and result after a failure: the failed advice), the stuck text with no action left and the
// hint texts. 500 seeded failures (seed 2_495 plus 100 plus the group, 25 groups of 20: random accepted actions, some
// undone and redone, then the run, some shown as a result) are explained with the true colony, cell, cycle and run
// lengths: the failure equals the one judged here from the play's arrangement and the text equals the one written
// here (counts of 1 in the singular, T-R02G2005-004). Mold, which no seeded catalog failure shows, is explained on 10
// damp copies of catalog levels. No clock; deterministic, explicit types, plain loops (CI type-check rule).
import Foundation
import Testing
import VisualCoreSimulation
@testable import MushroomWeatherCore

/// The witness directory: `MUSHROOM_WEATHER_LEVELS_DIR` when set, else the repository's, found from this file (five
/// levels up: CoreTests, MushroomWeather, the package, Packages).
private let hintWitnessDirectory: URL = {
    if let override = ProcessInfo.processInfo.environment["MUSHROOM_WEATHER_LEVELS_DIR"], !override.isEmpty {
        return URL(fileURLWithPath: override, isDirectory: true)
    }
    return URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/games/mushroom-weather/levels", isDirectory: true)
}()

/// The 100 stored witnesses in manifest order, read once per test process with the plain decoder.
private let hintWitnessesResult: Result<[MushroomWeatherWitness], any Error> = Result {
    var result: [MushroomWeatherWitness] = []
    for entry in MushroomWeatherManifest.entries {
        let name: String = String(MushroomWeatherGenerator.levelID(entry.number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: hintWitnessDirectory.appendingPathComponent(name))
        result.append(try JSONDecoder().decode(MushroomWeatherWitness.self, from: data))
    }
    return result
}

/// The stored witnesses.
private func hintWitnesses() throws -> [MushroomWeatherWitness] { try hintWitnessesResult.get() }

/// The arrangement actions of a witness (its actions without the closing run).
private func witnessChanges(_ witness: MushroomWeatherWitness) -> [MushroomWeatherAction] {
    var result: [MushroomWeatherAction] = []
    for action in witness.actions where action != .run { result.append(action) }
    return result
}

/// The opening play of `level`: begun, past its tutorial.
private func openingPlay(_ level: MushroomWeatherLevel) throws -> MushroomWeatherPlay {
    var play: MushroomWeatherPlay = MushroomWeatherPlay(level: level)
    try play.handle(.begin)
    if play.stage == .tutorial { try play.handle(.dismissTutorial) }
    return play
}

/// The certified plan of a witness: its arrangement actions and the arrangement they reach from the opening.
private func certifiedPlan(_ witness: MushroomWeatherWitness) throws -> MushroomWeatherPlan {
    var play: MushroomWeatherPlay = try openingPlay(witness.level)
    let changes: [MushroomWeatherAction] = witnessChanges(witness)
    for action in changes { try play.apply(action, expecting: play.fingerprint) }
    return MushroomWeatherPlan(actions: changes, arrangement: play.arrangement, arrangementsByDepth: [],
                               nearestMiss: 0, work: 0)
}

/// The texts of a pod, vent or moonlight hint at levels 1, 2 and 3 from `arrangement`, written here independently of
/// the hint engine.
private func expectedTexts(_ action: MushroomWeatherAction, arrangement: MushroomWeatherArrangement) -> [String] {
    switch action {
    case .place(let slot, let cell):
        let words: String = "row \(cell.row), column \(cell.column)"
        let occupied: Bool = arrangement.pods[slot] != nil
        let exact: String = occupied ? "Move pod \(slot + 1) to the site at \(words)"
            : "Put pod \(slot + 1) on the site at \(words)"
        return ["Change a spore pod", "Use the site at \(words)", exact]
    case .remove(let slot):
        return ["Change a spore pod", "Take pod \(slot + 1) away", "Take pod \(slot + 1) away"]
    case .vent(let index, let open):
        return ["Change a vent", "Use vent \(index + 1)", (open ? "Open" : "Close") + " vent \(index + 1)"]
    case .moonlight(let value):
        let way: String = value > arrangement.moonlight ? "brighter" : "dimmer"
        return ["Change the moonlight", "Make the moonlight \(way)", "Set the moonlight to level \(value)"]
    case .run:
        return []
    }
}

/// The explanation of `failure` on `level`, written here independently of the explanation.
private func expectedExplanation(_ failure: MushroomWeatherFailure, level: MushroomWeatherLevel) -> String {
    let sentence: String
    switch failure {
    case .dried(let colony, let cycle):
        sentence = "Colony \(colony + 1) dried out at cycle \(cycle): it fell below its survival floor."
    case .mold(let cell, let cycle):
        sentence = "The cell at row \(cell.row), column \(cell.column) grew mold at cycle \(cycle): it rose above "
            + "the mold bound."
    case .unstable(let colony, let run):
        // Singular counts (T-R02G2005-004): "the last 1 cycle", "1 was needed".
        let cycles: String = run == 1 ? "cycle" : "cycles"
        let needed: String = level.required == 1 ? "was" : "were"
        sentence = "Colony \(colony + 1) stayed in its band for only the last \(run) \(cycles); \(level.required) "
            + "\(needed) needed."
    }
    return sentence + " Undo the last action or retry the level."
}

/// Follows exact (level 3) hints from `start` until the play ends, running the weather when hinted; the problems found
/// (empty: won, every hinted action accepted, the play unchanged by every hint) and the actions spent following them.
private func followHints(_ start: MushroomWeatherPlay, certified: MushroomWeatherPlan?,
                         label: String) -> (problems: [String], spent: Int) {
    var play: MushroomWeatherPlay = start
    let spentBefore: Int = play.actionsSpent
    for _ in 0..<30 {
        if play.stage == .won { return ([], play.actionsSpent - spentBefore) }
        let before: MushroomWeatherPlay = play
        let fingerprint: String = play.fingerprint
        guard let hint = MushroomWeatherHints.hint(level: 3, play: play, certified: certified) else {
            return (["\(label): no hint in \(play.stage)"], play.actionsSpent - spentBefore)
        }
        guard play == before, play.fingerprint == fingerprint else {
            return (["\(label): the hint changed the play"], play.actionsSpent - spentBefore)
        }
        guard let action = hint.action else {
            return (["\(label): stuck with \(play.actionsLeft) actions left"], play.actionsSpent - spentBefore)
        }
        do {
            try play.apply(action, expecting: play.fingerprint)
        } catch {
            return (["\(label): hinted \(action) refused: \(error)"], play.actionsSpent - spentBefore)
        }
    }
    if play.stage == .won { return ([], play.actionsSpent - spentBefore) }
    return (["\(label): not won after following hints (\(play.stage))"], play.actionsSpent - spentBefore)
}

/// A random pod, vent or moonlight action the kernel accepts from `play` (a removal of a random slot about one time in
/// five when a pod is placed, a vent set to a random state about one time in five, a random moonlight about one time
/// in ten, else a placement on a random site into a random slot), applied; false after 30 refused tries.
private func randomAction(_ play: inout MushroomWeatherPlay, _ random: inout SeededRandom) -> Bool {
    let sites: [MushroomWeatherCell] = play.level.sites ?? []
    let slots: Int = play.level.podRules.slots
    let vents: Int = play.level.vents.count
    guard !sites.isEmpty else { return false }
    for _ in 0..<30 {
        let roll: Int = random.int(0...9)
        let action: MushroomWeatherAction
        if roll <= 1 && !play.arrangement.placedPods.isEmpty {
            action = .remove(slot: random.int(0...(slots - 1)))
        } else if roll <= 3 && vents > 0 {
            action = .vent(index: random.int(0...(vents - 1)), open: random.int(0...1) == 0)
        } else if roll == 4 {
            action = .moonlight(level: random.int(0...3))
        } else {
            action = .place(slot: random.int(0...(slots - 1)), cell: sites[random.int(0...(sites.count - 1))])
        }
        do {
            try play.apply(action, expecting: play.fingerprint)
            return true
        } catch {
            continue
        }
    }
    return false
}

/// The arrangement of `level` holding `pods` in slots 0, 1, … (in row-major order), `vents` and `moonlight`.
private func bruteArrangement(_ level: MushroomWeatherLevel, pods: Set<MushroomWeatherCell>, vents: [Bool],
                              moonlight: Int) -> MushroomWeatherArrangement {
    var slots: [MushroomWeatherCell?] = Array(repeating: nil, count: level.podRules.slots)
    var slot: Int = 0
    for cell in pods.sorted() {
        slots[slot] = cell
        slot += 1
    }
    return MushroomWeatherArrangement(pods: slots, ventsOpen: vents, moonlight: moonlight)
}

/// A state of the brute force: the set of pod cells, the vents and the moonlight.
private struct BruteState: Hashable {
    /// The pod cells.
    let pods: Set<MushroomWeatherCell>
    /// The vents' states.
    let vents: [Bool]
    /// The moonlight.
    let moonlight: Int
}

/// The shortest number of actions within `depth` that reaches a winning arrangement from `arrangement` on `level`, by
/// a brute force written here over sets of pod cells, vent states and moonlight levels: from a state, an action takes
/// one pod away, moves one pod to a site no pod holds, adds a pod on such a site while fewer pods than slots are
/// placed, toggles one vent or sets another moonlight level. Every state is judged at most once, without a bound; nil
/// when none wins.
private func bruteShortest(_ level: MushroomWeatherLevel, arrangement: MushroomWeatherArrangement,
                           depth: Int) -> Int? {
    let start: BruteState = BruteState(pods: Set(arrangement.placedPods), vents: arrangement.ventsOpen,
                                       moonlight: arrangement.moonlight)
    if MushroomWeatherForest.report(level, arrangement: arrangement).wins { return 0 }
    let sites: [MushroomWeatherCell] = level.sites ?? []
    var visited: Set<BruteState> = [start]
    var frontier: [BruteState] = [start]
    var step: Int = 0
    while step < depth {
        step += 1
        var next: [BruteState] = []
        for state in frontier {
            var successors: [BruteState] = []
            for pod in state.pods {
                var without: Set<MushroomWeatherCell> = state.pods
                without.remove(pod)
                successors.append(BruteState(pods: without, vents: state.vents, moonlight: state.moonlight))
                for site in sites where !state.pods.contains(site) {
                    successors.append(BruteState(pods: without.union([site]), vents: state.vents,
                                                 moonlight: state.moonlight))
                }
            }
            if state.pods.count < level.podRules.slots {
                for site in sites where !state.pods.contains(site) {
                    successors.append(BruteState(pods: state.pods.union([site]), vents: state.vents,
                                                 moonlight: state.moonlight))
                }
            }
            for index in state.vents.indices {
                var vents: [Bool] = state.vents
                vents[index].toggle()
                successors.append(BruteState(pods: state.pods, vents: vents, moonlight: state.moonlight))
            }
            for value in 0...3 where value != state.moonlight {
                successors.append(BruteState(pods: state.pods, vents: state.vents, moonlight: value))
            }
            for successor in successors where !visited.contains(successor) {
                visited.insert(successor)
                let candidate: MushroomWeatherArrangement = bruteArrangement(level, pods: successor.pods,
                                                                            vents: successor.vents,
                                                                            moonlight: successor.moonlight)
                if MushroomWeatherForest.report(level, arrangement: candidate).wins { return step }
                next.append(successor)
            }
        }
        frontier = next
    }
    return nil
}

@Suite struct MushroomWeatherHintsTests {
    /// Exact hints from the opening replay the witness and, then the run, win every certified level within its budget
    /// (25 groups of 4 levels).
    @Test(arguments: Array(0..<25))
    func followingHintsWinsEveryCertifiedLevel(group: Int) throws {
        let witnesses: [MushroomWeatherWitness] = try hintWitnesses()
        for index in (group * 4)..<(group * 4 + 4) {
            let witness: MushroomWeatherWitness = witnesses[index]
            let certified: MushroomWeatherPlan = try certifiedPlan(witness)
            let changes: [MushroomWeatherAction] = witnessChanges(witness)
            let opening: MushroomWeatherPlay = try openingPlay(witness.level)
            let plan: MushroomWeatherHintPlan? = MushroomWeatherHints.plan(opening, certified: certified)
            #expect(plan?.actions == changes, "level \(witness.number): opening plan")
            for level in 1...3 {
                let hint: MushroomWeatherHint? = MushroomWeatherHints.hint(level: level, play: opening,
                                                                           certified: certified)
                #expect(hint?.level == level)
                if let first = changes.first {
                    #expect(hint?.action == first, "level \(witness.number)")
                    #expect(hint?.kind == MushroomWeatherHint.kind(of: first), "level \(witness.number)")
                    let texts: [String] = expectedTexts(first, arrangement: opening.arrangement)
                    #expect(hint?.text == texts[level - 1], "level \(witness.number)")
                }
            }
            let followed: (problems: [String], spent: Int) = followHints(opening, certified: certified,
                                                                         label: "level \(witness.number)")
            #expect(followed.problems.isEmpty, "\(followed.problems)")
            #expect(followed.spent == changes.count, "level \(witness.number): spent \(followed.spent)")
            #expect(followed.spent <= witness.level.budget)
        }
    }

    /// 200 seeded reachable states: every exact hint is accepted by the kernel, following hints from a non-stuck state
    /// wins within the actions left, and no hint or explanation changes the play (200 cases of one).
    @Test(arguments: Array(0..<200))
    func seededReachableStatesGetAcceptedHints(group: Int) throws {
        let witnesses: [MushroomWeatherWitness] = try hintWitnesses()
        var random: SeededRandom = SeededRandom(seed: UInt64(2_495 + group))
        let witness: MushroomWeatherWitness = witnesses[random.int(0...99)]
        let certified: MushroomWeatherPlan = try certifiedPlan(witness)
        var play: MushroomWeatherPlay = try openingPlay(witness.level)
        let count: Int = random.int(0...4)
        for _ in 0..<count { _ = randomAction(&play, &random) }
        let label: String = "group \(group) level \(witness.number)"
        let before: MushroomWeatherPlay = play
        let fingerprint: String = play.fingerprint
        let hint: MushroomWeatherHint? = MushroomWeatherHints.hint(level: 3, play: play, certified: certified)
        _ = MushroomWeatherFailureExplanation(play: play)
        #expect(play == before && play.fingerprint == fingerprint, "\(label): changed")
        guard let hint else {
            Issue.record("\(label): no hint while playing")
            return
        }
        switch hint.kind {
        case .run:
            #expect(play.report.wins, "\(label): run hinted without a win")
            #expect(hint.text == MushroomWeatherHint.runText)
            var copy: MushroomWeatherPlay = play
            try copy.apply(.run, expecting: copy.fingerprint)
            #expect(copy.stage == .won, "\(label)")
        case .stuck:
            #expect(hint.action == nil)
            #expect(hint.text == MushroomWeatherHint.stuckText)
            print("MushroomWeatherHintsTests \(label): stuck with \(play.actionsLeft) actions left")
        case .pod, .vent, .moonlight:
            guard let action = hint.action else {
                Issue.record("\(label): no action")
                return
            }
            #expect(hint.kind == MushroomWeatherHint.kind(of: action), "\(label)")
            #expect(hint.text == expectedTexts(action, arrangement: play.arrangement)[2], "\(label)")
            var copy: MushroomWeatherPlay = play
            do {
                try copy.apply(action, expecting: copy.fingerprint)
            } catch {
                Issue.record("\(label): hinted \(action) refused: \(error)")
                return
            }
            let followed: (problems: [String], spent: Int) = followHints(copy, certified: certified, label: label)
            #expect(followed.problems.isEmpty, "\(followed.problems)")
            #expect(followed.spent + 1 <= before.actionsLeft, "\(label): spent \(followed.spent)")
        }
    }

    /// Off the certified path, the bounded search finds a winning plan exactly when an independent brute force within
    /// min(actions left, 2) actions does, of the same shortest length (10 groups of 3 states: a pod on a site the
    /// witness does not use, alone, on level 8g + 1; the witness's arrangement plus such a pod on level 10g + 10; the
    /// witness's actions but the last plus such a pod on level 10g + 5).
    @Test(arguments: Array(0..<10))
    func offPathStatesMatchBruteForce(group: Int) throws {
        let witnesses: [MushroomWeatherWitness] = try hintWitnesses()
        let cases: [(number: Int, kept: Int)] = [(group * 8 + 1, 0), (group * 10 + 10, 99), (group * 10 + 5, -1)]
        var exists: Int = 0
        for (number, kept) in cases {
            let witness: MushroomWeatherWitness = witnesses[number - 1]
            let certified: MushroomWeatherPlan = try certifiedPlan(witness)
            let changes: [MushroomWeatherAction] = witnessChanges(witness)
            var play: MushroomWeatherPlay = try openingPlay(witness.level)
            let used: Set<MushroomWeatherCell> = Set(certified.arrangement.placedPods)
            var wrong: MushroomWeatherCell? = nil
            for site in (witness.level.sites ?? []).reversed() where wrong == nil && !used.contains(site) {
                wrong = site
            }
            guard let wrong else {
                Issue.record("level \(number): every site is a certified pod cell")
                continue
            }
            let applied: Int = kept == 99 ? changes.count : (kept == -1 ? changes.count - 1 : 0)
            for position in 0..<applied {
                try play.apply(changes[position], expecting: play.fingerprint)
            }
            guard let free = MushroomWeatherHints.firstFreeSlot(play.arrangement.pods) else {
                print("MushroomWeatherHintsTests level \(number): no free slot for the extra pod")
                continue
            }
            try play.apply(.place(slot: free, cell: wrong), expecting: play.fingerprint)
            if play.report.wins { continue }
            let before: MushroomWeatherPlay = play
            let depth: Int = min(2, play.actionsLeft)
            let brute: Int? = bruteShortest(witness.level, arrangement: play.arrangement, depth: depth)
            let bounded: MushroomWeatherHintPlan? = MushroomWeatherHints.plan(play, certified: certified)
            var found: MushroomWeatherHintPlan? = bounded
            if bounded == nil {
                found = MushroomWeatherHints.plan(play, certified: certified, workBound: Int.max)
            }
            #expect(play == before, "level \(number): changed")
            #expect((bounded != nil) == (brute != nil), "level \(number): brute \(String(describing: brute))")
            #expect((found != nil) == (brute != nil), "level \(number): unbounded")
            #expect(found?.actions.count == brute, "level \(number)")
            if brute != nil { exists += 1 }
            if let actions = found?.actions {
                var copy: MushroomWeatherPlay = play
                for action in actions { try copy.apply(action, expecting: copy.fingerprint) }
                try copy.apply(.run, expecting: copy.fingerprint)
                #expect(copy.stage == .won, "level \(number): plan does not win")
            }
        }
        #expect(exists >= 1, "group \(group): no off-path state with a win in reach")
    }

    /// Stages: loading, paused, won and result after a win get no hint; failed and result after a failure get the
    /// failed advice; no action left gives the stuck text; the winning arrangement gives the run; the hint texts.
    @Test func stagesAndFixedTexts() throws {
        let witness: MushroomWeatherWitness = try hintWitnesses()[0]
        let certified: MushroomWeatherPlan = try certifiedPlan(witness)
        let level: MushroomWeatherLevel = witness.level
        let loading: MushroomWeatherPlay = MushroomWeatherPlay(level: level)
        #expect(MushroomWeatherHints.hint(level: 1, play: loading, certified: certified) == nil)
        #expect(MushroomWeatherHints.plan(loading, certified: certified) == nil)
        var tutorial: MushroomWeatherPlay = MushroomWeatherPlay(level: level)
        try tutorial.handle(.begin)
        if tutorial.stage == .tutorial {
            #expect(MushroomWeatherHints.hint(level: 1, play: tutorial, certified: certified) == nil)
        }
        var paused: MushroomWeatherPlay = try openingPlay(level)
        try paused.handle(.pause)
        #expect(MushroomWeatherHints.hint(level: 2, play: paused, certified: certified) == nil)
        var won: MushroomWeatherPlay = try openingPlay(level)
        for action in witnessChanges(witness) { try won.apply(action, expecting: won.fingerprint) }
        let runHint: MushroomWeatherHint? = MushroomWeatherHints.hint(level: 3, play: won, certified: certified)
        #expect(runHint?.kind == .run)
        #expect(runHint?.action == .run)
        #expect(runHint?.text == "Every colony stays in its band: run the weather")
        #expect(MushroomWeatherHints.plan(won, certified: certified)?.actions == [])
        try won.apply(.run, expecting: won.fingerprint)
        #expect(won.stage == .won)
        #expect(MushroomWeatherHints.hint(level: 1, play: won, certified: certified) == nil)
        #expect(MushroomWeatherFailureExplanation(play: won) == nil)
        try won.handle(.showResult)
        #expect(MushroomWeatherHints.hint(level: 1, play: won, certified: certified) == nil)
        var failed: MushroomWeatherPlay = try openingPlay(level)
        try failed.apply(.run, expecting: failed.fingerprint)
        #expect(failed.stage == .failed)
        let failedHint: MushroomWeatherHint? = MushroomWeatherHints.hint(level: 2, play: failed, certified: certified)
        #expect(failedHint?.kind == .stuck)
        #expect(failedHint?.action == nil)
        #expect(failedHint?.text == "Undo the last action or retry the level.")
        try failed.handle(.showResult)
        #expect(MushroomWeatherHints.hint(level: 1, play: failed, certified: certified)?.text
            == "Undo the last action or retry the level.")
        #expect(MushroomWeatherFailureExplanation(play: failed) != nil)
        var spent: MushroomWeatherPlay = try openingPlay(level)
        while spent.actionsLeft > 0 {
            let value: Int = spent.arrangement.moonlight == 0 ? 1 : 0
            try spent.apply(.moonlight(level: value), expecting: spent.fingerprint)
        }
        if !spent.report.wins {
            let stuck: MushroomWeatherHint? = MushroomWeatherHints.hint(level: 1, play: spent, certified: certified)
            #expect(stuck?.kind == .stuck)
            #expect(stuck?.action == nil)
            #expect(stuck?.text
                == "No way to win was found in the actions left: undo the last action or retry the level.")
            #expect(MushroomWeatherHints.plan(spent, certified: certified) == nil)
        }
        let cell: MushroomWeatherCell = MushroomWeatherCell(row: 7, column: 12)
        let other: MushroomWeatherCell = MushroomWeatherCell(row: 2, column: 3)
        let arrangement: MushroomWeatherArrangement = MushroomWeatherArrangement(pods: [other, nil],
                                                                                 ventsOpen: [true, false],
                                                                                 moonlight: 2)
        let put: MushroomWeatherAction = .place(slot: 1, cell: cell)
        let move: MushroomWeatherAction = .place(slot: 0, cell: cell)
        #expect(MushroomWeatherHint.actionText(level: 1, action: put, arrangement: arrangement)
            == "Change a spore pod")
        #expect(MushroomWeatherHint.actionText(level: 2, action: put, arrangement: arrangement)
            == "Use the site at row 7, column 12")
        #expect(MushroomWeatherHint.actionText(level: 3, action: put, arrangement: arrangement)
            == "Put pod 2 on the site at row 7, column 12")
        #expect(MushroomWeatherHint.actionText(level: 2, action: move, arrangement: arrangement)
            == "Use the site at row 7, column 12")
        #expect(MushroomWeatherHint.actionText(level: 3, action: move, arrangement: arrangement)
            == "Move pod 1 to the site at row 7, column 12")
        #expect(MushroomWeatherHint.actionText(level: 1, action: .remove(slot: 0), arrangement: arrangement)
            == "Change a spore pod")
        #expect(MushroomWeatherHint.actionText(level: 9, action: .remove(slot: 0), arrangement: arrangement)
            == "Take pod 1 away")
        #expect(MushroomWeatherHint.actionText(level: 1, action: .vent(index: 1, open: true),
                                               arrangement: arrangement) == "Change a vent")
        #expect(MushroomWeatherHint.actionText(level: 2, action: .vent(index: 1, open: true),
                                               arrangement: arrangement) == "Use vent 2")
        #expect(MushroomWeatherHint.actionText(level: 3, action: .vent(index: 1, open: true),
                                               arrangement: arrangement) == "Open vent 2")
        #expect(MushroomWeatherHint.actionText(level: 3, action: .vent(index: 0, open: false),
                                               arrangement: arrangement) == "Close vent 1")
        #expect(MushroomWeatherHint.actionText(level: 1, action: .moonlight(level: 3), arrangement: arrangement)
            == "Change the moonlight")
        #expect(MushroomWeatherHint.actionText(level: 2, action: .moonlight(level: 3), arrangement: arrangement)
            == "Make the moonlight brighter")
        #expect(MushroomWeatherHint.actionText(level: 2, action: .moonlight(level: 0), arrangement: arrangement)
            == "Make the moonlight dimmer")
        #expect(MushroomWeatherHint.actionText(level: 3, action: .moonlight(level: 0), arrangement: arrangement)
            == "Set the moonlight to level 0")
        #expect(MushroomWeatherHint.actionText(level: 0, action: .run, arrangement: arrangement) == nil)
        #expect(MushroomWeatherHints.workBound == 1_500)
    }

    /// The witness rule tolerates pods in other slots than the witness's and skips actions already done: with the
    /// witness's last placement made first into slot 0, the plan is the witness's other actions in order, placements
    /// into the first free slot, and following it then running wins.
    @Test func witnessRuleFollowsThePlayersSlots() throws {
        let witnesses: [MushroomWeatherWitness] = try hintWitnesses()
        var checked: Int = 0
        for witness in witnesses {
            let changes: [MushroomWeatherAction] = witnessChanges(witness)
            var placements: [MushroomWeatherCell] = []
            for action in changes {
                if case .place(_, let cell) = action { placements.append(cell) }
            }
            guard placements.count >= 2, let last = placements.last else { continue }
            let certified: MushroomWeatherPlan = try certifiedPlan(witness)
            var play: MushroomWeatherPlay = try openingPlay(witness.level)
            try play.apply(.place(slot: 0, cell: last), expecting: play.fingerprint)
            var expected: [MushroomWeatherAction] = []
            var slot: Int = 1
            for action in changes {
                if case .place(_, let cell) = action {
                    if cell == last { continue }
                    expected.append(.place(slot: slot, cell: cell))
                    slot += 1
                } else {
                    expected.append(action)
                }
            }
            let plan: MushroomWeatherHintPlan? = MushroomWeatherHints.plan(play, certified: certified)
            #expect(plan?.actions == expected, "level \(witness.number)")
            let followed: (problems: [String], spent: Int) = followHints(play, certified: certified,
                                                                         label: "level \(witness.number)")
            #expect(followed.problems.isEmpty, "\(followed.problems)")
            #expect(followed.spent == changes.count - 1, "level \(witness.number): spent \(followed.spent)")
            checked += 1
            if checked == 10 { break }
        }
        #expect(checked == 10)
    }

    /// Mold never ends a run on the certified levels' arrangements, so it is checked on damp copies of levels 1, 11, …
    /// 91 (every floor cell but the colonies' at 999 with no evaporation, the mold bound 1,000): a pod on the first
    /// site, then the run, fails, and the explanation names the true cell and cycle (at least 5 of the 10 by mold).
    @Test func unstableSentencesCountInTheSingularAndThePlural() {
        // T-R02G2005-004: never "the last 1 cycles" or "1 were needed".
        #expect(MushroomWeatherFailureExplanation.unstableSentence(colony: 0, run: 1, required: 6)
                    == "Colony 1 stayed in its band for only the last 1 cycle; 6 were needed.")
        #expect(MushroomWeatherFailureExplanation.unstableSentence(colony: 2, run: 4, required: 6)
                    == "Colony 3 stayed in its band for only the last 4 cycles; 6 were needed.")
        #expect(MushroomWeatherFailureExplanation.unstableSentence(colony: 1, run: 0, required: 1)
                    == "Colony 2 stayed in its band for only the last 0 cycles; 1 was needed.")
        #expect(MushroomWeatherFailureExplanation.unstableSentence(colony: 4, run: 1, required: 1)
                    == "Colony 5 stayed in its band for only the last 1 cycle; 1 was needed.")
    }

    @Test func moldFailuresAreExplainedTruly() throws {
        let witnesses: [MushroomWeatherWitness] = try hintWitnesses()
        var molds: Int = 0
        for group in 0..<10 {
            let source: MushroomWeatherLevel = witnesses[group * 10].level
            let colonies: Set<MushroomWeatherCell> = source.colonyCells
            var humidity: [Int] = source.humidity
            var rates: [Int] = source.rates
            for index in humidity.indices where source.floorMask[index] && !colonies.contains(source.cell(at: index)) {
                humidity[index] = 999
                rates[index] = 0
            }
            let level: MushroomWeatherLevel = try MushroomWeatherLevel(
                id: source.id, seed: source.seed, difficulty: source.difficulty, rows: source.rows,
                columns: source.columns, blocked: source.blocked, humidity: humidity, diffusion: source.diffusion,
                rates: rates, vents: source.vents, podRules: source.podRules, colonies: source.colonies,
                moldBound: 1_000, length: source.length, required: source.required, start: source.start,
                budget: source.budget, tutorial: false, sites: source.sites)
            guard let site = level.sites?.first else { continue }
            var play: MushroomWeatherPlay = try openingPlay(level)
            try play.apply(.place(slot: 0, cell: site), expecting: play.fingerprint)
            try play.apply(.run, expecting: play.fingerprint)
            guard play.stage == .failed else {
                Issue.record("damp level \(group * 10 + 1): not failed")
                continue
            }
            let truth: MushroomWeatherFailure? = MushroomWeatherForest.report(level, arrangement: play.arrangement)
                .failure
            let explanation: MushroomWeatherFailureExplanation? = MushroomWeatherFailureExplanation(play: play)
            #expect(explanation?.failure == truth)
            if let truth {
                #expect(explanation?.text == expectedExplanation(truth, level: level))
                if case .mold = truth { molds += 1 }
            }
        }
        #expect(molds >= 5, "\(molds) mold failures of 10")
        print("MushroomWeatherHintsTests damp levels: \(molds) mold failures of 10")
    }

    /// 500 seeded failures are explained with their true colony, cell, cycle and run lengths (25 groups of 20).
    @Test(arguments: Array(0..<25))
    func seededFailuresAreExplainedTruly(group: Int) throws {
        let witnesses: [MushroomWeatherWitness] = try hintWitnesses()
        var random: SeededRandom = SeededRandom(seed: UInt64(2_495 + 100 + group))
        var explained: Int = 0
        var kinds: [String: Int] = [:]
        var attempts: Int = 0
        while explained < 20 && attempts < 200 {
            attempts += 1
            let witness: MushroomWeatherWitness = witnesses[random.int(0...99)]
            var play: MushroomWeatherPlay = try openingPlay(witness.level)
            let count: Int = random.int(0...4)
            for _ in 0..<count { _ = randomAction(&play, &random) }
            if play.canUndo && random.int(0...3) == 0 {
                try play.undo()
                if random.int(0...1) == 0 { try play.redo() }
            }
            try play.apply(.run, expecting: play.fingerprint)
            guard play.stage == .failed else { continue }
            if random.int(0...1) == 0 {
                try play.undo()
                try play.redo()
            }
            if random.int(0...2) == 0 { try play.handle(.showResult) }
            let truth: MushroomWeatherFailure? = MushroomWeatherForest.report(witness.level,
                                                                              arrangement: play.arrangement).failure
            let before: MushroomWeatherPlay = play
            guard let explanation = MushroomWeatherFailureExplanation(play: play) else {
                Issue.record("group \(group): no explanation for \(String(describing: play.failure))")
                continue
            }
            #expect(play == before)
            #expect(explanation.failure == truth)
            #expect(explanation.failure == play.failure)
            if let truth {
                #expect(explanation.text == expectedExplanation(truth, level: witness.level))
                kinds[truth.code, default: 0] += 1
            }
            explained += 1
        }
        #expect(explained == 20, "group \(group): \(explained) failures in \(attempts) attempts")
        print("MushroomWeatherHintsTests group \(group) failures: \(kinds)")
    }
}
