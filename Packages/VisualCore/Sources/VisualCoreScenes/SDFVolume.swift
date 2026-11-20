// SDFVolume — feature 211 (R02-F11) T-R02F11-005 (FR-R02F11-005; clarification Q5; research R5; SC-R02F11-004).
// Estimates the volume of a signed-distance description by sampling the centres of an n³ grid over a box (1 ≤ n ≤ 256):
// a cell counts as inside when the distance at its centre is negative, and the volume is the count times the cell
// volume (midpoint rule, error O(h) at the surface). Cells are visited x fastest, then y, then z; the inside bits are
// packed in that order, least significant bit first, into bytes (the last byte padded with zeros) and digested with
// 64-bit FNV-1a, so two samplings of the same description are comparable by one number.
import Foundation
import VisualCoreMath

/// The result of sampling a description on a grid (see the file header).
public struct SDFVolumeSample: Sendable, Equatable {
    /// The lower corner of the sampled box.
    public let boundsMin: Vec3
    /// The upper corner of the sampled box.
    public let boundsMax: Vec3
    /// Cells per axis.
    public let resolution: Int
    /// How many cell centres are inside (distance < 0).
    public let insideCount: Int
    /// The estimated volume: `insideCount` times the cell volume.
    public let volume: Double
    /// The 64-bit FNV-1a digest of the packed inside bits.
    public let digest: UInt64

    /// Creates a sample from its parts.
    public init(boundsMin: Vec3, boundsMax: Vec3, resolution: Int, insideCount: Int, volume: Double, digest: UInt64) {
        self.boundsMin = boundsMin
        self.boundsMax = boundsMax
        self.resolution = resolution
        self.insideCount = insideCount
        self.volume = volume
        self.digest = digest
    }
}

/// Grid sampling of signed-distance descriptions (see the file header).
public enum SDFVolume {
    /// The most cells per axis.
    public static let maxResolution = 256

    /// Samples `shape` at the cell centres of a `resolution`³ grid over `[boundsMin, boundsMax]`.
    ///
    /// Refuses a resolution outside 1…256 (`nonPositive("resolution")`), non-finite bounds
    /// (`nonFinite("boundsMin")`, `nonFinite("boundsMax")`) and a minimum not below the maximum on any axis
    /// (`nonPositive("bounds")`).
    public static func sample(_ shape: SDFShape, boundsMin: Vec3, boundsMax: Vec3,
                              resolution: Int) throws(SDFError) -> SDFVolumeSample {
        guard (1...maxResolution).contains(resolution) else { throw .nonPositive("resolution") }
        guard boundsMin.isFinite else { throw .nonFinite("boundsMin") }
        guard boundsMax.isFinite else { throw .nonFinite("boundsMax") }
        guard boundsMin.x < boundsMax.x, boundsMin.y < boundsMax.y, boundsMin.z < boundsMax.z else {
            throw .nonPositive("bounds")
        }
        let n = Double(resolution)
        let cell = Vec3((boundsMax.x - boundsMin.x) / n, (boundsMax.y - boundsMin.y) / n,
                        (boundsMax.z - boundsMin.z) / n)
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        let prime: UInt64 = 0x0000_0100_0000_01b3
        var byte: UInt8 = 0, bit = 0, count = 0
        for k in 0..<resolution {
            let z = boundsMin.z + (Double(k) + 0.5) * cell.z
            for j in 0..<resolution {
                let y = boundsMin.y + (Double(j) + 0.5) * cell.y
                for i in 0..<resolution {
                    let x = boundsMin.x + (Double(i) + 0.5) * cell.x
                    if shape.distance(at: Vec3(x, y, z)) < 0 {
                        byte |= 1 << UInt8(bit)
                        count += 1
                    }
                    bit += 1
                    if bit == 8 {
                        hash = (hash ^ UInt64(byte)) &* prime
                        byte = 0
                        bit = 0
                    }
                }
            }
        }
        if bit > 0 { hash = (hash ^ UInt64(byte)) &* prime }
        return SDFVolumeSample(boundsMin: boundsMin, boundsMax: boundsMax, resolution: resolution,
                               insideCount: count, volume: Double(count) * cell.x * cell.y * cell.z, digest: hash)
    }
}
