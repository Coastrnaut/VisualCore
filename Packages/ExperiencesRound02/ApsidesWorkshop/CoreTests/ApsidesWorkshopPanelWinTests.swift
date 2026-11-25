// ApsidesWorkshopPanelWinTests — feature 474 (R02-G18-04) T-R02G1804-004 (FR-R02G1804-008; SC-R02G1804-005;
// clarification Q5). Every move without gestures: all 100 certified levels are won through panel actions only. The
// panel of feature 474 is modelled by a small pure helper (`ApsidesWorkshopPanelModel`) that mirrors its controls:
// eccentricity, direction and size − and + move a pending orbit (presentation only, no kernel action, no action
// spent; the direction wraps 0 … 23, the eccentricity clamps to 0 … 15 and the size to 8 … 48); "Set periapsis" sends
// exactly one `orbit.periapsis [k, d]` with the pending eccentricity and direction when they differ from the current
// orbit and the resulting orbit (current size) is valid; "Set size" sends exactly one `orbit.size [a]` with the pending
// size when it differs and the resulting orbit (current knob) is valid; "Play" sends `orbit.play`; Undo and Redo send
// `play.undo` and `play.redo`; after every accepted action the pending orbit follows the current orbit. The real
// adapter `ApsidesWorkshopExperienceCore` is prepared from seed n − 1 for level n and driven through `apply`; the plan
// is the certified one (`ApsidesWorkshopExperienceCore.generated(number:).plan`): for each of its tunings, in its order
// (the size first when the winning eccentricity is not lower), the − and + buttons move the pending lever(s) to the
// tuning's values (the direction the shorter way) and the matching Set button commits them; then "Play". Each level
// ends won with no more actions spent than its budget (exactly the plan's tunings), no − or + press changes the digest
// and no Set ever sends an invalid orbit. The 100 levels run in 4 parameterized groups of 25 (levels are certified
// once per process, about 0.3 s for the whole catalog). Panel Undo then Redo restore the digests of every tuning
// exactly. Explicit types, plain loops, single-literal comments. Modelled on CelestialEclipseLabPanelWinTests
// (feature 464).
@testable import ApsidesWorkshopCore
import Foundation
import Testing
import VisualCoreExperience

/// A pure model of the feature-474 control panel: the pending orbit its − and + buttons move and the Set and Play
/// buttons that turn it into adapter actions. It mirrors the panel's controls; it is not the panel itself.
struct ApsidesWorkshopPanelModel {
    /// The pending eccentricity step (0 … 15, clamped).
    private(set) var eccentricity: Int
    /// The pending periapsis direction step (0 … 23, wrapping).
    private(set) var direction: Int
    /// The pending size (8 … 48, clamped).
    private(set) var size: Int

    /// The panel showing `core`, its pending orbit at the current orbit.
    init(_ core: ApsidesWorkshopExperienceCore) {
        let orbit: ApsidesWorkshopOrbit = core.play.orbit
        eccentricity = orbit.eccentricity
        direction = orbit.direction
        size = orbit.size
    }

    /// The pending orbit (not checked for validity).
    var pending: ApsidesWorkshopOrbit {
        ApsidesWorkshopOrbit(size: size, eccentricity: eccentricity, direction: direction)
    }

