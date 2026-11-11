// PointerVelocityTracker.swift — touches as evenly spaced samples with a smoothed velocity (feature 020 T-A02-202;
// gap G-POINTERVEL; research R4). Apps that turn touches into forces (fluid splats, physics pushes, brush strokes)
// get a continuous trail at a chosen spacing and a per-finger velocity, with bounded work per touch update.
import VisualCoreMath

/// Converts pointer events into resampled samples with a smoothed velocity, independently per pointer.
public struct PointerVelocityTracker: Sendable {
    /// One output sample.
    public struct Sample: Sendable, Equatable {
        /// The pointer id from the event.
        public let id: Int
        /// Location in view points (origin top-left).
        public let position: Vec2
        /// Smoothed velocity in points per second (zero on `began`).
        public let velocity: Vec2
        /// Timestamp of the event that produced the sample (seconds).
        public let timestamp: Double
        /// The phase of that event.
        public let phase: PointerPhase
    }

    private struct State: Sendable {
        var position: Vec2
        var timestamp: Double
        var velocity: Vec2
        var moved: Bool
    }

    /// Largest distance between consecutive samples of one pointer, in points.
    public let spacing: Double
    /// Most samples one update may produce (1…256); the newest location is always included.
    public let maxSamplesPerUpdate: Int
    /// Exponential smoothing factor α (0 < α ≤ 1): v += α·(raw − v).
    public let smoothing: Double
    /// Pointers ignored because `PointerTracker.maxPointers` were already active.
    public private(set) var ignoredPointers = 0
    /// Events rejected for a non-finite location or timestamp.
    public private(set) var rejectedSamples = 0
    /// Updates that would have produced more than `maxSamplesPerUpdate` samples.
    public private(set) var cappedUpdates = 0
    private var states: [Int: State] = [:]
    private var ignoredIDs: Set<Int> = []

    /// Raw velocity is only computed over at least this interval (seconds); shorter steps keep the previous velocity.
    public static let minimumInterval = 0.001

    /// `spacing` must be > 0 (else 1), `maxSamplesPerUpdate` is clamped to 1…256, `smoothing` must be in (0, 1]
    /// (else 0.5).
    public init(spacing: Double, maxSamplesPerUpdate: Int = 16, smoothing: Double = 0.5) {
        self.spacing = spacing.isFinite && spacing > 0 ? spacing : 1
        self.maxSamplesPerUpdate = min(max(maxSamplesPerUpdate, 1), 256)
        self.smoothing = smoothing.isFinite && smoothing > 0 && smoothing <= 1 ? smoothing : 0.5
    }

    /// Number of pointers currently tracked.
    public var activeCount: Int { states.count }

    /// Processes one event:
    /// - `began`: one sample with zero velocity;
    /// - `moved`: samples along the segment from the previous location at most `spacing` apart (capped);
    /// - `ended`: one final sample, then the pointer is forgotten;
    /// - `cancelled`: the pointer is forgotten and nothing is emitted.
    public mutating func handle(_ e: PointerEvent) -> [Sample] {
        guard e.location.isFinite, e.timestamp.isFinite else {
            rejectedSamples += 1
            return []
        }
        switch e.phase {
        case .began:
            guard states[e.id] == nil else { return [] }
            guard states.count < PointerTracker.maxPointers else {
                ignoredPointers += 1
                ignoredIDs.insert(e.id)
                return []
            }
            states[e.id] = State(position: e.location, timestamp: e.timestamp, velocity: .zero, moved: false)
            return [Sample(id: e.id, position: e.location, velocity: .zero, timestamp: e.timestamp, phase: .began)]
        case .moved:
            guard var state = states[e.id] else { return [] }
            let samples = advance(&state, to: e)
            states[e.id] = state
            return samples
        case .ended:
            if ignoredIDs.remove(e.id) != nil { return [] }
            guard var state = states.removeValue(forKey: e.id) else { return [] }
            _ = advance(&state, to: e)
            return [Sample(id: e.id, position: e.location, velocity: state.velocity, timestamp: e.timestamp, phase: .ended)]
        case .cancelled:
            ignoredIDs.remove(e.id)
            states[e.id] = nil
            return []
        }
    }

    private mutating func advance(_ state: inout State, to e: PointerEvent) -> [Sample] {
        let dt = e.timestamp - state.timestamp
        if dt >= Self.minimumInterval {
            let raw = (e.location - state.position) / dt
            state.velocity = state.moved ? state.velocity + (raw - state.velocity) * smoothing : raw
            state.moved = true
        }
        let start = state.position
        let distance = start.distance(to: e.location)
        var count = max(1, Int((distance / spacing).rounded(.up)))
        if count > maxSamplesPerUpdate {
            cappedUpdates += 1
            count = maxSamplesPerUpdate
        }
        state.position = e.location
        state.timestamp = e.timestamp
        return (1...count).map { i in
            let p = i == count ? e.location : start + (e.location - start) * (Double(i) / Double(count))
            return Sample(id: e.id, position: p, velocity: state.velocity, timestamp: e.timestamp, phase: e.phase)
        }
    }
}
