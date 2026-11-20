// PlantShapesTests — feature 219 (R02-F19) T-R02F19-004 (FR-R02F19-003; SC-R02F19-002; clarification Q3).
// 200 seeded petals, caps and stems validate (caps and stems closed), stay within the default budget, have the
// expected vertex counts, unit normals and their stated length, radius or height within 1e-9; every refusal by name.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

/// A small deterministic generator (SplitMix64) for seeded shape parameters.
fileprivate struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z: UInt64 = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    /// A double in lower ..< upper.
    mutating func double(_ lower: Double, _ upper: Double) -> Double {
        let unit: Double = Double(next() >> 11) / Double(UInt64(1) << 53)
        return lower + (upper - lower) * unit
    }
    /// An integer in lower ... upper.
    mutating func int(_ lower: Int, _ upper: Int) -> Int {
        lower + Int(next() % UInt64(upper - lower + 1))
    }
    /// A bend in −π … π, exactly 0 one time in six.
    mutating func bend() -> Double {
        next() % 6 == 0 ? 0 : double(-Double.pi, Double.pi)
    }
}

@Suite struct PlantShapesTests {
    /// The analytic end of an arc of `length` turning by `bend` from the origin heading +y towards +z.
    static func arcPoint(length: Double, bend: Double, t: Double) -> Vec3 {
        let a: Double = bend * t
        if a == 0 { return Vec3(0, length * t, 0) }
        let rho: Double = length / bend
        return Vec3(0, rho * sin(a), rho * (1 - cos(a)))
    }

