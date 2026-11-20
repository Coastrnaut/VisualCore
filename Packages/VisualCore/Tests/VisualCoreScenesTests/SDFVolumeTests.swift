// SDFVolumeTests — feature 211 (R02-F11) T-R02F11-005 (FR-R02F11-005; SC-R02F11-004). A sphere of radius 1 in ±1.1 and
// a box of half extents (0.7, 0.5, 0.3) in ±1 are within 2% of their analytic volumes at 64³ and the 64³ error is at
// most half the 32³ error; sampling twice gives the same sample and digest; the digest follows the packed-bit FNV-1a
// rule; resolutions 0 and 257, non-finite and inverted bounds are refused.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

@Suite struct SDFVolumeTests {
    static func relativeError(_ shape: SDFShape, _ bound: Double, _ n: Int, _ exact: Double) throws -> Double {
        let sample = try SDFVolume.sample(shape, boundsMin: Vec3(-bound, -bound, -bound),
                                          boundsMax: Vec3(bound, bound, bound), resolution: n)
        return (sample.volume - exact) / exact
    }

    @Test func sphereVolumeConverges() throws {
        let sphere = try SDFShape.sphere(radius: 1)
        let exact = 4.0 / 3.0 * Double.pi
        let e32 = try Self.relativeError(sphere, 1.1, 32, exact)
        let e64 = try Self.relativeError(sphere, 1.1, 64, exact)
        print("SDFVolume sphere relative error: 32³ \(e32), 64³ \(e64)")
        #expect(abs(e64) <= 0.02)
        #expect(abs(e64) <= 0.5 * abs(e32))
    }

    /// The axis-aligned box in ±1 is grid-aliased: its faces 0.7 and 0.3 fall at the same fractional cell position at
    /// 32 and 64 cells (11.2 and 22.4, 4.8 and 9.6 cells from the centre), so the midpoint count is 1.375 × 1 × 0.625
    /// at both resolutions (+2.31%) and never converges. The convergence criterion is checked on the same box in a
    /// generic orientation (0.7 rad about (1, 2, 3)), where the faces cut the cells at varying positions.
    @Test func boxVolumeConverges() throws {
        let box = try SDFShape.box(halfExtents: Vec3(0.7, 0.5, 0.3))
        let exact = 1.4 * 1.0 * 0.6
        let a32 = try Self.relativeError(box, 1, 32, exact)
        let a64 = try Self.relativeError(box, 1, 64, exact)
        print("SDFVolume axis-aligned box relative error: 32³ \(a32), 64³ \(a64)")
        #expect(abs(a32 - (1.375 * 1.0 * 0.625 / exact - 1)) < 1e-12)
        #expect(a64 == a32)
        let turned = try box.rotated(by: Quat(axis: Vec3(1, 2, 3).normalized, angle: 0.7))
        let e32 = try Self.relativeError(turned, 1, 32, exact)
        let e64 = try Self.relativeError(turned, 1, 64, exact)
        print("SDFVolume rotated box relative error: 32³ \(e32), 64³ \(e64)")
        #expect(abs(e64) <= 0.02)
        #expect(abs(e64) <= 0.5 * abs(e32))
    }

    @Test func samplingIsDeterministicAndTheDigestFollowsTheRule() throws {
        let shape = try SDFShape.union([SDFShape.sphere(radius: 0.6),
                                        SDFShape.box(halfExtents: Vec3(0.2, 0.9, 0.2))])
        let lo = Vec3(-1, -1, -1), hi = Vec3(1, 1, 1)
        let a = try SDFVolume.sample(shape, boundsMin: lo, boundsMax: hi, resolution: 24)
        let b = try SDFVolume.sample(shape, boundsMin: lo, boundsMax: hi, resolution: 24)
        #expect(a == b)
        #expect(a.digest == b.digest)
        #expect(a.resolution == 24 && a.boundsMin == lo && a.boundsMax == hi)
        // Recompute the digest independently: bits x fastest, packed least significant first, FNV-1a 64.
        let n = 3, cell = 2.0 / Double(n)
        var bits: [Bool] = []
        for k in 0..<n {
            for j in 0..<n {
                for i in 0..<n {
                    let p = Vec3(-1 + (Double(i) + 0.5) * cell, -1 + (Double(j) + 0.5) * cell,
                                 -1 + (Double(k) + 0.5) * cell)
                    bits.append(shape.distance(at: p) < 0)
                }
            }
        }
        var bytes = [UInt8](repeating: 0, count: (bits.count + 7) / 8)
        for (index, inside) in bits.enumerated() where inside { bytes[index / 8] |= UInt8(1) << UInt8(index % 8) }
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in bytes { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        let small = try SDFVolume.sample(shape, boundsMin: lo, boundsMax: hi, resolution: n)
        #expect(small.digest == hash)
        #expect(small.insideCount == bits.filter { $0 }.count)
        #expect(abs(small.volume - Double(small.insideCount) * cell * cell * cell) < 1e-12)
        let other = try SDFVolume.sample(SDFShape.sphere(radius: 0.6), boundsMin: lo, boundsMax: hi, resolution: 24)
        #expect(other.digest != a.digest)
    }

    @Test func invalidRequestsAreRefused() throws {
        let sphere = try SDFShape.sphere(radius: 1)
        let lo = Vec3(-1, -1, -1), hi = Vec3(1, 1, 1)
        #expect(throws: SDFError.nonPositive("resolution")) {
            try SDFVolume.sample(sphere, boundsMin: lo, boundsMax: hi, resolution: 0)
        }
        #expect(throws: SDFError.nonPositive("resolution")) {
            try SDFVolume.sample(sphere, boundsMin: lo, boundsMax: hi, resolution: 257)
        }
        #expect(throws: SDFError.nonPositive("bounds")) {
            try SDFVolume.sample(sphere, boundsMin: hi, boundsMax: lo, resolution: 8)
        }
        #expect(throws: SDFError.nonPositive("bounds")) {
            try SDFVolume.sample(sphere, boundsMin: lo, boundsMax: Vec3(1, -1, 1), resolution: 8)
        }
        #expect(throws: SDFError.nonFinite("boundsMin")) {
            try SDFVolume.sample(sphere, boundsMin: Vec3(.nan, 0, 0), boundsMax: hi, resolution: 8)
        }
        #expect(throws: SDFError.nonFinite("boundsMax")) {
            try SDFVolume.sample(sphere, boundsMin: lo, boundsMax: Vec3(1, .infinity, 1), resolution: 8)
        }
        let one = try SDFVolume.sample(sphere, boundsMin: lo, boundsMax: hi, resolution: 1)
        #expect(one.insideCount == 1 && one.volume == 8)
    }
}
