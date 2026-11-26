// MicroscopicAuroraGestureWiringTests — feature 484 (R02-G19-04) T-R02G1904-005 (FR-R02G1904-001 … 010;
// SC-R02G1904-001 … 004). On the simulator, through the one app's session host: scripted touches go to the
// presenter's `pointer(_:viewSize:port:)` with the shell's own `port` at a 720 × 480-point view (aspect 1.5). Modelled
// on ApsidesWorkshopGestureWiringTests (feature 474). Targets are projected through the drawn camera of the
// presenter's orbit (`MicroscopicAuroraSceneGeometry.camera(aspect:orbit:)`, then `MicroscopicAuroraPicker.viewPoint`
// of `siteCentre`, `wellCentre`, `scrubberPoint` and `dishCentre`) on the presenter's `lastSnapshot`, and each is
// confirmed with the picker (`pick`, `dropTarget`, `scrubTick`) at the same view size before any touch. Levels are
// chosen at run time from bare opening cores (seed n − 1 opens level n); the kernel's verdict is the one a bare core
// gives for the same actions.
// Checked:
//   a. a tap on an empty site sends exactly one `well.place` in the first free slot with the panel's strength and
//      sense (FR-R02G1904-001);
//   b. a drag from a placed well to another site previews the move (drawn as the snapshot's preview, no digest
//      change) and on release sends exactly one `well.place` with the same strength and sense (FR-R02G1904-002, 004);
//   c. a drag from a placed well off the dish sends exactly one `well.remove` (FR-R02G1904-002);
//   d. a drag along the scrubber shows the tick under the finger (`clock.show`); no action spent, the digest unchanged
//      (FR-R02G1904-003);
//   e. a tap on the field toggles the freeze (drawn), and `toggleFreeze()` likewise; nothing sent (FR-R02G1904-005);
//   f. a two-finger orbit changes the orbit and never the digest; `resetView()` and a double tap on empty space return
//      to the authored orbit with no kernel action (FR-R02G1904-007);
//   g. a refused change (a site tap with no action left) is sent, refused, shown in the mirror message (since feature
//      486 exactly the feedback plan's sentence, "No actions are left: undo or retry.") and logged with its bare code
//      (FR-R02G1904-008);
//   h. a well drag on a won play sends nothing and says "The play is over: undo or go to the next level"
//      (FR-R02G1904-008);
//   i. a tap on a well selects its slot and explains the drag; a site tap with every slot used explains and sends
//      nothing (FR-R02G1904-001, 009);
//   the panel keeps every action (FR-R02G1904-009) and the gestures are proved here on the simulator (FR-R02G1904-010).
// Explicit synthetic timestamps (no clock, no sleep, no wall-clock assertion). Explicit types and plain loops (CI
// type-check rule); no nested closure literals. Synthetic data only. Each test well under 10 s.
//
// ASSUMED PRESENTER API (draft by agent E before the lead's presenter change; adjust here if it differs):
//   - `MicroscopicAuroraPresenter.pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort)`
//     (as Apsides Workshop's; `viewSize` is a `Vec2` here — if the lead's takes `CGSize`, change only
//     `MicroscopicAuroraGestureScript.touch`);
//   - `MicroscopicAuroraPresenter.orbit: MicroscopicAuroraViewOrbit` (the gesture controller's orbit, read-only);
//   - `MicroscopicAuroraPresenter.resetView()` and `MicroscopicAuroraPresenter.toggleFreeze()`;
//   - `MicroscopicAuroraPresenter.refusalLog: [String]` (refused codes without the engine's `action.rule.` prefix,
//     oldest first);
//   - `MicroscopicAuroraPresenter.lastSnapshot` carries the drawn preview (`preview`) and freeze (`frozen`) after a
//     frame is drawn;
//   - the gesture controller takes its strength and sense from the panel: `mirror.strength` and
//     `mirror.counterclockwise`; a tapped well sets `mirror.slot`;
//   - `MicroscopicAuroraMirror.message` holds the explain texts verbatim and a refusal as exactly
//     `MicroscopicAuroraFeedbackPlan.refusalText(code:)` (since feature 486;
//     `MicroscopicAuroraMirror.refusalText(code:)` forwards to it); `refusalText(code:)` reads codes with or without
//     `action.rule.`;
//   - the explain texts: a well tap "Drag a well to move it, or off the dish to remove it"; all slots used "Every well
//     slot is used: drag a well or remove one"; a finished play "The play is over: undo or go to the next level".
// Core API used from the contract (contracts/api.md): `MicroscopicAuroraViewOrbit` (`authored`, `clamped()`),
// `MicroscopicAuroraSceneGeometry.camera(aspect:orbit:)`, `scrubberPoint(_:)`, `wellCentre(_:_:)`,
// `MicroscopicAuroraPick`, `MicroscopicAuroraPicker.viewPoint/pick/dropTarget/scrubTick`,
// `MicroscopicAuroraPreviewTarget`, `MicroscopicAuroraSceneSnapshot.preview/frozen`.
#if os(iOS)
import CoreGraphics
import Foundation
import MicroscopicAuroraCore
import Testing
@testable import MicroscopicAuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// Scripted touches on Microscopic Aurora, placed through the drawn camera.
@MainActor
enum MicroscopicAuroraGestureScript {
    typealias Shell = MicroscopicAuroraTest.Shell
    typealias Snapshot = MicroscopicAuroraSceneSnapshot
    typealias Geometry = MicroscopicAuroraSceneGeometry
    typealias Core = MicroscopicAuroraExperienceCore
    typealias Picker = MicroscopicAuroraPicker
    typealias Pick = MicroscopicAuroraPick
    typealias ViewOrbit = MicroscopicAuroraViewOrbit
    typealias Action = MicroscopicAuroraAction
    typealias Well = MicroscopicAuroraWell
    typealias Cell = MicroscopicAuroraCell
    typealias T = MicroscopicAuroraTest

