// NocturneGardenGestureWiringTests — feature 384 (R02-G09-04) T-R02G0904-006 (FR-R02G0904-001 … 005, 007;
// SC-R02G0904-001 … 004; clarifications Q1–Q4). On the simulator, through the one app's session host: scripted touches
// go to the presenter's `pointer(_:viewSize:port:)` with the shell's own `port` at a 720 × 480-point view (aspect 1.5).
// Targets are world points (a bed cell's centre on z = 0, a bloom's head centre or foot on the head plane, the lantern)
// projected through the camera the presenter's controller draws with (`gestures.camera(viewSize:snapshot:)`, the
// controller's orbit) into view points (origin top left) and confirmed with `NocturneGardenPicker.pick` and
// `NocturneGardenPicker.bedCell` on the presenter's `lastSnapshot`. What the port sent is read from the shell's engine
// (accepted and rejected action counters) and the core, compared with a bare core that applied the expected action.
// Checked:
//   1. a tap on an empty bed cell of level 1 plants the mirror's kind and size at that cell (one bloom with that
//      anchor; the digest changes);
//   2. dragging a planted bloom by its head to another cell moves it by the cell difference; during the drag the
//      controller holds a preview equal to the kernel's mask of the moved arrangement (`NocturneGardenMask.union` on a
//      copy), the mirror's preview text is set after a drawn frame, nothing is sent and the digest is unchanged;
//   3. dragging a bloom to a point whose ray meets z = 0 outside the bed removes it (a removal preview first);
//   4. a 48-point downward drag on the lantern sets the next allowed (lower) sun;
//   5. a two-finger pinch on a size-1 bloom with scale 1.6, on a level allowing sizes 1 … 3, resizes it to 2;
//   6. a two-finger drag orbits within the orbit's bounds and changes no digest; a double tap on empty space and
//      `resetView()` return to `.authored`;
//   7. on a won play (level 1's certified solution sent through the port) a tap on a bed cell sends nothing and the
//      mirror shows `NocturneGardenPresenter.finishedMessage`;
//   8. a refused gesture plant (a kind the level does not supply) is shown in the mirror and logged in `refusalLog`
//      with its reason code `r02-g09.supply`; the gesture actions are native actions.
// Synthetic timestamps; no sleep, no wall-clock assertion; few frames. Explicit types and plain loops (CI type-check
// rule).
#if os(iOS)
import CoreGraphics
import Foundation
import NocturneGardenCore
import Testing
@testable import NocturneGardenExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes

/// Scripted touches on Nocturne Garden, placed through the drawn camera.
@MainActor
enum NocturneGardenGestureScript {
    typealias Shell = ExperienceShell<NocturneGardenPresenter>
    typealias Snapshot = NocturneGardenSceneSnapshot
    typealias Geometry = NocturneGardenSceneGeometry
    typealias Core = NocturneGardenExperienceCore
    typealias Picker = NocturneGardenPicker
    typealias Controller = NocturneGardenGestureController
    typealias Cell = (column: Int, row: Int, inside: Bool)

    /// The view's size in points (aspect 1.5).
    static let viewWidth: Double = 720
    static let viewHeight: Double = 480
    /// The view size handed with every event.
    static var viewSize: Vec2 { Vec2(viewWidth, viewHeight) }
    /// The view size as the picker takes it.
    static var size: SIMD2<Double> { SIMD2<Double>(viewWidth, viewHeight) }
    /// The time between scripted events in seconds (synthetic).
    static let frame: Double = 1.0 / 60
    /// The moves of a scripted drag.
    static let dragMoves: Int = 6
    /// The cell offsets tried for a bloom move, larger first.
    static let moveDeltas: [(Int, Int)] = [(3, 0), (-3, 0), (0, 3), (0, -3), (2, 0), (-2, 0), (0, 2), (0, -2),
                                           (2, 2), (-2, -2), (4, 0), (-4, 0), (0, 4), (0, -4)]
    /// The unit directions tried for a pinch's second finger.
    static let pinchDirections: [Vec2] = [Vec2(1, 0), Vec2(-1, 0), Vec2(0, 1), Vec2(0, -1)]
    /// The pinch's finger distance at its start, points, and the scale it ends at.
    static let pinchBase: Double = 80
    static let pinchScale: Double = 1.6
    /// The grid step in points of the searches over the view.
    static let gridStep: Double = 12

    /// What the engine has counted so far: accepted and rejected actions.
    struct Sent: Equatable {
        let accepted: Int
        let rejected: Int
    }