    static func checkCommon(_ mesh: Mesh, closed: Bool) {
        let report: MeshReport = mesh.validate(requireClosed: closed)
        #expect(report.isValid, "\(report)")
        if closed { #expect(report.summary.isClosed) }
        #expect(mesh.positions.count <= MeshBudget.default.maxVertices)
        #expect(mesh.indices.count <= MeshBudget.default.maxIndices)
        for normal in mesh.normals { #expect(abs(normal.length - 1) <= 1e-12) }
    }

    @Test func seededPetals() throws {
        var random: SplitMix = SplitMix(seed: 2_019)
        for _ in 0..<67 {
            let length: Double = random.double(0.05, 100)
            let width: Double = random.double(0.05, 1) * length
            let curl: Double = random.bend()
            let segments: Int = random.int(2, 32)
            let petal: PetalShape = try PetalShape(length: length, width: width, curl: curl, segments: segments)
            let mesh: Mesh = try petal.mesh()
            Self.checkCommon(mesh, closed: true)
            #expect(mesh.positions.count == 6 * segments - 2)
            #expect(mesh.indices.count == 24 * (segments - 1))
            let end: Vec3 = Self.arcPoint(length: length, bend: curl, t: 1)
            var tips: Int = 0
            for k in 0..<mesh.positions.count {
                let p: Vec3 = mesh.positions[k], uv: Vec2 = mesh.uvs[k]
                if uv.y == 1 { tips += 1; #expect((p - end).length <= 1e-9) }
                if uv.y == 0 { #expect(p.length <= 1e-12) }
                if uv.x == 1 {  // a +x rim point: on the analytic arc, offset by the half-width
                    let spine: Vec3 = Self.arcPoint(length: length, bend: curl, t: uv.y)
                    #expect((Vec3(0, p.y, p.z) - spine).length <= 1e-9)
                    #expect(abs(p.x - width * sin(Double.pi * uv.y)) <= 1e-9)
                }
            }
            #expect(tips == 2)
            #expect(try petal.mesh() == mesh)
        }
    }

    @Test func seededCaps() throws {
        var random: SplitMix = SplitMix(seed: 2_019 &+ 1)
        for index in 0..<67 {
            let radius: Double = random.double(0.05, 100)
            let height: Double = random.double(0.05, 100)
            let rim: Double = index % 5 == 0 ? 0 : random.double(0, 0.9) * height
            let sides: Int = random.int(8, 32)
            let rings: Int = random.int(2, 16)
            let cap: CapShape = try CapShape(radius: radius, height: height, rim: rim, sides: sides, rings: rings)
            let mesh: Mesh = try cap.mesh()
            Self.checkCommon(mesh, closed: true)
            let band: Int = rim > 0 ? 2 * (sides + 1) : 0
            #expect(mesh.positions.count == (rings + 1) * (sides + 1) + band + sides + 1)
            let bandTriangles: Int = rim > 0 ? 2 * sides : 0
            #expect(mesh.indices.count == 3 * (sides * (2 * rings - 1) + bandTriangles + sides))
            var widest: Double = 0, top: Double = -Double.infinity, bottom: Double = Double.infinity
            for p in mesh.positions {
                widest = max(widest, (p.x * p.x + p.z * p.z).squareRoot())
                top = max(top, p.y); bottom = min(bottom, p.y)
            }
            #expect(abs(widest - radius) <= 1e-9)
            #expect(abs(top - height) <= 1e-9)
            #expect(abs(bottom + rim) <= 1e-9)
            #expect(try cap.mesh() == mesh)
        }
    }

    @Test func seededStems() throws {
        var random: SplitMix = SplitMix(seed: 2_019 &+ 2)
        for _ in 0..<66 {
            let length: Double = random.double(0.05, 100)
            let baseRadius: Double = random.double(0.01, 0.2) * length
            let tipRadius: Double = random.double(0.2, 1) * baseRadius
            let bend: Double = random.bend()
            let sides: Int = random.int(3, 24)
            let segments: Int = random.int(1, 24)
            let stem: StemShape = try StemShape(length: length, baseRadius: baseRadius, tipRadius: tipRadius,
                                                bend: bend, sides: sides, segments: segments)
            let mesh: Mesh = try stem.mesh()
            Self.checkCommon(mesh, closed: true)
            #expect(mesh.positions.count == (segments + 1) * (sides + 1) + 2 * (sides + 1))
            #expect(mesh.indices.count == 3 * (2 * sides * segments + 2 * sides))
            let end: Vec3 = Self.arcPoint(length: length, bend: bend, t: 1)
            let tipTangent: Vec3 = Vec3(0, cos(bend), sin(bend))
            var baseRing: Int = 0, tipRing: Int = 0, tipCentre: Int = 0
            for k in 0..<mesh.positions.count {
                let p: Vec3 = mesh.positions[k], n: Vec3 = mesh.normals[k]
                let centre: Bool = mesh.uvs[k] == Vec2(0.5, 0.5)
                if (n - Vec3(0, -1, 0)).length <= 1e-12 {
                    if centre { #expect(p.length <= 1e-12) }
                    else { baseRing += 1; #expect(abs(p.length - baseRadius) <= 1e-9) }
                } else if (n - tipTangent).length <= 1e-12 {
                    if centre { tipCentre += 1; #expect((p - end).length <= 1e-9) }
                    else { tipRing += 1; #expect(abs((p - end).length - tipRadius) <= 1e-9) }
                }
            }
            #expect(baseRing == sides && tipRing == sides && tipCentre == 1)
            #expect(try stem.mesh() == mesh)
        }
    }

    @Test func petalRefusals() {
        let bad: [(Double, Double, Double, Int, String)] = [
            (0, 1, 0, 8, "length"), (100.5, 1, 0, 8, "length"), (.nan, 1, 0, 8, "length"),
            (2, 0, 0, 8, "width"), (2, 2.5, 0, 8, "width"), (2, .nan, 0, 8, "width"),
            (2, 1, -3.2, 8, "curl"), (2, 1, 3.2, 8, "curl"), (2, 1, .nan, 8, "curl"),
            (2, 1, 0, 1, "segments"), (2, 1, 0, 65, "segments"),
        ]
        for (length, width, curl, segments, name) in bad {
            #expect(throws: PlantError.shapeParameter(name)) {
                try PetalShape(length: length, width: width, curl: curl, segments: segments)
            }
        }
        #expect((try? PetalShape(length: 100, width: 100, curl: Double.pi, segments: 64)) != nil)
    }

    @Test func capRefusals() {
        let bad: [(Double, Double, Double, Int, Int, String)] = [
            (0, 1, 0, 8, 2, "radius"), (101, 1, 0, 8, 2, "radius"), (.nan, 1, 0, 8, 2, "radius"),
            (1, 0, 0, 8, 2, "height"), (1, 101, 0, 8, 2, "height"), (1, .nan, 0, 8, 2, "height"),
            (1, 1, -0.1, 8, 2, "rim"), (1, 1, 1, 8, 2, "rim"), (1, 1, .nan, 8, 2, "rim"),
            (1, 1, 0, 7, 2, "sides"), (1, 1, 0, 129, 2, "sides"),
            (1, 1, 0, 8, 1, "rings"), (1, 1, 0, 8, 65, "rings"),
        ]
        for (radius, height, rim, sides, rings, name) in bad {
            #expect(throws: PlantError.shapeParameter(name)) {
                try CapShape(radius: radius, height: height, rim: rim, sides: sides, rings: rings)
            }
        }
        #expect((try? CapShape(radius: 100, height: 100, rim: 99, sides: 128, rings: 64)) != nil)
    }

    @Test func stemRefusals() {
        let bad: [(Double, Double, Double, Double, Int, Int, String)] = [
            (0, 1, 1, 0, 3, 1, "length"), (101, 1, 1, 0, 3, 1, "length"), (.nan, 1, 1, 0, 3, 1, "length"),
            (1, 0, 0.1, 0, 3, 1, "baseRadius"), (1, .infinity, 1, 0, 3, 1, "baseRadius"),
            (1, .nan, 1, 0, 3, 1, "baseRadius"),
            (1, 1, 0, 0, 3, 1, "tipRadius"), (1, 1, 1.5, 0, 3, 1, "tipRadius"), (1, 1, .nan, 0, 3, 1, "tipRadius"),
            (1, 1, 1, -3.2, 3, 1, "bend"), (1, 1, 1, 3.2, 3, 1, "bend"), (1, 1, 1, .nan, 3, 1, "bend"),
            (1, 1, 1, 0, 2, 1, "sides"), (1, 1, 1, 0, 65, 1, "sides"),
            (1, 1, 1, 0, 3, 0, "segments"), (1, 1, 1, 0, 3, 65, "segments"),
        ]
        for (length, base, tip, bend, sides, segments, name) in bad {
            #expect(throws: PlantError.shapeParameter(name)) {
                try StemShape(length: length, baseRadius: base, tipRadius: tip, bend: bend, sides: sides,
                              segments: segments)
            }
        }
        #expect((try? StemShape(length: 100, baseRadius: 2, tipRadius: 2, bend: -Double.pi, sides: 64,
                                segments: 64)) != nil)
    }
}