    /// The view's width in points (aspect 1.5).
    static let viewWidth: Double = 720
    /// The view's height in points.
    static let viewHeight: Double = 480
    /// The view size handed with every event.
    static var viewSize: Vec2 { Vec2(viewWidth, viewHeight) }
    /// The view size as the picker takes it.
    static var size: SIMD2<Double> { SIMD2<Double>(viewWidth, viewHeight) }
    /// The first synthetic timestamp, seconds (the controller only compares timestamps).
    static let start: Double = 100
    /// The time between scripted events in seconds (synthetic).
    static let frame: Double = 1.0 / 60
    /// The pause between the two taps of a double tap, seconds (inside the 0.35 s window).
    static let tapGap: Double = 0.1
    /// The pause between two separate gestures, seconds (outside every double-tap window).
    static let gesturePause: Double = 1
    /// The moves of a scripted straight drag.
    static let dragMoves: Int = 6
    /// The shortest well drag scripted, points (twice the drag distance 16).
    static let minimumDrag: Double = 32
    /// The length of a drag that only has to start a well drag, points (more than the drag distance 16).
    static let shortDrag: Double = 40
    /// How far inside the view a touch point must lie, points.
    static let inset: Double = 8
    /// The radii in points around a projected centre at which a touch point is tried.
    static let radii: [Double] = [0, 4, 8]
    /// The directions tried at each radius.
    static let directions: Int = 8
    /// The grid step of the field, empty-space and removal searches, points.
    static let gridStep: Double = 12
    /// The candidate levels; the first that fits is used.
    static let candidateLevels: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
    /// The levels searched for a full set of slots with a site left: levels 1 … 20 have at most three sites, so the
    /// first levels with four sites (21 … 30) are tried.
    static let fullCandidateLevels: [Int] = [21, 22, 23, 24, 25, 26, 27, 28, 29, 30]
    /// The kernel's budget refusal code.
    static let budgetCode: String = "r02-g19.budget"
    /// The engine's prefix of a rule refusal.
    static let rulePrefix: String = "action.rule."
    /// The explain text of a tap on a well.
    static let wellTapText: String = MicroscopicAuroraGestureController.wellReason
    /// The explain text of a site tap with every slot used.
    static let slotsFullText: String = MicroscopicAuroraGestureController.fullReason
    /// The explain text of a gesture on a finished play.
    static let finishedText: String = MicroscopicAuroraGestureController.finishedReason

    /// What the engine has counted so far: accepted and rejected actions.
    struct Sent: Equatable {
        /// The accepted actions.
        let accepted: Int
        /// The rejected actions.
        let rejected: Int
    }

    /// A level, the actions issued through the shell before the gesture and the slot the gesture is about.
    struct LevelTarget {
        /// The level number.
        let number: Int
        /// The actions issued before the gesture.
        let setUp: [Action]
        /// The slot the gesture concerns (the well dragged or tapped, or the slot a tap fills).
        let slot: Int
    }

    /// A well drag on a snapshot: the touch-down point (picks the well) and the release point.
    struct WellDrag {
        /// The touch-down point.
        let start: Vec2
        /// The release point.
        let end: Vec2
    }

    /// A scrub on a snapshot: the touch-down point on the scrubber, the release point and the tick read there.
    struct Scrub {
        /// The touch-down point (picks the scrubber).
        let start: Vec2
        /// The release point.
        let end: Vec2
        /// The tick under the release point.
        let to: Int
    }

    /// Opens level `number` (seed `number − 1`) at the scripted view size with tick 0 shown, issues `setUp` and
    /// draws a frame so `lastSnapshot` is current.
    static func open(_ session: ExperienceSession, number: Int, setUp: [Action] = []) async throws -> Shell {
        let shell: Shell = try await T.open(session, seed: UInt64(number - 1), setUp: setUp,
                                            size: CGSize(width: viewWidth, height: viewHeight), atHalf: false)
        try T.draw(session)
        return shell
    }

    /// The engine's action counters of `shell`.
    static func sent(_ shell: Shell) -> Sent {
        Sent(accepted: shell.engine.acceptedActions, rejected: shell.engine.rejectedActions)
    }

    /// The snapshot the presenter drew last.
    static func drawn(_ shell: Shell) throws -> Snapshot {
        try #require(shell.presenter.lastSnapshot)
    }

    /// Sends one pointer event to the presenter with the shell's port; the synthetic clock advances one frame.
    static func touch(_ shell: Shell, id: Int, _ phase: PointerPhase, at location: Vec2, time: inout Double) {
        let event: PointerEvent = PointerEvent(id: id, phase: phase, location: location, timestamp: time)
        shell.presenter.pointer(event, viewSize: viewSize, port: shell.port)
        time += frame
    }

    /// A tap (down and up at `location`, one frame apart) with finger `id`.
    static func tap(_ shell: Shell, id: Int, at location: Vec2, time: inout Double) {
        touch(shell, id: id, .began, at: location, time: &time)
        touch(shell, id: id, .ended, at: location, time: &time)
    }

    /// ``dragMoves`` equal moves of finger `id` from `start` to `end` (no touch-down, no lift).
    static func moves(_ shell: Shell, id: Int, from start: Vec2, to end: Vec2, time: inout Double) {
        let delta: Vec2 = end - start
        for step in 1...dragMoves {
            let t: Double = Double(step) / Double(dragMoves)
            touch(shell, id: id, .moved, at: start + delta * t, time: &time)
        }
    }

