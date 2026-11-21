// ColorfallCanyonsGestureController — feature 344 (R02-G05-04) T-R02G0504-003 (FR-R02G0504-001, 002, 004, 005;
// SC-R02G0504-001, 002; clarifications "How does a drag become a carve?", "What do taps do?", "What can the camera
// do?", "How is a drag previewed and tested?"). Turns pointer events into Colorfall Canyons actions (carve, valve,
// reset view), the carve highlight and camera orbits, host-testable without a screen. A small state machine in the
// pattern of Hue Compass's gesture controller (feature 334):
//
// - idle → dragging: one finger goes down. The touch-down point is picked once with
//   `ColorfallCanyonsPicker.pick(_:size:snapshot:orbit:)` at the current orbit and the view's size. When the pick is a
//   carvable cell (``ColorfallCanyonsGestureController/isCarvable(_:snapshot:)``: open ground, no spring or basin, current
//   height above 0 — exactly `ColorfallCanyonsLevel.isCarvable(_:heights:)`) and the snapshot's stage is `playing`, that
//   cell is ``ColorfallCanyonsGestureController/highlightedCell`` until the gesture ends.
// - dragging: every move (and the release point) grows the travel, the farthest distance from where the finger went
//   down.
// - dragging → idle on release. Travel of at least 16 points (``ColorfallCanyonsGestureController/dragDistance``)
//   returns `[.carve(cell)]` of the cell picked at touch-down, only when it was carvable and the snapshot is playing.
//   Travel under 10 points (``ColorfallCanyonsGestureController/tapDistance``) is a tap: on a spring it returns
//   `[.valve(spring)]` while playing; on empty space it counts towards a double tap: two such taps whose `.ended`
//   timestamps are at most 0.35 s apart return `[.resetView]` and reset the orbit, in every stage (the counter then
//   clears); a tap on a cell returns `[]` (a stray tap never carves). Travel of 10 up to 16 points returns `[]`.
//   The highlight is cleared at release.
// - any → orbiting: a second finger goes down (a drag in progress is dropped: nothing is sent, the highlight clears).
//   The midpoint of the fingers turns the camera: yaw += Δx / view width × 90° and pitch −= Δy / view height × 60°.
//   Screen y grows downwards, so dragging the fingers up raises the pitch (the angle down from the horizon) and the
//   view looks more from above. The orbit is clamped after every step by `ColorfallCanyonsOrbit.clamped()` (yaw ±40°,
//   pitch 25° … 70°). A third finger re-bases the midpoint so the camera does not jump.
// - orbiting → cancelled when a finger lifts while others stay down; cancelled → idle when every finger has lifted.
// - a `.cancelled` pointer phase ends any drag or orbit and sends nothing.
//
// At most one action per gesture. Only event timestamps are read, never a clock, so the same events give the same
// results. Unknown pointer ids, repeated `.began` ids and non-finite locations (rejected by `PointerTracker`) send
// nothing; a view size that is not finite and positive has no camera, so a touch on it picks nothing, highlights
// nothing and sends nothing. Presentation only: the orbit is never in the digest, the snapshot or the kernel.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a Colorfall Canyons gesture asks for (feature 344): at most one per gesture.
public enum ColorfallCanyonsGestureAction: Sendable, Equatable {
    /// Carve the cell of this row-major index by one height step: `canyon.carve [cell]`.
    case carve(Int)
    /// Toggle the valve of the spring of this index: `canyon.valve [spring]`.
    case valve(Int)
    /// The camera returned to the authored orbit (a double tap on empty space); the presenter redraws.
    case resetView
}

/// Turns pointer events into Colorfall Canyons gesture actions, the carve highlight and camera orbits (feature 344,
/// FR-R02G0504-001, 002, 004, 005): at most one action per gesture, deterministic for the same events. See the file
/// header for the rules.
public struct ColorfallCanyonsGestureController: Sendable {
    /// The state of the gesture controller.
    public enum State: Sendable, Equatable {
        /// No gesture: the next finger starts a drag (or a tap).
        case idle
        /// One finger is down: a drag on the picked cell, or a press for a tap.
        case dragging
        /// Two or more fingers turn the camera.
        case orbiting
        /// A gesture was cancelled; nothing responds until every finger has lifted.
        case cancelled
    }

