// BinaryGardensPanelWinTests — feature 504 (R02-G21-04) T-R02G2104-004 (FR-R02G2104-013; SC-R02G2104-005). Every
// move without gestures: all 100 certified levels are won through panel actions only. The panel of features 503 and
// 504 is modelled by a small pure helper (`BinaryGardensPanelModel`) that mirrors its controls: the star picker selects
// star 1 or 2 (presentation only, no action); the Ring choice sends exactly one `star.ring [star, index]` for the
// chosen ring; the Luminosity choice exactly one `star.luminosity [star, index]`; the Phase target stepper moves by the
// level's phase step g over 0 … 48 − g, wrapping (presentation only: no kernel action, no action spent, the digest
// unchanged) and "Set phase" sends exactly one `star.phase [star, target]`; the Tilt choice sends exactly one
// `orbit.tilt [step]`; "Run" sends `light.run`; Undo and Redo send `play.undo` and `play.redo`. The panel opens on star
// 1 with the phase target at its current phase; selecting a star moves the phase target to that star's phase. The real
// adapter `BinaryGardensExperienceCore` is prepared from seed n − 1 for level n and driven through `apply`; the plan is
// the stored witness of docs/games/binary-gardens/levels/NNN.witness.json: each witness action as the selected star and
// its direct choice (the phase target stepped the shorter way, then Set phase), then Run. After every action the
// witness's state digest and play fingerprint are reproduced; each level ends won with no more actions spent than its
// budget (exactly the witness's arrangement actions). The 100 levels run in 20 parameterized groups of 5 (each level is
// certified once per process, which dominates the time). Panel Undo then Redo restore the adapter digests of every
// arrangement action exactly. Explicit types, plain loops. Modelled on MushroomWeatherPanelWinTests (feature 494).
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreSimulation
@testable import BinaryGardensCore

/// The repository's witness directory, found from this file (five levels up: CoreTests, BinaryGardens, the package,
/// Packages).
private let panelWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/binary-gardens/levels", isDirectory: true)

/// The stored witness of level `number`, read with the plain decoder.
private func panelWitness(_ number: Int) throws -> BinaryGardensWitness {
    let name: String = String(format: "%03d.witness.json", number)
    let data: Data = try Data(contentsOf: panelWitnessDirectory.appendingPathComponent(name))
    return try JSONDecoder().decode(BinaryGardensWitness.self, from: data)
}

/// A pure model of the Binary Gardens control panel: the selection its star picker and phase stepper move and the
/// direct choices, Set phase, Run, Undo and Redo that turn it into adapter actions. It mirrors the panel's controls; it
/// is not the panel itself.
struct BinaryGardensPanelModel {
    /// The selected star (0 or 1).
    private(set) var star: Int = 0
    /// The phase target (0 … 48 − g, on the grid).
    private(set) var phaseTarget: Int
    /// The level's phase step g.
    let phaseStep: Int

    /// The panel showing `core`: star 1 selected, the phase target at its current phase.
    init(_ core: BinaryGardensExperienceCore) {
        phaseStep = max(core.play.level.phaseStep, 1)
        phaseTarget = core.play.arrangement.phases[0]
    }

