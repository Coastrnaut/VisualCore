// MeshCache.swift — feature 044 (A05-P05) T-A05-502 (FR-A05-530; gap G-MESHCACHE; research D3).
// A bounded least-recently-used cache of built meshes keyed by a 64-bit signature hash.

extension Mesh {
    /// The size of the mesh as uploaded to the GPU, in bytes: every vertex attribute is counted as 4-byte floats and
    /// every index as 4 bytes, so `byteSize = positions.count × 12 + normals.count × 12 + uvs.count × 8 +
    /// indices.count × 4` (the in-memory `Double` vectors are not what the cache budget measures).
    public var byteSize: Int {
        positions.count * 12 + normals.count * 12 + uvs.count * 8 + indices.count * 4
    }
}

/// A bounded cache of built meshes with least-recently-used eviction.
///
/// Keys are 64-bit hashes of a mesh signature (for example a `StableHash` of its build parameters). Recency is
/// ordered by a monotonically increasing use counter, so two entries never tie and eviction is deterministic.
/// A mesh larger than `maxBytes` is returned but never stored, and `maxEntries == 0` disables storing.
///
/// The cache is not thread-safe and not `Sendable`: use it from one actor (the presenter that owns it on the main
/// actor).
public final class MeshCache {
    /// The default maximum number of stored meshes.
    public static let defaultMaxEntries = 16
    /// The default maximum total `Mesh.byteSize` of stored meshes (32 MiB).
    public static let defaultMaxBytes = 32 << 20

    /// The maximum number of stored meshes (a negative limit given to `init` is stored as 0).
    public let maxEntries: Int
    /// The maximum total `Mesh.byteSize` of stored meshes (a negative limit given to `init` is stored as 0).
    public let maxBytes: Int

    /// Lookups answered from the cache.
    public private(set) var hits = 0
    /// Lookups that called the build closure, including builds that threw.
    public private(set) var misses = 0
    /// Entries removed to respect `maxEntries` or `maxBytes` (not counting `removeAll`).
    public private(set) var evictions = 0

    private struct Entry {
        var mesh: Mesh
        var lastUse: UInt64
    }

    private var entries: [UInt64: Entry] = [:]
    private var useCounter: UInt64 = 0
    private var storedBytes = 0

    /// The number of stored meshes.
    public var count: Int { entries.count }
    /// The total `Mesh.byteSize` of the stored meshes.
    public var bytes: Int { storedBytes }

    /// Creates an empty cache with the given limits; negative limits are treated as 0.
    public init(maxEntries: Int = defaultMaxEntries, maxBytes: Int = defaultMaxBytes) {
        self.maxEntries = max(0, maxEntries)
        self.maxBytes = max(0, maxBytes)
    }

    /// Returns the mesh stored for `key`, or builds, stores and returns it.
    ///
    /// On a hit the stored mesh becomes the most recently used and `build` is not called. On a miss `build` is called
    /// exactly once; the result is stored unless `maxEntries == 0` or its `byteSize` exceeds `maxBytes`, and then the
    /// least recently used other entries are evicted until `count ≤ maxEntries` and `bytes ≤ maxBytes`. If `build`
    /// throws, nothing is stored, the miss is still counted and the error is rethrown.
    public func mesh(for key: UInt64, build: () throws -> Mesh) rethrows -> Mesh {
        useCounter &+= 1
        if var entry = entries[key] {
            hits += 1
            entry.lastUse = useCounter
            entries[key] = entry
            return entry.mesh
        }
        misses += 1
        let built = try build()
        let size = built.byteSize
        guard maxEntries > 0, size <= maxBytes else { return built }
        entries[key] = Entry(mesh: built, lastUse: useCounter)
        storedBytes += size
        while entries.count > maxEntries || storedBytes > maxBytes {
            // The new entry has the largest use counter, and alone it fits both limits, so it is never chosen.
            guard let victim = entries.min(by: { $0.value.lastUse < $1.value.lastUse }) else { break }
            entries[victim.key] = nil
            storedBytes -= victim.value.mesh.byteSize
            evictions += 1
        }
        return built
    }

    /// Whether a mesh is stored for `key`; does not change recency or counters.
    public func contains(_ key: UInt64) -> Bool {
        entries[key] != nil
    }

    /// Removes every stored mesh; `hits`, `misses` and `evictions` are kept.
    public func removeAll() {
        entries.removeAll()
        storedBytes = 0
    }
}
