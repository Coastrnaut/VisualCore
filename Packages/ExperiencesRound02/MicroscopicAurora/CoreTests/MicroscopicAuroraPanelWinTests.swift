// MicroscopicAuroraPanelWinTests — feature 484 (R02-G19-04) T-R02G1904-004 (FR-R02G1904-009; SC-R02G1904-005).
// Every move without gestures: all 100 certified levels are won through panel actions only. The panel of features
// 483 and 484 is modelled by a small pure helper (`MicroscopicAuroraPanelModel`) that mirrors its controls: Well − and
// + pick the slot (wrapping 0 … 2), Site − and + pick a site of the level (wrapping over its sites), Strength − and +
// pick the strength (clamped 1 … 4) and the sense toggle picks clockwise or counterclockwise (presentation only: no
// kernel action, no action spent, the digest unchanged); "Place" sends exactly one `well.place [slot, row, column,
// strength, sense]` with the sense 0 clockwise and 1 counterclockwise; "Play" sends `swim.play`; Undo and Redo send
// `play.undo` and `play.redo`. The panel opens as the presenter's mirror does: well 1, the first site, strength 2,
// counterclockwise. The real adapter `MicroscopicAuroraExperienceCore` is prepared from seed n − 1 for level n and
// driven through `apply`; the plan is the stored witness of docs/games/microscopic-aurora/levels/NNN.witness.json (its
// placements in slot order, then the play): for each placement the − and + buttons move the selection the shorter
// way to the placement's slot, site and strength, the toggle sets its sense, and Place sends it; then Play. After every
// action the witness's state digest and play fingerprint are reproduced; each level ends won with no more actions
// spent than its budget (exactly the witness placements). The 100 levels run in 20 parameterized groups of 5 (each
// level is certified once per process, which dominates the time). Panel Undo then Redo restore the adapter digests of
// every placement exactly. Explicit types, plain loops. Modelled on ApsidesWorkshopPanelWinTests (feature 474).
import Foundation
@testable import MicroscopicAuroraCore
import Testing
import VisualCoreExperience

/// The repository's witness directory, found from this file (five levels up: CoreTests, MicroscopicAurora, the
/// package, Packages).
private let panelWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/microscopic-aurora/levels", isDirectory: true)

/// The stored witness of level `number`, read with the plain decoder.
private func panelWitness(_ number: Int) throws -> MicroscopicAuroraWitness {
    let name: String = String(MicroscopicAuroraGenerator.levelID(number).suffix(3)) + ".witness.json"
    let data: Data = try Data(contentsOf: panelWitnessDirectory.appendingPathComponent(name))
    return try JSONDecoder().decode(MicroscopicAuroraWitness.self, from: data)
}

/// A pure model of the Microscopic Aurora control panel: the selection its − and + buttons and its sense toggle move
/// and the Place, Play, Undo and Redo buttons that turn it into adapter actions. It mirrors the panel's controls; it
/// is not the panel itself.
struct MicroscopicAuroraPanelModel {
    /// The selected slot (0 … 2, wrapping).
    private(set) var slot: Int = 0
    /// The index of the selected site in the level's sites (wrapping).
    private(set) var siteIndex: Int = 0
    /// The selected strength (1 … 4, clamped).
    private(set) var strength: Int = 2
    /// Whether the selected sense is counterclockwise.
    private(set) var counterclockwise: Bool = true
    /// The level's sites.
    let sites: [MicroscopicAuroraCell]

    /// The panel showing `core`, with the presenter mirror's opening selection.
    init(_ core: MicroscopicAuroraExperienceCore) {
        sites = core.play.level.sites ?? []
    }

    /// The selected site, or nil without sites.
    var site: MicroscopicAuroraCell? {
        sites.isEmpty ? nil : sites[siteIndex]
    }

