// GestureTests — feature 006 T-F506 (FR-F502, SC-F503: every transition incl. cancel and fail; US1 AC3/AC4).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

/// Feeds events through a tracker into recognizers, as an adapter would.
struct Driver {
    var tracker = PointerTracker()
    @discardableResult
    mutating func send<R: GestureRecognizer>(_ r: inout R, _ id: Int, _ phase: PointerPhase, _ x: Double, _ y: Double, t: Double) -> GestureState {
        let e = PointerEvent(id: id, phase: phase, location: Vec2(x, y), timestamp: t)
        tracker.handle(e)
        r.handle(e, tracker: tracker)
        return r.state
    }
    mutating func send2<A: GestureRecognizer, B: GestureRecognizer>(_ a: inout A, _ b: inout B, _ id: Int, _ phase: PointerPhase,
                                                                    _ x: Double, _ y: Double, t: Double) {
        let e = PointerEvent(id: id, phase: phase, location: Vec2(x, y), timestamp: t)
        tracker.handle(e)
        a.handle(e, tracker: tracker)
        b.handle(e, tracker: tracker)
    }
}

// MARK: Tap

@Test func tapRecognizedAndRestartsAfterwards() {
    var d = Driver(), r = TapRecognizer()
    #expect(d.send(&r, 1, .began, 50, 50, t: 0) == .possible)
    #expect(d.send(&r, 1, .moved, 55, 52, t: 0.1) == .possible)
    #expect(d.send(&r, 1, .ended, 55, 52, t: 0.2) == .recognized)
    #expect(r.location == Vec2(55, 52))
    #expect(d.send(&r, 2, .began, 10, 10, t: 1) == .possible, "terminal state resets on the next first finger")
    #expect(d.send(&r, 2, .ended, 10, 10, t: 1.1) == .recognized)
}

@Test func tapFailsOnMovementDurationTimeoutAndSecondFinger() {
    var d = Driver(), r = TapRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0)
    #expect(d.send(&r, 1, .moved, 11, 0, t: 0.05) == .failed, "beyond 10 pt")
    d.send(&r, 1, .ended, 11, 0, t: 0.1)

    d = Driver(); r = TapRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0)
    #expect(d.send(&r, 1, .ended, 0, 0, t: 0.31) == .failed, "longer than 0.3 s")

    d = Driver(); r = TapRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0)
    r.tick(now: 0.29); #expect(r.state == .possible)
    r.tick(now: 0.31); #expect(r.state == .failed, "times out without an event")

    d = Driver(); r = TapRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0)
    #expect(d.send(&r, 2, .began, 40, 0, t: 0.05) == .failed, "a second finger fails a pending tap")
}

@Test func tapCancelledBySystemReportsNoTap() {
    // AC4: a cancelled touch → cancelled, no tap.
    var d = Driver(), r = TapRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0)
    #expect(d.send(&r, 1, .cancelled, 0, 0, t: 0.1) == .cancelled)
    #expect(r.location == nil)
}

// MARK: Double tap

@Test func doubleTapRecognizedWithinIntervalAndDistance() {
    var d = Driver(), r = DoubleTapRecognizer()
    d.send(&r, 1, .began, 100, 100, t: 0); d.send(&r, 1, .ended, 100, 100, t: 0.1)
    #expect(r.state == .possible)
    d.send(&r, 2, .began, 120, 110, t: 0.35)
    #expect(d.send(&r, 2, .ended, 120, 110, t: 0.4) == .recognized)
    #expect(r.location == Vec2(120, 110))
}

@Test func doubleTapFailsWhenLateFarOrAbandoned() {
    var d = Driver(), r = DoubleTapRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0); d.send(&r, 1, .ended, 0, 0, t: 0.1)
    #expect(d.send(&r, 2, .began, 0, 0, t: 0.41) == .failed, "second tap starts > 0.3 s after the first ended")

    d = Driver(); r = DoubleTapRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0); d.send(&r, 1, .ended, 0, 0, t: 0.1)
    d.send(&r, 2, .began, 31, 0, t: 0.2)
    #expect(d.send(&r, 2, .ended, 31, 0, t: 0.25) == .failed, "more than 30 pt apart")

    d = Driver(); r = DoubleTapRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0); d.send(&r, 1, .ended, 0, 0, t: 0.1)
    r.tick(now: 0.39); #expect(r.state == .possible)
    r.tick(now: 0.41); #expect(r.state == .failed, "no second tap arrives")

    d = Driver(); r = DoubleTapRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0)
    #expect(d.send(&r, 1, .cancelled, 0, 0, t: 0.05) == .cancelled)
}

// MARK: Long press

@Test func longPressRecognizedByTickOrEvent() {
    var d = Driver(), r = LongPressRecognizer()
    d.send(&r, 1, .began, 10, 10, t: 0)
    r.tick(now: 0.49); #expect(r.state == .possible)
    r.tick(now: 0.5); #expect(r.state == .recognized)
    #expect(r.location == Vec2(10, 10))

    d = Driver(); r = LongPressRecognizer()
    d.send(&r, 1, .began, 10, 10, t: 0)
    #expect(d.send(&r, 1, .moved, 12, 10, t: 0.6) == .recognized, "a later event completes the hold")
}

@Test func longPressFailsOrCancels() {
    var d = Driver(), r = LongPressRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0)
    #expect(d.send(&r, 1, .ended, 0, 0, t: 0.3) == .failed, "lifted early")

    d = Driver(); r = LongPressRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0)
    #expect(d.send(&r, 1, .moved, 0, 10.5, t: 0.2) == .failed, "moved beyond 10 pt")

    d = Driver(); r = LongPressRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0)
    #expect(d.send(&r, 2, .began, 50, 0, t: 0.1) == .failed, "second finger")

    d = Driver(); r = LongPressRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0)
    #expect(d.send(&r, 1, .cancelled, 0, 0, t: 0.2) == .cancelled)
}

