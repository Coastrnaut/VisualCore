// FramingFlightTests and TourTimelineTests — feature 029 T-A03-402 (FR-A03-402, SC-A03-402; contract capture-tour-cost).
import Foundation
import Testing
@testable import VisualCoreMath

@Suite struct FramingFlightTests {
    let home = PlaneFraming(center: Vec2(-0.5, 0), span: 4)
    let seahorse = PlaneFraming(center: Vec2(-0.743643887, 0.131825904), span: 0.002)

    @Test func endsExactlyAndStartsAtTheStart() {
        let f = FramingFlight(from: home, to: seahorse)
        #expect(f.framing(at: 1) == seahorse)
        #expect(f.framing(at: 2) == seahorse)
        #expect(f.framing(at: 0) == home)
        #expect(f.framing(at: .nan) == home)
    }

    @Test func logSpanIsMonotonic() {
        for curve in EasingCurve.allCases {
            let f = FramingFlight(from: home, to: seahorse)
            var last = log(home.span)
            for i in 1...100 {
                let s = log(f.framing(at: Double(i) / 100, curve: curve).span)
                #expect(s <= last + 1e-12, "curve \(curve) step \(i)")
                last = s
            }
        }
    }

    @Test func targetStaysInViewAtEverySample() {
        for (from, to) in [(home, seahorse), (seahorse, home), (home, PlaneFraming(center: Vec2(0.3, 0.1), span: 1e-6))] {
            let f = FramingFlight(from: from, to: to)
            #expect(from.center.distance(to: to.center) <= max(from.span, to.span) / 2)
            for i in 0...100 {
                let v = f.framing(at: Double(i) / 100)
                // The point of interest: the target when zooming in, the start when zooming out.
                let focus = to.span <= from.span ? to.center : from.center
                let offset = v.center.distance(to: focus)
                #expect(offset <= v.span / 2 * (1 + 1e-9), "sample \(i): offset \(offset) span \(v.span)")
            }
        }
    }

    @Test func equalSpansMoveLinearly() {
        let a = PlaneFraming(center: Vec2(0, 0), span: 1), b = PlaneFraming(center: Vec2(0.4, 0), span: 1)
        let f = FramingFlight(from: a, to: b)
        #expect(f.framing(at: 0.5).span == 1)
        #expect(abs(f.framing(at: 0.5).center.x - 0.2) < 1e-12)
    }

    @Test func routeViaContainingFramingWhenTargetIsOutside() {
        let a = PlaneFraming(center: Vec2(-1.75, 0), span: 0.01)
        let b = PlaneFraming(center: Vec2(0.282, 0.0105), span: 0.02)
        let legs = FramingFlight.route(from: a, to: b)
        #expect(legs.count == 2)
        let mid = legs[0].to
        #expect(mid.center == (a.center + b.center) / 2)
        #expect(mid.span >= 2 * a.center.distance(to: b.center))
        #expect(mid.center.distance(to: a.center) <= mid.span / 2 && mid.center.distance(to: b.center) <= mid.span / 2)
        #expect(legs[1].to == b)
        #expect(FramingFlight.route(from: home, to: seahorse).count == 1)
    }
}

@Suite struct TourTimelineTests {
    let start = PlaneFraming(center: Vec2(-0.5, 0), span: 4)
    var stops: [TourTimeline.Stop] {
        [TourTimeline.Stop(framing: PlaneFraming(center: Vec2(-0.75, 0.1), span: 0.5), hold: 3),
         TourTimeline.Stop(framing: PlaneFraming(center: Vec2(-0.7436, 0.1318), span: 0.01), hold: 3)]
    }

    @Test func phasesAndStopsOverTime() {
        let t = TourTimeline(start: start, stops: stops, flightDuration: 4, reduceMotion: false)
        #expect(t.duration == 14)
        #expect(t.state(at: 0).phase == .flying)
        #expect(t.state(at: 2).stopIndex == 0)
        #expect(t.state(at: 4.5) == TourTimeline.State(framing: stops[0].framing, stopIndex: 0, phase: .holding))
        #expect(t.state(at: 7.5).phase == .flying)
        #expect(t.state(at: 7.5).stopIndex == 1)
        #expect(t.state(at: 12) == TourTimeline.State(framing: stops[1].framing, stopIndex: 1, phase: .holding))
    }

    @Test func finishedKeepsTheLastStop() {
        let t = TourTimeline(start: start, stops: stops, flightDuration: 4, reduceMotion: false)
        #expect(t.state(at: 100) == TourTimeline.State(framing: stops[1].framing, stopIndex: 1, phase: .finished))
    }

    @Test func reduceMotionJumps() {
        let t = TourTimeline(start: start, stops: stops, flightDuration: 4, reduceMotion: true)
        #expect(t.duration == 6)
        #expect(t.state(at: 0) == TourTimeline.State(framing: stops[0].framing, stopIndex: 0, phase: .holding))
        #expect(t.state(at: 3.1).framing == stops[1].framing)
    }

    @Test func flightsAreContinuousAndRouted() {
        let far = [TourTimeline.Stop(framing: PlaneFraming(center: Vec2(-1.75, 0), span: 0.01), hold: 1),
                   TourTimeline.Stop(framing: PlaneFraming(center: Vec2(0.282, 0.0105), span: 0.01), hold: 1)]
        let t = TourTimeline(start: start, stops: far, flightDuration: 4, reduceMotion: false)
        var last = t.state(at: 0).framing
        for i in 1...1000 {
            let f = t.state(at: Double(i) * t.duration / 1000).framing
            // Neighbouring samples never jump by more than the larger view (continuity on screen).
            #expect(f.center.distance(to: last.center) <= max(f.span, last.span), "sample \(i)")
            last = f
        }
        #expect(TourTimeline(start: start, stops: [], flightDuration: .nan, reduceMotion: false).stops.count == 1)
    }
}
