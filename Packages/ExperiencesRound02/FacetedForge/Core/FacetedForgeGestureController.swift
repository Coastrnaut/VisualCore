// FacetedForgeGestureController — feature 374 (R02-G08-04) T-R02G0804-003 (FR-R02G0804-001 … 006; SC-R02G0804-001,
// 003, 004; clarifications Q1 … Q5). Turns pointer events into Faceted Forge gesture actions (preview choices, cuts and
// view resets), the drag preview (the candidate choice) and camera orbits, host-testable without a screen. A small
// state machine in the pattern of Amethyst Escape's gesture controller (feature 364):
//
// - One finger goes down: the point is picked once with `FacetedForgePicker.pick(_:size:snapshot:orbit:reduceMotion:)`
//   at the current orbit and the view's size (reduce motion off: the controller picks the opened crystal as drawn by
//   default). The choice at touch-down is the snapshot's choice; the touch-down snapshot and play are kept for the
//   candidate, so the presenter may draw the candidate while the gesture runs.
//   - `.rim`: a rim drag (state `rimDrag`).
//   - `.plane`: a plane press (state `planePress`), a depth drag (state `depthDrag`) once the travel reaches 10 points.
//   - `.piece(i)`: a piece press (state `piecePress`).
//   - `.empty`: a press on empty space tracked for a tap (state `idle`).
// - Moves grow the travel (the farthest distance from the touch-down point). Once the travel reaches 10 points the
//   candidate (``FacetedForgeGestureController/candidate``) follows the total drag (the current point minus the
//   touch-down point): for a rim drag `FacetedForgePicker.tilt` of the touch-down choice, for a depth drag the
//   touch-down choice stepped by `FacetedForgePicker.depthSteps` crossing depths (`steppingDepth(_:in:)`); nil before.
// - Release (the release point counts as a last move):
//   - travel ≥ 16 points: a rim or depth drag sends `.choose(candidate)` (on a finished play too: choosing is
//     presentation); a drag from a piece or empty space sends nothing (one finger never orbits);
//   - travel 10 … 16 points: nothing;
//   - a tap (travel < 10 points, at most 0.5 s from touch-down to lift by event timestamps):
//     - on piece i: `.choose` piece i with the touch-down direction at the middle crossing depth of that direction
//       (`FacetedForgeSolver.crossingDepths`), the touch-down depth when none crosses;
//     - on the plane while the play is `playing`: `.cut(piece, direction, depth)` of the touch-down choice, unless the
//       previous commit lifted at most 0.35 s earlier (a double tap cuts once); on any other stage nothing;
//     - on the rim: nothing;
//     - on empty space: nothing; as the second tap of a double tap on empty space (the previous tap also on empty
//       space, its `.ended` at most 0.35 s earlier and at most 22 points away), `.resetView` and the authored orbit;
//   - a longer press: nothing.
// - A second finger cancels any one-finger gesture (candidate dropped, nothing sent) and orbits: yaw += Δx / width ×
//   90°, pitch −= Δy / height × 60° (the sign convention of Amethyst Escape and Chrono Constellator), clamped by
//   `FacetedForgeOrbit.clamped()`; a third finger re-bases the midpoint. A finger lifting while others stay →
//   `cancelled` until every finger has lifted. A `.cancelled` phase sends nothing.
//
// Only event timestamps are read, never a clock. Presentation only: the orbit and the candidate never enter the digest,
// the snapshot or the kernel, which still applies its own rules (stage, budget, crossing) to whatever cut is sent.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What a Faceted Forge gesture asks for (feature 374).
public enum FacetedForgeGestureAction: Sendable, Equatable {
    /// Make this the preview choice (presentation only, nothing sent to the kernel).
    case choose(FacetedForgePreviewChoice)
    /// Cut piece (first) by direction (second) at depth (third): `piece.cut [piece, direction, depth]`.
    case cut(Int, Int, Int)
    /// The camera returned to the authored orbit (a double tap on empty space); the presenter redraws.
    case resetView
}

/// Turns pointer events into Faceted Forge gesture actions, the drag preview and camera orbits (feature 374),
/// deterministic for the same events. See the file header for the rules.
public struct FacetedForgeGestureController: Sendable {
    /// The state of the gesture controller.
    public enum State: Sendable, Equatable {
        /// No drag, press or orbit: the next finger starts one, or a press on empty space tracked for a tap.
        case idle
        /// One finger went down on the preview rim: a tilt drag.
        case rimDrag
        /// A press on the preview interior travelled at least 10 points: a depth drag.
        case depthDrag
        /// One finger went down on the preview interior: a tap cuts while playing, a drag becomes a depth drag.
        case planePress
        /// One finger went down on a piece: a tap chooses it.
        case piecePress
        /// Two or more fingers turn the camera.
        case orbiting
        /// A gesture was cancelled; nothing responds until every finger has lifted.
        case cancelled
    }

