// SyntheticGestureScriptTests — feature 023 T-A02-501 (FR-A02-505, SC-A02-503).
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

private func run(_ s: SyntheticGestureScript, frames: Int) -> [PointerEvent] {
    (0..<frames).flatMap { s.events(forFrame: $0) }
}

@Test func identicalInputsGiveIdenticalEvents() {
    let a = SyntheticGestureScript(seed: 42, pointerCount: 3, viewSize: Vec2(300, 600))
    let b = SyntheticGestureScript(seed: 42, pointerCount: 3, viewSize: Vec2(300, 600))
    #expect(a == b)
    #expect(run(a, frames: 300) == run(b, frames: 300))
}

@Test func differentSeedsGiveDifferentEvents() {
    let a = SyntheticGestureScript(seed: 1, pointerCount: 2, viewSize: Vec2(300, 600))
    let b = SyntheticGestureScript(seed: 2, pointerCount: 2, viewSize: Vec2(300, 600))
    #expect(run(a, frames: 100) != run(b, frames: 100))
}

@Test func hundredSeedsStayInsideTheView() {
    for seed in UInt64(1)...100 {
        let s = SyntheticGestureScript(seed: seed, pointerCount: 10, strokeSamples: 40, speed: 20_000, viewSize: Vec2(320, 480))
        for e in run(s, frames: 600) {
            #expect(e.location.x >= 0 && e.location.x <= 320 && e.location.y >= 0 && e.location.y <= 480,
                    "seed \(seed) event \(e)")
        }
    }
}

@Test func eachPointerFollowsBeganMovedEnded() {
    let s = SyntheticGestureScript(seed: 9, pointerCount: 4, strokeSamples: 5, viewSize: Vec2(200, 200))
    var last: [Int: PointerPhase] = [:]
    var moves: [Int: Int] = [:]
    for e in run(s, frames: 200) {
        switch e.phase {
        case .began:
            #expect(last[e.id] == nil || last[e.id] == .ended)
            moves[e.id] = 0
        case .moved:
            #expect(last[e.id] == .began || last[e.id] == .moved)
            moves[e.id, default: 0] += 1
        case .ended:
            #expect(last[e.id] == .moved)
            #expect(moves[e.id] == 5)
        case .cancelled:
            Issue.record("the script never cancels")
        }
        last[e.id] = e.phase
    }
    #expect(Set(last.keys) == Set(0..<4))
}

@Test func timestampsIncreaseStrictlyPerPointer() {
    let s = SyntheticGestureScript(seed: 3, pointerCount: 10, viewSize: Vec2(400, 400))
    var last: [Int: Double] = [:]
    for e in run(s, frames: 400) {
        if let t = last[e.id] { #expect(e.timestamp > t) }
        last[e.id] = e.timestamp
    }
}

@Test func onePointerEventPerFrameAndStaggeredStarts() {
    let s = SyntheticGestureScript(seed: 5, pointerCount: 3, viewSize: Vec2(100, 100))
    #expect(s.events(forFrame: 0).map(\.id) == [0])
    #expect(s.events(forFrame: 1).map(\.id) == [0, 1])
    #expect(s.events(forFrame: 2).map(\.id) == [0, 1, 2])
    #expect(s.events(forFrame: 2).allSatisfy { e in e.id != 2 || e.phase == .began })
}

@Test func pointerCountAndSamplesAreClamped() {
    let many = SyntheticGestureScript(seed: 1, pointerCount: 50, strokeSamples: 10_000, viewSize: Vec2(100, 100))
    #expect(many.pointerCount == 10 && many.strokeSamples == 240)
    let none = SyntheticGestureScript(seed: 1, pointerCount: 0, strokeSamples: 0, viewSize: Vec2(100, 100))
    #expect(none.pointerCount == 1 && none.strokeSamples == 1)
}

@Test func invalidSizeSpeedAndIntervalFallBack() {
    let s = SyntheticGestureScript(seed: 1, speed: .nan, viewSize: Vec2(.infinity, -5), frameInterval: 0)
    #expect(s.viewSize == Vec2(1, 1))
    #expect(s.speed == 0)
    #expect(s.frameInterval == 1.0 / 60)
    #expect(SyntheticGestureScript(seed: 1, speed: 1e9, viewSize: Vec2(10, 10)).speed == 20_000)
    for e in run(s, frames: 50) { #expect(e.location == Vec2(e.location.x, e.location.y) && e.location.x <= 1 && e.location.y <= 1) }
}

@Test func seedZeroEqualsSeedOne() {
    let zero = SyntheticGestureScript(seed: 0, viewSize: Vec2(100, 100))
    let one = SyntheticGestureScript(seed: 1, viewSize: Vec2(100, 100))
    #expect(zero.seed == 1)
    #expect(run(zero, frames: 64) == run(one, frames: 64))
}

@Test func negativeFrameHasNoEvents() {
    let s = SyntheticGestureScript(seed: 1, pointerCount: 2, viewSize: Vec2(100, 100))
    #expect(s.events(forFrame: -1).isEmpty)
}

@Test func strokesMoveAtTheConfiguredSpeed() {
    // Away from the edges the step between consecutive moved samples is speed × frameInterval.
    let s = SyntheticGestureScript(seed: 11, pointerCount: 1, strokeSamples: 3, speed: 60, viewSize: Vec2(10_000, 10_000))
    let events = run(s, frames: 5)
    #expect(events.map(\.phase) == [.began, .moved, .moved, .moved, .ended])
    for (a, b) in zip(events, events.dropFirst()) where b.phase == .moved {
        #expect(abs(a.location.distance(to: b.location) - 1) < 1e-9)
    }
}
