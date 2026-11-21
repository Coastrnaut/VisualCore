// HueCompassSceneGeometryTests — feature 333 (R02-G04-03) T-R02G0403-004 (FR-R02G0403-001, 002, 006; SC-R02G0403-001;
// clarifications Q1–Q3). Bearing directions are the kernel's angle; needle, wheel, fog and marks are finite, inside the
// 1.45 bounding sphere and follow the shader vertex contract (glass meshes unit normals, unlit meshes the colour in the
// normal slot) for extreme snapshots (fog all 0 and all 9, 23 clues with a selection and the revealed target, a failed
// selection, the needle at every bearing); every element projects inside the view with a 5 % margin at 7 aspects
// 0.4 … 2.5; bearings, band samples, glyphs and marks sit at the same places at every tier and only the needle facets
// and fog layers change triangle counts; fog colour follows density only; band colours follow the offset; no target
// geometry while the target is absent; the glyph region stays clear of the radius-0.85 sample ring. Plain loops and
// explicit types (CI type-check rule); seed 2_333.
import Foundation
import Testing
@testable import HueCompassCore
import VisualCoreMath
import VisualCoreScenes

@Suite struct HueCompassSceneGeometryTests {
    typealias Geometry = HueCompassSceneGeometry

    /// The aspects the framing is checked for.
    static let aspects: [Double] = [0.4, 0.5, 0.75, 1, 1.5, 2, 2.5]

    /// The test seed.
    static let seed: UInt64 = 2_333

    /// A snapshot of a play of a level with `offset`, `fog`, `start` and `target` after `actions` (applied in stage
    /// playing; turns, probes and selections), at time 0.
    static func snapshot(offset: Int = 0, fog: [Int], start: Int, target: Int, allowance: Int = 24,
                         actions: [HueCompassAction] = []) throws -> HueCompassSceneSnapshot {
        let level: HueCompassLevel = try HueCompassLevel(id: "geometry-test", seed: seed, band: 1, offset: offset,
                                                         fog: fog, target: target, start: start, bearingTolerance: 0,
                                                         bandTolerance: 0, allowance: allowance)
        var play: HueCompassPlay = HueCompassPlay(level: level)
        try play.handle(.begin)
        for action in actions {
            try play.apply(action, expecting: play.fingerprint)
        }
        return HueCompassSceneSnapshot(play: play, levelNumber: 1, time: 0)
    }

    /// Seeded densities 0 … 9.
    static func seededFog(_ salt: UInt64) -> [Int] {
        var random: HueCompassRandom = HueCompassRandom(seed: seed &+ salt)
        var fog: [Int] = []
        for _ in 0..<96 { fog.append(random.int(0...9)) }
        return fog
    }

    /// Extreme snapshots: fog all 0 (playing); fog all 9 at offset 23 (playing); seeded fog with 23 clues every 4
    /// bearings, then the winning selection (target revealed); a seeded failed selection (target revealed).
    static func extremeSnapshots() throws -> [HueCompassSceneSnapshot] {
        var result: [HueCompassSceneSnapshot] = []
        result.append(try snapshot(fog: Array(repeating: 0, count: 96), start: 0, target: 48))
        result.append(try snapshot(offset: 23, fog: Array(repeating: 9, count: 96), start: 95, target: 47))
        var actions: [HueCompassAction] = []
        for _ in 0..<23 {
            actions.append(.probe)
            actions.append(.turn(4))
        }
        let target: Int = 60
        let offset: Int = 11
        actions.append(.select(bearing: target, band: HueCompassWheel.band(of: target, offset: offset)))
        result.append(try snapshot(offset: offset, fog: seededFog(1), start: 3, target: target, actions: actions))
        result.append(try snapshot(offset: 5, fog: seededFog(2), start: 10, target: 70,
                                   actions: [.probe, .turn(-7), .probe, .select(bearing: 20, band: 3)]))
        return result
    }

    /// A playing snapshot with the needle at `bearing` and seeded fog.
    static func bearingSnapshot(_ bearing: Int) throws -> HueCompassSceneSnapshot {
        try snapshot(offset: bearing % 24, fog: seededFog(UInt64(bearing) + 10), start: bearing,
                     target: (bearing + 48) % 96)
    }

