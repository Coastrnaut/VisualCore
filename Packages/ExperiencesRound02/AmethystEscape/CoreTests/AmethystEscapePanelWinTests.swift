// AmethystEscapePanelWinTests — feature 364 (R02-G07-04) T-R02G0704-005 (US5). Every certified level 1 … 100 is won
// through the control panel's actions only, applied to `AmethystEscapeExperienceCore` exactly as the panel sends them:
// for each action of the level's certified solution (`AmethystEscapeGenerated.solution.actions`, the actions
// `certifiedActions(_:)` gives), a turn of shell k by −1 or +1 is the shell picker on k and "Turn −" or "Turn +", one
// `shell.rotate [k, −1 or +1]`; an advance is "Advance", one `pearl.advance`. Every press must be accepted and the play
// must end in stage `won` with outcome `won`. The levels are generated concurrently into the adapter's per-process cache
// and split in four groups of 25 so each test stays short. A last test: panel Undo after a turn restores the digest from
// before it and Redo the digest after it. No randomness. Host-run (`swift test`); explicit types, plain loops.
import Foundation
import Testing
@testable import AmethystEscapeCore
import VisualCoreDiagnostics
import VisualCoreExperience

/// The digest of `core` as the engine computes it.
private func panelDigest(_ core: AmethystEscapeExperienceCore) throws -> String {
    var builder: DigestBuilder = DigestBuilder(domain: AmethystEscapeExperienceCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// A panel button's action: `control` with `values`.
private func panelAction(_ control: String, _ values: [Double] = []) -> ExperienceAction {
    ExperienceAction(control: control, values: values, step: 0)
}

/// The action the panel sends for a kernel action: the shell picker on `shell` and "Turn −" or "Turn +" send
/// `shell.rotate [shell, step]`; "Advance" sends `pearl.advance`.
private func panelAction(for action: AmethystEscapeAction) -> ExperienceAction {
    switch action {
    case .rotate(let shell, let step):
        return panelAction("shell.rotate", [Double(shell), Double(step)])
    case .advance:
        return panelAction("pearl.advance")
    }
}

/// Generates the levels `numbers` concurrently into the adapter's per-process cache.
private func panelPrewarm(_ numbers: [Int]) async {
    await withTaskGroup(of: Void.self) { (group: inout TaskGroup<Void>) in
        for number in numbers {
            group.addTask { _ = try? AmethystEscapeExperienceCore.generated(number: number) }
        }
    }
}

/// Plays certified level `number` through panel actions only; returns the problems found (empty: won).
private func panelProblems(level number: Int) throws -> [String] {
    let generated: AmethystEscapeGenerated = try AmethystEscapeExperienceCore.generated(number: number)
    var core: AmethystEscapeExperienceCore = try AmethystEscapeExperienceCore.opening(number: number)
    let actions: [AmethystEscapeAction] = generated.solution.actions
    if actions.isEmpty { return ["level \(number): empty certified solution"] }
    var index: Int = 0
    for action in actions {
        let press: ExperienceAction = panelAction(for: action)
        let result: ActionResult = core.apply(press)
        if result != .accepted {
            return ["level \(number): press \(index) \(press.control) \(press.values) gave \(result)"]
        }
        index += 1
    }
    var problems: [String] = []
    if core.play.stage != .won { problems.append("level \(number): stage \(core.play.stage)") }
    let outcome: String? = core.outcome?.code
    if outcome != AmethystEscapeExperienceCore.wonCode {
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

@Suite struct AmethystEscapePanelWinTests {
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

    @Test func panelUndoAndRedoAfterATurnRestoreTheDigests() throws {
        var core: AmethystEscapeExperienceCore = try AmethystEscapeExperienceCore.opening(number: 1)
        let before: String = try panelDigest(core)
        #expect(core.apply(panelAction("shell.rotate", [0, 1])) == .accepted)
        let after: String = try panelDigest(core)
        #expect(after != before)
        #expect(core.apply(panelAction("play.undo")) == .accepted)
        #expect(try panelDigest(core) == before)
        #expect(core.apply(panelAction("play.redo")) == .accepted)
        #expect(try panelDigest(core) == after)
    }
}
