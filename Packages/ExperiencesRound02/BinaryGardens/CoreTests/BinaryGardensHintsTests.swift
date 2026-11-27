// BinaryGardensHintsTests — feature 505 (R02-G21-05) T-R02G2105-002 (FR-R02G2105-002, 003, 009; SC-R02G2105-002, 003;
// clarifications Q1, Q5; research R1 … R3). Hints and failure explanations of Binary Gardens. The 100 certified levels
// and their certified plans come from `BinaryGardensExperienceCore.generated(number:)`, read once per test process in
// four quarters of 25 levels (each quarter a lazily initialised global, so concurrent tests share one generation).
//
// Per quarter: the hint plan from every opening is the certified witness; the level 1, 2 and 3 texts of the first hint
// match texts written here; following exact (level 3) hints, re-asked after every action, then the hinted run wins
// spending exactly the witness's actions within the budget, and no hint changes the play. 200 seeded reachable states
// (seed 2_505 plus the group, 8 × 25: 0 … 4 random legal moves from a random certified opening, sometimes one undone)
// get a hint the kernel accepts (the run only when the arrangement already wins; stuck only when an independent brute
// force finds no win within min(actions left, 2)), the hint is the plan's first action and the plan then the run wins
// within the actions left, and no hint changes the play. 500 seeded failures (seed 2_505 + 100 plus the quarter,
// 4 × 125: random legal moves, some undone and redone, then the run, some shown as a result; every fifth failure aimed
// at one cause in turn by a one-move change of the opening or of the certified arrangement) cover all five causes in
// every quarter and are explained with their true world, tick, window and totals: the failure equals the one judged
// from the play's arrangement, its values equal the report's and the level's, and the text equals the one written here.
// Off the certified path (an opening, the certified arrangement or the witness but its last action, each followed by a
// move to a value neither the start's nor the certified one), an independent brute force over every arrangement
// reachable within min(actions left, 2) decides whether a win exists and its shortest length; the plan exists exactly
// then, has that length, wins through the kernel and does not change the play; from the certified arrangement plus one
// off move a plan always exists. One move off each certified arrangement of levels 51 … 75, the search equals a
// reference search on the puzzle contract (same sequence, same work) and a work bound below the arrangements it judges
// returns nil. Hand cases check the stages, the stuck text with no action left, the hint texts and every failure
// wording (E = 0, w = 0 and the singulars). No clock; deterministic, explicit types, plain loops (CI type-check rule).
import Foundation
import Testing
import VisualCoreSimulation
@testable import BinaryGardensCore

/// The certified levels of quarter `quarter` (0 … 3): manifest numbers 25 · quarter + 1 … 25 · quarter + 25.
private func makeHintQuarter(_ quarter: Int) -> Result<[BinaryGardensGenerated], any Error> {
    Result {
        var result: [BinaryGardensGenerated] = []
        for number in (quarter * 25 + 1)...(quarter * 25 + 25) {
            result.append(try BinaryGardensExperienceCore.generated(number: number))
        }
        return result
    }
}

/// Quarter 0, generated once per process.
private let hintQuarter0: Result<[BinaryGardensGenerated], any Error> = makeHintQuarter(0)
/// Quarter 1, generated once per process.
private let hintQuarter1: Result<[BinaryGardensGenerated], any Error> = makeHintQuarter(1)
/// Quarter 2, generated once per process.
private let hintQuarter2: Result<[BinaryGardensGenerated], any Error> = makeHintQuarter(2)
/// Quarter 3, generated once per process.
private let hintQuarter3: Result<[BinaryGardensGenerated], any Error> = makeHintQuarter(3)

/// The certified levels of `quarter` (0 … 3).
private func hintQuarter(_ quarter: Int) throws -> [BinaryGardensGenerated] {
    switch quarter {
    case 0: return try hintQuarter0.get()
    case 1: return try hintQuarter1.get()
    case 2: return try hintQuarter2.get()
    default: return try hintQuarter3.get()
    }
}

/// The opening play of `level`: begun, past its tutorial.
private func hintOpening(_ level: BinaryGardensLevel) throws -> BinaryGardensPlay {
    var play: BinaryGardensPlay = BinaryGardensPlay(level: level)
    try play.handle(.begin)
    if play.stage == .tutorial { try play.handle(.dismissTutorial) }
    return play
}

/// The texts of a ring, phase, luminosity or tilt hint at levels 1, 2 and 3 on `level` from `arrangement`, written
/// here independently of the hint engine.
private func expectedHintTexts(_ action: BinaryGardensAction, level: BinaryGardensLevel,
                               arrangement: BinaryGardensArrangement) -> [String] {
    switch action {
    case .ring(let star, let index):
        let way: String = index > arrangement.rings[star] ? "outward" : "inward"
        return ["Move a star to another ring", "Move star \(star + 1) \(way)",
                "Move star \(star + 1) to ring \(index + 1) (\(level.ringRadii[index]) units)"]
    case .phase(let star, let step):
        var ahead: Int = (step - arrangement.phases[star]) % 48
        if ahead < 0 { ahead += 48 }
        let way: String = ahead >= 1 && ahead <= 24 ? "forward" : "back"
        return ["Shift a star's phase", "Shift star \(star + 1)'s phase \(way)",
                "Shift star \(star + 1) to phase \(step)"]
    case .luminosity(let star, let index):
        let way: String = index > arrangement.luminosities[star] ? "brighter" : "dimmer"
        return ["Change a star's brightness", "Make star \(star + 1) \(way)",
                "Set star \(star + 1)'s luminosity to \(level.luminosityLevels[index])"]
    case .tilt(let step):
        let way: String = step > arrangement.tilt ? "more" : "less"
        return ["Tilt the orbit plane", "Tilt the orbit plane \(way)",
                "Set the tilt to \(step) of \(level.maxTilt) steps"]
    case .run:
        return []
    }
}

