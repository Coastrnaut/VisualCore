# Contract: Phase 01 public API additions and app screens

```swift
// VisualCoreParameters (pure)
public enum ParameterTransform: String, Codable, Sendable { case linear, logarithmic }
public struct ParameterDefinition: Codable, Equatable, Sendable { name, title, unit, range, defaultValue, transform
  public init(name:title:unit:range:defaultValue:transform:) throws(ParameterError)
  public func normalized(_ v: Double) -> Double; public func value(normalized: Double) -> Double }
public struct ParameterSchema: Sendable, Equatable { public init(_ definitions: [ParameterDefinition]) throws(ParameterError)
  public var definitions: [ParameterDefinition]; public func resolve(_ values: [String: Double]) throws(ParameterError) -> ResolvedParameters }
public struct ResolvedParameters: Sendable, Equatable { public let values: [String: Double]; public let warnings: [String] }
public enum ParameterError: Error, Equatable, Sendable { case invalidName(String), duplicate(String), invalidRange(String),
  defaultOutOfRange(String), tooMany(Int), nonFinite(String), invalidPalette(String) }
public struct Palette: Codable, Equatable, Sendable, Identifiable { id, name, stops
  public init(id:name:stops:) throws(ParameterError); public var linearStops: [SIMD3<Double>]; public func sample(_ t: Double) -> SIMD3<Double>
  public static let builtIns: [Palette] }
public struct Preset: Codable, Equatable, Sendable, Identifiable { id, title, seed, paletteID, values }
public enum ParameterHash { public static func of(scope: String, seed: UInt64, paletteID: String, values: [String: Double]) -> String }

// VisualCoreRendering (iOS)
public final class ShaderBundle { public init(bundle: Bundle, subdirectory: String? = nil)
  public let library: ShaderLibrary; public func source(_ name: String) -> String?; public var names: [String] }
public final class FullScreenShaderScene: RenderScene { public init(fragment: String, fragmentName: String, bundle: ShaderBundle)
  public var parameters: [String: Double]; public var palette: [SIMD3<Float>]; public var seedOffsets: SIMD4<Float>
  public var fixedTime: Double?; public private(set) var errorMessage: String? }
extension ShaderProgram { public func set(_ name: String, vec3Array: [SIMD3<Float>]) }

// VisualCoreUI (iOS)
public struct RenderSurface: UIViewRepresentable { public init(host: RenderHost, accessibilityLabel: String, accessibilityHint: String? = nil) }

// VisualCoreTestSupport (tests only)
public struct ImageDifference { meanAbsolute, maxAbsolute; public func fractionWithin(_ tolerance: Int) -> Double }
public enum ImageComparison { public static func compare(_ a: [UInt8], _ b: [UInt8]) -> ImageDifference }
public enum ImageStatistics { public static func meanLuminance(_ rgba: [UInt8]) -> Double; public static func distinctColors(_ rgba: [UInt8]) -> Int }
```

App UI (accessibility identifiers):
- `gas.gallery` list;
- `gas.family.<id>` rows (label = title, hint = summary);
- `gas.scene.canvas` (label = family accessibility description);
- `gas.scene.error` (shader error text);
- `gas.scene.title`.
