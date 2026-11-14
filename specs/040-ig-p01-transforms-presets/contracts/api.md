# Contract: VisualCoreMath symmetry (G-SYMMETRY) and experience controls

```swift
public enum PointGroup: Sendable, Equatable, Hashable, Codable {
  case cyclic(Int); case dihedral(Int)
  public static let orderRange: ClosedRange<Int>   // 1...24
  public var order: Int { get }; public var imageCount: Int { get }
  public func images(of p: Vec2) -> [Vec2]          // identity first, then rotations, then mirrors
  public func fold(_ p: Vec2) -> Vec2               // into the fundamental wedge; idempotent
}
public enum WallpaperLattice: Sendable, Equatable, Hashable, Codable {
  case square; case hexagonal
  public var pointGroupImages: Int { get }          // 8 or 12
  public func cellCenters(rings: Int) -> [Vec2]      // centre first, then ring by ring; rings ≥ 0
  public func images(of p: Vec2, rings: Int) -> [Vec2]
  public func fold(_ p: Vec2) -> Vec2               // into the fundamental triangle of the cell; idempotent, periodic
}
```

Experience controls (ids under `experience.a05.infinite-geometry.`): `preset.select`, `symmetry.order`, `repeats.set`,
`scale.set`, `palette.set`, `reseed`; refusals use `ActionResult.rejected(.rule(code: "a05.<reason>"))` /
`.invalid(...)` as Particle Universe does.
