// CameraFramingTests — feature 125 (A17-P02) T-A17-203 (FR-A17-203, FR-A17-208; SC-A17-203; clarification Q3). The
// camera steps and framing: the opening view is turn 2, tilt 1, zoom 0; the turn wraps; every limit and any step
// other than ±1 is refused with the state unchanged; Reset view restores the opening view exactly; after framing each
// of the 14 parts (and the whole region) its sphere projects inside NDC ±1 at aspects 0.5 and 2, in front of the
// camera and between its near and far planes.
import Foundation
import Testing
import VisualCoreMath
@testable import InteractiveAnatomyCore

@Suite struct CameraFramingTests {
    /// True when the sphere at `center` with `radius` projects inside NDC ±1 through `camera` at `aspect`: its centre
    /// and the four points one radius along the view's right and up axes.
    private static func framingFits(_ camera: OrbitCamera, _ center: Vec3, _ radius: Double, _ aspect: Double) -> Bool {
        let right = Vec3(cos(camera.yaw), 0, -sin(camera.yaw))
        let up = Vec3(-sin(camera.pitch) * sin(camera.yaw), cos(camera.pitch), -sin(camera.pitch) * cos(camera.yaw))
        let points = [center, center + right * radius, center - right * radius, center + up * radius,
                      center - up * radius]
        return points.allSatisfy { p in
            let ndc = camera.project(p, aspect: aspect)
            return abs(ndc.x) <= 1 && abs(ndc.y) <= 1 && ndc.z > -1 && ndc.z < 1
        }
    }

    @Test func theOpeningViewIsTurnTwoTiltOneZoomZero() {
        let opening = AnatomyCameraState.opening
        #expect(opening == AnatomyCameraState(turn: 2, tilt: 1, zoom: 0))
        #expect(opening.isValid)
        let camera = opening.camera(center: .zero, radius: 10, aspect: 1)
        #expect(abs(camera.yaw - 30 * .pi / 180) < 1e-12)
        #expect(abs(camera.pitch - 10 * .pi / 180) < 1e-12)
        #expect(abs(camera.fovY - .pi / 3) < 1e-12)
        #expect(abs(camera.distance - 10 * 1.25 / sin(.pi / 6)) < 1e-9)
    }

    @Test func theTurnWraps() {
        var state = AnatomyCameraState(turn: 23, tilt: 0, zoom: 0)
        let up = state.turn(1)
        #expect(up)
        #expect(state.turn == 0)
        let down = state.turn(-1)
        #expect(down)
        #expect(state.turn == 23)
    }

    @Test func everyLimitIsRefusedWithTheStateUnchanged() {
        var state = AnatomyCameraState(turn: 5, tilt: 6, zoom: 6)
        let before = state
        let tiltUp = state.tilt(1)
        let zoomIn = state.zoom(1)
        #expect(!tiltUp && !zoomIn)
        #expect(state == before)
        state = AnatomyCameraState(turn: 5, tilt: -6, zoom: -4)
        let low = state
        let tiltDown = state.tilt(-1)
        let zoomOut = state.zoom(-1)
        #expect(!tiltDown && !zoomOut)
        #expect(state == low)
        for delta in [0, 2, -2] {
            var other = AnatomyCameraState.opening
            let turned = other.turn(delta)
            let tilted = other.tilt(delta)
            let zoomed = other.zoom(delta)
            #expect(!turned && !tilted && !zoomed, "\(delta)")
            #expect(other == .opening, "\(delta)")
        }
        var inside = AnatomyCameraState.opening
        let tiltOK = inside.tilt(1)
        let zoomOK = inside.zoom(-1)
        #expect(tiltOK && zoomOK)
        #expect(inside == AnatomyCameraState(turn: 2, tilt: 2, zoom: -1))
    }

    @Test func zoomStepsScaleTheDistance() {
        var state = AnatomyCameraState.opening
        let framed = state.camera(center: .zero, radius: 4, aspect: 2).distance
        let closer = state.zoom(1)
        #expect(closer)
        #expect(abs(state.camera(center: .zero, radius: 4, aspect: 2).distance - framed * 0.85) < 1e-9)
        #expect(abs(AnatomyCameraState.narrowerHalfFieldOfView(aspect: 0.5) - atan(tan(Double.pi / 6) * 0.5)) < 1e-12)
        #expect(abs(AnatomyCameraState.narrowerHalfFieldOfView(aspect: 2) - .pi / 6) < 1e-12)
    }

    @Test func resetRestoresTheOpeningView() {
        var state = AnatomyCameraState.opening
        let a = state.turn(1)
        let b = state.tilt(-1)
        let c = state.zoom(1)
        #expect(a && b && c)
        #expect(state != .opening)
        state.reset()
        #expect(state == .opening)
    }

    @Test func framingEveryPartKeepsItsSphereInView() throws {
        let region = try AnatomyContent.bundledRightKnee()
        let scene = try AnatomyScene.build(region, quality: AnatomyQuality.levels[0]).get()
        for state in [AnatomyCameraState.opening, AnatomyCameraState(turn: 13, tilt: -6, zoom: 0),
                      AnatomyCameraState(turn: 7, tilt: 6, zoom: 0)] {
            for aspect in [0.5, 2.0] {
                for index in scene.parts.indices {
                    let sphere = scene.structureSphere(index)
                    let camera = state.camera(center: sphere.center, radius: sphere.radius, aspect: aspect)
                    #expect(Self.framingFits(camera, sphere.center, sphere.radius, aspect),
                            "\(scene.parts[index].id) at aspect \(aspect), turn \(state.turn), tilt \(state.tilt)")
                    #expect(camera.target == sphere.center)
                }
                let whole = state.camera(center: scene.regionCenter, radius: scene.regionRadius, aspect: aspect)
                #expect(Self.framingFits(whole, scene.regionCenter, scene.regionRadius, aspect), "region \(aspect)")
            }
        }
    }
}
