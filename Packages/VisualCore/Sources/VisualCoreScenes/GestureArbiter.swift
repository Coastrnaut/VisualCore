// GestureArbiter.swift — feature 226 (R02-F26) T-R02F26-003: one owner per touch over the existing recognizers
// (FR-R02F26-001…003; research R1; data-model GestureDeclaration / GestureOutcome).
//
// The arbiter keeps its own PointerTracker and one recognizer per declaration. Every accepted event goes to the
// tracker and then to all recognizers; the arbiter turns their state changes into outcomes for at most one owner:
// - when several recognizers leave `possible` on the same event, the highest priority wins (ties: declaration order)
//   and the others are reset;
// - a continuous owner emits began / changed / ended; a discrete owner emits one `recognized`;
// - a higher-priority declaration with more pointers that begins while a continuous owner is active takes over
//   (the owner emits `cancelled`); an owner its own recognizer cancels (a drag when a second finger lands) frees the
//   touch for the next gesture;
// - a `.cancelled` pointer phase cancels an active owner with no completing outcome and claims the touch;
// - once an owner ended or was recognized, nothing else is sent until every pointer has lifted;
// - after every pointer lifts, ownership clears and every recognizer that left `possible` is reset (a double tap
//   waiting for its second tap keeps its state).
// Non-finite locations and pointers beyond the largest declared pointer count are ignored. The only clock is the
// event timestamps and `tick(now:)`, so the arbiter is deterministic and host-testable.
import Foundation
import VisualCoreMath

/// The recognizer behind a declared gesture.
public enum GestureKind: String, Sendable, Equatable, Codable, CaseIterable {
    /// Single-finger tap (`TapRecognizer`).
    case tap
    /// Two taps in quick succession (`DoubleTapRecognizer`).
    case doubleTap
    /// Single finger held still (`LongPressRecognizer`).
    case longPress
    /// Continuous single-finger drag (`DragRecognizer`).
    case drag
    /// Continuous two-finger pinch (`PinchRecognizer`).
    case pinch
    /// Continuous two-finger rotation (`RotateRecognizer`).
    case rotate

    /// True for drag, pinch and rotate, which report began / changed / ended.
    public var isContinuous: Bool { self == .drag || self == .pinch || self == .rotate }
}

/// A gesture a game declares to the arbiter: its id, recognizer kind, priority and pointer count.
public struct GestureDeclaration: Sendable, Equatable, Codable {
    /// The id reported in every outcome of this gesture.
    public var id: String
    /// The recognizer used.
    public var kind: GestureKind
    /// Higher wins when several gestures leave `possible` on the same event; ties go to declaration order.
    public var priority: Int
    /// Fingers the gesture uses, clamped to 1…2.
    public var pointers: Int

    /// Creates a declaration; `pointers` is clamped to 1…2.
    public init(id: String, kind: GestureKind, priority: Int, pointers: Int) {
        self.id = id; self.kind = kind; self.priority = priority; self.pointers = min(max(pointers, 1), 2)
    }
}

/// One action the arbiter sends for the gesture that owns the touch.
public struct GestureOutcome: Sendable, Equatable, Codable {
    /// Phase of the outcome.
    public enum Phase: String, Sendable, Equatable, Codable {
        /// A continuous gesture started.
        case began
        /// A continuous gesture moved.
        case changed
        /// A continuous gesture completed.
        case ended
        /// The gesture was cancelled (lost to another gesture, a cancelled touch or `cancelAll()`); no completion follows.
        case cancelled
        /// A discrete gesture (tap, double tap, long press) was recognized.
        case recognized
    }

    /// The declaration id.
    public var gesture: String
    /// The phase.
    public var phase: Phase
    /// tap, doubleTap, longPress: [x, y]; drag: [x, y, dx, dy]; pinch: [scale]; rotate: [angle in radians]; empty when cancelled.
    public var values: [Double]

    /// Creates an outcome.
    public init(gesture: String, phase: Phase, values: [Double]) {
        self.gesture = gesture; self.phase = phase; self.values = values
    }
}

/// Pure, deterministic arbiter that lets at most one declared gesture own the touch at a time.
public struct GestureArbiter: Sendable {
    /// The declarations, in declaration order.
    public let declarations: [GestureDeclaration]
    private var recognizers: [any GestureRecognizer]
    private var tracker = PointerTracker()
    private let maxPointers: Int
    private var rejected: Set<Int> = []
    private var owner: Int?
    /// The touch is claimed (owner finished or touch cancelled) until every pointer lifts.
    private var locked = false

    /// Creates an arbiter with one recognizer (default thresholds) per declaration.
    public init(_ declarations: [GestureDeclaration]) {
        self.declarations = declarations
        self.maxPointers = declarations.map(\.pointers).max() ?? 0
        self.recognizers = declarations.map { d -> any GestureRecognizer in
            switch d.kind {
            case .tap: TapRecognizer()
            case .doubleTap: DoubleTapRecognizer()
            case .longPress: LongPressRecognizer()
            case .drag: DragRecognizer()
            case .pinch: PinchRecognizer()
            case .rotate: RotateRecognizer()
            }
        }
    }

