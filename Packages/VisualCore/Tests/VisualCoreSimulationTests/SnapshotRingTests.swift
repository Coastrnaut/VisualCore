// SnapshotRingTests — feature 214 R02-F14 T-R02F14-002 (FR-R02F14-002, FR-R02F14-007; clarification Q3).
import Testing
@testable import VisualCoreSimulation

private func snap(_ step: Int) -> SnapshotRing<Int>.Snapshot {
    .init(step: step, state: step * 10, hash: .start(checksum: UInt64(step)))
}

@Test func snapshotRingRefusesCapacityAndIntervalOutOfRange() throws {
    for capacity in [0, -1, 1_025] {
        #expect(throws: TimelineError.ringSize(capacity)) { try SnapshotRing<Int>(capacity: capacity) }
    }
    for interval in [0, -3, 65_537] {
        #expect(throws: TimelineError.interval(interval)) { try SnapshotRing<Int>(interval: interval) }
    }
    let defaults = try SnapshotRing<Int>()
    #expect(defaults.capacity == 32 && defaults.interval == 64)
    let edges = try SnapshotRing<Int>(capacity: 1_024, interval: 65_536)
    #expect(edges.capacity == 1_024 && edges.interval == 65_536)
    _ = try SnapshotRing<Int>(capacity: 1, interval: 1)
}

@Test func snapshotRingDropsTheOldestWhenFull() throws {
    var ring = try SnapshotRing<Int>(capacity: 4, interval: 8)
    for k in 1...10 {
        ring.store(snap(k * 8))
        #expect(ring.snapshots.count == min(k, 4))
        #expect(ring.snapshots.map(\.step) == (max(1, k - 3)...k).map { $0 * 8 })
    }
}

@Test func snapshotRingLatestAtOrBefore() throws {
    var ring = try SnapshotRing<Int>(capacity: 8, interval: 10)
    for k in 1...5 { ring.store(snap(k * 10)) }
    #expect(ring.latest(atOrBefore: 9) == nil)
    for query in 10...70 {
        let expected = min(query / 10, 5) * 10
        #expect(ring.latest(atOrBefore: query)?.step == expected)
        #expect(ring.latest(atOrBefore: query)?.state == expected * 10)
    }
}

@Test func snapshotRingDropAfterAndOrderedStore() throws {
    var ring = try SnapshotRing<Int>(capacity: 8, interval: 10)
    for k in 1...6 { ring.store(snap(k * 10)) }
    ring.drop(after: 35)
    #expect(ring.snapshots.map(\.step) == [10, 20, 30])
    ring.store(snap(15))
    ring.store(.init(step: 20, state: -1, hash: .start(checksum: 0)))
    #expect(ring.snapshots.map(\.step) == [10, 15, 20, 30])
    #expect(ring.latest(atOrBefore: 29)?.state == -1)
    ring.drop(after: 0)
    #expect(ring.snapshots.isEmpty)
}
