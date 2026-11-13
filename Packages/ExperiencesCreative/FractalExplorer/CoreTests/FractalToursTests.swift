// FractalToursTests — feature 029 T-A03-408 (FR-A03-406; US3 AC1, AC4; research R7).
import Testing
import VisualCoreMath
@testable import FractalExplorerCore

@Suite struct FractalToursTests {
    @Test func threeToursWithValidStops() {
        #expect(FractalTours.all.map(\.id) == ["seahorse", "elephant", "mini"])
        for tour in FractalTours.all {
            #expect(tour.stops.count == 3)
            #expect(tour.mode == .mandelbrot)
            for stop in tour.stops {
                #expect(abs(stop.framing.center.x) <= 4 && abs(stop.framing.center.y) <= 4)
                #expect(stop.framing.span > 0)
                #expect(!stop.caption.isEmpty && stop.caption.count <= FractalTour.maxCaptionLength, "\(stop.caption)")
            }
            // Spans shrink: the tour zooms in.
            #expect(zip(tour.stops, tour.stops.dropFirst()).allSatisfy { $0.framing.span > $1.framing.span })
        }
    }

    @Test func everyStopIsWithin23BitPrecisionOnA3xDisplay() {
        for tour in FractalTours.all {
            for stop in tour.stops {
                for points in [320.0, 390.0, 1024.0] {
                    let v = stop.framing.viewport(size: Vec2(points, points * 1.6))
                    let status = PrecisionAdvisor.assess(mantissaBits: 23, magnitude: max(abs(v.center.x), abs(v.center.y)),
                                                         pixelStep: v.unitsPerPoint / 3)
                    #expect(status.level == .reliable, "\(tour.id) \(stop.caption.prefix(20)) at \(points) pt: margin \(status.margin)")
                }
            }
        }
    }

    @Test func timelineVisitsEveryStop() {
        let tour = FractalTours.tour("seahorse")!
        let t = tour.timeline(from: PlaneFraming(center: Vec2(-0.5, 0), span: 4), reduceMotion: false)
        #expect(t.duration == 3 * (FractalTour.flightSeconds + FractalTour.holdSeconds))
        #expect(t.state(at: 5).framing == tour.stops[0].framing)
        #expect(t.state(at: 100).framing == tour.stops[2].framing)
        let quick = tour.timeline(from: PlaneFraming(center: Vec2(-0.5, 0), span: 4), reduceMotion: true)
        #expect(quick.duration == 9)
        #expect(FractalTours.tour("none") == nil)
    }
}
