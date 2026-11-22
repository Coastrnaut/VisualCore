// AmethystEscapeGestureController — feature 364 (R02-G07-04) T-R02G0704-004 (FR-R02G0704-001, 002, 003, 005, 006;
// SC-R02G0704-001, 003, 004; clarifications Q1 … Q5). Turns pointer events into Amethyst Escape gesture actions (shell
// turns, pearl advances, shell selection, layer isolation, view reset), the drag preview (dragged shell and candidate
// sectors) and camera orbits, host-testable without a screen. A small state machine in the pattern of Chrono
// Constellator's gesture controller (feature 354):
//
// - One finger goes down: the point is picked once with `AmethystEscapePicker.pick(_:size:snapshot:orbit:)` at the
//   current orbit and the view's size; the pearl wins over shells.
//   - `.pearl`: a pearl press (state `pearlPress`, every stage).
//   - `.shell(k)` while the stage is `playing`: a shell drag (state `shellDrag`); k is
//     ``AmethystEscapeGestureController/draggedShell`` until the gesture ends. In any other stage a press on shell k
//     tracked for a tap (state `idle`).
//   - `.empty`: a press on empty space tracked for a tap (state `idle`).
// - Moves grow the travel (the farthest distance from the touch-down point). A shell drag adds the change of the touch
//   angle `AmethystEscapePicker.angle(shell:at:…)` (atan2(z, x) on the plane y = h_k) since the last point that met the
//   plane, unwrapped to −π … π, to its swept angle; the candidate n = round(swept / (2π/S)) reduced to −⌊S/2⌋ … ⌊S/2⌋
//   is ``AmethystEscapeGestureController/candidateSectors`` once the travel reaches 10 points (0 before).
// - Release (the release point counts as a last move):
//   - a shell drag with travel ≥ 16 points while the stage is still `playing`: |n| × `.turn(k, sign(n))`, nothing when
//     n = 0;
//   - travel 10 … 16 points: nothing;
//   - a tap (travel < 10 points, at most 0.5 s from touch-down to lift by event timestamps):
//     - on the pearl: `.advance` while the stage is `playing`, else nothing;
//     - on shell k: `.select(k)` (every stage); when the previous tap was also on shell k, its `.ended` at most 0.35 s
//       earlier and at most 22 points away, the double tap sends `.isolate(k)` instead, or `.isolate(nil)` when k is
//       already isolated, and ``AmethystEscapeGestureController/isolated`` follows;
//     - on empty space: nothing; as the second tap of a double tap on empty space, `.resetView` and the authored orbit;
//   - a longer press: nothing.
// - A second finger cancels any shell drag or press (nothing sent, preview cleared) and orbits: yaw += Δx / width × 90°,
//   pitch −= Δy / height × 60°, clamped; a third finger re-bases the midpoint. A finger lifting while others stay →
//   `cancelled` until every finger has lifted. A `.cancelled` phase sends nothing.
//
// At most ⌊S/2⌋ turns per gesture. Only event timestamps are read, never a clock. Presentation only: the orbit and the
// isolation never enter the digest, the snapshot or the kernel, which still applies its own rules (stage, budget) to
// whatever is sent.
import Foundation
import VisualCoreMath
import VisualCoreScenes

/// What an Amethyst Escape gesture asks for (feature 364).
public enum AmethystEscapeGestureAction: Sendable, Equatable {
    /// Turn shell (first) one sector by step (second, ±1; +1 clockwise from above): `shell.rotate [shell, step]`.
    case turn(Int, Int)
    /// Advance the pearl by one transition: `pearl.advance`.
    case advance
    /// Pick this shell in the panel's shell picker (presentation only, nothing sent to the kernel).
    case select(Int)
    /// Isolate this shell (draw the others dimmed), or show every layer again for nil (presentation only).
    case isolate(Int?)
    /// The camera returned to the authored orbit (a double tap on empty space); the presenter redraws.
    case resetView
}

/// Turns pointer events into Amethyst Escape gesture actions, the drag preview and camera orbits (feature 364),
/// deterministic for the same events. See the file header for the rules.
public struct AmethystEscapeGestureController: Sendable {
    /// The state of the gesture controller.
    public enum State: Sendable, Equatable {
        /// No shell drag, pearl press or orbit: the next finger starts one, or a press tracked for a tap.
        case idle
        /// One finger went down on a shell while playing: a turn drag or a tap.
        case shellDrag
        /// One finger went down on the pearl: a tap advances it while playing.
        case pearlPress
        /// Two or more fingers turn the camera.
        case orbiting
        /// A gesture was cancelled; nothing responds until every finger has lifted.
        case cancelled
    }

