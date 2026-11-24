// MoonlitMechanismPanelWinTests — feature 434 (R02-G14-04) T-R02G1404-004 (FR-R02G1404-007; SC-R02G1404-005)
// Every certified level 1 … 100 is won through the control panel's buttons only, applied to
// `MoonlitMechanismExperienceCore` exactly as the panel sends them. A pure panel model mirrors the presentation state of
// `MoonlitMechanismControls` (Q5: the chosen gear is presentation state, not kernel state): a level opens with gear
// `openingGear` (1) chosen; Gear − and + step the choice by ±1 clamped to the level's gears 0 … n−1; after every action,
// undo or redo the choice follows the play (a new level chooses gear 1, otherwise the choice is clamped). Turn − and +
// send `handle.turn [∓1]`, Re-seat − and + `gear.reseat [gear, ∓1]`, Lamp − and + `lamp.step [∓1]`, Run
// `machine.run`, Undo `play.undo`, Redo `play.redo`. Each level is opened as the engine opens it (`prepare(seed:)` with
// seed `number − 1`, which chooses level `seed % 100 + 1`). For each action of the level's stored witness
// (`docs/games/moonlit-mechanism/levels/NNN.witness.json`: its turns, its re-seats in gear order, its lamp steps, then
// one run) only Gear − and + are pressed (at most 16 per action) until the choice is the action's gear for a re-seat,
// then the action's button. Every press must be accepted, the play must end in stage `won` with outcome `won`, and it
// must spend exactly the witness's kernel-action count. The levels are certified concurrently into the adapter's
// per-process cache and split into ten groups of ten so each test stays short. A last test: panel Undo after the first
// witnessed action on level 1 restores the digest from before it and Redo the digest after it. No randomness.
// Host-run (`swift test`); explicit types, plain loops.
import Foundation
import Testing
@testable import MoonlitMechanismCore
import VisualCoreDiagnostics
import VisualCoreExperience

/// The repository's witness directory, found from this file (five levels up: CoreTests, MoonlitMechanism, the package,
/// Packages).
private let panelWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/moonlit-mechanism/levels", isDirectory: true)

/// The stored witness of level `number`, read with the plain decoder (the checked `decode` reruns the solver).
private func panelWitness(_ number: Int) throws -> MoonlitMechanismWitness {
    let name: String = String(format: "%03d.witness.json", number)
    let data: Data = try Data(contentsOf: panelWitnessDirectory.appendingPathComponent(name))
    return try JSONDecoder().decode(MoonlitMechanismWitness.self, from: data)
}

/// The most Gear − and + presses the panel may spend lining up one action (a level has at most 5 gears, so at most 4).
private let panelPressLimit: Int = 16