    /// An adapter action of `control` with `values`.
    static func action(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// "Eccentricity +": one step up, clamped at 15; no action is sent.
    mutating func eccentricityPlus() {
        eccentricity = min(eccentricity + 1, ApsidesWorkshopOrbit.eccentricities.upperBound)
    }

    /// "Eccentricity −": one step down, clamped at 0; no action is sent.
    mutating func eccentricityMinus() {
        eccentricity = max(eccentricity - 1, ApsidesWorkshopOrbit.eccentricities.lowerBound)
    }

    /// "Direction +": one step counterclockwise, 23 wrapping to 0; no action is sent.
    mutating func directionPlus() {
        let count: Int = ApsidesWorkshopOrbit.directions.count
        direction = (direction + 1) % count
    }

    /// "Direction −": one step clockwise, 0 wrapping to 23; no action is sent.
    mutating func directionMinus() {
        let count: Int = ApsidesWorkshopOrbit.directions.count
        direction = (direction + count - 1) % count
    }

    /// "Size +": one lattice unit up, clamped at 48; no action is sent.
    mutating func sizePlus() {
        size = min(size + 1, ApsidesWorkshopOrbit.sizes.upperBound)
    }

    /// "Size −": one lattice unit down, clamped at 8; no action is sent.
    mutating func sizeMinus() {
        size = max(size - 1, ApsidesWorkshopOrbit.sizes.lowerBound)
    }

    /// The orbit "Set periapsis" would make from `current`: the pending knob with the current size.
    func periapsisResult(current: ApsidesWorkshopOrbit) -> ApsidesWorkshopOrbit {
        ApsidesWorkshopOrbit(size: current.size, eccentricity: eccentricity, direction: direction)
    }

    /// The orbit "Set size" would make from `current`: the pending size with the current knob.
    func sizeResult(current: ApsidesWorkshopOrbit) -> ApsidesWorkshopOrbit {
        ApsidesWorkshopOrbit(size: size, eccentricity: current.eccentricity, direction: current.direction)
    }

    /// "Set periapsis": one `orbit.periapsis [k, d]` when the pending knob differs from `current`'s and the resulting
    /// orbit is valid; nil (the button is disabled) otherwise.
    func setPeriapsis(current: ApsidesWorkshopOrbit) -> ExperienceAction? {
        guard eccentricity != current.eccentricity || direction != current.direction else { return nil }
        guard periapsisResult(current: current).isValid else { return nil }
        return Self.action("orbit.periapsis", [Double(eccentricity), Double(direction)])
    }

    /// "Set size": one `orbit.size [a]` when the pending size differs from `current`'s and the resulting orbit is
    /// valid; nil (the button is disabled) otherwise.
    func setSize(current: ApsidesWorkshopOrbit) -> ExperienceAction? {
        guard size != current.size else { return nil }
        guard sizeResult(current: current).isValid else { return nil }
        return Self.action("orbit.size", [Double(size)])
    }

    /// "Play": `orbit.play`.
    func play() -> ExperienceAction { Self.action("orbit.play") }

    /// "Undo": `play.undo`.
    func undo() -> ExperienceAction { Self.action("play.undo") }

    /// "Redo": `play.redo`.
    func redo() -> ExperienceAction { Self.action("play.redo") }

    /// Follows `core` after an accepted action: the pending orbit becomes the current orbit.
    mutating func sync(_ core: ApsidesWorkshopExperienceCore) {
        let orbit: ApsidesWorkshopOrbit = core.play.orbit
        eccentricity = orbit.eccentricity
        direction = orbit.direction
        size = orbit.size
    }
}

@Suite struct ApsidesWorkshopPanelWinTests {
    typealias Core = ApsidesWorkshopExperienceCore
    typealias Panel = ApsidesWorkshopPanelModel

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// Presses eccentricity + or − until the pending eccentricity is `target`; no press changes the digest.
    static func moveEccentricity(to target: Int, core: Core, panel: inout Panel) throws {
        let before: StateDigest = try digest(core)
        while panel.eccentricity < target { panel.eccentricityPlus() }
        while panel.eccentricity > target { panel.eccentricityMinus() }
        #expect(panel.eccentricity == target)
        #expect(try digest(core) == before, "an eccentricity press changed the digest")
    }

    /// Presses direction + or − the shorter way until the pending direction is `target`; no press changes the digest.
    static func moveDirection(to target: Int, core: Core, panel: inout Panel) throws {
        let before: StateDigest = try digest(core)
        let count: Int = ApsidesWorkshopOrbit.directions.count
        let forward: Int = (target - panel.direction + count) % count
        let plus: Bool = forward <= count - forward
        let presses: Int = plus ? forward : count - forward
        for _ in 0..<presses {
            if plus { panel.directionPlus() } else { panel.directionMinus() }
        }
        #expect(panel.direction == target)
        #expect(try digest(core) == before, "a direction press changed the digest")
    }

