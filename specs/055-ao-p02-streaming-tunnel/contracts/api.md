# Contract: A07-P02 framework and core additions

```swift
// VisualCoreScenes (pure)
public struct SegmentWindowStep: Sendable, Equatable { public let toBuild: [Int]; public let toRetire: [Int] }
public struct SegmentWindow: Sendable, Equatable {
  public static let maxBuildsPerStep: Int                       // 2
  public init?(behind: Int, ahead: Int, capacity: Int)          // nil if capacity < behind + ahead + 1 or negative
  public private(set) var live: [Int]                           // sorted
  public mutating func advance(to distance: Double, pieceLength: Double) -> SegmentWindowStep
}
public struct SlotPool<Element>: Sendable where Element: Sendable {
  public init(capacity: Int, make: (Int) -> Element)
  public var capacity: Int { get }; public var available: Int { get }
  public mutating func acquire() -> Int?                        // slot index, nil when exhausted
  public mutating func release(_ slot: Int)
  public subscript(slot: Int) -> Element { get set }
}
// VisualCoreRendering
public struct MeshFog: Sendable, Equatable { public init?(start: Double, end: Double, color: Vec4) }
extension MeshRenderer { public func draw(model: Mat4, view: Mat4, projection: Mat4, color: Vec4, fog: MeshFog?) throws }
extension DepthMeshPass { public func draw(_ items: [Item], view: Mat4, projection: Mat4, fog: MeshFog?, context: RenderContext) throws }
// module AudioOdysseyCore
public enum SourceKind: Int, CaseIterable, Codable, Sendable { case demo, microphone, file }
public struct TunnelResponse: Sendable, Equatable {
  public init(reduceMotion: Bool, reduceFlashing: Bool)
  public private(set) var ripple: Double; public private(set) var ambient: Double
  public mutating func update(rippleTarget: Double, ambientTarget: Double)   // targets in 0…1, clamped, step-limited
}
```
