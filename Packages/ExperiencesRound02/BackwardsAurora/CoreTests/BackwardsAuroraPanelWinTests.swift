// BackwardsAuroraPanelWinTests — feature 394 (R02-G10-04) T-R02G1004-005 (FR-R02G1004-006; SC-R02G1004-005). Every
// certified level 1 … 100 is won through the control panel's buttons only, applied to `BackwardsAuroraExperienceCore`
// exactly as the panel sends them. A pure panel model copies the stepper arithmetic of the presenter's mirror
// (`BackwardsAuroraMirror`, iOS only): a level opens with the section 0 … 1; Start − and + move the start by ±1 clamped
// to 0 … N − 2 and the end follows to stay after it; End − and + move the end by ±1 clamped to 1 … N − 1 and the start
// follows to stay before it; after every action, undo or redo the section follows the play (a new level resets it to
// 0 … 1, otherwise it is clamped to the wave), so the section persists between reversals within a level. Reverse sends
// `wave.reverse [start, end]`, Undo `play.undo`, Redo `play.redo`. For each reversal of the level's certified solution
// (`BackwardsAuroraExperienceCore.generated(number:).solution.actions`) only stepper buttons are pressed (at most 64
// per reversal) from the panel's current section until it is the reversal's [start, end], then Reverse. Every Reverse
// must be accepted, the play must end in stage `won` with outcome `won`, and it must spend exactly the certified
// reversal count. The levels are certified concurrently into the adapter's per-process cache and split into ten groups
// of ten so each test stays short. A last test: panel Undo after a reversal on level 1 restores the digest from before
// it and Redo the digest after it. No randomness. Host-run (`swift test`); explicit types, plain loops.
import Foundation
import Testing
@testable import BackwardsAuroraCore
import VisualCoreDiagnostics
import VisualCoreExperience

/// The most stepper presses the panel may spend lining up one reversal.
private let panelPressLimit: Int = 64

