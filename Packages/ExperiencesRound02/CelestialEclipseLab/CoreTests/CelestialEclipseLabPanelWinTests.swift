// CelestialEclipseLabPanelWinTests — feature 464 (R02-G17-04) T-R02G1704-004 (FR-R02G1704-008; SC-R02G1704-005;
// clarification Q5). Every move without gestures: all 100 certified levels are won through panel actions only. The
// panel of feature 464 is modelled by a small pure helper (`CelestialEclipseLabPanelModel`): planet − and + send
// `orbit.choose` with the previous or next body (cycling 0 … n − 1, skipping nothing); phase − and + move a pending
// offset (presentation only, wrapping 0 … period − 1, no kernel action); "Set phase" sends exactly one
// `orbit.phase [body, pending]` when the pending offset differs from the chosen body's current phase; "Run" sends
// `clock.run`; Undo and Redo send `play.undo` and `play.redo`. The real adapter `CelestialEclipseLabExperienceCore` is
// prepared from seed n − 1 and driven through `apply`; the plan is each stored witness
// (`docs/games/celestial-eclipse-lab/levels/NNN.witness.json`, found from this file five levels up), whose phase
// changes are replayed by pressing planet ± the shorter way to the body, phase ± the shorter way to the offset, then
// "Set phase", and finally "Run". Each level ends won with no more actions spent than its budget (exactly the
// witness's phase changes), and no planet or pending press changes the digest. The 100 levels run in 10 parameterized
// groups of 10 so each test stays short. Panel Undo then Redo restore the digests of every phase change exactly.
// Explicit types, plain loops, single-literal comments.
import Foundation
import Testing
@testable import CelestialEclipseLabCore
import VisualCoreExperience

/// The repository's witness directory, found from this file (five levels up: CoreTests, CelestialEclipseLab, the
/// package, Packages).
private let panelWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/celestial-eclipse-lab/levels", isDirectory: true)

/// The stored witness of level `number`, read with the plain decoder.
private func panelWitness(_ number: Int) throws -> CelestialEclipseLabWitness {
    let name: String = String(CelestialEclipseLabGenerator.levelID(number).suffix(3)) + ".witness.json"
    let data: Data = try Data(contentsOf: panelWitnessDirectory.appendingPathComponent(name))
    return try JSONDecoder().decode(CelestialEclipseLabWitness.self, from: data)
}

/// A pure model of the feature-464 control panel: the chosen body and the pending phase offset it shows. Planet and
/// play buttons produce adapter actions; phase − and + only move the pending offset.
struct CelestialEclipseLabPanelModel {
    /// The chosen body, as the adapter last reported it.
    private(set) var chosenBody: Int
    /// The pending phase offset of the chosen body (presentation only, 0 … period − 1).
    private(set) var pending: Int
    /// The period of every body of the level.
    let periods: [Int]

    /// The panel showing `core`: its chosen body, with the pending offset at that body's current phase.
    init(_ core: CelestialEclipseLabExperienceCore) {
        var periods: [Int] = []
        for body in core.play.level.bodies { periods.append(body.period) }
        self.periods = periods
        self.chosenBody = core.chosenBody
        self.pending = core.play.phases[core.chosenBody]
    }

    /// The number of bodies of the level.
    var bodyCount: Int { periods.count }

