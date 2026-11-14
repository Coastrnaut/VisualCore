# Contract: A05-P04 experience additions (no VisualCore change)

```swift
// InfiniteGeometryExperience (Adapter)
public struct GeometryDocument: Codable, Equatable, Sendable {
  public static let version = 1; public static let maxNameLength = 60; public static let untitledName = "Untitled"
  public var version: Int; public var name: String; public var presetIndex: Int; public var preset: GeometryPreset
  public var view2D: GeometryCore.View2D; public var orbit3D: GeometryCore.Orbit3D
  public init(core: GeometryCore, name: String)
  public var openValues: [Double]          // [presetIndex, kind, order, repeats, scale, palette, seedHigh, seedLow,
                                           //  centerX, centerY, zoom, yaw, pitch, distance, targetX, targetY, targetZ, fovDegrees]
  public init?(openValues: [Double], name: String)
  public static func clean(_ name: String) -> String   // trim, cut to 60, empty → "Untitled"
}
// GeometryCore: control "composition.open" with exactly 18 values (layout above); the 64-bit seed is split into two
// 32-bit halves so every value is an exact Double.

// InfiniteGeometryExperience (Experience)
@MainActor @Observable final class GeometryLibrary {
  init(storage: ExperienceStorage, now: @escaping () -> Date = Date.init)
  private(set) var entries: [GeometryLibraryEntry]; private(set) var unreadable: Int; private(set) var newer: Int
  var errorMessage: String?
  func save(_ document: GeometryDocument, digest: String) -> GeometryLibraryEntry?
  func document(for entry: GeometryLibraryEntry) -> GeometryDocument?
  func rename(_ entry: GeometryLibraryEntry, to name: String) -> Bool
  func delete(_ entry: GeometryLibraryEntry) -> Bool
  func reload()
}
struct GeometryLibraryEntry: Equatable, Identifiable, Sendable { var id: UUID; var name: String; var saved: Date; var digest: String }

enum GeometryExport {
  static let longEdge = 2048
  static func size(canvas: CGSize, maxEdge: Int) -> (width: Int, height: Int)?   // nil for a zero-size canvas
  @MainActor static func png(still: ExperienceStillRenderer, canvas: CGSize, maxEdge: Int) throws -> GeometryCapture
}
struct GeometryCapture: Transferable { let data: Data; let width: Int; let height: Int }
```
