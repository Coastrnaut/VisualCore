// WaveKnotKeeperHandlesTests — feature 324 (R02-G03-04) T-R02G0304-002 (FR-R02G0304-001, 002; SC-R02G0304-001;
// clarifications Q1, Q3). Picking: a touch at a handle's projected centre picks it (or a handle nearer the eye that also
// covers the touch), empty space and unusable input pick nothing, overlapping handles give the one nearer the eye, and
// seeded touches agree with an independent recomputation. Drags: 500 seeded drags from seeded handles at seeded orbits
// and aspects give the same candidate as an independent recomputation from the 0 … 1 view projection; drags shorter
// than 6 points or than half the projected step give nil. Plain loops and explicit types (CI type-check rule); seed
// 2_324.
import Foundation
import Testing
@testable import WaveKnotKeeperCore
import VisualCoreMath
import VisualCoreScenes

@Suite struct WaveKnotKeeperHandlesTests {
    typealias Geometry = WaveKnotKeeperSceneGeometry
    typealias Handles = WaveKnotKeeperHandles

    /// The seed of every random choice here.
    static let seed: UInt64 = 2_324
    /// The viewport height in points every size is built from.
    static let height: Double = 768

    /// Seeded simple ropes of 6 … 16 points (spread 4 … 16), each with a gate, as scene snapshots.
    static func snapshots(count: Int) -> [WaveKnotKeeperSceneSnapshot] {
        var random: WaveKnotKeeperRandom = WaveKnotKeeperRandom(seed: seed)
        var result: [WaveKnotKeeperSceneSnapshot] = []
        var attempts: Int = 0
        while result.count < count && attempts < 200 {
            attempts += 1
            let rope: [WaveKnotKeeperPoint] = WaveKnotKeeperFixtures.rope(&random, count: random.int(6...16),
                                                                          spread: random.int(4...16))
            let c: WaveKnotKeeperPoint = rope[random.int(0...(rope.count - 1))]
            var gates: [WaveKnotKeeperGate] = []
            let lo: WaveKnotKeeperPoint = WaveKnotKeeperPoint(x: max(c.x - 2, -16), y: max(c.y - 2, -16),
                                                              z: max(c.z - 2, -16))
            let hi: WaveKnotKeeperPoint = WaveKnotKeeperPoint(x: min(c.x + 2, 16), y: min(c.y + 2, 16),
                                                              z: min(c.z + 2, 16))
            if let gate = try? WaveKnotKeeperGate(min: lo, max: hi) { gates.append(gate) }
            if let s = WaveKnotKeeperSceneGeometryTests.snapshot(rope, gates: gates) { result.append(s) }
        }
        #expect(result.count == count)
        return result
    }

    /// `p` in screen points of `size`, computed independently through the 0 … 1 view projection.
    static func screen(_ p: SIMD3<Double>, camera: WaveKnotKeeperCamera, size: SIMD2<Double>) -> SIMD2<Double>? {
        guard let v = Geometry.project(p, camera: camera) else { return nil }
        return v * size
    }

    /// The Euclidean length of a screen vector.
    static func norm(_ v: SIMD2<Double>) -> Double { (v.x * v.x + v.y * v.y).squareRoot() }

    /// An independent recomputation of the pick: the hits within max(22, projected handle radius) of `location`,
    /// nearest to the eye first, then nearest on screen, then lower index.
    static func expectedPick(_ location: SIMD2<Double>, snapshot: WaveKnotKeeperSceneSnapshot,
                             camera: WaveKnotKeeperCamera, size: SIMD2<Double>) -> Int? {
        let points: [SIMD3<Double>] = Geometry.worldPoints(snapshot)
        let forward: SIMD3<Double> = (camera.target - camera.eye) / Geometry.length(camera.target - camera.eye)
        var best: Int? = nil
        var bestEye: Double = .infinity
        var bestScreen: Double = .infinity
        for i in 0..<points.count {
            guard let q = screen(points[i], camera: camera, size: size) else { continue }
            let depth: Double = Geometry.dot(points[i] - camera.eye, forward)
            let radius: Double = Geometry.handleRadius / depth / tan(camera.fovY / 2) * size.y / 2
            let d: Double = norm(q - location)
            guard d <= max(22, radius) else { continue }
            let e: Double = Geometry.length(points[i] - camera.eye)
            if e < bestEye || (e == bestEye && d < bestScreen) {
                best = i
                bestEye = e
                bestScreen = d
            }
        }
        return best
    }

