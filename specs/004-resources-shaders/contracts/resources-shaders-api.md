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

`RenderContext` gains `public let resources: ResourceRegistry` and is no longer `Sendable` (main-thread callbacks only; analyze I1, 2026-11-10).

Errors and limits per `specs/002-architecture-contracts/contracts/resources-shaders-errors.md`.
