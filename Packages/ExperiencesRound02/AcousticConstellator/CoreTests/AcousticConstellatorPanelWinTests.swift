// AcousticConstellatorPanelWinTests — feature 424 (R02-G13-04) T-R02G1304-004 (FR-R02G1304-007; SC-R02G1304-005)
// Every certified level 1 … 100 is won through the control panel's buttons only, applied to
// `AcousticConstellatorExperienceCore` exactly as the panel sends them. A pure panel model mirrors the presentation state
// of `AcousticConstellatorControls` (Q5: the chosen star and partner are presentation state, not kernel state): a level
// opens with star `openingStar` (0) and partner `openingPartner` (1) chosen; Star − and + and Partner − and + step the
// choice by ±1 clamped to the level's stars 0 … n−1; after every action, undo or redo the choice follows the play (a
// new level chooses star 0 and partner 1, otherwise the choice is clamped). Link sends `link.add [star, partner]`,
// Unlink `link.remove [star, partner]`, Nudge − `star.nudge [star, -1]`, Nudge + `star.nudge [star, 1]`, Listen
// `constellation.listen`, Undo `play.undo`, Redo `play.redo`. Each level is opened as the engine opens it
// (`prepare(seed:)` with seed `number − 1`, which chooses level `seed % 100 + 1`). For each action of the level's stored
// witness (`docs/games/acoustic-constellator/levels/NNN.witness.json`: its links, its nudges one step at a time, then
// one listen) only stepper buttons are pressed (at most 32 per action) until the choice is the action's star (and
// partner for a link or an unlink), then the action's button. Every press must be accepted, the play must end in stage
// `won` with outcome `won`, and it must spend exactly the witness's kernel-action count. The levels are certified
// concurrently into the adapter's per-process cache and split into ten groups of ten so each test stays short. A last
// test: panel Undo after a link on level 1 restores the digest from before it and Redo the digest after it. No
// randomness. Host-run (`swift test`); explicit types, plain loops.
import Foundation
import Testing
@testable import AcousticConstellatorCore
import VisualCoreDiagnostics
import VisualCoreExperience

/// The repository's witness directory, found from this file (five levels up: CoreTests, AcousticConstellator, the
/// package, Packages).
private let panelWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/acoustic-constellator/levels", isDirectory: true)

/// The stored witness of level `number`, read with the plain decoder.
private func panelWitness(_ number: Int) throws -> AcousticConstellatorWitness {
    let name: String = String(AcousticConstellatorGenerator.levelID(number).suffix(3)) + ".witness.json"
    let data: Data = try Data(contentsOf: panelWitnessDirectory.appendingPathComponent(name))
    return try JSONDecoder().decode(AcousticConstellatorWitness.self, from: data)
}

/// The most stepper presses the panel may spend lining up one action (a level has at most 8 stars, so two steppers
/// need at most 14).
private let panelPressLimit: Int = 32