/// The adapter's digest of `core` in hex.
private func panelDigest(_ core: MoonlitMechanismExperienceCore) throws -> String {
    var builder: DigestBuilder = DigestBuilder(domain: MoonlitMechanismExperienceCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// The action a panel button sends.
private func panelAction(_ control: String, _ values: [Double] = []) -> ExperienceAction {
    ExperienceAction(control: control, values: values, step: 0)
}

/// The panel's chosen gear and its stepper arithmetic: the presentation state of `MoonlitMechanismControls` (Q5),
/// which is iOS-only.
private struct MoonlitMechanismPanelModel {
    /// The play the choice is clamped against.
    var play: MoonlitMechanismPlay
    /// The chosen gear (0-based).
    var gear: Int
    /// The Gear − and + presses so far.
    var presses: Int = 0

    /// A panel following a newly opened `play`: the opening gear, clamped to its gears.
    init(play: MoonlitMechanismPlay) {
        self.play = play
        gear = 0
        gear = clamped(MoonlitMechanismExperienceCore.openingGear)
    }

    /// The number of gears of the followed level (at least 1).
    var gearCount: Int { max(play.level.gears.count, 1) }

    /// `value` clamped to the followed level's gears 0 … n−1.
    func clamped(_ value: Int) -> Int { min(max(value, 0), gearCount - 1) }

    /// Gear − (`delta` −1) or + (`delta` +1): the chosen gear by `delta`, clamped.
    mutating func stepGear(_ delta: Int) { gear = clamped(gear + delta) }

    /// Follows `next` after an action, undo or redo: a new level chooses the opening gear; otherwise the choice is
    /// clamped.
    mutating func follow(_ next: MoonlitMechanismPlay) {
        let changedLevel: Bool = play.level.id != next.level.id
        play = next
        gear = clamped(changedLevel ? MoonlitMechanismExperienceCore.openingGear : gear)
    }

    /// Presses Gear − and + until the chosen gear is `target`; false when the stepper stops moving or the press limit
    /// is spent.
    mutating func lineUp(gear target: Int) -> Bool {
        let first: Int = presses
        while gear != target {
            if presses - first >= panelPressLimit { return false }
            let before: Int = gear
            presses += 1
            stepGear(target > gear ? 1 : -1)
            if gear == before { return false }
        }
        return true
    }
}

/// Lines the panel up with `action` and returns what Turn − or +, Re-seat − or +, Lamp − or +, or Run then sends; nil
/// when the stepper cannot reach the action's gear or the step is not −1 or +1.
private func panelPress(_ action: MoonlitMechanismAction,
                        _ panel: inout MoonlitMechanismPanelModel) -> (control: String, values: [Double])? {
    switch action {
    case let .turn(step):
        guard step == 1 || step == -1 else { return nil }
        return ("handle.turn", [Double(step)])
    case let .reseat(gear, step):
        guard step == 1 || step == -1, panel.lineUp(gear: gear) else { return nil }
        return ("gear.reseat", [Double(panel.gear), Double(step)])
    case let .lamp(step):
        guard step == 1 || step == -1 else { return nil }
        return ("lamp.step", [Double(step)])
    case .run:
        return ("machine.run", [])
    }
}

/// Certifies `numbers` concurrently into the adapter's per-process cache.
private func panelPrewarm(_ numbers: [Int]) async {
    await withTaskGroup(of: Void.self) { (group: inout TaskGroup<Void>) in
        for number in numbers {
            group.addTask { _ = try? MoonlitMechanismExperienceCore.generated(number: number) }
        }
    }
}

/// Plays level `number` through the panel model; the problems found (empty when it is won as witnessed).
private func panelProblems(level number: Int) async throws -> [String] {
    let witness: MoonlitMechanismWitness = try panelWitness(number)
    let actions: [MoonlitMechanismAction] = witness.actions
    if actions.isEmpty { return ["level \(number): empty witness"] }
    if actions.last != .run { return ["level \(number): the witness does not end with a run"] }
    var core: MoonlitMechanismExperienceCore = try await MoonlitMechanismExperienceCore.prepare(seed: UInt64(number - 1))
    if core.levelNumber != number { return ["level \(number): prepare opened level \(core.levelNumber)"] }
    if core.play.level.fingerprint != witness.level.fingerprint {
        return ["level \(number): the certified level is not the witness's level"]
    }
    var panel: MoonlitMechanismPanelModel = MoonlitMechanismPanelModel(play: core.play)
    if panel.gear != min(1, panel.gearCount - 1) { return ["level \(number): panel opened at gear \(panel.gear)"] }
    var index: Int = 0
    for action in actions {
        guard let press = panelPress(action, &panel) else {
            return ["level \(number): action \(index) \(action) not reached from gear \(panel.gear)"]
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
    if outcome != MoonlitMechanismExperienceCore.wonCode {
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
    for number in list { problems += try await panelProblems(level: number) }
    return problems
}

/// Ten groups of ten levels, one test each.
private let panelGroups: [ClosedRange<Int>] = [1...10, 11...20, 21...30, 31...40, 41...50,
                                               51...60, 61...70, 71...80, 81...90, 91...100]

@Suite struct MoonlitMechanismPanelWinTests {
    /// FR-R02G1404-007, SC-R02G1404-005: every level of `group` is won through Turn, the gear stepper, Re-seat, Lamp
    /// and Run in its witnessed kernel-action count.
    @Test(arguments: panelGroups)
    func levelsAreWonThroughThePanel(_ group: ClosedRange<Int>) async throws {
        let problems: [String] = try await panelProblems(levels: group)
        #expect(problems.isEmpty, "\(problems)")
    }

    /// FR-R02G1404-007: panel Undo after the first witnessed action restores the digest from before it; Redo the
    /// digest after it.
    @Test func panelUndoAndRedoRestoreTheDigests() async throws {
        var core: MoonlitMechanismExperienceCore = try await MoonlitMechanismExperienceCore.prepare(seed: 0)
        var panel: MoonlitMechanismPanelModel = MoonlitMechanismPanelModel(play: core.play)
        let before: String = try panelDigest(core)
        let witness: MoonlitMechanismWitness = try panelWitness(1)
        let chosen: MoonlitMechanismAction = try #require(witness.actions.first)
        #expect(chosen != .run)
        let press: (control: String, values: [Double]) = try #require(panelPress(chosen, &panel))
        #expect(core.apply(panelAction(press.control, press.values)) == .accepted)
        panel.follow(core.play)
        let gearAfter: Int = panel.gear
        let after: String = try panelDigest(core)
        #expect(after != before)
        #expect(core.apply(panelAction("play.undo")) == .accepted)
        panel.follow(core.play)
        #expect(try panelDigest(core) == before)
        #expect(panel.gear == gearAfter)
        #expect(core.apply(panelAction("play.redo")) == .accepted)
        panel.follow(core.play)
        #expect(try panelDigest(core) == after)
    }
}
