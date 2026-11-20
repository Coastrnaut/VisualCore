// LissajousLabyrinthSceneGeometryTests — feature 313 (R02-G02-03) T-R02G0203-004 (FR-R02G0203-001, 006; clarifications
// Q1, Q3). Path samples equal the kernel's samples at every tier's stride (and shared samples agree across tiers); every
// path sample, checkpoint and obstacle centre projects inside the view with the 5 % margin for aspects 0.4 … 2.5 on
// certified levels and on the extreme level; every mesh is finite and inside the bounding sphere for all 55 coprime
// frequency pairs × phases at the largest amplitudes with frequency c = 9; triangle and vertex counts are as documented;
// the icosphere lies on the ball's radius. Test data uses explicit types and plain loops (CI type-check rule); seed 2_313.
import Foundation
import Testing
@testable import LissajousLabyrinthCore
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation

@Suite struct LissajousLabyrinthSceneGeometryTests {
    typealias Geometry = LissajousLabyrinthSceneGeometry

    /// The aspects the framing is checked for.
    static let aspects: [Double] = [0.4, 0.6, 0.75, 1, 1.5, 2, 2.5]
    /// The certified manifest entries used.
    static let entries: [Int] = [0, 20, 40, 60, 80]

    /// Snapshots of fresh plays of the certified levels, plus one at the shortest solution's dials where it applies.
    static func certifiedSnapshots() throws -> [LissajousLabyrinthSceneSnapshot] {
        var result: [LissajousLabyrinthSceneSnapshot] = []
        for n in entries {
            let generated: LissajousLabyrinthGenerated = try LissajousLabyrinthGenerator.generate(
                LissajousLabyrinthManifest.entries[n])
            var play: LissajousLabyrinthPlay = LissajousLabyrinthPlay(level: generated.level)
            try play.handle(.begin)
            result.append(LissajousLabyrinthSceneSnapshot(play: play, time: 3.5 + Double(n)))
        }
        return result
    }

    /// A level at the largest amplitudes 4, 4, 4 with frequency c = 9 and start `dials`; a far checkpoint and a far
    /// obstacle (radius 1,024 at the ±5,000 corners) stretch the bounds without ever being reached or touched.
    static func extremeLevel(_ dials: LissajousLabyrinthDials) throws -> LissajousLabyrinthLevel {
        let far: LissajousLabyrinthBall = try LissajousLabyrinthBall(x: 5_000, y: 5_000, z: 5_000, radius: 1_024)
        let low: LissajousLabyrinthBall = try LissajousLabyrinthBall(x: -5_000, y: -5_000, z: -5_000, radius: 1_024)
        return try LissajousLabyrinthLevel(id: "geometry-extreme", seed: 2_313, band: 5, amplitudes: [4, 4, 4],
                                           frequencyC: 9, start: dials, checkpoints: [far], obstacles: [low],
                                           allowance: 8)
    }

    /// A snapshot of a fresh play of `level` at `time`.
    static func snapshot(_ level: LissajousLabyrinthLevel, time: Double) -> LissajousLabyrinthSceneSnapshot {
        LissajousLabyrinthSceneSnapshot(play: LissajousLabyrinthPlay(level: level), time: time)
    }

    /// Whether `mesh` is finite, inside the sphere (with a small tolerance) and its indices are in range.
    static func wellFormed(_ mesh: Mesh, centre: Vec3, radius: Double) -> Bool {
        if mesh.normals.count != mesh.positions.count || mesh.uvs.count != mesh.positions.count { return false }
        for p in mesh.positions where !p.isFinite || (p - centre).length > radius + 1e-9 { return false }
        for n in mesh.normals where !n.isFinite || abs(n.length - 1) > 1e-9 { return false }
        for uv in mesh.uvs where !uv.isFinite { return false }
        for i in mesh.indices where Int(i) >= mesh.positions.count { return false }
        return mesh.indices.count % 3 == 0
    }

    // MARK: Path

