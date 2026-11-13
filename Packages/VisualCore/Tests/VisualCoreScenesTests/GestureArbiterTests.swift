// GestureArbiterTests — feature 226 (R02-F26) T-R02F26-002 (FR-R02F26-001…003, SC-R02F26-001; research R1).
// Eight recorded pointer sequences give fixed outcome lists (gesture ids and phases), identical over three runs.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

/// One recorded step: a pointer event or a clock tick.
private enum Step {
    case e(Int, PointerPhase, Double, Double, Double)
    case tick(Double)
}

/// The declarations a typical game uses: tap, double tap, long press, drag (one finger), pinch and rotate (two fingers).
private let standard: [GestureDeclaration] = [
    GestureDeclaration(id: "tap", kind: .tap, priority: 1, pointers: 1),
    GestureDeclaration(id: "press", kind: .longPress, priority: 2, pointers: 1),
    GestureDeclaration(id: "drag", kind: .drag, priority: 0, pointers: 1),
    GestureDeclaration(id: "pinch", kind: .pinch, priority: 3, pointers: 2),
]

/// Runs the steps through a fresh arbiter and returns every outcome in order.
private func run(_ declarations: [GestureDeclaration], _ steps: [Step]) -> [GestureOutcome] {
    var arbiter = GestureArbiter(declarations)
    var out: [GestureOutcome] = []
    for s in steps {
        switch s {
        case let .e(id, phase, x, y, t):
            out += arbiter.handle(PointerEvent(id: id, phase: phase, location: Vec2(x, y), timestamp: t))
        case let .tick(now):
            out += arbiter.tick(now: now)
        }
    }
    return out
}

