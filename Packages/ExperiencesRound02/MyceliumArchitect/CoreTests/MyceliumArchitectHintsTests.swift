// MyceliumArchitectHintsTests — feature 515 (R02-G22-05) T-R02G2205-002 (FR-R02G2205-002, 003, 009; SC-R02G2205-002,
// 003; clarifications Q1, Q5; research R1 … R3). Hints and failure explanations of Mycelium Architect. The 100
// certified levels and their certified plans are read from the stored witnesses
// (docs/games/mycelium-architect/levels/NNN.witness.json: the level's stored form and the solver's plan, then the run;
// byte-identical to the regenerated witnesses by `MyceliumArchitectCatalogTests`), once per test process in four
// quarters of 25 levels (each quarter a lazily initialised global, so concurrent tests share one read); levels 1 … 3
// are compared with `MyceliumArchitectExperienceCore.generated(number:)`.
//
// Per quarter: the hint plan from every opening is the certified witness; the level 1, 2 and 3 texts of the first hint
// match texts written here; following exact (level 3) hints, re-asked after every action, then the hinted run wins
// spending exactly the witness's actions within the budget, and no hint changes the play. 200 seeded reachable states
// (seed 2_515 plus the group, 8 × 25: 0 … 4 random legal moves from a random certified opening, sometimes one undone)
// get a hint the kernel accepts (the run only when the arrangement already wins; stuck only when an independent brute
// force finds no win within min(actions left, 2)), the hint is the plan's first action and the plan then the run wins
// within the actions left, and no hint changes the play. 500 seeded failures (seed 2_515 + 100 plus the quarter,
// 4 × 125: random legal moves, some undone and redone, then the run, some shown as a result; every fifth failure aimed
// at one cause in turn by a change of one move — or, failing that, two — from the opening, a witness prefix or the
// certified arrangement) cover all four causes in every quarter and are explained with their true tip or terminal,
// cell, pulse, weight and bound: the failure equals the one judged from the play's arrangement, its values agree with
// the report and the level, and the text equals the one written here. Off the certified path (an opening, the
// certified arrangement or the witness but its last action, each followed by a move off the way), an independent brute
// force over every arrangement reachable within min(actions left, 2) decides whether a win exists and its shortest
// length; the plan exists exactly then, has that length, wins through the kernel and does not change the play; from
// the certified arrangement plus one off move a plan always exists. One move off each certified arrangement of levels
// 51 … 75, the search equals a reference search on the puzzle contract (same sequence, same work) and a work bound
// below the arrangements it judges returns nil. Hand cases check the stages, the stuck text with no action left, the
// hint texts and every failure wording. No clock; deterministic, explicit types, plain loops (CI type-check rule).
import Foundation
import Testing
import VisualCoreSimulation
@testable import MyceliumArchitectCore

/// The repository's witness directory, found from this file (five levels up: CoreTests, MyceliumArchitect, the
/// package, Packages).
private let hintWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/mycelium-architect/levels", isDirectory: true)

/// The parts of a stored witness these tests use: the manifest number, the level and the plan (then the run).
fileprivate struct HintWitness: Decodable {
    /// The manifest number.
    let number: Int
    /// The certified level (decoded under the level's own rules).
    let level: MyceliumArchitectLevel
    /// The solver's plan, then `run`.
    let actions: [MyceliumArchitectAction]
}

/// A certified level with its plan's arrangement actions.
fileprivate struct HintCertified: Sendable {
    /// The manifest number.
    let number: Int
    /// The level.
    let level: MyceliumArchitectLevel
    /// The plan's arrangement actions, without the run.
    let changes: [MyceliumArchitectAction]
}

/// The certified level `number` read from its stored witness.
private func readCertified(_ number: Int) throws -> HintCertified {
    let name: String = String(format: "%03d.witness.json", number)
    let data: Data = try Data(contentsOf: hintWitnessDirectory.appendingPathComponent(name))
    let witness: HintWitness = try JSONDecoder().decode(HintWitness.self, from: data)
    var changes: [MyceliumArchitectAction] = []
    for action in witness.actions where action != .run { changes.append(action) }
    return HintCertified(number: witness.number, level: witness.level, changes: changes)
}

/// The certified levels of quarter `quarter` (0 … 3): manifest numbers 25 · quarter + 1 … 25 · quarter + 25.
private func makeHintQuarter(_ quarter: Int) -> Result<[HintCertified], any Error> {
    Result {
        var result: [HintCertified] = []
        for number in (quarter * 25 + 1)...(quarter * 25 + 25) { result.append(try readCertified(number)) }
        return result
    }
}

/// Quarter 0, read once per process.
private let hintQuarter0: Result<[HintCertified], any Error> = makeHintQuarter(0)
/// Quarter 1, read once per process.
private let hintQuarter1: Result<[HintCertified], any Error> = makeHintQuarter(1)
/// Quarter 2, read once per process.
private let hintQuarter2: Result<[HintCertified], any Error> = makeHintQuarter(2)
/// Quarter 3, read once per process.
private let hintQuarter3: Result<[HintCertified], any Error> = makeHintQuarter(3)

/// The certified levels of `quarter` (0 … 3).
private func hintQuarter(_ quarter: Int) throws -> [HintCertified] {
    switch quarter {
    case 0: return try hintQuarter0.get()
    case 1: return try hintQuarter1.get()
    case 2: return try hintQuarter2.get()
    default: return try hintQuarter3.get()
    }
}

/// The opening play of `level`: begun, past its tutorial.
private func hintOpening(_ level: MyceliumArchitectLevel) throws -> MyceliumArchitectPlay {
    var play: MyceliumArchitectPlay = MyceliumArchitectPlay(level: level)
    try play.handle(.begin)
    if play.stage == .tutorial { try play.handle(.dismissTutorial) }
    return play
}