    /// Presses size + or − until the pending size is `target`; no press changes the digest.
    static func moveSize(to target: Int, core: Core, panel: inout Panel) throws {
        let before: StateDigest = try digest(core)
        while panel.size < target { panel.sizePlus() }
        while panel.size > target { panel.sizeMinus() }
        #expect(panel.size == target)
        #expect(try digest(core) == before, "a size press changed the digest")
    }

    /// Applies one plan tuning through the panel: the − and + buttons move the pending lever(s), then the matching
    /// Set button sends one action, whose resulting orbit must be valid; the pending orbit then follows the core.
    static func commit(_ tuning: ApsidesWorkshopAction, core: inout Core, panel: inout Panel) throws {
        let current: ApsidesWorkshopOrbit = core.play.orbit
        let set: ExperienceAction
        let expected: ApsidesWorkshopOrbit
        switch tuning {
        case let .periapsis(k, d):
            try moveEccentricity(to: k, core: core, panel: &panel)
            try moveDirection(to: d, core: core, panel: &panel)
            expected = panel.periapsisResult(current: current)
            #expect(expected.isValid, "Set periapsis would send an invalid orbit")
            set = try #require(panel.setPeriapsis(current: current), "Set periapsis disabled for a plan tuning")
            #expect(set.control == "orbit.periapsis")
            #expect(set.values == [Double(k), Double(d)])
        case let .size(a):
            try moveSize(to: a, core: core, panel: &panel)
            expected = panel.sizeResult(current: current)
            #expect(expected.isValid, "Set size would send an invalid orbit")
            set = try #require(panel.setSize(current: current), "Set size disabled for a plan tuning")
            #expect(set.control == "orbit.size")
            #expect(set.values == [Double(a)])
        case .play:
            Issue.record("a plan tuning is never the play")
            return
        }
        #expect(core.apply(set) == .accepted)
        panel.sync(core)
        #expect(core.play.orbit == expected)
        #expect(panel.pending == core.play.orbit)
        #expect(panel.setPeriapsis(current: core.play.orbit) == nil)
        #expect(panel.setSize(current: core.play.orbit) == nil)
    }

    /// Prepares level `number` from seed `number − 1`, checks it is the certified level and replays the certified
    /// plan's tunings through the panel; returns the core, the panel and the plan before the play.
    static func playedThroughPanel(_ number: Int) async throws
        -> (core: Core, panel: Panel, plan: ApsidesWorkshopPlan) {
        let generated: ApsidesWorkshopGenerated = try Core.generated(number: number)
        var core: Core = try await Core.prepare(seed: UInt64(number - 1))
        #expect(core.levelNumber == number)
        #expect(core.play.level.fingerprint == generated.level.fingerprint, "level \(number) differs from its plan")
        var panel = Panel(core)
        for tuning in generated.plan.actions {
            try commit(tuning, core: &core, panel: &panel)
        }
        #expect(core.play.orbit == generated.plan.orbit, "level \(number) did not reach the winning orbit")
        return (core, panel, generated.plan)
    }

    /// Wins level `number` through panel actions only, within its budget.
    static func winThroughPanel(_ number: Int) async throws {
        var played: (core: Core, panel: Panel, plan: ApsidesWorkshopPlan) = try await playedThroughPanel(number)
        #expect(played.core.apply(played.panel.play()) == .accepted)
        #expect(played.core.outcome?.code == Core.wonCode, "level \(number) not won through the panel")
        #expect(played.core.play.actionsSpent == played.plan.size)
        #expect(played.core.play.actionsSpent <= played.core.play.level.budget, "level \(number) over budget")
    }

    /// Levels 25 g + 1 … 25 g + 25 of group `group` (0 … 3).
    @Test(arguments: Array(0..<4))
    func panelWinsGroup(_ group: Int) async throws {
        for number in (group * 25 + 1)...(group * 25 + 25) {
            try await Self.winThroughPanel(number)
        }
    }