    /// The four coloured parts of `snapshot` at `tier`, glass first: needle, marks, wheel, fog.
    static func parts(_ snapshot: HueCompassSceneSnapshot,
                      tier: HueCompassTier) throws -> [(glass: Bool, part: HueCompassColouredMesh)] {
        [(true, try Geometry.needlePart(snapshot, tier: tier)), (true, try Geometry.markPart(snapshot)),
         (false, try Geometry.wheelPart(snapshot, tier: tier)), (false, try Geometry.fogPart(snapshot, tier: tier))]
    }

    /// `v` as SIMD.
    static func simd(_ v: Vec3) -> SIMD3<Double> { SIMD3(v.x, v.y, v.z) }

    /// The bearing (0 … 96, fractional) of the planar angle of `p`.
    static func bearingAngle(_ p: SIMD3<Double>) -> Double {
        var b: Double = atan2(p.y, p.x) * 96 / (2 * Double.pi)
        if b < 0 { b += 96 }
        return b
    }

    /// Whether `a` and `b` agree within 1e-12 per component.
    static func near(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ tolerance: Double = 1e-12) -> Bool {
        abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance && abs(a.z - b.z) <= tolerance
    }

    @Test func directionIsTheKernelAngle() {
        for b in 0..<96 {
            let d: SIMD3<Double> = Geometry.direction(b)
            let angle: Double = 2 * Double.pi * Double(b) / 96
            #expect(Self.near(d, SIMD3(cos(angle), sin(angle), 0)))
            #expect(abs(Geometry.length(d) - 1) < 1e-12)
            #expect(Self.near(Geometry.direction(b + 96), d, 1e-9))
        }
        #expect(Self.near(Geometry.direction(24), SIMD3(0, 1, 0)))
    }

