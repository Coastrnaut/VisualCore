// AcousticConstellatorScenarios — feature 423 (R02-G13-03) T-R02G1303-006 (FR-R02G1303-005; clarification Q5). The
// scenarios the verification runner plays for Acoustic Constellator, a round-two game, all short (owner rule of
// 2026-11-13), on the pattern of Harmonic Bridges' (feature 413):
//   - the nine standard scenarios and the two a game needs (`full-playthrough`, `hero`), prepared with seed 0, which
//     opens certified level 1 (`seed % 100 + 1`);
//   - the 80 acceptance scenarios `acceptance-001` … `acceptance-080`, one per row R2-G13-QA-001 … 080 of the archived
//     acceptance matrix (docs/archive/planning/rounds/round2.md), each with the seed of its level;
//   - three fixtures: `fixture-level-1-solved` (the certified witness of level 1, outcome `won`),
//     `fixture-budget-out` (the first certified pair linked and unlinked until the budget is spent, the last action
//     failing the play `budget`, outcome `failed`) and `fixture-undo-redo` (the first certified link, its undo and its
//     redo).
// Every certified action comes from the generated level's plan (`AcousticConstellatorGenerated.actions`, equal to the
// stored witness `docs/games/acoustic-constellator/levels/NNN.witness.json`: the plan's links in pair order, its nudges
// in star order, then one listen), so a regenerated catalog cannot leave a stale script. The two input actions link the
// first certified pair and unlink it again (neither listens, so neither decides; with a budget above 2, neither fails);
// input-response, save-restore and reset play both and undo the second; completion plays the certified witness of
// level 1 and expects `won`; full-playthrough solves levels 1, 2 and 3 with `level.next` between them; hero plays the
// certified moves of level 1 without the listen, so the picture shows the symbol linked while the play is still open;
// rejection refuses values outside the declared ranges, fractional values, actions the kernel refuses (a star the level
// lacks, a self link, an existing link, removing a missing or a fixed link, a nudge step of 0, an undo or redo with
// nothing to revert) and wrong value counts (never an undeclared control: the content audit forbids one in a manifest).
//
// The acceptance rows name level (7 × (r − 1) + 46) mod 100 + 1 for rows 1 … 20 (047, 054, … 096, 003, … 080); the
// same formula gives rows 21 … 80 their level, so the 80 rows visit 80 distinct levels (7 is prime to 100), each
// opened with seed `level − 1`. The rows come in eight families of ten (the matrix's areas), each scripted on the real
// controls with the outcome the kernel gives:
//   1 … 10  truth and state transitions — a legal command then an illegal one; the pair follows the row's command and
//           condition (r − 1) mod 5: the first certified link, then a link to a star the level lacks (a self link on
//           an eight-star level) refused `r02-g13.action`; the first certified link, then star 8 refused out of range;
//           the first certified link twice, the second refused `r02-g13.action` (it exists); the first certified link,
//           then star 1.5 refused `r02-g13.not-whole`; a listen at the opening (failed `missing`), then a link refused
//           `r02-g13.stage`;
//  11 … 20  solver witness and rejection — odd rows: the certified moves without one (the last whose omission fails
//           the listen other than `missing`, else the last), a listen (failed: the minimal plan has no smaller winning
//           set), an undo, the omitted move and a listen (won); even rows: the certified moves, then the first certified
//           pair unlinked and linked until the budget is spent (failed `budget`), then a listen refused `r02-g13.stage`;
//  21 … 30  numeric and geometry edges — star 0 nudged by −1 and the highest star by +1 (the step and star endpoints;
//           a phase of 0 wraps to 11), then a step of −2 (odd rows) or star 8 (even rows) refused out of range, star −1
//           refused out of range, a step of 0 refused `r02-g13.action`, a star the level lacks refused `r02-g13.action`
//           (when the level has fewer than 8 stars), then two undos back to the opening digest;
//  31 … 40  touch and camera semantics — the first certified link, undo, redo (the linked digest again), then a second
//           redo refused `r02-g13.action`;
//  41 … 50  rendering — the certified witness (won, the links brightened; the digest is the same at every quality
//           tier), then an undo refused `r02-g13.stage` (a won play is final);
//  51 … 60  accessibility and safety — odd rows: a listen at the opening (failed `missing`, the outline names the
//           missing guide); even rows: the certified moves without one (as rows 11 … 20) and a listen (failed); then an
//           undo, an honest retry back to the digest before the listen;
//  61 … 70  persistence and replay — the first certified link, undo, redo, then the rest of the witness (won; the
//           saved trace replays to the same state);
//  71 … 80  integration — `level.next` (the next certified level, a fresh play), its first certified link, an undo
//           (the next level's opening digest) and a second undo refused `r02-g13.action`.
// The expected digests and outcomes are derived by playing the entries on a core exactly as the engine plays them; the
// tests replay every scenario through `ExperienceEngine` and check each family's kernel state. No clock, no random
// source.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import VisualCoreExperience

