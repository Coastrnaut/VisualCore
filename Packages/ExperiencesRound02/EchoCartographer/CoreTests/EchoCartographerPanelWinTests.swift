// EchoCartographerPanelWinTests — feature 404 (R02-G11-04) T-R02G1104-004 (User Story 5). Every certified level
// 1 … 100 is won through the control panel's buttons only, applied to `EchoCartographerExperienceCore` exactly as the
// panel sends them. A pure panel model copies the cursor arithmetic of the presenter's mirror
// (`EchoCartographerMirror`, iOS only): a level opens with the cursor on the entry; Column − and + move the column by
// ±1 clamped to 0 … W − 1, Row − and + the row by ±1 clamped to 0 … H − 1; after every action, undo or redo the cursor
// follows the play (a new level puts it on the entry, otherwise it is clamped to the chamber), so it persists between
// actions within a level. Pulse sends `cell.pulse [column, row]`, Claim `cell.claim`, Mark `cell.mark`, Undo
// `play.undo`, Redo `play.redo`. For each action of the level's stored witness
// (`docs/games/echo-cartographer/levels/NNN.witness.json`) only stepper buttons are pressed (at most 64 per action)
// from the cursor's current cell until it is the action's cell, then Pulse, Claim or Mark. Every press must be
// accepted, the play must end in stage `won` with outcome `won`, and it must spend exactly the witness's action count.
// The levels are certified concurrently into the adapter's per-process cache and split into ten groups of ten so each
// test stays short. A last test: panel Undo after a pulse on level 1 restores the digest from before it and Redo the
// digest after it. No randomness. Host-run (`swift test`); explicit types, plain loops.
@testable import EchoCartographerCore
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience

/// The repository's witness directory, found from this file.
private let panelWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/echo-cartographer/levels", isDirectory: true)

/// The stored witness of level `number`, read with the plain decoder.
private func panelWitness(_ number: Int) throws -> EchoCartographerWitness {
    let name: String = String(EchoCartographerGenerator.levelID(number).suffix(3)) + ".witness.json"
    let data: Data = try Data(contentsOf: panelWitnessDirectory.appendingPathComponent(name))
    return try JSONDecoder().decode(EchoCartographerWitness.self, from: data)
}

/// The most stepper presses the panel may spend lining up one action.
private let panelPressLimit: Int = 64