    @Test func meshesAreFiniteBoundedAndFollowTheVertexContract() throws {
        var snapshots: [HueCompassSceneSnapshot] = try Self.extremeSnapshots()
        for b in stride(from: 0, to: 96, by: 5) { snapshots.append(try Self.bearingSnapshot(b)) }
        for snapshot in snapshots {
            for tier in HueCompassTier.all {
                for (glass, part) in try Self.parts(snapshot, tier: tier) {
                    let mesh: Mesh = part.mesh
                    #expect(part.colours.count == mesh.positions.count)
                    #expect(mesh.normals.count == mesh.positions.count && mesh.uvs.count == mesh.positions.count)
                    #expect(mesh.indices.count % 3 == 0)
                    for i in 0..<mesh.positions.count {
                        let p: SIMD3<Double> = Self.simd(mesh.positions[i])
                        let n: SIMD3<Double> = Self.simd(mesh.normals[i])
                        let c: Vec4 = part.colours[i]
                        #expect(p.x.isFinite && p.y.isFinite && p.z.isFinite)
                        #expect(Geometry.length(p) <= Geometry.boundingRadius - 0.04)
                        #expect(p.z >= -1e-12)
                        #expect(n.x.isFinite && n.y.isFinite && n.z.isFinite)
                        if glass {
                            #expect(abs(Geometry.length(n) - 1) < 1e-9)
                        } else {
                            #expect(Self.near(n, SIMD3(c.x, c.y, c.z)))
                        }
                        let channels: [Double] = [c.x, c.y, c.z, c.w, mesh.uvs[i].x, mesh.uvs[i].y]
                        for value in channels { #expect(value.isFinite && value >= 0 && value <= 1) }
                    }
                    for t in 0..<(mesh.indices.count / 3) {
                        let a: Int = Int(mesh.indices[3 * t]), b: Int = Int(mesh.indices[3 * t + 1])
                        let c: Int = Int(mesh.indices[3 * t + 2])
                        #expect(a < mesh.positions.count && b < mesh.positions.count && c < mesh.positions.count)
                        let pa: SIMD3<Double> = Self.simd(mesh.positions[a])
                        let area: Double = Geometry.length(Geometry.cross(Self.simd(mesh.positions[b]) - pa,
                                                                          Self.simd(mesh.positions[c]) - pa))
                        #expect(area > 1e-12)
                    }
                }
            }
        }
    }

    @Test func everyElementProjectsInsideTheViewAtSevenAspects() throws {
        let snapshots: [HueCompassSceneSnapshot] = try Self.extremeSnapshots()
        var points: [SIMD3<Double>] = []
        for snapshot in snapshots {
            for (_, part) in try Self.parts(snapshot, tier: HueCompassTier.all[0]) {
                for p in part.mesh.positions { points.append(Self.simd(p)) }
            }
            for b in 0..<96 {
                // A fog top with the shader's largest drift of +0.01.
                points.append(Geometry.fogTop(b, in: snapshot) + SIMD3(0, 0, 0.01))
            }
            for b in Geometry.probeBearings(snapshot) { points.append(Geometry.probeMarkCentre(b)) }
        }
        for b in 0..<96 {
            points.append(Geometry.needleTip(try Self.bearingSnapshot(b)))
            points.append(Geometry.selectionMarkCentre(b))
            points.append(Geometry.targetRingCentre(b))
        }
        for k in 0..<24 { points.append(Geometry.bandSamplePoint(k)) }
        // The bounding sphere itself, at 400 Fibonacci points.
        for i in 0..<400 {
            let z: Double = 1 - 2 * (Double(i) + 0.5) / 400
            let r: Double = (1 - z * z).squareRoot()
            let phi: Double = Double(i) * Double.pi * (3 - 5.0.squareRoot())
            points.append(SIMD3(r * cos(phi), r * sin(phi), z) * Geometry.boundingRadius)
        }
        for aspect in Self.aspects {
            let camera: HueCompassCamera = Geometry.camera(aspect: aspect)
            var outside: Int = 0
            for p in points {
                guard let v = Geometry.project(p, camera: camera) else {
                    outside += 1
                    continue
                }
                if v.x < 0.05 || v.x > 0.95 || v.y < 0.05 || v.y > 0.95 { outside += 1 }
            }
            #expect(outside == 0, "aspect \(aspect): \(outside) of \(points.count) points outside the 5 % margin")
        }
    }

    @Test func placesAreTheSameAtEveryTier() throws {
        let facets: [Int] = [12, 8, 4]
        let layers: [Int] = [3, 2, 1]
        for snapshot in try Self.extremeSnapshots() {
            let wheel: HueCompassColouredMesh = try Geometry.wheelPart(snapshot, tier: HueCompassTier.all[0])
            #expect(wheel.mesh.triangleCount == 192 + 384 + 567)
            var footprints: [[String]] = []
            for (index, tier) in HueCompassTier.all.enumerated() {
                #expect(try Geometry.wheelPart(snapshot, tier: tier) == wheel)
                let needle: Mesh = try Geometry.needleMesh(snapshot, tier: tier)
                #expect(needle.triangleCount == 4 * facets[index])
                // The needle's farthest vertex is the tip, at every tier.
                var far: SIMD3<Double> = .zero
                for p in needle.positions where Geometry.length(Self.simd(p)) > Geometry.length(far) {
                    far = Self.simd(p)
                }
                #expect(Self.near(far, Geometry.needleTip(snapshot)))
                let fog: Mesh = try Geometry.fogMesh(snapshot, tier: tier)
                #expect(fog.triangleCount == 96 * 12 * layers[index])
                // The footprint (sorted planar coordinates) and the top of every prism do not depend on the tier.
                var planar: Set<String> = []
                var top: [Double] = Array(repeating: 0, count: 96)
                for p in fog.positions {
                    planar.insert("\(Int((p.x * 1e9).rounded())),\(Int((p.y * 1e9).rounded()))")
                    let b: Int = Int(Self.bearingAngle(Self.simd(p)).rounded()) % 96
                    top[b] = max(top[b], p.z)
                }
                footprints.append(planar.sorted())
                for b in 0..<96 {
                    #expect(abs(top[b] - Geometry.fogTop(b, in: snapshot).z) < 1e-12)
                }
            }
            #expect(footprints[0] == footprints[1] && footprints[1] == footprints[2])
            let marks: Mesh = try Geometry.markMesh(snapshot)
            let expected: Int = 8 * Geometry.probeBearings(snapshot).count + (snapshot.selection == nil ? 0 : 8)
                + (snapshot.target == nil ? 0 : 192)
            #expect(marks.triangleCount == expected)
        }
        for k in 0..<24 {
            let p: SIMD3<Double> = Geometry.bandSamplePoint(k)
            #expect(abs(Geometry.length(p) - 0.85) < 1e-12 && p.z == 0)
            #expect(abs(Self.bearingAngle(p) - (Double(4 * k) + 1.5)) < 1e-9)
        }
    }

    @Test func fogColourFollowsDensityOnly() throws {
        for density in 0...9 {
            let fog: [Int] = Array(repeating: density, count: 96)
            let a: HueCompassSceneSnapshot = try Self.snapshot(offset: 0, fog: fog, start: 0, target: 48)
            let b: HueCompassSceneSnapshot = try Self.snapshot(offset: 17, fog: fog, start: 30, target: 80,
                                                               actions: [.probe, .turn(9), .probe])
            for tier in HueCompassTier.all {
                let part: HueCompassColouredMesh = try Geometry.fogPart(a, tier: tier)
                #expect(try Geometry.fogPart(b, tier: tier) == part)
                let g: Double = Double(density) / 9
                for i in 0..<part.colours.count {
                    let c: Vec4 = part.colours[i]
                    #expect(c.x == g && c.y == g && c.z == g && c.w == 1)
                    #expect(part.mesh.uvs[i].x == g)
                    #expect(part.mesh.positions[i].z <= Geometry.fogHeight(density) + 1e-12)
                }
            }
            #expect(Geometry.fogColour(density) == SIMD3(repeating: Double(density) / 9))
        }
        // Mixed densities: each prism's colour is its own density's.
        let snapshot: HueCompassSceneSnapshot = try Self.snapshot(fog: Self.seededFog(3), start: 0, target: 48)
        let part: HueCompassColouredMesh = try Geometry.fogPart(snapshot, tier: HueCompassTier.all[1])
        for i in 0..<part.colours.count {
            let b: Int = Int((part.mesh.uvs[i].y * 96).rounded())
            #expect(abs(Self.bearingAngle(Self.simd(part.mesh.positions[i])) - Double(b)) < 0.5
                    || abs(Self.bearingAngle(Self.simd(part.mesh.positions[i])) - Double(b) - 96) < 0.5)
            #expect(part.colours[i].x == Double(snapshot.fog[b]) / 9)
        }
    }

