// NocturneGardenPanelWinTests — feature 384 (R02-G09-04) T-R02G0904-005. Every certified level 1 … 100 is won through
// the control panel's buttons only, applied to `NocturneGardenExperienceCore` exactly as the panel sends them. A pure
// panel model mirrors the presenter's mirror (`NocturneGardenMirror`, iOS only): a level opens with its first supplied
// kind, column 0, row 0, its smallest allowed size, bloom 0 and the play's sun; the kind picker moves by ±1 wrapping
// over the kinds the level supplies (kernel order); column and row move by ±1 clamped to the bed; size moves by ±1 over
// the level's allowed sizes, clamped; the bloom picker moves by ±1 wrapping over the planted blooms; after every
// action, undo or redo the sun follows the play and the bloom pick is clamped to the blooms planted. Plant sends
// `bloom.plant [kind, column, row, size]`, Move `bloom.move [bloom, column, row]`, Resize `bloom.resize [bloom, size]`,
// Remove `bloom.remove [bloom]`, Undo `play.undo`, Redo `play.redo`; Sun − and + move the sun pick over the level's
// allowed elevations (clamped) and Set sun sends `sun.set [pick]` (the panel as corrected during implementation: a first
// version whose Sun ± sent single steps spent up to 2 extra moves on 35 levels, so the panel could not play the
// smallest move count). For each action of the level's certified solution
// (`NocturneGardenExperienceCore.generated(number:).solution.actions`) only picker buttons are pressed (at most 64 per
// action) until the picks are the action's values, then its button. Every press of an action button must be accepted,
// the play must end in stage `won` with outcome `won`, and it must spend exactly the certified smallest move count. The levels
// are certified concurrently into the adapter's per-process cache and split into ten groups of ten so each test stays
// short. A last test: panel Undo after a plant on level 1 restores the digest from before it and Redo the digest after
// it. No randomness. Host-run (`swift test`); explicit types, plain loops.
import Foundation
import Testing
@testable import NocturneGardenCore
import VisualCoreDiagnostics
import VisualCoreExperience

/// The most picker presses spent lining up one action.
private let panelPressLimit: Int = 64