    /// An adapter action of `control` with `values`.
    static func action(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// "Well +": the next slot, 2 wrapping to 0; no action is sent.
    mutating func slotPlus() { slot = (slot + 1) % MicroscopicAuroraLevel.slots }

    /// "Well −": the previous slot, 0 wrapping to 2; no action is sent.
    mutating func slotMinus() {
        let count: Int = MicroscopicAuroraLevel.slots
        slot = (slot + count - 1) % count
    }

    /// "Site +": the next site, the last wrapping to the first; no action is sent.
    mutating func sitePlus() {
        let count: Int = max(1, sites.count)
        siteIndex = (siteIndex + 1) % count
    }

    /// "Site −": the previous site, the first wrapping to the last; no action is sent.
    mutating func siteMinus() {
        let count: Int = max(1, sites.count)
        siteIndex = (siteIndex + count - 1) % count
    }

    /// "Strength +": one up, clamped at 4; no action is sent.
    mutating func strengthPlus() { strength = min(strength + 1, MicroscopicAuroraWell.strengths.upperBound) }

    /// "Strength −": one down, clamped at 1; no action is sent.
    mutating func strengthMinus() { strength = max(strength - 1, MicroscopicAuroraWell.strengths.lowerBound) }

    /// The sense toggle; no action is sent.
    mutating func toggleSense() { counterclockwise.toggle() }

    /// "Place": one `well.place [slot, row, column, strength, sense]` (sense 0 clockwise, 1 counterclockwise); nil
    /// when the level has no sites (the panel then sends nothing and says so).
    func place() -> ExperienceAction? {
        guard let cell = site else { return nil }
        let sense: Double = counterclockwise ? 1 : 0
        return Self.action("well.place", [Double(slot), Double(cell.row), Double(cell.column), Double(strength), sense])
    }

    /// "Play": `swim.play`.
    func play() -> ExperienceAction { Self.action("swim.play") }

    /// "Undo": `play.undo`.
    func undo() -> ExperienceAction { Self.action("play.undo") }

    /// "Redo": `play.redo`.
    func redo() -> ExperienceAction { Self.action("play.redo") }
}

@Suite struct MicroscopicAuroraPanelWinTests {
    typealias Core = MicroscopicAuroraExperienceCore
    typealias Panel = MicroscopicAuroraPanelModel

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// Moves the panel's selection to `slot` and `well` with − and + (the shorter way for the slot and the site) and
    /// the sense toggle; no press changes the digest.
    static func select(slot: Int, well: MicroscopicAuroraWell, core: Core, panel: inout Panel) throws {
        let before: StateDigest = try digest(core)
        let slots: Int = MicroscopicAuroraLevel.slots
        let slotForward: Int = (slot - panel.slot + slots) % slots
        if slotForward <= slots - slotForward {
            for _ in 0..<slotForward { panel.slotPlus() }
        } else {
            for _ in 0..<(slots - slotForward) { panel.slotMinus() }
        }
        let target: Int = try #require(panel.sites.firstIndex(of: well.cell), "the well is not on a site")
        let count: Int = panel.sites.count
        let siteForward: Int = (target - panel.siteIndex + count) % count
        if siteForward <= count - siteForward {
            for _ in 0..<siteForward { panel.sitePlus() }
        } else {
            for _ in 0..<(count - siteForward) { panel.siteMinus() }
        }
        while panel.strength < well.strength { panel.strengthPlus() }
        while panel.strength > well.strength { panel.strengthMinus() }
        if panel.counterclockwise != (well.sense == .counterclockwise) { panel.toggleSense() }
        #expect(panel.slot == slot)
        #expect(panel.site == well.cell)
        #expect(panel.strength == well.strength)
        #expect(panel.counterclockwise == (well.sense == .counterclockwise))
        #expect(try digest(core) == before, "a selection press changed the digest")
    }

    /// The witness's placements (its actions without the closing play) as slot and well.
    static func placements(_ witness: MicroscopicAuroraWitness) -> [(slot: Int, well: MicroscopicAuroraWell)] {
        var result: [(slot: Int, well: MicroscopicAuroraWell)] = []
        for action in witness.actions {
            if case let .place(slot, well) = action { result.append((slot, well)) }
        }
        return result
    }

