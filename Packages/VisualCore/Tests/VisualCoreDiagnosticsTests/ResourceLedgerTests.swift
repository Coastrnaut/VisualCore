// ResourceLedgerTests — feature 004 T-F308 (FR-F309–FR-F311, FR-F316, SC-F305).
import Testing
@testable import VisualCoreDiagnostics

private let MiB = 1 << 20

@Test func defaultBudgetIs256MiB() {
    #expect(ResourceBudget().total == 256 * MiB)
}

@Test func overTotalBudgetIsRefusedWithoutChange() throws {
    var l = ResourceLedger(budget: ResourceBudget(total: 64 * MiB))
    try l.allocate(.texture, bytes: 16 * MiB)
    #expect(throws: ResourceBudgetError.overBudget(.texture, requested: 128 * MiB, available: 48 * MiB)) {
        try l.allocate(.texture, bytes: 128 * MiB)
    }
    #expect(l.snapshot.totalBytes == 16 * MiB)
    #expect(l.snapshot.liveCount[.texture] == 1)
}

@Test func perKindBudgetIsEnforced() throws {
    var l = ResourceLedger(budget: ResourceBudget(total: 64 * MiB, perKind: [.buffer: 1 * MiB]))
    try l.allocate(.buffer, bytes: MiB / 2)
    #expect(throws: ResourceBudgetError.overBudget(.buffer, requested: MiB, available: MiB / 2)) {
        try l.allocate(.buffer, bytes: MiB)
    }
    try l.allocate(.texture, bytes: 8 * MiB)   // other kinds unaffected
}

@Test func releasingEverythingReturnsToZeroAndKeepsPeak() throws {
    var l = ResourceLedger()
    try l.allocate(.texture, bytes: 1000)
    try l.allocate(.framebuffer, bytes: 0)
    try l.allocate(.program, bytes: 0)
    l.release(.texture, bytes: 1000)
    l.release(.framebuffer, bytes: 0)
    l.release(.program, bytes: 0)
    let s = l.snapshot
    #expect(s.totalBytes == 0)
    #expect(s.liveCount.values.allSatisfy { $0 == 0 })
    #expect(s.peakBytes == 1000)
    #expect(s.leaked == 0)
}

@Test func abandonCountsLiveObjectsAsLeakedAndResets() throws {
    var l = ResourceLedger()
    try l.allocate(.texture, bytes: 400)
    try l.allocate(.buffer, bytes: 100)
    #expect(l.abandonAll() == 2)
    #expect(l.snapshot.leaked == 2)
    #expect(l.snapshot.totalBytes == 0)
    #expect(l.snapshot.liveCount[.texture] == 0)
}

@Test func staleShaderFailuresAndDedupedWarnings() {
    var l = ResourceLedger()
    l.noteStale(); l.noteStale()
    l.noteShaderFailure()
    #expect(l.warn("prog1:uTime type mismatch"))
    #expect(!l.warn("prog1:uTime type mismatch"))
    #expect(l.warn("prog1:uColor missing"))
    let s = l.snapshot
    #expect(s.staleRejected == 2)
    #expect(s.shaderFailures == 1)
    #expect(s.warnings == ["prog1:uTime type mismatch", "prog1:uColor missing"])
}

@Test func negativeOrZeroSizedReleasesNeverGoBelowZero() throws {
    var l = ResourceLedger()
    l.release(.texture, bytes: 10)
    #expect(l.snapshot.totalBytes == 0)
    #expect(l.snapshot.liveCount[.texture] == 0)
}
