// PlantScatterTests — feature 219 (R02-F19) T-R02F19-005 (FR-R02F19-005; SC-R02F19-004; clarification Q4).
// 100 seeded scatters keep the spacing (brute force), stay in the area and the count limit, draw scale, yaw and variant
// in range, repeat identically and carry T · R_y · S; a spacing larger than the area gives one instance; the sparse
// grid (tiny spacing over a large area) keeps the spacing too; every bad parameter and an empty area are refused.
// Test data uses explicit types and plain loops (CI type-check rule).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

@Suite struct PlantScatterTests {
    static func components(_ m: Mat4) -> [Double] {
        let columns: [Vec4] = [m.c0, m.c1, m.c2, m.c3]
        var out: [Double] = []
        for c in columns {
            out.append(c.x); out.append(c.y); out.append(c.z); out.append(c.w)
        }
        return out
    }

    /// T(x, 0, z) · R_y(yaw) · S(scale) written out in closed form, column-major.
    static func expectedModel(_ instance: PlantInstance) -> [Double] {
        let s: Double = instance.scale
        let c: Double = cos(instance.yaw)
        let n: Double = sin(instance.yaw)
        let p: Vec3 = instance.position
        return [s * c, 0, -s * n, 0, 0, s, 0, 0, s * n, 0, s * c, 0, p.x, 0, p.z, 1]
    }

    static func checkSpacing(_ instances: [PlantInstance], _ spacing: Double) -> Bool {
        var i = 0
        while i < instances.count {
            var j = i + 1
            while j < instances.count {
                let a: Vec3 = instances[i].position
                let b: Vec3 = instances[j].position
                if hypot(a.x - b.x, a.z - b.z) < spacing { return false }
                j += 1
            }
            i += 1
        }
        return true
    }

    @Test func hundredSeededScattersKeepEveryRule() throws {
        for k in 0..<100 {
            let seed: UInt64 = 2_019 + UInt64(k)
            let minX: Double = -Double(k % 7) - 1
            let maxX: Double = minX + 2 + Double(k % 5) * 3
            let minZ: Double = Double(k % 3) - 4
            let maxZ: Double = minZ + 1.5 + Double(k % 4) * 2.5
            let spacing: Double = 0.2 + Double(k % 6) * 0.15
            let maxCount: Int = 1 + (k * 37) % 200
            let scale: ClosedRange<Double> = (0.5 + Double(k % 3) * 0.25)...(1.5 + Double(k % 2))
            let variants: Int = 1 + k % 8
            let a: [PlantInstance] = try PlantScatter.scatter(minX: minX, maxX: maxX, minZ: minZ, maxZ: maxZ,
                                                              spacing: spacing, maxCount: maxCount, scale: scale,
                                                              variants: variants, seed: seed)
            let b: [PlantInstance] = try PlantScatter.scatter(minX: minX, maxX: maxX, minZ: minZ, maxZ: maxZ,
                                                              spacing: spacing, maxCount: maxCount, scale: scale,
                                                              variants: variants, seed: seed)
            #expect(a == b)
            #expect(!a.isEmpty)
            #expect(a.count <= maxCount)
            #expect(Self.checkSpacing(a, spacing))
            for instance in a {
                let p: Vec3 = instance.position
                #expect(p.x >= minX && p.x <= maxX && p.z >= minZ && p.z <= maxZ && p.y == 0)
                #expect(instance.scale >= scale.lowerBound && instance.scale <= scale.upperBound)
                #expect(instance.yaw >= 0 && instance.yaw < 2 * Double.pi)
                #expect(instance.variant >= 0 && instance.variant < variants)
                let got: [Double] = Self.components(instance.model)
                let want: [Double] = Self.expectedModel(instance)
                var worst: Double = 0
                for i in 0..<16 { worst = max(worst, abs(got[i] - want[i])) }
                #expect(worst <= 1e-12)
                let origin: Vec4 = instance.model * Vec4(0, 0, 0, 1)
                #expect(origin == Vec4(p, 1))
            }
        }
    }