    /// Opens level `seed % 100 + 1` at the scripted view size (one frame drawn).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0) async throws -> Shell {
        try await NocturneGardenTest.open(session, seed: seed, size: CGSize(width: viewWidth, height: viewHeight))
    }

    /// The engine's action counters of `shell`.
    static func sent(_ shell: Shell) -> Sent {
        Sent(accepted: shell.engine.acceptedActions, rejected: shell.engine.rejectedActions)
    }

    /// The snapshot the presenter drew last (the gestures read it).
    static func drawn(_ shell: Shell) throws -> Snapshot {
        try #require(shell.presenter.lastSnapshot)
    }

    /// The play the presenter drew last.
    static func drawnPlay(_ shell: Shell) throws -> NocturneGardenPlay {
        try #require(shell.presenter.lastPlay)
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

    /// The down and ``dragMoves`` equal moves of a one-finger drag with finger `id` from `start` to `end`, not lifted.
    static func press(_ shell: Shell, id: Int, from start: Vec2, to end: Vec2, time: inout Double) {
        touch(shell, id: id, .began, at: start, time: &time)
        let drag: Vec2 = end - start
        for step in 1...dragMoves {
            let t: Double = Double(step) / Double(dragMoves)
            touch(shell, id: id, .moved, at: start + drag * t, time: &time)
        }
    }

    /// A two-finger orbit: fingers `id` and `id + 1` down near the left corners, both moved `shift` points right and
    /// lifted.
    static func orbit(_ shell: Shell, id: Int, shift: Double = 100, time: inout Double) {
        let first: Vec2 = Vec2(8, 8)
        let second: Vec2 = Vec2(8, viewHeight - 8)
        touch(shell, id: id, .began, at: first, time: &time)
        touch(shell, id: id + 1, .began, at: second, time: &time)
        touch(shell, id: id, .moved, at: Vec2(first.x + shift, first.y), time: &time)
        touch(shell, id: id + 1, .moved, at: Vec2(second.x + shift, second.y), time: &time)
        touch(shell, id: id, .ended, at: Vec2(first.x + shift, first.y), time: &time)
        touch(shell, id: id + 1, .ended, at: Vec2(second.x + shift, second.y), time: &time)
    }

    /// `world` projected into view points (origin top left) through the controller's camera for `snapshot` at its
    /// current orbit; nil behind the camera.
    static func viewPoint(_ shell: Shell, _ world: SIMD3<Double>, _ snapshot: Snapshot) -> Vec2? {
        guard let camera: NocturneGardenCamera = shell.presenter.gestures.camera(viewSize: viewSize,
                                                                                 snapshot: snapshot),
              let unit: SIMD2<Double> = Geometry.project(world, camera: camera) else { return nil }
        return Vec2(unit.x * viewWidth, unit.y * viewHeight)
    }

    /// What the picker gives for `location` on `snapshot` at the controller's orbit.
    static func pick(_ shell: Shell, _ location: Vec2, _ snapshot: Snapshot) -> NocturneGardenPick {
        Picker.pick(SIMD2<Double>(location.x, location.y), size: size, snapshot: snapshot,
                    orbit: shell.presenter.gestures.orbit)
    }

    /// The bed cell under `location` on `snapshot` at the controller's orbit.
    static func bedCell(_ shell: Shell, _ location: Vec2, _ snapshot: Snapshot) -> Cell? {
        Picker.bedCell(SIMD2<Double>(location.x, location.y), size: size, snapshot: snapshot,
                       orbit: shell.presenter.gestures.orbit)
    }

    /// Whether `location` lies inside the view with a margin of `inset` points.
    static func inside(_ location: Vec2, inset: Double = 0) -> Bool {
        location.x >= inset && location.x <= viewWidth - inset && location.y >= inset
            && location.y <= viewHeight - inset
    }

    /// The centre on z = 0 of the cell (`column`, `row`) of `snapshot`'s bed grid, also for a cell outside the bed.
    static func cellWorld(column: Int, row: Int, _ snapshot: Snapshot) -> SIMD3<Double> {
        let u: Double = Geometry.cellSize(snapshot)
        return SIMD3<Double>(-Geometry.bedHalfWidth + (Double(column) + 0.5) * u, (Double(row) + 0.5) * u, 0)
    }

    /// The cells of a `width` × `height` bed ordered by distance from the bed's middle (ties by index).
    static func cellsFromCentre(width: Int, height: Int) -> [Int] {
        var keyed: [(key: Double, cell: Int)] = []
        let cx: Double = Double(width - 1) / 2
        let cy: Double = Double(height - 1) / 2
        for row in 0..<height {
            for column in 0..<width {
                let dx: Double = Double(column) - cx
                let dy: Double = Double(row) - cy
                keyed.append((key: dx * dx + dy * dy, cell: row * width + column))
            }
        }
        keyed.sort { (a: (key: Double, cell: Int), b: (key: Double, cell: Int)) -> Bool in
            a.key != b.key ? a.key < b.key : a.cell < b.cell
        }
        var cells: [Int] = []
        for entry in keyed { cells.append(entry.cell) }
        return cells
    }

    /// The projected centre of bed cell `cell` of the drawn snapshot when it lies 2 points inside the view and picks
    /// that cell; nil otherwise.
    static func cellPoint(_ shell: Shell, cell: Int) throws -> Vec2? {
        let snapshot: Snapshot = try drawn(shell)
        let width: Int = Swift.max(snapshot.width, 1)
        let world: SIMD3<Double> = cellWorld(column: cell % width, row: cell / width, snapshot)
        guard let point: Vec2 = viewPoint(shell, world, snapshot), inside(point, inset: 2) else { return nil }
        return pick(shell, point, snapshot) == .cell(cell) ? point : nil
    }

    /// The first bed cell of the drawn snapshot, nearest the bed's middle first, whose centre picks it and that
    /// `accept` takes; nil when none does.
    static func bedTarget(_ shell: Shell, where accept: (Int) -> Bool) throws -> (cell: Int, point: Vec2)? {
        let snapshot: Snapshot = try drawn(shell)
        for cell in cellsFromCentre(width: snapshot.width, height: snapshot.height) where accept(cell) {
            if let point: Vec2 = try cellPoint(shell, cell: cell) { return (cell, point) }
        }
        return nil
    }

    /// A point that picks bloom `bloom` of the drawn snapshot and whose ray meets z = 0 (so a drag has a grab cell):
    /// the projected head centre (the mean of the head outline's vertices on the head plane), the projected foot on the
    /// head plane, then the projected anchor cell centre; nil when none does.
    static func bloomPoint(_ shell: Shell, bloom: Int) throws -> Vec2? {
        let snapshot: Snapshot = try drawn(shell)
        guard snapshot.blooms.indices.contains(bloom) else { return nil }
        let b: NocturneGardenBloom = snapshot.blooms[bloom]
        let u: Double = Geometry.cellSize(snapshot)
        let z: Double = Geometry.bloomZ + Geometry.headDepth / 2
        let foot: SIMD2<Double> = SIMD2<Double>(-Geometry.bedHalfWidth + Double(b.column) * u, Double(b.row) * u)
        let scale: Double = Double(Swift.min(Swift.max(b.size, 1), 3)) * u * Geometry.headScale
        var mean: SIMD2<Double> = SIMD2<Double>(0, 0)
        var count: Int = 0
        for p in b.kind.outline {
            mean += SIMD2<Double>(Double(p.x), Double(p.y))
            count += 1
        }
        if count > 0 { mean /= Double(count) }
        let head: SIMD2<Double> = foot + mean * scale
        let worlds: [SIMD3<Double>] = [SIMD3<Double>(head.x, head.y, z), SIMD3<Double>(foot.x, foot.y, z),
                                       cellWorld(column: b.column, row: b.row, snapshot)]
        for world in worlds {
            guard let point: Vec2 = viewPoint(shell, world, snapshot), inside(point, inset: 2) else { continue }
            if pick(shell, point, snapshot) == .bloom(bloom), bedCell(shell, point, snapshot) != nil { return point }
        }
        return nil
    }

    /// The projected lantern of the drawn snapshot when it lies inside the view and picks the lantern; nil otherwise.
    static func lanternPoint(_ shell: Shell) throws -> Vec2? {
        let snapshot: Snapshot = try drawn(shell)
        guard let point: Vec2 = viewPoint(shell, Geometry.lantern(snapshot), snapshot), inside(point, inset: 2) else {
            return nil
        }
        return pick(shell, point, snapshot) == .lantern ? point : nil
    }

    /// A point of empty space (the picker gives `.outside` or `.empty`) at least 8 points inside the view: the four
    /// corners first, then a grid; nil when none.
    static func emptyPoint(_ shell: Shell) throws -> Vec2? {
        let snapshot: Snapshot = try drawn(shell)
        var points: [Vec2] = [Vec2(8, 8), Vec2(viewWidth - 8, 8), Vec2(8, viewHeight - 8),
                              Vec2(viewWidth - 8, viewHeight - 8)]
        var y: Double = 8
        while y <= viewHeight - 8 {
            var x: Double = 8
            while x <= viewWidth - 8 {
                points.append(Vec2(x, y))
                x += gridStep
            }
            y += gridStep
        }
        for point in points {
            let picked: NocturneGardenPick = pick(shell, point, snapshot)
            if picked == .outside || picked == .empty { return point }
        }
        return nil
    }

    /// A point at least 2 points inside the view, at least `away` points from `start`, whose ray meets z = 0 outside
    /// the bed of the drawn snapshot: left of the bed (column < 0) first, scanning from the left edge; then any off-bed
    /// point; nil when none.
    static func offBedPoint(_ shell: Shell, from start: Vec2, away: Double) throws -> Vec2? {
        let snapshot: Snapshot = try drawn(shell)
        var fallback: Vec2?
        var x: Double = 4
        while x <= viewWidth - 4 {
            var y: Double = 4
            while y <= viewHeight - 4 {
                let point: Vec2 = Vec2(x, y)
                if (point - start).length >= away, let cell: Cell = bedCell(shell, point, snapshot), !cell.inside {
                    if cell.column < 0 && cell.row >= 0 && cell.row < snapshot.height { return point }
                    if fallback == nil { fallback = point }
                }
                y += gridStep
            }
            x += gridStep
        }
        return fallback
    }

    /// The core `before` after applying `control` with `values`, and the adapter's answer.
    static func applied(_ before: Core, _ control: String, _ values: [Double]) -> (core: Core, result: ActionResult) {
        var copy: Core = before
        let result: ActionResult = copy.apply(ExperienceAction(control: control, values: values, step: 0))
        return (copy, result)
    }

    /// The control values of a plant.
    static func plantValues(_ kind: NocturneGardenKind, column: Int, row: Int, size: Int) -> [Double] {
        [Double(kind.order), Double(column), Double(row), Double(size)]
    }

    /// The first kind `level` supplies (kernel order), or nil.
    static func firstSupplied(_ level: NocturneGardenLevel) -> NocturneGardenKind? {
        for kind in NocturneGardenKind.allCases where level.supplyCount(kind) > 0 { return kind }
        return nil
    }

    /// The first kind `level` does not supply (kernel order), or nil.
    static func firstUnsupplied(_ level: NocturneGardenLevel) -> NocturneGardenKind? {
        for kind in NocturneGardenKind.allCases where level.supplyCount(kind) == 0 { return kind }
        return nil
    }

    /// Whether a plant of `kind` at `size` on `cell` of `core` is accepted and keeps the play `playing`.
    static func keepsPlaying(_ core: Core, kind: NocturneGardenKind, size: Int, cell: Int) -> Bool {
        let width: Int = core.play.level.width
        let after = applied(core, "bloom.plant", plantValues(kind, column: cell % width, row: cell / width,
                                                             size: size))
        return after.result == .accepted && after.core.play.stage == .playing
    }

    /// The first seed of `seeds` whose level has a budget of at least 2, allows every size of `sizes` and has a cell
    /// where a plant of its first supplied kind at the smallest of `sizes` (the level's smallest when `sizes` is empty)
    /// keeps the play going; nil when none.
    static func seedForPlant(_ seeds: Range<UInt64>, sizes: Set<Int>) throws -> UInt64? {
        for seed in seeds {
            let core: Core = try Core.opening(number: Core.levelNumber(forSeed: seed))
            let level: NocturneGardenLevel = core.play.level
            guard level.budget >= 2, sizes.isSubset(of: level.sizes),
                  let kind: NocturneGardenKind = firstSupplied(level),
                  let smallest: Int = sizes.min() ?? level.sizes.min() else { continue }
            for cell in cellsFromCentre(width: level.width, height: level.height)
            where keepsPlaying(core, kind: kind, size: smallest, cell: cell) {
                return seed
            }
        }
        return nil
    }

    /// Plants one bloom of the level's first supplied kind at `size` (the level's smallest when nil) through the port,
    /// on the cell nearest the bed's middle where the play keeps going and the drawn bloom has a pickable point, and
    /// draws a frame. Returns the bloom (index 0) and its point; nil when no cell qualifies. A plant whose bloom has no
    /// point is undone.
    static func plantOne(_ session: ExperienceSession, _ shell: Shell,
                         size wanted: Int? = nil) throws -> (bloom: NocturneGardenBloom, point: Vec2)? {
        let core: Core = try NocturneGardenTest.core(shell)
        let level: NocturneGardenLevel = core.play.level
        guard let kind: NocturneGardenKind = firstSupplied(level),
              let size: Int = wanted ?? level.sizes.min() else { return nil }
        for cell in cellsFromCentre(width: level.width, height: level.height)
        where keepsPlaying(core, kind: kind, size: size, cell: cell) {
            let values: [Double] = plantValues(kind, column: cell % level.width, row: cell / level.width, size: size)
            guard shell.port.send("bloom.plant", values) == .accepted else { continue }
            try NocturneGardenTest.draw(session)
            let play: NocturneGardenPlay = try drawnPlay(shell)
            if play.blooms.count == 1, let point: Vec2 = try bloomPoint(shell, bloom: 0) {
                return (play.blooms[0], point)
            }
            _ = shell.port.send("play.undo", [])
            try NocturneGardenTest.draw(session)
        }
        return nil
    }
}

