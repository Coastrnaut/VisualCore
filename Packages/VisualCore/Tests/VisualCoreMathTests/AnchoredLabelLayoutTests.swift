// AnchoredLabelLayoutTests — feature 127 (A17-P04) T-A17-402 (FR-A17-402, FR-A17-403; clarification Q2; SC-A17-402).
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import VisualCoreMath

@Suite struct AnchoredLabelLayoutTests {
    private typealias Layout = AnchoredLabelLayout

    /// A tiny deterministic LCG (VisualCoreMath has no seeded generator of its own).
    private struct LCG {
        var state: UInt64
        mutating func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / Double(UInt64(1) << 53)
        }
        mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * next() }
    }

    private func randomCandidates(seed: UInt64, count: Int) -> [Layout.Candidate] {
        var rng = LCG(state: seed)
        var out: [Layout.Candidate] = []
        for i in 0..<count {
            let anchor = Vec3(rng.range(-3, 3), rng.range(-3, 3), rng.range(-3, 3))
            let size = Vec2(rng.range(10, 90), rng.range(12, 24))
            let priority = Int(rng.range(0, 5))
            out.append(Layout.Candidate(id: i, anchor: anchor, size: size, priority: priority))
        }
        return out
    }

    private func cameras() -> [OrbitCamera] {
        var out: [OrbitCamera] = []
        let yaws: [Double] = [0, 0.9, 2.4, -1.7]
        let pitches: [Double] = [0, 0.5, -0.6]
        let distances: [Double] = [2, 6, 12]
        for yaw in yaws {
            for pitch in pitches {
                for distance in distances {
                    out.append(OrbitCamera(distance: distance, yaw: yaw, pitch: pitch))
                }
            }
        }
        return out
    }

    private func inside(_ p: Layout.Placement, _ canvas: Vec2) -> Bool {
        p.minX >= 0 && p.minY >= 0 && p.maxX <= canvas.x && p.maxY <= canvas.y
    }

    @Test func noOverlapsAndInsideCanvasOverRandomCandidates() {
        let candidates = randomCandidates(seed: 127, count: 200)
        let canvases: [Vec2] = [Vec2(390, 844), Vec2(1024, 768)]
        for canvas in canvases {
            for camera in cameras() {
                let placed = Layout.place(candidates, camera: camera, aspect: canvas.x / canvas.y, canvas: canvas,
                                          budget: 200)
                for i in placed.indices {
                    #expect(inside(placed[i], canvas))
                    for j in placed.indices where j > i {
                        #expect(!Layout.overlaps(placed[i], placed[j]))
                    }
                }
            }
        }
    }

    @Test func priorityZeroOnCanvasIsAlwaysPlaced() {
        var candidates = randomCandidates(seed: 7, count: 200)
        candidates.append(Layout.Candidate(id: 999, anchor: .zero, size: Vec2(40, 18), priority: 0))
        // Other candidates start at priority 1, so the target candidate is first in order.
        var shifted: [Layout.Candidate] = []
        for c in candidates {
            let priority = c.id == 999 ? 0 : c.priority + 1
            shifted.append(Layout.Candidate(id: c.id, anchor: c.anchor, size: c.size, priority: priority))
        }
        let canvas = Vec2(390, 844)
        for camera in cameras() {
            let placed = Layout.place(shifted, camera: camera, aspect: canvas.x / canvas.y, canvas: canvas, budget: 16)
            #expect(placed.first?.id == 999)
        }
    }

    @Test func behindCameraAndOffCanvasAreNeverPlaced() {
        let camera = OrbitCamera(distance: 5, yaw: 0.4, pitch: 0.3)
        let canvas = Vec2(400, 300)
        let aspect = canvas.x / canvas.y
        let eye = camera.eye
        let behind = eye + (eye - camera.target) * 0.5
        #expect(Layout.canvasPoint(of: behind, camera: camera, aspect: aspect, canvas: canvas) == nil)
        let beyondFar = eye + (camera.target - eye) * 1_000
        #expect(Layout.canvasPoint(of: beyondFar, camera: camera, aspect: aspect, canvas: canvas) == nil)
        // Far to the side of the view: projects, but outside the canvas.
        let right = Vec3(cos(camera.yaw), 0, -sin(camera.yaw))
        let aside = camera.target + right * 50
        let candidates: [Layout.Candidate] = [
            Layout.Candidate(id: 1, anchor: behind, size: Vec2(20, 10), priority: 0),
            Layout.Candidate(id: 2, anchor: beyondFar, size: Vec2(20, 10), priority: 0),
            Layout.Candidate(id: 3, anchor: aside, size: Vec2(20, 10), priority: 0),
            // On the canvas but the box is larger than the canvas.
            Layout.Candidate(id: 4, anchor: camera.target, size: Vec2(500, 10), priority: 0),
            Layout.Candidate(id: 5, anchor: Vec3(.nan, 0, 0), size: Vec2(20, 10), priority: 0),
            Layout.Candidate(id: 6, anchor: camera.target, size: Vec2(.infinity, 10), priority: 0),
        ]
        #expect(Layout.place(candidates, camera: camera, aspect: aspect, canvas: canvas, budget: 10).isEmpty)
    }

    @Test func budgetIsRespected() {
        let candidates = randomCandidates(seed: 3, count: 200)
        let canvas = Vec2(1024, 768)
        let camera = OrbitCamera(distance: 8, yaw: 0.3, pitch: 0.2)
        let aspect = canvas.x / canvas.y
        let all = Layout.place(candidates, camera: camera, aspect: aspect, canvas: canvas, budget: 1_000)
        #expect(all.count > 3)
        let three = Layout.place(candidates, camera: camera, aspect: aspect, canvas: canvas, budget: 3)
        #expect(three == Array(all.prefix(3)))
        #expect(Layout.place(candidates, camera: camera, aspect: aspect, canvas: canvas, budget: 0).isEmpty)
        #expect(Layout.place(candidates, camera: camera, aspect: aspect, canvas: canvas, budget: -1).isEmpty)
    }

    @Test func sameInputGivesSameOutput() {
        let candidates = randomCandidates(seed: 42, count: 200)
        let canvas = Vec2(390, 844)
        let camera = OrbitCamera(distance: 6, yaw: -0.8, pitch: 0.4)
        let a = Layout.place(candidates, camera: camera, aspect: canvas.x / canvas.y, canvas: canvas, budget: 16)
        let b = Layout.place(candidates.reversed(), camera: camera, aspect: canvas.x / canvas.y, canvas: canvas,
                             budget: 16)
        #expect(a == b, "the order of the input does not matter")
        #expect(a == Layout.place(candidates, camera: camera, aspect: canvas.x / canvas.y, canvas: canvas, budget: 16))
    }

    @Test func boxGeometryAndTouchingBoxesBothPlaced() {
        let camera = OrbitCamera(distance: 5)
        let canvas = Vec2(400, 400)
        let centre = Layout.canvasPoint(of: .zero, camera: camera, aspect: 1, canvas: canvas)
        #expect(centre.map { close($0, Vec2(200, 200), 1e-9) } == true)
        let one = Layout.place([Layout.Candidate(id: 0, anchor: .zero, size: Vec2(30, 18), priority: 0)],
                               camera: camera, aspect: 1, canvas: canvas, budget: 1)
        #expect(one.count == 1)
        if let p = one.first {
            #expect(close(p.minX, 206, 1e-9) && close(p.maxX, 236, 1e-9))
            #expect(close(p.maxY, 194, 1e-9) && close(p.minY, 176, 1e-9))
        }
        // Touching edges do not overlap; a positive-area overlap does.
        let a = Layout.Placement(id: 0, point: .zero, minX: 0, minY: 0, maxX: 10, maxY: 10)
        let b = Layout.Placement(id: 1, point: .zero, minX: 10, minY: 0, maxX: 20, maxY: 10)
        let c = Layout.Placement(id: 2, point: .zero, minX: 0, minY: 10, maxX: 10, maxY: 20)
        let d = Layout.Placement(id: 3, point: .zero, minX: 9.5, minY: 9.5, maxX: 20, maxY: 20)
        #expect(!Layout.overlaps(a, b) && !Layout.overlaps(a, c))
        #expect(Layout.overlaps(a, d) && Layout.overlaps(d, a))
        // Two anchors whose boxes touch exactly: the first box is as wide as the gap between the projected anchors.
        // Both left edges lie within a factor 2 of each other, so (b + (a − b)) == a exactly (Sterbenz lemma).
        let pushed = Layout.canvasPoint(of: Vec3(1, 0, 0), camera: camera, aspect: 1, canvas: canvas)
        #expect(pushed != nil)
        if let centre, let pushed {
            let width = (pushed.x + Layout.offset) - (centre.x + Layout.offset)
            #expect(width > 0)
            let pair: [Layout.Candidate] = [
                Layout.Candidate(id: 0, anchor: .zero, size: Vec2(width, 18), priority: 0),
                Layout.Candidate(id: 1, anchor: Vec3(1, 0, 0), size: Vec2(width, 18), priority: 0),
            ]
            let placed = Layout.place(pair, camera: camera, aspect: 1, canvas: canvas, budget: 2)
            #expect(placed.count == 2, "touching boxes are both placed")
        }
    }

    @Test func outputOrderFollowsPriorityThenID() {
        let camera = OrbitCamera(distance: 10)
        let canvas = Vec2(1000, 1000)
        var candidates: [Layout.Candidate] = []
        let ids: [Int] = [5, 2, 9, 1, 7, 3]
        let priorities: [Int] = [1, 1, 0, 2, 0, 1]
        for k in ids.indices {
            // Spread along x so no boxes overlap.
            let anchor = Vec3(Double(k) * 0.8 - 2, 0, 0)
            candidates.append(Layout.Candidate(id: ids[k], anchor: anchor, size: Vec2(20, 12), priority: priorities[k]))
        }
        let placed = Layout.place(candidates, camera: camera, aspect: 1, canvas: canvas, budget: 10)
        var got: [Int] = []
        for p in placed { got.append(p.id) }
        #expect(got == [7, 9, 2, 3, 5, 1])
    }
}
