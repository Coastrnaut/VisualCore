// SnapshotRing.swift — a bounded ring of (step, state, hash) snapshots, oldest dropped first
// (feature 214 R02-F14 T-R02F14-002; FR-R02F14-002, FR-R02F14-007; clarification Q3; research R2).

/// Up to `capacity` snapshots (1…1,024, default 32) kept every `interval` steps (1…65,536, default 64), sorted by
/// step; when full, the snapshot with the lowest step (the oldest) is dropped.
public struct SnapshotRing<State: Sendable>: Sendable {
    /// One kept state with the step it was taken at and the replay hash after that step.
    public struct Snapshot: Sendable {
        /// Steps completed when the snapshot was taken.
        public let step: Int
        /// The simulation state after `step` steps.
        public let state: State
        /// The replay hash after `step` steps.
        public let hash: ReplayHash
        /// The state's checksum when the snapshot was taken (internal: lets a restore detect a drifting checksum).
        internal let checksum: UInt64?

        /// Creates a snapshot of `state` after `step` steps with replay hash `hash`.
        public init(step: Int, state: State, hash: ReplayHash) {
            self.step = step; self.state = state; self.hash = hash; self.checksum = nil
        }

        internal init(step: Int, state: State, hash: ReplayHash, checksum: UInt64) {
            self.step = step; self.state = state; self.hash = hash; self.checksum = checksum
        }
    }

    /// The most snapshots kept.
    public let capacity: Int
    /// The step spacing between snapshots.
    public let interval: Int

    /// Creates an empty ring; refuses a capacity outside 1…1,024 or an interval outside 1…65,536.
    public init(capacity: Int = 32, interval: Int = 64) throws(TimelineError) {
        guard (1...1_024).contains(capacity) else { throw .ringSize(capacity) }
        guard (1...65_536).contains(interval) else { throw .interval(interval) }
        self.capacity = capacity; self.interval = interval
    }

    /// The kept snapshots, ascending by step (oldest first).
    public private(set) var snapshots: [Snapshot] = []

    /// Keeps `s` in step order, replacing a snapshot at the same step; when over capacity drops the oldest.
    public mutating func store(_ s: Snapshot) {
        if let last = snapshots.last, last.step < s.step {
            snapshots.append(s)
        } else if let same = snapshots.firstIndex(where: { $0.step == s.step }) {
            snapshots[same] = s
        } else {
            snapshots.insert(s, at: snapshots.firstIndex(where: { $0.step > s.step }) ?? snapshots.count)
        }
        if snapshots.count > capacity { snapshots.removeFirst(snapshots.count - capacity) }
    }

    /// The kept snapshot with the highest step ≤ `step`, if any.
    public func latest(atOrBefore step: Int) -> Snapshot? {
        snapshots.last { $0.step <= step }
    }

    /// Drops every snapshot with a step greater than `step` (`drop(after: 0)` drops all positive-step snapshots).
    public mutating func drop(after step: Int) {
        snapshots.removeAll { $0.step > step }
    }

    /// The kept snapshot at exactly `step`, if any.
    internal func snapshot(at step: Int) -> Snapshot? {
        guard let last = snapshots.last, last.step >= step else { return nil }
        return snapshots.last { $0.step == step }
    }
}
