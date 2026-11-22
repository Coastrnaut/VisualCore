// NocturneGardenGestureController — feature 384 (R02-G09-04) T-R02G0904-004 (FR-R02G0904-001 … 005, 007;
// SC-R02G0904-001 … 004; clarifications Q1 … Q4). Turns pointer events into Nocturne Garden gesture actions (plant,
// move, remove, resize, sun, choose, reset view), the drag preview (the would-be shadow of a bloom drag) and camera
// orbits, host-testable without a screen. A small state machine in the pattern of Faceted Forge's gesture controller
// (feature 374):
//
// - One finger goes down: the point is picked once with `NocturneGardenPicker.pick(_:size:snapshot:orbit:)` at the
//   current orbit and the view's size; the touch-down snapshot and play are kept for the whole gesture.
//   - `.lantern`: a lantern drag (state `lanternDrag`).
//   - `.bloom(i)`: a bloom press (state `bloomPress`), a bloom drag (state `bloomDrag`) once the travel reaches 16
//     points.
//   - `.cell(c)`: a bed press (state `bedPress`).
//   - `.outside`, `.empty`: a press on empty space tracked for a double tap (state `idle`).
// - Moves grow the travel (the farthest distance from the touch-down point). During a bloom drag the target anchor is
//   the bloom's anchor plus the whole-cell difference between the bed cell under the finger now and at touch-down
//   (`NocturneGardenPicker.bedCell`, the grab offset); the preview (``NocturneGardenGestureController/preview``) is
//   `NocturneGardenDragPreview.make` of the touch-down play with the bloom moved there, or removed while the finger's
//   ray meets z = 0 outside the bed; nil when the target anchor is outside the bed or the ray misses the plane.
// - Release (the release point counts as a last move):
//   - travel ≥ 16 points: a bloom drag sends `.remove(i)` when its last preview is a removal, `.move(i, c, r)` when it
//     is a move to another anchor, nothing at the bloom's own anchor or without a preview; a lantern drag sends
//     `.sun(e)` with e = `NocturneGardenPicker.sunElevation` of the play's elevation for the vertical drag (down
//     positive, one step per 48 points) among the level's allowed elevations, when e differs; a drag from the bed or
//     empty space sends nothing (one finger never orbits);
//   - travel 10 … 16 points: nothing;
//   - a tap (travel < 10 points, at most 0.5 s from touch-down to lift by event timestamps):
//     - on bed cell c: `.plant(kind, column, row, size)` with the panel's kind and size and the cell as the anchor;
//     - on bloom i: `.choose(i)` (presentation only);
//     - on the lantern: nothing;
//     - on empty or outside space: nothing; as the second tap of a double tap (the previous tap also on empty or
//       outside space, its `.ended` at most 0.35 s earlier and at most 22 points away), `.resetView` and the authored
//       orbit;
//   - a longer press: nothing.
// - A finished play (any stage but `playing`) sends no plant, move, remove, resize or sun; choose, the preview and the
//   orbit still work.
// - A second finger cancels any one-finger gesture (preview dropped, nothing sent). If the first finger began on bloom
//   i, the two fingers pinch it (state `pinch`): at the release of either finger the scale (the current distance
//   between the fingers over their distance when the second went down) gives `NocturneGardenPicker.pinchSize` among
//   the level's allowed sizes, and `.resize(i, size)` is sent when it differs; a third finger cancels the pinch.
//   Otherwise the fingers orbit (state `orbiting`): yaw += Δx / width × 90°, pitch −= Δy / height × 60° (the sign
//   convention of feature 374), clamped by `NocturneGardenOrbit.clamped()`; a third finger re-bases the midpoint. A
//   finger lifting while others stay → `cancelled` until every finger has lifted. A `.cancelled` phase sends nothing.
//
// Only event timestamps are read, never a clock. Presentation only: the orbit and the preview never enter the digest,
// the snapshot's state or the kernel, which still applies its own rules (stage, supply, range) to whatever is sent.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a Nocturne Garden gesture asks for (feature 384).
public enum NocturneGardenGestureAction: Sendable, Equatable {
    /// Plant a bloom (kind, column, row, size): `bloom.plant`.
    case plant(NocturneGardenKind, Int, Int, Int)
    /// Move bloom (first) to (column, row): `bloom.move`.
    case move(Int, Int, Int)
    /// Remove bloom: `bloom.remove`.
    case remove(Int)
    /// Resize bloom (first) to size (second): `bloom.resize`.
    case resize(Int, Int)
    /// Set the sun elevation: `sun.set`.
    case sun(Int)
    /// Choose bloom in the panel (presentation only, nothing sent to the kernel).
    case choose(Int)
    /// The camera returned to the authored orbit (a double tap on empty space); the presenter redraws.
    case resetView
}

