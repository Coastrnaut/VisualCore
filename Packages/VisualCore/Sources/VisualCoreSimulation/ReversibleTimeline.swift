// ReversibleTimeline.swift — a deterministic simulation with an editable event log, snapshots, seeking and a
// replay hash (feature 214 R02-F14 T-R02F14-003; FR-R02F14-002, FR-R02F14-003, FR-R02F14-004, FR-R02F14-005,
// FR-R02F14-007; clarifications Q2–Q4; research R2–R4).

/// Runs a deterministic `FixedStepSimulation` from `start` under an `EventLog`, keeping snapshots every `interval`
/// steps in a `SnapshotRing` and the `ReplayHash` of every step, so any step can be revisited and the log edited.
///
/// The commands at step s apply, in insertion order, just before the simulation advances from s to s + 1 by `dt`.
/// A snapshot is stored after every step that is a positive multiple of `interval` and lies beyond the ring's newest
/// snapshot; the start state is kept separately as `start`. Every request that throws leaves the timeline unchanged.
public struct ReversibleTimeline<Simulation: FixedStepSimulation & Sendable, Command: Sendable & Equatable> {
    /// The state at step 0.
    public let start: Simulation
    /// The fixed step duration in seconds.
    public let dt: Double
    /// The state after `step` steps.
    public private(set) var state: Simulation
    /// Steps completed.
    public private(set) var step: Int
    /// The commands of the run.
    public private(set) var log: EventLog<Command>
    /// The kept snapshots.
    public private(set) var ring: SnapshotRing<Simulation>
    /// The replay hash after `step` steps.
    public private(set) var hash: ReplayHash

    /// Steps simulated by the most recent seek, advance or recomputing edit (internal: test evidence for SC-R02F14-004).
    internal private(set) var replayedStepCount = 0

    private let apply: @Sendable (inout Simulation, Command) -> Void
    private let startChecksum: UInt64
    private let startHash: ReplayHash

    /// Creates a timeline at step 0; `apply` performs one command on the state. Refuses a ring capacity outside
    /// 1…1,024 or an interval outside 1…65,536.
    public init(start: Simulation, dt: Double = 1.0 / 120, interval: Int = 64, capacity: Int = 32,
                log: EventLog<Command> = .init(),
                apply: @escaping @Sendable (inout Simulation, Command) -> Void) throws(TimelineError) {
        self.ring = try SnapshotRing(capacity: capacity, interval: interval)
        self.start = start; self.dt = dt; self.state = start; self.step = 0; self.log = log; self.apply = apply
        self.startChecksum = start.checksum()
        self.startHash = ReplayHash.start(checksum: startChecksum)
        self.hash = startHash
    }

    /// Runs `steps` more steps from the current state; refuses a negative count, a target above
    /// `EventLog.maxStep`, or (`hashMismatch`) a replay disagreeing with a kept snapshot.
    public mutating func advance(steps: Int = 1) throws(TimelineError) {
        guard steps >= 0 else { throw .negativeStep }
        let target = step + steps
        guard target <= EventLog<Command>.maxStep else { throw .stepLimit(target) }
        var cursor = Cursor(state: state, step: step, hash: hash)
        var newRing = ring
        try run(&cursor, to: target, log: log, ring: &newRing)
        commit(cursor, ring: newRing, log: log, replayed: steps)
    }

    /// Moves to step `step`: restores the newest of the current state (when not past `step`), the newest kept
    /// snapshot at or before `step`, or the start, and replays forward. Refuses a negative step, a step above
    /// `EventLog.maxStep`, or (`hashMismatch`) a restore or replay disagreeing with a kept checksum or hash.
    public mutating func seek(to step: Int) throws(TimelineError) {
        try seek(to: step, log: log, ring: ring, allowCurrent: true)
    }

    /// The replay hash after `step` steps, without moving the timeline.
    public func hash(at step: Int) throws(TimelineError) -> ReplayHash {
        var copy = self
        try copy.seek(to: step)
        return copy.hash
    }

