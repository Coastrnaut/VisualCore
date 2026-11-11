// GPUObjects.swift — textures, buffers and render targets owned by a ResourceRegistry
// (feature 004 T-F313; FR-F308, FR-F313). Every object carries the generation that created it;
// use after a context recreation is rejected and counted (FR-F310).
import CVisualCoreGL
import VisualCoreDiagnostics

public enum TextureFormat: Sendable, Equatable {
    case rgba8, rgba16f, r8

    public var bytesPerPixel: Int {
        switch self { case .rgba8: 4; case .rgba16f: 8; case .r8: 1 }
    }
    var gl: (internal: GLint, format: GLenum, type: GLenum) {
        switch self {
        case .rgba8: (GLint(GL_RGBA8), GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE))
        case .rgba16f: (GLint(GL_RGBA16F), GLenum(GL_RGBA), GLenum(GL_HALF_FLOAT))
        case .r8: (GLint(GL_R8), GLenum(GL_RED), GLenum(GL_UNSIGNED_BYTE))
        }
    }
}

public enum ResourceError: Error, Equatable, Sendable {
    /// Zero or larger than the context's maximum texture size (FR-F313).
    case invalidSize(width: Int, height: Int, max: Int)
    /// The render target framebuffer is incomplete (GL status code).
    case incompleteFramebuffer(UInt32)
}

/// Bookkeeping shared by every registry object.
public struct GPUHandle: Sendable, Equatable {
    public let kind: ResourceKind
    public let name: UInt32
    public let bytes: Int
    public let generation: Int
    public let label: String
}

@MainActor
public protocol GPUResource: AnyObject {
    var handle: GPUHandle { get }
}

@MainActor
public final class Texture: GPUResource {
    public let handle: GPUHandle
    public let width: Int, height: Int
    public let format: TextureFormat
    weak var registry: ResourceRegistry?
    var released = false

    init(handle: GPUHandle, width: Int, height: Int, format: TextureFormat, registry: ResourceRegistry) {
        self.handle = handle; self.width = width; self.height = height; self.format = format; self.registry = registry
    }

    /// Binds to a texture unit; rejected (and counted) when stale or released.
    public func bind(unit: Int) {
        guard !released, let registry, registry.accept(generation: handle.generation) else { return }
        vcglActiveTexture(GLenum(GL_TEXTURE0 + Int32(unit)))
        vcglBindTexture(GLenum(GL_TEXTURE_2D), handle.name)
    }
}

@MainActor
public final class GPUBuffer: GPUResource {
    public let handle: GPUHandle
    weak var registry: ResourceRegistry?
    var released = false

    init(handle: GPUHandle, registry: ResourceRegistry) { self.handle = handle; self.registry = registry }

    public func bind(target: Int32 = GL_ARRAY_BUFFER) {
        guard !released, let registry, registry.accept(generation: handle.generation) else { return }
        vcglBindBuffer(GLenum(target), handle.name)
    }

    /// Uploads floats into the buffer (at most its allocated size).
    public func upload(_ values: [Float], target: Int32 = GL_ARRAY_BUFFER) {
        guard !released, let registry, registry.accept(generation: handle.generation) else { return }
        let count = min(values.count * MemoryLayout<Float>.size, handle.bytes)
        vcglBindBuffer(GLenum(target), handle.name)
        values.withUnsafeBytes { vcglBufferSubData(GLenum(target), 0, count, $0.baseAddress) }
    }
}

/// A framebuffer with one color texture; accounted as one `framebuffer` entry carrying the color bytes.
@MainActor
public final class RenderTarget: GPUResource {
    public let handle: GPUHandle
    public let colorTexture: GLuint
    public let width: Int, height: Int
    public let format: TextureFormat
    weak var registry: ResourceRegistry?
    var released = false

    init(handle: GPUHandle, colorTexture: GLuint, width: Int, height: Int, format: TextureFormat, registry: ResourceRegistry) {
        self.handle = handle; self.colorTexture = colorTexture; self.width = width; self.height = height
        self.format = format; self.registry = registry
    }

    /// Binds as the draw framebuffer (caller sets the viewport).
    public func bind() {
        guard !released, let registry, registry.accept(generation: handle.generation) else { return }
        vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), handle.name)
    }

    /// Binds the color texture for sampling.
    public func bindColor(unit: Int) {
        guard !released, let registry, registry.accept(generation: handle.generation) else { return }
        vcglActiveTexture(GLenum(GL_TEXTURE0 + Int32(unit)))
        vcglBindTexture(GLenum(GL_TEXTURE_2D), colorTexture)
    }

    /// RGBA8 readback of the color attachment, rows bottom-up (tests, exports).
    public func readPixels() -> [UInt8] {
        guard !released, let registry, registry.accept(generation: handle.generation) else { return [] }
        vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), handle.name)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        vcglReadPixels(0, 0, GLsizei(width), GLsizei(height), GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), &pixels)
        return vcglGetError() == GLenum(GL_NO_ERROR) ? pixels : []
    }
}
