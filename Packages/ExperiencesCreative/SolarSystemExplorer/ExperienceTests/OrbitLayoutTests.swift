// OrbitLayoutTests — feature 104 (A14-P02) T-A14-207 (FR-A14-220, FR-A14-221; research D4; SC-A14-204). The pure
// geometry of the orbit view, no GPU: the 4√r scene mapping (Mercury's 0.387 AU at 2.49 scene units, Neptune's 30.07
// AU at 21.9, the Sun at the origin, the ecliptic in the scene's x–z plane), the display radii (A14-P01's × 0.6 and the
// Sun × 0.5), the 128-point closed orbit paths, the camera (target follows the focus, yaw, pitch and distance from the
// state, the focused body always in front of the near plane), the ring facing the camera and the background ray test;
// with feature 105 (A14-P03) T-A14-308 the delegation to `ScaleMode` (the enhanced mapping unchanged, the true-relative
// mapping at 2 units per AU), the mode-aware camera, the rebuilt camera of a pushed eye, Saturn's selection ring around
// its planetary ring and the markers below 2 pixels.
import Foundation
import XCTest
@testable import SolarSystemExplorerExperience
import SolarSystemExplorerCore
import VisualCoreMath

final class OrbitLayoutTests: XCTestCase {
    private func state(selection: Int = 0, day: Double = 0, yaw: Int = 0, pitch: Int = 35,
                       zoom: Int = 0) throws -> SolarState {
        try XCTUnwrap(SolarState(selection: selection, dayOffset: day, yawSteps: yaw, pitchDegrees: pitch,
                                 zoomSteps: zoom))
    }

    private func assertClose(_ a: Vec3, _ b: Vec3, _ accuracy: Double, _ message: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertLessThanOrEqual((a - b).length, accuracy, "\(message): \(a) vs \(b)", file: file, line: line)
    }

    func testTheSquareRootMappingOfMercuryNeptuneAndTheSun() {
        XCTAssertEqual(OrbitLayout.scenePosition(Vec3(0.387, 0, 0)).length, 2.4884, accuracy: 1e-3, "Mercury")
        XCTAssertEqual(OrbitLayout.scenePosition(Vec3(30.07, 0, 0)).length, 21.934, accuracy: 1e-3, "Neptune")
        XCTAssertEqual(OrbitLayout.scenePosition(.zero), .zero, "the Sun at the origin")
        XCTAssertEqual(OrbitLayout.scenePosition(Vec3(.nan, 0, 0)), .zero)
        // (x, y, z) ecliptic → (x, z, −y) scene: the ecliptic is the x–z plane, ecliptic north is +y.
        assertClose(OrbitLayout.scenePosition(Vec3(1, 0, 0)), Vec3(4, 0, 0), 1e-12, "equinox direction")
        assertClose(OrbitLayout.scenePosition(Vec3(0, 1, 0)), Vec3(0, 0, -4), 1e-12, "90° ahead")
        assertClose(OrbitLayout.scenePosition(Vec3(0, 0, 1)), Vec3(0, 4, 0), 1e-12, "ecliptic north")
        assertClose(OrbitLayout.scenePosition(Vec3(0, 0, 4)), Vec3(0, 8, 0), 1e-12, "4 AU → 8 units")

        // The model's planets: the scene distance is 4√(distance in AU).
        let days: [Double] = [0, 365, -3_650, 9_131]
        for day in days {
            for index in 1..<SolarCore.bodyCount {
                let id = SolarCore.catalog.bodies[index].id
                let au = try? XCTUnwrap(SolarCore.model.distanceAU(bodyID: id, day: day))
                let scene = OrbitLayout.scenePosition(index: index, day: day)
                XCTAssertTrue(scene.isFinite, "\(id) day \(day)")
                XCTAssertEqual(scene.length, 4 * (au ?? 0).squareRoot(), accuracy: 1e-9, "\(id) day \(day)")
            }
            XCTAssertEqual(OrbitLayout.scenePosition(index: 0, day: day), .zero, "the Sun on day \(day)")
        }
        let mercury = OrbitLayout.scenePosition(index: 1, day: 0).length
        XCTAssertTrue(mercury > 2.2 && mercury < 2.75, "Mercury \(mercury)")
        let neptune = OrbitLayout.scenePosition(index: 8, day: 0).length
        XCTAssertTrue(neptune > 21.5 && neptune < 22.3, "Neptune \(neptune)")
        XCTAssertEqual(OrbitLayout.scenePosition(index: 42, day: 0), .zero, "an unknown index")
    }

