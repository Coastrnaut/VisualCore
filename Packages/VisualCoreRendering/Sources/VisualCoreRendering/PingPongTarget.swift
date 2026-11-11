// PingPongTarget.swift — a read/write pair of equal render targets that swap roles each step (feature 019
// T-A02-104; gap G-PINGPONG). GPU simulations and feedback effects read the previous state and write the next one;
// a pass never samples the texture it writes (FieldPass enforces this; A02 Bounded GPU rule).
import VisualCoreDiagnostics

/// Two render targets of the same size and format: passes sample `read` and draw into `write`, then `swap()`.
@MainActor
public final class PingPongTarget {
    /// The target holding the current state; sample it.
    public private(set) var read: RenderTarget
    /// The target the next step draws into; never the same object as `read`.
    public private(set) var write: RenderTarget
    /// Size in pixels (cells).
    public let width: Int, height: Int
    /// Color format of both targets.
    public let format: TextureFormat
    /// Swaps since creation.
    public private(set) var swapCount = 0
    private weak var registry: ResourceRegistry?
    private var released = false

    /// Creates both targets (labels `<label>.a` and `<label>.b`), charged to the registry's framebuffer budget.
    /// If the second cannot be created, the first is released before the error is rethrown.
    public init(registry: ResourceRegistry, width: Int, height: Int, format: TextureFormat, label: String) throws {
        let a = try registry.makeRenderTarget(width: width, height: height, format: format, label: label + ".a")
        let b: RenderTarget
        do {
            b = try registry.makeRenderTarget(width: width, height: height, format: format, label: label + ".b")
        } catch {
            registry.release(a)
            throw error
        }
        read = a
        write = b
        self.width = width
        self.height = height
        self.format = format
        self.registry = registry
    }

    /// Bytes charged for both targets.
    public var bytes: Int { read.handle.bytes + write.handle.bytes }

    /// False once released, or after a context recreation (its GL objects died with the old context).
    public var isValid: Bool {
        guard !released, let registry else { return false }
        return read.handle.generation == registry.generation
    }

    /// Exchanges the roles: what was written becomes `read`. Ignored after `release()`.
    public func swap() {
        guard !released else { return }
        (read, write) = (write, read)
        swapCount += 1
    }

    /// Releases both targets (idempotent; stale targets are ignored by the registry).
    public func release() {
        guard !released else { return }
        released = true
        registry?.release(read)
        registry?.release(write)
    }
}
