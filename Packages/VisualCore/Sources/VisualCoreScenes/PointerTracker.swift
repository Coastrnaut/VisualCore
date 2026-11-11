// PointerTracker.swift — timestamped pointer events and active-touch tracking (feature 006 T-F505;
// FR-F502, FR-F512). Pure: a UIKit adapter (VisualCoreRendering RenderView) produces the events.
import VisualCoreMath

/// Touch phase of a pointer event, mirroring UITouch phases.
public enum PointerPhase: String, Sendable, Codable {
    case began, moved, ended, cancelled
}

/// One timestamped touch sample for a single pointer.
public struct PointerEvent: Sendable, Equatable {
    /// Stable identifier of the pointer for the lifetime of its touch.
    public var id: Int
    /// Whether the pointer began, moved, ended or was cancelled.
    public var phase: PointerPhase
    /// Location in view points (origin top-left).
    public var location: Vec2
    /// Seconds (monotonic, e.g. UITouch.timestamp).
    public var timestamp: Double
    /// Creates an event; `location` is in view points (top-left origin) and `timestamp` in monotonic seconds.
    public init(id: Int, phase: PointerPhase, location: Vec2, timestamp: Double) {
        self.id = id; self.phase = phase; self.location = location; self.timestamp = timestamp
    }
}

/// Tracks active pointers (up to `maxPointers`), their start locations and touch-down order; rejects non-finite and unknown events.
public struct PointerTracker: Sendable {
    /// More simultaneous touches are ignored (edge case; FR-F512).
    public static let maxPointers = 10

    /// Active pointers by id with their current location.
    public private(set) var active: [Int: Vec2] = [:]
    /// Location where each active pointer began.
    public private(set) var start: [Int: Vec2] = [:]
    /// Active ids in the order they began.
    public private(set) var order: [Int] = []
    /// Touches ignored because `maxPointers` were already down.
    public private(set) var ignored = 0
    private var ignoredIDs: Set<Int> = []

    /// Creates a tracker with no active pointers.
    public init() {}

    /// Number of currently active pointers.
    public var count: Int { active.count }

    /// Applies an event; returns false when it was ignored (over the limit, unknown id, non-finite location).
    @discardableResult
    public mutating func handle(_ e: PointerEvent) -> Bool {
        switch e.phase {
        case .began:
            guard e.location.isFinite, active[e.id] == nil else { return false }
            guard active.count < Self.maxPointers else {
                ignored += 1
                ignoredIDs.insert(e.id)
                return false
            }
            active[e.id] = e.location
            start[e.id] = e.location
            order.append(e.id)
            return true
        case .moved:
            guard active[e.id] != nil, e.location.isFinite else { return false }
            active[e.id] = e.location
            return true
        case .ended, .cancelled:
            if ignoredIDs.remove(e.id) != nil { return false }
            guard active.removeValue(forKey: e.id) != nil else { return false }
            start[e.id] = nil
            order.removeAll { $0 == e.id }
            return true
        }
    }

    /// Mean location of the active pointers.
    public var centroid: Vec2? {
        guard !active.isEmpty else { return nil }
        return active.values.reduce(Vec2.zero, +) / Double(active.count)
    }
}