/// A walk tick in words, written here: "tick 17" or "tick 50 (tick 2 of the next cycle)".
private func expectedTickWords(_ tick: Int) -> String {
    tick > 48 ? "tick \(tick) (tick \(tick - 48) of the next cycle)" : "tick \(tick)"
}

/// "1 tick" or "n ticks", written here.
private func expectedTicks(_ count: Int) -> String {
    count == 1 ? "1 tick" : "\(count) ticks"
}

/// The explanation of `failure` with lethal tolerance `tolerance`, written here independently of the explanation.
private func expectedExplanation(_ failure: BinaryGardensFailure, tolerance: Int) -> String {
    let sentence: String
    switch failure {
    case .frozen(let world, let tick):
        let rest: String = tolerance == 0 ? "fell below its lethal floor."
            : "stayed below its lethal floor for more than \(expectedTicks(tolerance)) in a row."
        sentence = "World \(world + 1) froze at \(expectedTickWords(tick)): its light " + rest
    case .scorched(let world, let tick):
        let rest: String = tolerance == 0 ? "rose above its lethal ceiling."
            : "stayed above its lethal ceiling for more than \(expectedTicks(tolerance)) in a row."
        sentence = "World \(world + 1) scorched at \(expectedTickWords(tick)): its light " + rest
    case .unstable(let world, let window, let required):
        let needed: String = required == 1 ? "1 was needed." : "\(BinaryGardensLevel.grouped(required)) were needed."
        if window == 0 {
            sentence = "World \(world + 1) never had comfortable light; " + needed
        } else {
            sentence = "World \(world + 1) kept comfortable light for only \(expectedTicks(window)) in a row; " + needed
        }
    case .wilted(let world, let integral, let low, let high):
        sentence = "World \(world + 1) wilted: its light over the cycle totalled "
            + "\(BinaryGardensLevel.grouped(integral)), below its bloom band \(BinaryGardensLevel.grouped(low)) … "
            + "\(BinaryGardensLevel.grouped(high))."
    case .bleached(let world, let integral, let low, let high):
        sentence = "World \(world + 1) bleached: its light over the cycle totalled "
            + "\(BinaryGardensLevel.grouped(integral)), above its bloom band \(BinaryGardensLevel.grouped(low)) … "
            + "\(BinaryGardensLevel.grouped(high))."
    }
    return sentence + " Undo the last action or retry the level."
}

/// The legal moves of `play` (the puzzle contract's, in its order).
private func legalMoves(_ play: BinaryGardensPlay) -> [BinaryGardensAction] {
    let position: BinaryGardensPuzzle.Position =
        BinaryGardensPuzzle.Position(arrangement: play.arrangement, actionsSpent: play.actionsSpent)
    return BinaryGardensPuzzle(level: play.level).moves(in: position)
}

/// Applies a random legal move to `play`; false when none is legal.
private func applyRandomMove(_ play: inout BinaryGardensPlay, _ random: inout SeededRandom) throws -> Bool {
    let moves: [BinaryGardensAction] = legalMoves(play)
    guard !moves.isEmpty else { return false }
    try play.apply(moves[random.int(0...(moves.count - 1))], expecting: play.fingerprint)
    return true
}

/// Every arrangement action of `level`, legal or not, written here: for each star every ring, every phase 0 … 47 and
/// every luminosity; then every tilt.
private func bruteCandidates(_ level: BinaryGardensLevel) -> [BinaryGardensAction] {
    var result: [BinaryGardensAction] = []
    for star in 0..<2 {
        for index in 0..<level.ringRadii.count { result.append(.ring(star: star, index: index)) }
        for step in 0..<48 { result.append(.phase(star: star, step: step)) }
        for index in 0..<level.luminosityLevels.count { result.append(.luminosity(star: star, index: index)) }
    }
    for step in 0...level.maxTilt { result.append(.tilt(step: step)) }
    return result
}

/// The independent brute force: every arrangement reachable from `arrangement` within min(`actionsLeft`, 2) actions
/// the kernel accepts; the length of the shortest winning sequence (nil: none) and the distinct arrangements reached
/// (the whole space when no win exists; the exploration stops at the first win of the shortest length).
private func bruteShortest(_ level: BinaryGardensLevel, from arrangement: BinaryGardensArrangement,
                           actionsLeft: Int) -> (length: Int?, space: Int) {
    let cap: Int = min(2, actionsLeft)
    guard cap >= 1 else { return (nil, 0) }
    let candidates: [BinaryGardensAction] = bruteCandidates(level)
    var reached: Set<BinaryGardensArrangement> = []
    var firsts: [BinaryGardensArrangement] = []
    var found: Int? = nil
    for action in candidates {
        guard let next = try? BinaryGardensSky.changed(level, arrangement, by: action) else { continue }
        firsts.append(next)
        reached.insert(next)
        if found == nil && BinaryGardensSky.report(level, arrangement: next).wins { found = 1 }
    }
    guard cap >= 2, found == nil else { return (found, reached.count) }
    for middle in firsts {
        for action in candidates {
            guard let next = try? BinaryGardensSky.changed(level, middle, by: action) else { continue }
            if next == arrangement || reached.contains(next) { continue }
            reached.insert(next)
            if BinaryGardensSky.report(level, arrangement: next).wins { return (2, reached.count) }
        }
    }
    return (nil, reached.count)
}