    /// Appends `command` at `step`; recomputes the current state when `step` is before it.
    public mutating func insert(_ command: Command, at step: Int) throws(TimelineError) {
        var edited = log
        try edited.insert(command, at: step)
        try edit(edited, at: step)
    }

    /// Removes the command at position `index` within `step`; recomputes the current state when `step` is before it.
    public mutating func remove(at step: Int, index: Int) throws(TimelineError) {
        var edited = log
        try edited.remove(at: step, index: index)
        try edit(edited, at: step)
    }

    /// Replaces the command at position `index` within `step`; recomputes the current state when `step` is before it.
    public mutating func replace(at step: Int, index: Int, with command: Command) throws(TimelineError) {
        var edited = log
        try edited.replace(at: step, index: index, with: command)
        try edit(edited, at: step)
    }

    // MARK: - Internals

    private struct Cursor {
        var state: Simulation
        var step: Int
        var hash: ReplayHash
    }

    /// Commits an edited log: snapshots after `s` are dropped (the state at s precedes s's commands) and, when the
    /// timeline is past `s`, the current step is recomputed from the newest snapshot at or before `s`.
    private mutating func edit(_ edited: EventLog<Command>, at s: Int) throws(TimelineError) {
        var newRing = ring
        newRing.drop(after: s)
        if step > s {
            try seek(to: step, log: edited, ring: newRing, allowCurrent: false)
        } else {
            log = edited
            ring = newRing
            replayedStepCount = 0
        }
    }

    private mutating func seek(to target: Int, log: EventLog<Command>, ring: SnapshotRing<Simulation>,
                               allowCurrent: Bool) throws(TimelineError) {
        guard target >= 0 else { throw .negativeStep }
        guard target <= EventLog<Command>.maxStep else { throw .stepLimit(target) }
        var cursor = Cursor(state: start, step: 0, hash: startHash)
        var verify: UInt64? = startChecksum
        if let kept = ring.latest(atOrBefore: target) {
            cursor = Cursor(state: kept.state, step: kept.step, hash: kept.hash)
            verify = kept.checksum
        }
        if allowCurrent, step <= target, step >= cursor.step {
            cursor = Cursor(state: state, step: step, hash: hash)
            verify = nil
        }
        if let verify, cursor.state.checksum() != verify { throw .hashMismatch }
        let from = cursor.step
        var newRing = ring
        try run(&cursor, to: target, log: log, ring: &newRing)
        commit(cursor, ring: newRing, log: log, replayed: target - from)
    }

    /// Steps `cursor` to `target`, checking kept snapshots it reaches and storing new ones beyond the newest.
    private func run(_ cursor: inout Cursor, to target: Int, log: EventLog<Command>,
                     ring: inout SnapshotRing<Simulation>) throws(TimelineError) {
        let interval = ring.interval
        while cursor.step < target {
            for i in log.range(at: cursor.step) { apply(&cursor.state, log.entries[i].command) }
            cursor.state.step(dt)
            cursor.step += 1
            let checksum = cursor.state.checksum()
            cursor.hash = cursor.hash.next(step: cursor.step, checksum: checksum)
            guard cursor.step % interval == 0 else { continue }
            if let kept = ring.snapshot(at: cursor.step) {
                guard kept.hash == cursor.hash else { throw .hashMismatch }
            } else if cursor.step > (ring.snapshots.last?.step ?? 0) {
                ring.store(.init(step: cursor.step, state: cursor.state, hash: cursor.hash, checksum: checksum))
            }
        }
    }

    private mutating func commit(_ cursor: Cursor, ring newRing: SnapshotRing<Simulation>, log newLog: EventLog<Command>,
                                 replayed: Int) {
        state = cursor.state; step = cursor.step; hash = cursor.hash
        ring = newRing; log = newLog
        replayedStepCount = replayed
    }
}

extension ReversibleTimeline: Sendable {}