@MainActor
@Suite(.serialized) struct NocturneGardenGestureWiringTests {
    typealias Script = NocturneGardenGestureScript
    typealias Core = NocturneGardenExperienceCore
    typealias Controller = NocturneGardenGestureController

    /// 1. A tap on an empty bed cell of level 1 plants the mirror's kind and size at that cell.
    @Test func aBedTapPlantsThePanelsKindAndSize() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        #expect(shell.state == .active)
        #expect(shell.presenter.gestures.orbit == .authored)
        let before: Core = try NocturneGardenTest.core(shell)
        #expect(before.levelNumber == 1)
        #expect(before.play.stage == .playing)
        #expect(before.play.blooms.isEmpty)
        let kind: NocturneGardenKind = NocturneGardenKind.allCases[shell.presenter.mirror.kind]
        let size: Int = shell.presenter.mirror.size
        #expect(before.play.available(kind) > 0, "the mirror starts on a supplied kind")
        let width: Int = before.play.level.width
        let target = try #require(try Script.bedTarget(shell) { (_: Int) -> Bool in true }, "a pickable bed cell")
        let column: Int = target.cell % width
        let row: Int = target.cell / width
        let expected = Script.applied(before, "bloom.plant",
                                      Script.plantValues(kind, column: column, row: row, size: size))
        #expect(expected.result == .accepted)
        let digest: String = try NocturneGardenTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0