/// The board part of `cell`, written here: a column below W / 2 is left, a row below H / 2 upper.
private func expectedQuadrant(_ cell: MyceliumArchitectCell, level: MyceliumArchitectLevel) -> String {
    let upper: Bool = Double(cell.row) < Double(level.height) / 2.0
    let left: Bool = Double(cell.column) < Double(level.width) / 2.0
    return "in the " + (upper ? "upper" : "lower") + " " + (left ? "left" : "right")
}

/// The side of `direction`, written here.
private func expectedSide(_ direction: MyceliumArchitectDirection) -> String {
    if direction == .east { return "to the east" }
    if direction == .west { return "to the west" }
    if direction == .north || direction == .northEast || direction == .northWest { return "towards the top" }
    return "towards the bottom"
}

/// The compass name of `direction`, written here.
private func expectedCompass(_ direction: MyceliumArchitectDirection) -> String {
    let names: [String] = ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
    return names[direction.rawValue]
}

/// The texts of a nutrient, blocker, clear, seed or unseed hint at levels 1, 2 and 3 on `level`, written here
/// independently of the hint engine.
private func expectedHintTexts(_ action: MyceliumArchitectAction, level: MyceliumArchitectLevel) -> [String] {
    switch action {
    case .nutrient(let cell):
        return ["Place a nutrient", "Place a nutrient " + expectedQuadrant(cell, level: level),
                "Place a nutrient at (\(cell.column), \(cell.row))"]
    case .blocker(let cell):
        return ["Place a blocker", "Place a blocker " + expectedQuadrant(cell, level: level),
                "Place a blocker at (\(cell.column), \(cell.row))"]
    case .clear(let cell):
        return ["Clear a placed nutrient or blocker",
                "Clear a placed nutrient or blocker " + expectedQuadrant(cell, level: level),
                "Clear (\(cell.column), \(cell.row))"]
    case .seed(let direction):
        return ["Seed a filament from the root", "Seed a filament from the root " + expectedSide(direction),
                "Seed a filament to the " + expectedCompass(direction)]
    case .unseed(let direction):
        return ["Remove a seeded filament", "Remove a seeded filament " + expectedSide(direction),
                "Remove the filament to the " + expectedCompass(direction)]
    case .run:
        return []
    }
}

/// A number grouped in threes with spaces, written here.
private func expectedGrouped(_ value: Int) -> String {
    let digits: [Character] = Array(String(value))
    var out: String = ""
    for index in digits.indices {
        if index > 0 && (digits.count - index) % 3 == 0 { out += " " }
        out.append(digits[index])
    }
    return out
}

/// The explanation of `failure` on `level`, written here independently of the explanation and of the level's words.
private func expectedExplanation(_ failure: MyceliumArchitectFailure, level: MyceliumArchitectLevel) -> String {
    let sentence: String
    switch failure {
    case .toxic(let pulse, let tip, let cell):
        sentence = "Tip \(tip + 1) grew into toxin at (\(cell.column), \(cell.row)) on pulse \(pulse)."
    case .starved(let pulse, let tip, let cell, let weight, let budget):
        sentence = "Tip \(tip + 1) ran out of nutrient on pulse \(pulse): growing to (\(cell.column), \(cell.row)) "
            + "would make the branch weight \(expectedGrouped(weight)), above the budget of \(expectedGrouped(budget))."
    case .unreached(let terminal):
        let cell: MyceliumArchitectCell = level.terminals[terminal]
        sentence = "Terminal \(terminal + 1) at (\(cell.column), \(cell.row)) was not reached."
    case .overweight(let weight, let limit):
        sentence = "The network's branch weight \(expectedGrouped(weight)) is above the limit of "
            + "\(expectedGrouped(limit))."
    }
    return sentence + " Undo the last action or retry the level."
}

/// The legal moves of `play` (the puzzle contract's, in its order).
private func legalMoves(_ play: MyceliumArchitectPlay) -> [MyceliumArchitectAction] {
    let position: MyceliumArchitectPuzzle.Position =
        MyceliumArchitectPuzzle.Position(arrangement: play.arrangement, actionsSpent: play.actionsSpent)
    return MyceliumArchitectPuzzle(level: play.level).moves(in: position)
}

/// Applies a random legal move to `play`; false when none is legal.
private func applyRandomMove(_ play: inout MyceliumArchitectPlay, _ random: inout SeededRandom) throws -> Bool {
    let moves: [MyceliumArchitectAction] = legalMoves(play)
    guard !moves.isEmpty else { return false }
    try play.apply(moves[random.int(0...(moves.count - 1))], expecting: play.fingerprint)
    return true
}

/// Every arrangement action of `level`, legal or not, written here: a nutrient, a blocker and a clear on every board
/// cell; a seed and an unseed of every direction.
private func bruteCandidates(_ level: MyceliumArchitectLevel) -> [MyceliumArchitectAction] {
    var result: [MyceliumArchitectAction] = []
    for row in 0..<level.height {
        for column in 0..<level.width {
            let cell: MyceliumArchitectCell = MyceliumArchitectCell(column: column, row: row)
            result.append(.nutrient(cell))
            result.append(.blocker(cell))
            result.append(.clear(cell))
        }
    }
    for raw in 0..<8 {
        let direction: MyceliumArchitectDirection = MyceliumArchitectDirection(rawValue: raw) ?? .north
        result.append(.seed(direction))
        result.append(.unseed(direction))
    }
    return result
}