    func testTheDisplayRadiiAreScaledFromPhase01() {
        XCTAssertEqual(OrbitLayout.displayRadius(index: 0), 0.8, accuracy: 1e-12, "the Sun × 0.5")
        XCTAssertEqual(OrbitLayout.displayRadius(index: 1), 0.15, accuracy: 1e-12, "Mercury × 0.6")
        for index in 1..<SolarCore.bodyCount {
            XCTAssertEqual(OrbitLayout.displayRadius(index: index), SolarPresenter.displayRadius(index: index) * 0.6,
                           accuracy: 1e-12, "body \(index)")
        }
        XCTAssertEqual(OrbitLayout.largestDisplayRadius, 0.8, accuracy: 1e-12)
    }

    func testOrbitPathsHave128FinitePointsAndClose() throws {
        let ids = OrbitLayout.orbitBodyIDs
        XCTAssertEqual(ids, ["mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune"])
        for id in ids {
            let path = OrbitLayout.orbitPath(bodyID: id)
            let orbit = try XCTUnwrap(SolarCore.model.orbit(bodyID: id))
            XCTAssertEqual(path.count, 128, id)
            var largestGap = 0.0
            for k in 0..<path.count {
                XCTAssertTrue(path[k].isFinite, "\(id) point \(k)")
                let gap = (path[(k + 1) % path.count] - path[k]).length
                XCTAssertGreaterThan(gap, 0, "\(id): distinct points at \(k)")
                largestGap = max(largestGap, gap)
                let expected = 4 * orbit.position(at: orbit.period * Double(k) / 128).length.squareRoot()
                XCTAssertEqual(path[k].length, expected, accuracy: 1e-9, "\(id) point \(k)")
            }
            // One period later the orbit is back at the first point: the loop closes.
            assertClose(OrbitLayout.scenePosition(orbit.position(at: orbit.period)), path[0], 1e-6, "\(id) closes")
            // Each step covers 1/128 of a turn: no step is longer than the loop's length / 128 × 3 (eccentricity).
            XCTAssertLessThan(largestGap, 2 * Double.pi * OrbitLayout.sceneRadius / 128 * 3, id)
        }
        XCTAssertEqual(OrbitLayout.orbitPath(bodyID: "sun"), [])
        XCTAssertEqual(OrbitLayout.orbitPath(bodyID: "pluto"), [])
        XCTAssertTrue(OrbitLayout.sceneRadius > 21.8 && OrbitLayout.sceneRadius < 22.3, "\(OrbitLayout.sceneRadius)")
    }

    func testTheCameraFollowsTheFocusAndTheState() throws {
        for index in 0..<SolarCore.bodyCount {
            let camera = OrbitLayout.camera(state: try state(selection: index, day: 365))
            XCTAssertEqual(camera.target, OrbitLayout.scenePosition(index: index, day: 365), "body \(index)")
            XCTAssertEqual(camera.distance, 60, accuracy: 1e-12)
            XCTAssertEqual(camera.fovY, Double.pi / 3, accuracy: 1e-12)
        }
        XCTAssertEqual(OrbitLayout.camera(state: .initial).target, .zero, "the Sun at the origin")
        let turned = OrbitLayout.camera(state: try state(selection: 3, yaw: 3, pitch: 65, zoom: 2))
        XCTAssertEqual(turned.yaw, 45 * Double.pi / 180, accuracy: 1e-12)
        XCTAssertEqual(turned.pitch, 65 * Double.pi / 180, accuracy: 1e-12)
        XCTAssertEqual(turned.distance, 60 / (1.25 * 1.25), accuracy: 1e-9)
        let wrapped = OrbitLayout.camera(state: try state(yaw: -1))
        XCTAssertEqual(wrapped.yaw, 345 * Double.pi / 180, accuracy: 1e-12, "the yaw wraps")
        XCTAssertNotEqual(OrbitLayout.camera(state: try state(selection: 3)).target,
                          OrbitLayout.camera(state: try state(selection: 3, day: 30)).target, "the date moves Earth")
    }

