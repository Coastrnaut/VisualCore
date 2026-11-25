// StarlitCartouchePanelWinTests — feature 454 (R02-G16-04) T-R02G1604-004 (FR-R02G1604-008; SC-R02G1604-005)
// Every certified level 1 … 100 is won through the control panel's buttons only, applied to
// `StarlitCartoucheExperienceCore` exactly as `StarlitCartoucheControls` sends them: Star − and + send
// `route.choose [next destination, wait]`, where the next destination steps the chosen star by ∓1, wraps over the
// level's stars and skips the ship's star (the presenter mirror's `nextDestination`, reimplemented here because the
// Experience target is iOS-only); Wait − and + send `route.choose [destination, clamped(wait ∓ 1)]` (0 … 8); Fly sends
// `route.fly [destination, wait]`; Undo `play.undo`; Redo `play.redo`. Each level is opened as the engine opens it
// (`prepare(seed:)` with seed `number − 1`, which chooses level `seed % 100 + 1`). For each witness leg (star, wait)
// of the level's certified plan (`StarlitCartoucheExperienceCore.generated(number:).plan.legs`) only Star − or + is
// pressed (the shorter way round, one press at a time) until the chosen star is the leg's star, then Wait − or + until
// the chosen wait is the leg's wait, then Fly. Every press must be accepted, the play must end in stage `won` with
// outcome `won`, and it must spend exactly the plan's leg count. The levels are certified concurrently into the
// adapter's per-process cache and split into ten groups of ten so each test stays short. A last test: on three levels
// whose plans have three or more legs, after two panel legs, Undo restores the digest from after the first and Redo
// the digest after the second. No randomness, no clock. Host-run (`swift test`); explicit types, plain loops.
import Foundation
import Testing
@testable import StarlitCartoucheCore
import VisualCoreDiagnostics
import VisualCoreExperience

/// The most Star − and + presses, or Wait − and + presses, the panel may spend lining up one leg.
private let panelPressLimit: Int = 16