    /// The largest travel in view points of a tap, exclusive: 10.
    public static let tapDistance: Double = 10
    /// The smallest travel in view points of a turn drag, 16.
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
    /// The camera orbit (presentation only; always clamped); ``AmethystEscapeOrbit/authored`` at start.
    public private(set) var orbit: AmethystEscapeOrbit = .authored
    /// The shell of a shell drag in progress (set at touch-down, cleared when the gesture ends or is cancelled), or nil.
    public private(set) var draggedShell: Int?
    /// The sectors the shell drag in progress would turn its shell (positive clockwise from above), −⌊S/2⌋ … ⌊S/2⌋;
    /// 0 when no drag is in progress or the travel is still under ``tapDistance``.
    public private(set) var candidateSectors: Int = 0
    /// The isolated shell (presentation only), or nil when every layer is shown.
    public private(set) var isolated: Int?

    /// The active pointers.
    private var tracker: PointerTracker = PointerTracker()
    /// The one-finger gesture in progress.
    private var touch: Touch?
    /// The midpoint the orbit last followed.
    private var orbitMidpoint: Vec2?
    /// The last tap that may start a double tap: what it was on, its lift point and its `.ended` timestamp.
    private var lastTap: (kind: Kind, location: Vec2, time: Double)?

    /// What a one-finger gesture is on.
    private enum Kind: Sendable, Equatable {
        /// The pearl.
        case pearl
        /// Shell k.
        case shell(Int)
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
        /// Whether the gesture is a turn drag (a shell touched while playing).
        let drag: Bool
        /// The farthest distance from `start` the finger has gone, points.
        var travel: Double
        /// The last touch angle on the dragged shell's plane, radians, or nil before the first hit.
        var angle: Double?
        /// The unwrapped angle swept since touch-down, radians.
        var swept: Double
    }

    /// Creates an idle controller at the authored orbit with every layer shown.
    public init() {}

    /// The drawn camera for a view of `viewSize` points showing `snapshot` at the current orbit, or nil for a view
    /// that is not finite and positive.
    public func camera(viewSize: Vec2, snapshot: AmethystEscapeSceneSnapshot) -> AmethystEscapeCamera? {
        guard Self.usable(viewSize) else { return nil }
        return AmethystEscapeSceneGeometry.camera(snapshot, aspect: viewSize.x / viewSize.y, orbit: orbit)
    }

    /// The snapshot to draw for `snapshot` during the current gesture: the dragged shell turned by the candidate sectors
    /// (`previewing(shell:sectors:)`), or `snapshot` itself when no drag previews a turn.
    public func preview(of snapshot: AmethystEscapeSceneSnapshot) -> AmethystEscapeSceneSnapshot {
        guard let shell = draggedShell, candidateSectors != 0 else { return snapshot }
        return snapshot.previewing(shell: shell, sectors: candidateSectors)
    }

