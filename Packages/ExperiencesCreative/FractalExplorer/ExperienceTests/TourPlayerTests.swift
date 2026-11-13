// TourPlayerTests — feature 029 T-A03-409 (FR-A03-406, SC-A03-402; US3 AC1–AC4; analyze G1).
import FractalExplorerCore
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
import XCTest
@testable import FractalExplorerExperience

@MainActor
final class TourPlayerTests: XCTestCase {
    private func model(reduceMotion: Bool = false) -> ExplorerModel {
        let m = ExplorerModel(size: Vec2(390, 844), system: SystemAccessibility(reduceMotion: reduceMotion),
                              bookmarksDirectory: FileManager.default.temporaryDirectory.appendingPathComponent("fe-tour-\(UUID().uuidString)"))
        m.close()
        m.mantissaBitsOverride = 23
        m.pixelsPerPointOverride = 3
        return m
    }

    private func framing(_ m: ExplorerModel) -> PlaneFraming { PlaneFraming(m.state.viewport) }

    func testTicksReachEveryStopAnnounceOnceAndFinish() throws {
        let m = model()
        let tour = try XCTUnwrap(FractalTours.tour("seahorse"))
        m.startTour("seahorse", now: 100)
        XCTAssertTrue(m.tour.isPlaying)
        XCTAssertNil(m.tour.caption, "no caption while flying to the first stop")
        for i in 0...210 { m.tourTick(now: 100 + Double(i) * 0.1) }   // 21 s of ticks
        XCTAssertFalse(m.tour.isPlaying)
        XCTAssertEqual(framing(m).center, tour.stops[2].framing.center)
        XCTAssertEqual(framing(m).span, tour.stops[2].framing.span, accuracy: tour.stops[2].framing.span * 1e-12)
        XCTAssertEqual(m.tour.announcements, tour.stops.map(\.caption), "each caption announced once")
        XCTAssertEqual(m.tour.caption, tour.stops[2].caption)
        XCTAssertEqual(m.notice, .none, "tour stops are within precision")
    }

    func testFlightIsSmoothOnTheLogScale() {
        let m = model()
        m.startTour("elephant", now: 0)
        var last = log(framing(m).span)
        for i in 1...40 {
            m.tourTick(now: Double(i) * 0.1)   // the first 4 s flight
            let s = log(framing(m).span)
            XCTAssertLessThanOrEqual(s, last + 1e-9)
            last = s
        }
    }

    func testReduceMotionJumps() throws {
        let m = model(reduceMotion: true)
        let tour = try XCTUnwrap(FractalTours.tour("mini"))
        m.startTour("mini", now: 0)
        XCTAssertEqual(framing(m).center, tour.stops[0].framing.center, "no flight: the first stop at once")
        XCTAssertEqual(m.tour.caption, tour.stops[0].caption)
        m.tourTick(now: 3.5)
        XCTAssertEqual(framing(m).center, tour.stops[1].framing.center)
    }

    func testTouchStopsAndKeepsTheView() {
        let m = model()
        m.startTour("seahorse", now: 0)
        m.tourTick(now: 2)
        let during = m.state.viewport
        m.handle(PointerEvent(id: 1, phase: .began, location: Vec2(100, 100), timestamp: 2))
        m.handle(PointerEvent(id: 1, phase: .ended, location: Vec2(100, 100), timestamp: 2.1))
        XCTAssertFalse(m.tour.isPlaying)
        m.tourTick(now: 10)
        XCTAssertEqual(m.state.viewport, during, "the view stays where the tour was stopped")
    }

    func testStopButtonAndZoomStopTheTour() {
        let m = model()
        m.startTour("seahorse", now: 0)
        m.tourTick(now: 5)
        m.stopTour()
        XCTAssertFalse(m.tour.isPlaying)
        XCTAssertNotNil(m.tour.caption, "Stop keeps the reached caption")
        m.startTour("seahorse", now: 10)
        m.zoomIn()
        XCTAssertFalse(m.tour.isPlaying)
        XCTAssertNil(m.tour.caption)
    }

    func testCapChangeDuringATourAppliesAndTheTourContinues() {
        let m = model()
        m.startTour("seahorse", now: 0)
        m.tourTick(now: 1)
        m.doubleCap()
        XCTAssertEqual(m.cap, 400)
        XCTAssertTrue(m.tour.isPlaying)
        m.tourTick(now: 5)
        XCTAssertEqual(m.scene.snapshot.state.iterationCap, 400)
        XCTAssertTrue(m.tour.isPlaying)
    }

    func testJuliaSwitchesToMandelbrotAndAUserModeChangeStops() {
        let m = model()
        m.state.mode = .julia
        m.startTour("mini", now: 0)
        XCTAssertEqual(m.state.mode, .mandelbrot)
        XCTAssertTrue(m.tour.isPlaying)
        m.state.mode = .julia
        XCTAssertFalse(m.tour.isPlaying)
    }
}