    /// An adapter action of `control` with `values`.
    static func action(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// "Planet +": `orbit.choose` with the next body (n − 1 wraps to 0).
    func planetPlus() -> ExperienceAction {
        Self.action("orbit.choose", [Double((chosenBody + 1) % bodyCount)])
    }

    /// "Planet −": `orbit.choose` with the previous body (0 wraps to n − 1).
    func planetMinus() -> ExperienceAction {
        Self.action("orbit.choose", [Double((chosenBody + bodyCount - 1) % bodyCount)])
    }

    /// "Phase +": the pending offset forward by one, wrapping period − 1 to 0; no action is sent.
    mutating func phasePlus() {
        let period: Int = periods[chosenBody]
        pending = (pending + 1) % period
    }

    /// "Phase −": the pending offset back by one, wrapping 0 to period − 1; no action is sent.
    mutating func phaseMinus() {
        let period: Int = periods[chosenBody]
        pending = (pending + period - 1) % period
    }

    /// "Set phase": one `orbit.phase [body, pending]` when the pending offset differs from the chosen body's current
    /// phase in `phases`; nil otherwise.
    func setPhase(current phases: [Int]) -> ExperienceAction? {
        guard pending != phases[chosenBody] else { return nil }
        return Self.action("orbit.phase", [Double(chosenBody), Double(pending)])
    }

    /// "Run": `clock.run`.
    func run() -> ExperienceAction { Self.action("clock.run") }

    /// "Undo": `play.undo`.
    func undo() -> ExperienceAction { Self.action("play.undo") }

    /// "Redo": `play.redo`.
    func redo() -> ExperienceAction { Self.action("play.redo") }

    /// Follows `core` after an applied action: its chosen body, with the pending offset at that body's current phase.
    mutating func sync(_ core: CelestialEclipseLabExperienceCore) {
        chosenBody = core.chosenBody
        pending = core.play.phases[core.chosenBody]
    }
}

@Suite struct CelestialEclipseLabPanelWinTests {
    typealias Core = CelestialEclipseLabExperienceCore
    typealias Panel = CelestialEclipseLabPanelModel

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// Presses planet + or − the shorter way until the panel's chosen body is `body`; every press is accepted and
    /// leaves the digest unchanged.
    static func choose(_ body: Int, core: inout Core, panel: inout Panel) throws {
        let count: Int = panel.bodyCount
        let forward: Int = (body - panel.chosenBody + count) % count
        let plus: Bool = forward <= count - forward
        let presses: Int = plus ? forward : count - forward
        for _ in 0..<presses {
            let before: StateDigest = try digest(core)
            let press: ExperienceAction = plus ? panel.planetPlus() : panel.planetMinus()
            #expect(core.apply(press) == .accepted)
            panel.sync(core)
            #expect(try digest(core) == before, "a planet press changed the digest")
        }
        #expect(panel.chosenBody == body)
        #expect(core.chosenBody == body)
    }

    /// Presses phase + or − the shorter way until the panel's pending offset is `offset`; no press changes the digest.
    static func movePending(to offset: Int, core: Core, panel: inout Panel) throws {
        let period: Int = panel.periods[panel.chosenBody]
        let forward: Int = (offset - panel.pending + period) % period
        let plus: Bool = forward <= period - forward
        let presses: Int = plus ? forward : period - forward
        for _ in 0..<presses {
            let before: StateDigest = try digest(core)
            if plus { panel.phasePlus() } else { panel.phaseMinus() }
            #expect(try digest(core) == before, "a pending-offset press changed the digest")
        }
        #expect(panel.pending == offset)
    }

    /// Applies one witness phase change through the panel: choose the body, move the pending offset, "Set phase".
    static func commit(body: Int, offset: Int, core: inout Core, panel: inout Panel) throws {
        try choose(body, core: &core, panel: &panel)
        try movePending(to: offset, core: core, panel: &panel)
        let set: ExperienceAction = try #require(panel.setPhase(current: core.play.phases),
                                                 "witness offset equals the current phase")
        #expect(core.apply(set) == .accepted)
        panel.sync(core)
        #expect(core.play.phases[body] == offset)
        #expect(panel.setPhase(current: core.play.phases) == nil)
    }

    /// The phase changes of `witness` (its actions without the closing run) as (body, offset) pairs.
    static func changes(_ witness: CelestialEclipseLabWitness) -> [(body: Int, offset: Int)] {
        var result: [(body: Int, offset: Int)] = []
        for action in witness.actions {
            if case let .phase(body, offset) = action { result.append((body, offset)) }
        }
        return result
    }

