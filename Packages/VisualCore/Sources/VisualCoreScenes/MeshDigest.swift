// MeshDigest.swift — feature 205 (R02-F05) T-R02F05-003 (FR-R02F05-051, SC-R02F05-003).
// A platform-independent content digest of a mesh (spec Clarifications: little-endian stream, SHA-256).
import VisualCoreMath

extension Mesh {
    /// The SHA-256 content digest of this mesh as 64 lower-case hexadecimal digits.
    ///
    /// The hashed byte stream is little-endian: the counts of positions, normals, texture coordinates and indices as
    /// `UInt64`; then every position (x, y, z), every normal (x, y, z) and every texture coordinate (x, y) as its
    /// IEEE-754 binary64 bit pattern, with −0 written as +0; then every index as `UInt32`.
    public var digest: String {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(32 + (positions.count + normals.count) * 24 + uvs.count * 16 + indices.count * 4)
        func put64(_ v: UInt64) {
            for s in stride(from: 0, to: 64, by: 8) { bytes.append(UInt8(truncatingIfNeeded: v >> UInt64(s))) }
        }
        func putDouble(_ d: Double) { put64((d == 0 ? 0.0 : d).bitPattern) }
        for count in [positions.count, normals.count, uvs.count, indices.count] { put64(UInt64(count)) }
        for p in positions { putDouble(p.x); putDouble(p.y); putDouble(p.z) }
        for n in normals { putDouble(n.x); putDouble(n.y); putDouble(n.z) }
        for t in uvs { putDouble(t.x); putDouble(t.y) }
        for i in indices {
            for s in stride(from: 0, to: 32, by: 8) { bytes.append(UInt8(truncatingIfNeeded: i >> UInt32(s))) }
        }
        return StableHash.sha256Hex(bytes)
    }
}