    /// An adapter action of `control` with `values`.
    static func action(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The star picker: selects `star` and moves the phase target to its phase in `core`; no action is sent.
    mutating func select(_ star: Int, in core: BinaryGardensExperienceCore) {
        self.star = star
        phaseTarget = core.play.arrangement.phases[star]
    }

    /// The Ring choice: one `star.ring [star, index]` for the selected star.
    func ring(_ index: Int) -> ExperienceAction { Self.action("star.ring", [Double(star), Double(index)]) }

    /// The Luminosity choice: one `star.luminosity [star, index]` for the selected star.
    func luminosity(_ index: Int) -> ExperienceAction {
        Self.action("star.luminosity", [Double(star), Double(index)])
    }

    /// "Phase target +": the next grid phase, 48 − g wrapping to 0; no action is sent.
    mutating func phasePlus() { phaseTarget = (phaseTarget + phaseStep) % 48 }

    /// "Phase target −": the previous grid phase, 0 wrapping to 48 − g; no action is sent.
    mutating func phaseMinus() { phaseTarget = (phaseTarget - phaseStep + 48) % 48 }

    /// "Set phase": one `star.phase [star, target]` for the selected star.
    func setPhase() -> ExperienceAction { Self.action("star.phase", [Double(star), Double(phaseTarget)]) }

    /// The Tilt choice: one `orbit.tilt [step]`.
    func tilt(_ step: Int) -> ExperienceAction { Self.action("orbit.tilt", [Double(step)]) }

    /// "Run": `light.run`.
    func run() -> ExperienceAction { Self.action("light.run") }

    /// "Undo": `play.undo`.
    func undo() -> ExperienceAction { Self.action("play.undo") }

    /// "Redo": `play.redo`.
    func redo() -> ExperienceAction { Self.action("play.redo") }
}

@Suite struct BinaryGardensPanelWinTests {
    typealias Core = BinaryGardensExperienceCore
    typealias Panel = BinaryGardensPanelModel

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// Selects `star` in the panel; the selection changes no digest.
    static func select(_ star: Int, core: Core, panel: inout Panel) throws {
        let before: StateDigest = try digest(core)
        panel.select(star, in: core)
        #expect(panel.star == star)
        #expect(try digest(core) == before, "a selection changed the digest")
    }

    /// Steps the phase target to `step` the shorter way; no press changes the digest.
    static func stepPhase(to step: Int, core: Core, panel: inout Panel) throws {
        let before: StateDigest = try digest(core)
        let g: Int = panel.phaseStep
        let slots: Int = 48 / g
        let forward: Int = ((step - panel.phaseTarget) / g % slots + slots) % slots
        if forward <= slots - forward {
            for _ in 0..<forward { panel.phasePlus() }
        } else {
            for _ in 0..<(slots - forward) { panel.phaseMinus() }
        }
        #expect(panel.phaseTarget == step)
        #expect(try digest(core) == before, "a phase stepper press changed the digest")
    }

    /// The one panel action of witness action `action` (after selecting its star and stepping the phase target where
    /// needed), or nil for the run.
    static func panelAction(for action: BinaryGardensAction, core: Core, panel: inout Panel,
                            number: Int) throws -> ExperienceAction? {
        switch action {
        case let .ring(star, index):
            try select(star, core: core, panel: &panel)
            let sent: ExperienceAction = panel.ring(index)
            #expect(sent.control == "star.ring" && sent.values == [Double(star), Double(index)])
            return sent
        case let .phase(star, step):
            try select(star, core: core, panel: &panel)
            #expect(step % panel.phaseStep == 0, "level \(number): a witness phase off the grid")
            try stepPhase(to: step, core: core, panel: &panel)
            let sent: ExperienceAction = panel.setPhase()
            #expect(sent.control == "star.phase" && sent.values == [Double(star), Double(step)])
            return sent
        case let .luminosity(star, index):
            try select(star, core: core, panel: &panel)
            let sent: ExperienceAction = panel.luminosity(index)
            #expect(sent.control == "star.luminosity" && sent.values == [Double(star), Double(index)])
            return sent
        case let .tilt(step):
            let sent: ExperienceAction = panel.tilt(step)
            #expect(sent.control == "orbit.tilt" && sent.values == [Double(step)])
            return sent
        case .run:
            return nil
        }
    }