    /// Applies one pointer event for a view of `viewSize` points showing `snapshot` (the drawn one, not a preview).
    /// Returns the actions of a gesture that ended with this event (see the file header), and `[]` otherwise.
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2,
                                snapshot: AmethystEscapeSceneSnapshot) -> [AmethystEscapeGestureAction] {
        guard tracker.handle(event) else { return [] }
        switch event.phase {
        case .began:
            began(event, viewSize: viewSize, snapshot: snapshot)
            return []
        case .moved:
            moved(event, viewSize: viewSize, snapshot: snapshot)
            return []
        case .ended:
            return ended(event, cancelled: false, viewSize: viewSize, snapshot: snapshot)
        case .cancelled:
            return ended(event, cancelled: true, viewSize: viewSize, snapshot: snapshot)
        }
    }

    /// Returns the camera to the authored orbit (the panel's "Reset view"); an orbit in progress continues from the
    /// fingers' current midpoint.
    public mutating func resetView() {
        orbit = .authored
        orbitMidpoint = tracker.centroid
    }

    /// Shows every layer again (the panel's "Show all layers", and the next level).
    public mutating func clearIsolation() {
        isolated = nil
    }

    /// Drops every pointer and any gesture in progress without sending anything (a system cancel); the orbit and the
    /// isolation are kept, and the next touch starts a fresh gesture.
    public mutating func cancel() {
        tracker = PointerTracker()
        touch = nil
        orbitMidpoint = nil
        lastTap = nil
        clearPreview()
        state = .idle
    }

    // MARK: Phases

    private mutating func began(_ event: PointerEvent, viewSize: Vec2, snapshot: AmethystEscapeSceneSnapshot) {
        switch state {
        case .idle:
            if tracker.count == 1 && touch == nil {
                start(event, viewSize: viewSize, snapshot: snapshot)
            } else {
                startOrbit()
            }
        case .shellDrag, .pearlPress:
            startOrbit()
        case .orbiting:
            orbitMidpoint = tracker.centroid
        case .cancelled:
            break
        }
    }

    private mutating func moved(_ event: PointerEvent, viewSize: Vec2, snapshot: AmethystEscapeSceneSnapshot) {
        switch state {
        case .idle, .shellDrag, .pearlPress:
            guard var current = touch, current.pointer == event.id else { return }
            follow(&current, to: event.location, viewSize: viewSize, snapshot: snapshot)
            touch = current
            if current.drag {
                candidateSectors = current.travel >= Self.tapDistance
                    ? Self.sectors(current.swept, count: snapshot.sectors) : 0
            }
        case .orbiting:
            guard let midpoint = tracker.centroid, let last = orbitMidpoint else { return }
            orbitMidpoint = midpoint
            guard Self.usable(viewSize) else { return }
            let delta: Vec2 = midpoint - last
            let turned: AmethystEscapeOrbit =
                AmethystEscapeOrbit(yaw: orbit.yaw + delta.x / viewSize.x * Self.yawPerViewWidth,
                                    pitch: orbit.pitch - delta.y / viewSize.y * Self.pitchPerViewHeight)
            orbit = turned.clamped()
        case .cancelled:
            break
        }
    }

    private mutating func ended(_ event: PointerEvent, cancelled: Bool, viewSize: Vec2,
                                snapshot: AmethystEscapeSceneSnapshot) -> [AmethystEscapeGestureAction] {
        switch state {
        case .idle, .shellDrag, .pearlPress:
            guard var current = touch, current.pointer == event.id else { return [] }
            touch = nil
            clearPreview()
            state = tracker.count == 0 ? .idle : .cancelled
            guard !cancelled else {
                lastTap = nil
                return []
            }
            follow(&current, to: event.location, viewSize: viewSize, snapshot: snapshot)
            return release(current, at: event, snapshot: snapshot)
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
    private mutating func start(_ event: PointerEvent, viewSize: Vec2, snapshot: AmethystEscapeSceneSnapshot) {
        var pick: AmethystEscapePick = .empty
        if Self.usable(viewSize), event.location.isFinite {
            pick = AmethystEscapePicker.pick(Self.simd(event.location), size: Self.simd(viewSize), snapshot: snapshot,
                                             orbit: orbit)
        }
        let kind: Kind
        switch pick {
        case .pearl: kind = .pearl
        case .shell(let shell): kind = .shell(shell)
        case .empty: kind = .empty
        }
        var drag: Bool = false
        var angle: Double?
        if case .shell(let shell) = kind, snapshot.stage == .playing {
            drag = true
            angle = self.angle(shell, at: event.location, viewSize: viewSize, snapshot: snapshot)
        }
        touch = Touch(pointer: event.id, start: event.location, time: event.timestamp, kind: kind, drag: drag,
                      travel: 0, angle: angle, swept: 0)
        clearPreview()
        if drag, case .shell(let shell) = kind {
            draggedShell = shell
            state = .shellDrag
        } else if kind == .pearl {
            state = .pearlPress
        } else {
            state = .idle
        }
    }

    /// The actions of the one-finger gesture `touch` released by `event`.
    private mutating func release(_ touch: Touch, at event: PointerEvent,
                                  snapshot: AmethystEscapeSceneSnapshot) -> [AmethystEscapeGestureAction] {
        if touch.travel >= Self.dragDistance {
            lastTap = nil
            guard touch.drag, snapshot.stage == .playing, case .shell(let shell) = touch.kind else { return [] }
            let n: Int = Self.sectors(touch.swept, count: snapshot.sectors)
            guard n != 0 else { return [] }
            let step: Int = n > 0 ? 1 : -1
            return Array(repeating: .turn(shell, step), count: abs(n))
        }
        let held: Double = event.timestamp - touch.time
        guard touch.travel < Self.tapDistance, held.isFinite, held >= 0, held <= Self.tapDuration,
              event.timestamp.isFinite, event.location.isFinite else {
            lastTap = nil
            return []
        }
        let double: Bool
        if let last = lastTap, last.kind == touch.kind, event.timestamp - last.time >= 0,
           event.timestamp - last.time <= Self.doubleTapWindow,
           (event.location - last.location).length <= Self.doubleTapDistance {
            double = true
        } else {
            double = false
        }
        switch touch.kind {
        case .pearl:
            lastTap = nil
            return snapshot.stage == .playing ? [.advance] : []
        case .shell(let shell):
            if double {
                lastTap = nil
                isolated = isolated == shell ? nil : shell
                return [.isolate(isolated)]
            }
            lastTap = (touch.kind, event.location, event.timestamp)
            return [.select(shell)]
        case .empty:
            if double {
                lastTap = nil
                resetView()
                return [.resetView]
            }
            lastTap = (touch.kind, event.location, event.timestamp)
            return []
        }
    }

    /// Cancels any one-finger gesture (nothing sent) and starts orbiting from the current midpoint.
    private mutating func startOrbit() {
        touch = nil
        clearPreview()
        lastTap = nil
        orbitMidpoint = tracker.centroid
        state = .orbiting
    }

    /// Clears the dragged shell and the candidate sectors.
    private mutating func clearPreview() {
        draggedShell = nil
        candidateSectors = 0
    }

    // MARK: Helpers

    /// Moves `touch`'s finger to `location`: its travel grows to the farthest distance from the start, and a turn drag
    /// adds the unwrapped change of the touch angle on its shell's plane (a non-finite location, or one whose ray misses
    /// the plane, adds nothing).
    private func follow(_ touch: inout Touch, to location: Vec2, viewSize: Vec2,
                        snapshot: AmethystEscapeSceneSnapshot) {
        guard location.isFinite else { return }
        touch.travel = max(touch.travel, (location - touch.start).length)
        guard touch.drag, case .shell(let shell) = touch.kind,
              let a = angle(shell, at: location, viewSize: viewSize, snapshot: snapshot) else { return }
        if let last = touch.angle { touch.swept += Self.unwrapped(a - last) }
        touch.angle = a
    }

    /// The picker's touch angle on shell `shell`'s plane at `location`, or nil (unusable view included).
    private func angle(_ shell: Int, at location: Vec2, viewSize: Vec2,
                       snapshot: AmethystEscapeSceneSnapshot) -> Double? {
        guard Self.usable(viewSize), location.isFinite else { return nil }
        return AmethystEscapePicker.angle(shell: shell, at: Self.simd(location), size: Self.simd(viewSize),
                                          snapshot: snapshot, orbit: orbit)
    }

    /// `delta` reduced to −π … π.
    static func unwrapped(_ delta: Double) -> Double {
        var d: Double = delta.truncatingRemainder(dividingBy: 2 * Double.pi)
        if d > Double.pi { d -= 2 * Double.pi }
        if d < -Double.pi { d += 2 * Double.pi }
        return d
    }

    /// The whole sectors n = round(swept / (2π/count)) reduced to the shortest equivalent −⌊count/2⌋ … ⌊count/2⌋;
    /// 0 for no sectors or a non-finite angle.
    static func sectors(_ swept: Double, count: Int) -> Int {
        guard count > 0, swept.isFinite else { return 0 }
        let raw: Double = (swept / (2 * Double.pi / Double(count))).rounded()
        guard abs(raw) < 1e9 else { return 0 }
        var n: Int = ((Int(raw) % count) + count) % count
        if n > count / 2 { n -= count }
        return n
    }

    /// `v` as a `SIMD2<Double>`.
    private static func simd(_ v: Vec2) -> SIMD2<Double> { SIMD2(v.x, v.y) }

    /// Whether `size` is finite and positive on both axes.
    private static func usable(_ size: Vec2) -> Bool {
        size.x.isFinite && size.y.isFinite && size.x > 0 && size.y > 0
    }
}
