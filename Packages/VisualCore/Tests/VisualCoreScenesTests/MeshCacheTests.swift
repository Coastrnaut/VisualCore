// MeshCacheTests.swift — feature 044 (A05-P05) T-A05-502 (FR-A05-530; gap G-MESHCACHE; research D3).
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

/// A synthetic mesh tagged by `tag` with `vertices` vertices and `triangles` triangles.
private func synthetic(tag: Int, vertices: Int, triangles: Int) -> Mesh {
    Mesh(positions: (0..<vertices).map { Vec3(Double(tag), Double($0), 0) },
         normals: Array(repeating: Vec3(0, 0, 1), count: vertices),
         uvs: Array(repeating: Vec2(0, 0), count: vertices),
         indices: Array(repeating: 0, count: triangles * 3))
}

/// A tiny deterministic linear congruential generator (64-bit, Knuth constants).
private struct LCG {
    var state: UInt64
    mutating func next(_ bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}

private struct Failure: Error {}

@Test func byteSizeFormulaOnKnownMeshes() {
    let m = synthetic(tag: 0, vertices: 5, triangles: 7)
    #expect(m.byteSize == 5 * 12 + 5 * 12 + 5 * 8 + 21 * 4)
    let cube = Mesh.cube()
    #expect(cube.byteSize == cube.positions.count * 32 + cube.indices.count * 4)
    #expect(Mesh(positions: [], normals: [], uvs: [], indices: []).byteSize == 0)
}

@Test func defaultsAndNegativeLimits() {
    let cache = MeshCache()
    #expect(cache.maxEntries == 16 && cache.maxBytes == 32 << 20)
    let negative = MeshCache(maxEntries: -3, maxBytes: -1)
    #expect(negative.maxEntries == 0 && negative.maxBytes == 0)
}

@Test func hitMarksRecentAndMissBuildsOnce() {
    let cache = MeshCache()
    var builds = 0
    let a = synthetic(tag: 1, vertices: 3, triangles: 1), b = synthetic(tag: 2, vertices: 4, triangles: 2)
    #expect(cache.mesh(for: 1) { builds += 1; return a } == a)
    #expect(cache.mesh(for: 2) { builds += 1; return b } == b)
    #expect(cache.mesh(for: 1) { builds += 1; return b } == a)
    #expect(cache.hits == 1 && cache.misses == 2 && builds == 2)
    #expect(cache.count == 2 && cache.bytes == a.byteSize + b.byteSize)
    _ = cache.mesh(for: 3) { builds += 1; return a }
    #expect(cache.misses == 3 && builds == 3 && cache.contains(3) && !cache.contains(4))
}

@Test func leastRecentlyUsedIsEvicted() {
    let cache = MeshCache(maxEntries: 2)
    let m = synthetic(tag: 0, vertices: 3, triangles: 1)
    _ = cache.mesh(for: 1) { m }
    _ = cache.mesh(for: 2) { m }
    _ = cache.mesh(for: 1) { m }            // 2 is now least recently used
    _ = cache.mesh(for: 3) { m }
    #expect(cache.contains(1) && !cache.contains(2) && cache.contains(3) && cache.evictions == 1)
}

@Test func oversizeIsReturnedButNotStored() {
    let big = synthetic(tag: 9, vertices: 100, triangles: 50)
    let cache = MeshCache(maxEntries: 4, maxBytes: big.byteSize - 1)
    let small = synthetic(tag: 1, vertices: 3, triangles: 1)
    _ = cache.mesh(for: 1) { small }
    #expect(cache.mesh(for: 9) { big } == big)
    #expect(!cache.contains(9) && cache.contains(1) && cache.evictions == 0 && cache.bytes == small.byteSize)
    var builds = 0
    _ = cache.mesh(for: 9) { builds += 1; return big }
    #expect(builds == 1 && cache.misses == 3)
}

@Test func zeroEntriesStoresNothing() {
    let cache = MeshCache(maxEntries: 0)
    let m = synthetic(tag: 1, vertices: 3, triangles: 1)
    for _ in 0..<3 { #expect(cache.mesh(for: 1) { m } == m) }
    #expect(cache.count == 0 && cache.bytes == 0 && cache.misses == 3 && cache.hits == 0 && cache.evictions == 0)
}

@Test func throwingBuildStoresNothing() {
    let cache = MeshCache()
    #expect(throws: Failure.self) { _ = try cache.mesh(for: 7) { () throws -> Mesh in throw Failure() } }
    #expect(cache.count == 0 && cache.bytes == 0 && cache.misses == 1 && !cache.contains(7))
}

@Test func removeAllClearsEntriesKeepsCounters() {
    let cache = MeshCache()
    let m = synthetic(tag: 1, vertices: 3, triangles: 1)
    _ = cache.mesh(for: 1) { m }
    _ = cache.mesh(for: 1) { m }
    cache.removeAll()
    #expect(cache.count == 0 && cache.bytes == 0 && !cache.contains(1) && cache.hits == 1 && cache.misses == 1)
}

@Test func matchesReferenceLRUOnSeededSequences() {
    for seed in 0..<200 {
        var rng = LCG(state: UInt64(seed) &* 0x9E37_79B9_7F4A_7C15 &+ 1)
        // Each key has a fixed mesh within a sequence.
        let meshes = (0..<12).map { synthetic(tag: $0, vertices: 1 + rng.next(40), triangles: rng.next(30)) }
        let maxEntries = rng.next(8)
        let maxBytes = 200 + rng.next(4000)
        let cache = MeshCache(maxEntries: maxEntries, maxBytes: maxBytes)
        var model: [Int] = []                   // keys, least recently used first
        var hits = 0, misses = 0, evictions = 0
        for _ in 0..<60 {
            let key = rng.next(12)
            var built = 0
            let got = cache.mesh(for: UInt64(key)) { built += 1; return meshes[key] }
            #expect(got == meshes[key])
            if let i = model.firstIndex(of: key) {
                model.remove(at: i); model.append(key); hits += 1
                #expect(built == 0)
            } else {
                misses += 1
                #expect(built == 1)
                if maxEntries > 0 && meshes[key].byteSize <= maxBytes {
                    model.append(key)
                    while model.count > maxEntries || model.reduce(0, { $0 + meshes[$1].byteSize }) > maxBytes {
                        model.removeFirst(); evictions += 1
                    }
                }
            }
            let modelBytes = model.reduce(0) { $0 + meshes[$1].byteSize }
            #expect(cache.count == model.count && cache.bytes == modelBytes)
            #expect(cache.count <= maxEntries && cache.bytes <= maxBytes)
            #expect((0..<12).allSatisfy { cache.contains(UInt64($0)) == model.contains($0) })
            #expect(cache.hits == hits && cache.misses == misses && cache.evictions == evictions)
        }
    }
}