    /// Prepares level `number` from seed `number − 1`, checks it is the stored witness's level and applies every
    /// witness arrangement action through the panel (one panel action each), checking the witness digest and
    /// fingerprint after each; returns the core, the panel, the witness and the adapter digests (the opening, then
    /// after each arrangement action).
    static func arrangedThroughPanel(_ number: Int) async throws
        -> (core: Core, panel: Panel, witness: BinaryGardensWitness, digests: [StateDigest]) {
        let witness: BinaryGardensWitness = try panelWitness(number)
        var core: Core = try await Core.prepare(seed: UInt64(number - 1))
        #expect(core.levelNumber == number)
        #expect(core.play.level.fingerprint == witness.level.fingerprint, "level \(number) differs from its witness")
        var panel: Panel = Panel(core)
        #expect(witness.actions.last == .run, "level \(number): the witness does not end with the run")
        let offset: Int = witness.fingerprints.count - witness.actions.count
        var digests: [StateDigest] = [try digest(core)]
        for index in 0..<(witness.actions.count - 1) {
            let witnessAction: BinaryGardensAction = witness.actions[index]
            let sent: ExperienceAction? = try panelAction(for: witnessAction, core: core, panel: &panel,
                                                          number: number)
            let action: ExperienceAction = try #require(sent, "level \(number) action \(index): no panel action")
            #expect(core.apply(action) == .accepted, "level \(number) action \(index) refused")
            #expect(core.play.actionsSpent == index + 1, "level \(number) action \(index): more than one action")
            #expect(BinaryGardensWitness.digest(arrangement: core.play.arrangement, spent: core.play.actionsSpent)
                    == witness.digests[index], "level \(number) action \(index): witness digest")
            #expect(core.play.fingerprint == witness.fingerprints[offset + index],
                    "level \(number) action \(index): witness fingerprint")
            digests.append(try digest(core))
        }
        return (core, panel, witness, digests)
    }

    /// Wins level `number` through panel actions only, within its budget.
    static func winThroughPanel(_ number: Int) async throws {
        var arranged: (core: Core, panel: Panel, witness: BinaryGardensWitness, digests: [StateDigest]) =
            try await arrangedThroughPanel(number)
        let arrangementCount: Int = arranged.witness.actions.count - 1
        #expect(arranged.core.apply(arranged.panel.run()) == .accepted)
        #expect(arranged.core.play.stage == .won, "level \(number) not won through the panel")
        #expect(arranged.core.outcome?.code == Core.wonCode)
        #expect(arranged.core.play.fingerprint == arranged.witness.fingerprints.last)
        #expect(arranged.core.play.actionsSpent == arrangementCount)
        #expect(arranged.core.play.actionsSpent <= arranged.core.play.level.budget, "level \(number) over budget")
    }

    /// Levels 5 g + 1 … 5 g + 5 of group `group` (0 … 19).
    @Test(arguments: Array(0..<20))
    func panelWinsGroup(_ group: Int) async throws {
        for number in (group * 5 + 1)...(group * 5 + 5) {
            try await Self.winThroughPanel(number)
        }
    }

    /// Panel Undo walks back every arrangement action to the earlier digests exactly, and Redo forward to the later
    /// ones; nothing is left to undo at the opening or to redo at the end; the redone arrangement still wins on Run.
    @Test(arguments: [1, 50, 100])
    func panelUndoRedoRestoresDigests(_ number: Int) async throws {
        var arranged: (core: Core, panel: Panel, witness: BinaryGardensWitness, digests: [StateDigest]) =
            try await Self.arrangedThroughPanel(number)
        let count: Int = arranged.digests.count - 1
        #expect(count > 0)
        for index in stride(from: count - 1, through: 0, by: -1) {
            #expect(arranged.core.apply(arranged.panel.undo()) == .accepted)
            #expect(try Self.digest(arranged.core) == arranged.digests[index], "undo \(index) of level \(number)")
        }
        #expect(arranged.core.apply(arranged.panel.undo()) != .accepted)
        #expect(try Self.digest(arranged.core) == arranged.digests[0])
        for index in 1...count {
            #expect(arranged.core.apply(arranged.panel.redo()) == .accepted)
            #expect(try Self.digest(arranged.core) == arranged.digests[index], "redo \(index) of level \(number)")
        }
        #expect(arranged.core.apply(arranged.panel.redo()) != .accepted)
        #expect(arranged.core.apply(arranged.panel.run()) == .accepted)
        #expect(arranged.core.outcome?.code == Core.wonCode)
    }
}
