// FocusFlightTests — feature 105 (A14-P03) T-A14-307 (FR-A14-320, FR-A14-321; SC-A14-303; clarification Q4; research
// D4). The focus flight, no GPU: for both scale modes on day 0 at yaw 0 and pitch 35°, all 72 ordered pairs of the
// nine bodies at zoom steps 0 and 12, every frame 0…30 keeps the cleared eye outside every body's drawn radius and the
// focused body inside the mode's near and far planes at the end; Reduce Motion cuts to the new view at once; a restart
// begins at the view drawn mid-flight; frames are clamped; smoothstep and the log-space distance.
import Foundation
import XCTest
@testable import SolarSystemExplorerExperience
import SolarSystemExplorerCore
import VisualCoreMath

final class FocusFlightTests: XCTestCase {
    private let pitch = 35.0 * Double.pi / 180
    private let yaw = 0.0

    /// The view focused on `index`: its scene centre at the mode's camera distance, raised to its clearance.
    private func view(focus index: Int, bodies: [FocusFlight.Body], mode: ScaleMode,
                      zoomSteps: Int) -> FocusFlight.View {
        let distance = mode.cameraDistance(zoomSteps: zoomSteps)
        let near = mode.clipRange(distance: distance).near
        let clearance = FocusFlight.clearance(radius: bodies[index].radius, near: near)
        return FocusFlight.View(target: bodies[index].center, distance: max(distance, clearance))
    }

    func testEveryOrderedPairKeepsTheEyeOutsideAndTheFocusInsideTheDepthRange() {
        let zooms: [Int] = [0, 12]
        for mode in ScaleMode.allCases {
            let bodies = FocusFlight.bodies(mode: mode, day: 0)
            XCTAssertEqual(bodies.count, 9)
            for zoom in zooms {
                var pairs = 0
                for i in 0..<bodies.count {
                    for j in 0..<bodies.count where j != i {
                        pairs += 1
                        let from = view(focus: i, bodies: bodies, mode: mode, zoomSteps: zoom)
                        let to = view(focus: j, bodies: bodies, mode: mode, zoomSteps: zoom)
                        let flight = FocusFlight(from: from, to: to)
                        for frame in 0...FocusFlight.frameCount {
                            let drawn = flight.view(at: frame)
                            let near = mode.clipRange(distance: drawn.distance).near
                            let eye = flight.eye(at: frame, yaw: yaw, pitch: pitch, bodies: bodies, near: near)
                            for (k, body) in bodies.enumerated() {
                                let gap = (eye - body.center).length
                                if gap <= body.radius {
                                    XCTFail("\(mode) zoom \(zoom) \(i)→\(j) frame \(frame): eye inside body \(k)")
                                }
                            }
                        }
                        let final = flight.view(at: FocusFlight.frameCount)
                        let range = mode.clipRange(distance: final.distance)
                        let eye = flight.eye(at: FocusFlight.frameCount, yaw: yaw, pitch: pitch, bodies: bodies,
                                             near: range.near)
                        XCTAssertTrue(FocusFlight.isInsideDepth(target: bodies[j].center, eye: eye, near: range.near,
                                                                far: range.far, focusedRadius: bodies[j].radius),
                                      "\(mode) zoom \(zoom) \(i)→\(j): focused body outside near…far")
                    }
                }
                XCTAssertEqual(pairs, 72)
            }
        }
    }

    func testReduceMotionCutsToTheNewViewAtOnce() {
        let from = FocusFlight.View(target: Vec3(1, 2, 3), distance: 60)
        let to = FocusFlight.View(target: Vec3(-4, 0, 5), distance: 10)
        let flight = FocusFlight(from: from, to: to, reduceMotion: true)
        for frame in 0...FocusFlight.frameCount {
            XCTAssertEqual(flight.view(at: frame), to, "frame \(frame)")
        }
        XCTAssertTrue(flight.isFinished(at: 0))
        XCTAssertFalse(FocusFlight(from: from, to: to).isFinished(at: 0))
    }