/// The adapter's digest of `core` in hex.
private func panelDigest(_ core: BackwardsAuroraExperienceCore) throws -> String {
    var builder: DigestBuilder = DigestBuilder(domain: BackwardsAuroraExperienceCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// The action a panel button sends.
private func panelAction(_ control: String, _ values: [Double] = []) -> ExperienceAction {
    ExperienceAction(control: control, values: values, step: 0)
}

/// The panel's section and its stepper arithmetic, copied from `BackwardsAuroraMirror` (`stepStart`, `stepEnd`,
/// `follow`).
private struct BackwardsAuroraPanelModel {
    /// The play the section is clamped against.
    var play: BackwardsAuroraPlay
    /// The chosen section's start and end.
    var start: Int = 0
    var end: Int = 1
    /// The stepper presses so far.
    var presses: Int = 0

    init(play: BackwardsAuroraPlay) {
        self.play = play
    }

    /// The wave's sample count.
    var count: Int { play.wave.count }

    /// The mirror's `stepStart`: the start by `delta`, clamped to 0 … N − 2; the end follows to stay after it.
    mutating func stepStart(_ delta: Int) {
        start = min(max(start + delta, 0), count - 2)
        if end <= start { end = start + 1 }
    }

    /// The mirror's `stepEnd`: the end by `delta`, clamped to 1 … N − 1; the start follows to stay before it.
    mutating func stepEnd(_ delta: Int) {
        end = min(max(end + delta, 1), count - 1)
        if start >= end { start = end - 1 }
    }

    /// A press of Start − or + (`delta` −1 or 1).
    mutating func pressStart(_ delta: Int) {
        presses += 1
        stepStart(delta)
    }

    /// A press of End − or + (`delta` −1 or 1).
    mutating func pressEnd(_ delta: Int) {
        presses += 1
        stepEnd(delta)
    }

    /// The mirror's `follow`: a new level resets the section to 0 … 1; otherwise it is clamped to the wave.
    mutating func follow(_ next: BackwardsAuroraPlay) {
        let changedLevel: Bool = play.level.id != next.level.id
        play = next
        if changedLevel {
            start = 0
            end = 1
        } else {
            stepStart(0)
            stepEnd(0)
        }
    }

    /// Presses Start ± until the start is `target`; false when it stops moving or the press limit is spent.
    mutating func lineUpStart(_ target: Int, from first: Int) -> Bool {
        while start != target {
            if presses - first >= panelPressLimit { return false }
            let before: Int = start
            pressStart(target > start ? 1 : -1)
            if start == before { return false }
        }
        return true
    }

    /// Presses End ± until the end is `target`; false when it stops moving or the press limit is spent.
    mutating func lineUpEnd(_ target: Int, from first: Int) -> Bool {
        while end != target {
            if presses - first >= panelPressLimit { return false }
            let before: Int = end
            pressEnd(target > end ? 1 : -1)
            if end == before { return false }
        }
        return true
    }

    /// Lines the section up with [`targetStart`, `targetEnd`] by stepper presses only. When the target start is at or
    /// past the current end, the end moves up first (the start does not follow an end moving up), then the start;
    /// otherwise the start moves first (it stays before the current end, so the end does not follow), then the end
    /// (it stays after the target start, so the start does not follow).
    mutating func lineUp(_ targetStart: Int, _ targetEnd: Int) -> Bool {
        let first: Int = presses
        if targetStart >= end {
            guard lineUpEnd(targetEnd, from: first), lineUpStart(targetStart, from: first) else { return false }
        } else {
            guard lineUpStart(targetStart, from: first), lineUpEnd(targetEnd, from: first) else { return false }
        }
        return start == targetStart && end == targetEnd
    }
}

/// Lines the panel up with `action` and returns what Reverse then sends; nil when the steppers cannot reach it.
private func panelPress(_ action: BackwardsAuroraAction,
                        _ panel: inout BackwardsAuroraPanelModel) -> (control: String, values: [Double])? {
    switch action {
    case let .reverse(start, end):
        guard panel.lineUp(start, end) else { return nil }
        return ("wave.reverse", [Double(panel.start), Double(panel.end)])
    }
}

/// Certifies `numbers` concurrently into the adapter's per-process cache.
private func panelPrewarm(_ numbers: [Int]) async {
    await withTaskGroup(of: Void.self) { (group: inout TaskGroup<Void>) in
        for number in numbers {
            group.addTask { _ = try? BackwardsAuroraExperienceCore.generated(number: number) }
        }
    }
}

/// Plays level `number` through the panel model; the problems found (empty when it is won as certified).
private func panelProblems(level number: Int) throws -> [String] {
    let actions: [BackwardsAuroraAction] = try BackwardsAuroraExperienceCore.generated(number: number).solution.actions
    if actions.isEmpty { return ["level \(number): empty certified solution"] }
    var core: BackwardsAuroraExperienceCore = try BackwardsAuroraExperienceCore.opening(number: number)
    var panel: BackwardsAuroraPanelModel = BackwardsAuroraPanelModel(play: core.play)
    if panel.start != 0 || panel.end != 1 {
        return ["level \(number): panel opened at \(panel.start) … \(panel.end)"]
    }
    var index: Int = 0
    for action in actions {
        guard let press = panelPress(action, &panel) else {
            return ["level \(number): reversal \(index) \(action) not reached from \(panel.start) … \(panel.end)"]
        }
        let result: ActionResult = core.apply(panelAction(press.control, press.values))
        if result != .accepted {
            return ["level \(number): reversal \(index) \(action): \(press.control) \(press.values) gave \(result)"]
        }
        panel.follow(core.play)
        index += 1
    }
    var problems: [String] = []
    if core.play.stage != .won { problems.append("level \(number): stage \(core.play.stage)") }
    if core.play.spent != actions.count {
        problems.append("level \(number): \(core.play.spent) reversals, certified \(actions.count)")
    }
    let outcome: String? = core.outcome?.code
    if outcome != BackwardsAuroraExperienceCore.wonCode {
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

@Suite struct BackwardsAuroraPanelWinTests {
    /// SC-R02G1004-005: every level of `group` is won through the steppers and Reverse in its certified count.
    @Test(arguments: panelGroups)
    func levelsAreWonThroughThePanel(_ group: ClosedRange<Int>) async throws {
        let problems: [String] = try await panelProblems(levels: group)
        #expect(problems.isEmpty, "\(problems)")
    }

    /// FR-R02G1004-006: panel Undo after a reversal restores the digest from before it; Redo the digest after it.
    @Test func panelUndoAndRedoAfterAReversalRestoreTheDigests() throws {
        var core: BackwardsAuroraExperienceCore = try BackwardsAuroraExperienceCore.opening(number: 1)
        var panel: BackwardsAuroraPanelModel = BackwardsAuroraPanelModel(play: core.play)
        let before: String = try panelDigest(core)
        let actions: [BackwardsAuroraAction] = try BackwardsAuroraExperienceCore.generated(number: 1).solution.actions
        let chosen: BackwardsAuroraAction = try #require(actions.first)
        let press: (control: String, values: [Double]) = try #require(panelPress(chosen, &panel))
        #expect(press.control == "wave.reverse")
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