/// The digest of `core` as the engine computes it.
private func panelDigest(_ core: NocturneGardenExperienceCore) throws -> String {
    var builder: DigestBuilder = DigestBuilder(domain: NocturneGardenExperienceCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// A panel button's action: `control` with `values`.
private func panelAction(_ control: String, _ values: [Double] = []) -> ExperienceAction {
    ExperienceAction(control: control, values: values, step: 0)
}

/// The panel's picks and their stepping rules, mirroring `NocturneGardenMirror` (pure; presentation state only).
private struct NocturneGardenPanelModel {
    /// The play the picks are clamped against.
    var play: NocturneGardenPlay
    /// The picked kind's index in the kernel's kind order.
    var kind: Int
    /// The picked anchor column.
    var column: Int = 0
    /// The picked anchor row.
    var row: Int = 0
    /// The picked size.
    var size: Int
    /// The picked bloom's index in canonical order.
    var bloom: Int = 0
    /// The current sun elevation.
    var sun: Int
    /// The picked sun elevation (Set sun sends it).
    var sunPick: Int
    /// The picker buttons pressed so far.
    var presses: Int = 0

    /// A panel opening on `play`: its first supplied kind, column 0, row 0, its smallest size, bloom 0, its sun.
    init(play: NocturneGardenPlay) {
        self.play = play
        self.kind = Self.suppliedKinds(play.level).first ?? 0
        self.size = play.level.sizes.min() ?? 1
        self.sun = play.elevation
        self.sunPick = play.elevation
    }

    /// Sun − (delta −1) or Sun + (delta +1): the sun pick moves over the level's allowed elevations, clamped.
    mutating func stepSun(_ delta: Int) {
        presses += 1
        let allowed: [Int] = play.level.elevations.sorted()
        let at: Int = allowed.firstIndex(of: sunPick) ?? 0
        sunPick = allowed[Swift.min(Swift.max(at + delta, 0), allowed.count - 1)]
    }

    /// The kind indices (kernel order) the level supplies, ascending.
    static func suppliedKinds(_ level: NocturneGardenLevel) -> [Int] {
        var result: [Int] = []
        for kind in NocturneGardenKind.allCases where level.supplyCount(kind) > 0 { result.append(kind.order) }
        return result
    }

    /// The kind picker by `delta`, wrapping over the supplied kinds.
    mutating func pickKind(_ delta: Int) {
        presses += 1
        let supplied: [Int] = Self.suppliedKinds(play.level)
        if supplied.isEmpty { return }
        let at: Int = supplied.firstIndex(of: kind) ?? 0
        kind = supplied[((at + delta) % supplied.count + supplied.count) % supplied.count]
    }

    /// The column picker by `delta`, clamped to the bed.
    mutating func stepColumn(_ delta: Int) {
        presses += 1
        column = min(max(column + delta, 0), play.level.width - 1)
    }

    /// The row picker by `delta`, clamped to the bed.
    mutating func stepRow(_ delta: Int) {
        presses += 1
        row = min(max(row + delta, 0), play.level.height - 1)
    }

    /// The size picker by `delta` over the level's allowed sizes, clamped.
    mutating func stepSize(_ delta: Int) {
        presses += 1
        let sizes: [Int] = play.level.sizes.sorted()
        let at: Int = sizes.firstIndex(of: size) ?? 0
        size = sizes[min(max(at + delta, 0), sizes.count - 1)]
    }

    /// The bloom picker by `delta`, wrapping over the planted blooms.
    mutating func pickBloom(_ delta: Int) {
        presses += 1
        let count: Int = play.blooms.count
        if count == 0 { return }
        bloom = ((bloom + delta) % count + count) % count
    }

    /// Takes the play after an action, undo or redo: the sun follows it and the bloom pick is clamped.
    mutating func follow(_ next: NocturneGardenPlay) {
        play = next
        if sun != next.elevation { sunPick = next.elevation }
        sun = next.elevation
        bloom = min(bloom, max(next.blooms.count - 1, 0))
    }

    /// The shorter wrapping delta (−1 or +1) from `from` to `to` over `count` values; 0 when equal.
    static func wrapDelta(from: Int, to: Int, count: Int) -> Int {
        if from == to || count == 0 { return 0 }
        let forward: Int = ((to - from) % count + count) % count
        return forward <= count - forward ? 1 : -1
    }

    /// Presses the kind picker until it shows `target`; false past the press limit.
    mutating func lineUpKind(_ target: Int, start: Int) -> Bool {
        let supplied: [Int] = Self.suppliedKinds(play.level)
        guard let goal = supplied.firstIndex(of: target) else { return false }
        while kind != target {
            if presses - start >= panelPressLimit { return false }
            let at: Int = supplied.firstIndex(of: kind) ?? 0
            pickKind(Self.wrapDelta(from: at, to: goal, count: supplied.count))
        }
        return true
    }

    /// Presses the column and row pickers until they show (`targetColumn`, `targetRow`); false past the press limit
    /// or when a press does not move the pick.
    mutating func lineUpCell(_ targetColumn: Int, _ targetRow: Int, start: Int) -> Bool {
        while column != targetColumn {
            if presses - start >= panelPressLimit { return false }
            let before: Int = column
            stepColumn(targetColumn > column ? 1 : -1)
            if column == before { return false }
        }
        while row != targetRow {
            if presses - start >= panelPressLimit { return false }
            let before: Int = row
            stepRow(targetRow > row ? 1 : -1)
            if row == before { return false }
        }
        return true
    }

    /// Presses the size picker until it shows `target`; false past the press limit or when a press does not move it.
    mutating func lineUpSize(_ target: Int, start: Int) -> Bool {
        while size != target {
            if presses - start >= panelPressLimit { return false }
            let before: Int = size
            stepSize(target > size ? 1 : -1)
            if size == before { return false }
        }
        return true
    }

    /// Presses the bloom picker until it shows `target`; false past the press limit or outside the planted blooms.
    mutating func lineUpBloom(_ target: Int, start: Int) -> Bool {
        if !play.blooms.indices.contains(target) { return false }
        while bloom != target {
            if presses - start >= panelPressLimit { return false }
            pickBloom(Self.wrapDelta(from: bloom, to: target, count: play.blooms.count))
        }
        return true
    }
}

/// Lines the panel up for `action` with picker presses and returns the button press it ends with (control and values),
/// or nil when the picks cannot be reached. A sun action is Sun − or + until the pick is its elevation, then Set sun.
private func panelPress(_ action: NocturneGardenAction,
                        _ panel: inout NocturneGardenPanelModel) -> (control: String, values: [Double])? {
    let start: Int = panel.presses
    switch action {
    case let .plant(kind, column, row, size):
        guard panel.lineUpKind(kind.order, start: start), panel.lineUpCell(column, row, start: start),
              panel.lineUpSize(size, start: start) else { return nil }
        return ("bloom.plant", [Double(panel.kind), Double(panel.column), Double(panel.row), Double(panel.size)])
    case let .move(bloom, column, row):
        guard panel.lineUpBloom(bloom, start: start), panel.lineUpCell(column, row, start: start) else { return nil }
        return ("bloom.move", [Double(panel.bloom), Double(panel.column), Double(panel.row)])
    case let .resize(bloom, size):
        guard panel.lineUpBloom(bloom, start: start), panel.lineUpSize(size, start: start) else { return nil }
        return ("bloom.resize", [Double(panel.bloom), Double(panel.size)])
    case let .remove(bloom):
        guard panel.lineUpBloom(bloom, start: start) else { return nil }
        return ("bloom.remove", [Double(panel.bloom)])
    case let .sun(elevation):
        while panel.sunPick != elevation {
            if panel.presses - start >= 64 { return nil }
            panel.stepSun(elevation < panel.sunPick ? -1 : 1)
        }
        return ("sun.set", [Double(panel.sunPick)])
    }
}

/// Certifies the levels `numbers` concurrently into the adapter's per-process cache.
private func panelPrewarm(_ numbers: [Int]) async {
    await withTaskGroup(of: Void.self) { (group: inout TaskGroup<Void>) in
        for number in numbers {
            group.addTask { _ = try? NocturneGardenExperienceCore.generated(number: number) }
        }
    }
}

/// Plays certified level `number` through panel buttons only; returns the problems found (empty: won).
private func panelProblems(level number: Int) throws -> [String] {
    let actions: [NocturneGardenAction] = try NocturneGardenExperienceCore.generated(number: number).solution.actions
    if actions.isEmpty { return ["level \(number): empty certified solution"] }
    var core: NocturneGardenExperienceCore = try NocturneGardenExperienceCore.opening(number: number)
    var panel: NocturneGardenPanelModel = NocturneGardenPanelModel(play: core.play)
    var index: Int = 0
    for action in actions {
        guard let press = panelPress(action, &panel) else {
            return ["level \(number): action \(index) \(action) not reached by the panel (sun \(panel.sun))"]
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
        problems.append("level \(number): \(core.play.moves) moves, certified \(actions.count)")
    }
    let outcome: String? = core.outcome?.code
    if outcome != NocturneGardenExperienceCore.wonCode {
        problems.append("level \(number): outcome \(outcome ?? "none")")
    }
    return problems
}

/// The problems of every level in `numbers`, after certifying them concurrently into the process cache.
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

@Suite struct NocturneGardenPanelWinTests {
    /// Every certified level of the group is won through the panel's buttons only.
    @Test(arguments: panelGroups)
    func levelsAreWonThroughThePanel(_ group: ClosedRange<Int>) async throws {
        let problems: [String] = try await panelProblems(levels: group)
        #expect(problems.isEmpty, "\(problems)")
    }

    /// Panel Undo after a plant on level 1 restores the digest from before it; Redo the digest after it.
    @Test func panelUndoAndRedoAfterAPlantRestoreTheDigests() throws {
        var core: NocturneGardenExperienceCore = try NocturneGardenExperienceCore.opening(number: 1)
        var panel: NocturneGardenPanelModel = NocturneGardenPanelModel(play: core.play)
        let before: String = try panelDigest(core)
        var plant: NocturneGardenAction? = nil
        let actions: [NocturneGardenAction] = try NocturneGardenExperienceCore.generated(number: 1).solution.actions
        for action in actions {
            if case .plant = action {
                plant = action
                break
            }
        }
        let chosen: NocturneGardenAction = try #require(plant)
        let press: (control: String, values: [Double]) = try #require(panelPress(chosen, &panel))
        #expect(press.control == "bloom.plant")
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
