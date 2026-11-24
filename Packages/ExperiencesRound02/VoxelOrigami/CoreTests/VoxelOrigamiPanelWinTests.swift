// VoxelOrigamiPanelWinTests — feature 444 (R02-G15-04) T-R02G1504-004 (FR-R02G1504-006; SC-R02G1504-005)
// Every certified level 1 … 100 is won through the control panel's buttons only, applied to
// `VoxelOrigamiExperienceCore` exactly as `VoxelOrigamiControls` sends them: Hinge − and + send
// `hinge.choose [clamped(hinge ∓ 1)]` (the adapter's chosen hinge, clamped to 1 … cubes − 1), Turn − and + send
// `hinge.turn [chosen hinge, ∓1]`, Undo `play.undo`, Redo `play.redo`. Each level is opened as the engine opens it
// (`prepare(seed:)` with seed `number − 1`, which chooses level `seed % 100 + 1`). For each turn (h, step) of the
// level's certified plan (`VoxelOrigamiExperienceCore.generated(number:).plan`) only Hinge − and + are pressed, one at
// a time (at most 16 per turn), until the chosen hinge is h, then Turn − or +. Every press must be accepted, the play
// must end in stage `won` with outcome `won`, and it must spend exactly the plan's turn count. The levels are certified
// concurrently into the adapter's per-process cache and split into ten groups of ten so each test stays short. A last
// test: on levels 41, 61 and 81 (plans of 3 or more turns, so two turns do not win), after two panel turns, Undo
// restores the digest from after the first and Redo the digest after the second. No randomness. Host-run
// (`swift test`); explicit types, plain loops.
import Foundation
import Testing
@testable import VoxelOrigamiCore
import VisualCoreDiagnostics
import VisualCoreExperience

/// The most Hinge − and + presses the panel may spend lining up one turn (a level has at most 11 hinges, so at most
/// 10).
private let panelPressLimit: Int = 16

/// The adapter's digest of `core` in hex.
private func panelDigest(_ core: VoxelOrigamiExperienceCore) throws -> String {
    var builder: DigestBuilder = DigestBuilder(domain: VoxelOrigamiExperienceCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// The action a panel button sends.
private func panelAction(_ control: String, _ values: [Double] = []) -> ExperienceAction {
    ExperienceAction(control: control, values: values, step: 0)
}

/// `value` clamped to the hinges 1 … cubes − 1 of `core`'s level, as the panel's mirror clamps it.
private func panelClamped(_ value: Int, _ core: VoxelOrigamiExperienceCore) -> Int {
    let last: Int = max(core.play.level.cubes.count - 1, 1)
    return min(max(value, 1), last)
}

/// Presses Hinge − or + on `core` until its chosen hinge is `target`; a problem, or nil when it is lined up.
private func panelLineUp(hinge target: Int, _ core: inout VoxelOrigamiExperienceCore) -> String? {
    var presses: Int = 0
    while core.chosenHinge != target {
        if presses >= panelPressLimit { return "press limit spent before hinge \(target)" }
        let before: Int = core.chosenHinge
        let delta: Int = target > before ? 1 : -1
        let label: String = delta > 0 ? "Hinge +" : "Hinge −"
        let result: ActionResult = core.apply(panelAction("hinge.choose", [Double(panelClamped(before + delta, core))]))
        presses += 1
        if result != .accepted { return "\(label) from hinge \(before) gave \(result)" }
        if core.chosenHinge == before { return "\(label) did not move from hinge \(before)" }
    }
    return nil
}

/// Lines up and presses Turn − or + for the plan turn `action`; a problem, or nil when the press is accepted.
private func panelTurn(_ action: VoxelOrigamiAction, _ core: inout VoxelOrigamiExperienceCore) -> String? {
    switch action {
    case let .turn(hinge, step):
        guard step == 1 || step == -1 else { return "turn step \(step) has no button" }
        if let problem = panelLineUp(hinge: hinge, &core) { return problem }
        let result: ActionResult = core.apply(panelAction("hinge.turn", [Double(core.chosenHinge), Double(step)]))
        if result != .accepted { return "Turn \(step > 0 ? "+" : "−") on hinge \(hinge) gave \(result)" }
        return nil
    }
}

/// Certifies `numbers` concurrently into the adapter's per-process cache.
private func panelPrewarm(_ numbers: [Int]) async {
    await withTaskGroup(of: Void.self) { (group: inout TaskGroup<Void>) in
        for number in numbers {
            group.addTask { _ = try? VoxelOrigamiExperienceCore.generated(number: number) }
        }
    }
}

/// Plays level `number` through the panel; the problems found (empty when it is won in the plan's turn count).
private func panelProblems(level number: Int) async throws -> [String] {
    let generated: VoxelOrigamiGenerated = try VoxelOrigamiExperienceCore.generated(number: number)
    let turns: [VoxelOrigamiAction] = generated.plan.turns
    if turns.isEmpty { return ["level \(number): empty plan"] }
    var core: VoxelOrigamiExperienceCore = try await VoxelOrigamiExperienceCore.prepare(seed: UInt64(number - 1))
    if core.levelNumber != number { return ["level \(number): prepare opened level \(core.levelNumber)"] }
    if core.play.level.fingerprint != generated.level.fingerprint {
        return ["level \(number): the opened level is not the certified level"]
    }
    var index: Int = 0
    for action in turns {
        if let problem = panelTurn(action, &core) { return ["level \(number): turn \(index) \(action): \(problem)"] }
        index += 1
    }
    var problems: [String] = []
    if core.play.stage != .won { problems.append("level \(number): stage \(core.play.stage)") }
    if core.play.actionsSpent != turns.count {
        problems.append("level \(number): \(core.play.actionsSpent) actions, planned \(turns.count)")
    }
    let outcome: String? = core.outcome?.code
    if outcome != VoxelOrigamiExperienceCore.wonCode {
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

@Suite struct VoxelOrigamiPanelWinTests {
    /// FR-R02G1504-006, SC-R02G1504-005: every level of `group` is won through Hinge − and +, then Turn − or +, in its
    /// certified plan's turn count.
    @Test(arguments: panelGroups)
    func levelsAreWonThroughThePanel(_ group: ClosedRange<Int>) async throws {
        let problems: [String] = try await panelProblems(levels: group)
        #expect(problems.isEmpty, "\(problems)")
    }

    /// FR-R02G1504-006: after two panel turns, panel Undo restores the digest from after the first turn and Redo the
    /// digest after the second (levels 41, 61 and 81, whose plans have at least three turns, so the play stays open).
    @Test func panelUndoAndRedoRestoreTheDigests() async throws {
        let numbers: [Int] = [41, 61, 81]
        await panelPrewarm(numbers)
        for number in numbers {
            var core: VoxelOrigamiExperienceCore = try await VoxelOrigamiExperienceCore.prepare(
                seed: UInt64(number - 1))
            let turns: [VoxelOrigamiAction] = try VoxelOrigamiExperienceCore.generated(number: number).plan.turns
            try #require(turns.count >= 3, "level \(number) plan has \(turns.count) turns")
            let opening: String = try panelDigest(core)
            #expect(panelTurn(turns[0], &core) == nil)
            let first: String = try panelDigest(core)
            #expect(panelTurn(turns[1], &core) == nil)
            let second: String = try panelDigest(core)
            #expect(first != opening && second != first)
            #expect(core.apply(panelAction("play.undo")) == .accepted)
            #expect(try panelDigest(core) == first, "level \(number): Undo")
            #expect(core.apply(panelAction("play.redo")) == .accepted)
            #expect(try panelDigest(core) == second, "level \(number): Redo")
        }
    }
}
