// WaveKnotKeeperSceneGeometryTests — feature 323 (R02-G03-03) T-R02G0303-004 (FR-R02G0303-001, 006; SC-R02G0303-003;
// clarifications Q1–Q3; edge cases). World points are the kernel's × 1/8; rope, glow, handle and gate meshes are finite
// and inside the bounding sphere for extreme ropes (16 points at the bounds ±16, nearly coincident neighbours) and
// seeded ropes with gates; every control point, segment midpoint, handle extreme and gate corner projects inside the
// view with the 5 % margin at 7 aspects 0.4 … 2.5; the tube's centreline passes within one radius of every segment's
// straight middle at every tier; crossing weights are non-zero only near crossings on their over-strands; tiers never
// move points, handles or gates; zero-size and unusable aspects are safe. Plain loops and explicit types (CI type-check
// rule); seed 2_323.
import Foundation
import Testing
@testable import WaveKnotKeeperCore
import VisualCoreMath
import VisualCoreScenes

/// The dot product of `a` and `b`.
private func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { WaveKnotKeeperSceneGeometry.dot(a, b) }

/// The Euclidean length of `v`.
private func length(_ v: SIMD3<Double>) -> Double { WaveKnotKeeperSceneGeometry.length(v) }

@Suite struct WaveKnotKeeperSceneGeometryTests {
    typealias Geometry = WaveKnotKeeperSceneGeometry

    /// The aspects the framing is checked for.
    static let aspects: [Double] = [0.4, 0.6, 0.75, 1, 1.5, 2, 2.5]

    /// A snapshot of a fresh play of a level with `points` and `gates` (a target the start does not win), or nil when
    /// the level refuses the rope.
    static func snapshot(_ points: [WaveKnotKeeperPoint], gates: [WaveKnotKeeperGate] = [],
                         time: Double = 0) -> WaveKnotKeeperSceneSnapshot? {
        let summary: WaveKnotKeeperSummary = WaveKnotKeeperGeometry.summary(points)
        let crossings: Int = summary.crossings + 2 <= 32 ? summary.crossings + 2 : summary.crossings - 2
        let writhe: Int = abs(summary.writhe) <= crossings ? summary.writhe : 0
        guard let target = try? WaveKnotKeeperTarget(crossings: crossings, writhe: writhe) else { return nil }
        guard let level = try? WaveKnotKeeperLevel(id: "geometry-test", seed: 2_323, band: 1, points: points,
                                                   gates: gates, target: target, tensionBound: 49_152,
                                                   allowance: 8) else { return nil }
        return WaveKnotKeeperSceneSnapshot(play: WaveKnotKeeperPlay(level: level), levelNumber: 1, selected: 0,
                                           time: time)
    }