    /// The largest travel in view points of a tap, exclusive: 10.
    public static let tapDistance: Double = 10
    /// The smallest travel in view points of a rim or depth drag, 16.
    public static let dragDistance: Double = 16
    /// The longest time in seconds (event timestamps) from touch-down to lift of a tap, 0.5.
    public static let tapDuration: Double = 0.5
    /// The longest time in seconds between the two `.ended` events of a double tap, and the shortest time between two
    /// commits (cuts), 0.35.
    public static let doubleTapWindow: Double = 0.35
    /// The largest distance in view points between the two lift points of a double tap, 22.
    public static let doubleTapDistance: Double = 22
    /// The yaw turn in radians for a two-finger movement across the whole view width, 90°.
    public static let yawPerViewWidth: Double = Double.pi / 2
    /// The pitch change in radians for a two-finger movement across the whole view height, 60°.
    public static let pitchPerViewHeight: Double = Double.pi / 3

    /// The current gesture state.
    public private(set) var state: State = .idle
    /// The camera orbit (presentation only; always clamped); ``FacetedForgeOrbit/authored`` at start.
    public private(set) var orbit: FacetedForgeOrbit = .authored
    /// The choice a rim or depth drag in progress would make (the scene draws it), or nil when no drag previews one or
    /// the travel is still under ``tapDistance``.
    public private(set) var candidate: FacetedForgePreviewChoice?

    /// The active pointers.
    private var tracker: PointerTracker = PointerTracker()
    /// The one-finger gesture in progress.
    private var touch: Touch?
    /// The midpoint the orbit last followed.
    private var orbitMidpoint: Vec2?
    /// The last tap on empty space that may start a double tap: its lift point and its `.ended` timestamp.
    private var lastEmptyTap: (location: Vec2, time: Double)?
    /// The `.ended` timestamp of the last tap that sent a cut, or nil.
    private var lastCommit: Double?

    /// What a one-finger gesture is on.
    private enum Kind: Sendable, Equatable {
        /// The preview rim.
        case rim
        /// The preview interior.
        case plane
        /// Piece i.
        case piece(Int)
        /// Empty space.
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
        let snapshot: FacetedForgeSceneSnapshot
        /// The play at touch-down.
        let play: FacetedForgePlay
        /// The farthest distance from `start` the finger has gone, points.
        var travel: Double
        /// The last finite location of the finger.
        var last: Vec2
    }

    /// Creates an idle controller at the authored orbit.
    public init() {}