/// The independent brute force: every arrangement reachable from `arrangement` within min(`actionsLeft`, 2) actions
/// the kernel accepts; the length of the shortest winning sequence (nil: none) and the distinct arrangements reached
/// (the whole space when no win exists; the exploration stops at the first win of the shortest length).
private func bruteShortest(_ level: MyceliumArchitectLevel, from arrangement: MyceliumArchitectArrangement,
                           actionsLeft: Int) -> (length: Int?, space: Int) {
    let cap: Int = min(2, actionsLeft)
    guard cap >= 1 else { return (nil, 0) }
    let candidates: [MyceliumArchitectAction] = bruteCandidates(level)
    var reached: Set<MyceliumArchitectArrangement> = []
    var firsts: [MyceliumArchitectArrangement] = []
    var found: Int? = nil
    for action in candidates {
        guard let next = try? MyceliumArchitectPlay.changed(level, arrangement, by: action) else { continue }
        firsts.append(next)
        reached.insert(next)
        if found == nil && MyceliumArchitectGrowth.report(level, arrangement: next).wins { found = 1 }
    }
    guard cap >= 2, found == nil else { return (found, reached.count) }
    for middle in firsts {
        for action in candidates {
            guard let next = try? MyceliumArchitectPlay.changed(level, middle, by: action) else { continue }
            if next == arrangement || reached.contains(next) { continue }
            reached.insert(next)
            if MyceliumArchitectGrowth.report(level, arrangement: next).wins { return (2, reached.count) }
        }
    }
    return (nil, reached.count)
}