/// The search of clarification Q1 written here on the puzzle contract (`moves(in:)` and `apply(_:to:)`): the first
/// winning sequence of one, else two, legal moves within min(actions left, 2), each new arrangement judged once (the
/// current one never), and the arrangements judged; no bound.
private func referenceSearch(_ play: BinaryGardensPlay) -> (actions: [BinaryGardensAction]?, work: Int) {
    let puzzle: BinaryGardensPuzzle = BinaryGardensPuzzle(level: play.level)
    let current: BinaryGardensPuzzle.Position =
        BinaryGardensPuzzle.Position(arrangement: play.arrangement, actionsSpent: play.actionsSpent)
    var seen: Set<BinaryGardensArrangement> = [play.arrangement]
    var work: Int = 0
    let firsts: [BinaryGardensAction] = puzzle.moves(in: current)
    for first in firsts {
        guard let next = puzzle.apply(first, to: current), !seen.contains(next.arrangement) else { continue }
        seen.insert(next.arrangement)
        work += 1
        if puzzle.isSolved(next) { return ([first], work) }
    }
    if play.actionsLeft < 2 { return (nil, work) }
    for first in firsts {
        guard let middle = puzzle.apply(first, to: current) else { continue }
        for second in puzzle.moves(in: middle) {
            guard let next = puzzle.apply(second, to: middle), !seen.contains(next.arrangement) else { continue }
            seen.insert(next.arrangement)
            work += 1
            if puzzle.isSolved(next) { return ([first, second], work) }
        }
    }
    return (nil, work)
}

/// Whether every control of `arrangement` holds the value of `start` or of `target`, written here.
private func liesOnTheWay(_ arrangement: BinaryGardensArrangement, start: BinaryGardensArrangement,
                          target: BinaryGardensArrangement) -> Bool {
    for star in 0..<2 {
        let ring: Int = arrangement.rings[star]
        if ring != start.rings[star] && ring != target.rings[star] { return false }
        let phase: Int = arrangement.phases[star]
        if phase != start.phases[star] && phase != target.phases[star] { return false }
        let light: Int = arrangement.luminosities[star]
        if light != start.luminosities[star] && light != target.luminosities[star] { return false }
    }
    return arrangement.tilt == start.tilt || arrangement.tilt == target.tilt
}

/// A random legal move of `play` that leaves the way to `target` (a value neither the start's nor the target's), or
/// nil.
private func offMove(_ play: BinaryGardensPlay, target: BinaryGardensArrangement,
                     _ random: inout SeededRandom) -> BinaryGardensAction? {
    var off: [BinaryGardensAction] = []
    for move in legalMoves(play) {
        guard let next = try? BinaryGardensSky.changed(play.level, play.arrangement, by: move) else { continue }
        if !liesOnTheWay(next, start: play.level.start, target: target) { off.append(move) }
    }
    guard !off.isEmpty else { return nil }
    return off[random.int(0...(off.count - 1))]
}

