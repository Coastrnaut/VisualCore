// MicroscopicAuroraHintsTests — feature 485 (R02-G19-05) T-R02G1905-002 (FR-R02G1905-002, 003; SC-R02G1905-002, 003;
// clarifications Q1, Q5). Hints and failure explanations of Microscopic Aurora. The 100 certified levels and their
// certified wells are read from the stored witnesses in docs/games/microscopic-aurora/levels/ with the plain decoder
// (as MicroscopicAuroraCatalogTests reads them). In 25 groups of 4 levels: the hint plan from the opening is the
// witness's placements; the level 1, 2 and 3 texts of the first hint match texts written here; following exact
// (level 3) hints, re-asked after every action, then the hinted play wins spending exactly the witness's placements,
// within the budget, and no hint changes the play. 200 seeded reachable states (seed 2_485 plus the case, 200 cases of
// one: 0 … 3 random accepted placements and removals from a random certified opening) get a hint the kernel accepts
// (the play only when the wells already win), following hints from a non-stuck state wins within the actions left, and
// no hint or explanation changes the play (fingerprint and value). Off the certified path (one well that is not a
// certified well alone in slot 1 of levels 1, 9, … 73, or on a free site after the certified wells on levels 10, 20,
// … 100; 10 groups of 2), an independent brute force over every set reachable within min(actions left, 2) actions
// decides whether a win exists and its shortest length; the bounded plan (and, were it to give up, the unbounded one)
// exists exactly then, has that length, wins through the kernel and does not change the play.
// Hand plays check the stages (loading, paused, won and result after a win: no hint; failed and result after a
// failure: the failed advice), the stuck text with no action left and the hint texts. 500 seeded failures (seed 2_485
// plus 100 plus the group, 25 groups of 20: random accepted actions, some undone and redone, then the play, some shown
// as a result) are explained with the true swimmer, tick, group, counts or cell: the failure equals the one judged here
// from the play's wells and the text equals the one written here. Each test prints its duration (no wall-clock
// assertion). Deterministic, explicit types, plain loops.
import Foundation
import Testing
import VisualCoreSimulation
@testable import MicroscopicAuroraCore

/// The repository's witness directory, found from this file (five levels up: CoreTests, MicroscopicAurora, the
/// package, Packages).
private let hintWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/microscopic-aurora/levels", isDirectory: true)

