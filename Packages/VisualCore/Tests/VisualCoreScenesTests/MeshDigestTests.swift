// MeshDigestTests.swift — feature 205 (R02-F05) T-R02F05-003 (FR-R02F05-051, SC-R02F05-003).
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

private let tri = Mesh(positions: [Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(0, 1, 0)],
                       normals: Array(repeating: Vec3(0, 0, 1), count: 3),
                       uvs: [Vec2(0, 0), Vec2(1, 0), Vec2(0, 1)], indices: [0, 1, 2])

/// An independent re-implementation of the clarified byte stream, for cross-checking `Mesh.digest`.
private func referenceDigest(_ m: Mesh) -> String {
    var bytes: [UInt8] = []
    func le(_ v: UInt64, _ width: Int) { for k in 0..<width { bytes.append(UInt8((v >> UInt64(8 * k)) & 0xFF)) } }
    func d(_ x: Double) { le(x == 0 ? 0 : x.bitPattern, 8) }
    le(UInt64(m.positions.count), 8); le(UInt64(m.normals.count), 8)
    le(UInt64(m.uvs.count), 8); le(UInt64(m.indices.count), 8)
    m.positions.forEach { d($0.x); d($0.y); d($0.z) }
    m.normals.forEach { d($0.x); d($0.y); d($0.z) }
    m.uvs.forEach { d($0.x); d($0.y) }
    m.indices.forEach { le(UInt64($0), 4) }
    return StableHash.sha256Hex(bytes)
}

@Test func digestIsStableAndMatchesReference() {
    #expect(tri.digest == tri.digest)
    #expect(tri.digest == referenceDigest(tri))
    #expect(Mesh.cube().digest == referenceDigest(Mesh.cube()))
    let hex = tri.digest
    #expect(hex.count == 64)
    #expect(hex.allSatisfy { "0123456789abcdef".contains($0) })
    #expect(Mesh(positions: [], normals: [], uvs: [], indices: []).digest == referenceDigest(.init(
        positions: [], normals: [], uvs: [], indices: [])))
}

@Test func equalMeshesHaveEqualDigests() {
    let copy = Mesh(positions: tri.positions, normals: tri.normals, uvs: tri.uvs, indices: tri.indices)
    #expect(copy.digest == tri.digest)
    #expect(Mesh.uvSphere(segments: 8, rings: 4).digest == Mesh.uvSphere(segments: 8, rings: 4).digest)
}

@Test func anyChangeChangesDigest() {
    let base = tri.digest
    var m = tri; m.positions[1].x = 1.0000000000000002
    #expect(m.digest != base)
    m = tri; m.normals[2].z = -1
    #expect(m.digest != base)
    m = tri; m.uvs[0].y = 0.5
    #expect(m.digest != base)
    m = tri; m.indices = [0, 2, 1]
    #expect(m.digest != base)
    m = tri; m.indices.append(0)
    #expect(m.digest != base)
}

@Test func negativeZeroEqualsPositiveZero() {
    var m = tri
    m.positions[0] = Vec3(-0.0, -0.0, -0.0)
    m.normals[0].x = -0.0
    m.uvs[0] = Vec2(-0.0, -0.0)
    #expect(m.digest == tri.digest)
}