    /// Applies a pointer event and returns the outcomes it causes; ignored events (non-finite location, a pointer
    /// beyond the declared count, unknown id) return no outcomes.
    public mutating func handle(_ event: PointerEvent) -> [GestureOutcome] {
        guard event.location.isFinite else { return [] }
        switch event.phase {
        case .began:
            if tracker.count >= maxPointers { rejected.insert(event.id); return [] }
        case .moved:
            if rejected.contains(event.id) { return [] }
        case .ended, .cancelled:
            if rejected.remove(event.id) != nil { return [] }
        }
        guard tracker.handle(event) else { return [] }

        var out: [GestureOutcome] = []
        if event.phase == .cancelled {
            // A cancelled touch cancels the owner without a completing outcome and claims the touch.
            if let o = owner, declarations[o].kind.isContinuous { out.append(cancelled(o)) }
            owner = nil; locked = true
            for i in recognizers.indices { recognizers[i].reset() }
        } else {
            let before = recognizers.map(\.state)
            for i in recognizers.indices { recognizers[i].handle(event, tracker: tracker) }
            out = arbitrate(before)
        }
        if tracker.count == 0, event.phase == .ended || event.phase == .cancelled { finishTouch() }
        return out
    }

    /// Advances time-based transitions (tap timeout, long press) and returns the outcomes they cause.
    public mutating func tick(now: Double) -> [GestureOutcome] {
        guard now.isFinite else { return [] }
        let before = recognizers.map(\.state)
        for i in recognizers.indices { recognizers[i].tick(now: now) }
        return arbitrate(before)
    }

    /// Cancels the active owner (outcome `cancelled`) and resets every recognizer and tracked pointer.
    public mutating func cancelAll() -> [GestureOutcome] {
        var out: [GestureOutcome] = []
        if let o = owner, declarations[o].kind.isContinuous, recognizers[o].state.isActive { out.append(cancelled(o)) }
        owner = nil; locked = false; rejected = []; tracker = PointerTracker()
        for i in recognizers.indices { recognizers[i].reset() }
        return out
    }

    // MARK: Arbitration

    /// Turns the state changes since `before` into outcomes for at most one owner.
    private mutating func arbitrate(_ before: [GestureState]) -> [GestureOutcome] {
        var out: [GestureOutcome] = []
        // Recognizers other than the owner that just left `possible` for began or recognized.
        let risen = recognizers.indices.filter { i in
            i != owner && before[i] == .possible && (recognizers[i].state.isActive || recognizers[i].state == .recognized)
        }

        if let o = owner {
            let state = recognizers[o].state
            if let t = best(risen), declarations[t].pointers > declarations[o].pointers,
               declarations[t].priority > declarations[o].priority, state.isActive {
                // A higher-priority gesture with more pointers takes over.
                out.append(cancelled(o)); recognizers[o].reset()
                owner = t
                out.append(outcome(t, phase(for: recognizers[t].state)))
                resetAll(risen, except: t)
                return out
            }
            resetAll(risen, except: nil)
            if state != before[o] {
                switch state {
                case .changed: out.append(outcome(o, .changed))
                case .ended: out.append(outcome(o, .ended)); owner = nil; locked = true
                case .cancelled, .failed:
                    // The owner's own recognizer gave up (e.g. a second finger cancels a drag): the touch is free.
                    out.append(cancelled(o)); owner = nil
                default: break
                }
            }
            return out
        }

        guard !locked, let w = best(risen) else { resetAll(risen, except: nil); return out }
        resetAll(risen, except: w)
        let state = recognizers[w].state
        out.append(outcome(w, phase(for: state)))
        if state == .recognized { locked = true } else { owner = w }
        return out
    }

    /// Highest priority among `candidates`; ties go to the earliest declaration.
    private func best(_ candidates: [Int]) -> Int? {
        candidates.min { a, b in
            declarations[a].priority != declarations[b].priority ? declarations[a].priority > declarations[b].priority : a < b
        }
    }

    private mutating func resetAll(_ indices: [Int], except keep: Int?) {
        for i in indices where i != keep { recognizers[i].reset() }
    }

    /// Clears ownership after the last pointer lifted; recognizers still `possible` keep their state (double tap).
    private mutating func finishTouch() {
        owner = nil; locked = false; rejected = []
        for i in recognizers.indices where recognizers[i].state != .possible { recognizers[i].reset() }
    }

    private func phase(for state: GestureState) -> GestureOutcome.Phase {
        state == .recognized ? .recognized : .began
    }

    private func cancelled(_ i: Int) -> GestureOutcome {
        GestureOutcome(gesture: declarations[i].id, phase: .cancelled, values: [])
    }

    private func outcome(_ i: Int, _ phase: GestureOutcome.Phase) -> GestureOutcome {
        GestureOutcome(gesture: declarations[i].id, phase: phase, values: values(i))
    }

    /// The values of the gesture at index `i` (see `GestureOutcome.values`).
    private func values(_ i: Int) -> [Double] {
        switch recognizers[i] {
        case let r as TapRecognizer: return r.location.map { [$0.x, $0.y] } ?? []
        case let r as DoubleTapRecognizer: return r.location.map { [$0.x, $0.y] } ?? []
        case let r as LongPressRecognizer: return r.location.map { [$0.x, $0.y] } ?? []
        case let r as DragRecognizer:
            guard let l = r.location else { return [] }
            return [l.x, l.y, r.translation.x, r.translation.y]
        case let r as PinchRecognizer: return [r.scale]
        case let r as RotateRecognizer: return [r.angle]
        default: return []
        }
    }
}