/// The 100 stored witnesses in manifest order, read once per test process with the plain decoder.
private let hintWitnessesResult: Result<[MicroscopicAuroraWitness], any Error> = Result {
    var result: [MicroscopicAuroraWitness] = []
    for entry in MicroscopicAuroraManifest.entries {
        let name: String = String(MicroscopicAuroraGenerator.levelID(entry.number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: hintWitnessDirectory.appendingPathComponent(name))
        result.append(try JSONDecoder().decode(MicroscopicAuroraWitness.self, from: data))
    }
    return result
}

/// The stored witnesses.
private func hintWitnesses() throws -> [MicroscopicAuroraWitness] { try hintWitnessesResult.get() }

/// The placements of a witness (its actions without the closing play).
private func witnessPlacements(_ witness: MicroscopicAuroraWitness) -> [MicroscopicAuroraAction] {
    var result: [MicroscopicAuroraAction] = []
    for action in witness.actions where action != .play { result.append(action) }
    return result
}

/// The certified wells of a witness: its placed wells in placement order.
private func certifiedWells(_ witness: MicroscopicAuroraWitness) -> [MicroscopicAuroraWell] {
    var result: [MicroscopicAuroraWell] = []
    for action in witness.actions {
        if case .place(_, let well) = action { result.append(well) }
    }
    return result
}

/// The opening play of `level`: begun, past its tutorial.
private func openingPlay(_ level: MicroscopicAuroraLevel) throws -> MicroscopicAuroraPlay {
    try MicroscopicAuroraExperienceCore.freshPlay(of: level)
}

/// Prints the seconds since `start` for `name` (evidence of the test's duration; never asserted).
private func report(_ name: String, since start: ContinuousClock.Instant) {
    let elapsed: Duration = ContinuousClock.now - start
    print("MicroscopicAuroraHintsTests \(name): \(elapsed)")
}

/// The texts of a placement or removal hint at levels 1, 2 and 3, written here independently of the hint engine.
private func expectedTexts(_ action: MicroscopicAuroraAction) -> [String] {
    switch action {
    case .place(let slot, let well):
        let sense: String = well.sense == .clockwise ? "clockwise" : "counterclockwise"
        let cell: String = "row \(well.cell.row), column \(well.cell.column)"
        return ["Use the site at \(cell) next", "Place a \(sense) well at the site at \(cell)",
                "Place well \(slot + 1) at \(cell) with strength \(well.strength), turning \(sense)"]
    case .remove(let slot):
        return ["Take well \(slot + 1) away", "Take well \(slot + 1) away", "Take well \(slot + 1) away"]
    case .play:
        return []
    }
}

/// The explanation of `failure` on `level`, written here independently of the explanation.
private func expectedExplanation(_ failure: MicroscopicAuroraFailure, level: MicroscopicAuroraLevel) -> String {
    let sentence: String
    switch failure {
    case .exit(let swimmer, let tick):
        sentence = "Swimmer \(swimmer + 1) left the dish at tick \(tick)."
    case .coherence(let tick, let group):
        sentence = "The swarm split at tick \(tick): its largest group had \(group) swimmers, fewer than the "
            + "\(level.coherence) needed."
    case .coverage(let lit, let needed):
        sentence = "Only \(lit) stencil cells were lit; \(needed) were needed."
    case .connectedness(let cell):
        sentence = "The cell at row \(cell.row), column \(cell.column) is lit but not joined to the pattern."
    }
    return sentence + " Undo the last action or retry the level."
}

/// Follows exact (level 3) hints from `start` until the play ends; the problems found (empty: won, every hinted action
/// accepted, the play unchanged by every hint) and the actions spent following them.
private func followHints(_ start: MicroscopicAuroraPlay, certified: [MicroscopicAuroraWell]?,
                         label: String) -> (problems: [String], spent: Int) {
    var play: MicroscopicAuroraPlay = start
    let spentBefore: Int = play.actionsSpent
    for _ in 0..<6 {
        if play.stage == .won { return ([], play.actionsSpent - spentBefore) }
        let before: MicroscopicAuroraPlay = play
        let fingerprint: String = play.fingerprint
        guard let hint = MicroscopicAuroraHints.hint(level: 3, play: play, certified: certified) else {
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

/// A random placement or removal the kernel accepts from `play` (a removal of a random occupied slot about one time
/// in four, else a placement of a random well on a random site into a random slot), applied; false after 30 refused
/// tries.
private func randomAction(_ play: inout MicroscopicAuroraPlay, _ random: inout SeededRandom) -> Bool {
    let sites: [MicroscopicAuroraCell] = play.level.sites ?? []
    guard !sites.isEmpty else { return false }
    for _ in 0..<30 {
        let action: MicroscopicAuroraAction
        if !play.placedWells.isEmpty && random.int(0...3) == 0 {
            action = .remove(slot: random.int(0...2))
        } else {
            let cell: MicroscopicAuroraCell = sites[random.int(0...(sites.count - 1))]
            let sense: MicroscopicAuroraSense = random.int(0...1) == 0 ? .clockwise : .counterclockwise
            let well: MicroscopicAuroraWell = MicroscopicAuroraWell(cell: cell, strength: random.int(1...4),
                                                                    sense: sense)
            action = .place(slot: random.int(0...2), well: well)
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

/// The shortest number of actions within `depth` that reaches a winning set of wells from `wells` on `level`, by a
/// brute force written here over sets of wells (a report depends only on the set; a slot assignment only bounds the
/// set at three wells): from a set, an action takes one well away, replaces one well by another well on a site no
/// remaining well holds, or adds a well on a free site while fewer than three are placed. Every set is judged at most
/// once, without a bound; nil when none wins.
private func bruteShortest(_ level: MicroscopicAuroraLevel, wells: [MicroscopicAuroraWell?], depth: Int) -> Int? {
    let start: Set<MicroscopicAuroraWell> = Set(wells.compactMap { $0 })
    if MicroscopicAuroraDish.report(level, wells: Array(start)).wins { return 0 }
    var all: [MicroscopicAuroraWell] = []
    for site in level.sites ?? [] {
        for strength in 1...4 {
            all.append(MicroscopicAuroraWell(cell: site, strength: strength, sense: .clockwise))
            all.append(MicroscopicAuroraWell(cell: site, strength: strength, sense: .counterclockwise))
        }
    }
    var visited: Set<Set<MicroscopicAuroraWell>> = [start]
    var frontier: [Set<MicroscopicAuroraWell>] = [start]
    var step: Int = 0
    while step < depth {
        step += 1
        var next: [Set<MicroscopicAuroraWell>] = []
        for set in frontier {
            var successors: [Set<MicroscopicAuroraWell>] = []
            for well in set {
                var without: Set<MicroscopicAuroraWell> = set
                without.remove(well)
                successors.append(without)
                for other in all where other != well {
                    var held: Bool = false
                    for kept in without where kept.cell == other.cell { held = true }
                    if !held { successors.append(without.union([other])) }
                }
            }
            if set.count < 3 {
                for other in all {
                    var held: Bool = false
                    for kept in set where kept.cell == other.cell { held = true }
                    if !held { successors.append(set.union([other])) }
                }
            }
            for successor in successors where !visited.contains(successor) {
                visited.insert(successor)
                if MicroscopicAuroraDish.report(level, wells: Array(successor)).wins { return step }
                next.append(successor)
            }
        }
        frontier = next
    }
    return nil
}

@Suite struct MicroscopicAuroraHintsTests {
    /// Exact hints from the opening replay the witness and, then the play, win every certified level within its budget
    /// (25 groups of 4 levels).
    @Test(arguments: Array(0..<25))
    func followingHintsWinsEveryCertifiedLevel(group: Int) throws {
        let start: ContinuousClock.Instant = .now
        let witnesses: [MicroscopicAuroraWitness] = try hintWitnesses()
        for index in (group * 4)..<(group * 4 + 4) {
            let witness: MicroscopicAuroraWitness = witnesses[index]
            let certified: [MicroscopicAuroraWell] = certifiedWells(witness)
            let placements: [MicroscopicAuroraAction] = witnessPlacements(witness)
            let opening: MicroscopicAuroraPlay = try openingPlay(witness.level)
            let plan: MicroscopicAuroraHintPlan? = MicroscopicAuroraHints.plan(opening, certified: certified)
            #expect(plan?.actions == placements, "level \(witness.number): opening plan")
            for level in 1...3 {
                let hint: MicroscopicAuroraHint? = MicroscopicAuroraHints.hint(level: level, play: opening,
                                                                               certified: certified)
                #expect(hint?.kind == .place, "level \(witness.number)")
                #expect(hint?.level == level)
                if let first = placements.first {
                    #expect(hint?.action == first, "level \(witness.number)")
                    #expect(hint?.text == expectedTexts(first)[level - 1], "level \(witness.number)")
                }
            }
            let followed: (problems: [String], spent: Int) = followHints(opening, certified: certified,
                                                                         label: "level \(witness.number)")
            #expect(followed.problems.isEmpty, "\(followed.problems)")
            #expect(followed.spent == placements.count, "level \(witness.number): spent \(followed.spent)")
            #expect(followed.spent <= witness.level.budget)
        }
        report("followingHintsWinsEveryCertifiedLevel(\(group))", since: start)
    }

    /// 200 seeded reachable states: every exact hint is accepted by the kernel, following hints from a non-stuck state
    /// wins within the actions left, and no hint or explanation changes the play (200 cases of one).
    @Test(arguments: Array(0..<200))
    func seededReachableStatesGetAcceptedHints(group: Int) throws {
        let start: ContinuousClock.Instant = .now
        let witnesses: [MicroscopicAuroraWitness] = try hintWitnesses()
        var random: SeededRandom = SeededRandom(seed: UInt64(2_485 + group))
        var stuck: Int = 0
        for sample in 0..<1 {
            let witness: MicroscopicAuroraWitness = witnesses[random.int(0...99)]
            let certified: [MicroscopicAuroraWell] = certifiedWells(witness)
            var play: MicroscopicAuroraPlay = try openingPlay(witness.level)
            let count: Int = random.int(0...3)
            for _ in 0..<count { _ = randomAction(&play, &random) }
            let label: String = "group \(group) sample \(sample) level \(witness.number)"
            let before: MicroscopicAuroraPlay = play
            let fingerprint: String = play.fingerprint
            let hint: MicroscopicAuroraHint? = MicroscopicAuroraHints.hint(level: 3, play: play, certified: certified)
            _ = MicroscopicAuroraFailureExplanation(play: play)
            #expect(play == before && play.fingerprint == fingerprint, "\(label): changed")
            guard let hint else {
                Issue.record("\(label): no hint while playing")
                continue
            }
            switch hint.kind {
            case .play:
                #expect(play.report.wins, "\(label): play hinted without a win")
                #expect(hint.text == MicroscopicAuroraHint.playText)
                var copy: MicroscopicAuroraPlay = play
                try copy.apply(.play, expecting: copy.fingerprint)
                #expect(copy.stage == .won, "\(label)")
            case .stuck:
                #expect(hint.action == nil)
                #expect(hint.text == MicroscopicAuroraHint.stuckText)
                stuck += 1
            case .place, .remove:
                guard let action = hint.action else {
                    Issue.record("\(label): no action")
                    continue
                }
                #expect(hint.text == expectedTexts(action)[2], "\(label)")
                var copy: MicroscopicAuroraPlay = play
                do {
                    try copy.apply(action, expecting: copy.fingerprint)
                } catch {
                    Issue.record("\(label): hinted \(action) refused: \(error)")
                    continue
                }
                let followed: (problems: [String], spent: Int) = followHints(copy, certified: certified, label: label)
                #expect(followed.problems.isEmpty, "\(followed.problems)")
                #expect(followed.spent + 1 <= min(2, before.actionsLeft), "\(label): spent \(followed.spent)")
            }
        }
        print("MicroscopicAuroraHintsTests group \(group): \(stuck) stuck of 1")
        report("seededReachableStatesGetAcceptedHints(\(group))", since: start)
    }

    /// Off the certified path, the bounded search finds a winning plan exactly when an independent brute force within
    /// min(actions left, 2) actions does, of the same shortest length (10 groups of 2 states: one wrong well alone on
    /// level 8g + 1, and the certified wells plus one wrong well on level 10g + 10).
    @Test(arguments: Array(0..<10))
    func offPathStatesMatchBruteForce(group: Int) throws {
        let start: ContinuousClock.Instant = .now
        let witnesses: [MicroscopicAuroraWitness] = try hintWitnesses()
        for (number, extra) in [(group * 8 + 1, false), (group * 10 + 10, true)] {
            let witness: MicroscopicAuroraWitness = witnesses[number - 1]
            let certified: [MicroscopicAuroraWell] = certifiedWells(witness)
            var play: MicroscopicAuroraPlay = try openingPlay(witness.level)
            let sites: [MicroscopicAuroraCell] = witness.level.sites ?? []
            var wrong: MicroscopicAuroraWell? = nil
            for site in sites.reversed() where wrong == nil {
                var held: Bool = false
                for well in certified where well.cell == site { held = true }
                if extra && held { continue }
                for strength in 1...4 where wrong == nil {
                    let well: MicroscopicAuroraWell = MicroscopicAuroraWell(cell: site, strength: strength,
                                                                            sense: .clockwise)
                    if !certified.contains(well) { wrong = well }
                }
            }
            guard let wrong else {
                Issue.record("level \(number): no wrong well")
                continue
            }
            if extra {
                for action in witnessPlacements(witness) { try play.apply(action, expecting: play.fingerprint) }
                try play.apply(.place(slot: certified.count, well: wrong), expecting: play.fingerprint)
            } else {
                try play.apply(.place(slot: 0, well: wrong), expecting: play.fingerprint)
            }
            if play.report.wins { continue }
            let before: MicroscopicAuroraPlay = play
            let depth: Int = min(2, play.actionsLeft)
            let brute: Int? = bruteShortest(witness.level, wells: play.wells, depth: depth)
            let bounded: MicroscopicAuroraHintPlan? = MicroscopicAuroraHints.plan(play, certified: certified)
            var found: MicroscopicAuroraHintPlan? = bounded
            if bounded == nil {
                found = MicroscopicAuroraHints.plan(play, certified: certified, workBound: Int.max)
            }
            #expect(play == before, "level \(number): changed")
            #expect((bounded != nil) == (brute != nil), "level \(number): brute \(String(describing: brute))")
            #expect((found != nil) == (brute != nil), "level \(number): unbounded")
            #expect(found?.actions.count == brute, "level \(number)")
            if let actions = found?.actions {
                var copy: MicroscopicAuroraPlay = play
                for action in actions { try copy.apply(action, expecting: copy.fingerprint) }
                try copy.apply(.play, expecting: copy.fingerprint)
                #expect(copy.stage == .won, "level \(number): plan does not win")
            }
        }
        report("offPathStatesMatchBruteForce(\(group))", since: start)
    }

    /// Stages: loading, paused, won and result after a win get no hint; failed and result after a failure get the
    /// failed advice; no action left gives the stuck text; the winning wells give the play.
    @Test func stagesAndFixedTexts() throws {
        let start: ContinuousClock.Instant = .now
        let witness: MicroscopicAuroraWitness = try hintWitnesses()[0]
        let certified: [MicroscopicAuroraWell] = certifiedWells(witness)
        let level: MicroscopicAuroraLevel = witness.level
        let loading: MicroscopicAuroraPlay = MicroscopicAuroraPlay(level: level)
        #expect(MicroscopicAuroraHints.hint(level: 1, play: loading, certified: certified) == nil)
        #expect(MicroscopicAuroraHints.plan(loading, certified: certified) == nil)
        var paused: MicroscopicAuroraPlay = try openingPlay(level)
        try paused.handle(.pause)
        #expect(MicroscopicAuroraHints.hint(level: 2, play: paused, certified: certified) == nil)
        var won: MicroscopicAuroraPlay = try openingPlay(level)
        for action in witnessPlacements(witness) { try won.apply(action, expecting: won.fingerprint) }
        let playHint: MicroscopicAuroraHint? = MicroscopicAuroraHints.hint(level: 3, play: won, certified: certified)
        #expect(playHint?.kind == .play)
        #expect(playHint?.action == .play)
        #expect(playHint?.text == "The trails already cover the stencil as one pattern: play the swim")
        #expect(MicroscopicAuroraHints.plan(won, certified: certified)?.actions == [])
        try won.apply(.play, expecting: won.fingerprint)
        #expect(won.stage == .won)
        #expect(MicroscopicAuroraHints.hint(level: 1, play: won, certified: certified) == nil)
        #expect(MicroscopicAuroraFailureExplanation(play: won) == nil)
        try won.handle(.showResult)
        #expect(MicroscopicAuroraHints.hint(level: 1, play: won, certified: certified) == nil)
        var failed: MicroscopicAuroraPlay = try openingPlay(level)
        try failed.apply(.play, expecting: failed.fingerprint)
        #expect(failed.stage == .failed)
        let failedHint: MicroscopicAuroraHint? = MicroscopicAuroraHints.hint(level: 2, play: failed,
                                                                             certified: certified)
        #expect(failedHint?.kind == .stuck)
        #expect(failedHint?.action == nil)
        #expect(failedHint?.text == "Undo the last action or retry the level.")
        try failed.handle(.showResult)
        #expect(MicroscopicAuroraHints.hint(level: 1, play: failed, certified: certified)?.text
            == "Undo the last action or retry the level.")
        #expect(MicroscopicAuroraFailureExplanation(play: failed) != nil)
        var spent: MicroscopicAuroraPlay = try openingPlay(level)
        let sites: [MicroscopicAuroraCell] = level.sites ?? []
        var toggle: Int = 0
        while spent.actionsLeft > 0 {
            let well: MicroscopicAuroraWell = MicroscopicAuroraWell(cell: sites[toggle % sites.count], strength: 1,
                                                                    sense: .clockwise)
            try spent.apply(.place(slot: 0, well: well), expecting: spent.fingerprint)
            toggle += 1
        }
        if !spent.report.wins {
            let stuck: MicroscopicAuroraHint? = MicroscopicAuroraHints.hint(level: 1, play: spent,
                                                                            certified: certified)
            #expect(stuck?.kind == .stuck)
            #expect(stuck?.text
                == "No way to win was found in the actions left: undo the last action or retry the level.")
            #expect(MicroscopicAuroraHints.plan(spent, certified: certified) == nil)
        }
        let cell: MicroscopicAuroraCell = MicroscopicAuroraCell(row: 7, column: 12)
        let ccw: MicroscopicAuroraAction = .place(slot: 1, well: MicroscopicAuroraWell(cell: cell, strength: 3,
                                                                                       sense: .counterclockwise))
        #expect(MicroscopicAuroraHint.actionText(level: 1, action: ccw) == "Use the site at row 7, column 12 next")
        #expect(MicroscopicAuroraHint.actionText(level: 2, action: ccw)
            == "Place a counterclockwise well at the site at row 7, column 12")
        #expect(MicroscopicAuroraHint.actionText(level: 3, action: ccw)
            == "Place well 2 at row 7, column 12 with strength 3, turning counterclockwise")
        #expect(MicroscopicAuroraHint.actionText(level: 9, action: .remove(slot: 2)) == "Take well 3 away")
        #expect(MicroscopicAuroraHint.actionText(level: 1, action: .play) == nil)
        #expect(MicroscopicAuroraHints.workBound == 1_200)
        report("stagesAndFixedTexts", since: start)
    }

    /// 500 seeded failures are explained with their true swimmer, tick, group, counts or cell (25 groups of 20).
    @Test(arguments: Array(0..<25))
    func seededFailuresAreExplainedTruly(group: Int) throws {
        let start: ContinuousClock.Instant = .now
        let witnesses: [MicroscopicAuroraWitness] = try hintWitnesses()
        var random: SeededRandom = SeededRandom(seed: UInt64(2_485 + 100 + group))
        var explained: Int = 0
        var kinds: [String: Int] = [:]
        var attempts: Int = 0
        while explained < 20 && attempts < 200 {
            attempts += 1
            let witness: MicroscopicAuroraWitness = witnesses[random.int(0...99)]
            var play: MicroscopicAuroraPlay = try openingPlay(witness.level)
            let count: Int = random.int(0...3)
            for _ in 0..<count { _ = randomAction(&play, &random) }
            if play.canUndo && random.int(0...3) == 0 {
                try play.undo()
                if random.int(0...1) == 0 { try play.redo() }
            }
            try play.apply(.play, expecting: play.fingerprint)
            guard play.stage == .failed else { continue }
            if random.int(0...1) == 0 {
                try play.undo()
                try play.redo()
            }
            if random.int(0...2) == 0 { try play.handle(.showResult) }
            let truth: MicroscopicAuroraFailure? = MicroscopicAuroraDish.report(witness.level,
                                                                                wells: play.placedWells).failure
            let before: MicroscopicAuroraPlay = play
            guard let explanation = MicroscopicAuroraFailureExplanation(play: play) else {
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
        print("MicroscopicAuroraHintsTests group \(group) failures: \(kinds)")
        report("seededFailuresAreExplainedTruly(\(group))", since: start)
    }
}
