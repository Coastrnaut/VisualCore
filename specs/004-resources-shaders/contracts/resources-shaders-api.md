# Contract: resource and shader services API (Phase 3)

```swift
// VisualCoreShaderSource (pure)
public struct ShaderLibrary { public init(); public mutating func add(_ name: String, _ text: String)
  public func expand(_ name: String, defines: [String: String] = [:]) throws -> ExpandedShader }   // FR-F301–F303, F317
public struct ExpandedShader { public let text: String; public func origin(ofExpandedLine: Int) -> (file: String, line: Int) }
public enum InfoLogParser { public static func parse(_ log: String, stage: ShaderStage, map: ExpandedShader?) -> [ShaderDiagnostic] }

// VisualCoreDiagnostics (pure)
public struct ResourceLedger { public mutating func allocate(_ kind: ResourceKind, bytes: Int) throws  // over budget → throws
  public mutating func release(_ kind: ResourceKind, bytes: Int); public mutating func noteStale(); public var snapshot: ... }

// VisualCoreRendering (main thread, one registry per RenderHost, via RenderContext.resources)
@MainActor public final class ResourceRegistry {
  public func makeTexture(width: Int, height: Int, format: TextureFormat = .rgba8, label: String) throws -> Texture
  public func makeBuffer(bytes: Int, label: String) throws -> GPUBuffer
  public func makeRenderTarget(width: Int, height: Int, label: String) throws -> RenderTarget
  public func program(vertex: String, fragment: String, defines: [String: String] = [:], library: ShaderLibrary = .init()) throws -> ShaderProgram
  public func release(_ handle: some GPUResource)
  public var stats: ResourceLedger.Snapshot { get }
  public func trimPools()
}
public enum ShaderError: Error { case source(ShaderSourceError), compile([ShaderDiagnostic]), link([ShaderDiagnostic]) }
```

Additional public members (converge pass 1):

```swift
public enum ShaderCacheKey { static func make(vertex:fragment:) -> String; static func sha256Hex(_:) -> String }
public enum TextureFormat { case rgba8, rgba16f, r8; var bytesPerPixel: Int }
public enum ResourceError: Error { case invalidSize(width:height:max:), incompleteFramebuffer(UInt32) }
public struct GPUHandle { kind, name, bytes, generation, label }   // every Texture/GPUBuffer/RenderTarget/ShaderProgram carries one or its fields
Texture.bind(unit:) · GPUBuffer.bind(target:), upload(_:target:) · RenderTarget.bind(), bindColor(unit:), readPixels(), colorTexture
ResourceRegistry.acquireTarget(width:height:format:) / recycle(_:)      // pool, freed by trimPools() and on memory warnings
ResourceRegistry.compileCount, cacheHits, cachedProgramCount, maxCachedPrograms (64), budget
ShaderProgram.set(_:Float|SIMD2|SIMD3|SIMD4|Int32), set(_:matrix4:), uniforms, generation, cacheKey, lastFailureLog (static)
RenderHost(scene:maxFramesPerSecond:budget:), RenderHost.resources
```

`RenderContext` gains `public let resources: ResourceRegistry` and is no longer `Sendable` (main-thread callbacks only; analyze I1, 2026-11-10).

Errors and limits per `specs/002-architecture-contracts/contracts/resources-shaders-errors.md`.