    /// An independent recomputation of the drag candidate (see ``WaveKnotKeeperHandles/candidate``).
    static func expectedCandidate(point: Int, drag: SIMD2<Double>, snapshot: WaveKnotKeeperSceneSnapshot,
                                  camera: WaveKnotKeeperCamera, size: SIMD2<Double>) -> WaveKnotKeeperDirection? {
        let start: SIMD3<Double> = Geometry.worldPoints(snapshot)[point]
        guard let a = screen(start, camera: camera, size: size) else { return nil }
        var best: WaveKnotKeeperDirection? = nil
        var bestComponent: Double = -.infinity
        var bestLength: Double = 0
        let all: [WaveKnotKeeperDirection] = WaveKnotKeeperDirection.allCases
        for k in 0..<all.count {
            let o: (x: Int, y: Int, z: Int) = all[k].offset
            let end: SIMD3<Double> = start + SIMD3<Double>(Double(o.x), Double(o.y), Double(o.z)) / 8
            guard let b = screen(end, camera: camera, size: size) else { continue }
            let step: SIMD2<Double> = b - a
            let l: Double = norm(step)
            guard l > 1e-9 else { continue }
            let component: Double = (step.x * drag.x + step.y * drag.y) / l
            if component > bestComponent {
                best = all[k]
                bestComponent = component
                bestLength = l
            }
        }
        guard best != nil, bestComponent >= max(6, bestLength / 2) else { return nil }
        return best
    }

    @Test func touchRadiusIsTwentyTwoPoints() {
        #expect(Handles.touchRadius == 22)
        #expect(Handles.minimumSnap == 6)
        #expect(Handles.stepLength == 0.125)
    }

    @Test func aTouchAtAHandleCentrePicksItOrANearerCoveringHandle() throws {
        let size: SIMD2<Double> = SIMD2(1_152, Self.height)
        var exact: Int = 0
        for s in Self.snapshots(count: 6) {
            let camera: WaveKnotKeeperCamera = Geometry.camera(for: s, aspect: size.x / size.y)
            let points: [SIMD3<Double>] = Geometry.worldPoints(s)
            for i in 0..<points.count {
                let centre: SIMD2<Double> = try #require(Self.screen(points[i], camera: camera, size: size))
                let picked: Int = try #require(Handles.pick(centre, snapshot: s, camera: camera, size: size))
                #expect(picked == Self.expectedPick(centre, snapshot: s, camera: camera, size: size))
                if picked == i {
                    exact += 1
                } else {
                    // Another handle covers the touch and is nearer the eye.
                    #expect(Geometry.length(points[picked] - camera.eye) < Geometry.length(points[i] - camera.eye))
                }
            }
        }
        #expect(exact > 0)
    }

