// MushroomWeatherPanelWinTests — feature 494 (R02-G20-04) T-R02G2004-004 (FR-R02G2004-010; SC-R02G2004-005). Every
// action without gestures: all 100 certified levels are won through panel actions only. The panel of features 493 and
// 494 is modelled by a small pure helper (`MushroomWeatherPanelModel`) that mirrors its controls: Slot − and + pick the
// pod slot (wrapping 0 … slots − 1), Site − and + pick a site of the level (wrapping over its sites), "Place" sends
// exactly one `pod.place [slot, row, column]`; each vent's toggle sends exactly one `vent.set [index, open]` with the
// opposite of the vent's current state; Moonlight − and + pick the moonlight level (clamped 0 … 3, presentation only:
// no kernel action, no action spent, the digest unchanged) and "Set moonlight" sends exactly one `moon.set [level]`;
// "Run" sends `weather.run`; Undo and Redo send `play.undo` and `play.redo`. The panel opens on slot 0, the first site
// and the play's current moonlight. The real adapter `MushroomWeatherExperienceCore` is prepared from seed n − 1 for
// level n and driven through `apply`; the plan is the stored witness of docs/games/mushroom-weather/levels/NNN.witness
// .json (its placements in slot order, then its vent toggles, then its moonlight change, then the run): for each
// placement the − and + buttons move the selection the shorter way to the placement's slot and site and Place sends
// it, each vent setting is one toggle, the moonlight change is − or + to the level and one Set; then Run. After every
// action the witness's state digest and play fingerprint are reproduced; each level ends won with no more actions
// spent than its budget (exactly the witness's arrangement actions). The 100 levels run in 20 parameterized groups of
// 5 (each level is certified once per process, which dominates the time). Panel Undo then Redo restore the adapter
// digests of every arrangement action exactly. Explicit types, plain loops. Modelled on MicroscopicAuroraPanelWinTests
// (feature 484).
import Foundation
@testable import MushroomWeatherCore
import Testing
import VisualCoreExperience
import VisualCoreSimulation

/// The repository's witness directory, found from this file (five levels up: CoreTests, MushroomWeather, the package,
/// Packages).
private let panelWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/mushroom-weather/levels", isDirectory: true)

/// The stored witness of level `number`, read with the plain decoder.
private func panelWitness(_ number: Int) throws -> MushroomWeatherWitness {
    let name: String = String(MushroomWeatherGenerator.levelID(number).suffix(3)) + ".witness.json"
    let data: Data = try Data(contentsOf: panelWitnessDirectory.appendingPathComponent(name))
    return try JSONDecoder().decode(MushroomWeatherWitness.self, from: data)
}

/// A pure model of the Mushroom Weather control panel: the selection its − and + buttons move and the Place, vent
/// toggle, Set moonlight, Run, Undo and Redo buttons that turn it into adapter actions. It mirrors the panel's
/// controls; it is not the panel itself.
struct MushroomWeatherPanelModel {
    /// The selected slot (0 … slots − 1, wrapping).
    private(set) var slot: Int = 0
    /// The index of the selected site in the level's sites (wrapping).
    private(set) var siteIndex: Int = 0
    /// The selected moonlight level (clamped to the level's moonlight levels).
    private(set) var moonlight: Int
    /// The level's pod slots.
    let slots: Int
    /// The level's sites.
    let sites: [MushroomWeatherCell]

    /// The panel showing `core`: slot 0, the first site and the play's current moonlight.
    init(_ core: MushroomWeatherExperienceCore) {
        slots = core.play.level.podRules.slots
        sites = core.play.level.sites ?? []
        moonlight = core.play.arrangement.moonlight
    }

    /// The selected site, or nil without sites.
    var site: MushroomWeatherCell? {
        sites.isEmpty ? nil : sites[siteIndex]
    }

