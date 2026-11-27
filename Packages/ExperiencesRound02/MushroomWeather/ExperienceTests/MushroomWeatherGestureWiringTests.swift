// MushroomWeatherGestureWiringTests — feature 494 (R02-G20-04) T-R02G2004-005 (FR-R02G2004-001 … 011;
// SC-R02G2004-001 … 005). On the simulator, through the one app's session host: scripted touches go to the
// presenter's `pointer(_:viewSize:port:)` with the shell's own `port` at a 720 × 480-point view (aspect 1.5). Modelled
// on MicroscopicAuroraGestureWiringTests (feature 484). Targets are projected through the drawn camera of the
// presenter's orbit (`MushroomWeatherSceneGeometry.camera(aspect:orbit:)`, then `MushroomWeatherPicker.viewPoint` of
// `siteCentre`, `podCentre`, `ventCentre`, `moonCentre` and `scrubberPoint`) on the presenter's `lastSnapshot`, and
// each is confirmed with the picker (`pick`, `dropTarget`, `moonLevel`, `scrubCycle`) at the same view size before any
// touch. Levels are chosen at run time from bare opening cores (seed n − 1 opens level n); the kernel's verdict is the
// one a bare core gives for the same actions.
// Checked:
//   a. a tap on an empty site sends exactly one `pod.place [slot, row, column]` in the first free slot
//      (FR-R02G2004-001);
//   b. a drag from a placed pod to another site previews the weather (drawn as the snapshot's preview, no digest
//      change) and on release sends exactly one `pod.place` moving that slot's pod (FR-R02G2004-002, 006);
//   c. a drag from a placed pod off the floor previews the removal and sends exactly one `pod.remove`
//      (FR-R02G2004-002);
//   d. a tap on a vent sends exactly one `vent.set [index, open]` with the other state (FR-R02G2004-003);
//   e. a vertical drag from the moon previews the moonlight under the finger and on release sends exactly one
//      `moon.set [level]` (FR-R02G2004-004, 006);
//   f. a drag along the scrubber shows the cycle under the finger (`clock.show`); no action spent, the digest unchanged
//      (FR-R02G2004-005);
//   g. a two-finger orbit changes the orbit and never the digest; `resetView()` and a double tap on empty space return
//      to the authored orbit with no kernel action (FR-R02G2004-008);
//   h. a refused change (a vent or site tap with no action left) is sent, refused, shown in the mirror message and
//      logged with its bare code (FR-R02G2004-011);
//   i. a pod (or moon) drag on a won play sends nothing and says "The play is over: undo or go to the next level"
//      (FR-R02G2004-009);
//   j. a tap on a pod selects its slot and explains the drag; a tap on the moon explains the moon drag; a site tap
//      with every slot used explains and sends nothing (FR-R02G2004-001, 010);
//   the panel keeps every action (FR-R02G2004-010) and the gestures are proved here on the simulator (FR-R02G2004-011).
// Explicit synthetic timestamps (no clock, no sleep, no wall-clock assertion). Explicit types and plain loops (CI
// type-check rule); no nested closure literals. Synthetic data only. Each test well under 10 s.
//
// Presenter API used (T-R02G2004-005): `MushroomWeatherPresenter.pointer(_:viewSize:port:)`, `orbit`, `resetView()`,
// `refusalLog` (bare codes, oldest first), `lastSnapshot` (carries the drawn `preview` after a frame), `mirror.message`
// (the controller's explain texts verbatim; a refusal as a line containing `MushroomWeatherMirror.refusalText(code:)`,
// which reads codes with or without `action.rule.`), `mirror.slot` (a tapped pod's slot). Explain texts: the
// controller's `podReason`, `moonReason`, `fullReason` and `finishedReason`.
#if os(iOS)
import CoreGraphics
import Foundation
import MushroomWeatherCore
import Testing
@testable import MushroomWeatherExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// Scripted touches on Mushroom Weather, placed through the drawn camera.
@MainActor
enum MushroomWeatherGestureScript {
    typealias Shell = MushroomWeatherTest.Shell
    typealias Snapshot = MushroomWeatherSceneSnapshot
    typealias Geometry = MushroomWeatherSceneGeometry
    typealias Core = MushroomWeatherExperienceCore
    typealias Picker = MushroomWeatherPicker
    typealias Pick = MushroomWeatherPick
    typealias ViewOrbit = MushroomWeatherViewOrbit
    typealias Action = MushroomWeatherAction
    typealias Cell = MushroomWeatherCell
    typealias PreviewKind = MushroomWeatherPreviewKind
    typealias Controller = MushroomWeatherGestureController
    typealias T = MushroomWeatherTest

