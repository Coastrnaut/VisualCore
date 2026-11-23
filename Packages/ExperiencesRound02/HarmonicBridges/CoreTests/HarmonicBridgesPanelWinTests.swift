// HarmonicBridgesPanelWinTests — feature 414 (R02-G12-04) T-R02G1204-004 (FR-R02G1204-006; SC-R02G1204-005)
// Every certified level 1 … 100 is won through the control panel's buttons only, applied to
// `HarmonicBridgesExperienceCore` exactly as the panel sends them. A pure panel model mirrors the presentation state of
// `HarmonicBridgesMirror` (`stepString`, `stepPeg`, `follow`; iOS only, driven by `HarmonicBridgesControls`): a level
// opens with string 0 chosen at its current peg; String − and + step the chosen string by ±1 clamped to the level's
// strings and the peg jumps to that string's current peg; Peg − and + step the peg by ±1 clamped to 1 … 12; after every
// action, undo or redo the choice follows the play (a new level chooses string 0 at its current peg, otherwise the
// choice is clamped). Tune sends `string.tune [string, peg]`, Test `crossing.test`, Undo `play.undo`, Redo
// `play.redo`. For each tuning of the level's stored witness (`docs/games/harmonic-bridges/levels/NNN.witness.json`)
// only stepper buttons are pressed (at most 64 per action) until the choice is the tuning's string and peg, then Tune;
// the witness's last action is pressed as Test. Every press must be accepted, the play must end in stage `won` with
// outcome `won`, and it must spend exactly the witness's action count. The levels are certified concurrently into the
// adapter's per-process cache and split into ten groups of ten so each test stays short. A last test: panel Undo after
// a tuning on level 1 restores the digest from before it and Redo the digest after it. No randomness. Host-run
// (`swift test`); explicit types, plain loops.
import Foundation
import Testing
@testable import HarmonicBridgesCore
import VisualCoreDiagnostics
import VisualCoreExperience

/// The repository's witness directory, found from this file.
private let panelWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/harmonic-bridges/levels", isDirectory: true)

/// The stored witness of level `number`, read with the plain decoder.
private func panelWitness(_ number: Int) throws -> HarmonicBridgesWitness {
    let name: String = String(HarmonicBridgesGenerator.levelID(number).suffix(3)) + ".witness.json"
    let data: Data = try Data(contentsOf: panelWitnessDirectory.appendingPathComponent(name))
    return try JSONDecoder().decode(HarmonicBridgesWitness.self, from: data)
}

/// The most stepper presses the panel may spend lining up one action.
private let panelPressLimit: Int = 64

