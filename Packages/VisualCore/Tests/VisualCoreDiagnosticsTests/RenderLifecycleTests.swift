// RenderLifecycleTests — feature 003 T-F202 (FR-F203, SC-F203). The expected table below is written
// independently from specs/002-architecture-contracts/contracts/render-lifecycle.md, not copied from code.
import Testing
@testable import VisualCoreDiagnostics

typealias S = RenderLifecycleState

/// The contract's allowed transitions (22 of the 49 ordered pairs).
private let allowed: Set<String> = [
    "uninitialized>surfaceReady", "uninitialized>destroyed",
    "surfaceReady>active", "surfaceReady>surfaceInvalid", "surfaceReady>reinitialized", "surfaceReady>destroyed",
    "active>suspended", "active>surfaceInvalid", "active>reinitialized", "active>destroyed",
    "suspended>active", "suspended>surfaceInvalid", "suspended>reinitialized", "suspended>destroyed",
    "surfaceInvalid>active", "surfaceInvalid>suspended", "surfaceInvalid>reinitialized", "surfaceInvalid>destroyed",
    "reinitialized>active", "reinitialized>surfaceInvalid", "reinitialized>suspended", "reinitialized>destroyed",
]

@Test(arguments: S.allCases, S.allCases)
func everyStatePairMatchesTheContract(from: S, to: S) {
    #expect(RenderLifecycle.isAllowed(from: from, to: to) == allowed.contains("\(from.rawValue)>\(to.rawValue)"))
}

@Test func tableHasSevenStatesAndTwentyTwoAllowedPairs() {
    #expect(S.allCases.count == 7)
    let count = S.allCases.flatMap { a in S.allCases.map { (a, $0) } }.filter { RenderLifecycle.isAllowed(from: $0.0, to: $0.1) }.count
    #expect(count == 22)
}

@Test func rejectedTransitionLeavesStateAndCounts() {
    var life = RenderLifecycle()
    do { let ok = life.transition(to: .active); #expect(!ok) }
    #expect(life.state == .uninitialized)
    #expect(life.rejectedTransitions == 1)
    #expect(life.history.last == RenderLifecycleEvent(from: .uninitialized, to: .active, generation: 0, accepted: false))
}

@Test func generationIncrementsOnCreationAndEveryRecreation() {
    var life = RenderLifecycle()
    #expect(life.generation == 0)
    do { let ok = life.transition(to: .surfaceReady); #expect(ok) }
    #expect(life.generation == 1)
    do { let ok = life.transition(to: .active); #expect(ok) }
    for i in 0..<100 {
        do { let ok = life.transition(to: .reinitialized); #expect(ok) }
        do { let ok = life.transition(to: .active); #expect(ok) }
        #expect(life.generation == 2 + i)
    }
    #expect(life.generation == 101)
    do { let ok = life.transition(to: .destroyed); #expect(ok) }
    do { let ok = life.transition(to: .active); #expect(!ok) }
    #expect(life.canRender == false)
}

@Test func historyIsBounded() {
    var life = RenderLifecycle(historyLimit: 4)
    _ = life.transition(to: .surfaceReady)
    for _ in 0..<10 { _ = life.transition(to: .active); _ = life.transition(to: .suspended) }
    #expect(life.history.count == 4)
    #expect(life.history.last?.to == .suspended)
}
