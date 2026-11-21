// ColorfallCanyonsPanelWinTests — feature 344 (R02-G05-04) T-R02G0504-004 (FR-R02G0504-006, SC-R02G0504-004). Every
// certified level 1 … 100 is won through the control panel's actions only, played on `ExperienceEngine` as the
// scenarios play it (seed `level − 1`): each certified carve is first found in the panel's picker list — the carvable
// cells in index order, computed as the panel's mirror computes it from the snapshot's heights — and then sent as
// `canyon.carve`; each valve is sent as `canyon.valve` (one button per spring); each certified step is the panel's Run
// (`time.step` of the ticks left, at most 600), whose tick count must equal the step the solution prescribes. The play
// must end won. The 100 levels are split in four tests of 25 so each stays short. A last test: on level 1, panel Undo
// after a panel carve restores the digest from before the carve and Redo the digest after it. Host-run (`swift test`);
// explicit types, plain loops.
#if DEBUG || VISUALCORE_AUTOMATION
@testable import ColorfallCanyonsCore
import Foundation
import Testing
import VisualCoreExperience

/// The id of Colorfall Canyons as an experience.
private let panelExperienceID: ExperienceID = ExperienceID(rawValue: ColorfallCanyonsExperienceCore.experienceID)!

/// An active engine on certified level `number` (seed `number − 1`), as the scenarios open it.
private func panelEngine(level number: Int) async throws -> ExperienceEngine<ColorfallCanyonsExperienceCore> {
    var engine: ExperienceEngine<ColorfallCanyonsExperienceCore> =
        ExperienceEngine<ColorfallCanyonsExperienceCore>(id: panelExperienceID)
    try await engine.prepare(seed: ColorfallCanyonsExperienceCore.seed(forLevel: number))
    try engine.activate()
    return engine
}

/// The panel picker's list: the carvable cells of the core's level in index order, from the snapshot's heights (the
/// mirror's rule).
private func panelCarvable(_ core: ColorfallCanyonsExperienceCore) -> [Int] {
    let snapshot: ColorfallCanyonsSceneSnapshot = core.snapshot(time: 0)
    let level: ColorfallCanyonsLevel = core.play.level
    var cells: [Int] = []
    for cell in 0..<level.cellCount where level.isCarvable(cell, heights: snapshot.heights) { cells.append(cell) }
    return cells
}

/// The panel Run button's tick count: the ticks left, at least 1 and at most 600.
private func panelRunTicks(_ core: ColorfallCanyonsExperienceCore) -> Int {
    let snapshot: ColorfallCanyonsSceneSnapshot = core.snapshot(time: 0)
    return max(1, min(600, snapshot.tickLimit - snapshot.tick))
}

/// Plays certified level `number` through panel actions only; returns the problems found (empty: won).
private func panelProblems(level number: Int) async throws -> [String] {
    let actions: [ColorfallCanyonsAction] = ColorfallCanyonsExperienceCore.certifiedActions(number)
    guard !actions.isEmpty else { return ["level \(number): no certified actions"] }
    var engine: ExperienceEngine<ColorfallCanyonsExperienceCore> = try await panelEngine(level: number)
    var problems: [String] = []
    for action in actions {
        guard let core: ColorfallCanyonsExperienceCore = engine.core else {
            return problems + ["level \(number): no core"]
        }
        let control: String
        let value: Int
        switch action {
        case .carve(let cell):
            if !panelCarvable(core).contains(cell) {
                problems.append("level \(number): cell \(cell) not in the picker")
            }
            control = "canyon.carve"
            value = cell
        case .valve(let spring):
            if spring < 0 || spring >= core.play.level.springs.count {
                problems.append("level \(number): no valve button \(spring)")
            }
            control = "canyon.valve"
            value = spring
        case .step(let ticks):
            let run: Int = panelRunTicks(core)
            if run != ticks { problems.append("level \(number): Run \(run) ticks, solution \(ticks)") }
            control = "time.step"
            value = run
        }
        let code: String = engine.handle(control: control, values: [Double(value)]).code
        if code != "accepted" { problems.append("level \(number): \(control) \(value) gave \(code)") }
    }
    let outcome: String? = engine.core?.outcome?.code
    if outcome != ColorfallCanyonsExperienceCore.wonCode {
        problems.append("level \(number): outcome \(outcome ?? "none")")
    }
    return problems
}

/// The problems of every level in `numbers`, after generating them concurrently into the process cache.
private func panelProblems(levels numbers: ClosedRange<Int>) async throws -> [String] {
    var list: [Int] = []
    for number in numbers { list.append(number) }
    ColorfallCanyonsExperienceCore.prewarm(list)
    var problems: [String] = []
    for number in list { problems += try await panelProblems(level: number) }
    return problems
}

@Suite struct ColorfallCanyonsPanelWinTests {
    @Test func levels1To13AreWonThroughThePanel() async throws {
        let problems: [String] = try await panelProblems(levels: 1...13)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func levels14To25AreWonThroughThePanel() async throws {
        let problems: [String] = try await panelProblems(levels: 14...25)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func levels26To38AreWonThroughThePanel() async throws {
        let problems: [String] = try await panelProblems(levels: 26...38)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func levels39To50AreWonThroughThePanel() async throws {
        let problems: [String] = try await panelProblems(levels: 39...50)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func levels51To63AreWonThroughThePanel() async throws {
        let problems: [String] = try await panelProblems(levels: 51...63)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func levels64To75AreWonThroughThePanel() async throws {
        let problems: [String] = try await panelProblems(levels: 64...75)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func levels76To88AreWonThroughThePanel() async throws {
        let problems: [String] = try await panelProblems(levels: 76...88)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func levels89To100AreWonThroughThePanel() async throws {
        let problems: [String] = try await panelProblems(levels: 89...100)
        #expect(problems.isEmpty, "\(problems)")
    }

    @Test func panelUndoAndRedoAfterACarveRestoreTheDigests() async throws {
        var engine: ExperienceEngine<ColorfallCanyonsExperienceCore> = try await panelEngine(level: 1)
        let core: ColorfallCanyonsExperienceCore = try #require(engine.core)
        let cell: Int = try #require(panelCarvable(core).first)
        let before: String = try engine.digest().hex
        #expect(engine.handle(control: "canyon.carve", values: [Double(cell)]).code == "accepted")
        let after: String = try engine.digest().hex
        #expect(after != before)
        #expect(engine.handle(control: "play.undo").code == "accepted")
        #expect(try engine.digest().hex == before)
        #expect(engine.handle(control: "play.redo").code == "accepted")
        #expect(try engine.digest().hex == after)
    }
}
#endif