/// Turns pointer events into Nocturne Garden gesture actions, the drag preview and camera orbits (feature 384),
/// deterministic for the same events. See the file header for the rules.
public struct NocturneGardenGestureController: Sendable {
    /// The state of the gesture controller.
    public enum State: Sendable, Equatable {
        /// No drag, press or orbit: the next finger starts one, or a press on empty space tracked for a tap.
        case idle
        /// One finger went down on a bed cell: a tap plants there.
        case bedPress
        /// One finger went down on a bloom: a tap chooses it, a drag becomes a bloom drag.
        case bloomPress
        /// A bloom press travelled at least 16 points: the bloom is dragged with a preview.
        case bloomDrag
        /// One finger went down on the lantern: a vertical drag sets the sun.
        case lanternDrag
        /// Two fingers pinch the bloom the first went down on.
        case pinch
        /// Two or more fingers turn the camera.
        case orbiting
        /// A gesture was cancelled; nothing responds until every finger has lifted.
        case cancelled
    }

    /// The largest travel in view points of a tap, exclusive: 10.
    public static let tapDistance: Double = 10
    /// The smallest travel in view points of a bloom or lantern drag, 16.
    public static let dragDistance: Double = 16
    /// The longest time in seconds (event timestamps) from touch-down to lift of a tap, 0.5.
    public static let tapDuration: Double = 0.5
    /// The longest time in seconds between the two `.ended` events of a double tap, 0.35.
    public static let doubleTapWindow: Double = 0.35
    /// The largest distance in view points between the two lift points of a double tap, 22.
    public static let doubleTapDistance: Double = 22
    /// The yaw turn in radians for a two-finger movement across the whole view width, 90°.
    public static let yawPerViewWidth: Double = Double.pi / 2
    /// The pitch change in radians for a two-finger movement across the whole view height, 60°.
    public static let pitchPerViewHeight: Double = Double.pi / 3

    /// The current gesture state.
    public private(set) var state: State = .idle
    /// The camera orbit (presentation only; always clamped); ``NocturneGardenOrbit/authored`` at start.
    public private(set) var orbit: NocturneGardenOrbit = .authored
    /// The would-be shadow of the bloom drag in progress (the scene draws its cells), or nil when no bloom is dragged,
    /// the travel is under ``dragDistance`` or the target is not in the bed.
    public private(set) var preview: NocturneGardenDragPreview?

    /// The active pointers.
    private var tracker: PointerTracker = PointerTracker()
    /// The one-finger gesture in progress.
    private var touch: Touch?
    /// The pinch in progress.
    private var pinching: Pinch?
    /// The midpoint the orbit last followed.
    private var orbitMidpoint: Vec2?
    /// The last tap on empty space that may start a double tap: its lift point and its `.ended` timestamp.
    private var lastEmptyTap: (location: Vec2, time: Double)?

    /// What a one-finger gesture is on.
    private enum Kind: Sendable, Equatable {
        /// The lantern.
        case lantern
        /// Bloom i.
        case bloom(Int)
        /// Bed cell (column, row).
        case cell(Int, Int)
        /// Empty or outside space.
        case empty
    }

    /// A one-finger gesture in progress.
    private struct Touch: Sendable {
        /// The finger's pointer id.
        let pointer: Int
        /// Where the finger went down, in view points.
        let start: Vec2
        /// The touch-down timestamp.
        let time: Double
        /// What the gesture is on.
        let kind: Kind
        /// The snapshot drawn at touch-down.
        let snapshot: NocturneGardenSceneSnapshot
        /// The play at touch-down.
        let play: NocturneGardenPlay
        /// The bed cell (column, row) under the finger at touch-down (possibly outside the bed), or nil when its ray
        /// misses the bed's plane.
        let grab: (column: Int, row: Int)?
        /// The farthest distance from `start` the finger has gone, points.
        var travel: Double
        /// The last finite location of the finger.
        var last: Vec2
    }