    /// An adapter action of `control` with `values`.
    static func action(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// "Slot +": the next slot, the last wrapping to 0; no action is sent.
    mutating func slotPlus() { slot = (slot + 1) % max(1, slots) }

    /// "Slot −": the previous slot, 0 wrapping to the last; no action is sent.
    mutating func slotMinus() {
        let count: Int = max(1, slots)
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

    /// "Moonlight +": one level up, clamped at the brightest; no action is sent.
    mutating func moonPlus() { moonlight = min(moonlight + 1, MushroomWeatherLevel.moonlightLevels.upperBound) }

    /// "Moonlight −": one level down, clamped at the darkest; no action is sent.
    mutating func moonMinus() { moonlight = max(moonlight - 1, MushroomWeatherLevel.moonlightLevels.lowerBound) }

    /// "Place": one `pod.place [slot, row, column]`; nil when the level has no sites (the panel then sends nothing and
    /// says so).
    func place() -> ExperienceAction? {
        guard let cell = site else { return nil }
        return Self.action("pod.place", [Double(slot), Double(cell.row), Double(cell.column)])
    }

    /// The toggle of vent `index` in `core`: one `vent.set [index, open]` with the opposite of its current state.
    func toggleVent(_ index: Int, in core: MushroomWeatherExperienceCore) -> ExperienceAction {
        let open: Bool = !core.play.arrangement.ventsOpen[index]
        return Self.action("vent.set", [Double(index), open ? 1 : 0])
    }

    /// "Set moonlight": one `moon.set [level]` with the selected level.
    func setMoonlight() -> ExperienceAction { Self.action("moon.set", [Double(moonlight)]) }

    /// "Run": `weather.run`.
    func run() -> ExperienceAction { Self.action("weather.run") }

    /// "Undo": `play.undo`.
    func undo() -> ExperienceAction { Self.action("play.undo") }

    /// "Redo": `play.redo`.
    func redo() -> ExperienceAction { Self.action("play.redo") }
}

@Suite struct MushroomWeatherPanelWinTests {
    typealias Core = MushroomWeatherExperienceCore
    typealias Panel = MushroomWeatherPanelModel

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// Moves the panel's selection to `slot` and `cell` with − and + (the shorter way for each); no press changes the
    /// digest.
    static func select(slot: Int, cell: MushroomWeatherCell, core: Core, panel: inout Panel) throws {
        let before: StateDigest = try digest(core)
        let slots: Int = panel.slots
        let slotForward: Int = (slot - panel.slot + slots) % slots
        if slotForward <= slots - slotForward {
            for _ in 0..<slotForward { panel.slotPlus() }
        } else {
            for _ in 0..<(slots - slotForward) { panel.slotMinus() }
        }
        let target: Int = try #require(panel.sites.firstIndex(of: cell), "the pod is not on a site")
        let count: Int = panel.sites.count
        let siteForward: Int = (target - panel.siteIndex + count) % count
        if siteForward <= count - siteForward {
            for _ in 0..<siteForward { panel.sitePlus() }
        } else {
            for _ in 0..<(count - siteForward) { panel.siteMinus() }
        }
        #expect(panel.slot == slot)
        #expect(panel.site == cell)
        #expect(try digest(core) == before, "a selection press changed the digest")
    }

    /// The one panel action of witness action `action` (after moving the selection where needed), or nil for the run.
    static func panelAction(for action: MushroomWeatherAction, core: Core, panel: inout Panel, number: Int) throws
        -> ExperienceAction? {
        switch action {
        case let .place(slot, cell):
            try select(slot: slot, cell: cell, core: core, panel: &panel)
            let place: ExperienceAction = try #require(panel.place(), "Place disabled on level \(number)")
            #expect(place.control == "pod.place")
            #expect(place.values.count == 3)
            return place
        case let .vent(index, open):
            let toggle: ExperienceAction = panel.toggleVent(index, in: core)
            #expect(toggle.control == "vent.set")
            #expect(toggle.values == [Double(index), open ? 1 : 0], "level \(number): the toggle is not the witness")
            return toggle
        case let .moonlight(level):
            let before: StateDigest = try digest(core)
            while panel.moonlight < level { panel.moonPlus() }
            while panel.moonlight > level { panel.moonMinus() }
            #expect(panel.moonlight == level)
            #expect(try digest(core) == before, "a moonlight press changed the digest")
            let set: ExperienceAction = panel.setMoonlight()
            #expect(set.control == "moon.set")
            return set
        case .remove:
            Issue.record("level \(number): a witness never removes a pod")
            return nil
        case .run:
            return nil
        }
    }

    /// Prepares level `number` from seed `number − 1`, checks it is the stored witness's level and applies every
    /// witness arrangement action through the panel (one panel action each), checking the witness digest and
    /// fingerprint after each; returns the core, the panel, the witness and the adapter digests (the opening, then
    /// after each arrangement action).
    static func arrangedThroughPanel(_ number: Int) async throws
        -> (core: Core, panel: Panel, witness: MushroomWeatherWitness, digests: [StateDigest]) {
        let witness: MushroomWeatherWitness = try panelWitness(number)
        var core: Core = try await Core.prepare(seed: UInt64(number - 1))
        #expect(core.levelNumber == number)
        #expect(core.play.level.fingerprint == witness.level.fingerprint, "level \(number) differs from its witness")
        var panel = Panel(core)
        #expect(witness.actions.last == .run, "level \(number): the witness does not end with the run")
        let offset: Int = witness.fingerprints.count - witness.actions.count
        var digests: [StateDigest] = [try digest(core)]
        for index in 0..<(witness.actions.count - 1) {
            let witnessAction: MushroomWeatherAction = witness.actions[index]
            let sent: ExperienceAction? = try panelAction(for: witnessAction, core: core, panel: &panel,
                                                          number: number)
            let action: ExperienceAction = try #require(sent, "level \(number) action \(index): no panel action")
            #expect(core.apply(action) == .accepted, "level \(number) action \(index) refused")
            #expect(core.play.actionsSpent == index + 1, "level \(number) action \(index): more than one action")
            #expect(MushroomWeatherWitness.digest(arrangement: core.play.arrangement, spent: core.play.actionsSpent)
                    == witness.digests[index], "level \(number) action \(index): witness digest")
            #expect(core.play.fingerprint == witness.fingerprints[offset + index],
                    "level \(number) action \(index): witness fingerprint")
            digests.append(try digest(core))
        }
        return (core, panel, witness, digests)
    }

    /// Wins level `number` through panel actions only, within its budget.
    static func winThroughPanel(_ number: Int) async throws {
        var arranged: (core: Core, panel: Panel, witness: MushroomWeatherWitness, digests: [StateDigest]) =
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
        var arranged: (core: Core, panel: Panel, witness: MushroomWeatherWitness, digests: [StateDigest]) =
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
