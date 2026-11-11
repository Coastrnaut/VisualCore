// PointerVelocityTrackerTests — feature 020 T-A02-202 (G-POINTERVEL; FR-A02-201, SC-A02-204; research R4).
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

private func ev(_ id: Int, _ phase: PointerPhase, _ x: Double, _ y: Double, _ t: Double) -> PointerEvent {
    PointerEvent(id: id, phase: phase, location: Vec2(x, y), timestamp: t)
}

@Test func beganEmitsOneStillSample() {
    var t = PointerVelocityTracker(spacing: 10)
    let s = t.handle(ev(1, .began, 5, 5, 0))
    #expect(s.count == 1)
    #expect(s[0].velocity == .zero && s[0].position == Vec2(5, 5) && s[0].phase == .began)
    #expect(t.activeCount == 1)
}

@Test func movedIsResampledAtSpacing() {
    var t = PointerVelocityTracker(spacing: 10)
    _ = t.handle(ev(1, .began, 0, 0, 0))
    let s = t.handle(ev(1, .moved, 95, 0, 0.1))
    #expect(s.count == 10)   // ceil(95 / 10)
    var last = Vec2(0, 0)
    for sample in s {
        #expect(sample.position.distance(to: last) <= 10 + 1e-9)
        last = sample.position
    }
    #expect(s.last?.position == Vec2(95, 0))
}

@Test func velocityConvergesFromTimestamps() {
    var t = PointerVelocityTracker(spacing: 100, smoothing: 0.5)
    _ = t.handle(ev(1, .began, 0, 0, 0))
    var v = Vec2.zero
    for i in 1...20 {
        v = t.handle(ev(1, .moved, Double(i) * 5, 0, Double(i) * 0.01)).last!.velocity
    }
    #expect(abs(v.x - 500) < 1e-6 && abs(v.y) < 1e-9)
}

@Test func firstMoveUsesRawVelocityThenSmooths() {
    var t = PointerVelocityTracker(spacing: 100, smoothing: 0.5)
    _ = t.handle(ev(1, .began, 0, 0, 0))
    #expect(t.handle(ev(1, .moved, 10, 0, 0.01)).last!.velocity.x == 1000)
    #expect(t.handle(ev(1, .moved, 10, 0, 0.02)).last!.velocity.x == 500, "half-way toward the new raw velocity 0")
}

@Test func pointersAreIndependent() {
    var t = PointerVelocityTracker(spacing: 100)
    _ = t.handle(ev(1, .began, 0, 0, 0))
    _ = t.handle(ev(2, .began, 100, 100, 0))
    let a = t.handle(ev(1, .moved, 10, 0, 0.01)).last!
    let b = t.handle(ev(2, .moved, 100, 90, 0.01)).last!
    #expect(a.id == 1 && a.velocity.x > 0 && a.velocity.y == 0)
    #expect(b.id == 2 && b.velocity.y < 0 && b.velocity.x == 0)
}

@Test func updatesAreCappedAndCounted() {
    var t = PointerVelocityTracker(spacing: 1, maxSamplesPerUpdate: 16)
    _ = t.handle(ev(1, .began, 0, 0, 0))
    let s = t.handle(ev(1, .moved, 1000, 0, 0.01))
    #expect(s.count == 16)
    #expect(t.cappedUpdates == 1)
    #expect(s.last?.position == Vec2(1000, 0), "the newest location is always emitted")
}

@Test func nonFiniteInputIsRejected() {
    var t = PointerVelocityTracker(spacing: 10)
    #expect(t.handle(ev(1, .began, .nan, 0, 0)).isEmpty)
    _ = t.handle(ev(2, .began, 0, 0, 0))
    #expect(t.handle(ev(2, .moved, .infinity, 0, 0.1)).isEmpty)
    #expect(t.handle(ev(2, .moved, 5, 0, .nan)).isEmpty)
    #expect(t.rejectedSamples == 3)
    #expect(t.activeCount == 1)
}

@Test func zeroTimeStepKeepsPreviousVelocity() {
    var t = PointerVelocityTracker(spacing: 100)
    _ = t.handle(ev(1, .began, 0, 0, 0))
    let v1 = t.handle(ev(1, .moved, 10, 0, 0.01)).last!.velocity
    let s = t.handle(ev(1, .moved, 20, 0, 0.01)).last!
    #expect(s.velocity == v1, "no division by zero; the previous velocity is kept")
    #expect(s.position == Vec2(20, 0))
}

@Test func endedEmitsFinalSampleAndCancelEmitsNothing() {
    var t = PointerVelocityTracker(spacing: 100)
    _ = t.handle(ev(1, .began, 0, 0, 0))
    _ = t.handle(ev(1, .moved, 10, 0, 0.01))
    let end = t.handle(ev(1, .ended, 12, 0, 0.02))
    #expect(end.count == 1 && end[0].phase == .ended)
    #expect(t.activeCount == 0)
    _ = t.handle(ev(2, .began, 0, 0, 0))
    #expect(t.handle(ev(2, .cancelled, 50, 0, 0.01)).isEmpty)
    #expect(t.activeCount == 0)
    #expect(t.handle(ev(2, .moved, 60, 0, 0.02)).isEmpty, "a forgotten pointer emits nothing")
}

@Test func eleventhPointerIsIgnored() {
    var t = PointerVelocityTracker(spacing: 10)
    for id in 0..<10 { _ = t.handle(ev(id, .began, 0, 0, 0)) }
    #expect(t.handle(ev(10, .began, 0, 0, 0)).isEmpty)
    #expect(t.ignoredPointers == 1)
    #expect(t.handle(ev(10, .moved, 5, 0, 0.1)).isEmpty)
    #expect(t.activeCount == 10)
}

@Test func invalidConfigurationFallsBack() {
    let t = PointerVelocityTracker(spacing: -1, maxSamplesPerUpdate: 0, smoothing: 7)
    #expect(t.spacing == 1 && t.maxSamplesPerUpdate == 1 && t.smoothing == 0.5)
    #expect(PointerVelocityTracker(spacing: 2, maxSamplesPerUpdate: 9999).maxSamplesPerUpdate == 256)
}