    /// A pinch of a bloom in progress.
    private struct Pinch: Sendable {
        /// The pinched bloom's index.
        let bloom: Int
        /// The play at the first finger's touch-down.
        let play: NocturneGardenPlay
        /// The two fingers' pointer ids.
        let fingers: (Int, Int)
        /// The distance between the fingers when the second went down, points.
        let base: Double
        /// The first finger's last location.
        var first: Vec2
        /// The second finger's last location.
        var second: Vec2
    }

    /// Creates an idle controller at the authored orbit.
    public init() {}

    /// The drawn camera for a view of `viewSize` points showing `snapshot` at the current orbit, or nil for a view
    /// that is not finite and positive.
    public func camera(viewSize: Vec2, snapshot: NocturneGardenSceneSnapshot) -> NocturneGardenCamera? {
        guard Self.usable(viewSize) else { return nil }
        return NocturneGardenSceneGeometry.camera(snapshot, aspect: viewSize.x / viewSize.y, orbit: orbit)
    }

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot` (the drawn one of the committed
    /// play, without the preview) of `play`, with the panel's bloom `kind` and `size` for a plant. Returns the actions
    /// of a gesture that ended with this event (see the file header), and `[]` otherwise.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: NocturneGardenSceneSnapshot,
                                play: NocturneGardenPlay, kind: NocturneGardenKind,
                                size: Int) -> [NocturneGardenGestureAction] {
        guard tracker.handle(event) else { return [] }
        switch event.phase {
        case .began:
            began(event, viewSize: viewSize, snapshot: snapshot, play: play)
            return []
        case .moved:
            moved(event, viewSize: viewSize)
            return []
        case .ended:
            return ended(event, cancelled: false, viewSize: viewSize, play: play, kind: kind, size: size)
        case .cancelled:
            return ended(event, cancelled: true, viewSize: viewSize, play: play, kind: kind, size: size)
        }
    }

    /// Returns the camera to the authored orbit (the panel's "Reset view"); an orbit in progress continues from the
    /// fingers' current midpoint.
    public mutating func resetView() {
        orbit = .authored
        orbitMidpoint = tracker.centroid
    }

    /// Drops every pointer and any gesture in progress without sending anything (a system cancel); the orbit is kept,
    /// and the next touch starts a fresh gesture.
    public mutating func cancel() {
        tracker = PointerTracker()
        touch = nil
        pinching = nil
        orbitMidpoint = nil
        lastEmptyTap = nil
        preview = nil
        state = .idle
    }

    // MARK: Phases

    private mutating func began(_ event: PointerEvent, viewSize: Vec2, snapshot: NocturneGardenSceneSnapshot,
                                play: NocturneGardenPlay) {
        switch state {
        case .idle:
            if tracker.count == 1 && touch == nil {
                start(event, viewSize: viewSize, snapshot: snapshot, play: play)
            } else {
                secondFinger(event)
            }
        case .bedPress, .bloomPress, .bloomDrag, .lanternDrag:
            secondFinger(event)
        case .pinch:
            pinching = nil
            state = .cancelled
        case .orbiting:
            orbitMidpoint = tracker.centroid
        case .cancelled:
            break
        }
    }

    private mutating func moved(_ event: PointerEvent, viewSize: Vec2) {
        switch state {
        case .idle, .bedPress, .bloomPress, .bloomDrag, .lanternDrag:
            guard var current = touch, current.pointer == event.id else { return }
            follow(&current, to: event.location)
            touch = current
            if current.travel >= Self.dragDistance, case .bloom = current.kind {
                state = .bloomDrag
                preview = dragPreview(current, viewSize: viewSize)
            }
        case .pinch:
            guard var current = pinching, event.location.isFinite else { return }
            if event.id == current.fingers.0 { current.first = event.location }
            if event.id == current.fingers.1 { current.second = event.location }
            pinching = current
        case .orbiting:
            guard let midpoint = tracker.centroid, let last = orbitMidpoint else { return }
            orbitMidpoint = midpoint
            guard Self.usable(viewSize) else { return }
            let delta: Vec2 = midpoint - last
            let turned: NocturneGardenOrbit =
                NocturneGardenOrbit(yaw: orbit.yaw + delta.x / viewSize.x * Self.yawPerViewWidth,
                                    pitch: orbit.pitch - delta.y / viewSize.y * Self.pitchPerViewHeight)
            orbit = turned.clamped()
        case .cancelled:
            break
        }
    }

    private mutating func ended(_ event: PointerEvent, cancelled: Bool, viewSize: Vec2, play: NocturneGardenPlay,
                                kind: NocturneGardenKind, size: Int) -> [NocturneGardenGestureAction] {
        switch state {
        case .idle, .bedPress, .bloomPress, .bloomDrag, .lanternDrag:
            guard var current = touch, current.pointer == event.id else { return [] }
            touch = nil
            state = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled else {
                preview = nil
                lastEmptyTap = nil
                return []
            }
            follow(&current, to: event.location)
            let actions: [NocturneGardenGestureAction] = release(current, at: event, viewSize: viewSize, play: play,
                                                                 kind: kind, size: size)
            preview = nil
            return actions
        case .pinch:
            let current: Pinch? = pinching
            pinching = nil
            state = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled, var pinch = current else { return [] }
            if event.location.isFinite {
                if event.id == pinch.fingers.0 { pinch.first = event.location }
                if event.id == pinch.fingers.1 { pinch.second = event.location }
            }
            return resize(pinch, play: play)
        case .orbiting:
            orbitMidpoint = nil
            state = tracker.count == 0 ? .idle : .cancelled
        case .cancelled:
            if tracker.count == 0 { state = .idle }
        }
        return []
    }

    // MARK: Gestures

    /// Starts a one-finger gesture: picks the touch-down point once and decides what the gesture is.
    private mutating func start(_ event: PointerEvent, viewSize: Vec2, snapshot: NocturneGardenSceneSnapshot,
                                play: NocturneGardenPlay) {
        var pick: NocturneGardenPick = .empty
        var grab: (column: Int, row: Int)?
        if Self.usable(viewSize), event.location.isFinite {
            let point: SIMD2<Double> = Self.simd(event.location)
            let size: SIMD2<Double> = Self.simd(viewSize)
            pick = NocturneGardenPicker.pick(point, size: size, snapshot: snapshot, orbit: orbit)
            if let cell = NocturneGardenPicker.bedCell(point, size: size, snapshot: snapshot, orbit: orbit) {
                grab = (cell.column, cell.row)
            }
        }
        let kind: Kind
        switch pick {
        case .lantern:
            kind = .lantern
            state = .lanternDrag
        case .bloom(let index):
            kind = .bloom(index)
            state = .bloomPress
        case .cell(let cell):
            let width: Int = max(snapshot.width, 1)
            kind = .cell(cell % width, cell / width)
            state = .bedPress
        case .outside, .empty:
            kind = .empty
            state = .idle
        }
        touch = Touch(pointer: event.id, start: event.location, time: event.timestamp, kind: kind,
                      snapshot: snapshot, play: play, grab: grab, travel: 0, last: event.location)
        preview = nil
    }

    /// The preview of bloom drag `touch` at its last location: the touch-down play with the bloom moved by the
    /// whole-cell grab offset, or removed while the finger's ray meets the bed's plane outside the bed; nil for another
    /// gesture, an unusable view, a ray that misses the plane or a target outside the bed.
    private func dragPreview(_ touch: Touch, viewSize: Vec2) -> NocturneGardenDragPreview? {
        guard case .bloom(let index) = touch.kind, let grab = touch.grab, Self.usable(viewSize),
              touch.play.blooms.indices.contains(index),
              let now = NocturneGardenPicker.bedCell(Self.simd(touch.last), size: Self.simd(viewSize),
                                                     snapshot: touch.snapshot, orbit: orbit) else { return nil }
        let bloom: NocturneGardenBloom = touch.play.blooms[index]
        if !now.inside {
            return NocturneGardenDragPreview.make(play: touch.play, bloom: index, column: now.column, row: now.row,
                                                  removes: true)
        }
        return NocturneGardenDragPreview.make(play: touch.play, bloom: index,
                                              column: bloom.column + now.column - grab.column,
                                              row: bloom.row + now.row - grab.row, removes: false)
    }

    /// The actions of the one-finger gesture `touch` released by `event`.
    private mutating func release(_ touch: Touch, at event: PointerEvent, viewSize: Vec2, play: NocturneGardenPlay,
                                  kind: NocturneGardenKind, size: Int) -> [NocturneGardenGestureAction] {
        let playing: Bool = play.stage == .playing
        if touch.travel >= Self.dragDistance {
            lastEmptyTap = nil
            switch touch.kind {
            case .bloom(let index):
                guard playing, let last = dragPreview(touch, viewSize: viewSize) else { return [] }
                if last.removes { return [.remove(index)] }
                let bloom: NocturneGardenBloom = touch.play.blooms[index]
                guard last.column != bloom.column || last.row != bloom.row else { return [] }
                return [.move(index, last.column, last.row)]
            case .lantern:
                guard playing, touch.start.isFinite else { return [] }
                let allowed: [Int] = touch.play.level.elevations.sorted()
                let elevation: Int = NocturneGardenPicker.sunElevation(from: touch.play.elevation,
                                                                       drag: touch.last.y - touch.start.y,
                                                                       allowed: allowed)
                guard elevation != touch.play.elevation else { return [] }
                return [.sun(elevation)]
            case .cell, .empty:
                return []
            }
        }
        let held: Double = event.timestamp - touch.time
        guard touch.travel < Self.tapDistance, held.isFinite, held >= 0, held <= Self.tapDuration,
              event.timestamp.isFinite, event.location.isFinite else {
            lastEmptyTap = nil
            return []
        }
        switch touch.kind {
        case .cell(let column, let row):
            lastEmptyTap = nil
            guard playing else { return [] }
            return [.plant(kind, column, row, size)]
        case .bloom(let index):
            lastEmptyTap = nil
            return [.choose(index)]
        case .lantern:
            lastEmptyTap = nil
            return []
        case .empty:
            if let last = lastEmptyTap, event.timestamp - last.time >= 0,
               event.timestamp - last.time <= Self.doubleTapWindow,
               (event.location - last.location).length <= Self.doubleTapDistance {
                lastEmptyTap = nil
                resetView()
                return [.resetView]
            }
            lastEmptyTap = (event.location, event.timestamp)
            return []
        }
    }

    /// Cancels any one-finger gesture (nothing sent, preview dropped) for a second finger `event`: a pinch when the
    /// first finger began on a bloom and is still down, an orbit from the current midpoint otherwise.
    private mutating func secondFinger(_ event: PointerEvent) {
        let current: Touch? = touch
        touch = nil
        preview = nil
        lastEmptyTap = nil
        if let first = current, case .bloom(let index) = first.kind, tracker.count == 2,
           tracker.active[first.pointer] != nil, event.id != first.pointer {
            let at: Vec2 = tracker.active[first.pointer] ?? first.last
            pinching = Pinch(bloom: index, play: first.play, fingers: (first.pointer, event.id),
                             base: (event.location - at).length, first: at, second: event.location)
            orbitMidpoint = nil
            state = .pinch
            return
        }
        pinching = nil
        orbitMidpoint = tracker.centroid
        state = .orbiting
    }

    /// The resize a finished `pinch` sends on `play`: `.resize(bloom, size)` with the size
    /// `NocturneGardenPicker.pinchSize` gives for the scale (current distance over base distance) among the level's
    /// allowed sizes, when it differs from the bloom's and the play is playing; `[]` otherwise.
    private func resize(_ pinch: Pinch, play: NocturneGardenPlay) -> [NocturneGardenGestureAction] {
        guard play.stage == .playing, pinch.play.blooms.indices.contains(pinch.bloom), pinch.base.isFinite,
              pinch.base > 0 else { return [] }
        let scale: Double = (pinch.second - pinch.first).length / pinch.base
        guard scale.isFinite else { return [] }
        let from: Int = pinch.play.blooms[pinch.bloom].size
        let size: Int = NocturneGardenPicker.pinchSize(from: from, scale: scale,
                                                       allowed: pinch.play.level.sizes.sorted())
        guard size != from else { return [] }
        return [.resize(pinch.bloom, size)]
    }

    // MARK: Helpers

    /// Moves `touch`'s finger to `location`: its travel grows to the farthest distance from the start and its last
    /// location follows (a non-finite location changes nothing).
    private func follow(_ touch: inout Touch, to location: Vec2) {
        guard location.isFinite, touch.start.isFinite else { return }
        touch.travel = max(touch.travel, (location - touch.start).length)
        touch.last = location
    }

    /// `v` as a `SIMD2<Double>`.
    private static func simd(_ v: Vec2) -> SIMD2<Double> { SIMD2(v.x, v.y) }

    /// Whether `size` is finite and positive on both axes.
    private static func usable(_ size: Vec2) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }
}
