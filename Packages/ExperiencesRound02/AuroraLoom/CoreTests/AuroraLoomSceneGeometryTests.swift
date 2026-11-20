// AuroraLoomSceneGeometryTests — feature 303 (R02-G01-03) T-R02G0103-003 (FR-R02G0103-001, 006; SC-R02G0103-003;
// clarifications Q1–Q3). Geometry is finite and inside the scene bounds for extreme settings (all steps 0, all 15,
// mixed), every Ω and ribbon ω 1 … 256 and large times; each tier gives 3 · layers meshes with finite vertices; the camera
// frames the content box with at least 5 % margin for aspects 0.4 … 2.5 and puts the loom centre at the view centre;
// `project` matches the GL clip → NDC → viewport chain; centre-line and marker heights follow the phase formulas; the
// gate rings enclose every sheet; the same snapshot gives identical geometry.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
@testable import AuroraLoomCore
import VisualCoreMath
import VisualCoreScenes

@Suite struct AuroraLoomSceneGeometryTests {
    typealias Geometry = AuroraLoomSceneGeometry

    /// The aspects the framing is checked for.
    static let aspects: [Double] = [0.4, 0.5, 0.75, 1, 1.5, 2, 2.5]
    /// Large and fractional frame times.
    static let times: [Double] = [0, 0.5, 1, 119.75, 4_095.5, 1e6 + 0.25, 1e12]
    /// Every Ω (powers of two 1 … 256).
    static let omegas: [Int] = [1, 2, 4, 8, 16, 32, 64, 128, 256]

    /// A level whose start steps are the given ribbon steps (ribbon ω = `ribbonOmega`, harmony Ω = `omega`); the gate
    /// targets sit half a turn from ribbon 0 so the start never wins.
    static func level(wave: [Int], phase: [Int], ribbonOmega: Int, omega: Int) throws -> AuroraLoomLevel {
        let positions: [Int] = [2, 6, 9, 14]
        var gates: [AuroraLoomGate] = []
        for p in positions {
            let target: Int = ((wave[0] * p * 16 + phase[0] * 256 + 2_048) % 4_096 + 4_096) % 4_096
            gates.append(try AuroraLoomGate(position: p, target: target))
        }
        var ribbons: [AuroraLoomRibbon] = []
        for r in 0..<3 {
            ribbons.append(try AuroraLoomRibbon(wave: wave[r], phase: phase[r], omega: ribbonOmega))
        }
        return try AuroraLoomLevel(id: "geometry-test", seed: 7, band: 1, ribbons: ribbons, gates: gates,
                                   omega: omega, tolerance: 1, allowance: 8)
    }

    /// The extreme settings: all steps 0, all 15 and a mixed setting.
    static let settings: [(wave: [Int], phase: [Int])] = [
        (wave: [0, 0, 0], phase: [0, 0, 0]),
        (wave: [15, 15, 15], phase: [15, 15, 15]),
        (wave: [0, 15, 7], phase: [15, 0, 8]),
    ]

    /// A snapshot of a fresh play of `level` at `time`.
    static func snapshot(_ level: AuroraLoomLevel, time: Double) -> AuroraLoomSceneSnapshot {
        AuroraLoomSceneSnapshot(play: AuroraLoomPlay(level: level), time: time)
    }

    /// Whether `p` is finite and inside the content box (and so within `sceneBounds`).
    static func inside(_ p: Vec3) -> Bool {
        let h: Vec3 = Geometry.contentHalfExtents
        let tolerance: Double = 1e-9
        return p.isFinite && abs(p.x) <= h.x + tolerance && abs(p.y) <= h.y + tolerance && abs(p.z) <= h.z + tolerance
            && max(abs(p.x), abs(p.y), abs(p.z)) <= Geometry.sceneBounds + tolerance
    }

    @Test func layoutConstantsMatchTheClarification() {
        #expect(Geometry.ringRadius >= Geometry.amplitude * 1.15)
        #expect(Geometry.lane(ribbon: 0) == -Geometry.laneSpacing)
        #expect(Geometry.lane(ribbon: 1) == 0)
        #expect(Geometry.lane(ribbon: 2) == Geometry.laneSpacing)
        #expect(Geometry.x(sixteenths: 0) == -Geometry.length / 2)
        #expect(Geometry.x(sixteenths: 16) == Geometry.length / 2)
        // The rings enclose every sheet: the farthest sheet corner in the y–z plane lies inside the ring.
        let maxY: Double = Geometry.amplitude + Geometry.baseWidth / 2
        let maxZ: Double = Geometry.laneSpacing + Geometry.layerOffsets(layers: 5)[4]
        #expect((maxY * maxY + maxZ * maxZ).squareRoot() < Geometry.ringRadius)
        let offsets: [Double] = Geometry.layerOffsets(layers: 5)
        let widths: [Double] = Geometry.layerWidths(layers: 5)
        for k in 0..<5 {
            #expect(abs(offsets[k] + offsets[4 - k]) < 1e-12)
            #expect(widths[k] > 0 && widths[k] <= widths[2])
        }
    }