    @Test func emptySpaceAndUnusableInputPickNothing() throws {
        let size: SIMD2<Double> = SIMD2(1_152, Self.height)
        for s in Self.snapshots(count: 4) {
            let camera: WaveKnotKeeperCamera = Geometry.camera(for: s, aspect: size.x / size.y)
            // The corners lie in the 5 % margin, beyond the touch radius of every handle.
            let corners: [SIMD2<Double>] = [SIMD2(0, 0), SIMD2(size.x, 0), SIMD2(0, size.y), size,
                                            SIMD2(-1_000, -1_000)]
            for corner in corners {
                #expect(Handles.pick(corner, snapshot: s, camera: camera, size: size) == nil)
            }
            let first: SIMD2<Double> = try #require(Self.screen(Geometry.worldPoints(s)[0], camera: camera,
                                                                size: size))
            #expect(Handles.pick(SIMD2(Double.nan, 0), snapshot: s, camera: camera, size: size) == nil)
            #expect(Handles.pick(first, snapshot: s, camera: camera, size: SIMD2(0, Self.height)) == nil)
            #expect(Handles.pick(first, snapshot: s, camera: camera, size: SIMD2(1_152, -1)) == nil)
            #expect(Handles.pick(first, snapshot: s, camera: camera, size: SIMD2(Double.infinity, 768)) == nil)
        }
    }

    @Test func overlappingHandlesPickTheOneNearerTheEye() throws {
        // A large square with a one-unit step along z: point 5 sits one kernel unit above point 4, towards the eye, so
        // at the authored camera their handles overlap on screen (a few points apart).
        let rope: [WaveKnotKeeperPoint] = [WaveKnotKeeperPoint(x: -16, y: -16, z: 0),
                                           WaveKnotKeeperPoint(x: 16, y: -16, z: 0),
                                           WaveKnotKeeperPoint(x: 16, y: 16, z: 0),
                                           WaveKnotKeeperPoint(x: -16, y: 16, z: 0),
                                           WaveKnotKeeperPoint(x: -8, y: 0, z: 0),
                                           WaveKnotKeeperPoint(x: -8, y: 0, z: 1)]
        let s: WaveKnotKeeperSceneSnapshot = try #require(WaveKnotKeeperSceneGeometryTests.snapshot(rope))
        let size: SIMD2<Double> = SIMD2(1_152, Self.height)
        let camera: WaveKnotKeeperCamera = Geometry.camera(for: s, aspect: size.x / size.y)
        let points: [SIMD3<Double>] = Geometry.worldPoints(s)
        let far: SIMD2<Double> = try #require(Self.screen(points[4], camera: camera, size: size))
        let near: SIMD2<Double> = try #require(Self.screen(points[5], camera: camera, size: size))
        try #require(Self.norm(far - near) > 0 && Self.norm(far - near) <= 22, "the two handles overlap on screen")
        #expect(Geometry.length(points[5] - camera.eye) < Geometry.length(points[4] - camera.eye))
        // At the far handle's own centre (screen distance 0 to it) the nearer handle still wins.
        #expect(Handles.pick(far, snapshot: s, camera: camera, size: size) == 5)
        #expect(Handles.pick(near, snapshot: s, camera: camera, size: size) == 5)
        #expect(Handles.pick((far + near) * 0.5, snapshot: s, camera: camera, size: size) == 5)
        // The R02-F22 picker (nearest on screen first) would take the far handle here; Wave Knot Keeper does not.
        var handles: [SpatialHandle] = []
        for i in 0..<points.count {
            handles.append(try SpatialHandle(id: i, position: Vec3(points[i].x, points[i].y, points[i].z)))
        }
        let shared: Int? = try HandlePicker.pick(handles, at: Vec2(far.x, far.y), viewProjection: camera.viewProjection,
                                                 viewport: Vec2(size.x, size.y))
        #expect(shared == 4)
    }

    @Test func seededTouchesAgreeWithAnIndependentPick() throws {
        var random: WaveKnotKeeperRandom = WaveKnotKeeperRandom(seed: Self.seed)
        var hits: Int = 0
        var misses: Int = 0
        for s in Self.snapshots(count: 4) {
            let aspect: Double = Double(random.int(40...250)) / 100
            let size: SIMD2<Double> = SIMD2(Self.height * aspect, Self.height)
            let orbit: WaveKnotKeeperOrbit = WaveKnotKeeperOrbit(yaw: Double(random.int(-40...40)),
                                                                 pitch: Double(random.int(5...60)))
            let camera: WaveKnotKeeperCamera = Geometry.camera(for: s, aspect: aspect, orbit: orbit)
            let points: [SIMD3<Double>] = Geometry.worldPoints(s)
            for _ in 0..<60 {
                let i: Int = random.int(0...(points.count - 1))
                let centre: SIMD2<Double> = try #require(Self.screen(points[i], camera: camera, size: size))
                let touch: SIMD2<Double> = centre + SIMD2(Double(random.int(-40...40)), Double(random.int(-40...40)))
                let picked: Int? = Handles.pick(touch, snapshot: s, camera: camera, size: size)
                #expect(picked == Self.expectedPick(touch, snapshot: s, camera: camera, size: size))
                if picked == nil { misses += 1 } else { hits += 1 }
            }
        }
        #expect(hits > 0 && misses > 0)
    }

    @Test func fiveHundredSeededDragsAgreeWithAnIndependentCandidate() throws {
        var random: WaveKnotKeeperRandom = WaveKnotKeeperRandom(seed: Self.seed)
        let snapshots: [WaveKnotKeeperSceneSnapshot] = Self.snapshots(count: 8)
        var some: Int = 0
        var none: Int = 0
        for _ in 0..<500 {
            let s: WaveKnotKeeperSceneSnapshot = snapshots[random.int(0...(snapshots.count - 1))]
            let aspect: Double = Double(random.int(40...250)) / 100
            let size: SIMD2<Double> = SIMD2(Self.height * aspect, Self.height)
            let orbit: WaveKnotKeeperOrbit = WaveKnotKeeperOrbit(yaw: Double(random.int(-40...40)),
                                                                 pitch: Double(random.int(5...60)))
            let camera: WaveKnotKeeperCamera = Geometry.camera(for: s, aspect: aspect, orbit: orbit)
            let point: Int = random.int(0...(s.points.count - 1))
            let angle: Double = Double(random.int(0...359)) * Double.pi / 180
            let distance: Double = Double(random.int(0...160))
            let drag: SIMD2<Double> = SIMD2(cos(angle), sin(angle)) * distance
            let got: WaveKnotKeeperDirection? = Handles.candidate(point: point, drag: drag, snapshot: s,
                                                                  camera: camera, size: size)
            let expected: WaveKnotKeeperDirection? = Self.expectedCandidate(point: point, drag: drag, snapshot: s,
                                                                            camera: camera, size: size)
            #expect(got == expected, "point \(point) drag \(drag) orbit \(orbit) aspect \(aspect)")
            if got == nil { none += 1 } else { some += 1 }
        }
        #expect(some > 100 && none > 10)
    }

    @Test func shortDragsAndUnusableInputGiveNoCandidate() throws {
        var random: WaveKnotKeeperRandom = WaveKnotKeeperRandom(seed: Self.seed)
        let size: SIMD2<Double> = SIMD2(1_152, Self.height)
        for s in Self.snapshots(count: 4) {
            let camera: WaveKnotKeeperCamera = Geometry.camera(for: s, aspect: size.x / size.y)
            for point in 0..<s.points.count {
                // Any drag shorter than 6 points.
                for _ in 0..<8 {
                    let angle: Double = Double(random.int(0...359)) * Double.pi / 180
                    let drag: SIMD2<Double> = SIMD2(cos(angle), sin(angle)) * (Double(random.int(0...59)) / 10)
                    #expect(Handles.candidate(point: point, drag: drag, snapshot: s, camera: camera,
                                              size: size) == nil)
                }
                // Along a step: just under max(6, half the step) and at max(6, a full step).
                for direction in WaveKnotKeeperDirection.allCases {
                    let step: SIMD2<Double> = try #require(Handles.projectedStep(
                        point: point, direction: direction, snapshot: s, camera: camera, size: size))
                    let l: Double = Self.norm(step)
                    guard l > 1e-6 else { continue }
                    let unit: SIMD2<Double> = step / l
                    let short: SIMD2<Double> = unit * (max(6, l / 2) * 0.99)
                    // The step's own direction cannot reach its snap (another, shorter step may).
                    #expect(Handles.candidate(point: point, drag: short, snapshot: s, camera: camera,
                                              size: size) != direction)
                    let full: SIMD2<Double> = unit * max(6, l)
                    #expect(Handles.candidate(point: point, drag: full, snapshot: s, camera: camera, size: size)
                            == Self.expectedCandidate(point: point, drag: full, snapshot: s, camera: camera,
                                                      size: size))
                }
            }
            #expect(Handles.candidate(point: 0, drag: .zero, snapshot: s, camera: camera, size: size) == nil)
            #expect(Handles.candidate(point: 0, drag: SIMD2(Double.nan, 50), snapshot: s, camera: camera,
                                      size: size) == nil)
            #expect(Handles.candidate(point: -1, drag: SIMD2(80, 0), snapshot: s, camera: camera, size: size) == nil)
            #expect(Handles.candidate(point: s.points.count, drag: SIMD2(80, 0), snapshot: s, camera: camera,
                                      size: size) == nil)
            #expect(Handles.projectedStep(point: s.points.count, direction: .plusX, snapshot: s, camera: camera,
                                          size: size) == nil)
        }
    }

    @Test func projectedStepMatchesTheViewProjection() throws {
        let size: SIMD2<Double> = SIMD2(1_152, Self.height)
        let s: WaveKnotKeeperSceneSnapshot = Self.snapshots(count: 1)[0]
        let camera: WaveKnotKeeperCamera = Geometry.camera(for: s, aspect: size.x / size.y)
        let start: SIMD3<Double> = Geometry.worldPoints(s)[0]
        let a: SIMD2<Double> = try #require(Self.screen(start, camera: camera, size: size))
        let b: SIMD2<Double> = try #require(Self.screen(start + SIMD3(0.125, 0, 0), camera: camera, size: size))
        let step: SIMD2<Double> = try #require(Handles.projectedStep(point: 0, direction: .plusX, snapshot: s,
                                                                     camera: camera, size: size))
        #expect(Self.norm(step - (b - a)) < 1e-6)
        // At the authored camera +x goes right on screen and +y goes up.
        #expect(step.x > 0)
        let up: SIMD2<Double> = try #require(Handles.projectedStep(point: 0, direction: .plusY, snapshot: s,
                                                                   camera: camera, size: size))
        #expect(up.y < 0)
    }
}