    /// Prepares level `number` from seed `number − 1`, checks it is the stored witness's level and places every witness
    /// placement through the panel, checking the witness digest and fingerprint after each; returns the core, the
    /// panel, the witness and the adapter digests (the opening, then after each placement).
    static func placedThroughPanel(_ number: Int) async throws
        -> (core: Core, panel: Panel, witness: MicroscopicAuroraWitness, digests: [StateDigest]) {
        let witness: MicroscopicAuroraWitness = try panelWitness(number)
        var core: Core = try await Core.prepare(seed: UInt64(number - 1))
        #expect(core.levelNumber == number)
        #expect(core.play.level.fingerprint == witness.level.fingerprint, "level \(number) differs from its witness")
        var panel = Panel(core)
        let steps: [(slot: Int, well: MicroscopicAuroraWell)] = placements(witness)
        #expect(steps.count + 1 == witness.actions.count, "level \(number): the witness is not placements then play")
        let offset: Int = witness.fingerprints.count - witness.actions.count
        var digests: [StateDigest] = [try digest(core)]
        for (index, step) in steps.enumerated() {
            try select(slot: step.slot, well: step.well, core: core, panel: &panel)
            let place: ExperienceAction = try #require(panel.place(), "Place disabled on level \(number)")
            #expect(place.control == "well.place")
            #expect(place.values.count == 5)
            #expect(core.apply(place) == .accepted, "level \(number) placement \(index) refused")
            #expect(MicroscopicAuroraWitness.digest(wells: core.play.wells, spent: core.play.actionsSpent)
                    == witness.digests[index], "level \(number) placement \(index): witness digest")
            #expect(core.play.fingerprint == witness.fingerprints[offset + index],
                    "level \(number) placement \(index): witness fingerprint")
            digests.append(try digest(core))
        }
        return (core, panel, witness, digests)
    }

    /// Wins level `number` through panel actions only, within its budget.
    static func winThroughPanel(_ number: Int) async throws {
        var placed: (core: Core, panel: Panel, witness: MicroscopicAuroraWitness, digests: [StateDigest]) =
            try await placedThroughPanel(number)
        let placementCount: Int = placed.witness.actions.count - 1
        #expect(placed.core.apply(placed.panel.play()) == .accepted)
        #expect(placed.core.play.stage == .won, "level \(number) not won through the panel")
        #expect(placed.core.outcome?.code == Core.wonCode)
        #expect(placed.core.play.fingerprint == placed.witness.fingerprints.last)
        #expect(placed.core.play.actionsSpent == placementCount)
        #expect(placed.core.play.actionsSpent <= placed.core.play.level.budget, "level \(number) over budget")
    }

    /// Levels 5 g + 1 … 5 g + 5 of group `group` (0 … 19).
    @Test(arguments: Array(0..<20))
    func panelWinsGroup(_ group: Int) async throws {
        for number in (group * 5 + 1)...(group * 5 + 5) {
            try await Self.winThroughPanel(number)
        }
    }

    /// Panel Undo walks back every placement to the earlier digests exactly, and Redo forward to the later ones;
    /// nothing is left to undo at the opening or to redo at the end; the redone placements still win on Play.
    @Test(arguments: [1, 50, 100])
    func panelUndoRedoRestoresDigests(_ number: Int) async throws {
        var placed: (core: Core, panel: Panel, witness: MicroscopicAuroraWitness, digests: [StateDigest]) =
            try await Self.placedThroughPanel(number)
        let count: Int = placed.digests.count - 1
        #expect(count > 0)
        for index in stride(from: count - 1, through: 0, by: -1) {
            #expect(placed.core.apply(placed.panel.undo()) == .accepted)
            #expect(try Self.digest(placed.core) == placed.digests[index], "undo \(index) of level \(number)")
        }
        #expect(placed.core.apply(placed.panel.undo()) != .accepted)
        #expect(try Self.digest(placed.core) == placed.digests[0])
        for index in 1...count {
            #expect(placed.core.apply(placed.panel.redo()) == .accepted)
            #expect(try Self.digest(placed.core) == placed.digests[index], "redo \(index) of level \(number)")
        }
        #expect(placed.core.apply(placed.panel.redo()) != .accepted)
        #expect(placed.core.apply(placed.panel.play()) == .accepted)
        #expect(placed.core.outcome?.code == Core.wonCode)
    }
}