    func testTheFocusedBodyStaysInFrontOfTheNearPlaneAtTheClosestZoom() throws {
        // The smallest distance, 60 · 1.25^−12 = 4.12, is at least 4 and exceeds 3 × the largest display radius + 0.5.
        let closest = try state(zoom: 12).cameraDistance
        XCTAssertEqual(closest, 60 * pow(1.25, -12), accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(closest, 4)
        XCTAssertGreaterThan(closest, 3 * OrbitLayout.largestDisplayRadius + 0.5)
        let pitches: [Int] = [5, 45, 85]
        for index in 0..<SolarCore.bodyCount {
            for pitch in pitches {
                let camera = OrbitLayout.camera(state: try state(selection: index, pitch: pitch, zoom: 12))
                XCTAssertGreaterThanOrEqual(camera.distance, 3 * OrbitLayout.displayRadius(index: index) + 0.5,
                                            "body \(index)")
                let front = (camera.eye - camera.target).length - OrbitLayout.displayRadius(index: index)
                XCTAssertGreaterThan(front, camera.near, "body \(index) pitch \(pitch): in front of the near plane")
                let ndc = camera.project(camera.target, aspect: 1.5)
                XCTAssertEqual(ndc.x, 0, accuracy: 1e-9, "body \(index): centred")
                XCTAssertEqual(ndc.y, 0, accuracy: 1e-9, "body \(index): centred")
                XCTAssertTrue(ndc.z > -1 && ndc.z < 1, "body \(index): inside the depth range")
            }
        }
        // The farthest point of the scene lies inside the far plane at the largest distance.
        let farthest = try state(zoom: -1).cameraDistance
        XCTAssertLessThan(farthest + OrbitLayout.sceneRadius + 1, OrbitLayout.far)
    }

    func testTheRingFacesTheCamera() throws {
        let yaws: [Int] = [0, 3, -5, 12]
        let pitches: [Int] = [5, 35, 85]
        for yaw in yaws {
            for pitch in pitches {
                let camera = OrbitLayout.camera(state: try state(selection: 4, yaw: yaw, pitch: pitch))
                let model = OrbitLayout.ringModel(center: camera.target, camera: camera)
                let normal = model.applyVector(Vec3(0, 0, 1)).normalized
                let toEye = (camera.eye - camera.target).normalized
                XCTAssertEqual(normal.dot(toEye), 1, accuracy: 1e-9, "yaw \(yaw) pitch \(pitch)")
                assertClose(model.applyPoint(.zero), camera.target, 1e-9, "centred on the body")
                XCTAssertEqual(model.applyVector(Vec3(1, 0, 0)).length, 3, accuracy: 1e-9, "scale at 60")
            }
        }
        XCTAssertEqual(OrbitLayout.ringScale(distance: 60), 3, accuracy: 1e-12)
        XCTAssertEqual(OrbitLayout.ringScale(distance: 4.12), 1)
        XCTAssertEqual(OrbitLayout.ringScale(distance: .nan), 1)
    }

    func testTheBackgroundRayAndTheCentreOcclusion() throws {
        let overview = SolarState.initial
        XCTAssertFalse(OrbitLayout.rayMissesScene(ndc: Vec2(0, 0), state: overview, aspect: 1.5), "the Sun")
        XCTAssertTrue(OrbitLayout.rayMissesScene(ndc: Vec2(0, 0.92), state: overview, aspect: 1.5), "the top")
        let earth = try state(selection: 3)
        XCTAssertTrue(OrbitLayout.rayMissesScene(ndc: Vec2(0, 0.92), state: earth, aspect: 1.5), "the top")
        XCTAssertFalse(OrbitLayout.rayMissesScene(ndc: Vec2(0, 0), state: earth, aspect: 1.5), "Earth")
        XCTAssertTrue(OrbitLayout.centreUnobstructed(index: 0, state: overview), "nothing before the Sun")
        XCTAssertTrue(OrbitLayout.centreUnobstructed(index: 3, state: earth), "nothing before Earth")

        XCTAssertEqual(OrbitLayout.segmentDistance(Vec3(0, 0, 0), Vec3(2, 0, 0), Vec3(1, 1, 0), Vec3(1, 3, 0)), 1,
                       accuracy: 1e-12)
        XCTAssertEqual(OrbitLayout.segmentDistance(Vec3(0, 0, 0), Vec3(2, 0, 0), Vec3(3, 0, 0), Vec3(3, 0, 0)), 1,
                       accuracy: 1e-12)
        XCTAssertEqual(OrbitLayout.segmentDistance(Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0, 2, 0), Vec3(0, 2, 0)), 2,
                       accuracy: 1e-12)
        XCTAssertEqual(OrbitLayout.segmentDistance(Vec3(-1, 0, 0), Vec3(1, 0, 0), Vec3(0, -1, 1), Vec3(0, 1, 1)), 1,
                       accuracy: 1e-12, "crossing segments a unit apart")
    }