    /// A two-finger orbit with fingers `first` and `second` from `a` and `b`, both moving by `shift`, then lifting.
    static func orbit(_ shell: Shell, ids first: Int, _ second: Int, from a: Vec2, _ b: Vec2, by shift: Vec2,
                      time: inout Double) {
        touch(shell, id: first, .began, at: a, time: &time)
        touch(shell, id: second, .began, at: b, time: &time)
        touch(shell, id: first, .moved, at: a + shift, time: &time)
        touch(shell, id: second, .moved, at: b + shift, time: &time)
        touch(shell, id: first, .ended, at: a + shift, time: &time)
        touch(shell, id: second, .ended, at: b + shift, time: &time)
    }

    /// Whether `location` lies inside the view with a margin of ``inset`` points.
    static func inside(_ location: Vec2) -> Bool {
        location.x >= inset && location.x <= viewWidth - inset && location.y >= inset
            && location.y <= viewHeight - inset
    }

    /// `v` as the picker takes it.
    static func simd(_ v: Vec2) -> SIMD2<Double> { SIMD2<Double>(v.x, v.y) }

    /// What the picker gives for `location` on `snapshot` at `orbit`.
    static func pick(_ location: Vec2, _ snapshot: Snapshot, orbit: ViewOrbit) -> Pick {
        Picker.pick(simd(location), size: size, snapshot: snapshot, orbit: orbit)
    }

    /// The drop target the picker gives for slot `slot` released at `location`.
    static func drop(_ location: Vec2, slot: Int, _ snapshot: Snapshot,
                     orbit: ViewOrbit) -> MicroscopicAuroraPreviewTarget? {
        Picker.dropTarget(simd(location), slot: slot, size: size, snapshot: snapshot, orbit: orbit)
    }

    /// World `point` in view points through the drawn camera at `orbit`; nil when it does not project.
    static func project(_ point: SIMD3<Double>, orbit: ViewOrbit) -> Vec2? {
        let camera: MicroscopicAuroraCamera = Geometry.camera(aspect: viewWidth / viewHeight, orbit: orbit)
        guard let p: SIMD2<Double> = Picker.viewPoint(point, size: size, camera: camera) else { return nil }
        return Vec2(p.x, p.y)
    }

    /// A point inside the view near world `centre` (its projection, then rings about it) where the picker gives
    /// `wanted`; nil when none.
    static func point(near centre: SIMD3<Double>, _ snapshot: Snapshot, orbit: ViewOrbit, wanted: Pick) -> Vec2? {
        guard let c: Vec2 = project(centre, orbit: orbit) else { return nil }
        for radius in radii {
            let count: Int = radius == 0 ? 1 : directions
            for k in 0..<count {
                let a: Double = Double(k) * 2 * Double.pi / Double(directions)
                let p: Vec2 = c + Vec2(cos(a), sin(a)) * radius
                if inside(p), pick(p, snapshot, orbit: orbit) == wanted { return p }
            }
        }
        return nil
    }

    /// A point that picks site `index`; nil when none.
    static func sitePoint(_ index: Int, _ snapshot: Snapshot, orbit: ViewOrbit) -> Vec2? {
        point(near: Geometry.siteCentre(index, snapshot), snapshot, orbit: orbit, wanted: .site(index))
    }

    /// A point that picks the well of slot `slot`; nil when the slot is empty or none picks.
    static func wellPoint(_ slot: Int, _ snapshot: Snapshot, orbit: ViewOrbit) -> Vec2? {
        guard let centre: SIMD3<Double> = Geometry.wellCentre(slot, snapshot) else { return nil }
        return point(near: centre, snapshot, orbit: orbit, wanted: .well(slot))
    }

    /// The first grid point inside the view that picks `wanted` and lies at least `minimum` points from `away` (when
    /// given); nil when none.
    static func gridPoint(_ snapshot: Snapshot, orbit: ViewOrbit, wanted: Pick, away: Vec2? = nil,
                          minimum: Double = 0) -> Vec2? {
        var y: Double = inset
        while y <= viewHeight - inset {
            var x: Double = inset
            while x <= viewWidth - inset {
                let p: Vec2 = Vec2(x, y)
                var far: Bool = true
                if let away { far = (p - away).length >= minimum }
                if far, pick(p, snapshot, orbit: orbit) == wanted { return p }
                x += gridStep
            }
            y += gridStep
        }
        return nil
    }

    /// A point that picks the field (near the dish centre first, else on the grid); nil when none.
    static func fieldPoint(_ snapshot: Snapshot, orbit: ViewOrbit) -> Vec2? {
        if let p: Vec2 = point(near: Geometry.dishCentre(), snapshot, orbit: orbit, wanted: .field) { return p }
        return gridPoint(snapshot, orbit: orbit, wanted: .field)
    }

    /// The index of the first site no well stands on, at or after `from`, with a touch point; nil when none.
    static func freeSite(_ snapshot: Snapshot, orbit: ViewOrbit, from: Int = 0) -> Int? {
        var index: Int = from
        while index < snapshot.sites.count {
            let cell: Cell = snapshot.sites[index]
            var taken: Bool = false
            for well in snapshot.wells where well?.cell == cell { taken = true }
            if !taken, sitePoint(index, snapshot, orbit: orbit) != nil { return index }
            index += 1
        }
        return nil
    }

    /// The first empty slot of `snapshot`; nil when every slot holds a well.
    static func freeSlot(_ snapshot: Snapshot) -> Int? {
        for slot in snapshot.wells.indices where snapshot.wells[slot] == nil { return slot }
        return nil
    }

    /// The well the panel places on `cell` (the mirror's strength and sense).
    static func panelWell(_ mirror: MicroscopicAuroraMirror, on cell: Cell) -> Well {
        Well(cell: cell, strength: mirror.strength, sense: mirror.counterclockwise ? .counterclockwise : .clockwise)
    }

