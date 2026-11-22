// FacetedForgePanelWinTests — feature 374 (R02-G08-04) T-R02G0804-004. Every certified level 1 … 100 is won through
// the control panel's buttons only, applied to `FacetedForgeExperienceCore` exactly as the panel sends them. A pure
// panel model mirrors the presenter's mirror (`FacetedForgeMirror`): the preview choice starts at
// `FacetedForgePreviewChoice.initial(play)`; the piece picker moves the piece by ±1, wrapping over the pieces, and the
// direction picker by ±1, wrapping over the 13 directions, each moving the depth to the middle crossing depth
// (`FacetedForgeSolver.crossingDepths`) of the new piece and direction; depth − and + are
// `steppingDepth(∓1 / ±1, in:)`; after a cut the choice is clamped to the new play (`clamped(to:)`). For each cut of
// the level's certified solution (`FacetedForgeExperienceCore.certifiedActions(n)`) only panel buttons are pressed
// (at most 64 per cut) until the choice is the cut's piece, direction and depth; then Cut sends
// `piece.cut [piece, direction, depth]`. Every cut must be accepted and the play must end in stage `won` with outcome
// `won`. The levels are generated concurrently into the adapter's per-process cache and split into ten groups of ten
// so each test stays short. A last test: panel Undo after a cut restores the digest from before it and Redo the digest
// after it. No randomness. Host-run (`swift test`); explicit types, plain loops.
import Foundation
import Testing
@testable import FacetedForgeCore
import VisualCoreDiagnostics
import VisualCoreExperience

/// The most panel presses spent lining up one cut.
private let panelPressLimit: Int = 64

