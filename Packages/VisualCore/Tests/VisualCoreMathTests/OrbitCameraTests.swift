// OrbitCameraTests — feature 006 T-F515 (FR-F509; US4 AC1; edge case pitch/zoom limits).
import Foundation
import Testing
@testable import VisualCoreMath

@Test func targetProjectsToCenterAndCenterRayHitsIt() {
    // AC1: distance 5 looking at the origin.
    let cam = OrbitCamera(distance: 5, yaw: 0.7, pitch: 0.4)
    let ndc = cam.project(.zero, aspect: 1.5)
    #expect(abs(ndc.x) < 1e-12 && abs(ndc.y) < 1e-12)
    #expect(ndc.z > -1 && ndc.z < 1, "inside the depth range")
    let ray = cam.ray(ndc: .zero, aspect: 1.5)
    let toTarget = Vec3.zero - ray.origin
    let along = toTarget.dot(ray.direction)
    #expect((toTarget - ray.direction * along).length < 1e-9, "the ray passes through the origin")
    #expect(along > 0)
}

@Test func eyePositionAndHandedness() {
    let cam = OrbitCamera(distance: 5)
    #expect(close(cam.eye, Vec3(0, 0, 5)))
    #expect(cam.project(Vec3(1, 0, 0), aspect: 1).x > 0, "+x appears on the right")
    #expect(cam.project(Vec3(0, 1, 0), aspect: 1).y > 0, "+y appears up")
    #expect(cam.project(Vec3(0, 0, -100), aspect: 1).z > cam.project(.zero, aspect: 1).z, "farther is deeper")
}

@Test func pitchAndDistanceAreClamped() {
    var cam = OrbitCamera(pitch: 2)
    #expect(cam.pitch == OrbitCamera.pitchLimit)
    cam.orbit(dYaw: 0, dPitch: -10)
    #expect(cam.pitch == -OrbitCamera.pitchLimit)
    cam.zoom(by: 1e12)
    #expect(cam.distance == 0.01)
    cam.zoom(by: -2); cam.zoom(by: .nan)
    #expect(cam.distance == 0.01, "invalid factors ignored")
    cam.distance = .infinity
    #expect(cam.distance == 5)
    #expect(OrbitCamera(fovY: 4, near: -1, far: 0).fovY == .pi / 3)
}

@Test func orbitKeepsDistance() {
    var cam = OrbitCamera(target: Vec3(1, 2, 3), distance: 7)
    for _ in 0..<10 { cam.orbit(dYaw: 0.37, dPitch: 0.11) }
    #expect(abs((cam.eye - cam.target).length - 7) < 1e-9)
}
