// LissajousLabyrinthSceneGeometryTests — feature 313 (R02-G02-03) T-R02G0203-004 (FR-R02G0203-001, 006; clarifications
// Q1, Q3). Path samples equal the kernel's samples at every tier's stride (and shared samples agree across tiers); every
// path sample, checkpoint and obstacle centre projects inside the view with the 5 % margin for aspects 0.4 … 2.5 on
// certified levels and on the extreme level; every mesh is finite and inside the bounding sphere for all 55 coprime
// frequency pairs × phases at the largest amplitudes with frequency c = 9; triangle and vertex counts are as documented;
// the icosphere lies on the ball's radius. Test data uses explicit types and plain loops (CI type-check rule); seed 2_313.
// Feature 314 (R02-G02-04) T-R02G0204-002 (FR-R02G0204-001, 002, 004; clarifications Q1, Q3; research R1, R6): the camera
// targets the centre of `contentBounds` (stage and rings); the stage holds every path sample of all 100 certified levels
// at the start and the solution dials; stage and rings lie inside NDC ±0.9 for the authored orbit, the four corner limits
// and the four mid-edges at aspects 0.4 … 2.5; the orbit clamps and its authored direction is `eyeDirection`.
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
            let content: (centre: Vec3, radius: Double) = Geometry.contentBounds(level: s.level)
            for aspect in Self.aspects {
                let height: Int = 64
                let width: Int = Int((Double(height) * aspect).rounded())
                let usedAspect: Double = Double(width) / Double(height)
                let vp: Mat4 = Geometry.viewProjection(aspect: usedAspect, snapshot: s)
                let cam: (eye: Vec3, target: Vec3, fovY: Double) = Geometry.camera(aspect: usedAspect, snapshot: s)
                // Feature 314: the camera now fits the dial-independent content (stage and rings), not `bounds(_:)`.
                #expect(cam.target == content.centre && cam.fovY == Double.pi / 4 && cam.eye.isFinite)
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
                let centre: Vec2? = Geometry.project(content.centre, aspect: usedAspect, snapshot: s, width: width,
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

    // MARK: Stage, content and orbit (feature 314)

    /// The 100 certified levels and their solutions' final dials, read from the stored witness files (decoded without
    /// the replay, which `LissajousLabyrinthCatalogTests` already proves equal to the regenerated catalog).
    static func certifiedLevels() throws -> [(level: LissajousLabyrinthLevel, solved: LissajousLabyrinthDials)] {
        let directory: URL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/games/lissajous-labyrinth/levels", isDirectory: true)
        var result: [(level: LissajousLabyrinthLevel, solved: LissajousLabyrinthDials)] = []
        for entry in LissajousLabyrinthManifest.entries {
            let name: String = String(LissajousLabyrinthGenerator.levelID(entry.number).suffix(3)) + ".witness.json"
            let data: Data = try Data(contentsOf: directory.appendingPathComponent(name))
            let witness: LissajousLabyrinthWitness = try JSONDecoder().decode(LissajousLabyrinthWitness.self, from: data)
            var dials: LissajousLabyrinthDials = witness.level.start
            for action in witness.actions { dials[action.dial] = action.value }
            result.append((witness.level, dials))
        }
        return result
    }

    /// The orbits the framing is checked at: authored, the four corner limits and the four mid-edges.
    static var orbits: [LissajousLabyrinthOrbit] {
        let low: Double = LissajousLabyrinthOrbit.azimuthRange.lowerBound
        let high: Double = LissajousLabyrinthOrbit.azimuthRange.upperBound
        let bottom: Double = LissajousLabyrinthOrbit.elevationRange.lowerBound
        let top: Double = LissajousLabyrinthOrbit.elevationRange.upperBound
        let middle: Double = (bottom + top) / 2
        var result: [LissajousLabyrinthOrbit] = [LissajousLabyrinthOrbit.authored]
        result.append(LissajousLabyrinthOrbit(azimuthOffset: low, elevation: bottom))
        result.append(LissajousLabyrinthOrbit(azimuthOffset: low, elevation: top))
        result.append(LissajousLabyrinthOrbit(azimuthOffset: high, elevation: bottom))
        result.append(LissajousLabyrinthOrbit(azimuthOffset: high, elevation: top))
        result.append(LissajousLabyrinthOrbit(azimuthOffset: 0, elevation: bottom))
        result.append(LissajousLabyrinthOrbit(azimuthOffset: 0, elevation: top))
        result.append(LissajousLabyrinthOrbit(azimuthOffset: low, elevation: middle))
        result.append(LissajousLabyrinthOrbit(azimuthOffset: high, elevation: middle))
        return result
    }

    @Test func stageHoldsEveryPathOfAllCertifiedLevelsAtStartAndSolution() throws {
        let levels: [(level: LissajousLabyrinthLevel, solved: LissajousLabyrinthDials)] = try Self.certifiedLevels()
        #expect(levels.count == 100)
        for item in levels {
            let stage: (centre: Vec3, radius: Double) = Geometry.stageBounds(level: item.level)
            #expect(stage.centre.isFinite && stage.radius > 0)
            var inside: Bool = true
            for dials in [item.level.start, item.solved] {
                for p in LissajousLabyrinthLap.samples(dials, level: item.level) {
                    if (Geometry.world(p) - stage.centre).length + Geometry.pathMargin > stage.radius + 1e-9 {
                        inside = false
                    }
                }
            }
            var balls: [LissajousLabyrinthBall] = item.level.checkpoints
            for ball in item.level.obstacles { balls.append(ball) }
            for ball in balls where (Geometry.world(ball) - stage.centre).length + Geometry.radius(ball)
                > stage.radius + 1e-9 { inside = false }
            #expect(inside, "level \(item.level.id)")
            // The drawn figure's bounds lie inside the stage, and the stage inside the content.
            let snapshot: LissajousLabyrinthSceneSnapshot = Self.snapshot(item.level, time: 0)
            let figure: (centre: Vec3, radius: Double) = Geometry.bounds(snapshot)
            #expect((figure.centre - stage.centre).length + figure.radius <= stage.radius + 1e-9)
            let content: (centre: Vec3, radius: Double) = Geometry.contentBounds(level: item.level)
            #expect((stage.centre - content.centre).length + stage.radius <= content.radius + 1e-9)
        }
    }

    @Test func stageIsIndependentOfTheDialsOnTheExtremeLevel() throws {
        let first: LissajousLabyrinthLevel = try Self.extremeLevel(LissajousLabyrinthDials(
            frequencyA: 1, frequencyB: 2, phaseA: 0, phaseC: 0))
        let stage: (centre: Vec3, radius: Double) = Geometry.stageBounds(level: first)
        var inside: Bool = true
        for a in 1...9 {
            for b in 1...9 {
                let dials: LissajousLabyrinthDials = LissajousLabyrinthDials(frequencyA: a, frequencyB: b,
                                                                             phaseA: (a * 3) % 16, phaseC: (b * 5) % 16)
                guard dials.isValid else { continue }
                let level: LissajousLabyrinthLevel = try Self.extremeLevel(dials)
                let other: (centre: Vec3, radius: Double) = Geometry.stageBounds(level: level)
                if other.centre != stage.centre || other.radius != stage.radius { inside = false }
                for p in LissajousLabyrinthLap.samples(dials, level: level)
                where (Geometry.world(p) - stage.centre).length + Geometry.pathMargin > stage.radius + 1e-9 {
                    inside = false
                }
            }
        }
        #expect(inside)
    }

    @Test func orbitConstantsAndClamping() {
        let degree: Double = Double.pi / 180
        let authored: LissajousLabyrinthOrbit = LissajousLabyrinthOrbit.authored
        #expect(authored.azimuthOffset == 0)
        #expect(abs(LissajousLabyrinthOrbit.azimuth - atan2(0.55, 1.0)) < 1e-15)
        #expect(abs(authored.elevation / degree - 21.5) < 0.1)
        #expect((authored.eyeDirection - Geometry.eyeDirection).length < 1e-12)
        #expect(abs(LissajousLabyrinthOrbit.azimuthRange.lowerBound + 40 * degree) < 1e-15)
        #expect(abs(LissajousLabyrinthOrbit.azimuthRange.upperBound - 40 * degree) < 1e-15)
        #expect(abs(LissajousLabyrinthOrbit.elevationRange.lowerBound - 10 * degree) < 1e-15)
        #expect(abs(LissajousLabyrinthOrbit.elevationRange.upperBound - 60 * degree) < 1e-15)
        #expect(authored.clamped() == authored)
        let wide: LissajousLabyrinthOrbit = LissajousLabyrinthOrbit(azimuthOffset: 2, elevation: 3).clamped()
        #expect(wide == LissajousLabyrinthOrbit(azimuthOffset: LissajousLabyrinthOrbit.azimuthRange.upperBound,
                                                elevation: LissajousLabyrinthOrbit.elevationRange.upperBound))
        let low: LissajousLabyrinthOrbit = LissajousLabyrinthOrbit(azimuthOffset: -2, elevation: -1).clamped()
        #expect(low == LissajousLabyrinthOrbit(azimuthOffset: LissajousLabyrinthOrbit.azimuthRange.lowerBound,
                                               elevation: LissajousLabyrinthOrbit.elevationRange.lowerBound))
        let broken: LissajousLabyrinthOrbit = LissajousLabyrinthOrbit(azimuthOffset: Double.nan,
                                                                      elevation: Double.infinity).clamped()
        #expect(broken == authored)
        let inside: LissajousLabyrinthOrbit = LissajousLabyrinthOrbit(azimuthOffset: 0.1, elevation: 0.5)
        #expect(inside.clamped() == inside)
        // The eye direction is a unit vector of the clamped orbit.
        let far: LissajousLabyrinthOrbit = LissajousLabyrinthOrbit(azimuthOffset: 5, elevation: -5)
        #expect(far.eyeDirection == far.clamped().eyeDirection)
        #expect(abs(far.eyeDirection.length - 1) < 1e-12)
        #expect(abs(asin(far.eyeDirection.y) - 10 * degree) < 1e-12)
    }

    @Test func authoredCameraEqualsTheAuthoredOrbit() throws {
        let s: LissajousLabyrinthSceneSnapshot = try Self.certifiedSnapshots()[1]
        let aspects: [Double] = Self.aspects + [0.0, Double.nan, 100.0]
        for aspect in aspects {
            let a: (eye: Vec3, target: Vec3, fovY: Double) = Geometry.camera(aspect: aspect, snapshot: s)
            let b: (eye: Vec3, target: Vec3, fovY: Double) = Geometry.camera(aspect: aspect, snapshot: s,
                                                                             orbit: .authored)
            #expect(a.eye == b.eye && a.target == b.target && a.fovY == b.fovY)
            #expect(Geometry.viewProjection(aspect: aspect, snapshot: s)
                    == Geometry.viewProjection(aspect: aspect, snapshot: s, orbit: .authored))
            let r1: (near: Double, far: Double) = Geometry.depthRange(aspect: aspect, snapshot: s)
            let r2: (near: Double, far: Double) = Geometry.depthRange(aspect: aspect, snapshot: s, orbit: .authored)
            #expect(r1.near == r2.near && r1.far == r2.far)
            // The authored eye lies on `eyeDirection` from the content centre.
            let offset: Vec3 = (a.eye - a.target).normalized
            #expect((offset - Geometry.eyeDirection).length < 1e-9)
        }
        // An orbit moves the eye; an out-of-range orbit gives the camera of its clamped orbit; the target stays.
        let far: LissajousLabyrinthOrbit = LissajousLabyrinthOrbit(azimuthOffset: 5, elevation: -5)
        let moved: (eye: Vec3, target: Vec3, fovY: Double) = Geometry.camera(aspect: 1.5, snapshot: s, orbit: far)
        let clamped: (eye: Vec3, target: Vec3, fovY: Double) = Geometry.camera(aspect: 1.5, snapshot: s,
                                                                               orbit: far.clamped())
        #expect(moved.eye == clamped.eye && moved.target == clamped.target)
        #expect(moved.eye != Geometry.camera(aspect: 1.5, snapshot: s).eye)
        #expect(moved.target == Geometry.camera(aspect: 1.5, snapshot: s).target)
        // The framing does not depend on the dials: two levels that differ only in their dials frame identically.
        let one: LissajousLabyrinthSceneSnapshot = Self.snapshot(try Self.extremeLevel(LissajousLabyrinthDials(
            frequencyA: 1, frequencyB: 2, phaseA: 0, phaseC: 0)), time: 0)
        let two: LissajousLabyrinthSceneSnapshot = Self.snapshot(try Self.extremeLevel(LissajousLabyrinthDials(
            frequencyA: 8, frequencyB: 9, phaseA: 15, phaseC: 7)), time: 0)
        #expect(Geometry.viewProjection(aspect: 1, snapshot: one) == Geometry.viewProjection(aspect: 1, snapshot: two))
    }

    @Test func stageAndRingsFitInsideNinetyPercentAtEveryOrbitAndAspect() throws {
        let aspects: [Double] = [0.4, 0.5, 0.75, 1, 1.5, 2, 2.5]
        let all: [(level: LissajousLabyrinthLevel, solved: LissajousLabyrinthDials)] = try Self.certifiedLevels()
        var levels: [LissajousLabyrinthLevel] = [all[0].level, all[49].level, all[99].level]
        levels.append(try Self.extremeLevel(LissajousLabyrinthDials(frequencyA: 1, frequencyB: 2, phaseA: 0,
                                                                    phaseC: 0)))
        // 26 directions (cube corners, edge midpoints and face centres) for sampling sphere surfaces.
        var directions: [Vec3] = []
        for x in -1...1 {
            for y in -1...1 {
                for z in -1...1 where x != 0 || y != 0 || z != 0 {
                    directions.append(Vec3(Double(x), Double(y), Double(z)).normalized)
                }
            }
        }
        for level in levels {
            let stage: (centre: Vec3, radius: Double) = Geometry.stageBounds(level: level)
            var points: [Vec3] = []
            for d in directions { points.append(stage.centre + d * stage.radius) }
            for p in LissajousLabyrinthLap.samples(level.start, level: level) { points.append(Geometry.world(p)) }
            let ringRadius: Double = LissajousLabyrinthHandles.ringRadius(level: level)
            let knob: Double = LissajousLabyrinthHandles.knobRadius(level: level)
            for dial in LissajousLabyrinthDial.allCases {
                let centre: Vec3 = LissajousLabyrinthHandles.ringCentre(dial, level: level)
                for k in 0..<32 {
                    let t: Double = 2 * Double.pi * Double(k) / 32
                    let rim: Vec3 = centre + (LissajousLabyrinthHandles.up * cos(t)
                                              + LissajousLabyrinthHandles.right * sin(t)) * ringRadius
                    for d in directions { points.append(rim + d * knob) }
                }
            }
            let s: LissajousLabyrinthSceneSnapshot = Self.snapshot(level, time: 0)
            for orbit in Self.orbits {
                for aspect in aspects {
                    let vp: Mat4 = Geometry.viewProjection(aspect: aspect, snapshot: s, orbit: orbit)
                    var worst: Double = 0
                    var behind: Bool = false
                    for p in points {
                        let clip: Vec4 = vp * Vec4(p, 1)
                        if clip.w <= 0 {
                            behind = true
                            continue
                        }
                        worst = max(worst, abs(clip.x / clip.w), abs(clip.y / clip.w))
                    }
                    #expect(!behind && worst <= 0.9, "level \(level.id) orbit \(orbit) aspect \(aspect) \(worst)")
                }
            }
        }
    }
}