/// The adapter's digest of `core` in hex.
private func panelDigest(_ core: AcousticConstellatorExperienceCore) throws -> String {
    var builder: DigestBuilder = DigestBuilder(domain: AcousticConstellatorExperienceCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// The action a panel button sends.
private func panelAction(_ control: String, _ values: [Double] = []) -> ExperienceAction {
    ExperienceAction(control: control, values: values, step: 0)
}

/// The panel's chosen star and partner and their stepper arithmetic: the presentation state of
/// `AcousticConstellatorControls` (Q5), which is iOS-only.
private struct AcousticConstellatorPanelModel {
    /// The play the choice is clamped against.
    var play: AcousticConstellatorPlay
    /// The chosen star (0-based).
    var star: Int
    /// The chosen partner (0-based).
    var partner: Int
    /// The stepper presses so far.
    var presses: Int = 0

    /// A panel following a newly opened `play`: the opening star and partner, clamped to its stars.
    init(play: AcousticConstellatorPlay) {
        self.play = play
        star = 0
        partner = 0
        star = clamped(AcousticConstellatorExperienceCore.openingStar)
        partner = clamped(AcousticConstellatorExperienceCore.openingPartner)
    }

    /// The number of stars of the followed level (at least 1).
    var starCount: Int { max(play.level.stars.count, 1) }

    /// `value` clamped to the followed level's stars 0 … n−1.
    func clamped(_ value: Int) -> Int { min(max(value, 0), starCount - 1) }

    /// Star − (`delta` −1) or + (`delta` +1): the chosen star by `delta`, clamped.
    mutating func stepStar(_ delta: Int) { star = clamped(star + delta) }

    /// Partner − (`delta` −1) or + (`delta` +1): the chosen partner by `delta`, clamped.
    mutating func stepPartner(_ delta: Int) { partner = clamped(partner + delta) }

    /// Follows `next` after an action, undo or redo: a new level chooses the opening star and partner; otherwise the
    /// choice is clamped.
    mutating func follow(_ next: AcousticConstellatorPlay) {
        let changedLevel: Bool = play.level.fingerprint != next.level.fingerprint
        play = next
        if changedLevel {
            star = clamped(AcousticConstellatorExperienceCore.openingStar)
            partner = clamped(AcousticConstellatorExperienceCore.openingPartner)
        } else {
            star = clamped(star)
            partner = clamped(partner)
        }
    }

    /// Presses Star − and + until the chosen star is `target`, then (when `targetPartner` is given) Partner − and +
    /// until the partner is `targetPartner`; false when a stepper stops moving or the press limit is spent.
    mutating func lineUp(star target: Int, partner targetPartner: Int?) -> Bool {
        let first: Int = presses
        while star != target {
            if presses - first >= panelPressLimit { return false }
            let before: Int = star
            presses += 1
            stepStar(target > star ? 1 : -1)
            if star == before { return false }
        }
        if let wanted = targetPartner {
            while partner != wanted {
                if presses - first >= panelPressLimit { return false }
                let before: Int = partner
                presses += 1
                stepPartner(wanted > partner ? 1 : -1)
                if partner == before { return false }
            }
        }
        return star == target && (targetPartner == nil || partner == targetPartner)
    }

    /// The choice as the values of `link.add` and `link.remove`.
    var pairValues: [Double] { [Double(star), Double(partner)] }
}

/// Lines the panel up with `action` and returns what Link, Unlink, Nudge − or +, or Listen then sends; nil when the
/// steppers cannot reach the action's star and partner or the nudge step is not −1 or +1.
private func panelPress(_ action: AcousticConstellatorAction,
                        _ panel: inout AcousticConstellatorPanelModel) -> (control: String, values: [Double])? {
    switch action {
    case let .link(a, b):
        guard panel.lineUp(star: a, partner: b) else { return nil }
        return ("link.add", panel.pairValues)
    case let .unlink(a, b):
        guard panel.lineUp(star: a, partner: b) else { return nil }
        return ("link.remove", panel.pairValues)
    case let .nudge(star, step):
        guard step == 1 || step == -1, panel.lineUp(star: star, partner: nil) else { return nil }
        return ("star.nudge", [Double(panel.star), Double(step)])
    case .listen:
        return ("constellation.listen", [])
    }
}

/// Certifies `numbers` concurrently into the adapter's per-process cache.
private func panelPrewarm(_ numbers: [Int]) async {
    await withTaskGroup(of: Void.self) { (group: inout TaskGroup<Void>) in
        for number in numbers {
            group.addTask { _ = try? AcousticConstellatorExperienceCore.generated(number: number) }
        }
    }
}

/// Plays level `number` through the panel model; the problems found (empty when it is won as witnessed).
private func panelProblems(level number: Int) async throws -> [String] {
    let witness: AcousticConstellatorWitness = try panelWitness(number)
    let actions: [AcousticConstellatorAction] = witness.actions
    if actions.isEmpty { return ["level \(number): empty witness"] }
    if actions.last != .listen { return ["level \(number): the witness does not end with a listen"] }
    var core: AcousticConstellatorExperienceCore =
        try await AcousticConstellatorExperienceCore.prepare(seed: UInt64(number - 1))
    if core.levelNumber != number { return ["level \(number): prepare opened level \(core.levelNumber)"] }
    if core.play.level.fingerprint != witness.level.fingerprint {
        return ["level \(number): the certified level is not the witness's level"]
    }
    var panel: AcousticConstellatorPanelModel = AcousticConstellatorPanelModel(play: core.play)
    if panel.star != 0 || panel.partner != 1 {
        return ["level \(number): panel opened at star \(panel.star), partner \(panel.partner)"]
    }
    var index: Int = 0
    for action in actions {
        guard let press = panelPress(action, &panel) else {
            return ["level \(number): action \(index) \(action) not reached from \(panel.star), \(panel.partner)"]
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
    if outcome != AcousticConstellatorExperienceCore.wonCode {
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

@Suite struct AcousticConstellatorPanelWinTests {
    /// FR-R02G1304-007, SC-R02G1304-005: every level of `group` is won through the steppers, Link, Unlink, Nudge and
    /// Listen in its witnessed kernel-action count.
    @Test(arguments: panelGroups)
    func levelsAreWonThroughThePanel(_ group: ClosedRange<Int>) async throws {
        let problems: [String] = try await panelProblems(levels: group)
        #expect(problems.isEmpty, "\(problems)")
    }

    /// FR-R02G1304-007: panel Undo after a link restores the digest from before it; Redo the digest after it.
    @Test func panelUndoAndRedoAfterALinkRestoreTheDigests() async throws {
        var core: AcousticConstellatorExperienceCore = try await AcousticConstellatorExperienceCore.prepare(seed: 0)
        var panel: AcousticConstellatorPanelModel = AcousticConstellatorPanelModel(play: core.play)
        let before: String = try panelDigest(core)
        let witness: AcousticConstellatorWitness = try panelWitness(1)
        let chosen: AcousticConstellatorAction = try #require(witness.actions.first)
        let press: (control: String, values: [Double]) = try #require(panelPress(chosen, &panel))
        #expect(press.control == "link.add")
        #expect(core.apply(panelAction(press.control, press.values)) == .accepted)
        panel.follow(core.play)
        let after: String = try panelDigest(core)
        #expect(after != before)
        #expect(core.apply(panelAction("play.undo")) == .accepted)
        panel.follow(core.play)
        #expect(try panelDigest(core) == before)
        #expect(panel.star == 0 && panel.partner == 1)
        #expect(core.apply(panelAction("play.redo")) == .accepted)
        panel.follow(core.play)
        #expect(try panelDigest(core) == after)
    }
}
