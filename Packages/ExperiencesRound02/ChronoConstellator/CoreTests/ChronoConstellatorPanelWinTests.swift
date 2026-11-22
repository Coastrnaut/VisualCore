// ChronoConstellatorPanelWinTests — feature 354 (R02-G06-04) T-R02G0604-004 (US5). Every certified level 1 … 100 is
// won through the control panel's actions only, applied to `ChronoConstellatorExperienceCore` exactly as the panel
// sends them: the star picker visits the stars in order; for each star whose certified start phase differs from its
// current one, "Phase +" or "Phase −" (the shorter way round the loop) is pressed repeatedly, each press one
// `star.phase [star, (phase ± 1) mod L]` from the snapshot's phases (the mirror's rule); then Run sends `time.step` of
// the ticks left (at least 1, at most 1,200). The play must end in stage `won` with outcome `won`. Intermediate presses
// never exceed the edit budget: the edits in use count the stars off their default phase, not the presses. The levels
// are generated concurrently into the adapter's per-process cache, and split in groups so each test stays short. A last
// test: panel Undo after a phase press restores the digest from before it and Redo the digest after it. Host-run
// (`swift test`); explicit types, plain loops.
import Foundation
import Testing
@testable import ChronoConstellatorCore
import VisualCoreDiagnostics
import VisualCoreExperience

/// The digest of `core` as the engine computes it.
private func panelDigest(_ core: ChronoConstellatorExperienceCore) throws -> String {
    var builder: DigestBuilder = DigestBuilder(domain: ChronoConstellatorExperienceCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// A panel button's action: `control` with `values`.
private func panelAction(_ control: String, _ values: [Double] = []) -> ExperienceAction {
    ExperienceAction(control: control, values: values, step: 0)
}

/// The phase the panel's "Phase −" (`delta` −1) or "Phase +" (`delta` 1) sends for `star` (the mirror's rule).
private func panelPhase(_ core: ChronoConstellatorExperienceCore, star: Int, delta: Int) -> Int {
    let snapshot: ChronoConstellatorSceneSnapshot = core.snapshot(time: 0)
    let length: Int = core.play.level.stars[star].length
    return ((snapshot.phases[star] + delta) % length + length) % length
}

/// The panel Run button's tick count: the ticks left, at least 1 and at most 1,200.
private func panelRunTicks(_ core: ChronoConstellatorExperienceCore) -> Int {
    let snapshot: ChronoConstellatorSceneSnapshot = core.snapshot(time: 0)
    return max(1, min(1_200, snapshot.tickLimit - snapshot.tick))
}

/// Generates the levels `numbers` concurrently into the adapter's per-process cache.
private func panelPrewarm(_ numbers: [Int]) async {
    await withTaskGroup(of: Void.self) { (group: inout TaskGroup<Void>) in
        for number in numbers {
            group.addTask { _ = try? ChronoConstellatorExperienceCore.generated(number: number) }
        }
    }
}

/// Plays certified level `number` through panel actions only; returns the problems found (empty: won).
private func panelProblems(level number: Int) throws -> [String] {
    let generated: ChronoConstellatorGenerated = try ChronoConstellatorExperienceCore.generated(number: number)
    var core: ChronoConstellatorExperienceCore = try ChronoConstellatorExperienceCore.opening(number: number)
    var problems: [String] = []
    let target: [Int] = generated.solution.phases
    if target.count != core.play.level.stars.count { return ["level \(number): solution has \(target.count) phases"] }
    for star in 0..<target.count {
        let length: Int = core.play.level.stars[star].length
        let current: Int = core.snapshot(time: 0).phases[star]
        let forward: Int = ((target[star] - current) % length + length) % length
        let delta: Int = forward <= length - forward ? 1 : -1
        let presses: Int = delta == 1 ? forward : length - forward
        var press: Int = 0
        while press < presses {
            let phase: Int = panelPhase(core, star: star, delta: delta)
            let result: ActionResult = core.apply(panelAction("star.phase", [Double(star), Double(phase)]))
            if result != .accepted {
                problems.append("level \(number): star \(star) phase \(phase) gave \(result)")
                return problems
            }
            press += 1
        }
        let reached: Int = core.snapshot(time: 0).phases[star]
        if reached != target[star] {
            problems.append("level \(number): star \(star) at \(reached), not \(target[star])")
        }
    }
    let run: Int = panelRunTicks(core)
    let result: ActionResult = core.apply(panelAction("time.step", [Double(run)]))
    if result != .accepted { problems.append("level \(number): Run \(run) gave \(result)") }
    if core.play.stage != .won { problems.append("level \(number): stage \(core.play.stage.rawValue)") }
    let outcome: String? = core.outcome?.code
    if outcome != ChronoConstellatorExperienceCore.wonCode {
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

@Suite struct ChronoConstellatorPanelWinTests {
    @Test func levels1To25AreWonThroughThePanel() async throws {
        let problems: [String] = try await panelProblems(levels: 1...25)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func levels26To50AreWonThroughThePanel() async throws {
        let problems: [String] = try await panelProblems(levels: 26...50)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func levels51To75AreWonThroughThePanel() async throws {
        let problems: [String] = try await panelProblems(levels: 51...75)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func levels76To100AreWonThroughThePanel() async throws {
        let problems: [String] = try await panelProblems(levels: 76...100)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func panelUndoAndRedoAfterAPhaseChangeRestoreTheDigests() throws {
        var core: ChronoConstellatorExperienceCore = try ChronoConstellatorExperienceCore.opening(number: 1)
        let phase: Int = panelPhase(core, star: 0, delta: 1)
        let before: String = try panelDigest(core)
        #expect(core.apply(panelAction("star.phase", [0, Double(phase)])) == .accepted)
        let after: String = try panelDigest(core)
        #expect(after != before)
        #expect(core.apply(panelAction("play.undo")) == .accepted)
        #expect(try panelDigest(core) == before)
        #expect(core.apply(panelAction("play.redo")) == .accepted)
        #expect(try panelDigest(core) == after)
    }
}