    /// The drawn camera for a view of `viewSize` points showing `snapshot` at the current orbit, or nil for a view
    /// that is not finite and positive.
    public func camera(viewSize: Vec2, snapshot: FacetedForgeSceneSnapshot) -> FacetedForgeCamera? {
        guard Self.usable(viewSize) else { return nil }
        return FacetedForgeSceneGeometry.camera(snapshot, aspect: viewSize.x / viewSize.y, orbit: orbit)
    }

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot` (the drawn one of the committed
    /// choice, not the candidate preview) of `play`. Returns the actions of a gesture that ended with this event (see
    /// the file header), and `[]` otherwise.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: FacetedForgeSceneSnapshot,
                                play: FacetedForgePlay) -> [FacetedForgeGestureAction] {
        guard tracker.handle(event) else { return [] }
        switch event.phase {
        case .began:
            began(event, viewSize: viewSize, snapshot: snapshot, play: play)
            return []
        case .moved:
            moved(event, viewSize: viewSize)
            return []
        case .ended:
            return ended(event, cancelled: false, viewSize: viewSize, play: play)
        case .cancelled:
            return ended(event, cancelled: true, viewSize: viewSize, play: play)
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
        orbitMidpoint = nil
        lastEmptyTap = nil
        candidate = nil
        state = .idle
    }

    // MARK: Phases

    private mutating func began(_ event: PointerEvent, viewSize: Vec2, snapshot: FacetedForgeSceneSnapshot,
                                play: FacetedForgePlay) {
        switch state {
        case .idle:
            if tracker.count == 1 && touch == nil {
                start(event, viewSize: viewSize, snapshot: snapshot, play: play)
            } else {
                startOrbit()
            }
        case .rimDrag, .depthDrag, .planePress, .piecePress:
            startOrbit()
        case .orbiting:
            orbitMidpoint = tracker.centroid
        case .cancelled:
            break
        }
    }

    private mutating func moved(_ event: PointerEvent, viewSize: Vec2) {
        switch state {
        case .idle, .rimDrag, .depthDrag, .planePress, .piecePress:
            guard var current = touch, current.pointer == event.id else { return }
            follow(&current, to: event.location)
            touch = current
            preview(current, viewSize: viewSize)
        case .orbiting:
            guard let midpoint = tracker.centroid, let last = orbitMidpoint else { return }
            orbitMidpoint = midpoint
            guard Self.usable(viewSize) else { return }
            let delta: Vec2 = midpoint - last
            let turned: FacetedForgeOrbit =
                FacetedForgeOrbit(yaw: orbit.yaw + delta.x / viewSize.x * Self.yawPerViewWidth,
                                  pitch: orbit.pitch - delta.y / viewSize.y * Self.pitchPerViewHeight)
            orbit = turned.clamped()
        case .cancelled:
            break
        }
    }

    private mutating func ended(_ event: PointerEvent, cancelled: Bool, viewSize: Vec2,
                                play: FacetedForgePlay) -> [FacetedForgeGestureAction] {
        switch state {
        case .idle, .rimDrag, .depthDrag, .planePress, .piecePress:
            guard var current = touch, current.pointer == event.id else { return [] }
            touch = nil
            candidate = nil
            state = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled else {
                lastEmptyTap = nil
                return []
            }
            follow(&current, to: event.location)
            return release(current, at: event, viewSize: viewSize, play: play)
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
    private mutating func start(_ event: PointerEvent, viewSize: Vec2, snapshot: FacetedForgeSceneSnapshot,
                                play: FacetedForgePlay) {
        var pick: FacetedForgePick = .empty
        if Self.usable(viewSize), event.location.isFinite {
            pick = FacetedForgePicker.pick(Self.simd(event.location), size: Self.simd(viewSize), snapshot: snapshot,
                                           orbit: orbit, reduceMotion: false)
        }
        let kind: Kind
        switch pick {
        case .rim:
            kind = .rim
            state = .rimDrag
        case .plane:
            kind = .plane
            state = .planePress
        case .piece(let index):
            kind = .piece(index)
            state = .piecePress
        case .empty:
            kind = .empty
            state = .idle
        }
        touch = Touch(pointer: event.id, start: event.location, time: event.timestamp, kind: kind,
                      snapshot: snapshot, play: play, travel: 0, last: event.location)
        candidate = nil
    }

    /// The candidate of a rim or depth drag `touch` at its last location (nil under ``tapDistance`` of travel, for
    /// other gestures or an unusable view); a plane press becomes a depth drag once the travel reaches
    /// ``tapDistance``.
    private mutating func preview(_ touch: Touch, viewSize: Vec2) {
        guard touch.travel >= Self.tapDistance else {
            candidate = nil
            return
        }
        if touch.kind == .plane && state == .planePress { state = .depthDrag }
        candidate = choice(touch, viewSize: viewSize)
    }

    /// The choice a rim or depth drag `touch` makes for its total drag (its last location minus its start), or nil for
    /// another gesture or an unusable view.
    private func choice(_ touch: Touch, viewSize: Vec2) -> FacetedForgePreviewChoice? {
        guard Self.usable(viewSize), touch.start.isFinite else { return nil }
        let drag: SIMD2<Double> = SIMD2(touch.last.x - touch.start.x, touch.last.y - touch.start.y)
        let size: SIMD2<Double> = Self.simd(viewSize)
        let from: FacetedForgePreviewChoice = touch.snapshot.choice
        switch touch.kind {
        case .rim:
            return FacetedForgePicker.tilt(from, drag: drag, size: size, snapshot: touch.snapshot, play: touch.play,
                                           orbit: orbit)
        case .plane:
            let steps: Int = FacetedForgePicker.depthSteps(drag: drag, size: size, snapshot: touch.snapshot,
                                                           orbit: orbit, reduceMotion: false)
            return from.steppingDepth(steps, in: touch.play)
        case .piece, .empty:
            return nil
        }
    }

    /// The actions of the one-finger gesture `touch` released by `event`.
    private mutating func release(_ touch: Touch, at event: PointerEvent, viewSize: Vec2,
                                  play: FacetedForgePlay) -> [FacetedForgeGestureAction] {
        if touch.travel >= Self.dragDistance {
            lastEmptyTap = nil
            guard let chosen = choice(touch, viewSize: viewSize) else { return [] }
            return [.choose(chosen)]
        }
        let held: Double = event.timestamp - touch.time
        guard touch.travel < Self.tapDistance, held.isFinite, held >= 0, held <= Self.tapDuration,
              event.timestamp.isFinite, event.location.isFinite else {
            lastEmptyTap = nil
            return []
        }
        let from: FacetedForgePreviewChoice = touch.snapshot.choice
        switch touch.kind {
        case .piece(let index):
            lastEmptyTap = nil
            guard touch.play.pieces.indices.contains(index) else { return [] }
            let crossing: [Int] = FacetedForgeSolver.crossingDepths(touch.play.pieces[index],
                                                                    direction: from.direction)
            let depth: Int = crossing.isEmpty ? from.depth : crossing[crossing.count / 2]
            return [.choose(FacetedForgePreviewChoice(piece: index, direction: from.direction, depth: depth))]
        case .plane:
            lastEmptyTap = nil
            guard play.stage == .playing else { return [] }
            if let last = lastCommit {
                let since: Double = event.timestamp - last
                if since >= 0 && since <= Self.doubleTapWindow { return [] }
            }
            lastCommit = event.timestamp
            return [.cut(from.piece, from.direction, from.depth)]
        case .rim:
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

    /// Cancels any one-finger gesture (nothing sent, candidate dropped) and starts orbiting from the current midpoint.
    private mutating func startOrbit() {
        touch = nil
        candidate = nil
        lastEmptyTap = nil
        orbitMidpoint = tracker.centroid
        state = .orbiting
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