    /// A move drag of slot `slot`: a touch point on its well and a release point near another free site where the
    /// picker's drop target is that site, at least ``minimumDrag`` away; returns the drag and the site's cell.
    static func moveDrag(_ snapshot: Snapshot, orbit: ViewOrbit, slot: Int) -> (drag: WellDrag, cell: Cell)? {
        guard let start: Vec2 = wellPoint(slot, snapshot, orbit: orbit) else { return nil }
        for index in snapshot.sites.indices {
            let cell: Cell = snapshot.sites[index]
            var taken: Bool = false
            for well in snapshot.wells where well?.cell == cell { taken = true }
            if taken { continue }
            guard let c: Vec2 = project(Geometry.siteCentre(index, snapshot), orbit: orbit) else { continue }
            for radius in radii {
                let count: Int = radius == 0 ? 1 : directions
                for k in 0..<count {
                    let a: Double = Double(k) * 2 * Double.pi / Double(directions)
                    let end: Vec2 = c + Vec2(cos(a), sin(a)) * radius
                    guard inside(end), (end - start).length >= minimumDrag else { continue }
                    if drop(end, slot: slot, snapshot, orbit: orbit) == .site(cell) {
                        return (WellDrag(start: start, end: end), cell)
                    }
                }
            }
        }
        return nil
    }

    /// A removal drag of slot `slot`: a touch point on its well and a grid point where the drop target is a removal,
    /// at least ``minimumDrag`` away; nil when none.
    static func removalDrag(_ snapshot: Snapshot, orbit: ViewOrbit, slot: Int) -> WellDrag? {
        guard let start: Vec2 = wellPoint(slot, snapshot, orbit: orbit) else { return nil }
        var y: Double = inset
        while y <= viewHeight - inset {
            var x: Double = inset
            while x <= viewWidth - inset {
                let end: Vec2 = Vec2(x, y)
                if (end - start).length >= minimumDrag,
                   drop(end, slot: slot, snapshot, orbit: orbit) == .removal {
                    return WellDrag(start: start, end: end)
                }
                x += gridStep
            }
            y += gridStep
        }
        return nil
    }

    /// A scrub on `snapshot`: from a scrubber point near a quarter of the track to the projection of three quarters,
    /// where the tick read differs from the shown one; nil when none.
    static func scrub(_ snapshot: Snapshot, orbit: ViewOrbit) -> Scrub? {
        guard snapshot.ticksSwum >= 2 else { return nil }
        guard let start: Vec2 = point(near: Geometry.scrubberPoint(0.25), snapshot, orbit: orbit,
                                      wanted: .scrubber) else { return nil }
        let fractions: [Double] = [0.75, 0.9, 1.0]
        for fraction in fractions {
            guard let end: Vec2 = project(Geometry.scrubberPoint(fraction), orbit: orbit), inside(end),
                  (end - start).length >= minimumDrag else { continue }
            let to: Int = Picker.scrubTick(simd(end), size: size, snapshot: snapshot, orbit: orbit)
            if to != snapshot.shownTick { return Scrub(start: start, end: end, to: to) }
        }
        return nil
    }

    /// A drag of ``shortDrag`` points from `start` in the first of the four axis directions that ends inside the view.
    static func anyDragEnd(from start: Vec2) -> Vec2? {
        let axes: [Vec2] = [Vec2(1, 0), Vec2(-1, 0), Vec2(0, 1), Vec2(0, -1)]
        for axis in axes {
            let end: Vec2 = start + axis * shortDrag
            if inside(end) { return end }
        }
        return nil
    }

    /// The host action placing `well` in `slot`.
    static func placeValues(_ slot: Int, _ well: Well) -> [Double] {
        T.control(.place(slot: slot, well: well)).values
    }

    /// The core `before` after applying `control` with `values`, and the adapter's answer.
    static func applied(_ before: Core, _ control: String, _ values: [Double]) -> (core: Core, result: ActionResult) {
        var copy: Core = before
        let result: ActionResult = copy.apply(ExperienceAction(control: control, values: values, step: 0))
        return (copy, result)
    }

    /// The opening core of level `number` with `actions` applied; nil when the kernel refuses one of them.
    static func bare(_ number: Int, _ actions: [Action]) throws -> Core? {
        var core: Core = try Core.opening(number: number)
        for action in actions {
            let result: ActionResult = core.apply(T.experienceAction(action))
            if result != .accepted { return nil }
        }
        return core
    }

    // MARK: Level choice (from bare cores; the caller's `#require` records an issue when none fits)

    /// The first candidate level whose opening is playing with an action left, a free slot and a free site whose
    /// placement the kernel accepts; the target's slot is the first free one.
    static func placeTarget(_ panel: MicroscopicAuroraMirror) throws -> LevelTarget? {
        for number in candidateLevels {
            guard let core: Core = try bare(number, []), core.play.stage == .playing,
                  core.play.actionsLeft >= 1 else { continue }
            let snapshot: Snapshot = core.snapshot(time: 0)
            guard let slot: Int = freeSlot(snapshot), let site: Int = freeSite(snapshot, orbit: .authored) else {
                continue
            }
            let values: [Double] = placeValues(slot, panelWell(panel, on: snapshot.sites[site]))
            if applied(core, "well.place", values).result == .accepted {
                return LevelTarget(number: number, setUp: [], slot: slot)
            }
        }
        return nil
    }

    /// The set-up giving level `number` a placed well (none when its opening has one that picks, else one panel
    /// placement on its first free site) and that well's slot; nil when neither fits.
    static func wellSetUp(_ number: Int, _ panel: MicroscopicAuroraMirror) throws -> (setUp: [Action], slot: Int)? {
        guard let core: Core = try bare(number, []), core.play.stage == .playing else { return nil }
        let snapshot: Snapshot = core.snapshot(time: 0)
        for slot in snapshot.wells.indices where wellPoint(slot, snapshot, orbit: .authored) != nil {
            return ([], slot)
        }
        guard let slot: Int = freeSlot(snapshot), let site: Int = freeSite(snapshot, orbit: .authored) else {
            return nil
        }
        let setUp: [Action] = [.place(slot: slot, well: panelWell(panel, on: snapshot.sites[site]))]
        guard let placed: Core = try bare(number, setUp),
              wellPoint(slot, placed.snapshot(time: 0), orbit: .authored) != nil else { return nil }
        return (setUp, slot)
    }