// MARK: Drag

@Test func dragBeginsAfterThresholdChangesAndEnds() {
    var d = Driver(), r = DragRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0)
    #expect(d.send(&r, 1, .moved, 9, 0, t: 0.1) == .possible)
    #expect(d.send(&r, 1, .moved, 12, 0, t: 0.2) == .began)
    #expect(d.send(&r, 1, .moved, 32, 0, t: 0.3) == .changed)
    #expect(r.translation == Vec2(32, 0))
    #expect(abs(r.velocity.x - 200) < 1e-9, "20 pt in 0.1 s")
    #expect(d.send(&r, 1, .ended, 32, 0, t: 0.4) == .ended)
}

@Test func dragFailsOrIsCancelled() {
    var d = Driver(), r = DragRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0)
    #expect(d.send(&r, 1, .ended, 5, 0, t: 0.1) == .failed, "never crossed the threshold")

    d = Driver(); r = DragRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0); d.send(&r, 1, .moved, 20, 0, t: 0.1)
    #expect(d.send(&r, 2, .began, 100, 0, t: 0.2) == .cancelled, "a second finger cancels an active drag")

    d = Driver(); r = DragRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0)
    #expect(d.send(&r, 2, .began, 100, 0, t: 0.1) == .failed, "a second finger fails a pending drag")

    d = Driver(); r = DragRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0); d.send(&r, 1, .moved, 20, 0, t: 0.1)
    #expect(d.send(&r, 1, .cancelled, 20, 0, t: 0.2) == .cancelled, "system cancel")

    d = Driver(); r = DragRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0)
    #expect(d.send(&r, 1, .cancelled, 0, 0, t: 0.1) == .failed, "cancel before it began")
}

// MARK: Pinch and rotate

@Test func pinchScaleIsDistanceRatio() {
    // AC3: fingers 100 pt apart move to 200 pt apart → scale 2.0.
    var d = Driver(), r = PinchRecognizer()
    d.send(&r, 1, .began, 100, 300, t: 0)
    #expect(d.send(&r, 2, .began, 200, 300, t: 0.01) == .possible)
    #expect(d.send(&r, 2, .moved, 250, 300, t: 0.1) == .began)
    #expect(d.send(&r, 1, .moved, 50, 300, t: 0.2) == .changed)
    #expect(abs(r.scale - 2.0) < 1e-12)
    #expect(r.center == Vec2(150, 300))
    #expect(d.send(&r, 1, .ended, 50, 300, t: 0.3) == .ended)
    d.send(&r, 2, .ended, 250, 300, t: 0.31)
    #expect(r.state == .ended)
}

@Test func pinchCancelsAndFails() {
    var d = Driver(), r = PinchRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0); d.send(&r, 2, .began, 100, 0, t: 0)
    d.send(&r, 2, .moved, 150, 0, t: 0.1)
    #expect(d.send(&r, 2, .cancelled, 150, 0, t: 0.2) == .cancelled)

    d = Driver(); r = PinchRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0)
    #expect(d.send(&r, 1, .ended, 0, 0, t: 0.1) == .failed, "one finger is not a pinch")

    d = Driver(); r = PinchRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0); d.send(&r, 2, .began, 100, 0, t: 0)
    #expect(d.send(&r, 2, .ended, 100, 0, t: 0.1) == .failed, "lifted before any change")
}

@Test func pinchAndRotateRunSimultaneously() {
    var d = Driver(), pinch = PinchRecognizer(), rotate = RotateRecognizer()
    d.send2(&pinch, &rotate, 1, .began, 100, 100, t: 0)
    d.send2(&pinch, &rotate, 2, .began, 200, 100, t: 0)
    // Finger 2 moves to directly above finger 1 (screen y-down): a 90° counter-clockwise turn, distance unchanged.
    d.send2(&pinch, &rotate, 2, .moved, 100, 0, t: 0.1)
    #expect(rotate.state == .began)
    #expect(abs(rotate.angle - .pi / 2) < 1e-12)
    #expect(abs(pinch.scale - 1) < 1e-12)
    d.send2(&pinch, &rotate, 2, .moved, 100, -100, t: 0.2)
    #expect(pinch.state.isActive && rotate.state == .changed)
    #expect(abs(pinch.scale - 2) < 1e-12)
    d.send2(&pinch, &rotate, 1, .ended, 100, 100, t: 0.3)
    #expect(pinch.state == .ended && rotate.state == .ended)
}

@Test func rotateCancelsAndFails() {
    var d = Driver(), r = RotateRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0); d.send(&r, 2, .began, 100, 0, t: 0)
    d.send(&r, 2, .moved, 100, 50, t: 0.1)
    #expect(r.angle < 0, "clockwise on screen is negative")
    #expect(d.send(&r, 1, .cancelled, 0, 0, t: 0.2) == .cancelled)

    d = Driver(); r = RotateRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0)
    #expect(d.send(&r, 1, .ended, 0, 0, t: 0.1) == .failed)
}

@Test func thirdFingerDoesNotDisturbTwoFingerGesture() {
    var d = Driver(), r = PinchRecognizer()
    d.send(&r, 1, .began, 0, 0, t: 0); d.send(&r, 2, .began, 100, 0, t: 0)
    d.send(&r, 2, .moved, 200, 0, t: 0.1)
    d.send(&r, 3, .began, 500, 500, t: 0.15)
    d.send(&r, 3, .moved, 900, 900, t: 0.2)
    #expect(abs(r.scale - 2) < 1e-12)
    #expect(d.send(&r, 3, .ended, 900, 900, t: 0.25) == .began, "still the active pinch from its first change")
}