/// Follows exact (level 3) hints from `start` until the play ends, running the cycle when hinted; the problems found
/// (empty: won, every hinted action accepted, every text as written here, the play unchanged by every hint) and the
/// actions spent following them.
private func followHints(_ start: BinaryGardensPlay, certified: BinaryGardensPlan?,
                         label: String) -> (problems: [String], spent: Int) {
    var play: BinaryGardensPlay = start
    let spentBefore: Int = play.actionsSpent
    for _ in 0..<30 {
        if play.stage == .won { return ([], play.actionsSpent - spentBefore) }
        let before: BinaryGardensPlay = play
        let fingerprint: String = play.fingerprint
        guard let hint = BinaryGardensHints.hint(level: 3, play: play, certified: certified) else {
            return (["\(label): no hint in \(play.stage)"], play.actionsSpent - spentBefore)
        }
        guard play == before, play.fingerprint == fingerprint else {
            return (["\(label): the hint changed the play"], play.actionsSpent - spentBefore)
        }
        guard let action = hint.action else {
            return (["\(label): \(hint.kind) with \(play.actionsLeft) actions left"], play.actionsSpent - spentBefore)
        }
        if action != .run {
            let texts: [String] = expectedHintTexts(action, level: play.level, arrangement: play.arrangement)
            if texts.count != 3 || hint.text != texts[2] {
                return (["\(label): text \(hint.text)"], play.actionsSpent - spentBefore)
            }
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

/// The failure codes in the order the aimed draws use them.
private let hintCauseCodes: [String] = ["frozen", "scorched", "unstable", "wilted", "bleached"]

@Suite struct BinaryGardensHintsTests {
    // MARK: Exact hints from every opening

    /// Exact hints from every opening of `quarter` replay the certified witness and win within the certified count.
    func exactHintsWin(quarter: Int) throws {
        let levels: [BinaryGardensGenerated] = try hintQuarter(quarter)
        #expect(levels.count == 25)
        for generated in levels {
            let number: Int = generated.entry.number
            let opening: BinaryGardensPlay = try hintOpening(generated.level)
            var changes: [BinaryGardensAction] = []
            for action in generated.plan.actions where action != .run { changes.append(action) }
            let plan: BinaryGardensHintPlan? = BinaryGardensHints.plan(opening, certified: generated.plan)
            #expect(plan == BinaryGardensHintPlan(actions: changes), "level \(number): plan from the opening")
            let first: BinaryGardensAction = try #require(changes.first)
            let texts: [String] = expectedHintTexts(first, level: generated.level, arrangement: opening.arrangement)
            for hintLevel in 1...3 {
                let hint: BinaryGardensHint? = BinaryGardensHints.hint(level: hintLevel, play: opening,
                                                                       certified: generated.plan)
                #expect(hint?.text == texts[hintLevel - 1], "level \(number): text at hint level \(hintLevel)")
                #expect(hint?.action == first)
                #expect(hint?.level == hintLevel)
                #expect(hint?.kind == BinaryGardensHint.kind(of: first))
            }
            let followed: (problems: [String], spent: Int) =
                followHints(opening, certified: generated.plan, label: "level \(number)")
            #expect(followed.problems.isEmpty, "\(followed.problems)")
            #expect(followed.spent == changes.count, "level \(number): spent \(followed.spent)")
            #expect(followed.spent <= generated.level.budget)
        }
    }

    @Test func exactHintsFromTheOpeningWinLevels1To25() throws { try exactHintsWin(quarter: 0) }

    @Test func exactHintsFromTheOpeningWinLevels26To50() throws { try exactHintsWin(quarter: 1) }

    @Test func exactHintsFromTheOpeningWinLevels51To75() throws { try exactHintsWin(quarter: 2) }

    @Test func exactHintsFromTheOpeningWinLevels76To100() throws { try exactHintsWin(quarter: 3) }

    // MARK: Seeded reachable states

    /// 25 seeded reachable states of `quarter` (`half` 0 or 1 of its 50): every exact hint is accepted by the kernel
    /// and following hints wins.
    func reachableStates(quarter: Int, half: Int) throws {
        let levels: [BinaryGardensGenerated] = try hintQuarter(quarter)
        var random: SeededRandom = SeededRandom(seed: 2_505 + UInt64(2 * quarter + half))
        var stuck: Int = 0
        for index in 0..<25 {
            let generated: BinaryGardensGenerated = levels[random.int(0...24)]
            let label: String = "state \(index) of level \(generated.entry.number)"
            var play: BinaryGardensPlay = try hintOpening(generated.level)
            let count: Int = random.int(0...4)
            for _ in 0..<count {
                if try !applyRandomMove(&play, &random) { break }
            }
            if random.int(0...3) == 0 && play.canUndo { try play.undo() }
            let before: BinaryGardensPlay = play
            let fingerprint: String = play.fingerprint
            let hint: BinaryGardensHint = try #require(BinaryGardensHints.hint(level: 3, play: play,
                                                                               certified: generated.plan))
            #expect(play == before && play.fingerprint == fingerprint, "\(label): the hint changed the play")
            switch hint.kind {
            case .run:
                #expect(play.report.wins, "\(label): run hinted on a losing arrangement")
                #expect(hint.action == .run && hint.text == BinaryGardensHint.runText)
            case .stuck:
                stuck += 1
                let brute: (length: Int?, space: Int) =
                    bruteShortest(play.level, from: play.arrangement, actionsLeft: play.actionsLeft)
                #expect(brute.length == nil, "\(label): stuck although a win exists")
                #expect(hint.action == nil && hint.text == BinaryGardensHint.stuckText)
            case .retry:
                Issue.record("\(label): retry while playing")
            case .ring, .phase, .luminosity, .tilt:
                let action: BinaryGardensAction = try #require(hint.action)
                #expect(hint.kind == BinaryGardensHint.kind(of: action))
                let texts: [String] = expectedHintTexts(action, level: play.level, arrangement: play.arrangement)
                #expect(hint.text == texts[2], "\(label): exact text")
                for hintLevel in 1...2 {
                    let shown: String? = BinaryGardensHint.actionText(level: hintLevel, action: action,
                                                                      gardens: play.level,
                                                                      arrangement: play.arrangement)
                    #expect(shown == texts[hintLevel - 1], "\(label): text at hint level \(hintLevel)")
                }
                var accepted: BinaryGardensPlay = play
                do {
                    try accepted.apply(action, expecting: accepted.fingerprint)
                } catch {
                    Issue.record("\(label): hinted \(action) refused: \(error)")
                }
            }
            if hint.kind != .stuck {
                // The hint is the plan's first action, and the plan then the run wins within the actions left.
                let plan: BinaryGardensHintPlan = try #require(BinaryGardensHints.plan(play, certified: generated.plan))
                #expect(plan.actions.first ?? .run == hint.action, "\(label): the hint is not the plan's first action")
                #expect(plan.actions.count <= play.actionsLeft)
                var replay: BinaryGardensPlay = play
                for action in plan.actions { try replay.apply(action, expecting: replay.fingerprint) }
                try replay.apply(.run, expecting: replay.fingerprint)
                #expect(replay.stage == .won, "\(label): the plan does not win")
            }
        }
        #expect(stuck < 25)
    }

    @Test func seededReachableStatesGetAcceptedHintsLevels1To25A() throws {
        try reachableStates(quarter: 0, half: 0)
    }

    @Test func seededReachableStatesGetAcceptedHintsLevels1To25B() throws {
        try reachableStates(quarter: 0, half: 1)
    }

    @Test func seededReachableStatesGetAcceptedHintsLevels26To50A() throws {
        try reachableStates(quarter: 1, half: 0)
    }

    @Test func seededReachableStatesGetAcceptedHintsLevels26To50B() throws {
        try reachableStates(quarter: 1, half: 1)
    }

    @Test func seededReachableStatesGetAcceptedHintsLevels51To75A() throws {
        try reachableStates(quarter: 2, half: 0)
    }

    @Test func seededReachableStatesGetAcceptedHintsLevels51To75B() throws {
        try reachableStates(quarter: 2, half: 1)
    }

    @Test func seededReachableStatesGetAcceptedHintsLevels76To100A() throws {
        try reachableStates(quarter: 3, half: 0)
    }

    @Test func seededReachableStatesGetAcceptedHintsLevels76To100B() throws {
        try reachableStates(quarter: 3, half: 1)
    }

    // MARK: Seeded failures

    /// Draws a failed play of `quarter`'s levels: aimed at `cause` by a one-move change of the opening or of the
    /// certified arrangement, else random legal moves, some undone and redone, then the run. Nil when the draw wins or
    /// no aimed move exists.
    func drawFailure(_ levels: [BinaryGardensGenerated], cause: String?,
                     _ random: inout SeededRandom) throws -> BinaryGardensPlay? {
        let generated: BinaryGardensGenerated = levels[random.int(0...24)]
        var play: BinaryGardensPlay = try hintOpening(generated.level)
        if let cause {
            if random.int(0...1) == 1 {
                for action in generated.plan.actions where action != .run {
                    try play.apply(action, expecting: play.fingerprint)
                }
            }
            var aimed: [BinaryGardensAction] = []
            for move in legalMoves(play) {
                guard let next = try? BinaryGardensSky.changed(play.level, play.arrangement, by: move) else { continue }
                if BinaryGardensSky.report(play.level, arrangement: next).failure?.code == cause { aimed.append(move) }
            }
            guard !aimed.isEmpty else { return nil }
            try play.apply(aimed[random.int(0...(aimed.count - 1))], expecting: play.fingerprint)
        } else {
            let count: Int = random.int(0...5)
            for _ in 0..<count {
                if try !applyRandomMove(&play, &random) { break }
            }
            if random.int(0...3) == 0 && play.canUndo {
                try play.undo()
                if random.int(0...1) == 0 { try play.redo() }
            }
        }
        try play.apply(.run, expecting: play.fingerprint)
        guard play.stage == .failed else { return nil }
        if random.int(0...2) == 0 { try play.handle(.showResult) }
        return play
    }

    /// 125 seeded failures of `quarter`, every fifth aimed at a cause in turn: all five causes appear and each is
    /// explained with its true values.
    func seededFailures(quarter: Int) throws {
        let levels: [BinaryGardensGenerated] = try hintQuarter(quarter)
        var random: SeededRandom = SeededRandom(seed: 2_505 + 100 + UInt64(quarter))
        var failures: Int = 0
        var draws: Int = 0
        var causes: [String: Int] = [:]
        while failures < 125 && draws < 5_000 {
            draws += 1
            let cause: String? = failures % 5 == 0 ? hintCauseCodes[(failures / 5) % 5] : nil
            guard let play = try drawFailure(levels, cause: cause, &random) else { continue }
            let failure: BinaryGardensFailure = try #require(play.failure)
            let level: BinaryGardensLevel = play.level
            let report: BinaryGardensReport = BinaryGardensSky.report(level, arrangement: play.arrangement)
            #expect(report.failure == failure, "the failure differs from the judged one")
            let world: Int = failure.world
            let light: BinaryGardensWorldLight = report.worlds[world]
            let rules: BinaryGardensWorld = level.worlds[world]
            switch failure {
            case .frozen(_, let tick):
                #expect(tick >= 1 && tick <= 48 + level.lethalTolerance)
                #expect(light.bands[(tick - 1) % 48] == .lethalLow)
            case .scorched(_, let tick):
                #expect(tick >= 1 && tick <= 48 + level.lethalTolerance)
                #expect(light.bands[(tick - 1) % 48] == .lethalHigh)
            case .unstable(_, let window, let required):
                #expect(window == light.window && required == rules.window && window < required)
            case .wilted(_, let integral, let low, let high):
                #expect(integral == light.integral && low == rules.bloomLow && high == rules.bloomHigh)
                #expect(integral < low)
            case .bleached(_, let integral, let low, let high):
                #expect(integral == light.integral && low == rules.bloomLow && high == rules.bloomHigh)
                #expect(integral > high)
            }
            let before: BinaryGardensPlay = play
            let explanation: BinaryGardensFailureExplanation = try #require(BinaryGardensFailureExplanation(play: play))
            #expect(explanation.failure == failure)
            #expect(explanation.text == expectedExplanation(failure, tolerance: level.lethalTolerance))
            for hintLevel in 1...3 {
                let hint: BinaryGardensHint? = BinaryGardensHints.hint(level: hintLevel, play: play, certified: nil)
                #expect(hint?.kind == .retry && hint?.action == nil && hint?.text == BinaryGardensHint.failedText)
            }
            #expect(play == before, "the explanation or a hint changed the play")
            causes[failure.code, default: 0] += 1
            failures += 1
        }
        #expect(failures == 125, "only \(failures) failures in \(draws) draws")
        for code in hintCauseCodes {
            #expect((causes[code] ?? 0) >= 1, "no \(code) failure in quarter \(quarter): \(causes)")
        }
    }

    @Test func seededFailuresAreExplainedLevels1To25() throws { try seededFailures(quarter: 0) }

    @Test func seededFailuresAreExplainedLevels26To50() throws { try seededFailures(quarter: 1) }

    @Test func seededFailuresAreExplainedLevels51To75() throws { try seededFailures(quarter: 2) }

    @Test func seededFailuresAreExplainedLevels76To100() throws { try seededFailures(quarter: 3) }

    // MARK: Off the certified path

    /// States off the certified path on every sixth level of `quarter` from index 3 · `half`: the plan agrees with the
    /// brute force and the reference search.
    func offPath(quarter: Int, half: Int) throws {
        var random: SeededRandom = SeededRandom(seed: 2_505 + 200 + UInt64(2 * quarter + half))
        var fromCertified: Int = 0
        var found: Int = 0
        let levels: [BinaryGardensGenerated] = try hintQuarter(quarter)
        for index in stride(from: 3 * half, to: 25, by: 6) {
            let generated: BinaryGardensGenerated = levels[index]
            let target: BinaryGardensArrangement = generated.plan.arrangement
            var changes: [BinaryGardensAction] = []
            for action in generated.plan.actions where action != .run { changes.append(action) }
            for kind in 0..<3 {
                var play: BinaryGardensPlay = try hintOpening(generated.level)
                let prefix: Int = kind == 0 ? 0 : (kind == 1 ? changes.count : changes.count - 1)
                for step in 0..<prefix { try play.apply(changes[step], expecting: play.fingerprint) }
                guard let move = offMove(play, target: target, &random) else { continue }
                try play.apply(move, expecting: play.fingerprint)
                let label: String = "level \(generated.entry.number) kind \(kind)"
                #expect(!liesOnTheWay(play.arrangement, start: generated.level.start, target: target))
                if play.report.wins {
                    #expect(BinaryGardensHints.plan(play, certified: generated.plan)?.actions == [])
                    continue
                }
                let before: BinaryGardensPlay = play
                let brute: (length: Int?, space: Int) =
                    bruteShortest(play.level, from: play.arrangement, actionsLeft: play.actionsLeft)
                #expect(brute.space <= 650, "\(label): two-action space \(brute.space)")
                let plan: BinaryGardensHintPlan? = BinaryGardensHints.plan(play, certified: generated.plan)
                #expect(play == before, "\(label): the plan changed the play")
                #expect(plan?.actions.count == brute.length, "\(label): plan \(String(describing: plan))")
                if kind == 1 {
                    fromCertified += 1
                    #expect(plan != nil, "\(label): no plan one move off the certified arrangement")
                }
                guard let plan else { continue }
                found += 1
                var replay: BinaryGardensPlay = play
                for action in plan.actions { try replay.apply(action, expecting: replay.fingerprint) }
                try replay.apply(.run, expecting: replay.fingerprint)
                #expect(replay.stage == .won, "\(label): the plan does not win")
            }
        }
        #expect(fromCertified >= 2)
        #expect(found >= fromCertified)
    }

    @Test func theBoundedSearchFindsPlansOffTheCertifiedPathLevels1To25A() throws {
        try offPath(quarter: 0, half: 0)
    }

    @Test func theBoundedSearchFindsPlansOffTheCertifiedPathLevels1To25B() throws {
        try offPath(quarter: 0, half: 1)
    }

    @Test func theBoundedSearchFindsPlansOffTheCertifiedPathLevels26To50A() throws {
        try offPath(quarter: 1, half: 0)
    }

    @Test func theBoundedSearchFindsPlansOffTheCertifiedPathLevels26To50B() throws {
        try offPath(quarter: 1, half: 1)
    }

    @Test func theBoundedSearchFindsPlansOffTheCertifiedPathLevels51To75A() throws {
        try offPath(quarter: 2, half: 0)
    }

    @Test func theBoundedSearchFindsPlansOffTheCertifiedPathLevels51To75B() throws {
        try offPath(quarter: 2, half: 1)
    }

    @Test func theBoundedSearchFindsPlansOffTheCertifiedPathLevels76To100A() throws {
        try offPath(quarter: 3, half: 0)
    }

    @Test func theBoundedSearchFindsPlansOffTheCertifiedPathLevels76To100B() throws {
        try offPath(quarter: 3, half: 1)
    }

    // MARK: Work bound

    @Test func aWorkBoundBelowTheSearchedSpaceReturnsNil() throws {
        #expect(BinaryGardensHints.workBound == 2_000)
        let levels: [BinaryGardensGenerated] = try hintQuarter(2)
        var random: SeededRandom = SeededRandom(seed: 2_505 + 300)
        var checked: Int = 0
        var exhausted: Int = 0
        for generated in levels {
            let target: BinaryGardensArrangement = generated.plan.arrangement
            var play: BinaryGardensPlay = try hintOpening(generated.level)
            for action in generated.plan.actions where action != .run {
                try play.apply(action, expecting: play.fingerprint)
            }
            guard let move = offMove(play, target: target, &random) else { continue }
            try play.apply(move, expecting: play.fingerprint)
            if play.report.wins { continue }
            let full: (plan: BinaryGardensHintPlan?, work: Int) = BinaryGardensHints.search(play, workBound: Int.max)
            let plan: BinaryGardensHintPlan = try #require(full.plan)
            #expect(full.work >= 1 && full.work <= 650)
            let reference: (actions: [BinaryGardensAction]?, work: Int) = referenceSearch(play)
            #expect(plan.actions == reference.actions && full.work == reference.work, "the search differs")
            #expect(BinaryGardensHints.plan(play, certified: generated.plan) == plan)
            #expect(BinaryGardensHints.plan(play, certified: generated.plan, workBound: full.work) == plan)
            #expect(BinaryGardensHints.plan(play, certified: generated.plan, workBound: full.work - 1) == nil)
            #expect(BinaryGardensHints.plan(play, certified: generated.plan, workBound: 0) == nil)
            checked += 1
            // A state whose whole two-action space holds no win: the search judges all of it, so any bound refuses.
            var lost: BinaryGardensPlay = try hintOpening(generated.level)
            if try !applyRandomMove(&lost, &random) { continue }
            let brute: (length: Int?, space: Int) =
                bruteShortest(lost.level, from: lost.arrangement, actionsLeft: lost.actionsLeft)
            if brute.length == nil && !liesOnTheWay(lost.arrangement, start: generated.level.start, target: target) {
                let searched: (plan: BinaryGardensHintPlan?, work: Int) =
                    BinaryGardensHints.search(lost, workBound: Int.max)
                #expect(searched.plan == nil && searched.work == brute.space)
                #expect(BinaryGardensHints.search(lost, workBound: brute.space - 1).work == brute.space - 1)
                exhausted += 1
            }
        }
        #expect(checked >= 10)
        #expect(exhausted >= 1, "no state without a win in two actions")
    }

    // MARK: Stages, hints never change the play

    @Test func hintsFollowTheStagesAndNeverChangeThePlay() throws {
        let generated: BinaryGardensGenerated = try hintQuarter(0)[0]
        let level: BinaryGardensLevel = generated.level
        #expect(level.tutorial)
        var play: BinaryGardensPlay = BinaryGardensPlay(level: level)
        #expect(BinaryGardensHints.hint(level: 1, play: play, certified: generated.plan) == nil)
        #expect(BinaryGardensHints.plan(play, certified: generated.plan) == nil)
        try play.handle(.begin)
        #expect(play.stage == .tutorial)
        #expect(BinaryGardensHints.hint(level: 1, play: play, certified: generated.plan) == nil)
        try play.handle(.dismissTutorial)
        let opening: BinaryGardensPlay = play
        var actions: [BinaryGardensAction?] = []
        for hintLevel in 0...4 {
            let hint: BinaryGardensHint? = BinaryGardensHints.hint(level: hintLevel, play: play,
                                                                   certified: generated.plan)
            #expect(hint?.level == min(3, max(1, hintLevel)))
            actions.append(hint?.action)
            #expect(play == opening && play.fingerprint == opening.fingerprint)
        }
        for action in actions { #expect(action == actions[0] && action != nil) }
        #expect(BinaryGardensFailureExplanation(play: play) == nil)
        try play.handle(.pause)
        #expect(BinaryGardensHints.hint(level: 2, play: play, certified: generated.plan) == nil)
        try play.handle(.resume)
        // Winning: the run hint, then no hint once won and in the result.
        var won: BinaryGardensPlay = play
        for action in generated.plan.actions where action != .run {
            try won.apply(action, expecting: won.fingerprint)
        }
        let runHint: BinaryGardensHint? = BinaryGardensHints.hint(level: 1, play: won, certified: generated.plan)
        #expect(runHint?.kind == .run && runHint?.action == .run && runHint?.text == BinaryGardensHint.runText)
        #expect(BinaryGardensHints.plan(won, certified: generated.plan) == BinaryGardensHintPlan(actions: []))
        try won.apply(.run, expecting: won.fingerprint)
        #expect(won.stage == .won)
        #expect(BinaryGardensHints.hint(level: 3, play: won, certified: generated.plan) == nil)
        #expect(BinaryGardensFailureExplanation(play: won) == nil)
        try won.handle(.showResult)
        #expect(BinaryGardensHints.hint(level: 3, play: won, certified: generated.plan) == nil)
        #expect(BinaryGardensFailureExplanation(play: won) == nil)
        // Failing: the retry advice in failed and in the result.
        var failed: BinaryGardensPlay = play
        try failed.apply(.run, expecting: failed.fingerprint)
        #expect(failed.stage == .failed)
        let failedBefore: BinaryGardensPlay = failed
        let retry: BinaryGardensHint? = BinaryGardensHints.hint(level: 2, play: failed, certified: generated.plan)
        #expect(retry?.kind == .retry && retry?.action == nil && retry?.text == BinaryGardensHint.failedText)
        let explanation: BinaryGardensFailureExplanation? = BinaryGardensFailureExplanation(play: failed)
        #expect(explanation != nil)
        #expect(failed == failedBefore)
        try failed.handle(.showResult)
        #expect(BinaryGardensHints.hint(level: 1, play: failed, certified: generated.plan)?.kind == .retry)
        #expect(BinaryGardensFailureExplanation(play: failed) == explanation)
        #expect(BinaryGardensHints.plan(failed, certified: generated.plan) == nil)
    }

    @Test func noActionLeftOnALosingArrangementIsStuck() throws {
        let generated: BinaryGardensGenerated = try hintQuarter(0)[0]
        var play: BinaryGardensPlay = try hintOpening(generated.level)
        while play.actionsLeft > 0 {
            var chosen: BinaryGardensAction? = nil
            for move in legalMoves(play) {
                guard let next = try? BinaryGardensSky.changed(play.level, play.arrangement, by: move) else { continue }
                if !BinaryGardensSky.report(play.level, arrangement: next).wins {
                    chosen = move
                    break
                }
            }
            let move: BinaryGardensAction = try #require(chosen)
            try play.apply(move, expecting: play.fingerprint)
        }
        #expect(!play.report.wins)
        #expect(BinaryGardensHints.plan(play, certified: generated.plan) == nil)
        for hintLevel in 1...3 {
            let hint: BinaryGardensHint? = BinaryGardensHints.hint(level: hintLevel, play: play,
                                                                   certified: generated.plan)
            #expect(hint?.kind == .stuck && hint?.action == nil && hint?.text == BinaryGardensHint.stuckText)
        }
        #expect(BinaryGardensHint.stuckText
            == "No way to win was found in the actions left: undo the last action or retry the level.")
    }

    // MARK: Texts

    @Test func hintTextsNameTheKindTheWayAndTheExactAction() throws {
        var chosen: BinaryGardensLevel? = nil
        for generated in try hintQuarter(0) where generated.level.luminosityLevels.count >= 2 {
            chosen = generated.level
            break
        }
        let level: BinaryGardensLevel = try #require(chosen)
        let arrangement: BinaryGardensArrangement =
            BinaryGardensArrangement(rings: [0, 1], phases: [40, 2], luminosities: [1, 0], tilt: 1)
        let radius: Int = level.ringRadii[1]
        let cases: [(BinaryGardensAction, [String])] = [
            (.ring(star: 0, index: 1), ["Move a star to another ring", "Move star 1 outward",
                                        "Move star 1 to ring 2 (\(radius) units)"]),
            (.ring(star: 1, index: 0), ["Move a star to another ring", "Move star 2 inward",
                                        "Move star 2 to ring 1 (\(level.ringRadii[0]) units)"]),
            (.phase(star: 0, step: 2), ["Shift a star's phase", "Shift star 1's phase forward",
                                        "Shift star 1 to phase 2"]),
            (.phase(star: 1, step: 40), ["Shift a star's phase", "Shift star 2's phase back",
                                         "Shift star 2 to phase 40"]),
            (.phase(star: 1, step: 26), ["Shift a star's phase", "Shift star 2's phase forward",
                                         "Shift star 2 to phase 26"]),
            (.phase(star: 1, step: 27), ["Shift a star's phase", "Shift star 2's phase back",
                                         "Shift star 2 to phase 27"]),
            (.tilt(step: 3), ["Tilt the orbit plane", "Tilt the orbit plane more",
                              "Set the tilt to 3 of \(level.maxTilt) steps"]),
            (.tilt(step: 0), ["Tilt the orbit plane", "Tilt the orbit plane less",
                              "Set the tilt to 0 of \(level.maxTilt) steps"]),
        ]
        for (action, texts) in cases {
            for hintLevel in 1...3 {
                let text: String? = BinaryGardensHint.actionText(level: hintLevel, action: action, gardens: level,
                                                                 arrangement: arrangement)
                #expect(text == texts[hintLevel - 1], "\(action) at \(hintLevel)")
            }
            #expect(BinaryGardensHint.actionText(level: 0, action: action, gardens: level,
                                                 arrangement: arrangement) == texts[0])
            #expect(BinaryGardensHint.actionText(level: 9, action: action, gardens: level,
                                                 arrangement: arrangement) == texts[2])
        }
        let brighter: String? = BinaryGardensHint.actionText(level: 2, action: .luminosity(star: 1, index: 1),
                                                             gardens: level, arrangement: arrangement)
        #expect(brighter == "Make star 2 brighter")
        let dimmer: String? = BinaryGardensHint.actionText(level: 3, action: .luminosity(star: 0, index: 0),
                                                           gardens: level, arrangement: arrangement)
        #expect(dimmer == "Set star 1's luminosity to \(level.luminosityLevels[0])")
        #expect(BinaryGardensHint.actionText(level: 2, action: .luminosity(star: 0, index: 0), gardens: level,
                                             arrangement: arrangement) == "Make star 1 dimmer")
        #expect(BinaryGardensHint.actionText(level: 1, action: .luminosity(star: 0, index: 0), gardens: level,
                                             arrangement: arrangement) == "Change a star's brightness")
        #expect(BinaryGardensHint.actionText(level: 3, action: .run, gardens: level, arrangement: arrangement) == nil)
        #expect(BinaryGardensHint.runText == "Every world keeps its light: run the cycle")
        #expect(BinaryGardensHint.failedText == "Undo the last action or retry the level.")
        let kinds: [String] = ["ring", "phase", "luminosity", "tilt", "run", "stuck", "retry"]
        let values: [BinaryGardensHintKind] = [.ring, .phase, .luminosity, .tilt, .run, .stuck, .retry]
        for index in kinds.indices { #expect(values[index].rawValue == kinds[index]) }
    }

    @Test func failureSentencesUseTheWordingsOfTheSpec() {
        let advice: String = " Undo the last action or retry the level."
        #expect(BinaryGardensFailureExplanation.advice + "" == "Undo the last action or retry the level.")
        let cases: [(BinaryGardensFailure, Int, String)] = [
            (.frozen(world: 1, tick: 50), 3, "World 2 froze at tick 50 (tick 2 of the next cycle): its light stayed "
                + "below its lethal floor for more than 3 ticks in a row."),
            (.frozen(world: 0, tick: 17), 1, "World 1 froze at tick 17: its light stayed below its lethal floor for "
                + "more than 1 tick in a row."),
            (.frozen(world: 2, tick: 9), 0, "World 3 froze at tick 9: its light fell below its lethal floor."),
            (.scorched(world: 0, tick: 7), 2, "World 1 scorched at tick 7: its light stayed above its lethal ceiling "
                + "for more than 2 ticks in a row."),
            (.scorched(world: 0, tick: 49), 1, "World 1 scorched at tick 49 (tick 1 of the next cycle): its light "
                + "stayed above its lethal ceiling for more than 1 tick in a row."),
            (.scorched(world: 4, tick: 48), 0, "World 5 scorched at tick 48: its light rose above its lethal ceiling."),
            (.unstable(world: 0, window: 1, required: 24), 3,
             "World 1 kept comfortable light for only 1 tick in a row; 24 were needed."),
            (.unstable(world: 1, window: 20, required: 1), 3,
             "World 2 kept comfortable light for only 20 ticks in a row; 1 was needed."),
            (.unstable(world: 2, window: 0, required: 31), 3, "World 3 never had comfortable light; 31 were needed."),
            (.wilted(world: 2, integral: 1_800_000, low: 1_900_000, high: 2_100_000), 3,
             "World 3 wilted: its light over the cycle totalled 1 800 000, below its bloom band "
                + "1 900 000 … 2 100 000."),
            (.bleached(world: 0, integral: 2_200_000, low: 950, high: 1_000_500), 3,
             "World 1 bleached: its light over the cycle totalled 2 200 000, above its bloom band 950 … 1 000 500."),
        ]
        for (failure, tolerance, sentence) in cases {
            #expect(BinaryGardensFailureExplanation.sentence(failure, tolerance: tolerance) == sentence)
            #expect(expectedExplanation(failure, tolerance: tolerance) == sentence + advice)
        }
    }
}