extension AcousticConstellatorExperienceCore {
    /// The seed of every standard scenario: it opens certified level 1.
    public static let manifestSeed: UInt64 = 0
    /// The round of the game in the scenario manifest.
    public static let manifestRound = 2
    /// The levels `full-playthrough` solves in order, with `level.next` between them.
    public static let playthroughLevels: [Int] = [1, 2, 3]
    /// The number of acceptance rows (R2-G13-QA-001 … 080).
    public static let acceptanceRows = 80
    /// The rows of one acceptance family (the matrix's areas come in blocks of ten).
    public static let acceptanceFamilySize = 10

    /// The result code of an accepted action.
    static let acceptedCode = "accepted"
    /// The engine's code for a value outside its declared range.
    static let outOfRangeCode = "action.out-of-range"
    /// The engine's code for a wrong number of values.
    static let wrongCountCode = "action.wrong-value-count"
    /// The code of a fractional star index or nudge step.
    static let notWholeCode = "action.rule." + AcousticConstellatorExperienceRule.notWhole
    /// The code of the kernel's action refusal (an unknown star, a self, existing, missing or fixed link, a step of 0,
    /// nothing to undo or redo).
    static let kernelActionCode = "action.rule." + AcousticConstellatorError.action("").reasonCode
    /// The code of the kernel's stage refusal (an action outside stage `playing`, an undo of a won play).
    static let stageCode = "action.rule." + AcousticConstellatorError.stage.reasonCode

    /// The eight acceptance families, in row order: rows 10 × f + 1 … 10 × f + 10 belong to family f.
    public enum AcceptanceFamily: Int, CaseIterable, Sendable {
        /// Rows 1 … 10: a legal command, then an illegal one.
        case truth
        /// Rows 11 … 20: the witness with a move omitted and recovered (odd) or an exhausted budget (even).
        case witness
        /// Rows 21 … 30: the star and step endpoints and the refusals just outside them.
        case numeric
        /// Rows 31 … 40: a link, undo, redo and a refused redo.
        case touch
        /// Rows 41 … 50: the witness won, then a refused undo.
        case rendering
        /// Rows 51 … 60: a failed listen, then an undo back to the state before it.
        case accessibility
        /// Rows 61 … 70: a link undone and redone, then the rest of the witness.
        case persistence
        /// Rows 71 … 80: the next level, its first link, an undo and a refused undo.
        case integration
    }

