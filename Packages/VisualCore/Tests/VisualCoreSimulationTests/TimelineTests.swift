// TimelineTests — feature 006 T-F510 (FR-F505; US2 AC4; edge case zero duration; Reduce Motion clarification).
import Testing
import VisualCoreMath
@testable import VisualCoreSimulation

private func near(_ a: Double?, _ b: Double, _ eps: Double = 1e-12) -> Bool { a.map { abs($0 - b) <= eps } ?? false }

@Test func easeInOutTweenSamples() {
    // AC4: ease-in-out 0→1 over 1 s at 0, 0.5, 1 s.
    var tl = Timeline()
    tl.add(Tween(from: 0, to: 1, duration: 1, curve: .cubic, mode: .inOut), name: "x")
    #expect(near(tl.value(of: "x"), 0))
    tl.advance(by: 0.5); #expect(near(tl.value(of: "x"), 0.5))
    tl.advance(by: 0.5); #expect(near(tl.value(of: "x"), 1))
    #expect(tl.value(of: "missing") == nil)
}

@Test func pauseResumeReverseAndSeek() {
    var tl = Timeline()
    tl.add(Tween(from: 10, to: 20, duration: 2), name: "x")
    tl.advance(by: 0.5)
    tl.isPaused = true
    #expect(tl.advance(by: 5) == [])
    #expect(near(tl.value(of: "x"), 12.5))
    tl.isPaused = false
    tl.advance(by: 0.5); #expect(near(tl.value(of: "x"), 15))
    tl.rate = -1
    tl.advance(by: 0.25); #expect(near(tl.value(of: "x"), 13.75))
    tl.seek(to: 1.5); #expect(near(tl.value(of: "x"), 17.5))
    tl.seek(to: 99); #expect(tl.time == 2)
    tl.rate = 2
    #expect(tl.advance(by: .nan) == [] && tl.advance(by: -1) == [])
}

@Test func repeatsAndAutoreverse() {
    let t = Tween(from: 0, to: 10, duration: 1, repeatCount: 3, autoreverses: true)
    #expect(t.totalDuration == 3)
    #expect(near(t.value(at: 0.25), 2.5))
    #expect(near(t.value(at: 1.25), 7.5), "second pass runs back")
    #expect(near(t.value(at: 2.25), 2.5))
    #expect(t.value(at: 3) == 10 && t.finalValue == 10)
    #expect(Tween(from: 0, to: 10, duration: 1, repeatCount: 2, autoreverses: true).finalValue == 0)
    let forever = Tween(from: 0, to: 1, duration: 1, repeatCount: nil)
    #expect(forever.totalDuration == nil)
    #expect(near(forever.value(at: 1_000.5), 0.5))
    #expect(Tween(from: 0, to: 1, duration: 1, repeatCount: 0).repeatCount == 1, "at least one pass")
}

@Test func completionEventsFireOncePerPass() {
    var tl = Timeline()
    tl.add(Tween(from: 0, to: 1, duration: 1), name: "a")
    tl.add(Tween(from: 0, to: 1, duration: 1), at: 0.5, name: "b")
    #expect(tl.duration == 1.5)
    #expect(tl.advance(by: 0.9) == [])
    #expect(tl.advance(by: 0.2) == [.completed("a")])
    #expect(tl.advance(by: 1) == [.completed("b"), .finished])
    #expect(tl.advance(by: 1) == [], "nothing fires twice at the end")
    tl.rate = -1
    #expect(tl.advance(by: 1.2) == [.returnedToStart("b")])
    #expect(tl.advance(by: 1) == [.returnedToStart("a"), .finished])
    tl.rate = 1
    #expect(tl.advance(by: 2) == [.completed("a"), .completed("b"), .finished], "a new pass fires again")
}

@Test func zeroDurationJumpsToEnd() {
    var tl = Timeline()
    tl.add(Tween(from: 3, to: 7, duration: 0), name: "z")
    #expect(tl.value(of: "z") == 7)
    #expect(Tween(from: 3, to: 7, duration: -2).duration == 0)
    #expect(Tween(from: 3, to: 7, duration: .nan).value(at: 1) == 7)
}

@Test func reduceMotionJumpsToEndAndDisablesRepeats() {
    var tl = Timeline()
    tl.add(Tween(from: 0, to: 1, duration: 2, repeatCount: nil, autoreverses: true), name: "pulse")
    tl.add(Tween(from: 5, to: 9, duration: 1, repeatCount: 4, autoreverses: true), at: 1, name: "slide")
    #expect(tl.duration == .infinity)
    tl.reduceMotion = true
    #expect(tl.value(of: "pulse") == 1)
    #expect(tl.value(of: "slide") == 9, "end value, repeats ignored")
    #expect(tl.duration == 2)
    #expect(tl.advance(by: 1.0 / 60) == [.completed("pulse"), .completed("slide"), .finished])
}
