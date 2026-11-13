# Public API contract: R02-F04 (additions; defaults keep existing callers unchanged)

```swift
// VisualCoreShaderSource
public struct RenderState: Hashable, Sendable {
    public enum BlendMode: Hashable, Sendable { case none, alpha, premultiplied, additive }
    public enum CullMode: Hashable, Sendable { case none, back, front }
    public struct ColorMask: Hashable, Sendable { public var red, green, blue, alpha: Bool; public static let all: ColorMask }
    public var blend: BlendMode; public var depthTest: Bool; public var depthWrite: Bool; public var cull: CullMode; public var colorMask: ColorMask
    public init(blend: BlendMode = .none, depthTest: Bool = false, depthWrite: Bool = false, cull: CullMode = .none, colorMask: ColorMask = .all)
    public static let opaque, alphaBlended, additive, opaque3D: RenderState
}
// VisualCoreRendering
public struct Pipeline: Hashable { public let program: ShaderProgram; public let state: RenderState; public init(program: ShaderProgram, state: RenderState) }
extension GLState { @MainActor @discardableResult public static func apply(_ pipeline: Pipeline, resources: ResourceRegistry) -> Bool }
extension ResourceRegistry {
    public func makeRenderTarget(width: Int, height: Int, format: TextureFormat = .rgba8, depth: Bool = false, label: String) throws -> RenderTarget
    public func acquireTarget(width: Int, height: Int, format: TextureFormat = .rgba8, depth: Bool = false) throws -> RenderTarget
    public private(set) var evictionCount: Int
    public var retiredProgramCount: Int { get }
}
extension RenderTarget { public let depthRenderbuffer: GLuint }   // stored property; 0 when the target has no depth
```
