// ScopeZoomTests — feature 064 (A08-P04) T-A08-402 (FR-A08-403; SC-A08-403; clarification 2; story 2). Pinch zoom as
// timebase steps, host-free and short: one step per doubling of the pinch scale against the scale at the last step,
// pinch out (scale > 1) steps the timebase index down (zoom in), pinch in steps it up, the index is clamped to 0…5.
// A continuous pinch is replayed by `pinch(by:from:)`, which feeds scales in small increments and re-anchors at each
// step as the presenter does, so a factor of 4 counts as two steps (one per doubling crossed) and 0.25 as two up.
import Foundation
import Testing
import OscilloscopeStudioCore

@Suite struct ScopeZoomTests {
    private let count = ScopeSettings.timebasesMilliseconds.count

    /// The timebase index after a continuous pinch from scale 1 to `factor`, starting at `index`: the scale moves in
    /// 64 geometric increments; whenever ``ScopeZoom/step(scale:anchorScale:)`` gives a step, the index moves and the
    /// anchor becomes the current scale.
    private func pinch(by factor: Double, from index: Int) -> Int {
        var anchor = 1.0
        var current = index
        for i in 1...64 {
            let scale = pow(2, log2(factor) * Double(i) / 64)   // exact at every power of two
            let step = ScopeZoom.step(scale: scale, anchorScale: anchor)
            if step != 0 {
                current = ScopeZoom.index(after: current, step: step, count: count)
                anchor = scale
            }
        }
        return current
    }

    @Test func oneStepPerDoublingOfTheScale() {
        #expect(ScopeZoom.step(scale: 2, anchorScale: 1) == -1)
        #expect(ScopeZoom.step(scale: 1.99, anchorScale: 1) == 0)
        #expect(ScopeZoom.step(scale: 0.5, anchorScale: 1) == 1)
        #expect(ScopeZoom.step(scale: 0.51, anchorScale: 1) == 0)
        #expect(ScopeZoom.step(scale: 4, anchorScale: 2) == -1)
        #expect(ScopeZoom.step(scale: 1, anchorScale: 2) == 1)
        #expect(ScopeZoom.step(scale: 1, anchorScale: 1) == 0)
        for bad in [0.0, -1, .nan, .infinity] {
            #expect(ScopeZoom.step(scale: bad, anchorScale: 1) == 0)
            #expect(ScopeZoom.step(scale: 2, anchorScale: bad) == 0)
        }
    }

    @Test func theIndexIsClampedToTheOfferedTimebases() {
        #expect(count == 6)
        #expect(ScopeZoom.index(after: 3, step: -1, count: count) == 2)
        #expect(ScopeZoom.index(after: 3, step: 1, count: count) == 4)
        #expect(ScopeZoom.index(after: 0, step: -1, count: count) == 0)
        #expect(ScopeZoom.index(after: 5, step: 1, count: count) == 5)
        #expect(ScopeZoom.index(after: 2, step: 0, count: count) == 2)
        #expect(ScopeZoom.index(after: Int.max, step: 1, count: count) == 5)
        #expect(ScopeZoom.index(after: 3, step: 1, count: 0) == 0)
    }

    @Test func pinchFactorsFromEveryTimebaseGiveTheExpectedClampedSteps() {
        // factor → expected index change before clamping: 2 → −1, 4 → −2 (zoom in), 0.5 → +1, 0.25 → +2 (zoom out).
        let factors: [(factor: Double, steps: Int)] = [(0.25, 2), (0.5, 1), (2, -1), (4, -2)]
        for start in 0..<count {
            for entry in factors {
                let expected = min(max(start + entry.steps, 0), count - 1)
                #expect(pinch(by: entry.factor, from: start) == expected, "factor \(entry.factor) from \(start)")
            }
        }
    }

    @Test func storyTwoAcceptance() {
        // 1 ms/div (index 3) pinched out by 2 becomes 0.5 ms/div; 0.1 ms/div stays when pinched out further.
        #expect(ScopeSettings.timebasesMilliseconds[pinch(by: 2, from: 3)] == 0.5)
        #expect(ScopeSettings.timebasesMilliseconds[pinch(by: 2, from: 0)] == 0.1)
        #expect(pinch(by: 1.9, from: 3) == 3 && pinch(by: 0.6, from: 3) == 3)
    }
}