    /// The first candidate level with a placed well, an action left and a move drag (when `move`) or a removal drag
    /// the kernel accepts.
    static func dragTarget(move: Bool, _ panel: MicroscopicAuroraMirror) throws -> LevelTarget? {
        for number in candidateLevels {
            guard let made = try wellSetUp(number, panel), let core: Core = try bare(number, made.setUp),
                  core.play.actionsLeft >= 1 else { continue }
            let snapshot: Snapshot = core.snapshot(time: 0)
            guard let well: Well = snapshot.wells[made.slot] else { continue }
            if move {
                guard let found = moveDrag(snapshot, orbit: .authored, slot: made.slot) else { continue }
                let moved: Well = Well(cell: found.cell, strength: well.strength, sense: well.sense)
                if applied(core, "well.place", placeValues(made.slot, moved)).result == .accepted {
                    return LevelTarget(number: number, setUp: made.setUp, slot: made.slot)
                }
            } else {
                guard removalDrag(snapshot, orbit: .authored, slot: made.slot) != nil else { continue }
                if applied(core, "well.remove", [Double(made.slot)]).result == .accepted {
                    return LevelTarget(number: number, setUp: made.setUp, slot: made.slot)
                }
            }
        }
        return nil
    }

    /// The first candidate level (opening, or after its certified plan) whose swim has a scrub.
    static func scrubTarget() throws -> LevelTarget? {
        for number in candidateLevels {
            let setUps: [[Action]] = [[], try T.certifiedPlan(number)]
            for setUp in setUps {
                guard let core: Core = try bare(number, setUp) else { continue }
                if scrub(core.snapshot(time: 0), orbit: .authored) != nil {
                    return LevelTarget(number: number, setUp: setUp, slot: 0)
                }
            }
        }
        return nil
    }

    /// The first candidate level where every free slot can be filled with panel placements on free sites within the
    /// budget, still playing, leaving another free site with a touch point.
    static func fullTarget(_ panel: MicroscopicAuroraMirror) throws -> LevelTarget? {
        for number in fullCandidateLevels {
            guard let opening: Core = try bare(number, []), opening.play.stage == .playing else { continue }
            var setUp: [Action] = []
            var snapshot: Snapshot = opening.snapshot(time: 0)
            var fits: Bool = true
            while fits, let slot: Int = freeSlot(snapshot) {
                guard let site: Int = freeSite(snapshot, orbit: .authored),
                      let next: Core = try bare(number, setUp
                        + [.place(slot: slot, well: panelWell(panel, on: snapshot.sites[site]))]) else {
                    fits = false
                    continue
                }
                setUp.append(.place(slot: slot, well: panelWell(panel, on: snapshot.sites[site])))
                snapshot = next.snapshot(time: 0)
            }
            guard fits, snapshot.stage == .playing, freeSlot(snapshot) == nil,
                  freeSite(snapshot, orbit: .authored) != nil else { continue }
            return LevelTarget(number: number, setUp: setUp, slot: 0)
        }
        return nil
    }

    /// The first candidate level whose whole budget can be spent by placing and removing one panel well in its first
    /// free slot, still playing, with a free slot and a free site left whose tap the kernel refuses with
    /// ``budgetCode``.
    static func budgetTarget(_ panel: MicroscopicAuroraMirror) throws -> LevelTarget? {
        for number in candidateLevels {
            guard let opening: Core = try bare(number, []), opening.play.stage == .playing else { continue }
            let first: Snapshot = opening.snapshot(time: 0)
            guard let slot: Int = freeSlot(first), let site: Int = freeSite(first, orbit: .authored) else { continue }
            let well: Well = panelWell(panel, on: first.sites[site])
            var setUp: [Action] = []
            for index in 0..<opening.play.actionsLeft {
                setUp.append(index % 2 == 0 ? .place(slot: slot, well: well) : .remove(slot: slot))
            }
            guard let spent: Core = try bare(number, setUp), spent.play.actionsLeft == 0,
                  spent.play.stage == .playing else { continue }
            let snapshot: Snapshot = spent.snapshot(time: 0)
            guard let free: Int = freeSlot(snapshot), let target: Int = freeSite(snapshot, orbit: .authored) else {
                continue
            }
            let values: [Double] = placeValues(free, panelWell(panel, on: snapshot.sites[target]))
            let result: ActionResult = applied(spent, "well.place", values).result
            if result.code.hasSuffix(budgetCode) {
                return LevelTarget(number: number, setUp: setUp, slot: free)
            }
        }
        return nil
    }

    /// The first candidate level won by its certified plan and the play with a well that picks and a drag from it
    /// inside the view.
    static func wonTarget() throws -> LevelTarget? {
        for number in candidateLevels {
            let actions: [Action] = try T.certifiedPlan(number) + [.play]
            guard let core: Core = try bare(number, actions), core.play.stage == .won else { continue }
            let snapshot: Snapshot = core.snapshot(time: 0)
            for slot in snapshot.wells.indices {
                guard let start: Vec2 = wellPoint(slot, snapshot, orbit: .authored),
                      anyDragEnd(from: start) != nil else { continue }
                return LevelTarget(number: number, setUp: actions, slot: slot)
            }
        }
        return nil
    }
}

@MainActor
@Suite(.serialized) struct MicroscopicAuroraGestureWiringTests {
    typealias Script = MicroscopicAuroraGestureScript
    typealias Core = MicroscopicAuroraExperienceCore
    typealias Snapshot = MicroscopicAuroraSceneSnapshot
    typealias Mirror = MicroscopicAuroraMirror
    typealias ViewOrbit = MicroscopicAuroraViewOrbit
    typealias Well = MicroscopicAuroraWell
    typealias Cell = MicroscopicAuroraCell
    typealias T = MicroscopicAuroraTest

