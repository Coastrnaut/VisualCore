// DynamicVertexBuffer.swift — a registry-accounted vertex buffer that grows as needed and is rebuilt
// after context recreation (feature 006 T-F513; FR-F508). Used by the primitive and particle renderers.
import CVisualCoreGL

@MainActor
final class DynamicVertexBuffer {
    let registry: ResourceRegistry
    let label: String
    private(set) var buffer: GPUBuffer?
    private var capacity = 0

    init(registry: ResourceRegistry, label: String) { self.registry = registry; self.label = label }

    /// Uploads `floats`, growing (×2) when needed, and leaves the buffer bound to GL_ARRAY_BUFFER.
    func upload(_ floats: [Float]) throws {
        let bytes = max(floats.count * MemoryLayout<Float>.size, 64)
        if let b = buffer, b.handle.generation != registry.generation { buffer = nil; capacity = 0 }   // died with the old context
        if buffer == nil || bytes > capacity {
            if let b = buffer { registry.release(b) }
            capacity = max(bytes, capacity * 2)
            buffer = try registry.makeBuffer(bytes: capacity, label: label)
        }
        buffer?.upload(floats)
    }

    func release() {
        if let b = buffer { registry.release(b) }
        buffer = nil
        capacity = 0
    }
}

/// Sets float vertex attribute `index` from the bound array buffer.
@MainActor
func vcAttribute(_ index: GLuint, components: GLint, strideFloats: Int, offsetFloats: Int, divisor: GLuint = 0) {
    vcglEnableVertexAttribArray(index)
    vcglVertexAttribPointer(index, components, GLenum(GL_FLOAT), GLboolean(GL_FALSE),
                            GLsizei(strideFloats * MemoryLayout<Float>.size),
                            UnsafeRawPointer(bitPattern: offsetFloats * MemoryLayout<Float>.size))
    vcglVertexAttribDivisor(index, divisor)
}
