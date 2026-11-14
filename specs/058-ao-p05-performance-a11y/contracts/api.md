# Contract: A07-P05 additions

```swift
// VisualCoreScenes
public struct StreamingLevel: Sendable, Equatable { public let behind, ahead: Int; public let drawDistance, elementShare: Double
  public init(behind: Int, ahead: Int, drawDistance: Double, elementShare: Double) }
public struct StreamingBudget: Sendable, Equatable {
  public init?(levels: [StreamingLevel], pieceLength: Double)
  public let levels: [StreamingLevel]; public let pieceLength: Double
  public func level(_ index: Int) -> StreamingLevel                 // clamped to 0…count-1
  public func vertexTotal(level: Int, perPieceVertices: Int) -> Int
  public func fits(level: Int, perPieceVertices: Int, budget: MeshBudget) -> Bool
}
// module AudioOdysseyCore
public struct JourneyAnnouncer: Sendable, Equatable { public static let interval: Double
  public mutating func offer(_ text: String, at time: Double) -> String?; public mutating func tick(at time: Double) -> String? }
public enum OdysseyQuality { public static let budget: StreamingBudget; public static func starCount(level: Int) -> Int }
```
