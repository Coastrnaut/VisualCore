// MyceliumArchitectGestureWiringTests — feature 514 (R02-G22-04) T-R02G2204-006 (FR-R02G2204-001, 004, 005, 008, 009,
// 011 … 014; SC-R02G2204-001 … 003, 006; clarifications Q1–Q5). On the simulator, through the one app's session host:
// scripted touches go to the presenter's `pointer(_:viewSize:port:)` with the shell's own `port` at a 1,200 × 800-point
// view (aspect 1.5). Targets are projected through the drawn camera of the presenter's orbit
// (`MyceliumArchitectPicker.camera(viewSize:orbit:)` and `viewPoint` of `MyceliumArchitectSceneGeometry.centre`) on the
// presenter's `lastSnapshot`, and each is confirmed with `MyceliumArchitectPicker.pick` at the same view size before
// any touch. Levels are chosen at run time from bare opening cores (seed n − 1 opens level n); the kernel's verdict is
// the one a bare core gives for the same actions. Modelled on BinaryGardensGestureWiringTests (feature 504).
// Checked:
//   a. a site press reaches the controller (state `sitePress`), previews the tool's placement (the kernel's preview,
//      drawn, named in words, no digest change, nothing sent) and its release sends exactly one `cell.nutrient`
//      [column, row] with the kernel's verdict and drops the preview;
//   b. the "Blocker tool" button changes what a tap places (exactly one `cell.blocker`), and "Place at cursor" sends
//      exactly one placement by the tool on the panel's cursor cell; choosing a tool sends nothing;
//   c. a cell tap inspects the cell (drawn, described with the kernel's cell words), a second tap clears it, and the
//      panel's "Inspect cursor" and "Inspect: none" set and clear it; nothing is sent, the digest unchanged;
//   d. a two-finger orbit changes the drawn orbit (scene and snapshot) and never the digest; "Reset view" and a double
//      tap on empty space return to the authored view; nothing is sent;
//   e. a tap on the root explains the seed drag, and a tap on an empty site of a won play inspects it and explains
//      that the play is over; nothing is sent;
//   f. a refused panel action is shown in words and its bare code logged;
//   g. a new level and a reset return the tool, the inspection and the orbit to their defaults;
//   h. the gesture actions are the six canvas controls and the native actions every declared control.
// Explicit synthetic timestamps (no clock, no sleep, no wall-clock assertion). Explicit types and plain loops (CI
// type-check rule); no nested closure literals. Synthetic data only. Each test well under 10 s. Feature 515
// (R02-G22-05) T-R02G2205-004 (clarification Q5): g.'s `level.next` needs the next level open, so the level is first
// won through the presenter (its certified plan and the run; an unwon level opens nothing).
#if os(iOS)
import CoreGraphics
import Foundation
@testable import MyceliumArchitectCore
import Testing
@testable import MyceliumArchitectExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// Scripted touches on Mycelium Architect, placed through the drawn camera.
@MainActor
enum MyceliumArchitectGestureScript {
    typealias Shell = MyceliumArchitectTest.Shell
    typealias Snapshot = MyceliumArchitectSceneSnapshot
    typealias Geometry = MyceliumArchitectSceneGeometry
    typealias Core = MyceliumArchitectExperienceCore
    typealias Picker = MyceliumArchitectPicker
    typealias Pick = MyceliumArchitectPickTarget
    typealias ViewOrbit = MyceliumArchitectViewOrbit
    typealias Action = MyceliumArchitectAction
    typealias Cell = MyceliumArchitectCell
    typealias T = MyceliumArchitectTest