        Script.touch(shell, id: 1, .began, at: target.point, time: &time)
        #expect(shell.presenter.gestures.state == .bedPress)
        Script.touch(shell, id: 1, .ended, at: target.point, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one bloom.plant accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try NocturneGardenTest.core(shell)
        #expect(after.play.blooms.count == 1, "one bloom planted")
        let bloom: NocturneGardenBloom = try #require(after.play.blooms.first)
        #expect(bloom.column == column && bloom.row == row, "anchored at the tapped cell")
        #expect(bloom.kind == kind, "the mirror's kind")
        #expect(bloom.size == size, "the mirror's size")
        #expect(after.play.fingerprint == expected.core.play.fingerprint, "the tap is the mirror's plant")
        #expect(try NocturneGardenTest.digest(shell) != digest, "the plant changes the digest")
        #expect(shell.presenter.refusalLog.isEmpty)
        #expect(shell.presenter.gestures.state == .idle)
    }

    /// 2. Dragging a bloom by its head to another cell moves it by the cell difference, with the exact preview shown
    /// during the drag.
    @Test func aBloomDragMovesItWithTheExactPreview() async throws {
        let seed: UInt64 = try #require(try Script.seedForPlant(0..<30, sizes: []), "a level that keeps playing")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: seed)
        let planted = try #require(try Script.plantOne(session, shell), "a planted, pickable bloom")
        let snapshot: NocturneGardenSceneSnapshot = try Script.drawn(shell)
        let play: NocturneGardenPlay = try Script.drawnPlay(shell)
        let core: Core = try NocturneGardenTest.core(shell)
        let grab: Script.Cell = try #require(Script.bedCell(shell, planted.point, snapshot), "a grab cell")
        var chosen: (end: Vec2, column: Int, row: Int)?
        for delta in Script.moveDeltas where chosen == nil {
            let column: Int = planted.bloom.column + delta.0
            let row: Int = planted.bloom.row + delta.1
            guard column >= 0, column < play.level.width, row >= 0, row < play.level.height else { continue }
            let world: SIMD3<Double> = Script.cellWorld(column: grab.column + delta.0, row: grab.row + delta.1,
                                                        snapshot)
            guard let end: Vec2 = Script.viewPoint(shell, world, snapshot), Script.inside(end, inset: 2),
                  (end - planted.point).length >= Controller.dragDistance + 1,
                  let now: Script.Cell = Script.bedCell(shell, end, snapshot), now.inside,
                  now.column == grab.column + delta.0, now.row == grab.row + delta.1 else { continue }
            let values: [Double] = [0, Double(column), Double(row)]
            guard Script.applied(core, "bloom.move", values).result == .accepted else { continue }
            chosen = (end, column, row)
        }
        let move = try #require(chosen, "a move target inside the bed and the view")
        var moved: [NocturneGardenBloom] = play.blooms
        moved[0] = NocturneGardenBloom(kind: planted.bloom.kind, column: move.column, row: move.row,
                                       size: planted.bloom.size)
        let mask: NocturneGardenMask = NocturneGardenMask.union(moved, elevation: play.elevation,
                                                                width: play.level.width, height: play.level.height)
        let expectedCells: [Int] = mask.cells.sorted()
        let expected = Script.applied(core, "bloom.move", [0, Double(move.column), Double(move.row)])
        let digest: String = try NocturneGardenTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0

        Script.touch(shell, id: 1, .began, at: planted.point, time: &time)
        #expect(shell.presenter.gestures.state == .bloomPress)
        #expect(shell.presenter.gestures.preview == nil, "no preview before the drag distance")
        let drag: Vec2 = move.end - planted.point
        for step in 1...Script.dragMoves {
            let t: Double = Double(step) / Double(Script.dragMoves)
            Script.touch(shell, id: 1, .moved, at: planted.point + drag * t, time: &time)
            if (drag * t).length >= Controller.dragDistance {
                #expect(shell.presenter.gestures.state == .bloomDrag, "past 16 points the bloom is dragged")
                #expect(shell.presenter.gestures.preview != nil, "a preview while the bloom is dragged")
            }
        }
        let preview: NocturneGardenDragPreview = try #require(shell.presenter.gestures.preview)
        #expect(!preview.removes)
        #expect(preview.bloom == 0)
        #expect(preview.column == move.column && preview.row == move.row, "the preview's anchor is the target")
        #expect(preview.cells == expectedCells, "the preview is the kernel's mask of the moved arrangement")
        try NocturneGardenTest.draw(session)
        #expect(shell.presenter.mirror.previewText == preview.text, "the drawn frame describes the preview")
        #expect(shell.presenter.mirror.previewText != nil)
        #expect(try Script.drawn(shell).preview.isEmpty, "the kept snapshot never carries the preview")
        #expect(Script.sent(shell) == sentBefore, "nothing is sent mid-drag")
        #expect(try NocturneGardenTest.digest(shell) == digest, "the preview never changes the digest")

        Script.touch(shell, id: 1, .ended, at: move.end, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one bloom.move accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try NocturneGardenTest.core(shell)
        #expect(after.play.blooms.count == 1)
        let bloom: NocturneGardenBloom = try #require(after.play.blooms.first)
        #expect(bloom.column - planted.bloom.column == move.column - planted.bloom.column)
        #expect(bloom.column == move.column && bloom.row == move.row, "moved by the cell difference")
        #expect(after.play.fingerprint == expected.core.play.fingerprint)
        #expect(after.play.mask.cells.sorted() == expectedCells, "the committed shadow is the previewed one")
        #expect(shell.presenter.gestures.preview == nil)
        #expect(shell.presenter.gestures.state == .idle)
        try NocturneGardenTest.draw(session)
        #expect(shell.presenter.mirror.previewText == nil, "no preview text after the drag")
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 3. Dragging a bloom to a point whose ray meets z = 0 outside the bed removes it.
    @Test func aBloomDraggedOffTheBedIsRemoved() async throws {
        let seed: UInt64 = try #require(try Script.seedForPlant(0..<30, sizes: []), "a level that keeps playing")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: seed)
        let planted = try #require(try Script.plantOne(session, shell), "a planted, pickable bloom")
        let snapshot: NocturneGardenSceneSnapshot = try Script.drawn(shell)
        let play: NocturneGardenPlay = try Script.drawnPlay(shell)
        let core: Core = try NocturneGardenTest.core(shell)
        let end: Vec2 = try #require(try Script.offBedPoint(shell, from: planted.point,
                                                            away: Controller.dragDistance + 1),
                                     "a point inside the view off the bed")
        let off: Script.Cell = try #require(Script.bedCell(shell, end, snapshot))
        #expect(!off.inside)
        var remaining: [NocturneGardenBloom] = play.blooms
        remaining.remove(at: 0)
        let expectedCells: [Int] = NocturneGardenMask.union(remaining, elevation: play.elevation,
                                                            width: play.level.width,
                                                            height: play.level.height).cells.sorted()
        let expected = Script.applied(core, "bloom.remove", [0])
        #expect(expected.result == .accepted)
        let digest: String = try NocturneGardenTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0

        Script.press(shell, id: 1, from: planted.point, to: end, time: &time)
        #expect(shell.presenter.gestures.state == .bloomDrag)
        let preview: NocturneGardenDragPreview = try #require(shell.presenter.gestures.preview)
        #expect(preview.removes, "off the bed the preview is a removal")
        #expect(preview.cells == expectedCells, "the shadow without the bloom")
        try NocturneGardenTest.draw(session)
        #expect(shell.presenter.mirror.previewText == preview.text)
        #expect(shell.presenter.mirror.previewText?.hasPrefix("would remove") == true)
        #expect(Script.sent(shell) == sentBefore)
        #expect(try NocturneGardenTest.digest(shell) == digest)

        Script.touch(shell, id: 1, .ended, at: end, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one bloom.remove accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try NocturneGardenTest.core(shell)
        #expect(after.play.blooms.isEmpty, "the bloom is removed")
        #expect(after.play.fingerprint == expected.core.play.fingerprint)
        #expect(shell.presenter.gestures.preview == nil)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 4. A 48-point downward drag on the lantern sets the next allowed (lower) sun.
    @Test func aLanternDragStepsTheSun() async throws {
        var found: UInt64?
        for seed in UInt64(40)..<UInt64(100) where found == nil {
            let core: Core = try Core.opening(number: Core.levelNumber(forSeed: seed))
            let elevation: Int = core.play.elevation
            guard core.play.level.elevations.contains(elevation + 1) else { continue }
            if Script.applied(core, "sun.set", [Double(elevation + 1)]).result == .accepted { found = seed }
        }
        let seed: UInt64 = try #require(found, "a level whose next lower sun is allowed")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: seed)
        let core: Core = try NocturneGardenTest.core(shell)
        let from: Int = core.play.elevation
        let allowed: [Int] = core.play.level.elevations.sorted()
        let step: Double = NocturneGardenPicker.pointsPerSunStep
        let wanted: Int = NocturneGardenPicker.sunElevation(from: from, drag: step, allowed: allowed)
        #expect(wanted == from + 1, "one step down is the next allowed elevation")
        let start: Vec2 = try #require(try Script.lanternPoint(shell), "the lantern inside the view")
        let end: Vec2 = Vec2(start.x, start.y + step)
        #expect(Script.inside(end, inset: 2))
        let expected = Script.applied(core, "sun.set", [Double(wanted)])
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0

        Script.touch(shell, id: 1, .began, at: start, time: &time)
        #expect(shell.presenter.gestures.state == .lanternDrag)
        Script.touch(shell, id: 1, .moved, at: Vec2(start.x, start.y + step / 2), time: &time)
        Script.touch(shell, id: 1, .moved, at: end, time: &time)
        #expect(Script.sent(shell) == sentBefore, "nothing is sent mid-drag")
        Script.touch(shell, id: 1, .ended, at: end, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one sun.set accepted")
        let after: Core = try NocturneGardenTest.core(shell)
        #expect(after.play.elevation == wanted, "the sun moved one allowed step lower")
        #expect(after.play.fingerprint == expected.core.play.fingerprint)
        try NocturneGardenTest.draw(session)
        #expect(shell.presenter.mirror.sun == wanted)
        #expect(shell.presenter.mirror.sunPick == wanted, "the sun picker follows the new sun")
        #expect(shell.presenter.refusalLog.isEmpty)
        #expect(shell.presenter.gestures.state == .idle)
    }

    /// 5. A two-finger pinch on a size-1 bloom with scale 1.6 resizes it to the nearest allowed size, 2.
    @Test func aPinchResizesTheBloom() async throws {
        let all: Set<Int> = [1, 2, 3]
        let seed: UInt64 = try #require(try Script.seedForPlant(40..<60, sizes: all), "a level allowing sizes 1 … 3")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: seed)
        let planted = try #require(try Script.plantOne(session, shell, size: 1), "a planted, pickable bloom")
        #expect(planted.bloom.size == 1)
        let core: Core = try NocturneGardenTest.core(shell)
        let wanted: Int = NocturneGardenPicker.pinchSize(from: 1, scale: Script.pinchScale,
                                                         allowed: core.play.level.sizes.sorted())
        #expect(wanted == 2, "1 × 1.6 is nearest to 2")
        let expected = Script.applied(core, "bloom.resize", [0, Double(wanted)])
        #expect(expected.result == .accepted)
        var placed: (down: Vec2, end: Vec2)?
        for direction in Script.pinchDirections where placed == nil {
            let down: Vec2 = planted.point + direction * Script.pinchBase
            let end: Vec2 = planted.point + direction * (Script.pinchBase * Script.pinchScale)
            if Script.inside(down, inset: 2), Script.inside(end, inset: 2) { placed = (down, end) }
        }
        let second = try #require(placed, "room for the second finger")
        let sentBefore: Script.Sent = Script.sent(shell)
        var time: Double = 0

        Script.touch(shell, id: 1, .began, at: planted.point, time: &time)
        #expect(shell.presenter.gestures.state == .bloomPress)
        Script.touch(shell, id: 2, .began, at: second.down, time: &time)
        #expect(shell.presenter.gestures.state == .pinch, "a second finger on a pressed bloom pinches it")
        Script.touch(shell, id: 2, .moved, at: second.end, time: &time)
        Script.touch(shell, id: 2, .ended, at: second.end, time: &time)
        Script.touch(shell, id: 1, .ended, at: planted.point, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted + 1, "one bloom.resize accepted")
        #expect(sentAfter.rejected == sentBefore.rejected)
        let after: Core = try NocturneGardenTest.core(shell)
        #expect(after.play.blooms.first?.size == wanted, "resized to the nearest allowed size")
        #expect(after.play.fingerprint == expected.core.play.fingerprint)
        #expect(shell.presenter.gestures.state == .idle)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 6. A two-finger drag orbits within bounds and changes no digest; a double tap on empty space and `resetView()`
    /// return to the authored orbit.
    @Test func anOrbitChangesTheViewAndResets() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        let digest: String = try NocturneGardenTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        #expect(shell.presenter.scene.orbit == .authored)
        var time: Double = 0

        Script.orbit(shell, id: 1, time: &time)
        let orbit: NocturneGardenOrbit = shell.presenter.gestures.orbit
        #expect(orbit != .authored, "two fingers orbit the camera")
        #expect(Swift.abs(orbit.yaw) <= NocturneGardenOrbit.yawLimit + 1e-12, "yaw within ±35°")
        #expect(NocturneGardenOrbit.pitchRange.contains(orbit.pitch), "pitch within 0 … 30°")
        #expect(orbit == orbit.clamped())
        #expect(shell.presenter.gestures.state == .idle)
        #expect(Script.sent(shell) == sentBefore, "an orbit sends nothing")
        #expect(try NocturneGardenTest.digest(shell) == digest, "an orbit never changes the digest")
        try NocturneGardenTest.draw(session)
        #expect(shell.presenter.scene.orbit == orbit, "the scene draws the controller's orbit")
        #expect(try NocturneGardenTest.digest(shell) == digest)

        // A double tap on empty space (two taps two frames apart, same point).
        time += 1
        let empty: Vec2 = try #require(try Script.emptyPoint(shell), "empty space inside the view")
        Script.tap(shell, id: 3, at: empty, time: &time)
        #expect(shell.presenter.gestures.orbit == orbit, "one tap keeps the orbit")
        Script.tap(shell, id: 4, at: empty, time: &time)
        #expect(shell.presenter.gestures.orbit == .authored, "a double tap on empty space resets the view")
        try NocturneGardenTest.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)
        #expect(Script.sent(shell) == sentBefore)
        #expect(try NocturneGardenTest.digest(shell) == digest)

        // Orbit again, then Reset view.
        time += 1
        Script.orbit(shell, id: 5, time: &time)
        #expect(shell.presenter.gestures.orbit != .authored)
        shell.presenter.resetView()
        #expect(shell.presenter.gestures.orbit == .authored, "Reset view restores the authored orbit")
        try NocturneGardenTest.draw(session)
        #expect(shell.presenter.scene.orbit == .authored)
        #expect(Script.sent(shell) == sentBefore)
        #expect(try NocturneGardenTest.digest(shell) == digest)
        #expect(shell.presenter.mirror.message == nil)
        #expect(shell.presenter.refusalLog.isEmpty)
    }

    /// 7. On a won play a tap on a bed cell sends nothing and the mirror explains that the play is over.
    @Test func aBedTapOnAWonPlaySendsNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: 0)
        let number: Int = try NocturneGardenTest.core(shell).levelNumber
        let actions: [NocturneGardenAction] = try NocturneGardenTest.certifiedActions(number)
        try #require(!actions.isEmpty, "level \(number) has a certified solution")
        for action in actions {
            let issued = NocturneGardenTest.control(action)
            #expect(shell.port.send(issued.control, issued.values) == .accepted)
        }
        let won: Core = try NocturneGardenTest.core(shell)
        try #require(won.play.stage == .won, "the certified solution wins level \(number)")
        try NocturneGardenTest.draw(session)
        #expect(try Script.drawn(shell).stage == .won)
        let target = try #require(try Script.bedTarget(shell) { (_: Int) -> Bool in true }, "a pickable bed cell")
        let digest: String = try NocturneGardenTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        #expect(shell.presenter.mirror.message == nil)
        var time: Double = 0

        Script.touch(shell, id: 1, .began, at: target.point, time: &time)
        #expect(shell.presenter.gestures.state == .bedPress)
        Script.touch(shell, id: 1, .ended, at: target.point, time: &time)
        #expect(Script.sent(shell) == sentBefore, "a tap on a won play sends nothing")
        #expect(try NocturneGardenTest.digest(shell) == digest)
        #expect(try NocturneGardenTest.core(shell).play.fingerprint == won.play.fingerprint)
        #expect(shell.presenter.mirror.message == NocturneGardenPresenter.finishedMessage)
        #expect(shell.presenter.refusalLog.isEmpty, "nothing was refused: nothing was sent")
        #expect(shell.presenter.gestures.state == .idle)
    }