/// The adapter's digest of `core` in hex.
private func panelDigest(_ core: StarlitCartoucheExperienceCore) throws -> String {
    var builder: DigestBuilder = DigestBuilder(domain: StarlitCartoucheExperienceCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// The action a panel button sends.
private func panelAction(_ control: String, _ values: [Double] = []) -> ExperienceAction {
    ExperienceAction(control: control, values: values, step: 0)
}

/// The destination Star − (`step` −1) or Star + (`step` +1) chooses: the chosen star stepped with wrap-around over the
/// level's stars, skipping the ship's star (the presenter mirror's `nextDestination`).
private func panelNextDestination(_ step: Int, _ core: StarlitCartoucheExperienceCore) -> Int {
    let starCount: Int = core.play.level.stars.count
    var candidate: Int = core.chosenStar
    for _ in 0..<starCount {
        candidate = ((candidate + step) % starCount + starCount) % starCount
        if candidate != core.play.star { return candidate }
    }
    return core.chosenStar
}

/// `value` clamped to the waits 0 … 8, as the panel's mirror clamps it.
private func panelClampedWait(_ value: Int) -> Int {
    min(max(value, 0), 8)
}

/// The presses of Star `step` needed from the current choice to reach `target`; nil when it is not reached.
private func panelPresses(toward target: Int, step: Int, _ core: StarlitCartoucheExperienceCore) -> Int? {
    var probe: StarlitCartoucheExperienceCore = core
    var presses: Int = 0
    while probe.chosenStar != target {
        if presses >= panelPressLimit { return nil }
        let next: Int = panelNextDestination(step, probe)
        if next == probe.chosenStar { return nil }
        if probe.apply(panelAction("route.choose", [Double(next), Double(probe.chosenWait)])) != .accepted {
            return nil
        }
        presses += 1
    }
    return presses
}

/// Presses Star − or + (the shorter way) until the chosen star is `target`; a problem, or nil when it is lined up.
private func panelLineUp(star target: Int, _ core: inout StarlitCartoucheExperienceCore) -> String? {
    let up: Int? = panelPresses(toward: target, step: 1, core)
    let down: Int? = panelPresses(toward: target, step: -1, core)
    var step: Int = 1
    if let downCount = down, downCount < (up ?? Int.max) { step = -1 }
    if up == nil && down == nil { return "star \(target) cannot be reached from star \(core.chosenStar)" }
    let label: String = step > 0 ? "Star +" : "Star −"
    var presses: Int = 0
    while core.chosenStar != target {
        if presses >= panelPressLimit { return "press limit spent before star \(target)" }
        let before: Int = core.chosenStar
        let next: Int = panelNextDestination(step, core)
        let result: ActionResult = core.apply(panelAction("route.choose", [Double(next), Double(core.chosenWait)]))
        presses += 1
        if result != .accepted { return "\(label) from star \(before) gave \(result)" }
        if core.chosenStar == before { return "\(label) did not move from star \(before)" }
    }
    return nil
}

/// Presses Wait − or + until the chosen wait is `target`; a problem, or nil when it is lined up.
private func panelLineUp(wait target: Int, _ core: inout StarlitCartoucheExperienceCore) -> String? {
    var presses: Int = 0
    while core.chosenWait != target {
        if presses >= panelPressLimit { return "press limit spent before wait \(target)" }
        let before: Int = core.chosenWait
        let delta: Int = target > before ? 1 : -1
        let label: String = delta > 0 ? "Wait +" : "Wait −"
        let values: [Double] = [Double(core.chosenStar), Double(panelClampedWait(before + delta))]
        let result: ActionResult = core.apply(panelAction("route.choose", values))
        presses += 1
        if result != .accepted { return "\(label) from wait \(before) gave \(result)" }
        if core.chosenWait == before { return "\(label) did not move from wait \(before)" }
    }
    return nil
}

/// Lines up and presses Fly for the plan leg `action`; a problem, or nil when the press is accepted.
private func panelLeg(_ action: StarlitCartoucheAction, _ core: inout StarlitCartoucheExperienceCore) -> String? {
    switch action {
    case let .leg(star, wait):
        if let problem = panelLineUp(star: star, &core) { return problem }
        if let problem = panelLineUp(wait: wait, &core) { return problem }
        let result: ActionResult = core.apply(panelAction("route.fly",
                                                          [Double(core.chosenStar), Double(core.chosenWait)]))
        if result != .accepted { return "Fly to star \(star) after wait \(wait) gave \(result)" }
        return nil
    }
}

/// Certifies `numbers` concurrently into the adapter's per-process cache.
private func panelPrewarm(_ numbers: [Int]) async {
    await withTaskGroup(of: Void.self) { (group: inout TaskGroup<Void>) in
        for number in numbers {
            group.addTask { _ = try? StarlitCartoucheExperienceCore.generated(number: number) }
        }
    }
}

/// Plays level `number` through the panel; the problems found (empty when it is won in the plan's leg count).
private func panelProblems(level number: Int) async throws -> [String] {
    let generated: StarlitCartoucheGenerated = try StarlitCartoucheExperienceCore.generated(number: number)
    let legs: [StarlitCartoucheAction] = generated.plan.legs
    if legs.isEmpty { return ["level \(number): empty plan"] }
    var core: StarlitCartoucheExperienceCore = try await StarlitCartoucheExperienceCore.prepare(
        seed: UInt64(number - 1))
    if core.levelNumber != number { return ["level \(number): prepare opened level \(core.levelNumber)"] }
    var index: Int = 0
    for action in legs {
        if let problem = panelLeg(action, &core) { return ["level \(number): leg \(index) \(action): \(problem)"] }
        index += 1
    }
    var problems: [String] = []
    if core.play.stage != .won { problems.append("level \(number): stage \(core.play.stage)") }
    if core.play.actionsSpent != legs.count {
        problems.append("level \(number): \(core.play.actionsSpent) actions, planned \(legs.count)")
    }
    let outcome: String? = core.outcome?.code
    if outcome != StarlitCartoucheExperienceCore.wonCode {
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

@Suite struct StarlitCartouchePanelWinTests {
    /// FR-R02G1604-008, SC-R02G1604-005: every level of `group` is won through Star − and +, Wait − and +, then Fly,
    /// in its certified plan's leg count.
    @Test(arguments: panelGroups)
    func levelsAreWonThroughThePanel(_ group: ClosedRange<Int>) async throws {
        let problems: [String] = try await panelProblems(levels: group)
        #expect(problems.isEmpty, "\(problems)")
    }

    /// FR-R02G1604-008: after two panel legs, panel Undo restores the digest from after the first leg and Redo the
    /// digest after the second (the first three levels from 41 whose plans have at least three legs, so the play stays
    /// open).
    @Test func panelUndoAndRedoRestoreTheDigests() async throws {
        var numbers: [Int] = []
        var candidate: Int = 41
        while numbers.count < 3 && candidate <= 100 {
            if try StarlitCartoucheExperienceCore.generated(number: candidate).plan.legs.count >= 3 {
                numbers.append(candidate)
            }
            candidate += 1
        }
        try #require(numbers.count == 3, "levels with plans of three or more legs: \(numbers)")
        for number in numbers {
            var core: StarlitCartoucheExperienceCore = try await StarlitCartoucheExperienceCore.prepare(
                seed: UInt64(number - 1))
            let legs: [StarlitCartoucheAction] = try StarlitCartoucheExperienceCore.generated(number: number).plan.legs
            let opening: String = try panelDigest(core)
            #expect(panelLeg(legs[0], &core) == nil)
            let first: String = try panelDigest(core)
            #expect(panelLeg(legs[1], &core) == nil)
            let second: String = try panelDigest(core)
            #expect(first != opening && second != first)
            #expect(core.play.stage != .won, "level \(number): won after two legs")
            #expect(core.apply(panelAction("play.undo")) == .accepted)
            #expect(try panelDigest(core) == first, "level \(number): Undo")
            #expect(core.apply(panelAction("play.redo")) == .accepted)
            #expect(try panelDigest(core) == second, "level \(number): Redo")
        }
    }
}