    /// The view's width in points (aspect 1.5).
    nonisolated static let viewWidth: Double = 720
    /// The view's height in points.
    nonisolated static let viewHeight: Double = 480
    /// The view size handed with every event.
    static var viewSize: Vec2 { Vec2(viewWidth, viewHeight) }
    /// The view size as the picker takes it.
    static var size: SIMD2<Double> { SIMD2<Double>(viewWidth, viewHeight) }
    /// The first synthetic timestamp, seconds (the controller only compares timestamps).
    nonisolated static let start: Double = 100
    /// The time between scripted events in seconds (synthetic).
    nonisolated static let frame: Double = 1.0 / 60
    /// The pause between the two taps of a double tap, seconds (inside the 0.35 s window).
    nonisolated static let tapGap: Double = 0.1
    /// The pause between two separate gestures, seconds (outside every double-tap window).
    nonisolated static let gesturePause: Double = 1
    /// The moves of a scripted straight drag.
    nonisolated static let dragMoves: Int = 6
    /// The shortest pod drag scripted, points (twice the drag distance 16).
    nonisolated static let minimumDrag: Double = 32
    /// The length of a drag that only has to start a drag, points (more than the drag distance 16).
    nonisolated static let shortDrag: Double = 40
    /// How far inside the view a touch point must lie, points.
    nonisolated static let inset: Double = 8
    /// The radii in points around a projected centre at which a touch point is tried.
    nonisolated static let radii: [Double] = [0, 4, 8]
    /// The directions tried at each radius.
    nonisolated static let directions: Int = 8
    /// The grid step of the empty-space and removal searches, points.
    nonisolated static let gridStep: Double = 12
    /// The moonlight steps tried for a moon drag (each ``MushroomWeatherPicker/moonStep`` points of vertical travel).
    nonisolated static let moonSteps: [Int] = [1, 2, 3]
    /// The candidate levels; the first that fits is used.
    nonisolated static let candidateLevels: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
    /// The levels searched for a full set of slots with a free site left (more sites than slots).
    nonisolated static let fullCandidateLevels: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17,
                                                         18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]
    /// The kernel's budget refusal code.
    nonisolated static let budgetCode: String = "r02-g20.budget"
    /// The engine's prefix of a rule refusal.
    nonisolated static let rulePrefix: String = "action.rule."
    /// The explain text of a tap on a pod.
    nonisolated static let podTapText: String = MushroomWeatherGestureController.podReason
    /// The explain text of a tap on the moon.
    nonisolated static let moonTapText: String = MushroomWeatherGestureController.moonReason
    /// The explain text of a site tap with every slot used.
    nonisolated static let slotsFullText: String = MushroomWeatherGestureController.fullReason
    /// The explain text of a gesture on a finished play.
    nonisolated static let finishedText: String = MushroomWeatherGestureController.finishedReason

    /// What the engine has counted so far: accepted and rejected actions.
    struct Sent: Equatable {
        /// The accepted actions.
        let accepted: Int
        /// The rejected actions.
        let rejected: Int
    }

    /// A level, the actions issued through the shell before the gesture and the slot or vent the gesture is about.
    struct LevelTarget {
        /// The level number.
        let number: Int
        /// The actions issued before the gesture.
        let setUp: [Action]
        /// The slot the gesture concerns (the pod dragged or tapped, or the slot a tap fills), or the vent tapped.
        let slot: Int
    }

    /// A level whose budget is spent, and the gesture the kernel then refuses: a tap on vent `vent`, or (nil) a tap
    /// on a free site filling slot `slot`.
    struct BudgetTarget {
        /// The level number.
        let number: Int
        /// The actions issued before the gesture (the whole budget).
        let setUp: [Action]
        /// The vent tapped, or nil for a site tap.
        let vent: Int?
        /// The slot a site tap fills (unused for a vent tap).
        let slot: Int
    }

    /// A one-finger drag on a snapshot: the touch-down point and the release point.
    struct Drag {
        /// The touch-down point.
        let start: Vec2
        /// The release point.
        let end: Vec2
    }

    /// A moon drag on a snapshot: the touch-down point on the moon, the release point and the level read there.
    struct MoonDrag {
        /// The touch-down point (picks the moon).
        let start: Vec2
        /// The release point (straight above or below).
        let end: Vec2
        /// The moonlight level read at the release point (never the current one).
        let level: Int
    }

    /// A scrub on a snapshot: the touch-down point on the scrubber, the release point and the cycle read there.
    struct Scrub {
        /// The touch-down point (picks the scrubber).
        let start: Vec2
        /// The release point.
        let end: Vec2
        /// The cycle under the release point.
        let to: Int
    }

    /// Opens level `number` (seed `number − 1`) at the scripted view size with cycle 0 shown, issues `setUp` and
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
    static func drop(_ location: Vec2, slot: Int, _ snapshot: Snapshot, orbit: ViewOrbit) -> PreviewKind? {
        Picker.dropTarget(simd(location), slot: slot, size: size, snapshot: snapshot, orbit: orbit)
    }

    /// World `point` in view points through the drawn camera at `orbit`; nil when it does not project.
    static func project(_ point: SIMD3<Double>, orbit: ViewOrbit) -> Vec2? {
        let camera: MushroomWeatherCamera = Geometry.camera(aspect: viewWidth / viewHeight, orbit: orbit)
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

    /// A point that picks the pod of slot `slot`; nil when the slot is empty or none picks.
    static func podPoint(_ slot: Int, _ snapshot: Snapshot, orbit: ViewOrbit) -> Vec2? {
        guard let centre: SIMD3<Double> = Geometry.podCentre(slot, snapshot) else { return nil }
        return point(near: centre, snapshot, orbit: orbit, wanted: .pod(slot))
    }

    /// A point that picks vent `index`; nil when none.
    static func ventPoint(_ index: Int, _ snapshot: Snapshot, orbit: ViewOrbit) -> Vec2? {
        guard index >= 0, index < snapshot.vents.count else { return nil }
        return point(near: Geometry.ventCentre(index, snapshot), snapshot, orbit: orbit, wanted: .vent(index))
    }

    /// A point that picks the moon; nil when none.
    static func moonPoint(_ snapshot: Snapshot, orbit: ViewOrbit) -> Vec2? {
        point(near: Geometry.moonCentre(), snapshot, orbit: orbit, wanted: .moon)
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

    /// Whether a pod of `snapshot` stands on `cell`.
    static func taken(_ cell: Cell, _ snapshot: Snapshot) -> Bool {
        for pod in snapshot.pods where pod == cell { return true }
        return false
    }

    /// The index of the first site no pod stands on, with a touch point; nil when none.
    static func freeSite(_ snapshot: Snapshot, orbit: ViewOrbit) -> Int? {
        for index in snapshot.sites.indices {
            if taken(snapshot.sites[index], snapshot) { continue }
            if sitePoint(index, snapshot, orbit: orbit) != nil { return index }
        }
        return nil
    }

    /// The first empty slot of `snapshot`; nil when every slot holds a pod.
    static func freeSlot(_ snapshot: Snapshot) -> Int? {
        for slot in snapshot.pods.indices where snapshot.pods[slot] == nil { return slot }
        return nil
    }

    /// A move drag of slot `slot`: a touch point on its pod and a release point near another free site where the
    /// picker's drop target is that site, at least ``minimumDrag`` away; returns the drag and the site's cell.
    static func moveDrag(_ snapshot: Snapshot, orbit: ViewOrbit, slot: Int) -> (drag: Drag, cell: Cell)? {
        guard let start: Vec2 = podPoint(slot, snapshot, orbit: orbit) else { return nil }
        for index in snapshot.sites.indices {
            let cell: Cell = snapshot.sites[index]
            if taken(cell, snapshot) { continue }
            guard let c: Vec2 = project(Geometry.siteCentre(index, snapshot), orbit: orbit) else { continue }
            for radius in radii {
                let count: Int = radius == 0 ? 1 : directions
                for k in 0..<count {
                    let a: Double = Double(k) * 2 * Double.pi / Double(directions)
                    let end: Vec2 = c + Vec2(cos(a), sin(a)) * radius
                    guard inside(end), (end - start).length >= minimumDrag else { continue }
                    if drop(end, slot: slot, snapshot, orbit: orbit) == .pod(slot: slot, target: cell) {
                        return (Drag(start: start, end: end), cell)
                    }
                }
            }
        }
        return nil
    }

    /// A removal drag of slot `slot`: a touch point on its pod and a grid point where the drop target is a removal,
    /// at least ``minimumDrag`` away; nil when none.
    static func removalDrag(_ snapshot: Snapshot, orbit: ViewOrbit, slot: Int) -> Drag? {
        guard let start: Vec2 = podPoint(slot, snapshot, orbit: orbit) else { return nil }
        let removal: PreviewKind = .pod(slot: slot, target: nil)
        var y: Double = inset
        while y <= viewHeight - inset {
            var x: Double = inset
            while x <= viewWidth - inset {
                let end: Vec2 = Vec2(x, y)
                if (end - start).length >= minimumDrag, drop(end, slot: slot, snapshot, orbit: orbit) == removal {
                    return Drag(start: start, end: end)
                }
                x += gridStep
            }
            y += gridStep
        }
        return nil
    }

    /// A moon drag on `snapshot`: from a moon point straight up or down by 1 … 3 moon steps, ending inside the view,
    /// where the level read differs from the current moonlight; nil when none.
    static func moonDrag(_ snapshot: Snapshot, orbit: ViewOrbit) -> MoonDrag? {
        guard let start: Vec2 = moonPoint(snapshot, orbit: orbit) else { return nil }
        let signs: [Double] = [1, -1]
        for steps in moonSteps {
            for sign in signs {
                let travel: Double = sign * Picker.moonStep * Double(steps)
                let end: Vec2 = start + Vec2(0, travel)
                guard inside(end) else { continue }
                let level: Int = Picker.moonLevel(start: snapshot.moonlight, travel: travel)
                if level != snapshot.moonlight { return MoonDrag(start: start, end: end, level: level) }
            }
        }
        return nil
    }

    /// A scrub on `snapshot`: from a scrubber point near a quarter of the track to the projection of three quarters,
    /// where the cycle read differs from the shown one; nil when none.
    static func scrub(_ snapshot: Snapshot, orbit: ViewOrbit) -> Scrub? {
        guard snapshot.cyclesRun >= 2 else { return nil }
        guard let start: Vec2 = point(near: Geometry.scrubberPoint(0.25), snapshot, orbit: orbit,
                                      wanted: .scrubber) else { return nil }
        let fractions: [Double] = [0.75, 0.9, 1.0]
        for fraction in fractions {
            guard let end: Vec2 = project(Geometry.scrubberPoint(fraction), orbit: orbit), inside(end),
                  (end - start).length >= minimumDrag else { continue }
            let to: Int = Picker.scrubCycle(simd(end), size: size, snapshot: snapshot, orbit: orbit)
            if to != snapshot.shownCycle { return Scrub(start: start, end: end, to: to) }
        }
        return nil
    }

    /// A drag of ``shortDrag`` points from `start` in the first of the four axis directions that ends inside the view.
    static func anyDragEnd(from start: Vec2) -> Vec2? {
        let axes: [Vec2] = [Vec2(0, 1), Vec2(0, -1), Vec2(1, 0), Vec2(-1, 0)]
        for axis in axes {
            let end: Vec2 = start + axis * shortDrag
            if inside(end) { return end }
        }
        return nil
    }

    /// The host values placing slot `slot`'s pod on `cell`: [slot, row, column].
    static func placeValues(_ slot: Int, _ cell: Cell) -> [Double] {
        T.control(.place(slot: slot, cell: cell)).values
    }

    /// The host values setting vent `index` open or shut: [index, open ? 1 : 0].
    static func ventValues(_ index: Int, open: Bool) -> [Double] {
        T.control(.vent(index: index, open: open)).values
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
    static func placeTarget() throws -> LevelTarget? {
        for number in candidateLevels {
            guard let core: Core = try bare(number, []), core.play.stage == .playing,
                  core.play.actionsLeft >= 1 else { continue }
            let snapshot: Snapshot = core.snapshot(time: 0)
            guard let slot: Int = freeSlot(snapshot), let site: Int = freeSite(snapshot, orbit: .authored) else {
                continue
            }
            if applied(core, "pod.place", placeValues(slot, snapshot.sites[site])).result == .accepted {
                return LevelTarget(number: number, setUp: [], slot: slot)
            }
        }
        return nil
    }

    /// The set-up giving level `number` a placed pod (none when its opening has one that picks, else one placement on
    /// its first free site) and that pod's slot; nil when neither fits.
    static func podSetUp(_ number: Int) throws -> (setUp: [Action], slot: Int)? {
        guard let core: Core = try bare(number, []), core.play.stage == .playing else { return nil }
        let snapshot: Snapshot = core.snapshot(time: 0)
        for slot in snapshot.pods.indices where podPoint(slot, snapshot, orbit: .authored) != nil {
            return ([], slot)
        }
        guard let slot: Int = freeSlot(snapshot), let site: Int = freeSite(snapshot, orbit: .authored) else {
            return nil
        }
        let setUp: [Action] = [.place(slot: slot, cell: snapshot.sites[site])]
        guard let placed: Core = try bare(number, setUp),
              podPoint(slot, placed.snapshot(time: 0), orbit: .authored) != nil else { return nil }
        return (setUp, slot)
    }

    /// The first candidate level with a placed pod, an action left and a move drag (when `move`) or a removal drag
    /// the kernel accepts.
    static func dragTarget(move: Bool) throws -> LevelTarget? {
        for number in candidateLevels {
            guard let made = try podSetUp(number), let core: Core = try bare(number, made.setUp),
                  core.play.stage == .playing, core.play.actionsLeft >= 1 else { continue }
            let snapshot: Snapshot = core.snapshot(time: 0)
            if move {
                guard let found = moveDrag(snapshot, orbit: .authored, slot: made.slot) else { continue }
                if applied(core, "pod.place", placeValues(made.slot, found.cell)).result == .accepted {
                    return LevelTarget(number: number, setUp: made.setUp, slot: made.slot)
                }
            } else {
                guard removalDrag(snapshot, orbit: .authored, slot: made.slot) != nil else { continue }
                if applied(core, "pod.remove", [Double(made.slot)]).result == .accepted {
                    return LevelTarget(number: number, setUp: made.setUp, slot: made.slot)
                }
            }
        }
        return nil
    }

    /// The first candidate level whose opening is playing with an action left and a vent that picks whose change to
    /// the other state the kernel accepts; the target's slot is that vent.
    static func ventTarget() throws -> LevelTarget? {
        for number in candidateLevels {
            guard let core: Core = try bare(number, []), core.play.stage == .playing,
                  core.play.actionsLeft >= 1 else { continue }
            let snapshot: Snapshot = core.snapshot(time: 0)
            for index in snapshot.vents.indices where index < snapshot.ventsOpen.count {
                guard ventPoint(index, snapshot, orbit: .authored) != nil else { continue }
                let values: [Double] = ventValues(index, open: !snapshot.ventsOpen[index])
                if applied(core, "vent.set", values).result == .accepted {
                    return LevelTarget(number: number, setUp: [], slot: index)
                }
            }
        }
        return nil
    }

    /// The first candidate level whose opening is playing with an action left and a moon drag whose level the kernel
    /// accepts.
    static func moonTarget() throws -> LevelTarget? {
        for number in candidateLevels {
            guard let core: Core = try bare(number, []), core.play.stage == .playing,
                  core.play.actionsLeft >= 1 else { continue }
            guard let found: MoonDrag = moonDrag(core.snapshot(time: 0), orbit: .authored) else { continue }
            if applied(core, "moon.set", [Double(found.level)]).result == .accepted {
                return LevelTarget(number: number, setUp: [], slot: 0)
            }
        }
        return nil
    }

    /// The first candidate level (opening, or after its certified plan) whose run has a scrub.
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

    /// The first candidate level where every free slot can be filled with placements on free sites within the
    /// budget, still playing, leaving another free site with a touch point.
    static func fullTarget() throws -> LevelTarget? {
        for number in fullCandidateLevels {
            guard let opening: Core = try bare(number, []), opening.play.stage == .playing else { continue }
            var setUp: [Action] = []
            var snapshot: Snapshot = opening.snapshot(time: 0)
            var fits: Bool = true
            while fits, let slot: Int = freeSlot(snapshot) {
                guard let site: Int = freeSite(snapshot, orbit: .authored) else {
                    fits = false
                    continue
                }
                let next: [Action] = setUp + [.place(slot: slot, cell: snapshot.sites[site])]
                guard let placed: Core = try bare(number, next) else {
                    fits = false
                    continue
                }
                setUp = next
                snapshot = placed.snapshot(time: 0)
            }
            guard fits, snapshot.stage == .playing, freeSlot(snapshot) == nil,
                  freeSite(snapshot, orbit: .authored) != nil else { continue }
            return LevelTarget(number: number, setUp: setUp, slot: 0)
        }
        return nil
    }

    /// The first candidate level whose whole budget can be spent, still playing, after which a gesture is refused
    /// with ``budgetCode``: toggling a vent that picks back and forth (the refused gesture a tap on it), else placing
    /// and removing a pod in its first free slot (the refused gesture a tap on a free site).
    static func budgetTarget() throws -> BudgetTarget? {
        for number in candidateLevels {
            guard let opening: Core = try bare(number, []), opening.play.stage == .playing else { continue }
            let first: Snapshot = opening.snapshot(time: 0)
            let budget: Int = opening.play.actionsLeft
            for index in first.vents.indices where index < first.ventsOpen.count {
                guard ventPoint(index, first, orbit: .authored) != nil else { continue }
                let open: Bool = first.ventsOpen[index]
                var setUp: [Action] = []
                for step in 0..<budget { setUp.append(.vent(index: index, open: step % 2 == 0 ? !open : open)) }
                guard let spent: Core = try bare(number, setUp), spent.play.actionsLeft == 0,
                      spent.play.stage == .playing else { continue }
                let now: Bool = spent.play.arrangement.ventsOpen[index]
                let result: ActionResult = applied(spent, "vent.set", ventValues(index, open: !now)).result
                if result.code.hasSuffix(budgetCode) {
                    return BudgetTarget(number: number, setUp: setUp, vent: index, slot: 0)
                }
            }
            guard let slot: Int = freeSlot(first), let site: Int = freeSite(first, orbit: .authored) else { continue }
            var setUp: [Action] = []
            for step in 0..<budget {
                setUp.append(step % 2 == 0 ? .place(slot: slot, cell: first.sites[site]) : .remove(slot: slot))
            }
            guard let spent: Core = try bare(number, setUp), spent.play.actionsLeft == 0,
                  spent.play.stage == .playing else { continue }
            let snapshot: Snapshot = spent.snapshot(time: 0)
            guard let free: Int = freeSlot(snapshot), let target: Int = freeSite(snapshot, orbit: .authored) else {
                continue
            }
            let result: ActionResult = applied(spent, "pod.place", placeValues(free, snapshot.sites[target])).result
            if result.code.hasSuffix(budgetCode) {
                return BudgetTarget(number: number, setUp: setUp, vent: nil, slot: free)
            }
        }
        return nil
    }

    /// The first candidate level won by its certified plan and the run, with a drag inside the view from a pod that
    /// picks (else from the moon) on its snapshot.
    static func wonTarget() throws -> (target: LevelTarget, drag: Drag)? {
        for number in candidateLevels {
            let actions: [Action] = try T.certifiedPlan(number) + [.run]
            guard let core: Core = try bare(number, actions), core.play.stage == .won else { continue }
            let snapshot: Snapshot = core.snapshot(time: 0)
            for slot in snapshot.pods.indices {
                guard let start: Vec2 = podPoint(slot, snapshot, orbit: .authored),
                      let end: Vec2 = anyDragEnd(from: start) else { continue }
                return (LevelTarget(number: number, setUp: actions, slot: slot), Drag(start: start, end: end))
            }
            if let start: Vec2 = moonPoint(snapshot, orbit: .authored), let end: Vec2 = anyDragEnd(from: start) {
                return (LevelTarget(number: number, setUp: actions, slot: -1), Drag(start: start, end: end))
            }
        }
        return nil
    }
}

@MainActor
@Suite(.serialized) struct MushroomWeatherGestureWiringTests {
    typealias Script = MushroomWeatherGestureScript
    typealias Core = MushroomWeatherExperienceCore
    typealias Snapshot = MushroomWeatherSceneSnapshot
    typealias Mirror = MushroomWeatherMirror
    typealias ViewOrbit = MushroomWeatherViewOrbit
    typealias Cell = MushroomWeatherCell
    typealias PreviewKind = MushroomWeatherPreviewKind
    typealias T = MushroomWeatherTest

    /// a. A tap on an empty site sends exactly one `pod.place` in the first free slot.
    @Test func aSiteTapPlacesAPod() async throws {
        let target = try #require(try Script.placeTarget(), "a free site and slot fit")
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
        let cell: Cell = snapshot.sites[site]
        let expected = Script.applied(ready, "pod.place", Script.placeValues(target.slot, cell))
        #expect(expected.result == .accepted)
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.tap(shell, id: 1, at: point, time: &time)
        let after: Core = try T.core(shell)
        #expect(after.play.arrangement.pods[target.slot] == cell, "the first free slot holds a pod on the site")
        #expect(after.play.actionsLeft == ready.play.actionsLeft - 1, "one action of the budget is spent")
        #expect(after.play == expected.core.play, "the kernel's verdict")
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "exactly one pod.place")
        #expect(sentAfter.rejected == sentBefore.rejected)
        #expect(try T.digest(shell) != digest)
        #expect(shell.presenter.refusalLog.isEmpty)
        try T.draw(session)
        #expect(try Script.drawn(shell).pods[target.slot] == cell, "the next frame draws the pod")
    }

    /// b, c. A drag from a placed pod previews (presentation only), then on release sends exactly one `pod.place` to
    /// the new site (`move`) or one `pod.remove` (dragged off the floor).
    func podDragChangesOnce(move: Bool) async throws {
        let target = try #require(try Script.dragTarget(move: move), "a pod drag fits (move \(move))")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let ready: Core = try T.core(shell)
        try #require(ready.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        try #require(snapshot.pods[target.slot] != nil)
        let drag: Script.Drag
        let control: String
        let values: [Double]
        let wanted: PreviewKind
        if move {
            let found = try #require(Script.moveDrag(snapshot, orbit: orbit, slot: target.slot), "a move drag fits")
            drag = found.drag
            control = "pod.place"
            values = Script.placeValues(target.slot, found.cell)
            wanted = .pod(slot: target.slot, target: found.cell)
        } else {
            drag = try #require(Script.removalDrag(snapshot, orbit: orbit, slot: target.slot), "a removal drag fits")
            control = "pod.remove"
            values = [Double(target.slot)]
            wanted = .pod(slot: target.slot, target: nil)
        }
        try #require(Script.pick(drag.start, snapshot, orbit: orbit) == .pod(target.slot))
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
        let preview: MushroomWeatherPreview = try #require(previewing.preview, "the drag is previewed")
        #expect(preview.kind == wanted)
        #expect(previewing.pods == ready.play.arrangement.pods, "the committed pods are still the snapshot's")
        #expect(try T.digest(shell) == digest)

        Script.touch(shell, id: 1, .ended, at: drag.end, time: &time)
        let after: Core = try T.core(shell)
        #expect(after.play == expected.core.play, "the kernel's verdict")
        #expect(after.play.actionsLeft == ready.play.actionsLeft - 1, "one action of the budget is spent")
        if move {
            if case .pod(_, let cell) = wanted {
                #expect(after.play.arrangement.pods[target.slot] == cell, "the pod moved to the site")
            }
        } else {
            #expect(after.play.arrangement.pods[target.slot] == nil, "the pod is removed")
        }
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "exactly one \(control)")
        #expect(sentAfter.rejected == sentBefore.rejected)
        #expect(try T.digest(shell) != digest)
        #expect(shell.presenter.refusalLog.isEmpty)
        try T.draw(session)
        let drawn: Snapshot = try Script.drawn(shell)
        #expect(drawn.preview == nil, "the release drops the preview")
        #expect(drawn.pods == after.play.arrangement.pods, "the next frame draws the changed pods")
    }

    /// b. A drag from a placed pod to another site moves it with one `pod.place`.
    @Test func aPodDragMovesThePod() async throws {
        try await podDragChangesOnce(move: true)
    }

    /// c. A drag from a placed pod off the floor removes it with one `pod.remove`.
    @Test func aPodDragOffTheFloorRemovesIt() async throws {
        try await podDragChangesOnce(move: false)
    }

    /// d. A tap on a vent sends exactly one `vent.set` with the other state.
    @Test func aVentTapTogglesTheVent() async throws {
        let target = try #require(try Script.ventTarget(), "a vent that picks fits")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let ready: Core = try T.core(shell)
        try #require(ready.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        let index: Int = target.slot
        let point: Vec2 = try #require(Script.ventPoint(index, snapshot, orbit: orbit), "the vent picks")
        try #require(Script.pick(point, snapshot, orbit: orbit) == .vent(index))
        let open: Bool = snapshot.ventsOpen[index]
        let expected = Script.applied(ready, "vent.set", Script.ventValues(index, open: !open))
        #expect(expected.result == .accepted)
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.tap(shell, id: 1, at: point, time: &time)
        let after: Core = try T.core(shell)
        #expect(after.play.arrangement.ventsOpen[index] == !open, "the vent changed to its other state")
        #expect(after.play.actionsLeft == ready.play.actionsLeft - 1, "one action of the budget is spent")
        #expect(after.play == expected.core.play, "the kernel's verdict")
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "exactly one vent.set")
        #expect(sentAfter.rejected == sentBefore.rejected)
        #expect(try T.digest(shell) != digest)
        #expect(shell.presenter.refusalLog.isEmpty)
        try T.draw(session)
        #expect(try Script.drawn(shell).ventsOpen[index] == !open, "the next frame draws the vent")
        #expect(try Script.drawn(shell).preview == nil, "a tap previews nothing")
    }

    /// e. A vertical drag from the moon previews the moonlight (presentation only) and on release sends exactly one
    /// `moon.set`.
    @Test func aMoonDragSetsTheMoonlight() async throws {
        let target = try #require(try Script.moonTarget(), "a moon drag fits")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let ready: Core = try T.core(shell)
        try #require(ready.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        let drag: Script.MoonDrag = try #require(Script.moonDrag(snapshot, orbit: orbit), "a moon drag fits")
        try #require(Script.pick(drag.start, snapshot, orbit: orbit) == .moon)
        let expected = Script.applied(ready, "moon.set", [Double(drag.level)])
        #expect(expected.result == .accepted)
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: drag.start, time: &time)
        Script.moves(shell, id: 1, from: drag.start, to: drag.end, time: &time)
        #expect(Script.sent(shell) == sentBefore, "nothing is sent before the release")
        #expect(try T.digest(shell) == digest, "a preview never changes the digest")
        try T.draw(session)
        let previewing: Snapshot = try Script.drawn(shell)
        let preview: MushroomWeatherPreview = try #require(previewing.preview, "the moon drag is previewed")
        #expect(preview.kind == .moonlight(level: drag.level))
        #expect(previewing.moonlight == ready.play.arrangement.moonlight, "the committed moonlight is unchanged")
        #expect(try T.digest(shell) == digest)

        Script.touch(shell, id: 1, .ended, at: drag.end, time: &time)
        let after: Core = try T.core(shell)
        #expect(after.play.arrangement.moonlight == drag.level, "the moonlight is the level under the finger")
        #expect(after.play.actionsLeft == ready.play.actionsLeft - 1, "one action of the budget is spent")
        #expect(after.play == expected.core.play, "the kernel's verdict")
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "exactly one moon.set")
        #expect(sentAfter.rejected == sentBefore.rejected)
        #expect(try T.digest(shell) != digest)
        #expect(shell.presenter.refusalLog.isEmpty)
        #expect(shell.presenter.mirror.chosenMoonlight == drag.level, "the panel's chosen level follows")
        try T.draw(session)
        let drawn: Snapshot = try Script.drawn(shell)
        #expect(drawn.preview == nil, "the release drops the preview")
        #expect(drawn.moonlight == drag.level, "the next frame draws the moonlight")
    }

    /// f. A drag along the scrubber shows the cycle under the finger; no action spent, no digest change.
    @Test func aScrubShowsTheCycle() async throws {
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
        #expect(try T.core(shell).shownCycle == scrub.to, "the shown cycle follows the finger")
        Script.touch(shell, id: 1, .ended, at: scrub.end, time: &time)
        let after: Core = try T.core(shell)
        #expect(after.shownCycle == scrub.to)
        #expect(after.shownCycle != before.shownCycle, "the shown cycle changed")
        #expect(after.play == before.play, "a scrub changes no kernel state")
        #expect(after.play.actionsLeft == before.play.actionsLeft, "no action is spent")
        #expect(Script.sent(shell).rejected == rejectedBefore)
        #expect(try T.digest(shell) == digest, "a shown cycle never changes the digest")
        #expect(shell.presenter.refusalLog.isEmpty)
        try T.draw(session)
        #expect(shell.presenter.mirror.shownCycle == scrub.to, "the panel follows the shown cycle")
        #expect(try Script.drawn(shell).shownCycle == scrub.to, "the drawn snapshot shows the cycle")
        #expect(try Script.drawn(shell).preview == nil, "a scrub previews nothing")
    }

    /// g. A two-finger drag orbits the camera and changes no digest; "Reset view" and a double tap on empty space
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
        #expect(Script.sent(shell) == sentBefore, "no kernel action and no cycle")
        #expect(try T.digest(shell) == digest)
        let after: Core = try T.core(shell)
        #expect(after.shownCycle == before.shownCycle)
        #expect(after.play == before.play)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// h. A gesture with no action left is sent and refused; the mirror shows the refusal in words and the bare code
    /// is logged.
    @Test func aRefusedChangeIsShown() async throws {
        let target = try #require(try Script.budgetTarget(), "a level whose budget can be spent, then a tap")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let spent: Core = try T.core(shell)
        try #require(spent.play.actionsLeft == 0, "the budget is spent")
        try #require(spent.play.stage == .playing)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        let point: Vec2
        let control: String
        let values: [Double]
        if let vent = target.vent {
            point = try #require(Script.ventPoint(vent, snapshot, orbit: orbit), "the vent picks")
            control = "vent.set"
            values = Script.ventValues(vent, open: !snapshot.ventsOpen[vent])
        } else {
            let site: Int = try #require(Script.freeSite(snapshot, orbit: orbit), "a free site picks")
            point = try #require(Script.sitePoint(site, snapshot, orbit: orbit))
            control = "pod.place"
            values = Script.placeValues(target.slot, snapshot.sites[site])
        }
        let expected = Script.applied(spent, control, values)
        #expect(expected.result.code.hasSuffix(Script.budgetCode), "\(expected.result.code)")
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.tap(shell, id: 1, at: point, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted, "nothing was accepted")
        #expect(sentAfter.rejected == sentBefore.rejected + 1, "the \(control) was sent and refused")
        let message: String = try #require(shell.presenter.mirror.message, "the refusal is shown")
        #expect(message.contains(Mirror.refusalText(code: Script.budgetCode)), "\(message)")
        #expect(message == Mirror.refusalMessage(code: Script.rulePrefix + Script.budgetCode), "\(message)")
        #expect(Mirror.refusalText(code: Script.rulePrefix + Script.budgetCode)
                    == Mirror.refusalText(code: Script.budgetCode), "codes are read with or without the prefix")
        #expect(shell.presenter.refusalLog.last == Script.budgetCode, "the bare code is logged")
        #expect(try T.core(shell).play == spent.play, "a refused change changes nothing")
        #expect(try T.digest(shell) == digest)
        try T.draw(session)
        #expect(try Script.drawn(shell).preview == nil)
    }

    /// i. On a won play a pod (or moon) drag sends nothing and the mirror says the play is over.
    @Test func aDragOnAWonPlaySendsNothing() async throws {
        let found = try #require(try Script.wonTarget(), "a won play with a pod or the moon inside the view")
        let target: Script.LevelTarget = found.target
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let won: Core = try T.core(shell)
        try #require(won.play.stage == .won, "level \(target.number) is won")
        let snapshot: Snapshot = try Script.drawn(shell)
        #expect(snapshot.stage == .won)
        let orbit: ViewOrbit = shell.presenter.orbit
        let start: Vec2 = found.drag.start
        let end: Vec2 = found.drag.end
        if target.slot >= 0 {
            try #require(Script.pick(start, snapshot, orbit: orbit) == .pod(target.slot))
        } else {
            try #require(Script.pick(start, snapshot, orbit: orbit) == .moon)
        }
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: start, time: &time)
        Script.moves(shell, id: 1, from: start, to: end, time: &time)
        #expect(shell.presenter.mirror.message == Script.finishedText, "the drag says the play is over")
        Script.touch(shell, id: 1, .ended, at: end, time: &time)
        #expect(shell.presenter.mirror.message == Script.finishedText)
        #expect(Script.sent(shell) == sentBefore, "a drag on a won play sends nothing")
        #expect(try T.digest(shell) == digest)
        #expect(try T.core(shell).play == won.play)
        #expect(shell.presenter.refusalLog.isEmpty, "nothing was sent, so nothing was refused")
        try T.draw(session)
        #expect(try Script.drawn(shell).preview == nil, "a won play previews nothing")
    }

    /// j. A tap on a pod selects its slot and explains the drag; a tap on the moon explains the moon drag; nothing is
    /// sent.
    @Test func aPodOrMoonTapExplains() async throws {
        let podTarget = try #require(try Script.dragTarget(move: false), "a placed pod picks")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, number: podTarget.number, setUp: podTarget.setUp)
        let before: Core = try T.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        let orbit: ViewOrbit = shell.presenter.orbit
        let point: Vec2 = try #require(Script.podPoint(podTarget.slot, snapshot, orbit: orbit), "the pod picks")
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.tap(shell, id: 1, at: point, time: &time)
        #expect(shell.presenter.mirror.message == Script.podTapText, "the tap says how to move a pod")
        #expect(shell.presenter.mirror.slot == podTarget.slot, "a tapped pod selects its slot")
        #expect(Script.sent(shell) == sentBefore, "a tap on a pod sends nothing")
        #expect(try T.digest(shell) == digest)
        #expect(try T.core(shell).play == before.play)

        if let moon: Vec2 = Script.moonPoint(snapshot, orbit: orbit) {
            time += Script.gesturePause
            Script.tap(shell, id: 2, at: moon, time: &time)
            #expect(shell.presenter.mirror.message == Script.moonTapText, "the tap says how to set the moonlight")
            #expect(Script.sent(shell) == sentBefore, "a tap on the moon sends nothing")
            #expect(try T.digest(shell) == digest)
        }
        try T.draw(session)
        #expect(try Script.drawn(shell).preview == nil, "a tap previews nothing")
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// j. A site tap with every slot used explains and sends nothing.
    @Test func aSiteTapWithEverySlotUsedExplains() async throws {
        let fullTarget = try #require(try Script.fullTarget(), "every slot can be filled with a site left")
        let session = ExperienceSession()
        defer { session.close() }
        let full = try await Script.open(session, number: fullTarget.number, setUp: fullTarget.setUp)
        let filled: Core = try T.core(full)
        let snapshot: Snapshot = try Script.drawn(full)
        #expect(Script.freeSlot(snapshot) == nil, "every slot holds a pod")
        let site: Int = try #require(Script.freeSite(snapshot, orbit: full.presenter.orbit), "a free site picks")
        let point: Vec2 = try #require(Script.sitePoint(site, snapshot, orbit: full.presenter.orbit))
        let digest: String = try T.digest(full)
        let sentBefore: Script.Sent = Script.sent(full)
        var time: Double = Script.start

        Script.tap(full, id: 1, at: point, time: &time)
        #expect(full.presenter.mirror.message == Script.slotsFullText, "the tap says every slot is used")
        #expect(Script.sent(full) == sentBefore, "a site tap with every slot used sends nothing")
        #expect(try T.digest(full) == digest)
        #expect(try T.core(full).play == filled.play)
        #expect(full.presenter.refusalLog.isEmpty)
    }
}
#endif