    func testTheScaleModesAreDelegatedAndTheCameraFollowsTheMode() throws {
        let days: [Double] = [0, 365]
        for day in days {
            for index in 0..<SolarCore.bodyCount {
                let id = SolarCore.catalog.bodies[index].id
                let p = SolarCore.model.position(bodyID: id, day: day) ?? .zero
                XCTAssertEqual(OrbitLayout.scenePosition(index: index, day: day),
                               ScaleMode.enhanced.scenePosition(p), "\(id): the enhanced mapping is ScaleMode's")
                XCTAssertEqual(OrbitLayout.scenePosition(index: index, day: day, mode: .trueRelative),
                               ScaleMode.trueRelative.scenePosition(p), "\(id)")
                XCTAssertEqual(OrbitLayout.drawnRadius(index: index, mode: .enhanced),
                               OrbitLayout.displayRadius(index: index), accuracy: 1e-15)
                XCTAssertEqual(OrbitLayout.drawnRadius(index: index, mode: .trueRelative),
                               ScaleMode.trueRelative.drawnRadius(index: index), accuracy: 1e-15)
            }
        }
        assertClose(OrbitLayout.scenePosition(Vec3(1, 0, 0), mode: .trueRelative), Vec3(2, 0, 0), 1e-12, "2 per AU")
        XCTAssertEqual(OrbitLayout.orbitPath(bodyID: "earth"), OrbitLayout.orbitPath(bodyID: "earth", mode: .enhanced))
        XCTAssertEqual(OrbitLayout.orbitTubeRadius(mode: .enhanced), 0.04)
        XCTAssertEqual(OrbitLayout.orbitTubeRadius(mode: .trueRelative), 0.1)
        XCTAssertTrue(OrbitLayout.trueExtent.radius > 59 && OrbitLayout.trueExtent.radius < 61.5,
                      "\(OrbitLayout.trueExtent.radius)")
        XCTAssertEqual(OrbitLayout.paths(mode: .trueRelative).count, 8)
        XCTAssertEqual(OrbitLayout.paths(mode: .enhanced)[2], OrbitLayout.orbitPath(bodyID: "earth"))

        let trueState = try XCTUnwrap(SolarState(selection: 5, dayOffset: 0, yawSteps: 0, pitchDegrees: 35,
                                                 zoomSteps: 12, scaleMode: .trueRelative))
        let camera = OrbitLayout.camera(state: trueState)
        XCTAssertEqual(camera.distance, 120 * pow(1.25, -12), accuracy: 1e-9)
        XCTAssertEqual(camera.near, max(1e-4, 0.05 * camera.distance), accuracy: 1e-12)
        XCTAssertEqual(camera.far, camera.distance + 140, accuracy: 1e-12)
        XCTAssertEqual(camera.target, OrbitLayout.scenePosition(index: 5, day: 0, mode: .trueRelative))

        // A camera rebuilt from its own eye looks the same way from the same place.
        let rebuilt = OrbitLayout.camera(target: camera.target, eye: camera.eye, near: camera.near, far: camera.far)
        assertClose(rebuilt.eye, camera.eye, 1e-9, "rebuilt eye")
        XCTAssertEqual(rebuilt.yaw, camera.yaw, accuracy: 1e-9)
        XCTAssertEqual(rebuilt.pitch, camera.pitch, accuracy: 1e-9)
        XCTAssertEqual(rebuilt.distance, camera.distance, accuracy: 1e-9)
    }