    @Test func bandColoursFollowTheOffset() throws {
        let fog: [Int] = Self.seededFog(4)
        for offset in 0..<24 {
            let snapshot: HueCompassSceneSnapshot = try Self.snapshot(offset: offset, fog: fog, start: 0, target: 48)
            for k in 0..<24 {
                #expect(Geometry.bandOfSegment(k, in: snapshot) == (k + offset) % 24)
                #expect(Geometry.bandSegmentColour(k, in: snapshot) == HueCompassPalette.band((k + offset) % 24))
            }
            let wheel: HueCompassColouredMesh = try Geometry.wheelPart(snapshot, tier: HueCompassTier.all[2])
            var bandVertices: Int = 0
            for i in 0..<wheel.mesh.positions.count {
                let p: SIMD3<Double> = Self.simd(wheel.mesh.positions[i])
                let r: Double = Geometry.length(p)
                guard p.z == 0, r >= 0.82 - 1e-9, r <= 0.92 + 1e-9 else { continue }
                bandVertices += 1
                let segment: Int = Int((Self.bearingAngle(p) + 0.5) / 4) % 24
                let expected: SIMD3<Double> = HueCompassPalette.band((segment + offset) % 24)
                let c: Vec4 = wheel.colours[i]
                #expect(Self.near(SIMD3(c.x, c.y, c.z), expected))
            }
            #expect(bandVertices == 24 * 9 * 2)
        }
    }

    @Test func noTargetGeometryWhileTheTargetIsAbsent() throws {
        let fog: [Int] = Self.seededFog(5)
        let playing: HueCompassSceneSnapshot = try Self.snapshot(offset: 2, fog: fog, start: 10, target: 70,
                                                                 actions: [.probe, .turn(5), .probe])
        #expect(playing.target == nil)
        let marks: HueCompassColouredMesh = try Geometry.markPart(playing)
        #expect(marks.mesh.triangleCount == 16)
        let sapphire: Vec4 = Geometry.colour(HueCompassPalette.sapphire)
        for i in 0..<marks.colours.count {
            #expect(marks.colours[i] != sapphire)
            #expect(marks.mesh.uvs[i].y != 1)
        }
        let won: HueCompassSceneSnapshot = try Self.snapshot(offset: 2, fog: fog, start: 10, target: 70,
                                                             actions: [.probe, .select(bearing: 70,
                                                                                       band: (70 / 4 + 2) % 24)])
        #expect(won.target == 70)
        let revealed: HueCompassColouredMesh = try Geometry.markPart(won)
        #expect(revealed.mesh.triangleCount == 8 + 8 + 192)
        var ringVertices: Int = 0
        for i in 0..<revealed.colours.count where revealed.colours[i] == sapphire {
            ringVertices += 1
            let p: SIMD3<Double> = Self.simd(revealed.mesh.positions[i])
            #expect(Geometry.length(p - Geometry.targetRingCentre(70)) <= 0.07 + 0.012 + 1e-9)
        }
        #expect(ringVertices == 16 * 6)
    }