    @Test func modelMatchesQuaternionRotation() throws {
        let a: [PlantInstance] = try PlantScatter.scatter(minX: 0, maxX: 10, minZ: 0, maxZ: 10, spacing: 1, maxCount: 20,
                                                          scale: 0.5...2, variants: 3, seed: 2_019)
        for instance in a {
            let q: Quat = Quat(axis: Vec3(0, 1, 0), angle: instance.yaw)
            let s: Vec3 = Vec3(instance.scale, instance.scale, instance.scale)
            let m: Mat4 = Mat4.translation(instance.position) * Mat4.rotation(q) * Mat4.scale(s)
            let got: [Double] = Self.components(instance.model)
            let want: [Double] = Self.components(m)
            for i in 0..<16 { #expect(abs(got[i] - want[i]) <= 1e-12) }
        }
    }

    @Test func spacingLargerThanTheAreaGivesOneInstance() throws {
        let a: [PlantInstance] = try PlantScatter.scatter(minX: 0, maxX: 1, minZ: 0, maxZ: 1, spacing: 5, maxCount: 100,
                                                          scale: 1...1, variants: 1, seed: 2_019)
        #expect(a.count == 1)
        #expect(a[0].scale == 1 && a[0].variant == 0)
    }

    @Test func countStopsAtMaxCount() throws {
        let a: [PlantInstance] = try PlantScatter.scatter(minX: 0, maxX: 100, minZ: 0, maxZ: 100, spacing: 0.5,
                                                          maxCount: 50, scale: 1...2, variants: 4, seed: 2_019)
        #expect(a.count == 50)
    }

    @Test func sparseGridKeepsTheSpacing() throws {
        // (1e4 / (1e-3 / √2))² cells far exceed the dense limit, so the dictionary storage is used.
        let a: [PlantInstance] = try PlantScatter.scatter(minX: -5_000, maxX: 5_000, minZ: -5_000, maxZ: 5_000,
                                                          spacing: 1e-3, maxCount: 300, scale: 1...1, variants: 2,
                                                          seed: 2_019)
        #expect(a.count == 300)
        #expect(Self.checkSpacing(a, 1e-3))
        // A dense grid with a large spacing, where most candidates conflict, keeps it too.
        let b: [PlantInstance] = try PlantScatter.scatter(minX: 0, maxX: 1e6, minZ: 0, maxZ: 1e6, spacing: 1e5,
                                                          maxCount: 500, scale: 1...1, variants: 1, seed: 2_020)
        #expect(Self.checkSpacing(b, 1e5))
        #expect(b.count <= 500)
    }

    @Test func differentSeedsDiffer() throws {
        let a: [PlantInstance] = try PlantScatter.scatter(minX: 0, maxX: 10, minZ: 0, maxZ: 10, spacing: 0.5,
                                                          maxCount: 40, scale: 1...2, variants: 4, seed: 2_019)
        let b: [PlantInstance] = try PlantScatter.scatter(minX: 0, maxX: 10, minZ: 0, maxZ: 10, spacing: 0.5,
                                                          maxCount: 40, scale: 1...2, variants: 4, seed: 2_020)
        #expect(a != b)
    }

    static func refusal(_ minX: Double, _ maxX: Double, _ minZ: Double, _ maxZ: Double, _ spacing: Double,
                        _ maxCount: Int, _ scale: ClosedRange<Double>, _ variants: Int) -> PlantError? {
        do {
            _ = try PlantScatter.scatter(minX: minX, maxX: maxX, minZ: minZ, maxZ: maxZ, spacing: spacing,
                                         maxCount: maxCount, scale: scale, variants: variants, seed: 2_019)
            return nil
        } catch {
            return error
        }
    }

    @Test func badAreasAreRefused() {
        let area: PlantError = .scatterArea
        #expect(Self.refusal(1, 1, 0, 1, 1, 10, 1...1, 1) == area)
        #expect(Self.refusal(2, 1, 0, 1, 1, 10, 1...1, 1) == area)
        #expect(Self.refusal(0, 1, 0, 0, 1, 10, 1...1, 1) == area)
        #expect(Self.refusal(0, 1, 3, 2, 1, 10, 1...1, 1) == area)
        #expect(Self.refusal(.nan, 1, 0, 1, 1, 10, 1...1, 1) == area)
        #expect(Self.refusal(0, .infinity, 0, 1, 1, 10, 1...1, 1) == area)
        #expect(Self.refusal(0, 1, -.infinity, 1, 1, 10, 1...1, 1) == area)
        #expect(Self.refusal(-1e308, 1e308, 0, 1, 1, 10, 1...1, 1) == area)
        #expect(area.reasonCode == "r2-f19.scatter-area")
    }

    @Test func badParametersAreRefused() {
        let spacing: PlantError = .scatterParameter("spacing")
        let count: PlantError = .scatterParameter("maxCount")
        let scale: PlantError = .scatterParameter("scale")
        let variants: PlantError = .scatterParameter("variants")
        #expect(Self.refusal(0, 1, 0, 1, 0, 10, 1...1, 1) == spacing)
        #expect(Self.refusal(0, 1, 0, 1, -1, 10, 1...1, 1) == spacing)
        #expect(Self.refusal(0, 1, 0, 1, .nan, 10, 1...1, 1) == spacing)
        #expect(Self.refusal(0, 1, 0, 1, .infinity, 10, 1...1, 1) == spacing)
        #expect(Self.refusal(0, 1, 0, 1, 1, 0, 1...1, 1) == count)
        #expect(Self.refusal(0, 1, 0, 1, 1, PlantScatter.maxCount + 1, 1...1, 1) == count)
        #expect(Self.refusal(0, 1, 0, 1, 1, 10, 0...1, 1) == scale)
        #expect(Self.refusal(0, 1, 0, 1, 1, 10, -1...1, 1) == scale)
        #expect(Self.refusal(0, 1, 0, 1, 1, 10, 1...100.5, 1) == scale)
        #expect(Self.refusal(0, 1, 0, 1, 1, 10, 1...Double.infinity, 1) == scale)
        #expect(Self.refusal(0, 1, 0, 1, 1, 10, 1...1, 0) == variants)
        #expect(Self.refusal(0, 1, 0, 1, 1, 10, 1...1, 65) == variants)
        #expect(Self.refusal(0, 1, 0, 1, 1, 10, 1...1, 64) == nil)
        #expect(Self.refusal(0, 1_000, 0, 1_000, 1, PlantScatter.maxCount, 0.01...100, 1) == nil)
        #expect(scale.reasonCode == "r2-f19.scatter-parameter")
    }
}
