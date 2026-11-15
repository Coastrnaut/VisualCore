// LabelLayoutTests — feature 106 (A14-P04) T-A14-408 (FR-A14-420; clarification Q4). The pure label placement of
// Solar System Explorer: a body at the camera's target gets its label 8 pt right of and 8 pt above the canvas centre;
// no label for a body behind the camera, beyond the far plane or off the canvas; the focused body is placed first;
// placed labels never overlap; at the overview several labels are placed. Short, host-free and deterministic.
import Foundation
import XCTest
@testable import SolarSystemExplorerExperience
import SolarSystemExplorerCore
import VisualCoreMath

final class LabelLayoutTests: XCTestCase {
    /// A camera at (0, 0, 10) looking at the origin (yaw 0, pitch 0, 60° field of view, near 0.1, far 100).
    private let camera = OrbitCamera(target: .zero, distance: 10, yaw: 0, pitch: 0, fovY: Double.pi / 3,
                                     near: 0.1, far: 100)
    /// A canvas of 390 × 300 points.
    private let canvas = Vec2(390, 300)

    /// Whether any two labels of `labels` overlap.
    private func anyOverlap(_ labels: [LabelLayout.Label]) -> Bool {
        for i in labels.indices {
            for j in labels.indices where j > i {
                if LabelLayout.overlaps(labels[i].box, labels[j].box) { return true }
            }
        }
        return false
    }

    func testABodyAtTheTargetIsLabelledRightOfAndAboveTheCanvasCentre() throws {
        let labels = LabelLayout.labels(camera: camera, canvas: canvas, positions: [Vec3(0, 0, 0)], focused: 0,
                                        eye: camera.eye, names: ["Sun"])
        XCTAssertEqual(labels.count, 1)
        let label = try XCTUnwrap(labels.first)
        XCTAssertEqual(label.index, 0)
        XCTAssertEqual(label.name, "Sun")
        XCTAssertEqual(label.point.x, 195 + 8, accuracy: 1e-9)
        XCTAssertEqual(label.point.y, 150 - 8, accuracy: 1e-9)
        let box = label.box
        XCTAssertEqual(box.maxX - box.minX, 90, accuracy: 1e-12)
        XCTAssertEqual(box.maxY - box.minY, 20, accuracy: 1e-12)
        XCTAssertEqual(box.maxY, label.point.y, accuracy: 1e-12, "the point is the box's bottom-left corner")
    }

    func testNoLabelBehindTheCameraBeyondTheFarPlaneOrOffTheCanvas() {
        let behind = Vec3(0, 0, 20)          // behind the eye at z = 10: clip w < 0
        let beyondFar = Vec3(0, 0, -200)     // 210 from the eye, beyond the far plane at 100: NDC z > 1
        let offCanvas = Vec3(100, 0, 0)      // far outside the 60° frustum at depth 10
        let visible = Vec3(1, 1, 0)
        let positions: [Vec3] = [behind, beyondFar, offCanvas, visible]
        XCTAssertNil(LabelLayout.canvasPoint(of: behind, camera: camera, canvas: canvas))
        XCTAssertNil(LabelLayout.canvasPoint(of: beyondFar, camera: camera, canvas: canvas))
        XCTAssertNil(LabelLayout.canvasPoint(of: offCanvas, camera: camera, canvas: canvas))
        XCTAssertNotNil(LabelLayout.canvasPoint(of: visible, camera: camera, canvas: canvas))
        let labels = LabelLayout.labels(camera: camera, canvas: canvas, positions: positions, focused: 0,
                                        eye: camera.eye, names: ["a", "b", "c", "d"])
        var indices: [Int] = []
        for label in labels { indices.append(label.index) }
        XCTAssertEqual(indices, [3], "only the visible body is labelled, even when a hidden one is focused")
        XCTAssertNil(LabelLayout.canvasPoint(of: .zero, camera: camera, canvas: Vec2(0, 0)), "no canvas, no label")
    }

    func testTheFocusedBodyIsPlacedFirstThenByDistanceAndOverlapsAreSkipped() {
        // Three bodies at nearly the same canvas point: only one label fits, and it is the focused one.
        let positions: [Vec3] = [Vec3(0, 0, 0), Vec3(0.01, 0, 2), Vec3(0.02, 0, 4)]
        let focusedFar = LabelLayout.labels(camera: camera, canvas: canvas, positions: positions, focused: 0,
                                            eye: camera.eye, names: ["far", "middle", "near"])
        XCTAssertEqual(focusedFar.count, 1)
        XCTAssertEqual(focusedFar.first?.index, 0, "the focused body wins over nearer ones")
        let focusedNear = LabelLayout.labels(camera: camera, canvas: canvas, positions: positions, focused: 2,
                                             eye: camera.eye, names: ["far", "middle", "near"])
        XCTAssertEqual(focusedNear.first?.index, 2)
        // Spread bodies: after the focused one, the nearer body comes first.
        let spread: [Vec3] = [Vec3(-3, -2, 0), Vec3(3, 2, 0), Vec3(0, 0, 5)]
        let ordered = LabelLayout.labels(camera: camera, canvas: canvas, positions: spread, focused: 1,
                                         eye: camera.eye, names: ["a", "b", "c"])
        var indices: [Int] = []
        for label in ordered { indices.append(label.index) }
        XCTAssertEqual(indices, [1, 2, 0], "focused first, then by increasing distance from the eye")
        XCTAssertFalse(anyOverlap(ordered))
    }

    func testAtTheOverviewSeveralLabelsArePlacedAndNoneOverlap() {
        var placedAtSomeDate = 0
        let days: [Double] = [0, 100, 1_000, 5_000, -7_000]
        for day in days {
            for zoom in [0, 4, 8] {
                guard let state = SolarState(selection: 3, dayOffset: day, yawSteps: 2, pitchDegrees: 35,
                                             zoomSteps: zoom) else {
                    XCTFail("state")
                    continue
                }
                let overview = OrbitLayout.camera(state: state)
                var positions: [Vec3] = []
                for index in 0..<SolarCore.bodyCount {
                    positions.append(OrbitLayout.scenePosition(index: index, day: day, mode: .enhanced))
                }
                let labels = LabelLayout.labels(camera: overview, canvas: canvas, positions: positions, focused: 3,
                                                eye: overview.eye)
                XCTAssertFalse(anyOverlap(labels), "day \(day) zoom \(zoom)")
                XCTAssertEqual(labels.first?.index, 3, "the focused Earth at the centre is placed first")
                XCTAssertEqual(labels.first?.name, "Earth")
                for label in labels {
                    XCTAssertGreaterThanOrEqual(label.point.x, LabelLayout.offsetRight)
                    XCTAssertLessThanOrEqual(label.point.x, canvas.x + LabelLayout.offsetRight)
                }
                if zoom == 0 { placedAtSomeDate = max(placedAtSomeDate, labels.count) }
            }
        }
        XCTAssertGreaterThanOrEqual(placedAtSomeDate, 3, "the overview labels several bodies")
    }
}