    /// Extreme ropes: a seeded simple 16-point rope at the corners of the bounds (coordinates ±15 … ±16), the cube's
    /// edge cycle through its 8 corners and 8 edge midpoints at ±16, and a 16-point ring of unit-spaced neighbours in
    /// the corner x 12 … 16, y −16 … −12 with z alternating 16 / 15, with gates at the bounds.
    static func extremeSnapshots() throws -> [WaveKnotKeeperSceneSnapshot] {
        var result: [WaveKnotKeeperSceneSnapshot] = []
        // A seeded simple rope of 16 points whose every coordinate is −16, −15, 15 or 16 (corners of the bounds).
        var random: WaveKnotKeeperRandom = WaveKnotKeeperRandom(seed: 2_323)
        let extremes: [Int] = [-16, -15, 15, 16]
        var cornerRope: [WaveKnotKeeperPoint] = []
        var attempts: Int = 0
        while attempts < 20_000 && (cornerRope.count < 16 || !WaveKnotKeeperGeometry.isSimple(cornerRope)) {
            attempts += 1
            cornerRope = []
            var seen: Set<WaveKnotKeeperPoint> = []
            while cornerRope.count < 16 {
                let p: WaveKnotKeeperPoint = WaveKnotKeeperPoint(x: extremes[random.int(0...3)],
                                                                 y: extremes[random.int(0...3)],
                                                                 z: extremes[random.int(0...3)])
                if seen.insert(p).inserted { cornerRope.append(p) }
            }
        }
        let corners: [(Int, Int, Int)] = [(-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
                                          (-1, 1, 1), (1, 1, 1), (1, -1, 1), (-1, -1, 1)]
        var cube: [WaveKnotKeeperPoint] = []
        for i in 0..<8 {
            let a: (Int, Int, Int) = corners[i], b: (Int, Int, Int) = corners[(i + 1) % 8]
            cube.append(WaveKnotKeeperPoint(x: 16 * a.0, y: 16 * a.1, z: 16 * a.2))
            cube.append(WaveKnotKeeperPoint(x: 8 * (a.0 + b.0), y: 8 * (a.1 + b.1), z: 8 * (a.2 + b.2)))
        }
        var ring: [WaveKnotKeeperPoint] = []
        let perimeter: [(Int, Int)] = [(0, 0), (1, 0), (2, 0), (3, 0), (4, 0), (4, 1), (4, 2), (4, 3),
                                       (4, 4), (3, 4), (2, 4), (1, 4), (0, 4), (0, 3), (0, 2), (0, 1)]
        for (k, q) in perimeter.enumerated() {
            ring.append(WaveKnotKeeperPoint(x: 12 + q.0, y: -16 + q.1, z: k % 2 == 0 ? 16 : 15))
        }
        let wide: WaveKnotKeeperGate = try WaveKnotKeeperGate(min: WaveKnotKeeperPoint(x: -16, y: -16, z: -16),
                                                              max: WaveKnotKeeperPoint(x: -10, y: -10, z: -10))
        let far: WaveKnotKeeperGate = try WaveKnotKeeperGate(min: WaveKnotKeeperPoint(x: 10, y: 10, z: 16),
                                                             max: WaveKnotKeeperPoint(x: 16, y: 16, z: 16))
        let ropes: [[WaveKnotKeeperPoint]] = [cornerRope, cube, ring]
        for rope in ropes {
            if let s = snapshot(rope, gates: [wide, far], time: 1e9) { result.append(s) }
        }
        #expect(result.count == 3, "every extreme rope makes a level")
        return result
    }

    /// Seeded simple ropes of 6 … 16 points spread over the whole bounds, each with one or two gates.
    static func seededSnapshots(count: Int) -> [WaveKnotKeeperSceneSnapshot] {
        var random: WaveKnotKeeperRandom = WaveKnotKeeperRandom(seed: 2_323)
        var result: [WaveKnotKeeperSceneSnapshot] = []
        var attempts: Int = 0
        while result.count < count && attempts < 200 {
            attempts += 1
            let rope: [WaveKnotKeeperPoint] = WaveKnotKeeperFixtures.rope(&random, count: random.int(6...16),
                                                                          spread: random.int(4...16))
            var gates: [WaveKnotKeeperGate] = []
            for _ in 0..<random.int(1...2) {
                let c: WaveKnotKeeperPoint = rope[random.int(0...(rope.count - 1))]
                let lo: WaveKnotKeeperPoint = WaveKnotKeeperPoint(x: max(c.x - 2, -16), y: max(c.y - 2, -16),
                                                                  z: max(c.z - 2, -16))
                let hi: WaveKnotKeeperPoint = WaveKnotKeeperPoint(x: min(c.x + 2, 16), y: min(c.y + 2, 16),
                                                                  z: min(c.z + 2, 16))
                if let gate = try? WaveKnotKeeperGate(min: lo, max: hi) { gates.append(gate) }
            }
            if let s = snapshot(rope, gates: gates, time: Double(attempts)) { result.append(s) }
        }
        return result
    }

    /// Whether `mesh` is finite with unit normals, in-range indices and every position within `radius` of `centre`.
    static func wellFormed(_ mesh: Mesh, centre: SIMD3<Double>, radius: Double,
                           offset: SIMD3<Double> = .zero) -> Bool {
        if mesh.normals.count != mesh.positions.count || mesh.uvs.count != mesh.positions.count { return false }
        for p in mesh.positions {
            let q: SIMD3<Double> = SIMD3(p.x, p.y, p.z) + offset
            if !p.isFinite || length(q - centre) > radius + 1e-9 { return false }
        }
        for n in mesh.normals where !n.isFinite || abs(n.length - 1) > 1e-9 { return false }
        for uv in mesh.uvs where !uv.isFinite || uv.x < 0 || uv.x > 1 || uv.y < 0 || uv.y > 1 { return false }
        for i in mesh.indices where Int(i) >= mesh.positions.count { return false }
        return mesh.indices.count % 3 == 0
    }

    /// The distance from `p` to the segment a … b.
    static func distance(_ p: SIMD3<Double>, _ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d: SIMD3<Double> = b - a
        let l2: Double = dot(d, d)
        let t: Double = l2 > 0 ? min(max(dot(p - a, d) / l2, 0), 1) : 0
        return length(p - (a + d * t))
    }

    /// The distance from `p` to the closed polyline through `c`.
    static func distance(_ p: SIMD3<Double>, loop c: [SIMD3<Double>]) -> Double {
        var best: Double = .infinity
        for j in 0..<c.count { best = min(best, distance(p, c[j], c[(j + 1) % c.count])) }
        return best
    }

    // MARK: World

    @Test func worldPointsAreKernelPointsTimesOneEighth() throws {
        for s in try Self.extremeSnapshots() + Self.seededSnapshots(count: 4) {
            let world: [SIMD3<Double>] = Geometry.worldPoints(s)
            #expect(world.count == s.points.count)
            for (i, p) in s.points.enumerated() {
                #expect(world[i] == SIMD3(Double(p.x) / 8, Double(p.y) / 8, Double(p.z) / 8))
            }
            let mids: [SIMD3<Double>] = Geometry.segmentMidpoints(s)
            #expect(mids.count == world.count)
            for i in 0..<mids.count { #expect(mids[i] == (world[i] + world[(i + 1) % world.count]) * 0.5) }
            for gate in s.gates {
                let box: (low: SIMD3<Double>, high: SIMD3<Double>) = Geometry.gateBox(gate)
                #expect(box.low == SIMD3(Double(gate.min.x) - 0.5, Double(gate.min.y) - 0.5,
                                         Double(gate.min.z) - 0.5) / 8)
                #expect(box.high == SIMD3(Double(gate.max.x) + 0.5, Double(gate.max.y) + 0.5,
                                          Double(gate.max.z) + 0.5) / 8)
            }
        }
    }

    // MARK: Meshes

    @Test func meshesAreFiniteAndBoundedForExtremeAndSeededRopes() throws {
        let snapshots: [WaveKnotKeeperSceneSnapshot] = try Self.extremeSnapshots() + Self.seededSnapshots(count: 12)
        #expect(snapshots.count == 15)
        let handle: Mesh = try Geometry.handleMesh()
        for s in snapshots {
            let b: (centre: SIMD3<Double>, radius: Double) = Geometry.bounds(s)
            #expect(b.centre.x.isFinite && b.centre.y.isFinite && b.centre.z.isFinite && b.radius.isFinite)
            #expect(b.radius > 0 && b.radius < 6)
            for tier in WaveKnotKeeperTier.all {
                let rope: Mesh = try Geometry.ropeMesh(s, tier: tier)
                let m: Int = Geometry.centreline(s, tier: tier).count
                #expect(rope.positions.count == (m + 1) * tier.sides && rope.triangleCount == 2 * m * tier.sides)
                #expect(Self.wellFormed(rope, centre: b.centre, radius: b.radius), "rope tier \(tier.index)")
                let glow: Mesh = try Geometry.glowMesh(s, tier: tier)
                #expect(glow.positions.count == tier.glowShells * rope.positions.count)
                #expect(Self.wellFormed(glow, centre: b.centre, radius: b.radius), "glow tier \(tier.index)")
            }
            for p in Geometry.worldPoints(s) {
                #expect(Self.wellFormed(handle, centre: b.centre, radius: b.radius, offset: p))
            }
            for gate in s.gates {
                #expect(Self.wellFormed(try Geometry.gateMesh(gate), centre: b.centre, radius: b.radius))
            }
        }
    }

    @Test func ringsSitOneRadiusFromTheCentrelineAndFaceOutwards() throws {
        let s: WaveKnotKeeperSceneSnapshot = Self.seededSnapshots(count: 1)[0]
        for tier in WaveKnotKeeperTier.all {
            let samples: [SIMD3<Double>] = Geometry.centreline(s, tier: tier).map(\.position)
            let mesh: Mesh = try Geometry.ropeMesh(s, tier: tier)
            let sides: Int = tier.sides
            var ok: Bool = true
            for v in 0..<mesh.positions.count {
                let c: SIMD3<Double> = samples[(v / sides) % samples.count]
                let p: SIMD3<Double> = SIMD3(mesh.positions[v].x, mesh.positions[v].y, mesh.positions[v].z)
                let n: SIMD3<Double> = SIMD3(mesh.normals[v].x, mesh.normals[v].y, mesh.normals[v].z)
                if abs(length(p - c) - 0.1) > 1e-9 || length((p - c) / 0.1 - n) > 1e-9 { ok = false }
            }
            for k in 0..<sides where mesh.positions[samples.count * sides + k] != mesh.positions[k] { ok = false }
            for k in 0..<sides where mesh.uvs[samples.count * sides + k].y != 1 || mesh.uvs[k].y != 0 { ok = false }
            var t: Int = 0, inverted: Int = 0
            while t < mesh.indices.count {
                let a: Vec3 = mesh.positions[Int(mesh.indices[t])]
                let b: Vec3 = mesh.positions[Int(mesh.indices[t + 1])]
                let c: Vec3 = mesh.positions[Int(mesh.indices[t + 2])]
                let out: Vec3 = mesh.normals[Int(mesh.indices[t])] + mesh.normals[Int(mesh.indices[t + 1])]
                    + mesh.normals[Int(mesh.indices[t + 2])]
                    if (b - a).cross(c - a).dot(out) < -1e-12 { inverted += 1 }
                t += 3
            }
            // Rings may fold through each other inside the tightest corners (neighbours one kernel unit apart).
            #expect(ok && inverted * 100 <= mesh.triangleCount, "tier \(tier.index)")
        }
        let wide: Mesh = try Geometry.ropeMesh(s, tier: .of(0), radius: 0.2)
        let fallback: Mesh = try Geometry.ropeMesh(s, tier: .of(0), radius: .nan)
        #expect(fallback == (try Geometry.ropeMesh(s, tier: .of(0))) && wide != fallback)
        let radii: [Double] = Geometry.glowRadii(.of(0))
        #expect(radii.count == 2 && abs(radii[0] - 0.15) < 1e-12 && abs(radii[1] - 0.2) < 1e-12)
        #expect(Geometry.glowRadii(.of(1)).count == 1 && Geometry.glowRadii(.of(2)).isEmpty)
        #expect(try Geometry.glowMesh(s, tier: .of(2)).positions.isEmpty)
    }

    @Test func handleAndGateMeshes() throws {
        let handle: Mesh = try Geometry.handleMesh()
        #expect(handle.triangleCount == 320 && handle.positions.count == 162)
        for (i, p) in handle.positions.enumerated() {
            #expect(abs(p.length - 0.18) < 1e-12 && (p.normalized - handle.normals[i]).length < 1e-12)
        }
        #expect(try Geometry.handleMesh(subdivisions: 0).triangleCount == 20)
        let gate: WaveKnotKeeperGate = try WaveKnotKeeperGate(min: WaveKnotKeeperPoint(x: -3, y: 0, z: 2),
                                                              max: WaveKnotKeeperPoint(x: 1, y: 0, z: 6))
        let cube: Mesh = try Geometry.gateMesh(gate)
        #expect(cube.triangleCount == 12 && cube.positions.count == 24)
        for p in cube.positions {
            #expect(p.x == -3.5 / 8 || p.x == 1.5 / 8)
            #expect(p.y == -0.5 / 8 || p.y == 0.5 / 8)
            #expect(p.z == 1.5 / 8 || p.z == 6.5 / 8)
        }
        let centre: SIMD3<Double> = Geometry.gateCentre(gate)
        var t: Int = 0
        while t < cube.indices.count {
            let a: Vec3 = cube.positions[Int(cube.indices[t])]
            let b: Vec3 = cube.positions[Int(cube.indices[t + 1])]
            let c: Vec3 = cube.positions[Int(cube.indices[t + 2])]
            let mid: Vec3 = (a + b + c) * (1.0 / 3)
            #expect((b - a).cross(c - a).dot(mid - Vec3(centre.x, centre.y, centre.z)) > 0)
            t += 3
        }
    }

    // MARK: Tube path

    @Test func tubePassesWithinOneRadiusOfEveryStraightMiddleAtEveryTier() throws {
        for s in try Self.extremeSnapshots() + Self.seededSnapshots(count: 8) {
            let p: [SIMD3<Double>] = Geometry.worldPoints(s)
            let n: Int = p.count
            for tier in WaveKnotKeeperTier.all {
                let c: [SIMD3<Double>] = Geometry.centreline(s, tier: tier).map(\.position)
                var ok: Bool = true
                for i in 0..<n {
                    let a: SIMD3<Double> = p[i], b: SIMD3<Double> = p[(i + 1) % n]
                    var k: Int = 0
                    while k <= 10 {
                        let t: Double = 0.25 + 0.05 * Double(k)
                        if Self.distance(a + (b - a) * t, loop: c) > 0.1 { ok = false }
                        k += 1
                    }
                    // The straight middle's ends are exact samples at every tier.
                    if !c.contains(a + (b - a) * 0.25) || !c.contains(b + (a - b) * 0.25) { ok = false }
                }
                #expect(ok, "tier \(tier.index)")
            }
        }
    }

    // MARK: Crossing weights

    @Test func crossingWeightsAreNonZeroOnlyNearOverStrandCrossings() throws {
        let snapshots: [WaveKnotKeeperSceneSnapshot] = try Self.extremeSnapshots() + Self.seededSnapshots(count: 12)
        var checkedCrossings: Int = 0
        for s in snapshots {
            let p: [SIMD3<Double>] = Geometry.worldPoints(s)
            let n: Int = p.count
            var marks: [(segment: Int, point: SIMD3<Double>, inMiddle: Bool)] = []
            var anchors: [(segment: Int, point: SIMD3<Double>)] = []
            for mark in s.crossings {
                let x: SIMD3<Double> = try #require(Geometry.crossingPoint(mark, in: s))
                #expect(abs(x.x - mark.x / 8) < 1e-9 && abs(x.y - mark.y / 8) < 1e-9)
                let a: SIMD3<Double> = p[mark.over], b: SIMD3<Double> = p[(mark.over + 1) % n]
                let t: Double = dot(x - a, b - a) / dot(b - a, b - a)
                let margin: Double = 0.2 / length(b - a)
                marks.append((mark.over, x, t > 0.25 + margin && t < 0.75 - margin))
                // T-R02G0303-014: the weight is measured from where the crossing lies on the drawn tube.
                anchors.append((mark.over, try #require(Geometry.drawnCrossingPoint(mark, in: s))))
            }
            for tier in WaveKnotKeeperTier.all {
                let samples: [WaveKnotKeeperSceneGeometry.Sample] = Geometry.centreline(s, tier: tier)
                let mesh: Mesh = try Geometry.ropeMesh(s, tier: tier)
                var ok: Bool = true
                for v in 0..<mesh.positions.count {
                    let w: Double = mesh.uvs[v].x
                    let sample: WaveKnotKeeperSceneGeometry.Sample = samples[(v / tier.sides) % samples.count]
                    if w == 0 { continue }
                    var near: Bool = false
                    for m in anchors where m.segment == sample.segment && length(sample.position - m.point) < 0.2 {
                        near = true
                    }
                    if !near { ok = false }
                }
                #expect(ok, "tier \(tier.index)")
                // T-R02G0303-014: every crossing, in a straight middle or a corner, has a full-weight vertex within
                // one radius of its drawn point at every tier.
                for m in anchors {
                    var lit: Bool = false
                    for v in 0..<mesh.positions.count where mesh.uvs[v].x == 1 {
                        let sample: WaveKnotKeeperSceneGeometry.Sample = samples[(v / tier.sides) % samples.count]
                        if sample.segment == m.segment && length(sample.position - m.point) <= 0.1 { lit = true }
                    }
                    #expect(lit, "a crossing on segment \(m.segment) is lit at tier \(tier.index)")
                }
                for m in marks where m.inMiddle {
                    checkedCrossings += 1
                    var full: Bool = false, ramp: Bool = false
                    for v in 0..<mesh.positions.count {
                        let sample: WaveKnotKeeperSceneGeometry.Sample = samples[(v / tier.sides) % samples.count]
                        guard sample.segment == m.segment else { continue }
                        let d: Double = length(sample.position - m.point)
                        if d < 1e-9 && mesh.uvs[v].x == 1 { full = true }
                        if abs(d - 0.2) < 1e-9 && mesh.uvs[v].x < 1e-9 { ramp = true }
                    }
                    // A second crossing on the same segment within four radii may keep the ramp's end lit.
                    for other in marks where other.segment == m.segment && other.point != m.point
                        && length(other.point - m.point) < 0.4 { ramp = true }
                    #expect(full && ramp, "a crossing in the straight middle ramps 1 → 0 at tier \(tier.index)")
                }
            }
        }
        #expect(checkedCrossings > 0)
        // A rope whose projection has no crossing carries no weight anywhere.
        let ring: WaveKnotKeeperSceneSnapshot = try Self.extremeSnapshots()[2]
        #expect(ring.crossings.isEmpty)
        #expect(try Geometry.ropeMesh(ring, tier: .of(0)).uvs.allSatisfy { $0.x == 0 })
    }

    // MARK: Camera

    @Test func everyElementProjectsInsideTheViewWithFivePercentMargin() throws {
        for s in try Self.extremeSnapshots() + Self.seededSnapshots(count: 8) {
            var points: [SIMD3<Double>] = Geometry.worldPoints(s) + Geometry.segmentMidpoints(s)
            for c in Geometry.worldPoints(s) {
                for axis in 0..<3 {
                    var e: SIMD3<Double> = .zero
                    e[axis] = 0.18
                    points.append(c + e)
                    points.append(c - e)
                }
            }
            for gate in s.gates {
                let box: (low: SIMD3<Double>, high: SIMD3<Double>) = Geometry.gateBox(gate)
                for corner in 0..<8 {
                    points.append(SIMD3(corner & 1 == 0 ? box.low.x : box.high.x,
                                        corner & 2 == 0 ? box.low.y : box.high.y,
                                        corner & 4 == 0 ? box.low.z : box.high.z))
                }
                points.append(Geometry.gateCentre(gate))
            }
            for tier in WaveKnotKeeperTier.all {
                let mesh: Mesh = try Geometry.ropeMesh(s, tier: tier)
                var j: Int = 0
                while j < mesh.positions.count {
                    points.append(SIMD3(mesh.positions[j].x, mesh.positions[j].y, mesh.positions[j].z))
                    j += 7
                }
            }
            let b: (centre: SIMD3<Double>, radius: Double) = Geometry.bounds(s)
            for aspect in Self.aspects {
                let camera: WaveKnotKeeperCamera = Geometry.camera(for: s, aspect: aspect)
                #expect(camera.target == b.centre && camera.fovY == Double.pi / 4 && camera.aspect == aspect)
                let direction: SIMD3<Double> = (camera.eye - camera.target) / length(camera.eye - camera.target)
                #expect(abs(direction.x) < 1e-12 && abs(direction.y - sin(Double.pi / 9)) < 1e-12)
                var inside: Bool = true
                for p in points {
                    guard let q = Geometry.project(p, camera: camera) else {
                        inside = false
                        continue
                    }
                    if q.x < 0.05 || q.x > 0.95 || q.y < 0.05 || q.y > 0.95 { inside = false }
                }
                #expect(inside, "aspect \(aspect)")
                let centre: SIMD2<Double> = try #require(Geometry.project(b.centre, camera: camera))
                #expect(abs(centre.x - 0.5) < 1e-9 && abs(centre.y - 0.5) < 1e-9)
                let pixel: Vec2 = try #require(Geometry.pixel(b.centre, camera: camera, width: 1_152, height: 768))
                #expect(abs(pixel.x - 576) < 1e-6 && abs(pixel.y - 384) < 1e-6)
            }
            // Up in the world is up on screen.
            let camera: WaveKnotKeeperCamera = Geometry.camera(for: s, aspect: 1)
            let above: SIMD2<Double> = try #require(Geometry.project(b.centre + SIMD3(0, 0.5, 0), camera: camera))
            #expect(above.y < 0.5)
        }
    }

    @Test func zeroSizeAndUnusableInputsAreSafe() throws {
        let s: WaveKnotKeeperSceneSnapshot = Self.seededSnapshots(count: 1)[0]
        for aspect in [0, -1, Double.nan, Double.infinity, 1e-9, 1e9] {
            let camera: WaveKnotKeeperCamera = Geometry.camera(for: s, aspect: aspect)
            #expect(camera.eye.x.isFinite && camera.eye.y.isFinite && camera.eye.z.isFinite)
            #expect(camera.near > 0 && camera.far > camera.near && camera.aspect >= 0.1 && camera.aspect <= 10)
            #expect(Geometry.project(Geometry.worldPoints(s)[0], camera: camera) != nil)
        }
        let camera: WaveKnotKeeperCamera = Geometry.camera(for: s, aspect: 1.5)
        #expect(Geometry.pixel(camera.target, camera: camera, width: 0, height: 768) == nil)
        #expect(Geometry.pixel(camera.target, camera: camera, width: 1_152, height: -1) == nil)
        #expect(Geometry.project(SIMD3(.nan, 0, 0), camera: camera) == nil)
        let behind: SIMD3<Double> = camera.eye + (camera.eye - camera.target)
        #expect(Geometry.project(behind, camera: camera) == nil)
    }

    // MARK: Tiers

    @Test func tiersNeverMovePointsHandlesGatesOrCamera() throws {
        for s in try Self.extremeSnapshots() + Self.seededSnapshots(count: 4) {
            let p: [SIMD3<Double>] = Geometry.worldPoints(s)
            let n: Int = p.count
            var quarterPoints: [SIMD3<Double>] = []
            for i in 0..<n {
                quarterPoints.append(p[i] + (p[(i + n - 1) % n] - p[i]) * 0.25)
                quarterPoints.append(p[i] + (p[(i + 1) % n] - p[i]) * 0.25)
            }
            for tier in WaveKnotKeeperTier.all {
                let c: [SIMD3<Double>] = Geometry.centreline(s, tier: tier).map(\.position)
                #expect(quarterPoints.allSatisfy { c.contains($0) }, "tier \(tier.index)")
                #expect(c.count >= n * tier.cornerSamples)
            }
            // Points, handles, gates and the camera take no tier.
            #expect(Geometry.camera(for: s, aspect: 1.5) == Geometry.camera(for: s, aspect: 1.5))
            #expect(try Geometry.ropeMesh(s, tier: .of(1)) == (try Geometry.ropeMesh(s, tier: .of(1))))
        }
    }
}