    /// Prepares level `number` from seed `number − 1`, checks it is the witness's level and replays the witness's
    /// phase changes through the panel; returns the core and panel before the run.
    static func playedThroughPanel(_ number: Int) async throws -> (core: Core, panel: Panel, changes: Int) {
        let witness: CelestialEclipseLabWitness = try panelWitness(number)
        var core: Core = try await Core.prepare(seed: UInt64(number - 1))
        #expect(core.levelNumber == number)
        #expect(core.play.level.fingerprint == witness.level.fingerprint, "level \(number) differs from its witness")
        var panel = Panel(core)
        let planned: [(body: Int, offset: Int)] = changes(witness)
        for change in planned {
            try commit(body: change.body, offset: change.offset, core: &core, panel: &panel)
        }
        return (core, panel, planned.count)
    }

    /// Wins level `number` through panel actions only, within its budget.
    static func winThroughPanel(_ number: Int) async throws {
        var played: (core: Core, panel: Panel, changes: Int) = try await playedThroughPanel(number)
        #expect(played.core.apply(played.panel.run()) == .accepted)
        #expect(played.core.outcome?.code == Core.wonCode, "level \(number) not won through the panel")
        #expect(played.core.play.actionsSpent == played.changes)
        #expect(played.core.play.actionsSpent <= played.core.play.level.budget, "level \(number) over budget")
    }

    /// Levels 10 g + 1 … 10 g + 10 of group `group` (0 … 9).
    @Test(arguments: Array(0..<10))
    func panelWinsGroup(_ group: Int) async throws {
        for number in (group * 10 + 1)...(group * 10 + 10) {
            try await Self.winThroughPanel(number)
        }
    }

    /// Panel Undo walks back every phase change to the earlier digests exactly, and Redo forward to the later ones;
    /// the pending offset follows the restored phase; the redone play still wins.
    @Test(arguments: [1, 48, 100])
    func panelUndoRedoRestoresDigests(_ number: Int) async throws {
        let witness: CelestialEclipseLabWitness = try panelWitness(number)
        var core: Core = try await Core.prepare(seed: UInt64(number - 1))
        var panel = Panel(core)
        var digests: [StateDigest] = [try Self.digest(core)]
        let planned: [(body: Int, offset: Int)] = Self.changes(witness)
        for change in planned {
            try Self.commit(body: change.body, offset: change.offset, core: &core, panel: &panel)
            digests.append(try Self.digest(core))
        }
        #expect(!planned.isEmpty)
        for index in stride(from: planned.count - 1, through: 0, by: -1) {
            #expect(core.apply(panel.undo()) == .accepted)
            panel.sync(core)
            #expect(try Self.digest(core) == digests[index], "undo \(index) of level \(number)")
            #expect(panel.pending == core.play.phases[panel.chosenBody])
        }
        #expect(core.apply(panel.undo()) != .accepted)
        for index in 1...planned.count {
            #expect(core.apply(panel.redo()) == .accepted)
            panel.sync(core)
            #expect(try Self.digest(core) == digests[index], "redo \(index) of level \(number)")
        }
        #expect(core.apply(panel.redo()) != .accepted)
        #expect(core.apply(panel.run()) == .accepted)
        #expect(core.outcome?.code == Core.wonCode)
    }

    /// The pending offset wraps both ways and "Set phase" sends nothing while it equals the current phase.
    @Test func pendingOffsetWrapsAndSetPhaseNeedsAChange() async throws {
        let core: Core = try await Core.prepare(seed: 0)
        var panel = Panel(core)
        let period: Int = panel.periods[panel.chosenBody]
        let start: Int = panel.pending
        #expect(panel.setPhase(current: core.play.phases) == nil)
        for _ in 0..<period { panel.phasePlus() }
        #expect(panel.pending == start)
        for _ in 0..<period { panel.phaseMinus() }
        #expect(panel.pending == start)
        panel.phaseMinus()
        #expect(panel.pending == (start + period - 1) % period)
        let set: ExperienceAction = try #require(panel.setPhase(current: core.play.phases))
        #expect(set.control == "orbit.phase")
        #expect(set.values == [Double(panel.chosenBody), Double(panel.pending)])
    }
}