    @Test func pathSamplesAreExactKernelSamplesAtEveryTier() throws {
        var snapshots: [LissajousLabyrinthSceneSnapshot] = try Self.certifiedSnapshots()
        snapshots.append(Self.snapshot(try Self.extremeLevel(LissajousLabyrinthDials(
            frequencyA: 8, frequencyB: 9, phaseA: 15, phaseC: 7)), time: 0))
        for s in snapshots {
            let kernel: [LissajousLabyrinthPoint] = LissajousLabyrinthLap.samples(s.dials, level: s.level)
            let full: [Vec3] = Geometry.path(s, tier: .of(0))
            #expect(full.count == 4_096)
            for tier in LissajousLabyrinthTier.all {
                let drawn: [Vec3] = Geometry.path(s, tier: tier)
                #expect(drawn.count == tier.samples)
                var exact: Bool = true
                for i in 0..<drawn.count {
                    let k: LissajousLabyrinthPoint = kernel[i * tier.stride]
                    let expected: Vec3 = Vec3(Double(k.x) / 1_024, Double(k.y) / 1_024, Double(k.z) / 1_024)
                    if drawn[i] != expected || drawn[i] != full[i * tier.stride] { exact = false }
                }
                #expect(exact, "tier \(tier.index)")
            }
            let head: Vec3 = Geometry.headPosition(s)
            #expect(head == full[s.headTick])
        }
    }

    // MARK: Camera