    /// The largest travel in view points of a tap, exclusive: a touch that never moves 10 points is a tap.
    public static let tapDistance: Double = 10
    /// The smallest travel in view points of a carving drag, 16.
    public static let dragDistance: Double = 16
    /// The longest time in seconds between the two `.ended` events of a double tap, 0.35.
    public static let doubleTapInterval: Double = 0.35
    /// The yaw turn in radians for a two-finger movement across the whole view width, 90°.
    public static let yawPerViewWidth: Double = Double.pi / 2
    /// The pitch change in radians for a two-finger movement across the whole view height, 60° (upwards raises it, so
    /// the view looks more from above).
    public static let pitchPerViewHeight: Double = Double.pi / 3

    /// The current gesture state.
    public private(set) var state: State = .idle
    /// The camera orbit (presentation only; always clamped); ``ColorfallCanyonsOrbit/authored`` at start.
    public private(set) var orbit: ColorfallCanyonsOrbit = .authored
    /// The cell a drag in progress would carve: the carvable cell picked at touch-down while the snapshot was
    /// playing. Nil when no such drag is in progress.
    public private(set) var highlightedCell: Int?

    /// The active pointers.
    private var tracker: PointerTracker = PointerTracker()
    /// The drag (or press) in progress.
    private var drag: Drag?
    /// The midpoint the orbit last followed.
    private var orbitMidpoint: Vec2?
    /// The `.ended` timestamp of the last tap on empty space, if it may start a double tap.
    private var lastTapTime: Double?

    /// A drag (or press) in progress.
    private struct Drag: Sendable {
        /// The finger's pointer id.
        let pointer: Int
        /// Where the finger went down, in view points.
        let start: Vec2
        /// What the touch-down point picked; nil for an unusable view.
        let pick: ColorfallCanyonsPick?
        /// The carvable cell picked at touch-down while playing, or nil.
        let carvable: Int?
        /// The farthest distance from `start` the finger has gone, points.
        var travel: Double
    }

    /// Creates an idle controller at the authored orbit.
    public init() {}

    /// The drawn camera for a view of `viewSize` points showing `snapshot` at the current orbit, or nil for a view
    /// that is not finite and positive.
    public func camera(viewSize: Vec2, snapshot: ColorfallCanyonsSceneSnapshot) -> ColorfallCanyonsCamera? {
        guard Self.usable(viewSize) else { return nil }
        return ColorfallCanyonsSceneGeometry.camera(snapshot, aspect: viewSize.x / viewSize.y, orbit: orbit)
    }

