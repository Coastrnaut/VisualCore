// GPUObjects.swift — textures, buffers and render targets owned by a ResourceRegistry
// (feature 004 T-F313; FR-F308, FR-F313). Every object carries the generation that created it;
// use after a context recreation is rejected and counted (FR-F310).
import CVisualCoreGL
import VisualCoreDiagnostics
import VisualCoreSimulation

/// Color formats for registry textures and render targets.
public enum TextureFormat: Sendable, Equatable {
    case rgba8, rgba16f, r8

    /// Bytes per pixel used for budget accounting (rgba8 4, rgba16f 8, r8 1).
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

/// Errors creating textures and render targets.
public enum ResourceError: Error, Equatable, Sendable {
    /// Zero or larger than the context's maximum texture size (FR-F313).
    case invalidSize(width: Int, height: Int, max: Int)
    /// The render target framebuffer is incomplete (GL status code).
    case incompleteFramebuffer(UInt32)
}

/// Bookkeeping shared by every registry object.
public struct GPUHandle: Sendable, Equatable {
    /// Which ledger category the object is accounted under.
    public let kind: ResourceKind
    /// The GL object name (texture, buffer or framebuffer id).
    public let name: UInt32
    /// Bytes charged to the registry's budget for this object.
    public let bytes: Int
    /// Context generation that created the object; use from another generation is rejected and counted as stale.
    public let generation: Int
    /// Diagnostic label shown in resource reports and leak lists.
    public let label: String
}

/// A GPU object created and accounted by a ResourceRegistry (main thread only).
@MainActor
public protocol GPUResource: AnyObject {
    var handle: GPUHandle { get }
}

/// A 2D texture owned by a ResourceRegistry; bound or uploaded only in its creating generation until released.
@MainActor
public final class Texture: GPUResource {
    /// Registry bookkeeping: GL name, accounted bytes, generation and label.
    public let handle: GPUHandle
    /// Size in pixels.
    public let width: Int, height: Int
    /// Pixel format, which determines the accounted bytes.
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

    /// Uploads tightly packed RGBA8 pixels, rows bottom-up (GL order), replacing the whole texture
    /// (feature 007 T-F603). Returns false for a non-rgba8 texture, a size mismatch or a stale/released texture.
    @discardableResult
    public func upload(rgba pixels: [UInt8]) -> Bool {
        guard format == .rgba8, pixels.count == width * height * 4,
              !released, let registry, registry.accept(generation: handle.generation) else { return false }
        vcglBindTexture(GLenum(GL_TEXTURE_2D), handle.name)
        vcglPixelStorei(GLenum(GL_UNPACK_ALIGNMENT), 1)
        pixels.withUnsafeBytes {
            vcglTexSubImage2D(GLenum(GL_TEXTURE_2D), 0, 0, 0, GLsizei(width), GLsizei(height),
                              GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), $0.baseAddress)
        }
        return vcglGetError() == GLenum(GL_NO_ERROR)
    }
}

/// A GL buffer of fixed byte size owned by a ResourceRegistry; operations are ignored when stale or released.
@MainActor
public final class GPUBuffer: GPUResource {
    /// Registry bookkeeping: GL name, allocated bytes, generation and label.
    public let handle: GPUHandle
    weak var registry: ResourceRegistry?
    var released = false

    init(handle: GPUHandle, registry: ResourceRegistry) { self.handle = handle; self.registry = registry }

    /// Binds to `target` (array buffer by default); rejected (and counted) when stale or released.
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

    /// Uploads 32-bit indices (at most the allocated size), e.g. into GL_ELEMENT_ARRAY_BUFFER (feature 006 T-F517).
    public func upload(indices: [UInt32], target: Int32 = GL_ELEMENT_ARRAY_BUFFER) {
        guard !released, let registry, registry.accept(generation: handle.generation) else { return }
        let count = min(indices.count * MemoryLayout<UInt32>.size, handle.bytes)
        vcglBindBuffer(GLenum(target), handle.name)
        indices.withUnsafeBytes { vcglBufferSubData(GLenum(target), 0, count, $0.baseAddress) }
    }
}

/// A framebuffer with one color texture; accounted as one `framebuffer` entry carrying the color bytes.
@MainActor
public final class RenderTarget: GPUResource {
    /// Registry bookkeeping: framebuffer name, accounted color bytes, generation and label.
    public let handle: GPUHandle
    /// GL name of the color attachment texture.
    public let colorTexture: GLuint
    /// Size in pixels.
    public let width: Int, height: Int
    /// Pixel format of the color attachment.
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

    /// Replaces the whole color texture with RGBA float values, rows bottom-up (feature 019; G-FLOATRT, research R4).
    /// `.rgba16f` uploads the floats (rounded to half precision by GL); `.rgba8` clamps each value to 0…1 and stores
    /// it as n/255. Returns false for `.r8`, a count other than width × height × 4, or a stale or released target.
    @discardableResult
    public func upload(rgbaFloats values: [Float]) -> Bool {
        guard format != .r8, values.count == width * height * 4,
              !released, let registry, registry.accept(generation: handle.generation) else { return false }
        vcglBindTexture(GLenum(GL_TEXTURE_2D), colorTexture)
        vcglPixelStorei(GLenum(GL_UNPACK_ALIGNMENT), 1)
        if format == .rgba16f {
            values.withUnsafeBytes {
                vcglTexSubImage2D(GLenum(GL_TEXTURE_2D), 0, 0, 0, GLsizei(width), GLsizei(height),
                                  GLenum(GL_RGBA), GLenum(GL_FLOAT), $0.baseAddress)
            }
        } else {
            let bytes = values.map { UInt8(StoragePrecision.unorm8.round($0) * 255) }
            bytes.withUnsafeBytes {
                vcglTexSubImage2D(GLenum(GL_TEXTURE_2D), 0, 0, 0, GLsizei(width), GLsizei(height),
                                  GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), $0.baseAddress)
            }
        }
        vcglPixelStorei(GLenum(GL_UNPACK_ALIGNMENT), 4)
        return vcglGetError() == GLenum(GL_NO_ERROR)
    }

    /// The color attachment as RGBA floats, rows bottom-up (feature 019): `.rgba16f` is read as GL floats, `.rgba8`
    /// as bytes divided by 255. Empty for `.r8`, a GL error, or a stale or released target. Leaves this target bound.
    public func readFloatPixels() -> [Float] {
        guard format != .r8, !released, let registry, registry.accept(generation: handle.generation) else { return [] }
        vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), handle.name)
        let count = width * height * 4
        if format == .rgba8 {
            var bytes = [UInt8](repeating: 0, count: count)
            vcglReadPixels(0, 0, GLsizei(width), GLsizei(height), GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), &bytes)
            return vcglGetError() == GLenum(GL_NO_ERROR) ? bytes.map { Float($0) / 255 } : []
        }
        var floats = [Float](repeating: 0, count: count)
        vcglReadPixels(0, 0, GLsizei(width), GLsizei(height), GLenum(GL_RGBA), GLenum(GL_FLOAT), &floats)
        return vcglGetError() == GLenum(GL_NO_ERROR) ? floats : []
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