    func testRestartBeginsAtTheViewDrawnMidFlight() {
        let a = FocusFlight.View(target: Vec3(0, 0, 0), distance: 60)
        let b = FocusFlight.View(target: Vec3(10, 0, -3), distance: 20)
        let c = FocusFlight.View(target: Vec3(-8, 1, 6), distance: 40)
        let first = FocusFlight(from: a, to: b)
        let current = first.view(at: 12)
        XCTAssertNotEqual(current, a)
        XCTAssertNotEqual(current, b)
        let second = first.restarted(from: current, to: c)
        XCTAssertEqual(second.view(at: 0), current)
        XCTAssertEqual(second.view(at: FocusFlight.frameCount), c)
        XCTAssertFalse(second.reduceMotion)
        let reduced = FocusFlight(from: a, to: b, reduceMotion: true).restarted(from: current, to: c)
        XCTAssertTrue(reduced.reduceMotion)
        XCTAssertEqual(reduced.view(at: 0), c)
    }

    func testFramesAreClampedAndEndpointsExact() {
        let from = FocusFlight.View(target: Vec3(0.1, 0.2, 0.3), distance: 7)
        let to = FocusFlight.View(target: Vec3(5, -1, 2), distance: 90)
        let flight = FocusFlight(from: from, to: to)
        XCTAssertEqual(flight.view(at: -5), from)
        XCTAssertEqual(flight.view(at: 0), from)
        XCTAssertEqual(flight.view(at: FocusFlight.frameCount), to)
        XCTAssertEqual(flight.view(at: 99), to)
        XCTAssertTrue(flight.isFinished(at: FocusFlight.frameCount))
    }

    func testSmoothstepAndLogSpaceDistance() {
        XCTAssertEqual(FocusFlight.smoothstep(0), 0)
        XCTAssertEqual(FocusFlight.smoothstep(1), 1)
        XCTAssertEqual(FocusFlight.smoothstep(0.5), 0.5, accuracy: 1e-15)
        XCTAssertEqual(FocusFlight.smoothstep(-1), 0)
        XCTAssertEqual(FocusFlight.smoothstep(2), 1)
        var previous = -1.0
        for k in 0...100 {
            let s = FocusFlight.smoothstep(Double(k) / 100)
            XCTAssertGreaterThanOrEqual(s, previous)
            previous = s
        }
        // Frame 15 is t = 0.5, s = 0.5: the distance is the geometric mean and the target the midpoint.
        let flight = FocusFlight(from: FocusFlight.View(target: Vec3(0, 0, 0), distance: 10),
                                 to: FocusFlight.View(target: Vec3(4, 0, 0), distance: 90))
        let middle = flight.view(at: 15)
        XCTAssertEqual(middle.distance, 30, accuracy: 1e-9)
        XCTAssertEqual(middle.target.x, 2, accuracy: 1e-12)
    }

    func testClearancePushesTheEyeOutRadially() {
        let body = FocusFlight.Body(center: Vec3(1, 0, 0), radius: 0.5)
        // Clearance 3 × 0.5 + 0.5 × 0.5 = 1.75.
        let eye = FocusFlight.clearedEye(Vec3(1, 1, 0), direction: Vec3(0, 0, 1), bodies: [body], near: 0.5)
        XCTAssertEqual((eye - body.center).length, 1.75, accuracy: 1e-12)
        XCTAssertEqual(eye.x, 1, accuracy: 1e-12)
        let atCentre = FocusFlight.clearedEye(body.center, direction: Vec3(0, 0, 2), bodies: [body], near: 0.5)
        XCTAssertEqual(atCentre.z, 1.75, accuracy: 1e-12)
        let outside = Vec3(1, 3, 0)
        XCTAssertEqual(FocusFlight.clearedEye(outside, direction: Vec3(0, 1, 0), bodies: [body], near: 0.5), outside)
    }
}