    /// Whether `cell` of `snapshot` may be carved: open ground without a spring or basin, current height above 0 —
    /// the rule of `ColorfallCanyonsLevel.isCarvable(_:heights:)` on the snapshot's grounds and heights.
    public static func isCarvable(_ cell: Int, snapshot: ColorfallCanyonsSceneSnapshot) -> Bool {
        guard (0..<snapshot.cellCount).contains(cell), snapshot.heights.count == snapshot.cellCount,
              snapshot.grounds.count == snapshot.cellCount else { return false }
        guard !snapshot.isSpring(cell), !snapshot.isBasin(cell), snapshot.grounds[cell] == .open else { return false }
        return snapshot.heights[cell] > 0
    }

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot`. Returns `[.carve(cell)]` when a
    /// drag of at least ``dragDistance`` points that began on a carvable cell is released while `snapshot.stage` is
    /// `playing`, `[.valve(spring)]` for a tap on a spring while playing, `[.resetView]` for a double tap on empty
    /// space (any stage), and `[]` otherwise.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: ColorfallCanyonsSceneSnapshot) -> [ColorfallCanyonsGestureAction] {
        guard tracker.handle(event) else { return [] }
        switch event.phase {
        case .began:
            began(event, viewSize: viewSize, snapshot: snapshot)
            return []
        case .moved:
            moved(event, viewSize: viewSize)
            return []
        case .ended:
            return ended(event, cancelled: false, snapshot: snapshot)
        case .cancelled:
            return ended(event, cancelled: true, snapshot: snapshot)
        }
    }

    /// Returns the camera to the authored orbit (the panel's "Reset view"); an orbit in progress continues from the
    /// fingers' current midpoint.
    public mutating func resetView() {
        orbit = .authored
        orbitMidpoint = tracker.centroid
    }

    /// Drops every pointer and any drag in progress without sending anything (a system cancel, such as the app going
    /// to the background mid-gesture); the orbit is kept, and the next touch starts a fresh gesture.
    public mutating func cancel() {
        tracker = PointerTracker()
        drag = nil
        orbitMidpoint = nil
        highlightedCell = nil
        lastTapTime = nil
        state = .idle
    }

    // MARK: Phases

    private mutating func began(_ event: PointerEvent, viewSize: Vec2, snapshot: ColorfallCanyonsSceneSnapshot) {
        switch state {
        case .idle:
            if tracker.count == 1 {
                startDrag(event, viewSize: viewSize, snapshot: snapshot)
            } else {
                startOrbit()
            }
        case .dragging:
            startOrbit()
        case .orbiting:
            orbitMidpoint = tracker.centroid
        case .cancelled:
            break
        }
    }

    private mutating func moved(_ event: PointerEvent, viewSize: Vec2) {
        switch state {
        case .dragging:
            guard var current = drag, current.pointer == event.id else { return }
            Self.follow(&current, to: event.location)
            drag = current
        case .orbiting:
            guard let midpoint = tracker.centroid, let last = orbitMidpoint else { return }
            orbitMidpoint = midpoint
            guard Self.usable(viewSize) else { return }
            let delta: Vec2 = midpoint - last
            let turned: ColorfallCanyonsOrbit =
                ColorfallCanyonsOrbit(yaw: orbit.yaw + delta.x / viewSize.x * Self.yawPerViewWidth,
                                      pitch: orbit.pitch - delta.y / viewSize.y * Self.pitchPerViewHeight)
            orbit = turned.clamped()
        case .idle, .cancelled:
            break
        }
    }

    private mutating func ended(_ event: PointerEvent, cancelled: Bool,
                                snapshot: ColorfallCanyonsSceneSnapshot) -> [ColorfallCanyonsGestureAction] {
        switch state {
        case .dragging:
            guard var current = drag, current.pointer == event.id else { return [] }
            drag = nil
            highlightedCell = nil
            state = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled else {
                lastTapTime = nil
                return []
            }
            Self.follow(&current, to: event.location)
            if current.travel < Self.tapDistance {
                return tap(current, timestamp: event.timestamp, snapshot: snapshot)
            }
            lastTapTime = nil
            guard current.travel >= Self.dragDistance, snapshot.stage == .playing,
                  let cell = current.carvable else { return [] }
            return [.carve(cell)]
        case .orbiting:
            orbitMidpoint = nil
            state = tracker.count == 0 ? .idle : .cancelled
        case .cancelled:
            if tracker.count == 0 { state = .idle }
        case .idle:
            break
        }
        return []
    }

    // MARK: Helpers

    /// Starts a drag for the first finger: picks the touch-down point and sets the highlight.
    private mutating func startDrag(_ event: PointerEvent, viewSize: Vec2, snapshot: ColorfallCanyonsSceneSnapshot) {
        var pick: ColorfallCanyonsPick?
        if Self.usable(viewSize) {
            pick = ColorfallCanyonsPicker.pick(SIMD2(event.location.x, event.location.y),
                                               size: SIMD2(viewSize.x, viewSize.y), snapshot: snapshot, orbit: orbit)
        }
        var carvable: Int?
        if case .cell(let cell)? = pick, snapshot.stage == .playing, Self.isCarvable(cell, snapshot: snapshot) {
            carvable = cell
        }
        drag = Drag(pointer: event.id, start: event.location, pick: pick, carvable: carvable, travel: 0)
        highlightedCell = carvable
        state = .dragging
    }

    /// Drops any drag (nothing is sent) and starts orbiting from the current midpoint.
    private mutating func startOrbit() {
        drag = nil
        highlightedCell = nil
        lastTapTime = nil
        orbitMidpoint = tracker.centroid
        state = .orbiting
    }

    /// The action of a tap that ended at `timestamp`.
    private mutating func tap(_ drag: Drag, timestamp: Double,
                              snapshot: ColorfallCanyonsSceneSnapshot) -> [ColorfallCanyonsGestureAction] {
        switch drag.pick {
        case .spring(let spring)?:
            lastTapTime = nil
            return snapshot.stage == .playing ? [.valve(spring)] : []
        case .empty?:
            if let last = lastTapTime, timestamp.isFinite, timestamp - last >= 0,
               timestamp - last <= Self.doubleTapInterval {
                lastTapTime = nil
                resetView()
                return [.resetView]
            }
            lastTapTime = timestamp.isFinite ? timestamp : nil
            return []
        case .cell?, nil:
            lastTapTime = nil
            return []
        }
    }

    /// Moves `drag`'s finger to `location`: its travel grows to the farthest distance from the start (a non-finite
    /// location adds nothing).
    private static func follow(_ drag: inout Drag, to location: Vec2) {
        guard location.isFinite else { return }
        drag.travel = max(drag.travel, (location - drag.start).length)
    }

    /// Whether `size` is finite and positive on both axes.
    private static func usable(_ size: Vec2) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }
}