    /// 8. A refused gesture plant (a kind the level does not supply) is shown in the mirror and logged with its reason
    /// code; the gesture actions are native actions.
    @Test func aRefusedGesturePlantIsShownAndLogged() async throws {
        var found: (seed: UInt64, kind: NocturneGardenKind)?
        for seed in UInt64(0)..<UInt64(30) where found == nil {
            let core: Core = try Core.opening(number: Core.levelNumber(forSeed: seed))
            if let kind: NocturneGardenKind = Script.firstUnsupplied(core.play.level) { found = (seed, kind) }
        }
        let unsupplied = try #require(found, "a level that leaves a kind unsupplied")
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session, seed: unsupplied.seed)
        let gestureActions: Set<String> = shell.presenter.gestureActions
        let want: Set<String> = ["bloom.plant", "bloom.move", "bloom.remove", "bloom.resize", "sun.set"]
        #expect(gestureActions == want)
        #expect(gestureActions.isSubset(of: shell.presenter.nativeActions))
        shell.presenter.mirror.kind = unsupplied.kind.order
        let size: Int = shell.presenter.mirror.size
        let core: Core = try NocturneGardenTest.core(shell)
        let width: Int = core.play.level.width
        let target = try #require(try Script.bedTarget(shell) { (_: Int) -> Bool in true }, "a pickable bed cell")
        let expected = Script.applied(core, "bloom.plant",
                                      Script.plantValues(unsupplied.kind, column: target.cell % width,
                                                         row: target.cell / width, size: size))
        #expect(expected.result != .accepted, "the kernel refuses a kind without supply")
        #expect(expected.result.code.hasSuffix("r02-g09.supply"), "\(expected.result.code)")
        let digest: String = try NocturneGardenTest.digest(shell)
        let sentBefore: Script.Sent = Script.sent(shell)
        let logBefore: Int = shell.presenter.refusalLog.count
        var time: Double = 0

        Script.tap(shell, id: 1, at: target.point, time: &time)
        let sentAfter: Script.Sent = Script.sent(shell)
        #expect(sentAfter.accepted == sentBefore.accepted)
        #expect(sentAfter.rejected == sentBefore.rejected + 1, "one bloom.plant refused")
        #expect(shell.presenter.refusalLog.count == logBefore + 1)
        #expect(shell.presenter.refusalLog.last == expected.result.code)
        #expect(shell.presenter.refusalLog.last?.hasSuffix("r02-g09.supply") == true)
        let message: String = try #require(shell.presenter.mirror.message, "the refusal is shown")
        #expect(message.contains(expected.result.code), "\(message)")
        #expect(try NocturneGardenTest.digest(shell) == digest, "a refused plant changes nothing")
        #expect(try NocturneGardenTest.core(shell).play.blooms.isEmpty)
    }
}
#endif
