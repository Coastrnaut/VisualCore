# Contract: A05-P05 framework additions

```swift
// VisualCoreScenes
extension Mesh { public var byteSize: Int }   // (positions + normals) × 12 + uvs × 8 + indices × 4
public final class MeshCache {                // not Sendable; owned by one presenter on the main actor
  public static let defaultMaxEntries = 16; public static let defaultMaxBytes = 32 << 20
  public let maxEntries: Int; public let maxBytes: Int
  public private(set) var hits: Int; public private(set) var misses: Int; public private(set) var evictions: Int
  public var count: Int { get }; public var bytes: Int { get }
  public init(maxEntries: Int = defaultMaxEntries, maxBytes: Int = defaultMaxBytes)
  public func mesh(for key: UInt64, build: () throws -> Mesh) rethrows -> Mesh
  public func contains(_ key: UInt64) -> Bool
  public func removeAll()
}
// VisualCoreDiagnostics
public enum TessellationChoice {
  public static func segments(full: Int, minimum: Int, share: Double) -> Int
  public static func segments(full: Int, minimum: Int, share: Double, vertices: (Int) -> Int, budget: Int) -> Int
}
```

Rules: `segments` = clamp(round(full × share), minimum…full) for a finite share in 0…1 (non-finite → minimum); the budget
variant lowers the result while `vertices(segments) > budget`, never below `minimum`. Non-decreasing in `share`.