    @Test func everyPathSampleAndBallCentreFitsWithFivePercentMargin() throws {
        var snapshots: [LissajousLabyrinthSceneSnapshot] = try Self.certifiedSnapshots()
        snapshots.append(Self.snapshot(try Self.extremeLevel(LissajousLabyrinthDials(
            frequencyA: 1, frequencyB: 2, phaseA: 0, phaseC: 0)), time: 0))
        for s in snapshots {
            var points: [Vec3] = Geometry.path(s, tier: .of(0))
            for ball in s.level.checkpoints { points.append(Geometry.world(ball)) }
            for ball in s.level.obstacles { points.append(Geometry.world(ball)) }
            let b: (centre: Vec3, radius: Double) = Geometry.bounds(s)
            #expect(b.centre.isFinite && b.radius.isFinite && b.radius > 0)
            for aspect in Self.aspects {
                let height: Int = 64
                let width: Int = Int((Double(height) * aspect).rounded())
                let usedAspect: Double = Double(width) / Double(height)
                let vp: Mat4 = Geometry.viewProjection(aspect: usedAspect, snapshot: s)
                let cam: (eye: Vec3, target: Vec3, fovY: Double) = Geometry.camera(aspect: usedAspect, snapshot: s)
                #expect(cam.target == b.centre && cam.fovY == Double.pi / 4 && cam.eye.isFinite)
                var inside: Bool = true
                for p in points {
                    guard let q = Geometry.project(p, viewProjection: vp, width: width, height: height) else {
                        inside = false
                        continue
                    }
                    let mx: Double = 0.05 * Double(width), my: Double = 0.05 * Double(height)
                    if q.x < mx || q.x > Double(width) - mx || q.y < my || q.y > Double(height) - my { inside = false }
                }
                #expect(inside, "level \(s.level.id) aspect \(aspect)")
                let centre: Vec2? = Geometry.project(b.centre, aspect: usedAspect, snapshot: s, width: width,
                                                     height: height)
                #expect(centre != nil && abs(centre!.x - Double(width) / 2) < 1e-6
                        && abs(centre!.y - Double(height) / 2) < 1e-6)
            }
            #expect(Geometry.project(b.centre, aspect: 1, snapshot: s, width: 0, height: 64) == nil)
            let behind: Vec3 = Geometry.camera(aspect: 1, snapshot: s).eye + Geometry.eyeDirection
            #expect(Geometry.project(behind, aspect: 1, snapshot: s, width: 96, height: 64) == nil)
        }
    }

    // MARK: Meshes

    @Test func meshesAreFiniteAndBoundedForEveryCoprimePair() throws {
        let phases: [(Int, Int)] = [(0, 0), (15, 7), (8, 15)]
        var pairs: Int = 0
        for a in 1...9 {
            for b in 1...9 where LissajousLabyrinthDials(frequencyA: a, frequencyB: b, phaseA: 0, phaseC: 0).isValid {
                pairs += 1
                for (index, phase) in phases.enumerated() {
                    let dials: LissajousLabyrinthDials = LissajousLabyrinthDials(
                        frequencyA: a, frequencyB: b, phaseA: phase.0, phaseC: phase.1)
                    let s: LissajousLabyrinthSceneSnapshot = Self.snapshot(try Self.extremeLevel(dials),
                                                                           time: 1e9 + 0.25)
                    let box: (centre: Vec3, radius: Double) = Geometry.bounds(s)
                    let tier: LissajousLabyrinthTier = .of((a + b + index) % 3)
                    let thread: Mesh = try Geometry.threadMesh(s, tier: tier)
                    #expect(Self.wellFormed(thread, centre: box.centre, radius: box.radius), "thread \(a) \(b)")
                    #expect(thread.positions.count == 2 * tier.samples + 2 && thread.triangleCount == 2 * tier.samples)
                    let head: Mesh = try Geometry.headMesh(position: Geometry.headPosition(s))
                    #expect(Self.wellFormed(head, centre: box.centre, radius: box.radius), "head \(a) \(b)")
                    for ball in s.level.checkpoints {
                        let ring: Mesh = try Geometry.ringMesh(ball)
                        #expect(Self.wellFormed(ring, centre: box.centre, radius: box.radius))
                    }
                    for ball in s.level.obstacles {
                        let sphere: Mesh = try Geometry.sphereMesh(ball)
                        #expect(Self.wellFormed(sphere, centre: box.centre, radius: box.radius))
                    }
                }
            }
        }
        #expect(pairs == 55)
    }

    @Test func threadFacesTheCameraWithDocumentedAttributes() throws {
        let snapshots: [LissajousLabyrinthSceneSnapshot] = try Self.certifiedSnapshots()
        let s: LissajousLabyrinthSceneSnapshot = snapshots[2]
        let v: Vec3 = Geometry.viewDirection
        for tier in LissajousLabyrinthTier.all {
            let mesh: Mesh = try Geometry.threadMesh(s, tier: tier, width: 0.05, viewDirection: v)
            let points: [Vec3] = Geometry.path(s, tier: tier)
            #expect(mesh.positions.count == 2 * points.count + 2 && mesh.triangleCount == 2 * points.count)
            let n: Int = points.count
            #expect(mesh.positions[2 * n] == mesh.positions[0] && mesh.positions[2 * n + 1] == mesh.positions[1])
            #expect(mesh.uvs[2 * n] == Vec2(1, -1) && mesh.uvs[2 * n + 1] == Vec2(1, 1))
            var lastUsed: Bool = false
            for index in mesh.indices where Int(index) >= 2 * n { lastUsed = true }
            #expect(lastUsed)
            var ok: Bool = true
            for i in 0..<points.count {
                let minus: Vec3 = mesh.positions[2 * i], plus: Vec3 = mesh.positions[2 * i + 1]
                if abs((plus - minus).length - 0.05) > 1e-9 { ok = false }
                if ((plus + minus) * 0.5 - points[i]).length > 1e-12 { ok = false }
                if abs((plus - minus).dot(v)) > 1e-9 { ok = false }
                let u: Double = Double(i * tier.stride) / 4_096
                if mesh.uvs[2 * i] != Vec2(u, -1) || mesh.uvs[2 * i + 1] != Vec2(u, 1) { ok = false }
                if (mesh.normals[2 * i] + v).length > 1e-12 || (mesh.normals[2 * i + 1] + v).length > 1e-12 { ok = false }
            }
            var t: Int = 0
            while t < mesh.indices.count {
                let a: Vec3 = mesh.positions[Int(mesh.indices[t])]
                let b: Vec3 = mesh.positions[Int(mesh.indices[t + 1])]
                let c: Vec3 = mesh.positions[Int(mesh.indices[t + 2])]
                if (b - a).cross(c - a).dot(-v) < -1e-15 { ok = false }
                t += 3
            }
            #expect(ok, "tier \(tier.index)")
        }
        let fallback: Mesh = try Geometry.threadMesh(s, tier: .of(2), width: .nan, viewDirection: .zero)
        let expected: Mesh = try Geometry.threadMesh(s, tier: .of(2))
        #expect(fallback.indices == expected.indices && fallback.uvs == expected.uvs)
        var close: Bool = fallback.positions.count == expected.positions.count
        for i in 0..<min(fallback.positions.count, expected.positions.count)
        where (fallback.positions[i] - expected.positions[i]).length > 1e-12 { close = false }
        #expect(close)
    }

    @Test func ringSphereAndHeadCountsAndRadii() throws {
        var random: SeededRandom = SeededRandom(seed: 2_313)
        for _ in 0..<20 {
            let ball: LissajousLabyrinthBall = try LissajousLabyrinthBall(
                x: random.int(-5_000...5_000), y: random.int(-5_000...5_000), z: random.int(-5_000...5_000),
                radius: random.int(64...1_024))
            let centre: Vec3 = Geometry.world(ball)
            let r: Double = Double(ball.radius) / 1_024
            let sphere: Mesh = try Geometry.sphereMesh(ball)
            #expect(sphere.triangleCount == 320 && sphere.positions.count == 162)
            var onSphere: Bool = true
            for i in 0..<sphere.positions.count {
                let d: Vec3 = sphere.positions[i] - centre
                if abs(d.length - r) > 0.01 * r { onSphere = false }
                if d.normalized.dot(sphere.normals[i]) < 0.999 { onSphere = false }
            }
            var t: Int = 0
            while t < sphere.indices.count {
                let a: Vec3 = sphere.positions[Int(sphere.indices[t])]
                let b: Vec3 = sphere.positions[Int(sphere.indices[t + 1])]
                let c: Vec3 = sphere.positions[Int(sphere.indices[t + 2])]
                if (b - a).cross(c - a).dot((a + b + c) * (1.0 / 3) - centre) <= 0 { onSphere = false }
                t += 3
            }
            #expect(onSphere)
            let coarse: Mesh = try Geometry.sphereMesh(ball, subdivisions: 0)
            #expect(coarse.triangleCount == 20 && coarse.positions.count == 12)
            let ring: Mesh = try Geometry.ringMesh(ball, segments: 32)
            #expect(ring.triangleCount == 64 && ring.positions.count == 64)
            var annulus: Bool = true
            for i in 0..<ring.positions.count {
                let d: Vec3 = ring.positions[i] - centre
                let expected: Double = i % 2 == 0 ? 0.8 * r : r
                if abs(d.length - expected) > 1e-9 || abs(d.dot(Geometry.viewDirection)) > 1e-9 { annulus = false }
            }
            #expect(annulus)
            #expect(try Geometry.ringMesh(ball, segments: 2).triangleCount == 16)
            let band: Vec3 = Geometry.ringBandPoint(ball)
            let offset: Vec3 = band - centre
            #expect(abs(offset.length - 0.9 * r) < 1e-9 && abs(offset.dot(Geometry.viewDirection)) < 1e-9)
            #expect(offset.y > 0)
        }
        let head: Mesh = try Geometry.headMesh(position: Vec3(1, 2, 3))
        #expect(head.triangleCount == 24 && head.positions.count == 25)
        for p in head.positions { #expect(abs((p - Vec3(1, 2, 3)).length - (p == Vec3(1, 2, 3) ? 0 : 0.06)) < 1e-12) }
    }

    @Test func sameSnapshotGivesIdenticalGeometry() throws {
        let s: LissajousLabyrinthSceneSnapshot = try Self.certifiedSnapshots()[4]
        let first: Mesh = try Geometry.threadMesh(s, tier: .of(0))
        let second: Mesh = try Geometry.threadMesh(s, tier: .of(0))
        #expect(first == second)
        #expect(Geometry.viewProjection(aspect: 1.5, snapshot: s) == Geometry.viewProjection(aspect: 1.5, snapshot: s))
    }
}