    @Test func glyphsStayClearOfTheSampleRing() throws {
        for offset in [0, 7, 23] {
            let snapshot: HueCompassSceneSnapshot = try Self.snapshot(offset: offset, fog: Self.seededFog(6),
                                                                      start: 0, target: 48)
            let wheel: Mesh = try Geometry.wheelMesh(snapshot, tier: HueCompassTier.all[0])
            var glyphVertices: Int = 0
            for p in wheel.positions where p.z == Geometry.glyphLift {
                glyphVertices += 1
                let r: Double = Geometry.length(Self.simd(p))
                #expect(r >= 0.895 && r <= 0.92)
            }
            #expect(glyphVertices > 0)
            for k in 0..<24 {
                let band: Int = Geometry.bandOfSegment(k, in: snapshot)
                let centres: [SIMD3<Double>] = Geometry.glyphCentres(k, in: snapshot)
                #expect(centres.count == HueCompassGlyph.of(band: band).marks)
                let sample: SIMD3<Double> = Geometry.bandSamplePoint(k)
                for c in centres {
                    // Every glyph mark spans at most its half-size diagonal about its centre.
                    #expect(Geometry.length(SIMD3(c.x, c.y, 0)) - Geometry.glyphHalfSize * 2.0.squareRoot()
                            > Geometry.bandSampleRadius + 0.04)
                    #expect(Geometry.length(c - sample) > 0.04)
                    // Inside its own segment: within 1.85 bearings of the middle (wrapped about 0).
                    var offset: Double = Self.bearingAngle(c) - (Double(4 * k) + 1.5)
                    if offset < -48 { offset += 96 }
                    if offset >= 48 { offset -= 96 }
                    #expect(abs(offset) < 2 - 0.15)
                }
                let gray: Double = Geometry.glyphGray(band)
                let colour: SIMD3<Double> = HueCompassPalette.band(band)
                let luminance: Double = 0.2126 * colour.x + 0.7152 * colour.y + 0.0722 * colour.z
                #expect(abs(luminance - gray) >= 0.3)
            }
        }
    }

    @Test func cameraAndProjectionEdgeCases() {
        let camera: HueCompassCamera = Geometry.camera(aspect: 1.5)
        #expect(camera.aspect == 1.5)
        #expect(Self.near(Geometry.unit(camera.eye), Geometry.eyeDirection))
        #expect(Geometry.camera(aspect: .nan).aspect == 1)
        #expect(Geometry.camera(aspect: -2).aspect == 1)
        #expect(Geometry.camera(aspect: 100).aspect == 10)
        // The centre projects to the middle of the view.
        let centre: SIMD2<Double>? = Geometry.project(.zero, camera: camera)
        #expect(centre != nil)
        if let centre { #expect(abs(centre.x - 0.5) < 1e-9 && abs(centre.y - 0.5) < 1e-9) }
        // +y (bearing 24) appears above the centre, +x (bearing 0) to the right.
        if let up = Geometry.project(SIMD3(0, 1, 0), camera: camera),
           let right = Geometry.project(SIMD3(1, 0, 0), camera: camera) {
            #expect(up.y < 0.5 && right.x > 0.5)
        } else {
            Issue.record("compass points did not project")
        }
        let behind: SIMD3<Double> = camera.eye * 2
        #expect(Geometry.project(behind, camera: camera) == nil)
        #expect(Geometry.project(SIMD3(.nan, 0, 0), camera: camera) == nil)
        #expect(Geometry.pixel(.zero, camera: camera, width: 0, height: 768) == nil)
        if let pixel = Geometry.pixel(.zero, camera: camera, width: 1_152, height: 768) {
            #expect(abs(pixel.x - 576) < 1e-6 && abs(pixel.y - 384) < 1e-6)
        } else {
            Issue.record("centre pixel missing")
        }
    }
}
