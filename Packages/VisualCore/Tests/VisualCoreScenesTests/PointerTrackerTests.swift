// PointerTrackerTests — feature 006 T-F505 (FR-F502, FR-F512, edge case > 10 touches).
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

private func ev(_ id: Int, _ phase: PointerPhase, _ x: Double = 0, _ y: Double = 0, t: Double = 0) -> PointerEvent {
    PointerEvent(id: id, phase: phase, location: Vec2(x, y), timestamp: t)
}

@Test func tracksBeganMovedEnded() {
    var t = PointerTracker()
    do { let r = t.handle(ev(1, .began, 10, 20)); #expect(r) }
    do { let r = t.handle(ev(1, .moved, 15, 25)); #expect(r) }
    #expect(t.active[1] == Vec2(15, 25))
    #expect(t.start[1] == Vec2(10, 20))
    do { let r = t.handle(ev(1, .ended)); #expect(r) }
    #expect(t.count == 0)
    do { let r = t.handle(ev(1, .moved)); #expect(!r, "moves of unknown ids are ignored") }
}

@Test func eleventhTouchIsIgnoredAndCounted() {
    var t = PointerTracker()
    for i in 0..<10 { let r = t.handle(ev(i, .began, Double(i), 0)); #expect(r) }
    do { let r = t.handle(ev(10, .began)); #expect(!r) }
    do { let r = t.handle(ev(10, .moved, 5, 5)); #expect(!r) }
    #expect(t.ignored == 1)
    #expect(t.count == 10)
    do { let r = t.handle(ev(10, .ended)); #expect(!r, "an ignored touch's end does not remove anything") }
    #expect(t.count == 10)
    do { let r = t.handle(ev(3, .cancelled)); #expect(r) }
    do { let r = t.handle(ev(11, .began)); #expect(r, "a slot frees up after a touch ends") }
    #expect(t.order.last == 11)
}

@Test func cancelRemovesAndCentroidAverages() {
    var t = PointerTracker()
    t.handle(ev(1, .began, 0, 0)); t.handle(ev(2, .began, 10, 20))
    #expect(t.centroid == Vec2(5, 10))
    t.handle(ev(2, .cancelled))
    #expect(t.centroid == Vec2(0, 0))
    t.handle(ev(1, .ended))
    #expect(t.centroid == nil)
}

@Test func rejectsNonFiniteAndDuplicateBegins() {
    var t = PointerTracker()
    do { let r = t.handle(ev(1, .began, .nan, 0)); #expect(!r) }
    do { let r = t.handle(ev(1, .began)); #expect(r) }
    do { let r = t.handle(ev(1, .began)); #expect(!r) }
    do { let r = t.handle(ev(1, .moved, .infinity, 0)); #expect(!r) }
    #expect(t.active[1] == .zero)
}