/// The adapter's digest of `core` in hex.
private func panelDigest(_ core: HarmonicBridgesExperienceCore) throws -> String {
    var builder: DigestBuilder = DigestBuilder(domain: HarmonicBridgesExperienceCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// The action a panel button sends.
private func panelAction(_ control: String, _ values: [Double] = []) -> ExperienceAction {
    ExperienceAction(control: control, values: values, step: 0)
}

/// The panel's chosen string and peg and its stepper arithmetic. This mirrors `HarmonicBridgesMirror.stepString`,
/// `HarmonicBridgesMirror.stepPeg` and `HarmonicBridgesMirror.follow` (Experience/HarmonicBridgesPresenter.swift),
/// which are iOS-only.
private struct HarmonicBridgesPanelModel {
    /// The pegs a string may be tuned to (the mirror's `pegRange`).
    static let pegRange: ClosedRange<Int> = HarmonicBridgesExperienceCore.pegRange

    /// The play the choice is clamped against.
    var play: HarmonicBridgesPlay
    /// The chosen string (0-based).
    var string: Int
    /// The chosen peg (1 … 12).
    var peg: Int
    /// The stepper presses so far.
    var presses: Int = 0

    /// A panel following a newly opened `play`: string 0 chosen at its current peg.
    init(play: HarmonicBridgesPlay) {
        self.play = play
        string = 0
        peg = HarmonicBridgesPanelModel.clampedPeg(play.pegs.first ?? Self.pegRange.lowerBound)
    }

    /// The mirror's `clampedPeg`.
    static func clampedPeg(_ value: Int) -> Int { min(max(value, pegRange.lowerBound), pegRange.upperBound) }

    /// The number of strings of the followed level (the mirror's `stringCount`).
    var stringCount: Int { max(play.level.strings.count, 1) }

    /// The current peg of the chosen string in the followed play (the mirror's `currentPeg`).
    var currentPeg: Int? {
        guard string >= 0, string < play.pegs.count else { return nil }
        return play.pegs[string]
    }

    /// The mirror's `stepString`: the string by `delta`, clamped to the level's strings; the peg becomes that string's
    /// current peg.
    mutating func stepString(_ delta: Int) {
        string = min(max(string + delta, 0), stringCount - 1)
        if let current = currentPeg { peg = Self.clampedPeg(current) }
    }

    /// The mirror's `stepPeg`: the peg by `delta`, clamped to 1 … 12.
    mutating func stepPeg(_ delta: Int) { peg = Self.clampedPeg(peg + delta) }

    /// The mirror's `follow`: a new level chooses string 0 at its current peg; otherwise the choice is clamped.
    mutating func follow(_ next: HarmonicBridgesPlay) {
        let changedLevel: Bool = play.level.id != next.level.id
        play = next
        if changedLevel {
            string = 0
            peg = Self.clampedPeg(currentPeg ?? Self.pegRange.lowerBound)
        } else {
            string = min(max(string, 0), stringCount - 1)
            peg = Self.clampedPeg(peg)
        }
    }

    /// Presses String − and + and then Peg − and + until the choice is `target` at `targetPeg`; false when a stepper
    /// stops moving or the press limit is spent.
    mutating func lineUp(string target: Int, peg targetPeg: Int) -> Bool {
        let first: Int = presses
        while string != target {
            if presses - first >= panelPressLimit { return false }
            let before: Int = string
            presses += 1
            stepString(target > string ? 1 : -1)
            if string == before { return false }
        }
        while peg != targetPeg {
            if presses - first >= panelPressLimit { return false }
            let before: Int = peg
            presses += 1
            stepPeg(targetPeg > peg ? 1 : -1)
            if peg == before { return false }
        }
        return string == target && peg == targetPeg
    }

    /// The choice as the values of `string.tune`.
    var choiceValues: [Double] { [Double(string), Double(peg)] }
}

/// Lines the panel up with `action` and returns what Tune or Test then sends; nil when the steppers cannot reach the
/// tuning's string and peg.
private func panelPress(_ action: HarmonicBridgesAction,
                        _ panel: inout HarmonicBridgesPanelModel) -> (control: String, values: [Double])? {
    switch action {
    case let .tune(string, peg):
        guard panel.lineUp(string: string, peg: peg) else { return nil }
        return ("string.tune", panel.choiceValues)
    case .test:
        return ("crossing.test", [])
    }
}

/// Certifies `numbers` concurrently into the adapter's per-process cache.
private func panelPrewarm(_ numbers: [Int]) async {
    await withTaskGroup(of: Void.self) { (group: inout TaskGroup<Void>) in
        for number in numbers {
            group.addTask { _ = try? HarmonicBridgesExperienceCore.generated(number: number) }
        }
    }
}

/// Plays level `number` through the panel model; the problems found (empty when it is won as witnessed).
private func panelProblems(level number: Int) throws -> [String] {
    let witness: HarmonicBridgesWitness = try panelWitness(number)
    let actions: [HarmonicBridgesAction] = witness.actions
    if actions.isEmpty { return ["level \(number): empty witness"] }
    if actions.last != .test { return ["level \(number): the witness does not end with a test"] }
    var core: HarmonicBridgesExperienceCore = try HarmonicBridgesExperienceCore.opening(number: number)
    if core.play.level.fingerprint != witness.level.fingerprint {
        return ["level \(number): the certified level is not the witness's level"]
    }
    var panel: HarmonicBridgesPanelModel = HarmonicBridgesPanelModel(play: core.play)
    if panel.string != 0 || panel.peg != HarmonicBridgesPanelModel.clampedPeg(core.play.pegs[0]) {
        return ["level \(number): panel opened at string \(panel.string), peg \(panel.peg)"]
    }
    var index: Int = 0
    for action in actions {
        guard let press = panelPress(action, &panel) else {
            return ["level \(number): action \(index) \(action) not reached from \(panel.string), \(panel.peg)"]
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
    if core.play.actionsSpent != actions.count {
        problems.append("level \(number): \(core.play.actionsSpent) actions, witnessed \(actions.count)")
    }
    let outcome: String? = core.outcome?.code
    if outcome != HarmonicBridgesExperienceCore.wonCode {
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

@Suite struct HarmonicBridgesPanelWinTests {
    /// FR-R02G1204-006, SC-R02G1204-005: every level of `group` is won through the steppers, Tune and Test in its
    /// witnessed count.
    @Test(arguments: panelGroups)
    func levelsAreWonThroughThePanel(_ group: ClosedRange<Int>) async throws {
        let problems: [String] = try await panelProblems(levels: group)
        #expect(problems.isEmpty, "\(problems)")
    }

    /// FR-R02G1204-006: panel Undo after a tuning restores the digest from before it; Redo the digest after it.
    @Test func panelUndoAndRedoAfterATuningRestoreTheDigests() throws {
        var core: HarmonicBridgesExperienceCore = try HarmonicBridgesExperienceCore.opening(number: 1)
        var panel: HarmonicBridgesPanelModel = HarmonicBridgesPanelModel(play: core.play)
        let before: String = try panelDigest(core)
        let witness: HarmonicBridgesWitness = try panelWitness(1)
        let chosen: HarmonicBridgesAction = try #require(witness.actions.first)
        let press: (control: String, values: [Double]) = try #require(panelPress(chosen, &panel))
        #expect(press.control == "string.tune")
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