    /// One accepted entry of `control` with `values` after `steps` steps.
    static func acceptedEntry(_ control: String, _ values: [Double] = [], steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: acceptedCode)
    }

    /// One refused entry of `control` with `values`, expecting `result`, after `steps` steps.
    static func refusedEntry(_ control: String, _ values: [Double], _ result: String, steps: Int = 0) -> ScenarioStep {
        ScenarioStep(steps: steps, action: ScriptedAction(control, values), result: result)
    }

    /// The control and values that issue a kernel action.
    static func scripted(_ action: AcousticConstellatorAction) -> ScriptedAction {
        switch action {
        case let .link(a, b): ScriptedAction("link.add", [Double(a), Double(b)])
        case let .unlink(a, b): ScriptedAction("link.remove", [Double(a), Double(b)])
        case let .nudge(star, step): ScriptedAction("star.nudge", [Double(star), Double(step)])
        case .listen: ScriptedAction("constellation.listen", [])
        }
    }

    /// The accepted entry of a kernel action.
    static func actionEntry(_ action: AcousticConstellatorAction, steps: Int = 1) -> ScenarioStep {
        ScenarioStep(steps: steps, action: scripted(action), result: acceptedCode)
    }

    /// The refused entry of a kernel action, expecting `result`.
    static func refusedAction(_ action: AcousticConstellatorAction, _ result: String) -> ScenarioStep {
        ScenarioStep(steps: 1, action: scripted(action), result: result)
    }

    /// The certified level and plan of manifest number `number`; nil when it cannot be generated.
    static func certified(_ number: Int) -> AcousticConstellatorGenerated? {
        try? generated(number: number)
    }

    /// The certified witness's actions of manifest number `number` (its links, its nudges, then one listen); empty when
    /// the level cannot be generated.
    public static func certifiedActions(_ number: Int) -> [AcousticConstellatorAction] {
        certified(number)?.actions ?? []
    }

    /// The certified moves of manifest number `number` (the witness without its listen); empty when the level cannot be
    /// generated.
    public static func certifiedMoves(_ number: Int) -> [AcousticConstellatorAction] {
        var moves: [AcousticConstellatorAction] = []
        for action in certifiedActions(number) where action != .listen { moves.append(action) }
        return moves
    }

    /// The first certified link of manifest number `number` (every plan links at least one missing symbol pair, and
    /// its links come first); nil when the level cannot be generated.
    static func firstLink(_ number: Int) -> (a: Int, b: Int)? {
        guard case let .link(a, b)? = certifiedMoves(number).first else { return nil }
        return (a, b)
    }

    /// Certifies the levels of `numbers` concurrently into the process cache (certification is pure and
    /// deterministic), so building the manifest's 80 acceptance scenarios stays short.
    static func prewarm(_ numbers: [Int]) {
        DispatchQueue.concurrentPerform(iterations: numbers.count) { index in
            _ = try? generated(number: numbers[index])
        }
    }

    /// The opening play of manifest number `number` (begun, past its tutorial); nil when it cannot be generated.
    static func openingPlay(_ number: Int) -> AcousticConstellatorPlay? {
        guard let level = certified(number)?.level else { return nil }
        return try? freshPlay(of: level)
    }

    /// The two input actions on the opening level: the first certified pair linked, then unlinked; empty when the level
    /// cannot be generated or its budget is below 3 (so neither fails).
    public static var inputActions: [AcousticConstellatorAction] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        guard let play = openingPlay(number), play.level.budget >= 3, let pair = firstLink(number) else { return [] }
        return [.link(pair.a, pair.b), .unlink(pair.a, pair.b)]
    }

    /// The actions of input-response, save-restore and reset: the two ``inputActions``, then the second undone.
    public static var inputEntries: [ScenarioStep] {
        let actions: [AcousticConstellatorAction] = inputActions
        guard !actions.isEmpty else { return [] }
        return actions.map { actionEntry($0, steps: 10) } + [acceptedEntry("play.undo", steps: 10)]
    }

    /// The entries of completion: the certified witness of the opening level.
    public static var completionEntries: [ScenarioStep] {
        certifiedActions(levelNumber(forSeed: manifestSeed)).map { actionEntry($0) }
    }

    /// The entries of full-playthrough: the certified witnesses of ``playthroughLevels`` with `level.next` between
    /// them.
    public static var playthroughEntries: [ScenarioStep] {
        var entries: [ScenarioStep] = []
        for (index, number) in playthroughLevels.enumerated() {
            if index > 0 { entries.append(acceptedEntry("level.next")) }
            let actions: [AcousticConstellatorAction] = certifiedActions(number)
            guard !actions.isEmpty else { return [] }
            for action in actions { entries.append(actionEntry(action)) }
        }
        return entries
    }

    /// The entries of hero: the certified moves of the opening level without the listen, so the picture shows the
    /// symbol linked while the play is still open.
    public static var heroEntries: [ScenarioStep] {
        certifiedMoves(levelNumber(forSeed: manifestSeed)).map { actionEntry($0) }
    }

    /// The actions that spend the rest of `play`'s budget by alternating `first` and `second` (starting with `first`),
    /// the last one failing the play `budget`; empty when the play is not playing or the kernel refuses one.
    static func exhaustingActions(_ play: AcousticConstellatorPlay, alternating first: AcousticConstellatorAction,
                                  and second: AcousticConstellatorAction) -> [AcousticConstellatorAction] {
        var current: AcousticConstellatorPlay = play
        var actions: [AcousticConstellatorAction] = []
        while current.stage == .playing {
            let action: AcousticConstellatorAction = actions.count % 2 == 0 ? first : second
            guard (try? current.apply(action, expecting: current.fingerprint)) != nil else { return [] }
            actions.append(action)
        }
        if case .budget? = current.failure { return actions }
        return []
    }

    /// The entries of `fixture-budget-out`: the first certified pair linked and unlinked for the whole budget, the last
    /// action failing the play.
    public static var budgetOutEntries: [ScenarioStep] {
        let number: Int = levelNumber(forSeed: manifestSeed)
        guard let play = openingPlay(number), let pair = firstLink(number) else { return [] }
        return exhaustingActions(play, alternating: .link(pair.a, pair.b), and: .unlink(pair.a, pair.b))
            .map { actionEntry($0) }
    }

    /// The entries of `fixture-undo-redo`: the first certified link, its undo and its redo.
    public static var undoRedoEntries: [ScenarioStep] {
        guard let first = certifiedMoves(levelNumber(forSeed: manifestSeed)).first else { return [] }
        return [actionEntry(first), acceptedEntry("play.undo"), acceptedEntry("play.redo")]
    }

    /// The entries of rejection, from the opening state of level 1 (see the file header).
    public static var rejectionEntries: [ScenarioStep] {
        guard let play = openingPlay(levelNumber(forSeed: manifestSeed)) else { return [] }
        let level: AcousticConstellatorLevel = play.level
        let high: Double = Double(starRange.upperBound + 1)
        var entries: [ScenarioStep] = [
            refusedEntry("link.add", [high, 0], outOfRangeCode),
            refusedEntry("link.add", [-1, 0], outOfRangeCode),
            refusedEntry("link.remove", [0, high], outOfRangeCode),
            refusedEntry("star.nudge", [0, 2], outOfRangeCode),
            refusedEntry("star.nudge", [0, -2], outOfRangeCode),
            refusedEntry("link.add", [0.5, 1], notWholeCode),
            refusedEntry("star.nudge", [0, 0.5], notWholeCode),
            refusedEntry("link.add", [0, 0], kernelActionCode),
            refusedEntry("star.nudge", [0, 0], kernelActionCode),
        ]
        if level.stars.count <= starRange.upperBound {
            entries.append(refusedEntry("link.add", [0, Double(level.stars.count)], kernelActionCode))
            entries.append(refusedEntry("star.nudge", [Double(level.stars.count), 1], kernelActionCode))
        }
        if let fixed = level.fixedLinks.first {
            entries.append(refusedEntry("link.add", [Double(fixed.a), Double(fixed.b)], kernelActionCode))
            entries.append(refusedEntry("link.remove", [Double(fixed.a), Double(fixed.b)], kernelActionCode))
        }
        if let pair = firstLink(levelNumber(forSeed: manifestSeed)) {
            entries.append(refusedEntry("link.remove", [Double(pair.a), Double(pair.b)], kernelActionCode))
        }
        entries += [
            refusedEntry("play.undo", [], kernelActionCode),
            refusedEntry("play.redo", [], kernelActionCode),
            refusedEntry("link.add", [1], wrongCountCode),
            refusedEntry("link.remove", [1], wrongCountCode),
            refusedEntry("star.nudge", [1], wrongCountCode),
            refusedEntry("constellation.listen", [1], wrongCountCode),
            refusedEntry("play.undo", [1], wrongCountCode),
            refusedEntry("play.redo", [1], wrongCountCode),
            refusedEntry("level.next", [1], wrongCountCode),
        ]
        return entries
    }

    /// The level of acceptance row `row` (1 … 80): (7 × (row − 1) + 46) mod 100 + 1, the levels the archived rows
    /// 1 … 20 name (047, 054, … 096, 003, … 080), continued for rows 21 … 80.
    public static func acceptanceLevel(_ row: Int) -> Int { (7 * (row - 1) + 46) % 100 + 1 }

    /// The level of each acceptance row, in row order: 80 distinct levels.
    public static var acceptanceLevels: [Int] {
        var levels: [Int] = []
        for row in 1...acceptanceRows { levels.append(acceptanceLevel(row)) }
        return levels
    }

    /// `number` written with at least three digits.
    static func threeDigits(_ number: Int) -> String {
        let digits = String(number)
        return String(repeating: "0", count: max(0, 3 - digits.count)) + digits
    }

    /// The scenario name of acceptance row `row` (1 … 80): `acceptance-001` … `acceptance-080` (the validator counts
    /// the `acceptance-` prefix; names are lower case).
    public static func acceptanceName(_ row: Int) -> String { "acceptance-" + threeDigits(row) }

    /// The archived matrix id of acceptance row `row` (1 … 80): `R2-G13-QA-001` … `R2-G13-QA-080`.
    public static func acceptanceRowID(_ row: Int) -> String { "R2-G13-QA-" + threeDigits(row) }

    /// The family of acceptance row `row` (1 … 80).
    public static func acceptanceFamily(_ row: Int) -> AcceptanceFamily {
        AcceptanceFamily(rawValue: (row - 1) / acceptanceFamilySize) ?? .integration
    }

    /// The seed that opens level `number`: `number − 1` (``levelNumber(forSeed:)`` gives `seed % 100 + 1`).
    public static func seed(forLevel number: Int) -> UInt64 { UInt64(max(number - 1, 0)) }

    /// The level after `number` as `level.next` opens it (100 wraps to 1).
    public static func nextLevel(after number: Int) -> Int { number % levelNumbers.upperBound + 1 }

    /// The failure of a listen after the certified moves of manifest number `number` without move `omitted`; nil when
    /// the level cannot be generated, the kernel refuses a move or the listen wins.
    static func omissionFailure(_ number: Int, omitting omitted: Int) -> AcousticConstellatorFailure? {
        guard var play = openingPlay(number) else { return nil }
        for (index, move) in certifiedMoves(number).enumerated() where index != omitted {
            guard (try? play.apply(move, expecting: play.fingerprint)) != nil else { return nil }
        }
        guard (try? play.apply(.listen, expecting: play.fingerprint)) != nil else { return nil }
        return play.failure
    }

    /// The certified move of manifest number `number` that the witness and accessibility rows omit: the last one whose
    /// omission makes the listen fail other than `missing` (a snapped link or no hold), else the last one whose
    /// omission fails at all; nil when no omission fails (never for a minimal certified plan).
    public static func omittedMove(_ number: Int) -> Int? {
        let moves: [AcousticConstellatorAction] = certifiedMoves(number)
        var fallback: Int?
        for index in moves.indices.reversed() {
            guard let failure = omissionFailure(number, omitting: index) else { continue }
            if case .missing = failure {
                if fallback == nil { fallback = index }
                continue
            }
            return index
        }
        return fallback
    }

    /// The certified moves of manifest number `number` without ``omittedMove(_:)``, and that move; nil when the level
    /// cannot be generated or no omission fails.
    static func omission(_ number: Int) -> (kept: [AcousticConstellatorAction], omitted: AcousticConstellatorAction)? {
        let moves: [AcousticConstellatorAction] = certifiedMoves(number)
        guard let index = omittedMove(number) else { return nil }
        var kept: [AcousticConstellatorAction] = []
        for (position, move) in moves.enumerated() where position != index { kept.append(move) }
        return (kept, moves[index])
    }

    /// The entries of truth row `row` on level `number` (see the file header); empty when the level cannot be generated.
    static func truthEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number), let pair = firstLink(number) else { return [] }
        let stars: Int = play.level.stars.count
        let legal: ScenarioStep = actionEntry(.link(pair.a, pair.b))
        switch (row - 1) % 5 {
        case 0:   // commit constellation — stiff coupling: a link to a star the level lacks (a self link at 8 stars)
            if stars <= starRange.upperBound {
                return [legal, refusedAction(.link(pair.a, stars), kernelActionCode)]
            }
            return [legal, refusedAction(.link(pair.a, pair.a), kernelActionCode)]
        case 1:   // connect oscillators — colour-only progress: a star above the declared range
            return [legal, refusedAction(.link(pair.a, starRange.upperBound + 1), outOfRangeCode)]
        case 2:   // retune node — phase wrapping: the same link again changes nothing
            return [legal, refusedAction(.link(pair.a, pair.b), kernelActionCode)]
        case 3:   // move anchor — incorrect oscillator stepping: a fractional star
            return [legal, ScenarioStep(steps: 1, action: ScriptedAction("link.add", [Double(pair.a), 1.5]),
                                        result: notWholeCode)]
        default:  // inspect synchrony — false graph isomorphism: the listen fails, then the play is closed
            return [actionEntry(.listen), refusedAction(.link(pair.a, pair.b), stageCode)]
        }
    }

    /// The entries of witness row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated, no omission fails or the budget cannot be spent.
    static func witnessEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard var play = openingPlay(number), let pair = firstLink(number) else { return [] }
        if row % 2 == 1 {
            guard let omission = omission(number) else { return [] }
            return omission.kept.map { actionEntry($0) }
                + [actionEntry(.listen), acceptedEntry("play.undo"), actionEntry(omission.omitted),
                   actionEntry(.listen)]
        }
        var entries: [ScenarioStep] = []
        for move in certifiedMoves(number) {
            guard (try? play.apply(move, expecting: play.fingerprint)) != nil else { return [] }
            entries.append(actionEntry(move))
        }
        let spending: [AcousticConstellatorAction] = exhaustingActions(play, alternating: .unlink(pair.a, pair.b),
                                                                       and: .link(pair.a, pair.b))
        guard !spending.isEmpty else { return [] }
        for action in spending { entries.append(actionEntry(action)) }
        entries.append(refusedAction(.listen, stageCode))
        return entries
    }

    /// The entries of numeric row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated.
    static func numericEntries(row: Int, number: Int) -> [ScenarioStep] {
        guard let play = openingPlay(number) else { return [] }
        let stars: Int = play.level.stars.count
        var entries: [ScenarioStep] = [
            actionEntry(.nudge(0, stepRange.lowerBound)),
            actionEntry(.nudge(stars - 1, stepRange.upperBound)),
        ]
        if row % 2 == 1 {
            entries.append(refusedAction(.nudge(0, stepRange.lowerBound - 1), outOfRangeCode))
        } else {
            entries.append(refusedAction(.nudge(starRange.upperBound + 1, 1), outOfRangeCode))
        }
        entries += [refusedAction(.nudge(starRange.lowerBound - 1, 1), outOfRangeCode),
                    refusedAction(.nudge(0, 0), kernelActionCode)]
        if stars <= starRange.upperBound {
            entries.append(refusedAction(.nudge(stars, 1), kernelActionCode))
        }
        entries += [acceptedEntry("play.undo"), acceptedEntry("play.undo")]
        return entries
    }

    /// The entries of accessibility row `row` on level `number` (see the file header); empty when the level cannot be
    /// generated or no omission fails.
    static func accessibilityEntries(row: Int, number: Int) -> [ScenarioStep] {
        if row % 2 == 1 { return [actionEntry(.listen), acceptedEntry("play.undo")] }
        guard let omission = omission(number) else { return [] }
        return omission.kept.map { actionEntry($0) } + [actionEntry(.listen), acceptedEntry("play.undo")]
    }

    /// The entries of acceptance row `row` (1 … 80) on its level (see the file header); empty when the level cannot be
    /// generated.
    public static func acceptanceEntries(row: Int) -> [ScenarioStep] {
        let number: Int = acceptanceLevel(row)
        let actions: [AcousticConstellatorAction] = certifiedActions(number)
        guard let first = actions.first, first != .listen else { return [] }
        switch acceptanceFamily(row) {
        case .truth:
            return truthEntries(row: row, number: number)
        case .witness:
            return witnessEntries(row: row, number: number)
        case .numeric:
            return numericEntries(row: row, number: number)
        case .touch:
            return [actionEntry(first), acceptedEntry("play.undo"), acceptedEntry("play.redo"),
                    refusedEntry("play.redo", [], kernelActionCode, steps: 1)]
        case .rendering:
            return actions.map { actionEntry($0) } + [refusedEntry("play.undo", [], stageCode, steps: 1)]
        case .accessibility:
            return accessibilityEntries(row: row, number: number)
        case .persistence:
            return [actionEntry(first), acceptedEntry("play.undo"), acceptedEntry("play.redo")]
                + actions.dropFirst().map { actionEntry($0) }
        case .integration:
            guard let next = certifiedMoves(nextLevel(after: number)).first else { return [] }
            return [acceptedEntry("level.next"), actionEntry(next), acceptedEntry("play.undo"),
                    refusedEntry("play.undo", [], kernelActionCode, steps: 1)]
        }
    }

    /// The acceptance scenarios, one per row: its name, seed and entries (see the file header). Empty when a level
    /// cannot be generated.
    public static var acceptanceScenarios: [(name: String, seed: UInt64, entries: [ScenarioStep])] {
        var list: [(name: String, seed: UInt64, entries: [ScenarioStep])] = []
        var needed: [Int] = acceptanceLevels + playthroughLevels
        for row in 1...acceptanceRows where acceptanceFamily(row) == .integration {
            needed.append(nextLevel(after: acceptanceLevel(row)))
        }
        prewarm(needed)
        for row in 1...acceptanceRows {
            let entries: [ScenarioStep] = acceptanceEntries(row: row)
            guard !entries.isEmpty else { return [] }
            list.append((acceptanceName(row), seed(forLevel: acceptanceLevel(row)), entries))
        }
        return list
    }

    /// The fixtures: a name, the entries from the opening state and the outcome expected after them (nil: none).
    public static var fixtures: [(name: String, entries: [ScenarioStep], outcome: String?)] {
        [("fixture-level-1-solved", completionEntries, wonCode),
         ("fixture-budget-out", budgetOutEntries, failedCode),
         ("fixture-undo-redo", undoRedoEntries, nil)]
    }

    /// The core prepared with `seed` after playing `entries` as the engine plays them: each entry's steps, then its
    /// action (an action the engine would refuse for its count or range is refused here too and changes nothing);
    /// nil when the seed's level cannot be generated.
    public static func played(seed: UInt64, entries: [ScenarioStep]) -> AcousticConstellatorExperienceCore? {
        guard var core = try? opening(number: levelNumber(forSeed: seed)) else { return nil }
        var step = 0
        for entry in entries {
            for _ in 0..<max(0, entry.steps) {
                core.update(step: step)
                step += 1
            }
            guard let action = entry.action else { continue }
            if ExperienceInput.validate(control: action.control, values: action.values, controls: controls) != nil {
                continue
            }
            var next = core
            if next.apply(ExperienceAction(control: action.control, values: action.values, step: step)).isAccepted {
                core = next
            }
        }
        return core
    }

    /// The digest of the core prepared with `seed` after `entries`, computed as the engine computes it; nil when the
    /// level cannot be generated or the digest cannot be written.
    public static func expectedDigest(for id: ExperienceID, seed: UInt64, entries: [ScenarioStep]) -> String? {
        guard let core = played(seed: seed, entries: entries) else { return nil }
        var builder = DigestBuilder(domain: id.rawValue)
        do { try core.writeDigest(into: &builder) } catch { return nil }
        return builder.finish().hex
    }

    /// The scenario manifest of the experience `id`: a round-two game (see the file header).
    public static func manifest(for id: ExperienceID, seed: UInt64 = manifestSeed) -> ScenarioManifest {
        let input = inputEntries
        let initial = expectedDigest(for: id, seed: seed, entries: [])
        let final = expectedDigest(for: id, seed: seed, entries: input)
        let playthrough = playthroughEntries
        let hero = heroEntries
        var specs = [
            ScenarioSpec(name: "launch-first-frame", seed: seed, entries: [],
                         expect: ScenarioExpectations(initialDigest: initial)),
            ScenarioSpec(name: "input-response", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, finalDigest: final)),
            ScenarioSpec(name: "completion", seed: seed, entries: completionEntries,
                         expect: ScenarioExpectations(outcome: wonCode)),
            ScenarioSpec(name: "rejection", seed: seed, entries: rejectionEntries,
                         expect: ScenarioExpectations(initialDigest: initial, finalDigest: initial)),
            ScenarioSpec(name: "save-restore", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, finalDigest: final)),
            ScenarioSpec(name: "reset", seed: seed, entries: input,
                         expect: ScenarioExpectations(initialDigest: initial, resetDigest: true)),
            ScenarioSpec(name: "suspend-resume", seed: seed, entries: []),
            ScenarioSpec(name: "teardown-reentry", seed: seed, entries: [], cycles: 5),
            ScenarioSpec(name: "cancel-prepare", seed: seed, entries: []),
            ScenarioSpec(name: "full-playthrough", seed: seed, entries: playthrough,
                         expect: ScenarioExpectations(initialDigest: initial,
                                                      finalDigest: expectedDigest(for: id, seed: seed,
                                                                                  entries: playthrough),
                                                      outcome: wonCode)),
            ScenarioSpec(name: "hero", seed: seed, entries: hero,
                         expect: ScenarioExpectations(initialDigest: initial,
                                                      finalDigest: expectedDigest(for: id, seed: seed,
                                                                                  entries: hero))),
        ]
        for acceptance in acceptanceScenarios {
            let end = played(seed: acceptance.seed, entries: acceptance.entries)
            specs.append(ScenarioSpec(name: acceptance.name, seed: acceptance.seed, entries: acceptance.entries,
                                      expect: ScenarioExpectations(
                                          initialDigest: expectedDigest(for: id, seed: acceptance.seed, entries: []),
                                          finalDigest: expectedDigest(for: id, seed: acceptance.seed,
                                                                      entries: acceptance.entries),
                                          outcome: end?.outcome?.code)))
        }
        for fixture in fixtures {
            specs.append(ScenarioSpec(name: fixture.name, seed: seed, entries: fixture.entries,
                                      expect: ScenarioExpectations(initialDigest: initial,
                                                                   finalDigest: expectedDigest(
                                                                       for: id, seed: seed, entries: fixture.entries),
                                                                   outcome: fixture.outcome)))
        }
        return ScenarioManifest(experience: id, kind: .game, round: manifestRound, scenarios: specs)
    }
}
#endif