    /// a. A tap on an empty site sends exactly one `well.place` in the first free slot with the panel's strength and
    /// sense.
    @Test func aSiteTapPlacesAWell() async throws {
        let target = try #require(try Script.placeTarget(Mirror()), "a free site and slot fit")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number)
        let ready: Core = try T.core(shell)
        try #require(ready.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        #expect(orbit == .authored)
        let site: Int = try #require(Script.freeSite(snapshot, orbit: orbit), "a free site picks")
        let point: Vec2 = try #require(Script.sitePoint(site, snapshot, orbit: orbit))
        try #require(Script.pick(point, snapshot, orbit: orbit) == .site(site))
        let well: Well = Script.panelWell(shell.presenter.mirror, on: snapshot.sites[site])
        let expected = Script.applied(ready, "well.place", Script.placeValues(target.slot, well))
        #expect(expected.result == .accepted)
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.tap(shell, id: 1, at: point, time: &time)
        let after: Core = try T.core(shell)
        #expect(after.play.wells[target.slot] == well, "the first free slot holds the panel's well on the site")
        #expect(after.play.actionsLeft == ready.play.actionsLeft - 1, "one action of the budget is spent")
        #expect(after.play == expected.core.play, "the kernel's verdict")
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "exactly one well.place")
        #expect(sentAfter.rejected == sentBefore.rejected)
        #expect(try T.digest(shell) != digest)
        #expect(shell.presenter.refusalLog.isEmpty)
        try T.draw(session)
        #expect(try Script.drawn(shell).wells[target.slot] == well, "the next frame draws the well")
    }

    /// b, c. A drag from a placed well previews (presentation only), then on release sends exactly one `well.place`
    /// to the new site (`move`) or one `well.remove` (dragged off the dish).
    func wellDragChangesOnce(move: Bool) async throws {
        let target = try #require(try Script.dragTarget(move: move, Mirror()), "a well drag fits (move \(move))")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let ready: Core = try T.core(shell)
        try #require(ready.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        let well: Well = try #require(snapshot.wells[target.slot])
        let drag: Script.WellDrag
        let control: String
        let values: [Double]
        let wanted: MicroscopicAuroraPreviewTarget
        if move {
            let found = try #require(Script.moveDrag(snapshot, orbit: orbit, slot: target.slot), "a move drag fits")
            drag = found.drag
            let moved: Well = Well(cell: found.cell, strength: well.strength, sense: well.sense)
            control = "well.place"
            values = Script.placeValues(target.slot, moved)
            wanted = .site(found.cell)
        } else {
            drag = try #require(Script.removalDrag(snapshot, orbit: orbit, slot: target.slot), "a removal drag fits")
            control = "well.remove"
            values = [Double(target.slot)]
            wanted = .removal
        }
        try #require(Script.pick(drag.start, snapshot, orbit: orbit) == .well(target.slot))
        try #require(Script.drop(drag.end, slot: target.slot, snapshot, orbit: orbit) == wanted)
        let expected = Script.applied(ready, control, values)
        #expect(expected.result == .accepted, "the kernel accepts \(control) \(values)")
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: drag.start, time: &time)
        Script.moves(shell, id: 1, from: drag.start, to: drag.end, time: &time)
        #expect(Script.sent(shell) == sentBefore, "nothing is sent before the release")
        #expect(try T.digest(shell) == digest, "a preview never changes the digest")
        #expect(try T.core(shell).play == ready.play, "nothing is changed before the release")
        try T.draw(session)
        let previewing: Snapshot = try Script.drawn(shell)
        let preview: MicroscopicAuroraPreview = try #require(previewing.preview, "the drag is previewed")
        #expect(preview.slot == target.slot)
        #expect(preview.target == wanted)
        #expect(previewing.wells == ready.play.wells, "the committed wells are still the snapshot's")
        #expect(try T.digest(shell) == digest)

        Script.touch(shell, id: 1, .ended, at: drag.end, time: &time)
        let after: Core = try T.core(shell)
        #expect(after.play == expected.core.play, "the kernel's verdict")
        #expect(after.play.actionsLeft == ready.play.actionsLeft - 1, "one action of the budget is spent")
        if move {
            #expect(after.play.wells[target.slot]?.strength == well.strength, "the move keeps the strength")
            #expect(after.play.wells[target.slot]?.sense == well.sense, "the move keeps the sense")
        } else {
            #expect(after.play.wells[target.slot] == nil, "the well is removed")
        }
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "exactly one \(control)")
        #expect(sentAfter.rejected == sentBefore.rejected)
        #expect(try T.digest(shell) != digest)
        #expect(shell.presenter.refusalLog.isEmpty)
        try T.draw(session)
        let drawn: Snapshot = try Script.drawn(shell)
        #expect(drawn.preview == nil, "the release drops the preview")
        #expect(drawn.wells == after.play.wells, "the next frame draws the changed wells")
    }

    /// b. A drag from a placed well to another site moves it with one `well.place`.
    @Test func aWellDragMovesTheWell() async throws {
        try await wellDragChangesOnce(move: true)
    }

    /// c. A drag from a placed well off the dish removes it with one `well.remove`.
    @Test func aWellDragOffTheDishRemovesIt() async throws {
        try await wellDragChangesOnce(move: false)
    }

    /// d. A drag along the scrubber shows the tick under the finger; no action spent, no digest change.
    @Test func aScrubShowsTheTick() async throws {
        let target = try #require(try Script.scrubTarget(), "a scrub fits")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let before: Core = try T.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        let scrub: Script.Scrub = try #require(Script.scrub(snapshot, orbit: orbit), "a scrub fits")
        try #require(Script.pick(scrub.start, snapshot, orbit: orbit) == .scrubber)
        let digest: String = try T.digest(shell)
        let rejectedBefore: Int = Script.sent(shell).rejected
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: scrub.start, time: &time)
        Script.moves(shell, id: 1, from: scrub.start, to: scrub.end, time: &time)
        #expect(try T.core(shell).shownTick == scrub.to, "the shown tick follows the finger")
        Script.touch(shell, id: 1, .ended, at: scrub.end, time: &time)
        let after: Core = try T.core(shell)
        #expect(after.shownTick == scrub.to)
        #expect(after.shownTick != before.shownTick, "the shown tick changed")
        #expect(after.play == before.play, "a scrub changes no kernel state")
        #expect(after.play.actionsLeft == before.play.actionsLeft, "no action is spent")
        #expect(Script.sent(shell).rejected == rejectedBefore)
        #expect(try T.digest(shell) == digest, "a shown tick never changes the digest")
        #expect(shell.presenter.refusalLog.isEmpty)
        try T.draw(session)
        #expect(shell.presenter.mirror.shownTick == scrub.to, "the panel follows the shown tick")
        #expect(try Script.drawn(shell).shownTick == scrub.to, "the drawn snapshot shows the tick")
        #expect(try Script.drawn(shell).preview == nil, "a scrub previews nothing")
    }

    /// e. A tap on the field toggles the freeze, drawn; `toggleFreeze()` likewise; nothing is sent.
    @Test func aFieldTapTogglesTheFreeze() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: Script.candidateLevels[0])
        let before: Core = try T.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        #expect(snapshot.frozen == false, "the scene opens unfrozen")
        let orbit: ViewOrbit = shell.presenter.orbit
        let field: Vec2 = try #require(Script.fieldPoint(snapshot, orbit: orbit), "the field picks")
        try #require(Script.pick(field, snapshot, orbit: orbit) == .field)
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.tap(shell, id: 1, at: field, time: &time)
        try T.draw(session)
        #expect(try Script.drawn(shell).frozen, "a field tap freezes the scene")
        #expect(Script.sent(shell) == sentBefore, "the freeze sends nothing")
        #expect(try T.digest(shell) == digest, "the freeze never changes the digest")

        time += Script.gesturePause
        Script.tap(shell, id: 2, at: field, time: &time)
        try T.draw(session)
        #expect(try Script.drawn(shell).frozen == false, "a second field tap unfreezes it")

        shell.presenter.toggleFreeze()
        try T.draw(session)
        #expect(try Script.drawn(shell).frozen, "Freeze freezes the scene")
        shell.presenter.toggleFreeze()
        try T.draw(session)
        #expect(try Script.drawn(shell).frozen == false, "Freeze again unfreezes it")
        #expect(Script.sent(shell) == sentBefore, "no kernel action and no tick")
        #expect(try T.digest(shell) == digest)
        #expect(try T.core(shell).play == before.play)
        #expect(try T.core(shell).shownTick == before.shownTick)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// f. A two-finger drag orbits the camera and changes no digest; "Reset view" and a double tap on empty space
    /// return to the authored orbit.
    @Test func anOrbitChangesTheViewButNotTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: Script.candidateLevels[0])
        let before: Core = try T.core(shell)
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        #expect(shell.presenter.orbit == .authored)
        let snapshot: Snapshot = try Script.drawn(shell)
        let first: Vec2 = try #require(Script.gridPoint(snapshot, orbit: .authored, wanted: .empty),
                                       "empty space picks")
        let second: Vec2 = try #require(Script.gridPoint(snapshot, orbit: .authored, wanted: .empty, away: first,
                                                         minimum: 200), "a second empty point picks")
        let shift: Vec2 = Vec2(100, 0)
        var time: Double = Script.start

        Script.orbit(shell, ids: 1, 2, from: first, second, by: shift, time: &time)
        let orbit: ViewOrbit = shell.presenter.orbit
        #expect(orbit != .authored, "two fingers orbit the camera")
        #expect(orbit == orbit.clamped(), "the orbit stays within its bounds")
        #expect(Script.sent(shell) == sentBefore, "an orbit sends nothing")
        #expect(try T.digest(shell) == digest, "an orbit never changes the digest")
        try T.draw(session)
        #expect(shell.presenter.fallbackReason == nil, "\(shell.presenter.fallbackReason ?? "")")
        #expect(try T.digest(shell) == digest)

        shell.presenter.resetView()
        #expect(shell.presenter.orbit == .authored, "Reset view restores the authored orbit")
        #expect(Script.sent(shell) == sentBefore, "Reset view sends nothing")
        #expect(try T.digest(shell) == digest)

        // Orbit again, then a double tap on empty space returns to the authored orbit.
        time += Script.gesturePause
        Script.orbit(shell, ids: 3, 4, from: first, second, by: shift, time: &time)
        let turned: ViewOrbit = shell.presenter.orbit
        #expect(turned != .authored)
        try T.draw(session)
        let drawn: Snapshot = try Script.drawn(shell)
        let empty: Vec2 = try #require(Script.gridPoint(drawn, orbit: turned, wanted: .empty),
                                       "empty space picks at the orbit")
        time += Script.gesturePause
        Script.tap(shell, id: 5, at: empty, time: &time)
        #expect(shell.presenter.orbit == turned, "a single tap on empty space keeps the orbit")
        time += Script.tapGap
        Script.tap(shell, id: 6, at: empty, time: &time)
        #expect(shell.presenter.orbit == .authored, "a double tap on empty space resets the view")
        try T.draw(session)
        #expect(shell.presenter.fallbackReason == nil)
        #expect(Script.sent(shell) == sentBefore, "no kernel action and no tick")
        #expect(try T.digest(shell) == digest)
        let after: Core = try T.core(shell)
        #expect(after.shownTick == before.shownTick)
        #expect(after.play == before.play)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// g. A site tap with no action left is sent and refused; the mirror shows the refusal in words and the bare
    /// code is logged.
    @Test func aRefusedChangeIsShown() async throws {
        let target = try #require(try Script.budgetTarget(Mirror()), "a level whose budget can be spent, then a tap")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let spent: Core = try T.core(shell)
        try #require(spent.play.actionsLeft == 0, "the budget is spent")
        try #require(spent.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        let site: Int = try #require(Script.freeSite(snapshot, orbit: orbit), "a free site picks")
        let point: Vec2 = try #require(Script.sitePoint(site, snapshot, orbit: orbit))
        let well: Well = Script.panelWell(shell.presenter.mirror, on: snapshot.sites[site])
        let expected = Script.applied(spent, "well.place", Script.placeValues(target.slot, well))
        #expect(expected.result.code.hasSuffix(Script.budgetCode), "\(expected.result.code)")
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.tap(shell, id: 1, at: point, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted, "nothing was accepted")
        #expect(sentAfter.rejected == sentBefore.rejected + 1, "the well.place was sent and refused")
        let message: String = try #require(shell.presenter.mirror.message, "the refusal is shown")
        #expect(message == MicroscopicAuroraFeedbackPlan.refusalText(code: Script.budgetCode), "\(message)")
        #expect(message == "No actions are left: undo or retry.", "\(message)")
        #expect(message == Mirror.refusalText(code: Script.budgetCode), "\(message)")
        #expect(Mirror.refusalText(code: Script.rulePrefix + Script.budgetCode)
                    == Mirror.refusalText(code: Script.budgetCode), "codes are read with or without the prefix")
        #expect(shell.presenter.refusalLog.last == Script.budgetCode, "the bare code is logged")
        #expect(try T.core(shell).play == spent.play, "a refused placement changes nothing")
        #expect(try T.digest(shell) == digest)
        try T.draw(session)
        #expect(try Script.drawn(shell).preview == nil)
    }

    /// h. On a won play a well drag sends nothing and the mirror says the play is over.
    @Test func aWellDragOnAWonPlaySendsNothing() async throws {
        let target = try #require(try Script.wonTarget(), "a won play with a well inside the view")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let won: Core = try T.core(shell)
        try #require(won.play.stage == .won, "level \(target.number) is won")
        let snapshot: Snapshot = try Script.drawn(shell)
        #expect(snapshot.stage == .won)
        let orbit: ViewOrbit = shell.presenter.orbit
        let start: Vec2 = try #require(Script.wellPoint(target.slot, snapshot, orbit: orbit), "the well picks")
        let end: Vec2 = try #require(Script.anyDragEnd(from: start), "a drag fits")
        try #require(Script.pick(start, snapshot, orbit: orbit) == .well(target.slot))
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: start, time: &time)
        Script.moves(shell, id: 1, from: start, to: end, time: &time)
        #expect(shell.presenter.mirror.message == Script.finishedText, "the drag says the play is over")
        Script.touch(shell, id: 1, .ended, at: end, time: &time)
        #expect(shell.presenter.mirror.message == Script.finishedText)
        #expect(Script.sent(shell) == sentBefore, "a well drag on a won play sends nothing")
        #expect(try T.digest(shell) == digest)
        #expect(try T.core(shell).play == won.play)
        #expect(shell.presenter.refusalLog.isEmpty, "nothing was sent, so nothing was refused")
        try T.draw(session)
        #expect(try Script.drawn(shell).preview == nil, "a won play previews nothing")
    }

    /// i. A tap on a well selects its slot and explains the drag; nothing is sent.
    @Test func aWellTapSelectsAndExplains() async throws {
        let wellTarget = try #require(try Script.dragTarget(move: false, Mirror()), "a placed well picks")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: wellTarget.number, setUp: wellTarget.setUp)
        let before: Core = try T.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        let point: Vec2 = try #require(Script.wellPoint(wellTarget.slot, snapshot, orbit: orbit), "the well picks")
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.tap(shell, id: 1, at: point, time: &time)
        #expect(shell.presenter.mirror.message == Script.wellTapText, "the tap says how to move a well")
        #expect(shell.presenter.mirror.slot == wellTarget.slot, "a tapped well selects its slot")
        #expect(Script.sent(shell) == sentBefore, "a tap on a well sends nothing")
        #expect(try T.digest(shell) == digest)
        #expect(try T.core(shell).play == before.play)
        try T.draw(session)
        #expect(try Script.drawn(shell).preview == nil, "a tap previews nothing")
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// i. A site tap with every slot used explains and sends nothing.
    @Test func aSiteTapWithEverySlotUsedExplains() async throws {
        let fullTarget = try #require(try Script.fullTarget(Mirror()), "every slot can be filled with a site left")
        let fullSession = ExperienceSession()
        defer { fullSession.close() }
        let full = try await Script.open(fullSession, number: fullTarget.number, setUp: fullTarget.setUp)
        let filled: Core = try T.core(full)
        let fullSnapshot: Snapshot = try Script.drawn(full)
        #expect(Script.freeSlot(fullSnapshot) == nil, "every slot holds a well")
        let site: Int = try #require(Script.freeSite(fullSnapshot, orbit: full.presenter.orbit), "a free site picks")
        let sitePoint: Vec2 = try #require(Script.sitePoint(site, fullSnapshot, orbit: full.presenter.orbit))
        let fullDigest: String = try T.digest(full)
        let fullSent: Script.Sent = Script.sent(full)
        var time: Double = Script.start

        Script.tap(full, id: 1, at: sitePoint, time: &time)
        #expect(full.presenter.mirror.message == Script.slotsFullText, "the tap says every slot is used")
        #expect(Script.sent(full) == fullSent, "a site tap with every slot used sends nothing")
        #expect(try T.digest(full) == fullDigest)
        #expect(try T.core(full).play == filled.play)
        #expect(full.presenter.refusalLog.isEmpty)
    }
}
#endif