    /// The view's width in points (aspect 1.5).
    nonisolated static let viewWidth: Double = 1_200
    /// The view's height in points.
    nonisolated static let viewHeight: Double = 800
    /// The view size handed with every event.
    static var viewSize: Vec2 { Vec2(viewWidth, viewHeight) }
    /// The first synthetic timestamp, seconds (the controller only compares timestamps).
    nonisolated static let start: Double = 100
    /// The time between scripted events in seconds (synthetic).
    nonisolated static let frame: Double = 1.0 / 60
    /// The pause between the two taps of a double tap, seconds (inside the 0.35 s window).
    nonisolated static let tapGap: Double = 0.1
    /// The pause between two separate gestures, seconds (outside every double-tap window).
    nonisolated static let gesturePause: Double = 1
    /// How far inside the view a touch point must lie, points.
    nonisolated static let inset: Double = 8
    /// The radii in points around a projected centre at which a touch point is tried.
    nonisolated static let radii: [Double] = [0, 3, 6]
    /// The directions tried at each radius.
    nonisolated static let directions: Int = 8
    /// The grid step of the empty-space search, points.
    nonisolated static let gridStep: Double = 12
    /// The candidate levels; the first that fits is used.
    nonisolated static let candidateLevels: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
                                                     20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]
    /// The kernel's change-rule refusal code.
    nonisolated static let actionCode: String = "r02-g22.action"

    /// What the engine has counted so far: accepted and rejected actions.
    struct Sent: Equatable {
        /// The accepted actions.
        let accepted: Int
        /// The rejected actions.
        let rejected: Int
    }

    /// A level for the placement tests: two empty sites, the first tapped (accepting a nutrient and a blocker), the
    /// second placed at the cursor after a blocker on the first.
    struct PlacementTarget {
        /// The level number.
        let number: Int
        /// The tapped site.
        let site: Cell
        /// The tap point of the tapped site at the authored orbit.
        let point: Vec2
        /// The site placed at the cursor.
        let second: Cell
    }

    /// A level and a cell a tap inspects (a cell that is not an empty site or a placed item), with its tap point.
    struct CellTarget {
        /// The level number.
        let number: Int
        /// The actions issued before the gesture.
        let setUp: [Action]
        /// The cell.
        let cell: Cell
        /// The tap point at the authored orbit.
        let point: Vec2
    }

    /// Opens level `number` (seed `number − 1`) at the scripted view size, issues `setUp` and draws a frame so
    /// `lastSnapshot` is current.
    static func open(_ session: ExperienceSession, number: Int, setUp: [Action] = []) async throws -> Shell {
        let shell: Shell = try await T.open(session, seed: UInt64(number - 1), setUp: setUp,
                                            size: CGSize(width: viewWidth, height: viewHeight))
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

    /// A two-finger orbit with fingers `first` and `second` from `a` and `b`, both moving by `shift` in three steps,
    /// then lifting.
    static func orbit(_ shell: Shell, ids first: Int, _ second: Int, from a: Vec2, _ b: Vec2, by shift: Vec2,
                      time: inout Double) {
        touch(shell, id: first, .began, at: a, time: &time)
        touch(shell, id: second, .began, at: b, time: &time)
        for step in 1...3 {
            let t: Double = Double(step) / 3
            touch(shell, id: first, .moved, at: a + shift * t, time: &time)
            touch(shell, id: second, .moved, at: b + shift * t, time: &time)
        }
        touch(shell, id: first, .ended, at: a + shift, time: &time)
        touch(shell, id: second, .ended, at: b + shift, time: &time)
    }

    /// Whether `location` lies inside the view with a margin of ``inset`` points.
    static func inside(_ location: Vec2) -> Bool {
        location.x >= inset && location.x <= viewWidth - inset && location.y >= inset
            && location.y <= viewHeight - inset
    }

    /// What the picker gives for `location` on `snapshot` at `orbit`.
    static func pick(_ location: Vec2, _ snapshot: Snapshot, orbit: ViewOrbit) -> Pick {
        Picker.pick(location, viewSize: viewSize, snapshot: snapshot, orbit: orbit)
    }

    /// World `point` in view points through the drawn camera at `orbit`; nil when it does not project.
    static func project(_ point: SIMD3<Double>, orbit: ViewOrbit) -> Vec2? {
        guard let camera: MyceliumArchitectCamera = Picker.camera(viewSize: viewSize, orbit: orbit) else { return nil }
        return Picker.viewPoint(point, viewSize: viewSize, camera: camera)
    }

    /// The touch points tried about view point `c`: `c` itself, then rings of ``radii`` in ``directions`` directions,
    /// inside the view only.
    static func candidates(around c: Vec2) -> [Vec2] {
        var points: [Vec2] = []
        for radius in radii {
            let count: Int = radius == 0 ? 1 : directions
            for k in 0..<count {
                let a: Double = -Double.pi / 2 + Double(k) * 2 * Double.pi / Double(directions)
                let p: Vec2 = c + Vec2(cos(a), sin(a)) * radius
                if inside(p) { points.append(p) }
            }
        }
        return points
    }

    /// A point inside the view near world `centre` where the picker gives `wanted`; nil when none.
    static func point(near centre: SIMD3<Double>, _ snapshot: Snapshot, orbit: ViewOrbit, wanted: Pick) -> Vec2? {
        guard let c: Vec2 = project(centre, orbit: orbit) else { return nil }
        for p in candidates(around: c) where pick(p, snapshot, orbit: orbit) == wanted { return p }
        return nil
    }

    /// Cell `cell`'s centre in `snapshot`'s level.
    static func centre(_ cell: Cell, _ snapshot: Snapshot) -> SIMD3<Double> {
        Geometry.centre(cell, width: snapshot.level.width, height: snapshot.level.height, scale: snapshot.fitScale)
    }

    /// A point that picks cell `cell`; nil when none.
    static func cellPoint(_ cell: Cell, _ snapshot: Snapshot, orbit: ViewOrbit) -> Vec2? {
        point(near: centre(cell, snapshot), snapshot, orbit: orbit, wanted: .cell(cell))
    }

    /// A point that picks the root; nil when none.
    static func rootPoint(_ snapshot: Snapshot, orbit: ViewOrbit) -> Vec2? {
        point(near: centre(snapshot.level.root, snapshot), snapshot, orbit: orbit, wanted: .root)
    }

    /// A point on a grid of ``gridStep`` points that picks empty space, at least `minimum` points from `away` when
    /// given, scanned row by row from the top; nil when none.
    static func emptyPoint(_ snapshot: Snapshot, orbit: ViewOrbit, away: Vec2? = nil,
                           minimum: Double = 0) -> Vec2? {
        var y: Double = inset + gridStep
        while y <= viewHeight - inset {
            var x: Double = inset + gridStep
            while x <= viewWidth - inset {
                let p: Vec2 = Vec2(x, y)
                var far: Bool = true
                if let other = away { far = (p - other).length >= minimum }
                if far && pick(p, snapshot, orbit: orbit) == .empty { return p }
                x += gridStep
            }
            y += gridStep
        }
        return nil
    }

    /// Every cell of `snapshot`'s level, row by row.
    static func cells(_ snapshot: Snapshot) -> [Cell] {
        var all: [Cell] = []
        for row in 0..<snapshot.level.height {
            for column in 0..<snapshot.level.width { all.append(Cell(column: column, row: row)) }
        }
        return all
    }

    /// Whether `cell` is an empty site of `snapshot` (a tap places the tool's item there while playing).
    static func isEmptySite(_ cell: Cell, _ snapshot: Snapshot) -> Bool {
        snapshot.level.isSite(cell) && snapshot.level.isEmpty(cell, in: snapshot.arrangement)
    }

    /// Whether a tap on `cell` inspects in any stage: not the root, not an empty site, not a placed item.
    static func isInspectable(_ cell: Cell, _ snapshot: Snapshot) -> Bool {
        cell != snapshot.level.root && !isEmptySite(cell, snapshot)
            && !snapshot.arrangement.nutrients.contains(cell) && !snapshot.arrangement.blockers.contains(cell)
    }

    /// The core `before` after the kernel action `change`, and the adapter's answer.
    static func applied(_ before: Core, _ change: Action) -> (core: Core, result: ActionResult) {
        var copy: Core = before
        let result: ActionResult = copy.apply(T.experienceAction(change))
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

    /// The first candidate level, playing with two actions left, with an empty site that picks at the authored orbit
    /// and accepts both a nutrient and a blocker, and a second empty site that accepts a nutrient after a blocker on
    /// the first.
    static func placementTarget() throws -> PlacementTarget? {
        for number in candidateLevels {
            guard let core: Core = try bare(number, []), core.play.stage == .playing, core.play.actionsLeft >= 2 else {
                continue
            }
            let snapshot: Snapshot = core.snapshot(time: 0)
            for site in cells(snapshot) where isEmptySite(site, snapshot) {
                guard applied(core, .nutrient(site)).result == .accepted else { continue }
                let blocked: (core: Core, result: ActionResult) = applied(core, .blocker(site))
                guard blocked.result == .accepted, let point = cellPoint(site, snapshot, orbit: .authored) else {
                    continue
                }
                for second in cells(snapshot) where second != site && isEmptySite(second, snapshot) {
                    if applied(blocked.core, .nutrient(second)).result == .accepted {
                        return PlacementTarget(number: number, site: site, point: point, second: second)
                    }
                }
            }
        }
        return nil
    }

    /// The first candidate opening with a cell a tap inspects that picks at the authored orbit.
    static func inspectTarget() throws -> CellTarget? {
        for number in candidateLevels {
            guard let core: Core = try bare(number, []) else { continue }
            let snapshot: Snapshot = core.snapshot(time: 0)
            for cell in cells(snapshot) where isInspectable(cell, snapshot) {
                if let point = cellPoint(cell, snapshot, orbit: .authored) {
                    return CellTarget(number: number, setUp: [], cell: cell, point: point)
                }
            }
        }
        return nil
    }

    /// The first candidate level won by its certified plan and the run whose won snapshot has an empty site that
    /// picks at the authored orbit.
    static func wonTarget() throws -> CellTarget? {
        for number in candidateLevels {
            let setUp: [Action] = try T.certifiedPlan(number) + [.run]
            guard let core: Core = try bare(number, setUp), core.play.stage == .won else { continue }
            let snapshot: Snapshot = core.snapshot(time: 0)
            for cell in cells(snapshot) where isEmptySite(cell, snapshot) {
                if let point = cellPoint(cell, snapshot, orbit: .authored) {
                    return CellTarget(number: number, setUp: setUp, cell: cell, point: point)
                }
            }
        }
        return nil
    }
}

@MainActor
@Suite(.serialized) struct MyceliumArchitectGestureWiringTests {
    typealias Script = MyceliumArchitectGestureScript
    typealias Core = MyceliumArchitectExperienceCore
    typealias Snapshot = MyceliumArchitectSceneSnapshot
    typealias Mirror = MyceliumArchitectMirror
    typealias ViewOrbit = MyceliumArchitectViewOrbit
    typealias Action = MyceliumArchitectAction
    typealias Controller = MyceliumArchitectGestureController
    typealias T = MyceliumArchitectTest

    /// a. A site press previews the tool's placement and its release sends exactly one `cell.nutrient`.
    @Test func aSiteTapPreviewsAndPlacesOnce() async throws {
        let target: Script.PlacementTarget = try #require(try Script.placementTarget(), "an empty site that picks")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Script.open(session, number: target.number)
        let ready: Core = try T.core(shell)
        try #require(ready.play.stage == .playing)
        #expect(shell.presenter.orbit == .authored)
        #expect(shell.presenter.tool == .nutrient, "nutrient at an opening")
        let snapshot: Snapshot = try Script.drawn(shell)
        try #require(Script.pick(target.point, snapshot, orbit: .authored) == .cell(target.site))
        let change: Action = .nutrient(target.site)
        let expected: (core: Core, result: ActionResult) = Script.applied(ready, change)
        #expect(expected.result == .accepted)
        let wanted: MyceliumArchitectPreview = MyceliumArchitectPreview.of(
            change, level: ready.play.level, arrangement: ready.play.arrangement, stage: ready.play.stage,
            actionsLeft: ready.play.actionsLeft)
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.touch(shell, id: 1, .began, at: target.point, time: &time)
        #expect(shell.presenter.gestureState == .sitePress, "the touch reached the controller")
        #expect(shell.presenter.previewChange == change, "the press previews the tool's placement")
        #expect(Script.sent(shell) == sentBefore, "nothing is sent before the release")
        #expect(try T.digest(shell) == digest, "a preview never changes the digest")
        #expect(try T.core(shell).play == ready.play)
        #expect(shell.presenter.mirror.previewLabel == Mirror.previewText(wanted, level: ready.play.level))
        try T.draw(session)
        let previewing: Snapshot = try Script.drawn(shell)
        let preview: MyceliumArchitectPreview = try #require(previewing.preview, "the press is previewed")
        #expect(preview == wanted, "the preview is the kernel's")
        #expect(previewing.arrangement == ready.play.arrangement, "the committed arrangement is still drawn")
        #expect(try T.digest(shell) == digest)

        Script.touch(shell, id: 1, .ended, at: target.point, time: &time)
        let after: Core = try T.core(shell)
        #expect(after.play == expected.core.play, "the kernel's verdict")
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "exactly one cell.nutrient")
        #expect(sentAfter.rejected == sentBefore.rejected)
        #expect(try T.digest(shell) != digest)
        #expect(shell.presenter.previewChange == nil, "the release drops the preview")
        #expect(shell.presenter.gestureState == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
        try T.draw(session)
        let drawn: Snapshot = try Script.drawn(shell)
        #expect(drawn.preview == nil, "the next frame draws no preview")
        #expect(drawn.arrangement.nutrients.contains(target.site), "the next frame draws the nutrient")
        #expect(shell.presenter.fallbackReason == nil)
    }

    /// b. The Blocker tool changes what a tap places; "Place at cursor" places the tool's item on the cursor's cell.
    @Test func aToolButtonChangesWhatATapPlaces() async throws {
        let target: Script.PlacementTarget = try #require(try Script.placementTarget(), "an empty site that picks")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Script.open(session, number: target.number)
        let ready: Core = try T.core(shell)
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)

        shell.presenter.chooseTool(.blocker)
        #expect(shell.presenter.tool == .blocker)
        #expect(shell.presenter.mirror.tool == .blocker, "the panel shows the tool")
        #expect(Script.sent(shell) == sentBefore, "choosing a tool sends nothing")
        #expect(try T.digest(shell) == digest, "the tool never changes the digest")
        try T.draw(session)
        #expect(try Script.drawn(shell).tool == .blocker, "the drawn snapshot carries the tool")

        var time: Double = Script.start
        Script.touch(shell, id: 1, .began, at: target.point, time: &time)
        #expect(shell.presenter.previewChange == .blocker(target.site), "the press previews a blocker")
        Script.touch(shell, id: 1, .ended, at: target.point, time: &time)
        let placed: Core = try T.core(shell)
        #expect(placed.play == Script.applied(ready, .blocker(target.site)).core.play, "the kernel's verdict")
        #expect(placed.play.arrangement.blockers.contains(target.site), "the tap placed a blocker")
        #expect(!placed.play.arrangement.nutrients.contains(target.site))
        #expect(Script.sent(shell).accepted == sentBefore.accepted + 1, "exactly one cell.blocker")
        #expect(Script.sent(shell).rejected == sentBefore.rejected)

        shell.presenter.chooseTool(.nutrient)
        shell.presenter.mirror.column = target.second.column
        shell.presenter.mirror.row = target.second.row
        #expect(shell.presenter.mirror.cursor == target.second)
        let result: ActionResult = shell.presenter.placeAtCursor(port: shell.port)
        #expect(result == .accepted, "\(result.code)")
        let after: Core = try T.core(shell)
        #expect(after.play == Script.applied(placed, .nutrient(target.second)).core.play)
        #expect(after.play.arrangement.nutrients.contains(target.second), "Place at cursor placed a nutrient")
        #expect(Script.sent(shell).accepted == sentBefore.accepted + 2, "exactly one more action")
        #expect(Script.sent(shell).rejected == sentBefore.rejected)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// c. A cell tap inspects and a second tap clears; "Inspect cursor" and "Inspect: none" do the same from the panel.
    @Test func aCellTapInspectsAndInspectNoneClears() async throws {
        let target: Script.CellTarget = try #require(try Script.inspectTarget(), "a cell a tap inspects")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Script.open(session, number: target.number, setUp: target.setUp)
        let before: Core = try T.core(shell)
        let snapshot: Snapshot = try Script.drawn(shell)
        try #require(Script.pick(target.point, snapshot, orbit: .authored) == .cell(target.cell))
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.tap(shell, id: 1, at: target.point, time: &time)
        #expect(shell.presenter.inspectedCell == target.cell, "the tap inspects the cell")
        #expect(Script.sent(shell) == sentBefore, "an inspection sends nothing")
        #expect(try T.digest(shell) == digest, "an inspection never changes the digest")
        try T.draw(session)
        #expect(try Script.drawn(shell).inspectedCell == target.cell, "the drawn snapshot rings the cell")
        let words: String = before.play.level.cellDescription(target.cell, arrangement: before.play.arrangement,
                                                              report: before.play.report)
        #expect(shell.presenter.mirror.inspectedLabel == words)
        let text: String = shell.presenter.describe(try T.core(shell))
        #expect(text.contains("Inspected " + words), "\(text)")

        time += Script.gesturePause
        Script.tap(shell, id: 2, at: target.point, time: &time)
        #expect(shell.presenter.inspectedCell == nil, "a second tap clears the inspection")
        try T.draw(session)
        #expect(try Script.drawn(shell).inspectedCell == nil)
        #expect(!shell.presenter.describe(try T.core(shell)).contains("Inspected "))

        shell.presenter.mirror.column = target.cell.column
        shell.presenter.mirror.row = target.cell.row
        shell.presenter.inspect(shell.presenter.mirror.cursor)
        #expect(shell.presenter.inspectedCell == target.cell, "Inspect cursor inspects the cursor's cell")
        try T.draw(session)
        #expect(try Script.drawn(shell).inspectedCell == target.cell)
        shell.presenter.inspect(nil)
        #expect(shell.presenter.inspectedCell == nil, "Inspect: none clears the inspection")
        #expect(shell.presenter.mirror.inspectedLabel == nil)
        try T.draw(session)
        #expect(try Script.drawn(shell).inspectedCell == nil)
        #expect(Script.sent(shell) == sentBefore)
        #expect(try T.digest(shell) == digest)
        #expect(try T.core(shell).play == before.play)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// d. A two-finger drag orbits the drawn camera and changes no digest; "Reset view" and a double tap on empty space
    /// return to the authored view.
    @Test func anOrbitChangesTheViewButNotTheDigest() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Script.open(session, number: Script.candidateLevels[0])
        let before: Core = try T.core(shell)
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        #expect(shell.presenter.orbit == .authored)
        let snapshot: Snapshot = try Script.drawn(shell)
        let first: Vec2 = try #require(Script.emptyPoint(snapshot, orbit: .authored), "empty space picks")
        let second: Vec2 = try #require(Script.emptyPoint(snapshot, orbit: .authored, away: first, minimum: 200),
                                        "a second empty point picks")
        let shift: Vec2 = Vec2(100, 0)
        var time: Double = Script.start

        Script.orbit(shell, ids: 1, 2, from: first, second, by: shift, time: &time)
        let orbit: ViewOrbit = shell.presenter.orbit
        #expect(orbit != .authored, "two fingers orbit the camera")
        #expect(orbit == orbit.clamped(), "the orbit stays within its bounds")
        #expect(shell.presenter.gestureState == .idle, "every finger lifted")
        #expect(shell.presenter.mirror.orbited)
        #expect(Script.sent(shell) == sentBefore, "an orbit sends nothing")
        #expect(try T.digest(shell) == digest, "an orbit never changes the digest")
        try T.draw(session)
        #expect(shell.presenter.scene.orbit == orbit, "the scene draws the orbit")
        #expect(try Script.drawn(shell).orbit == orbit, "the drawn snapshot carries the orbit")
        #expect(shell.presenter.fallbackReason == nil, "\(shell.presenter.fallbackReason ?? "")")
        #expect(try T.digest(shell) == digest)

        shell.presenter.resetView()
        #expect(shell.presenter.orbit == .authored, "Reset view restores the authored view")
        #expect(!shell.presenter.mirror.orbited)
        #expect(Script.sent(shell) == sentBefore, "Reset view sends nothing")
        try T.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)
        #expect(try T.digest(shell) == digest)

        time += Script.gesturePause
        Script.orbit(shell, ids: 3, 4, from: first, second, by: shift, time: &time)
        let turned: ViewOrbit = shell.presenter.orbit
        #expect(turned != .authored)
        try T.draw(session)
        let drawn: Snapshot = try Script.drawn(shell)
        let empty: Vec2 = try #require(Script.emptyPoint(drawn, orbit: turned), "empty space picks at the orbit")
        time += Script.gesturePause
        Script.tap(shell, id: 5, at: empty, time: &time)
        #expect(shell.presenter.orbit == turned, "a single tap on empty space keeps the orbit")
        time += Script.tapGap
        Script.tap(shell, id: 6, at: empty, time: &time)
        #expect(shell.presenter.orbit == .authored, "a double tap on empty space resets the view")
        try T.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)
        #expect(try Script.drawn(shell).orbit == .authored)
        #expect(Script.sent(shell) == sentBefore, "no kernel action and no pulse")
        #expect(try T.digest(shell) == digest)
        let after: Core = try T.core(shell)
        #expect(after.shownPulse == before.shownPulse)
        #expect(after.play == before.play)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// e. A root tap explains the seed drag; nothing is sent.
    @Test func aRootTapExplains() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Script.open(session, number: Script.candidateLevels[0])
        let snapshot: Snapshot = try Script.drawn(shell)
        let root: Vec2 = try #require(Script.rootPoint(snapshot, orbit: .authored), "the root picks")
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start

        Script.tap(shell, id: 1, at: root, time: &time)
        #expect(shell.presenter.mirror.message == Controller.rootReason, "the root tap explains the seed drag")
        #expect(shell.presenter.describe(try T.core(shell)).contains(Controller.rootReason))
        #expect(Script.sent(shell) == sentBefore, "a root tap sends nothing")
        #expect(try T.digest(shell) == digest)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// e2. A tap on an empty site of a won play inspects it and explains that the play is over; nothing is sent.
    @Test func aSiteTapOnAWonPlayExplains() async throws {
        let won: Script.CellTarget = try #require(try Script.wonTarget(), "a won level with an empty site")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Script.open(session, number: won.number, setUp: won.setUp)
        try #require(try T.core(shell).play.stage == .won)
        try #require(Script.pick(won.point, try Script.drawn(shell), orbit: .authored) == .cell(won.cell))
        let digest: String = try T.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = Script.start
        Script.tap(shell, id: 1, at: won.point, time: &time)
        #expect(shell.presenter.mirror.message == Controller.finishedReason, "the play is over")
        #expect(shell.presenter.describe(try T.core(shell)).contains(Controller.finishedReason))
        #expect(shell.presenter.inspectedCell == won.cell, "a tap outside playing inspects")
        #expect(shell.presenter.previewChange == nil, "nothing is previewed outside playing")
        #expect(Script.sent(shell) == sentBefore, "nothing is sent outside playing")
        #expect(try T.digest(shell) == digest)
    }

    /// f. A refused panel action is shown in words and its bare code is logged.
    @Test func aRefusedActionIsShownAndLogged() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Script.open(session, number: Script.candidateLevels[0])
        let digest: String = try T.digest(shell)
        let root: MyceliumArchitectCell = try T.core(shell).play.level.root
        let result: ActionResult = shell.presenter.send("cell.clear", [Double(root.column), Double(root.row)],
                                                        port: shell.port)
        #expect(!result.isAccepted, "nothing to clear on the root")
        #expect(result.code.hasSuffix(Script.actionCode), "\(result.code)")
        #expect(shell.presenter.refusalLog == [Script.actionCode], "the bare code is logged once")
        #expect(shell.presenter.mirror.message == Mirror.refusalMessage(code: result.code))
        #expect(try T.digest(shell) == digest)
    }

    /// g. A new level and a reset return the tool, the inspection and the orbit to their defaults.
    @Test func aNewPlayClearsThePresentation() async throws {
        let target: Script.CellTarget = try #require(try Script.inspectTarget(), "a cell a tap inspects")
        let session = ExperienceSession()
        defer { session.close() }
        let shell: Script.Shell = try await Script.open(session, number: target.number)
        let snapshot: Snapshot = try Script.drawn(shell)
        let first: Vec2 = try #require(Script.emptyPoint(snapshot, orbit: .authored), "empty space picks")
        let second: Vec2 = try #require(Script.emptyPoint(snapshot, orbit: .authored, away: first, minimum: 200),
                                        "a second empty point picks")
        var time: Double = Script.start
        shell.presenter.chooseTool(.blocker)
        shell.presenter.inspect(target.cell)
        Script.orbit(shell, ids: 1, 2, from: first, second, by: Vec2(100, 0), time: &time)
        try T.draw(session)
        #expect(shell.presenter.tool == .blocker)
        #expect(shell.presenter.inspectedCell == target.cell)
        #expect(shell.presenter.orbit != .authored)

        // Feature 515: `level.next` needs the next level open, so the level is first won (certified plan, then run).
        let winning: [Action] = try T.certifiedPlan(target.number) + [.run]
        for action in winning {
            let issued: (control: String, values: [Double]) = T.control(action)
            let result: ActionResult = shell.presenter.send(issued.control, issued.values, port: shell.port)
            #expect(result == .accepted, "\(issued.control): \(result.code)")
        }
        #expect(try T.core(shell).play.stage == .won)
        let next: ActionResult = shell.presenter.send("level.next", [], port: shell.port)
        #expect(next == .accepted, "\(next.code)")
        #expect(try T.core(shell).levelNumber != target.number)
        #expect(shell.presenter.tool == .nutrient, "the next level returns the tool to nutrient")
        #expect(shell.presenter.inspectedCell == nil, "the next level clears the inspection")
        #expect(shell.presenter.previewChange == nil)
        #expect(shell.presenter.orbit == .authored, "the next level returns the camera to the authored view")
        try T.draw(session)
        #expect(try Script.drawn(shell).inspectedCell == nil)
        #expect(try Script.drawn(shell).orbit == .authored)
        #expect(shell.presenter.scene.orbit == .authored)

        shell.presenter.chooseTool(.blocker)
        shell.presenter.inspect(MyceliumArchitectCell(column: 0, row: 0))
        try shell.reset()
        #expect(try T.core(shell).levelNumber == target.number, "a reset returns to the opening level")
        #expect(shell.presenter.tool == .nutrient, "a reset returns the tool to nutrient")
        #expect(shell.presenter.inspectedCell == nil, "a reset clears the inspection")
        #expect(shell.presenter.orbit == .authored)
        try T.draw(session)
        #expect(try Script.drawn(shell).inspectedCell == nil)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// h. The canvas gestures send the six canvas controls; the native controls every declared control.
    @Test func theGestureAndNativeActionSets() {
        let presenter: MyceliumArchitectPresenter = MyceliumArchitectPresenter(reduceMotion: false,
                                                                               reduceFlashing: false)
        let gestures: Set<String> = ["cell.nutrient", "cell.blocker", "cell.clear", "root.seed", "root.unseed",
                                     "growth.show"]
        #expect(presenter.gestureActions == gestures)
        #expect(presenter.nativeActions == Set(Core.actionIDs))
        #expect(presenter.gestureActions.isSubset(of: presenter.nativeActions), "the panel can do what a gesture can")
        #expect(presenter.orbit == .authored)
        #expect(presenter.gestureState == .idle)
        #expect(presenter.tool == .nutrient)
        #expect(presenter.previewChange == nil && presenter.inspectedCell == nil)
        #expect(presenter.refusalLog.isEmpty)
        #expect(MyceliumArchitectPresenter.refusalLogLimit == 64)
        #expect(MyceliumArchitectControls.identifierNames.contains("tool-nutrient"))
        #expect(MyceliumArchitectControls.identifierNames.contains("tool-blocker"))
        #expect(MyceliumArchitectControls.identifierNames.contains("place"))
        #expect(MyceliumArchitectControls.identifierNames.contains("inspect-none"))
        #expect(MyceliumArchitectControls.identifierNames.contains("reset-view"))
    }
}
#endif