/// The adapter's digest of `core` in hex.
private func panelDigest(_ core: EchoCartographerExperienceCore) throws -> String {
    var builder: DigestBuilder = DigestBuilder(domain: EchoCartographerExperienceCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// The action a panel button sends.
private func panelAction(_ control: String, _ values: [Double] = []) -> ExperienceAction {
    ExperienceAction(control: control, values: values, step: 0)
}

/// The panel's cursor and its stepper arithmetic, copied from `EchoCartographerMirror` (`stepColumn`, `stepRow`,
/// `follow`).
private struct EchoCartographerPanelModel {
    /// The play the cursor is clamped against.
    var play: EchoCartographerPlay
    /// The cursor's column and row.
    var column: Int
    var row: Int
    /// The stepper presses so far.
    var presses: Int = 0

    /// A panel following `play`: the cursor on the entry.
    init(play: EchoCartographerPlay) {
        self.play = play
        column = play.level.entry.x
        row = play.level.entry.y
    }

    /// The chamber's width and height.
    var width: Int { play.level.chamber.width }
    var height: Int { play.level.chamber.height }

    /// The mirror's `stepColumn`: the column by `delta`, clamped to the chamber.
    mutating func stepColumn(_ delta: Int) { column = min(max(column + delta, 0), width - 1) }

    /// The mirror's `stepRow`: the row by `delta`, clamped to the chamber.
    mutating func stepRow(_ delta: Int) { row = min(max(row + delta, 0), height - 1) }

    /// The mirror's `follow`: a new level puts the cursor on the entry; otherwise it is clamped to the chamber.
    mutating func follow(_ next: EchoCartographerPlay) {
        let changedLevel: Bool = play.level.id != next.level.id
        play = next
        if changedLevel {
            column = next.level.entry.x
            row = next.level.entry.y
        } else {
            stepColumn(0)
            stepRow(0)
        }
    }

    /// Presses Column − and + and Row − and + until the cursor is on `cell`; false when it stops moving or the press
    /// limit is spent.
    mutating func lineUp(_ cell: EchoCartographerCell) -> Bool {
        let first: Int = presses
        while column != cell.x {
            if presses - first >= panelPressLimit { return false }
            let before: Int = column
            presses += 1
            stepColumn(cell.x > column ? 1 : -1)
            if column == before { return false }
        }
        while row != cell.y {
            if presses - first >= panelPressLimit { return false }
            let before: Int = row
            presses += 1
            stepRow(cell.y > row ? 1 : -1)
            if row == before { return false }
        }
        return column == cell.x && row == cell.y
    }

    /// The cursor as the values of a `cell.*` control.
    var cursorValues: [Double] { [Double(column), Double(row)] }
}

/// Lines the panel up with `action` and returns what Pulse, Claim or Mark then sends; nil when the steppers cannot
/// reach its cell.
private func panelPress(_ action: EchoCartographerAction,
                        _ panel: inout EchoCartographerPanelModel) -> (control: String, values: [Double])? {
    guard panel.lineUp(action.cell) else { return nil }
    switch action {
    case .pulse: return ("cell.pulse", panel.cursorValues)
    case .claim: return ("cell.claim", panel.cursorValues)
    case .mark: return ("cell.mark", panel.cursorValues)
    }
}

/// Certifies `numbers` concurrently into the adapter's per-process cache.
private func panelPrewarm(_ numbers: [Int]) async {
    await withTaskGroup(of: Void.self) { (group: inout TaskGroup<Void>) in
        for number in numbers {
            group.addTask { _ = try? EchoCartographerExperienceCore.generated(number: number) }
        }
    }
}

/// Plays level `number` through the panel model; the problems found (empty when it is won as witnessed).
private func panelProblems(level number: Int) throws -> [String] {
    let witness: EchoCartographerWitness = try panelWitness(number)
    let actions: [EchoCartographerAction] = witness.actions
    if actions.isEmpty { return ["level \(number): empty witness"] }
    var core: EchoCartographerExperienceCore = try EchoCartographerExperienceCore.opening(number: number)
    if core.play.level.fingerprint != witness.level.fingerprint {
        return ["level \(number): the certified level is not the witness's level"]
    }
    var panel: EchoCartographerPanelModel = EchoCartographerPanelModel(play: core.play)
    let entry: EchoCartographerCell = core.play.level.entry
    if panel.column != entry.x || panel.row != entry.y {
        return ["level \(number): panel opened at \(panel.column), \(panel.row)"]
    }
    var index: Int = 0
    for action in actions {
        guard let press = panelPress(action, &panel) else {
            return ["level \(number): action \(index) \(action) not reached from \(panel.column), \(panel.row)"]
        }
        let result: ActionResult = core.apply(panelAction(press.control, press.values))
        if result != .accepted {
            return ["level \(number): action \(index) \(action): \(press.control) \(press.values) gave \(result)"]
        }
        panel.follow(core.play)
        index += 1
    }
    var problems: [String] = []
    if core.play.stage != .won { problems.append("level \(number): stage \(core.play.stage)") }
    if core.play.moves != actions.count {
        problems.append("level \(number): \(core.play.moves) actions, witnessed \(actions.count)")
    }
    let outcome: String? = core.outcome?.code
    if outcome != EchoCartographerExperienceCore.wonCode {
        problems.append("level \(number): outcome \(outcome ?? "none")")
    }
    return problems
}

/// Plays every level of `numbers` through the panel after certifying them concurrently.
private func panelProblems(levels numbers: ClosedRange<Int>) async throws -> [String] {
    var list: [Int] = []
    for number in numbers { list.append(number) }
    await panelPrewarm(list)
    var problems: [String] = []
    for number in list { problems += try panelProblems(level: number) }
    return problems
}

/// Ten groups of ten levels, one test each.
private let panelGroups: [ClosedRange<Int>] = [1...10, 11...20, 21...30, 31...40, 41...50,
                                               51...60, 61...70, 71...80, 81...90, 91...100]

@Suite struct EchoCartographerPanelWinTests {
    /// User Story 5: every level of `group` is won through the steppers, Pulse and Claim in its witnessed count.
    @Test(arguments: panelGroups)
    func levelsAreWonThroughThePanel(_ group: ClosedRange<Int>) async throws {
        let problems: [String] = try await panelProblems(levels: group)
        #expect(problems.isEmpty, "\(problems)")
    }

    /// User Story 5: panel Undo after a pulse restores the digest from before it; Redo the digest after it.
    @Test func panelUndoAndRedoAfterAPulseRestoreTheDigests() throws {
        var core: EchoCartographerExperienceCore = try EchoCartographerExperienceCore.opening(number: 1)
        var panel: EchoCartographerPanelModel = EchoCartographerPanelModel(play: core.play)
        let before: String = try panelDigest(core)
        let witness: EchoCartographerWitness = try panelWitness(1)
        let chosen: EchoCartographerAction = try #require(witness.actions.first)
        let press: (control: String, values: [Double]) = try #require(panelPress(chosen, &panel))
        #expect(press.control == "cell.pulse")
        #expect(core.apply(panelAction(press.control, press.values)) == .accepted)
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