    /// Panel Undo walks back every tuning to the earlier digests exactly, and Redo forward to the later ones; the
    /// pending orbit follows the restored orbit; the redone play still wins.
    @Test(arguments: [1, 48, 100])
    func panelUndoRedoRestoresDigests(_ number: Int) async throws {
        let generated: ApsidesWorkshopGenerated = try Core.generated(number: number)
        var core: Core = try await Core.prepare(seed: UInt64(number - 1))
        var panel = Panel(core)
        var digests: [StateDigest] = [try Self.digest(core)]
        for tuning in generated.plan.actions {
            try Self.commit(tuning, core: &core, panel: &panel)
            digests.append(try Self.digest(core))
        }
        let count: Int = generated.plan.actions.count
        #expect(count > 0)
        for index in stride(from: count - 1, through: 0, by: -1) {
            #expect(core.apply(panel.undo()) == .accepted)
            panel.sync(core)
            #expect(try Self.digest(core) == digests[index], "undo \(index) of level \(number)")
            #expect(panel.pending == core.play.orbit)
        }
        #expect(core.apply(panel.undo()) != .accepted)
        for index in 1...count {
            #expect(core.apply(panel.redo()) == .accepted)
            panel.sync(core)
            #expect(try Self.digest(core) == digests[index], "redo \(index) of level \(number)")
            #expect(panel.pending == core.play.orbit)
        }
        #expect(core.apply(panel.redo()) != .accepted)
        #expect(core.apply(panel.play()) == .accepted)
        #expect(core.outcome?.code == Core.wonCode)
    }

    /// The direction wraps both ways, eccentricity and size clamp at their bounds, and neither Set button sends
    /// anything while the pending orbit equals the current one.
    @Test func pendingOrbitWrapsClampsAndSetNeedsAChange() async throws {
        let core: Core = try await Core.prepare(seed: 0)
        var panel = Panel(core)
        let current: ApsidesWorkshopOrbit = core.play.orbit
        #expect(panel.pending == current)
        #expect(panel.setPeriapsis(current: current) == nil)
        #expect(panel.setSize(current: current) == nil)
        let directions: Int = ApsidesWorkshopOrbit.directions.count
        for _ in 0..<directions { panel.directionPlus() }
        #expect(panel.direction == current.direction)
        for _ in 0..<directions { panel.directionMinus() }
        #expect(panel.direction == current.direction)
        for _ in 0..<40 { panel.eccentricityPlus() }
        #expect(panel.eccentricity == ApsidesWorkshopOrbit.eccentricities.upperBound)
        for _ in 0..<40 { panel.eccentricityMinus() }
        #expect(panel.eccentricity == ApsidesWorkshopOrbit.eccentricities.lowerBound)
        for _ in 0..<80 { panel.sizePlus() }
        #expect(panel.size == ApsidesWorkshopOrbit.sizes.upperBound)
        for _ in 0..<80 { panel.sizeMinus() }
        #expect(panel.size == ApsidesWorkshopOrbit.sizes.lowerBound)
        #expect(try Self.digest(core) == (try Self.digest(try await Core.prepare(seed: 0))))
    }

    /// A Set button whose resulting orbit would be invalid sends nothing: the largest eccentricity on a size-8 orbit
    /// leaves the periapsis too near the star (8 × 5 < 60), and size 48 on an orbit of eccentricity 15 puts the
    /// apoapsis outside the sky (48 × 35 > 1280).
    @Test func setSendsNothingForAnInvalidOrbit() async throws {
        let core: Core = try await Core.prepare(seed: 0)
        let small = ApsidesWorkshopOrbit(size: 8, eccentricity: 0, direction: 0)
        #expect(small.isValid)
        var tight = Panel(core)
        for _ in 0..<40 { tight.eccentricityPlus() }
        #expect(!tight.periapsisResult(current: small).isValid)
        #expect(tight.setPeriapsis(current: small) == nil)
        let eccentric = ApsidesWorkshopOrbit(size: 20, eccentricity: 15, direction: 0)
        #expect(eccentric.isValid)
        var wide = Panel(core)
        for _ in 0..<80 { wide.sizePlus() }
        #expect(!wide.sizeResult(current: eccentric).isValid)
        #expect(wide.setSize(current: eccentric) == nil)
    }
}
