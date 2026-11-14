// TessellationChoiceTests — feature 044 A05-P05 T-A05-503 (G-MESHLOD; FR-A05-531; contract api.md).
import Testing
@testable import VisualCoreDiagnostics

@Test func fourLevelsOfTwentyFour() {
    let shares: [Double] = [1, 2.0 / 3.0, 0.5, 1.0 / 3.0]
    #expect(shares.map { TessellationChoice.segments(full: 24, minimum: 8, share: $0) } == [24, 16, 12, 8])
    let levels = shares.map { QualityLevel(name: "L", elementShare: $0) }
    #expect(levels.map { TessellationChoice.segments(full: 24, minimum: 8, level: $0) } == [24, 16, 12, 8])
}

@Test func monotonicInShare() {
    for (full, minimum) in [(24, 8), (64, 3), (7, 7), (5, 9), (100, 1), (1, 1)] {
        var previous = Int.min
        for i in 0...1_000 {
            let s = TessellationChoice.segments(full: full, minimum: minimum, share: Double(i) / 1_000)
            #expect(s >= previous, "full \(full) minimum \(minimum) share \(i)")
            previous = s
        }
    }
}

@Test func boundsAndNonFiniteShares() {
    #expect(TessellationChoice.segments(full: 24, minimum: 8, share: 0) == 8)
    #expect(TessellationChoice.segments(full: 24, minimum: 8, share: 1) == 24)
    #expect(TessellationChoice.segments(full: 24, minimum: 8, share: 3) == 24, "share above 1 is clamped")
    #expect(TessellationChoice.segments(full: 24, minimum: 8, share: -2) == 8, "negative share is clamped")
    for share in [Double.nan, .infinity, -.infinity] {
        #expect(TessellationChoice.segments(full: 24, minimum: 8, share: share) == 8)
    }
    #expect(TessellationChoice.segments(full: 24, minimum: 30, share: 0.1) == 24, "minimum above full gives full")
    #expect(TessellationChoice.segments(full: 0, minimum: 0, share: 1) == 1, "never below one segment")
}

@Test func vertexBudget() {
    let v: (Int) -> Int = { $0 * 100 }
    #expect(TessellationChoice.segments(full: 24, minimum: 8, share: 1, vertices: v, budget: 1_500) == 15)
    #expect(TessellationChoice.segments(full: 24, minimum: 8, share: 0.5, vertices: v, budget: 1_500) == 12,
            "an unbudgeted choice that fits is kept")
    #expect(TessellationChoice.segments(full: 24, minimum: 8, share: 1, vertices: v, budget: 500) == 8,
            "a budget below the minimum gives the minimum (best effort)")
    #expect(TessellationChoice.segments(full: 24, minimum: 8, share: .nan, vertices: v, budget: 10_000) == 8)
}

@Test func monotonicWithBudget() {
    let v: (Int) -> Int = { $0 * $0 * 10 + 4 }
    for budget in [0, 500, 1_500, 3_000, 10_000] {
        var previous = Int.min
        for i in 0...1_000 {
            let s = TessellationChoice.segments(full: 24, minimum: 8, share: Double(i) / 1_000,
                                                vertices: v, budget: budget)
            #expect(s >= previous && s >= 8 && s <= 24, "budget \(budget) share \(i)")
            previous = s
        }
    }
}