/// Runs three times, checks the runs agree, and returns the (gesture, phase) pairs of the first.
private func phases(_ declarations: [GestureDeclaration], _ steps: [Step]) -> ([String], [GestureOutcome]) {
    let first = run(declarations, steps)
    for _ in 0..<2 { #expect(run(declarations, steps) == first, "deterministic over three runs") }
    return (first.map { "\($0.gesture).\($0.phase.rawValue)" }, first)
}

@Test func arbiterTap() {
    let (p, o) = phases(standard, [.e(1, .began, 50, 60, 0), .e(1, .moved, 52, 61, 0.05), .e(1, .ended, 52, 61, 0.1)])
    #expect(p == ["tap.recognized"])
    #expect(o.first?.values == [52, 61])
}

@Test func arbiterTapThatMovesBecomesDrag() {
    let (p, o) = phases(standard, [
        .e(1, .began, 0, 0, 0), .e(1, .moved, 5, 0, 0.02), .e(1, .moved, 25, 0, 0.04),
        .e(1, .moved, 40, 10, 0.06), .e(1, .ended, 40, 10, 0.08),
    ])
    #expect(p == ["drag.began", "drag.changed", "drag.ended"], "no tap is emitted")
    #expect(o[0].values == [25, 0, 25, 0])
    #expect(o[1].values == [40, 10, 40, 10])
}

@Test func arbiterDragThenSecondFingerBecomesPinch() {
    let (p, o) = phases(standard, [
        .e(1, .began, 100, 100, 0), .e(1, .moved, 130, 100, 0.02), .e(1, .moved, 140, 100, 0.04),
        .e(2, .began, 200, 100, 0.06),            // drag cancelled
        .e(2, .moved, 220, 100, 0.08),            // pinch began: 80 / 60
        .e(2, .moved, 260, 100, 0.10),            // pinch changed: 120 / 60
        .e(3, .began, 300, 300, 0.11), .e(3, .moved, 10, 10, 0.12), .e(3, .ended, 10, 10, 0.13),  // third finger ignored
        .e(2, .ended, 260, 100, 0.14), .e(1, .ended, 140, 100, 0.16),
    ])
    #expect(p == ["drag.began", "drag.changed", "drag.cancelled", "pinch.began", "pinch.changed", "pinch.ended"])
    #expect(abs(o[3].values[0] - 80.0 / 60.0) < 1e-12)
    #expect(abs(o[4].values[0] - 2.0) < 1e-12)
}

@Test func arbiterPinchReleasedToOneFingerEnds() {
    let (p, _) = phases(standard, [
        .e(1, .began, 100, 100, 0), .e(2, .began, 200, 100, 0.01),
        .e(2, .moved, 250, 100, 0.03), .e(1, .ended, 100, 100, 0.05),   // pinch ended
        .e(2, .moved, 300, 140, 0.07), .e(2, .moved, 340, 180, 0.09),   // the remaining finger sends nothing
        .e(2, .ended, 340, 180, 0.11),
        .e(4, .began, 10, 10, 1), .e(4, .ended, 10, 10, 1.05),          // everything reset: a new tap works
    ])
    #expect(p == ["pinch.began", "pinch.ended", "tap.recognized"])
}

@Test func arbiterLongPress() {
    let (p, o) = phases(standard, [.e(1, .began, 30, 40, 0), .tick(0.2), .tick(0.6), .e(1, .moved, 32, 40, 0.7),
                                   .e(1, .ended, 32, 40, 0.8)])
    #expect(p == ["press.recognized"])
    #expect(o.first?.values == [30, 40])
}

@Test func arbiterRotateVersusPinchByPriority() {
    let steps: [Step] = [
        .e(1, .began, 100, 100, 0), .e(2, .began, 200, 100, 0.01),
        .e(2, .moved, 200, 150, 0.03), .e(2, .moved, 150, 200, 0.05),
        .e(2, .ended, 150, 200, 0.07), .e(1, .ended, 100, 100, 0.09),
    ]
    let rotateFirst = [GestureDeclaration(id: "pinch", kind: .pinch, priority: 1, pointers: 2),
                       GestureDeclaration(id: "rotate", kind: .rotate, priority: 2, pointers: 2)]
    let (p1, o1) = phases(rotateFirst, steps)
    #expect(p1 == ["rotate.began", "rotate.changed", "rotate.ended"])
    #expect(abs(o1[0].values[0] - -atan2(50.0, 100.0)) < 1e-12)
    let pinchFirst = [GestureDeclaration(id: "pinch", kind: .pinch, priority: 2, pointers: 2),
                      GestureDeclaration(id: "rotate", kind: .rotate, priority: 2, pointers: 2)]  // tie: declaration order
    let (p2, _) = phases(pinchFirst, steps)
    #expect(p2 == ["pinch.began", "pinch.changed", "pinch.ended"])
}

@Test func arbiterCancelledTouchCancelsOwnerWithoutEnding() {
    let (p, _) = phases(standard, [
        .e(1, .began, 0, 0, 0), .e(1, .moved, 30, 0, 0.02), .e(1, .cancelled, 30, 0, 0.04),
        .e(2, .began, 5, 5, 1), .e(2, .ended, 5, 5, 1.05),
    ])
    #expect(p == ["drag.began", "drag.cancelled", "tap.recognized"], "no drag.ended after a cancelled touch")
}

@Test func arbiterIgnoresNonFiniteLocations() {
    let (p, _) = phases(standard, [
        .e(9, .began, .nan, 0, 0), .e(9, .ended, .nan, 0, 0.01),
        .e(1, .began, 0, 0, 0.1), .e(1, .moved, .infinity, 0, 0.12), .e(1, .ended, 1, 1, 0.15),
    ])
    #expect(p == ["tap.recognized"])
    var a = GestureArbiter(standard)
    #expect(a.handle(PointerEvent(id: 1, phase: .began, location: Vec2(.nan, .nan), timestamp: 0)).isEmpty)
}

@Test func arbiterCancelAllCancelsActiveOwner() {
    var a = GestureArbiter(standard)
    _ = a.handle(PointerEvent(id: 1, phase: .began, location: Vec2(0, 0), timestamp: 0))
    _ = a.handle(PointerEvent(id: 1, phase: .moved, location: Vec2(30, 0), timestamp: 0.02))
    #expect(a.cancelAll().map(\.phase) == [.cancelled])
    #expect(a.handle(PointerEvent(id: 1, phase: .ended, location: Vec2(30, 0), timestamp: 0.04)).isEmpty)
    #expect(a.cancelAll().isEmpty)
}