    @Test func extremeSettingsStayFiniteAndBounded() throws {
        for setting in Self.settings {
            for omega in Self.omegas {
                let level: AuroraLoomLevel = try Self.level(wave: setting.wave, phase: setting.phase,
                                                            ribbonOmega: omega, omega: omega)
                for time in Self.times {
                    let snap: AuroraLoomSceneSnapshot = Self.snapshot(level, time: time)
                    for r in 0..<3 {
                        let line: [Vec3] = Geometry.centreLine(ribbon: r, snapshot: snap, segments: 32)
                        #expect(line.count == 33)
                        for p in line { #expect(Self.inside(p)) }
                    }
                    for g in 0..<4 {
                        #expect(Self.inside(Geometry.marker(gate: g, snapshot: snap)))
                        for p in Geometry.gateRing(gate: g, snapshot: snap, points: 16) { #expect(Self.inside(p)) }
                    }
                    let meshes: [Mesh] = try Geometry.ribbonMeshes(snapshot: snap, tier: AuroraLoomTier.of(2))
                    for mesh in meshes {
                        for p in mesh.positions { #expect(Self.inside(p)) }
                    }
                }
            }
        }
    }

    @Test func everyTierGivesLayersTimesThreeFiniteMeshes() throws {
        for setting in Self.settings {
            let level: AuroraLoomLevel = try Self.level(wave: setting.wave, phase: setting.phase,
                                                        ribbonOmega: 256, omega: 256)
            for time in [0.0, 1e9 + 0.5] {
                let snap: AuroraLoomSceneSnapshot = Self.snapshot(level, time: time)
                for tier in AuroraLoomTier.all {
                    let meshes: [Mesh] = try Geometry.ribbonMeshes(snapshot: snap, tier: tier)
                    #expect(meshes.count == tier.layers * 3)
                    var vertices: Int = 0
                    for mesh in meshes {
                        #expect(mesh.positions.count == 2 * (2 * tier.segments + 1))
                        #expect(mesh.indices.count == 6 * 2 * tier.segments)
                        vertices += mesh.positions.count
                        for p in mesh.positions { #expect(Self.inside(p)) }
                        for n in mesh.normals { #expect(n.isFinite && abs(n.length - 1) < 1e-6) }
                        for uv in mesh.uvs { #expect(uv.isFinite) }
                    }
                    #expect(vertices <= MeshBudget.default.maxVertices)
                }
            }
        }
    }

    @Test func certifiedLevelsBuildEveryTier() throws {
        for i in [0, 12, 24] {
            let generated: AuroraLoomGenerated = try AuroraLoomGenerator.generate(AuroraLoomManifest.entries[i])
            let snap: AuroraLoomSceneSnapshot = Self.snapshot(generated.level, time: 37.25)
            for tier in AuroraLoomTier.all {
                let meshes: [Mesh] = try Geometry.ribbonMeshes(snapshot: snap, tier: tier)
                #expect(meshes.count == tier.layers * 3)
                for mesh in meshes {
                    for p in mesh.positions { #expect(Self.inside(p)) }
                }
            }
        }
    }

    @Test func framingKeepsFivePercentMarginForEveryAspect() {
        let corners: [Vec3] = Geometry.contentCorners
        for aspect in Self.aspects {
            let height: Int = 1_000
            let width: Int = Int((aspect * Double(height)).rounded())
            let w: Double = Double(width)
            let h: Double = Double(height)
            for corner in corners {
                let pixel: (x: Double, y: Double)? = Geometry.project(corner, aspect: Double(width) / h,
                                                                       width: width, height: height)
                #expect(pixel != nil)
                guard let p = pixel else { continue }
                #expect(p.x >= 0.05 * w && p.x <= 0.95 * w, "aspect \(aspect) corner \(corner) x \(p.x)")
                #expect(p.y >= 0.05 * h && p.y <= 0.95 * h, "aspect \(aspect) corner \(corner) y \(p.y)")
            }
            // The loom centre projects to the view centre.
            let centre: (x: Double, y: Double)? = Geometry.project(.zero, aspect: Double(width) / h,
                                                                    width: width, height: height)
            #expect(centre != nil)
            if let c = centre {
                #expect(abs(c.x - w / 2) < 1e-6 * w && abs(c.y - h / 2) < 1e-6 * h)
            }
        }
    }

    @Test func framedSceneLiesInsideTheMarginForEveryAspect() throws {
        let level: AuroraLoomLevel = try Self.level(wave: [15, 0, 7], phase: [3, 15, 0], ribbonOmega: 128, omega: 128)
        let snap: AuroraLoomSceneSnapshot = Self.snapshot(level, time: 12.5)
        let meshes: [Mesh] = try Geometry.ribbonMeshes(snapshot: snap, tier: AuroraLoomTier.of(0))
        var points: [Vec3] = []
        for mesh in meshes { points += mesh.positions }
        for g in 0..<4 { points += Geometry.gateRing(gate: g, snapshot: snap, points: 32) }
        for aspect in Self.aspects {
            let width: Int = Int((aspect * 400).rounded())
            let height: Int = 400
            let w: Double = Double(width)
            let h: Double = Double(height)
            let m: (view: Mat4, projection: Mat4) = Geometry.camera(aspect: w / h)
            let viewProjection: Mat4 = m.projection * m.view
            for p in points {
                guard let q = Geometry.project(p, viewProjection: viewProjection, width: width, height: height) else {
                    Issue.record("point behind the camera at aspect \(aspect)")
                    continue
                }
                #expect(q.x >= 0.05 * w && q.x <= 0.95 * w && q.y >= 0.05 * h && q.y <= 0.95 * h)
            }
        }
    }

    @Test func projectionFollowsTheGLChain() {
        let points: [Vec3] = [Vec3(1, 0.5, -0.3), Vec3(-4, 1, 0.5), Vec3(3.5, -1.2, 1.1)]
        for aspect in Self.aspects {
            let height: Int = 64
            let width: Int = Int((aspect * 64).rounded())
            let a: Double = Double(width) / Double(height)
            let m: (view: Mat4, projection: Mat4) = Geometry.camera(aspect: a)
            for p in points {
                let clip: Vec4 = m.projection * (m.view * Vec4(p, 1))
                #expect(clip.w > 0)
                let ndcX: Double = clip.x / clip.w
                let ndcY: Double = clip.y / clip.w
                let expectedX: Double = (ndcX + 1) / 2 * Double(width)
                let expectedY: Double = (1 - ndcY) / 2 * Double(height)
                let q: (x: Double, y: Double)? = Geometry.project(p, aspect: a, width: width, height: height)
                #expect(q != nil)
                if let q {
                    #expect(abs(q.x - expectedX) < 1e-9 && abs(q.y - expectedY) < 1e-9)
                }
            }
            // A point behind the eye has no pixel; a zero viewport has none either.
            let behind: Vec3 = Geometry.eyeDirection * (Geometry.cameraDistance(aspect: a) + 5)
            #expect(Geometry.project(behind, aspect: a, width: width, height: height) == nil)
            #expect(Geometry.project(.zero, aspect: a, width: 0, height: height) == nil)
        }
    }

    @Test func centreLineHeightFollowsThePhaseFormula() throws {
        let level: AuroraLoomLevel = try Self.level(wave: [3, 11, 15], phase: [9, 0, 4], ribbonOmega: 64, omega: 32)
        for time in [0.0, 0.25, 17.5, 1_000.75] {
            let snap: AuroraLoomSceneSnapshot = Self.snapshot(level, time: time)
            for r in 0..<3 {
                let line: [Vec3] = Geometry.centreLine(ribbon: r, snapshot: snap, segments: 64)
                for i in 0...64 {
                    let s: Double = 16 * Double(i) / 64
                    let theta: Double = Double(snap.steps.wave[r]) * s * 16 + Double(snap.steps.phase[r]) * 256
                        + Double(level.ribbons[r].omega) * time
                    let y: Double = Geometry.amplitude * sin(2 * Double.pi * theta / 4_096)
                    #expect(abs(line[i].y - y) < 1e-9)
                    #expect(abs(line[i].x - (-Geometry.length / 2 + Geometry.length * s / 16)) < 1e-12)
                    #expect(line[i].z == Geometry.lane(ribbon: r))
                }
            }
            // At a whole tick the drawn height at a gate is the judged phase's height.
            if time == time.rounded(.down) {
                for g in 0..<4 {
                    let position: Int = level.gates[g].position
                    let line: [Vec3] = Geometry.centreLine(ribbon: 1, snapshot: snap, segments: 16)
                    let phase: Int = AuroraLoomHarmony.phase(ribbon: 1, gate: g, tick: Int(time), steps: snap.steps,
                                                             level: level)
                    #expect(abs(line[position].y - Geometry.amplitude * sin(2 * Double.pi * Double(phase) / 4_096))
                            < 1e-9)
                }
            }
        }
    }

    @Test func markerFollowsTheTargetFormula() throws {
        for omega in Self.omegas {
            let level: AuroraLoomLevel = try Self.level(wave: [5, 5, 5], phase: [2, 2, 2], ribbonOmega: omega,
                                                        omega: omega)
            for time in [0.0, 3.5, 250.25] {
                let snap: AuroraLoomSceneSnapshot = Self.snapshot(level, time: time)
                for g in 0..<4 {
                    let m: Vec3 = Geometry.marker(gate: g, snapshot: snap)
                    let theta: Double = Double(level.gates[g].target) + Double(omega) * time
                    #expect(abs(m.y - Geometry.amplitude * sin(2 * Double.pi * theta / 4_096)) < 1e-9)
                    #expect(m.z == 0)
                    #expect(m.x == Geometry.x(sixteenths: Double(level.gates[g].position)))
                    let ring: [Vec3] = Geometry.gateRing(gate: g, snapshot: snap, points: 48)
                    #expect(ring.count == 48)
                    for p in ring {
                        #expect(p.x == m.x)
                        #expect(abs((p.y * p.y + p.z * p.z).squareRoot() - Geometry.ringRadius) < 1e-12)
                    }
                    #expect((m.y * m.y + m.z * m.z).squareRoot() < Geometry.ringRadius)
                }
            }
        }
    }

    @Test func referenceSamplesMatchProjectedCentreLines() throws {
        let generated: AuroraLoomGenerated = try AuroraLoomGenerator.generate(AuroraLoomManifest.entries[3])
        let snap: AuroraLoomSceneSnapshot = Self.snapshot(generated.level, time: 9.5)
        let aspect: Double = 96.0 / 64.0
        let samples: [[(x: Double, y: Double)]] = Geometry.referenceSamples(snapshot: snap, aspect: aspect, width: 96,
                                                                           height: 64, segments: 32)
        #expect(samples.count == 3)
        for r in 0..<3 {
            #expect(samples[r].count == 33)
            let line: [Vec3] = Geometry.centreLine(ribbon: r, snapshot: snap, segments: 32)
            for i in 0..<samples[r].count {
                let q: (x: Double, y: Double)? = Geometry.project(line[i], aspect: aspect, width: 96, height: 64)
                #expect(q != nil)
                if let q { #expect(q.x == samples[r][i].x && q.y == samples[r][i].y) }
                #expect(samples[r][i].x > 0 && samples[r][i].x < 96 && samples[r][i].y > 0 && samples[r][i].y < 64)
            }
        }
        for g in 0..<4 {
            let pixel: (x: Double, y: Double)? = Geometry.markerPixel(gate: g, snapshot: snap, aspect: aspect,
                                                                       width: 96, height: 64)
            let direct: (x: Double, y: Double)? = Geometry.project(Geometry.marker(gate: g, snapshot: snap),
                                                                    aspect: aspect, width: 96, height: 64)
            #expect(pixel != nil && direct != nil)
            if let pixel, let direct { #expect(pixel.x == direct.x && pixel.y == direct.y) }
        }
    }

    @Test func sameSnapshotGivesIdenticalGeometry() throws {
        let generated: AuroraLoomGenerated = try AuroraLoomGenerator.generate(AuroraLoomManifest.entries[7])
        let a: AuroraLoomSceneSnapshot = Self.snapshot(generated.level, time: 401.125)
        let b: AuroraLoomSceneSnapshot = Self.snapshot(generated.level, time: 401.125)
        for tier in AuroraLoomTier.all {
            let first: [Mesh] = try Geometry.ribbonMeshes(snapshot: a, tier: tier)
            let second: [Mesh] = try Geometry.ribbonMeshes(snapshot: b, tier: tier)
            #expect(first == second)
        }
        for g in 0..<4 {
            #expect(Geometry.marker(gate: g, snapshot: a) == Geometry.marker(gate: g, snapshot: b))
            #expect(Geometry.gateRing(gate: g, snapshot: a) == Geometry.gateRing(gate: g, snapshot: b))
        }
        let first: (view: Mat4, projection: Mat4) = Geometry.camera(aspect: 1.5)
        let second: (view: Mat4, projection: Mat4) = Geometry.camera(aspect: 1.5)
        #expect(first.view == second.view && first.projection == second.projection)
    }

    @Test func unusableAspectsFallBackToFiniteCameras() {
        for aspect in [0.0, -1.0, Double.nan, Double.infinity, 100.0] {
            let m: (view: Mat4, projection: Mat4) = Geometry.camera(aspect: aspect)
            for v in m.view.floats + m.projection.floats { #expect(v.isFinite) }
        }
    }
}