/// The digest of `core` as the engine computes it.
private func panelDigest(_ core: FacetedForgeExperienceCore) throws -> String {
    var builder: DigestBuilder = DigestBuilder(domain: FacetedForgeExperienceCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// A panel button's action: `control` with `values`.
private func panelAction(_ control: String, _ values: [Double] = []) -> ExperienceAction {
    ExperienceAction(control: control, values: values, step: 0)
}

/// The panel's preview choice and its rules, mirroring `FacetedForgeMirror` (pure; presentation state only).
private struct FacetedForgePanelModel {
    /// The play the choice is clamped against.
    var play: FacetedForgePlay
    /// The preview choice the panel shows.
    var choice: FacetedForgePreviewChoice
    /// The buttons pressed so far.
    var presses: Int = 0

    /// A panel on `play` with the opening choice.
    init(play: FacetedForgePlay) {
        self.play = play
        self.choice = FacetedForgePreviewChoice.initial(play)
    }

    /// `choice` with its depth set to the middle crossing depth of its piece and direction (unchanged when none).
    static func middle(_ choice: FacetedForgePreviewChoice, _ play: FacetedForgePlay) -> FacetedForgePreviewChoice {
        guard play.pieces.indices.contains(choice.piece) else { return choice.clamped(to: play) }
        let crossing: [Int] = FacetedForgeSolver.crossingDepths(play.pieces[choice.piece], direction: choice.direction)
        if crossing.isEmpty { return choice }
        return FacetedForgePreviewChoice(piece: choice.piece, direction: choice.direction,
                                         depth: crossing[crossing.count / 2])
    }

    /// The piece picker by `delta`, wrapping; the depth moves to the middle crossing depth.
    mutating func pickPiece(_ delta: Int) {
        presses += 1
        let count: Int = play.pieces.count
        if count == 0 { return }
        let piece: Int = ((choice.piece + delta) % count + count) % count
        choice = Self.middle(FacetedForgePreviewChoice(piece: piece, direction: choice.direction, depth: 0), play)
    }

    /// The direction picker by `delta`, wrapping over the 13 directions; the depth moves to the middle crossing depth.
    mutating func pickDirection(_ delta: Int) {
        presses += 1
        let count: Int = FacetedForgeDirection.all.count
        let direction: Int = ((choice.direction + delta) % count + count) % count
        choice = Self.middle(FacetedForgePreviewChoice(piece: choice.piece, direction: direction, depth: 0), play)
    }

    /// Depth − (`step` −1) or + (`step` +1).
    mutating func stepDepth(_ step: Int) {
        presses += 1
        choice = choice.steppingDepth(step, in: play)
    }

    /// Takes the play after a cut, undo or redo and clamps the choice to it.
    mutating func follow(_ next: FacetedForgePlay) {
        play = next
        choice = choice.clamped(to: next)
    }

    /// The shorter wrapping delta (−1 or +1) from `from` to `to` over `count` values; 0 when equal.
    static func wrapDelta(from: Int, to: Int, count: Int) -> Int {
        if from == to || count == 0 { return 0 }
        let forward: Int = ((to - from) % count + count) % count
        return forward <= count - forward ? 1 : -1
    }

    /// Presses piece, direction and depth buttons until the choice is (`piece`, `direction`, `depth`); false when
    /// that takes more than ``panelPressLimit`` presses or the depth cannot be reached.
    mutating func lineUp(piece: Int, direction: Int, depth: Int) -> Bool {
        let start: Int = presses
        while choice.piece != piece {
            if presses - start >= panelPressLimit { return false }
            pickPiece(Self.wrapDelta(from: choice.piece, to: piece, count: play.pieces.count))
        }
        while choice.direction != direction {
            if presses - start >= panelPressLimit { return false }
            pickDirection(Self.wrapDelta(from: choice.direction, to: direction, count: FacetedForgeDirection.all.count))
        }
        while choice.depth != depth {
            if presses - start >= panelPressLimit { return false }
            let before: FacetedForgePreviewChoice = choice
            stepDepth(depth > choice.depth ? 1 : -1)
            if choice == before { return false }
        }
        return true
    }
}

/// Generates the levels `numbers` concurrently into the adapter's per-process cache.
private func panelPrewarm(_ numbers: [Int]) async {
    await withTaskGroup(of: Void.self) { (group: inout TaskGroup<Void>) in
        for number in numbers {
            group.addTask { _ = try? FacetedForgeExperienceCore.generated(number: number) }
        }
    }
}

/// Plays certified level `number` through panel buttons only; returns the problems found (empty: won).
private func panelProblems(level number: Int) throws -> [String] {
    let actions: [FacetedForgeAction] = FacetedForgeExperienceCore.certifiedActions(number)
    if actions.isEmpty { return ["level \(number): empty certified solution"] }
    var core: FacetedForgeExperienceCore = try FacetedForgeExperienceCore.opening(number: number)
    var panel: FacetedForgePanelModel = FacetedForgePanelModel(play: core.play)
    var index: Int = 0
    for action in actions {
        guard case .cut(let piece, let direction, let depth) = action else {
            return ["level \(number): cut \(index) is not a cut"]
        }
        if !panel.lineUp(piece: piece, direction: direction, depth: depth) {
            return ["level \(number): cut \(index) [\(piece), \(direction), \(depth)] not reached; at \(panel.choice)"]
        }
        let values: [Double] = [Double(panel.choice.piece), Double(panel.choice.direction), Double(panel.choice.depth)]
        let result: ActionResult = core.apply(panelAction("piece.cut", values))
        if result != .accepted { return ["level \(number): cut \(index) \(values) gave \(result)"] }
        panel.follow(core.play)
        index += 1
    }
    var problems: [String] = []
    if core.play.stage != .won { problems.append("level \(number): stage \(core.play.stage)") }
    let outcome: String? = core.outcome?.code
    if outcome != FacetedForgeExperienceCore.wonCode {
        problems.append("level \(number): outcome \(outcome ?? "none")")
    }
    return problems
}

/// The problems of every level in `numbers`, after generating them concurrently into the process cache.
private func panelProblems(levels numbers: ClosedRange<Int>) async throws -> [String] {
    var list: [Int] = []
    for number in numbers { list.append(number) }
    await panelPrewarm(list)
    var problems: [String] = []
    for number in list { problems += try panelProblems(level: number) }
    return problems
}

/// The ten groups of ten levels each test case plays.
private let panelGroups: [ClosedRange<Int>] = [1...10, 11...20, 21...30, 31...40, 41...50,
                                               51...60, 61...70, 71...80, 81...90, 91...100]

@Suite struct FacetedForgePanelWinTests {
    @Test(arguments: panelGroups)
    func levelsAreWonThroughThePanel(_ group: ClosedRange<Int>) async throws {
        let problems: [String] = try await panelProblems(levels: group)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func panelUndoAndRedoAfterACutRestoreTheDigests() throws {
        var core: FacetedForgeExperienceCore = try FacetedForgeExperienceCore.opening(number: 1)
        var panel: FacetedForgePanelModel = FacetedForgePanelModel(play: core.play)
        let before: String = try panelDigest(core)
        let choice: FacetedForgePreviewChoice = panel.choice
        let values: [Double] = [Double(choice.piece), Double(choice.direction), Double(choice.depth)]
        #expect(core.apply(panelAction("piece.cut", values)) == .accepted)
        panel.follow(core.play)
        let after: String = try panelDigest(core)
        #expect(after != before)
        #expect(core.apply(panelAction("play.undo")) == .accepted)
        panel.follow(core.play)
        #expect(try panelDigest(core) == before)
        #expect(core.apply(panelAction("play.redo")) == .accepted)
        panel.follow(core.play)
        #expect(try panelDigest(core) == after)
    }
}