/// The search of clarification Q1 written here on the puzzle contract (`moves(in:)` and `apply(_:to:)`): the first
/// winning sequence of one, else two, legal moves within min(actions left, 2), each new arrangement judged once (the
/// current one never), and the arrangements judged; no bound.
private func referenceSearch(_ play: MyceliumArchitectPlay) -> (actions: [MyceliumArchitectAction]?, work: Int) {
    let puzzle: MyceliumArchitectPuzzle = MyceliumArchitectPuzzle(level: play.level)
    let current: MyceliumArchitectPuzzle.Position =
        MyceliumArchitectPuzzle.Position(arrangement: play.arrangement, actionsSpent: play.actionsSpent)
    var seen: Set<MyceliumArchitectArrangement> = [play.arrangement]
    var work: Int = 0
    let firsts: [MyceliumArchitectAction] = puzzle.moves(in: current)
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

/// Whether every item of `part` lies between `start` and `target` (start ∩ target ⊆ part ⊆ start ∪ target), written
/// here with plain loops.
private func liesBetween<Item: Equatable>(_ part: [Item], start: [Item], target: [Item]) -> Bool {
    for item in start where target.contains(item) && !part.contains(item) { return false }
    for item in part where !start.contains(item) && !target.contains(item) { return false }
    return true
}

/// Whether `arrangement` lies on the way from `start` to `target` for nutrients, blockers and seeds, written here.
private func liesOnTheWay(_ arrangement: MyceliumArchitectArrangement, start: MyceliumArchitectArrangement,
                          target: MyceliumArchitectArrangement) -> Bool {
    liesBetween(arrangement.nutrients, start: start.nutrients, target: target.nutrients)
        && liesBetween(arrangement.blockers, start: start.blockers, target: target.blockers)
        && liesBetween(arrangement.seeds, start: start.seeds, target: target.seeds)
}

/// The arrangement the certified actions reach from `level`'s start.
private func certifiedTarget(_ certified: HintCertified) throws -> MyceliumArchitectArrangement {
    var play: MyceliumArchitectPlay = try hintOpening(certified.level)
    for action in certified.changes { try play.apply(action, expecting: play.fingerprint) }
    return play.arrangement
}

/// A random legal move of `play` that leaves the way to `target`, or nil.
private func offMove(_ play: MyceliumArchitectPlay, target: MyceliumArchitectArrangement,
                     _ random: inout SeededRandom) -> MyceliumArchitectAction? {
    var off: [MyceliumArchitectAction] = []
    for move in legalMoves(play) {
        guard let next = try? MyceliumArchitectPlay.changed(play.level, play.arrangement, by: move) else { continue }
        if !liesOnTheWay(next, start: play.level.start, target: target) { off.append(move) }
    }
    guard !off.isEmpty else { return nil }
    return off[random.int(0...(off.count - 1))]
}

/// Follows exact (level 3) hints from `start` until the play ends, running the growth when hinted; the problems found
/// (empty: won, every hinted action accepted, every text as written here, the play unchanged by every hint) and the
/// actions spent following them.
private func followHints(_ start: MyceliumArchitectPlay, certified: [MyceliumArchitectAction]?,
                         label: String) -> (problems: [String], spent: Int) {
    var play: MyceliumArchitectPlay = start
    let spentBefore: Int = play.actionsSpent
    for _ in 0..<30 {
        if play.stage == .won { return ([], play.actionsSpent - spentBefore) }
        let before: MyceliumArchitectPlay = play
        let fingerprint: String = play.fingerprint
        guard let hint = MyceliumArchitectHints.hint(level: 3, play: play, certified: certified) else {
            return (["\(label): no hint in \(play.stage)"], play.actionsSpent - spentBefore)
        }
        guard play == before, play.fingerprint == fingerprint else {
            return (["\(label): the hint changed the play"], play.actionsSpent - spentBefore)
        }
        guard let action = hint.action else {
            return (["\(label): \(hint.kind) with \(play.actionsLeft) actions left"], play.actionsSpent - spentBefore)
        }
        if action != .run {
            let texts: [String] = expectedHintTexts(action, level: play.level)
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
private let hintCauseCodes: [String] = ["toxic", "starved", "unreached", "overweight"]

/// The legal moves of `play` whose arrangement fails with `cause`.
private func aimedMoves(_ play: MyceliumArchitectPlay, cause: String) -> [MyceliumArchitectAction] {
    var aimed: [MyceliumArchitectAction] = []
    for move in legalMoves(play) {
        guard let next = try? MyceliumArchitectPlay.changed(play.level, play.arrangement, by: move) else { continue }
        if MyceliumArchitectGrowth.report(play.level, arrangement: next).failure?.code == cause { aimed.append(move) }
    }
    return aimed
}

@Suite struct MyceliumArchitectHintsTests {
    /// The seed of this feature's draws.
    static let seed: UInt64 = 2_515

    // MARK: Certified plans

    @Test func storedWitnessesAreTheCertifiedPlansOfLevels1To3() throws {
        for number in 1...3 {
            let generated: MyceliumArchitectGeneratedLevel = try MyceliumArchitectExperienceCore.generated(number: number)
            let stored: HintCertified = try hintQuarter(0)[number - 1]
            #expect(stored.number == number)
            #expect(stored.level == generated.level, "level \(number)")
            var changes: [MyceliumArchitectAction] = []
            for action in generated.solution.actions where action != .run { changes.append(action) }
            #expect(stored.changes == changes, "level \(number)")
            #expect(generated.solution.actions.last == .run)
        }
    }

    // MARK: Exact hints from every opening

    /// Exact hints from every opening of `quarter` replay the certified witness and win within the certified count.
    func exactHintsWin(quarter: Int) throws {
        let levels: [HintCertified] = try hintQuarter(quarter)
        #expect(levels.count == 25)
        for certified in levels {
            let number: Int = certified.number
            let opening: MyceliumArchitectPlay = try hintOpening(certified.level)
            let plan: MyceliumArchitectHintPlan? = MyceliumArchitectHints.plan(opening, certified: certified.changes)
            #expect(plan == MyceliumArchitectHintPlan(actions: certified.changes), "level \(number): plan")
            let first: MyceliumArchitectAction = try #require(certified.changes.first)
            let texts: [String] = expectedHintTexts(first, level: certified.level)
            for hintLevel in 1...3 {
                let hint: MyceliumArchitectHint? = MyceliumArchitectHints.hint(level: hintLevel, play: opening,
                                                                               certified: certified.changes)
                #expect(hint?.text == texts[hintLevel - 1], "level \(number): text at hint level \(hintLevel)")
                #expect(hint?.action == first)
                #expect(hint?.level == hintLevel)
                #expect(hint?.kind == MyceliumArchitectHint.kind(of: first))
            }
            let followed: (problems: [String], spent: Int) =
                followHints(opening, certified: certified.changes, label: "level \(number)")
            #expect(followed.problems.isEmpty, "\(followed.problems)")
            #expect(followed.spent == certified.changes.count, "level \(number): spent \(followed.spent)")
            #expect(followed.spent <= certified.level.budget)
        }
    }

    @Test func exactHintsFromTheOpeningWinLevels1To25() throws { try exactHintsWin(quarter: 0) }

    @Test func exactHintsFromTheOpeningWinLevels26To50() throws { try exactHintsWin(quarter: 1) }

    @Test func exactHintsFromTheOpeningWinLevels51To75() throws { try exactHintsWin(quarter: 2) }

    @Test func exactHintsFromTheOpeningWinLevels76To100() throws { try exactHintsWin(quarter: 3) }

    // MARK: Seeded reachable states

    /// 25 seeded reachable states of `quarter` (`half` 0 or 1 of its 50): every exact hint is accepted by the kernel
    /// and following the plan wins.
    func reachableStates(quarter: Int, half: Int) throws {
        let levels: [HintCertified] = try hintQuarter(quarter)
        var random: SeededRandom = SeededRandom(seed: Self.seed + UInt64(2 * quarter + half))
        var stuck: Int = 0
        for index in 0..<25 {
            let certified: HintCertified = levels[random.int(0...24)]
            let label: String = "state \(index) of level \(certified.number)"
            var play: MyceliumArchitectPlay = try hintOpening(certified.level)
            let count: Int = random.int(0...4)
            for _ in 0..<count {
                if try !applyRandomMove(&play, &random) { break }
            }
            if random.int(0...3) == 0 && play.canUndo { try play.undo() }
            let before: MyceliumArchitectPlay = play
            let fingerprint: String = play.fingerprint
            let hint: MyceliumArchitectHint = try #require(MyceliumArchitectHints.hint(level: 3, play: play,
                                                                                       certified: certified.changes))
            #expect(play == before && play.fingerprint == fingerprint, "\(label): the hint changed the play")
            switch hint.kind {
            case .run:
                #expect(play.report.wins, "\(label): run hinted on a losing arrangement")
                #expect(hint.action == .run && hint.text == MyceliumArchitectHint.runText)
            case .stuck:
                stuck += 1
                let brute: (length: Int?, space: Int) =
                    bruteShortest(play.level, from: play.arrangement, actionsLeft: play.actionsLeft)
                #expect(brute.length == nil, "\(label): stuck although a win exists")
                #expect(hint.action == nil && hint.text == MyceliumArchitectHint.stuckText)
            case .retry:
                Issue.record("\(label): retry while playing")
            case .nutrient, .blocker, .clear, .seed, .unseed:
                let action: MyceliumArchitectAction = try #require(hint.action)
                #expect(hint.kind == MyceliumArchitectHint.kind(of: action))
                let texts: [String] = expectedHintTexts(action, level: play.level)
                #expect(hint.text == texts[2], "\(label): exact text")
                for hintLevel in 1...2 {
                    let shown: String? = MyceliumArchitectHint.actionText(level: hintLevel, action: action,
                                                                          on: play.level)
                    #expect(shown == texts[hintLevel - 1], "\(label): text at hint level \(hintLevel)")
                }
                var accepted: MyceliumArchitectPlay = play
                do {
                    try accepted.apply(action, expecting: accepted.fingerprint)
                } catch {
                    Issue.record("\(label): hinted \(action) refused: \(error)")
                }
            }
            if hint.kind != .stuck {
                // The hint is the plan's first action, and the plan then the run wins within the actions left.
                let plan: MyceliumArchitectHintPlan =
                    try #require(MyceliumArchitectHints.plan(play, certified: certified.changes))
                #expect(plan.actions.first ?? .run == hint.action, "\(label): the hint is not the plan's first action")
                #expect(plan.actions.count <= play.actionsLeft)
                var replay: MyceliumArchitectPlay = play
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

    /// Draws a failed play of `levels`: aimed at `cause` by one move from the opening, a witness prefix or the
    /// certified arrangement (two moves from the certified arrangement when no one-move change fails that way), else
    /// random legal moves, some undone and redone, then the run. Nil when the draw wins or no aimed move exists.
    fileprivate func drawFailure(_ levels: [HintCertified], cause: String?,
                     _ random: inout SeededRandom) throws -> MyceliumArchitectPlay? {
        let certified: HintCertified = levels[random.int(0...24)]
        var play: MyceliumArchitectPlay = try hintOpening(certified.level)
        if let cause {
            // The prefixes of the witness, tried from a random one onwards.
            let prefixes: Int = certified.changes.count + 1
            let startPrefix: Int = random.int(0...(prefixes - 1))
            var chosen: MyceliumArchitectPlay? = nil
            var aimed: [MyceliumArchitectAction] = []
            for offset in 0..<prefixes {
                let prefix: Int = (startPrefix + offset) % prefixes
                var candidate: MyceliumArchitectPlay = try hintOpening(certified.level)
                for step in 0..<prefix { try candidate.apply(certified.changes[step], expecting: candidate.fingerprint) }
                let moves: [MyceliumArchitectAction] = aimedMoves(candidate, cause: cause)
                if !moves.isEmpty {
                    chosen = candidate
                    aimed = moves
                    break
                }
            }
            if let chosen {
                play = chosen
            } else {
                // Two moves from the certified arrangement.
                for action in certified.changes { try play.apply(action, expecting: play.fingerprint) }
                var firsts: [MyceliumArchitectAction] = []
                for move in legalMoves(play) {
                    var middle: MyceliumArchitectPlay = play
                    try middle.apply(move, expecting: middle.fingerprint)
                    if !aimedMoves(middle, cause: cause).isEmpty { firsts.append(move) }
                }
                guard !firsts.isEmpty else { return nil }
                try play.apply(firsts[random.int(0...(firsts.count - 1))], expecting: play.fingerprint)
                aimed = aimedMoves(play, cause: cause)
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

    /// 125 seeded failures of `quarter`, every fifth aimed at a cause in turn: all four causes appear and each is
    /// explained with its true values.
    func seededFailures(quarter: Int) throws {
        let levels: [HintCertified] = try hintQuarter(quarter)
        var random: SeededRandom = SeededRandom(seed: Self.seed + 100 + UInt64(quarter))
        var failures: Int = 0
        var draws: Int = 0
        var causes: [String: Int] = [:]
        while failures < 125 && draws < 5_000 {
            draws += 1
            let cause: String? = failures % 5 == 0 ? hintCauseCodes[(failures / 5) % 4] : nil
            guard let play = try drawFailure(levels, cause: cause, &random) else { continue }
            let failure: MyceliumArchitectFailure = try #require(play.failure)
            let level: MyceliumArchitectLevel = play.level
            let report: MyceliumArchitectReport = MyceliumArchitectGrowth.report(level, arrangement: play.arrangement)
            #expect(report.failure == failure, "the failure differs from the judged one")
            switch failure {
            case .toxic(let pulse, let tip, let cell):
                #expect(level.toxins.contains(cell))
                let last: MyceliumArchitectStep? = report.steps.last
                #expect(last?.pulse == pulse && last?.tip == tip && last?.to == cell)
                #expect(pulse == report.pulsesRun)
            case .starved(let pulse, let tip, let cell, let weight, let budget):
                #expect(budget == level.nutrientBudget && weight > budget)
                let added: Int = weight - report.totalWeight
                #expect(added == MyceliumArchitectGrowth.orthogonalWeight
                    || added == MyceliumArchitectGrowth.diagonalWeight)
                #expect(pulse == report.pulsesRun && tip >= 0)
                #expect(level.contains(cell))
            case .unreached(let terminal):
                #expect(level.terminals.indices.contains(terminal))
                #expect(report.terminalPulses[terminal] == nil)
                for earlier in 0..<terminal { #expect(report.terminalPulses[earlier] != nil) }
            case .overweight(let weight, let limit):
                #expect(weight == report.totalWeight && limit == level.weightLimit && weight > limit)
                for pulse in report.terminalPulses { #expect(pulse != nil) }
            }
            let before: MyceliumArchitectPlay = play
            let explanation: MyceliumArchitectFailureExplanation =
                try #require(MyceliumArchitectFailureExplanation(play: play))
            #expect(explanation.failure == failure)
            #expect(explanation.text == expectedExplanation(failure, level: level))
            for hintLevel in 1...3 {
                let hint: MyceliumArchitectHint? = MyceliumArchitectHints.hint(level: hintLevel, play: play,
                                                                               certified: nil)
                #expect(hint?.kind == .retry && hint?.action == nil && hint?.text == MyceliumArchitectHint.failedText)
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

    /// States off the certified path on every other level of `quarter` from index `half`: the plan agrees with the
    /// brute force.
    func offPath(quarter: Int, half: Int) throws {
        var random: SeededRandom = SeededRandom(seed: Self.seed + 200 + UInt64(2 * quarter + half))
        var fromCertified: Int = 0
        var found: Int = 0
        let levels: [HintCertified] = try hintQuarter(quarter)
        for index in stride(from: half, to: 25, by: 2) {
            let certified: HintCertified = levels[index]
            let target: MyceliumArchitectArrangement = try certifiedTarget(certified)
            let changes: [MyceliumArchitectAction] = certified.changes
            for kind in 0..<3 {
                var play: MyceliumArchitectPlay = try hintOpening(certified.level)
                let prefix: Int = kind == 0 ? 0 : (kind == 1 ? changes.count : changes.count - 1)
                for step in 0..<prefix { try play.apply(changes[step], expecting: play.fingerprint) }
                guard let move = offMove(play, target: target, &random) else { continue }
                try play.apply(move, expecting: play.fingerprint)
                let label: String = "level \(certified.number) kind \(kind)"
                #expect(!liesOnTheWay(play.arrangement, start: certified.level.start, target: target))
                if play.report.wins {
                    #expect(MyceliumArchitectHints.plan(play, certified: changes)?.actions == [])
                    continue
                }
                let before: MyceliumArchitectPlay = play
                let brute: (length: Int?, space: Int) =
                    bruteShortest(play.level, from: play.arrangement, actionsLeft: play.actionsLeft)
                #expect(brute.space <= 1_190, "\(label): two-action space \(brute.space)")
                let plan: MyceliumArchitectHintPlan? = MyceliumArchitectHints.plan(play, certified: changes)
                #expect(play == before, "\(label): the plan changed the play")
                #expect(plan?.actions.count == brute.length, "\(label): plan \(String(describing: plan))")
                if kind == 1 {
                    fromCertified += 1
                    #expect(plan != nil, "\(label): no plan one move off the certified arrangement")
                }
                guard let plan else { continue }
                found += 1
                var replay: MyceliumArchitectPlay = play
                for action in plan.actions { try replay.apply(action, expecting: replay.fingerprint) }
                try replay.apply(.run, expecting: replay.fingerprint)
                #expect(replay.stage == .won, "\(label): the plan does not win")
            }
        }
        #expect(fromCertified >= 3, "only \(fromCertified) states one move off the certified arrangement")
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
        #expect(MyceliumArchitectHints.workBound == 2_000)
        let levels: [HintCertified] = try hintQuarter(2)
        var random: SeededRandom = SeededRandom(seed: Self.seed + 300)
        var checked: Int = 0
        var exhausted: Int = 0
        var largest: Int = 0
        for certified in levels {
            let target: MyceliumArchitectArrangement = try certifiedTarget(certified)
            var play: MyceliumArchitectPlay = try hintOpening(certified.level)
            for action in certified.changes { try play.apply(action, expecting: play.fingerprint) }
            guard let move = offMove(play, target: target, &random) else { continue }
            try play.apply(move, expecting: play.fingerprint)
            if play.report.wins { continue }
            let full: (plan: MyceliumArchitectHintPlan?, work: Int) =
                MyceliumArchitectHints.search(play, workBound: Int.max)
            let plan: MyceliumArchitectHintPlan = try #require(full.plan)
            #expect(full.work >= 1 && full.work <= 1_190)
            largest = max(largest, full.work)
            let reference: (actions: [MyceliumArchitectAction]?, work: Int) = referenceSearch(play)
            #expect(plan.actions == reference.actions && full.work == reference.work, "the search differs")
            #expect(MyceliumArchitectHints.plan(play, certified: certified.changes) == plan)
            #expect(MyceliumArchitectHints.plan(play, certified: certified.changes, workBound: full.work) == plan)
            #expect(MyceliumArchitectHints.plan(play, certified: certified.changes, workBound: full.work - 1) == nil)
            #expect(MyceliumArchitectHints.plan(play, certified: certified.changes, workBound: 0) == nil)
            checked += 1
            // A state whose whole two-action space holds no win: the search judges all of it, so any bound refuses.
            var lost: MyceliumArchitectPlay = try hintOpening(certified.level)
            if try !applyRandomMove(&lost, &random) { continue }
            let brute: (length: Int?, space: Int) =
                bruteShortest(lost.level, from: lost.arrangement, actionsLeft: lost.actionsLeft)
            if brute.length == nil && !liesOnTheWay(lost.arrangement, start: certified.level.start, target: target) {
                let searched: (plan: MyceliumArchitectHintPlan?, work: Int) =
                    MyceliumArchitectHints.search(lost, workBound: Int.max)
                #expect(searched.plan == nil && searched.work == brute.space)
                #expect(searched.work <= 1_190)
                largest = max(largest, searched.work)
                #expect(MyceliumArchitectHints.search(lost, workBound: brute.space - 1).work == brute.space - 1)
                #expect(MyceliumArchitectHints.plan(lost, certified: certified.changes) == nil)
                exhausted += 1
            }
        }
        #expect(checked >= 10)
        #expect(exhausted >= 1, "no state without a win in two actions")
        print("MyceliumArchitectHintsTests: largest search work \(largest), exhausted \(exhausted)")
    }

    // MARK: Stages, hints never change the play

    @Test func hintsFollowTheStagesAndNeverChangeThePlay() throws {
        let certified: HintCertified = try hintQuarter(0)[0]
        let level: MyceliumArchitectLevel = certified.level
        #expect(level.tutorial)
        var play: MyceliumArchitectPlay = MyceliumArchitectPlay(level: level)
        #expect(MyceliumArchitectHints.hint(level: 1, play: play, certified: certified.changes) == nil)
        #expect(MyceliumArchitectHints.plan(play, certified: certified.changes) == nil)
        try play.handle(.begin)
        #expect(play.stage == .tutorial)
        #expect(MyceliumArchitectHints.hint(level: 1, play: play, certified: certified.changes) == nil)
        try play.handle(.dismissTutorial)
        let opening: MyceliumArchitectPlay = play
        var actions: [MyceliumArchitectAction?] = []
        for hintLevel in 0...4 {
            let hint: MyceliumArchitectHint? = MyceliumArchitectHints.hint(level: hintLevel, play: play,
                                                                           certified: certified.changes)
            #expect(hint?.level == min(3, max(1, hintLevel)))
            actions.append(hint?.action)
            #expect(play == opening && play.fingerprint == opening.fingerprint)
        }
        for action in actions { #expect(action == actions[0] && action != nil) }
        #expect(MyceliumArchitectFailureExplanation(play: play) == nil)
        try play.handle(.pause)
        #expect(MyceliumArchitectHints.hint(level: 2, play: play, certified: certified.changes) == nil)
        try play.handle(.resume)
        // Winning: the run hint, then no hint once won and in the result.
        var won: MyceliumArchitectPlay = play
        for action in certified.changes { try won.apply(action, expecting: won.fingerprint) }
        let runHint: MyceliumArchitectHint? = MyceliumArchitectHints.hint(level: 1, play: won,
                                                                          certified: certified.changes)
        #expect(runHint?.kind == .run && runHint?.action == .run && runHint?.text == MyceliumArchitectHint.runText)
        #expect(MyceliumArchitectHints.plan(won, certified: certified.changes) == MyceliumArchitectHintPlan(actions: []))
        try won.apply(.run, expecting: won.fingerprint)
        #expect(won.stage == .won)
        #expect(MyceliumArchitectHints.hint(level: 3, play: won, certified: certified.changes) == nil)
        #expect(MyceliumArchitectFailureExplanation(play: won) == nil)
        try won.handle(.showResult)
        #expect(MyceliumArchitectHints.hint(level: 3, play: won, certified: certified.changes) == nil)
        #expect(MyceliumArchitectFailureExplanation(play: won) == nil)
        // Failing: the retry advice in failed and in the result.
        var failed: MyceliumArchitectPlay = play
        try failed.apply(.run, expecting: failed.fingerprint)
        #expect(failed.stage == .failed)
        let failedBefore: MyceliumArchitectPlay = failed
        let retry: MyceliumArchitectHint? = MyceliumArchitectHints.hint(level: 2, play: failed,
                                                                        certified: certified.changes)
        #expect(retry?.kind == .retry && retry?.action == nil && retry?.text == MyceliumArchitectHint.failedText)
        let explanation: MyceliumArchitectFailureExplanation? = MyceliumArchitectFailureExplanation(play: failed)
        #expect(explanation != nil)
        #expect(failed == failedBefore)
        try failed.handle(.showResult)
        #expect(MyceliumArchitectHints.hint(level: 1, play: failed, certified: certified.changes)?.kind == .retry)
        #expect(MyceliumArchitectFailureExplanation(play: failed) == explanation)
        #expect(MyceliumArchitectHints.plan(failed, certified: certified.changes) == nil)
        // Without a certified plan the search still finds the one-action witness of level 1.
        #expect(MyceliumArchitectHints.plan(opening, certified: nil)?.actions.count == 1)
    }

    @Test func noActionLeftOnALosingArrangementIsStuck() throws {
        let certified: HintCertified = try hintQuarter(0)[0]
        var play: MyceliumArchitectPlay = try hintOpening(certified.level)
        while play.actionsLeft > 0 {
            var chosen: MyceliumArchitectAction? = nil
            for move in legalMoves(play) {
                guard let next = try? MyceliumArchitectPlay.changed(play.level, play.arrangement, by: move) else {
                    continue
                }
                if !MyceliumArchitectGrowth.report(play.level, arrangement: next).wins {
                    chosen = move
                    break
                }
            }
            let move: MyceliumArchitectAction = try #require(chosen)
            try play.apply(move, expecting: play.fingerprint)
        }
        #expect(!play.report.wins)
        #expect(MyceliumArchitectHints.plan(play, certified: certified.changes) == nil)
        for hintLevel in 1...3 {
            let hint: MyceliumArchitectHint? = MyceliumArchitectHints.hint(level: hintLevel, play: play,
                                                                           certified: certified.changes)
            #expect(hint?.kind == .stuck && hint?.action == nil && hint?.text == MyceliumArchitectHint.stuckText)
        }
        #expect(MyceliumArchitectHint.stuckText
            == "No way to win was found in the actions left: undo the last action or retry the level.")
    }

    // MARK: Texts

    @Test func hintTextsNameTheKindThePlaceAndTheExactAction() throws {
        let level: MyceliumArchitectLevel = try hintQuarter(0)[0].level
        let width: Int = level.width
        let height: Int = level.height
        // The four corners and the centre lines (a column of exactly W / 2 is right, a row of exactly H / 2 lower).
        let upperLeft: MyceliumArchitectCell = MyceliumArchitectCell(column: 0, row: 0)
        let upperRight: MyceliumArchitectCell = MyceliumArchitectCell(column: width - 1, row: 0)
        let lowerLeft: MyceliumArchitectCell = MyceliumArchitectCell(column: 0, row: height - 1)
        let lowerRight: MyceliumArchitectCell = MyceliumArchitectCell(column: width - 1, row: height - 1)
        let quadrants: [(MyceliumArchitectCell, String)] = [
            (upperLeft, "in the upper left"), (upperRight, "in the upper right"),
            (lowerLeft, "in the lower left"), (lowerRight, "in the lower right"),
        ]
        for (cell, words) in quadrants {
            #expect(MyceliumArchitectHint.quadrantWords(cell, on: level) == words)
            #expect(expectedQuadrant(cell, level: level) == words)
        }
        for row in 0..<height {
            for column in 0..<width {
                let cell: MyceliumArchitectCell = MyceliumArchitectCell(column: column, row: row)
                #expect(MyceliumArchitectHint.quadrantWords(cell, on: level) == expectedQuadrant(cell, level: level))
            }
        }
        let cell: MyceliumArchitectCell = MyceliumArchitectCell(column: 1, row: height - 1)
        let cases: [(MyceliumArchitectAction, [String])] = [
            (.nutrient(cell), ["Place a nutrient", "Place a nutrient in the lower left",
                               "Place a nutrient at (1, \(height - 1))"]),
            (.blocker(upperRight), ["Place a blocker", "Place a blocker in the upper right",
                                    "Place a blocker at (\(width - 1), 0)"]),
            (.clear(lowerRight), ["Clear a placed nutrient or blocker",
                                  "Clear a placed nutrient or blocker in the lower right",
                                  "Clear (\(width - 1), \(height - 1))"]),
            (.seed(.northEast), ["Seed a filament from the root", "Seed a filament from the root towards the top",
                                 "Seed a filament to the north-east"]),
            (.seed(.south), ["Seed a filament from the root", "Seed a filament from the root towards the bottom",
                             "Seed a filament to the south"]),
            (.seed(.east), ["Seed a filament from the root", "Seed a filament from the root to the east",
                            "Seed a filament to the east"]),
            (.unseed(.west), ["Remove a seeded filament", "Remove a seeded filament to the west",
                              "Remove the filament to the west"]),
            (.unseed(.northWest), ["Remove a seeded filament", "Remove a seeded filament towards the top",
                                   "Remove the filament to the north-west"]),
            (.unseed(.southWest), ["Remove a seeded filament", "Remove a seeded filament towards the bottom",
                                   "Remove the filament to the south-west"]),
        ]
        for (action, texts) in cases {
            #expect(expectedHintTexts(action, level: level) == texts)
            for hintLevel in 1...3 {
                let text: String? = MyceliumArchitectHint.actionText(level: hintLevel, action: action, on: level)
                #expect(text == texts[hintLevel - 1], "\(action) at \(hintLevel)")
            }
            #expect(MyceliumArchitectHint.actionText(level: 0, action: action, on: level) == texts[0])
            #expect(MyceliumArchitectHint.actionText(level: 9, action: action, on: level) == texts[2])
        }
        for raw in 0..<8 {
            let direction: MyceliumArchitectDirection = try #require(MyceliumArchitectDirection(rawValue: raw))
            #expect(MyceliumArchitectHint.sideWords(direction) == expectedSide(direction))
            #expect(expectedCompass(direction) == direction.words)
        }
        let off: MyceliumArchitectCell = MyceliumArchitectCell(column: width, row: 0)
        #expect(MyceliumArchitectHint.actionText(level: 3, action: .nutrient(off), on: level) == nil)
        #expect(MyceliumArchitectHint.actionText(level: 3, action: .run, on: level) == nil)
        #expect(MyceliumArchitectHint.runText == "Every terminal is reached within the limits: run the growth")
        #expect(MyceliumArchitectHint.failedText == "Undo the last action or retry the level.")
        let kinds: [String] = ["nutrient", "blocker", "clear", "seed", "unseed", "run", "stuck", "retry"]
        let values: [MyceliumArchitectHintKind] = [.nutrient, .blocker, .clear, .seed, .unseed, .run, .stuck, .retry]
        for index in kinds.indices { #expect(values[index].rawValue == kinds[index]) }
    }

    @Test func failureSentencesUseTheWordingsOfTheSpec() throws {
        let level: MyceliumArchitectLevel = try hintQuarter(0)[0].level
        let terminal: MyceliumArchitectCell = level.terminals[0]
        #expect(MyceliumArchitectFailureExplanation.advice == "Undo the last action or retry the level.")
        let cell: MyceliumArchitectCell = MyceliumArchitectCell(column: 5, row: 6)
        let cases: [(MyceliumArchitectFailure, String)] = [
            (.toxic(pulse: 9, tip: 2, cell: cell), "Tip 3 grew into toxin at (5, 6) on pulse 9."),
            (.starved(pulse: 4, tip: 0, cell: cell, weight: 1_050, budget: 1_048),
             "Tip 1 ran out of nutrient on pulse 4: growing to (5, 6) would make the branch weight 1 050, above the "
                + "budget of 1 048."),
            (.unreached(terminal: 0),
             "Terminal 1 at (\(terminal.column), \(terminal.row)) was not reached."),
            (.overweight(weight: 1_234, limit: 999), "The network's branch weight 1 234 is above the limit of 999."),
        ]
        for (failure, sentence) in cases {
            #expect(MyceliumArchitectFailureExplanation.sentence(failure, level: level) == sentence)
            #expect(expectedExplanation(failure, level: level) == sentence + " Undo the last action or retry the level.")
        }
        #expect(MyceliumArchitectFailureExplanation.sentence(.unreached(terminal: level.terminals.count),
                                                             level: level) == nil)
    }
}
