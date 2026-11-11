# Contract: Phase 04 API and UI

```swift
// VisualCoreScenes (pure)
public struct ExportAspect: Sendable, Hashable, Identifiable {
  public let id: String; public let title: String; public let width: Int; public let height: Int
  public init(id: String, title: String, width: Int, height: Int)
  public static let square, portrait, landscape, story: ExportAspect; public static let builtIns: [ExportAspect]
}
public struct ExportSize: Sendable, Hashable { public let width: Int; public let height: Int; public var pixelCount: Int }
public struct ExportGeometry: Sendable, Equatable {
  public static let hardMaxEdge = 8192; public static let defaultMaxPixels = 64_000_000
  public init(maxEdge: Int, maxPixels: Int = ExportGeometry.defaultMaxPixels)
  public var effectiveMaxEdge: Int
  public func size(longEdge: Int, aspect: ExportAspect) -> ExportSize
  public func clampedLongEdge(_ longEdge: Int) -> Int
}

// VisualCoreRendering
public struct StillImage: Sendable, Equatable {
  public let width: Int; public let height: Int; public let rgba: [UInt8]   // top-down rows
  public init?(width: Int, height: Int, topDownRGBA: [UInt8]); public init?(width: Int, height: Int, bottomUpRGBA: [UInt8])
  public func pixel(x: Int, y: Int) -> SIMD4<UInt8>
}
public enum OffscreenRenderError: Error, Equatable, Sendable {
  case unavailable(String), invalidSize(width: Int, height: Int, max: Int), resource(String), scene(String), readback, encoding
}
public enum StillImageEncoder { public static func pngData(_ image: StillImage) throws(OffscreenRenderError) -> Data }
extension RenderCapabilities { public var maxRenderbufferSize: Int }
extension RenderHost {
  public var maxRenderSize: Int                     // 0 before a context exists
  public func renderOffscreen(width: Int, height: Int, time: Double) throws(OffscreenRenderError) -> StillImage
}
```

App UI identifiers:
- `gas.export` (scene toolbar), `gas.export.sheet`;
- `gas.export.size` (picker; the value is the long edge, for example "2048 px"), `gas.export.aspect` (picker);
- `gas.export.dimensions` (label "W × H px"), `gas.export.format` ("Opaque · sRGB"), `gas.export.preview` (crop
  frame);
- `gas.export.run`, `gas.export.progress`, `gas.export.share`, `gas.export.error`, `gas.export.done`.