    func testSaturnsSelectionRingSurroundsItsPlanetaryRing() {
        let saturn = SceneMeshes.saturnIndex
        XCTAssertEqual(BodyCatalog.bundled.bodies[saturn].id, "saturn")
        let planetary = OrbitLayout.saturnRingRadius(mode: .enhanced)
        XCTAssertEqual(planetary, 136_775 / 58_232 * OrbitLayout.displayRadius(index: saturn), accuracy: 1e-9)
        XCTAssertGreaterThan(OrbitLayout.selectionRingRadius(index: saturn) - SolarPresenter.ringTubeRadius, planetary)
        for index in 0..<SolarCore.bodyCount where index != saturn {
            XCTAssertEqual(OrbitLayout.selectionRingRadius(index: index),
                           SolarPresenter.ringRadius(displayRadius: OrbitLayout.displayRadius(index: index)),
                           accuracy: 1e-12, "body \(index)")
        }
        // True-relative: the ring is 10 pixels at its distance from the eye.
        let scale = OrbitLayout.selectionRingScale(index: 3, mode: .trueRelative, cameraDistance: 120,
                                                   eyeDistance: 100, heightPixels: 480)
        let pixel = CameraRelative.pixelSize(distance: 100, fovY: Double.pi / 3, heightPixels: 480)
        XCTAssertEqual(scale * OrbitLayout.selectionRingRadius(index: 3), 10 * pixel, accuracy: 1e-12)
        XCTAssertEqual(OrbitLayout.selectionRingScale(index: 3, mode: .enhanced, cameraDistance: 60, eyeDistance: 60,
                                                      heightPixels: 480), 3, accuracy: 1e-12)
    }

    func testMarkersAreChosenBelowTwoPixelsInTheTrueRelativeModeOnly() throws {
        let eye = Vec3(0, 120 * pow(1.25, -12) * sin(35 * Double.pi / 180),
                       120 * pow(1.25, -12) * cos(35 * Double.pi / 180))
        XCTAssertEqual(OrbitLayout.markerIndices(mode: .enhanced, day: 0, eye: eye, heightPixels: 480), [])
        // On a phone canvas every true-relative body is far under 2 pixels.
        XCTAssertEqual(OrbitLayout.markerIndices(mode: .trueRelative, day: 0, eye: eye, heightPixels: 480),
                       Array(0..<SolarCore.bodyCount))
        // On a canvas 20,000 pixels high the Sun, 8.25 units away, is about 19 pixels: only it goes unmarked.
        let tall = OrbitLayout.markerIndices(mode: .trueRelative, day: 0, eye: eye, heightPixels: 20_000)
        XCTAssertFalse(tall.contains(0), "the Sun is large enough")
        XCTAssertTrue(tall.contains(1), "Mercury stays marked")
        for index in 0..<SolarCore.bodyCount {
            let center = OrbitLayout.scenePosition(index: index, day: 0, mode: .trueRelative)
            let pixels = OrbitLayout.pixelRadius(ScaleMode.trueRelative.drawnRadius(index: index), at: center,
                                                 eye: eye, heightPixels: 20_000)
            XCTAssertEqual(tall.contains(index), pixels < 2, "body \(index): \(pixels) px")
        }
        let scale = OrbitLayout.markerScale(center: .zero, eye: eye, heightPixels: 480)
        XCTAssertEqual(scale, 6 * CameraRelative.pixelSize(distance: eye.length, fovY: Double.pi / 3, heightPixels: 480),
                       accuracy: 1e-12)
    }
}
