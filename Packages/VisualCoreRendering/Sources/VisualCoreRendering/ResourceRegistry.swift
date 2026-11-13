// ResourceRegistry.swift — one per RenderHost: creates and tracks GPU objects against budgets,
// rejects stale generations and reports leaks (feature 004 T-F311/T-F313/T-F315; FR-F305–FR-F313,
// FR-F316). Contract: specs/004-resources-shaders/contracts/resources-shaders-api.md.
import CVisualCoreGL
import VisualCoreDiagnostics
import VisualCoreShaderSource

/// Creates and tracks one host's GPU objects on the main thread against budgets, rejects stale context generations and reports leaks.
@MainActor
public final class ResourceRegistry {
    /// Current context generation; objects from other generations are rejected and counted as stale.
    public private(set) var generation: Int
    private var ledger: ResourceLedger
    /// Byte budgets (total and per kind) enforced on allocation.
    public var budget: ResourceBudget { ledger.budget }
    /// Snapshot of live counts, bytes, peaks, stale rejections, leaks and warnings.
    public var stats: ResourceLedger.Snapshot { ledger.snapshot }

    init(budget: ResourceBudget, generation: Int) {
        ledger = ResourceLedger(budget: budget)
        self.generation = generation
    }

    // MARK: Generations (FR-F310, FR-F316)

    /// True when `handleGeneration` is current; otherwise counts a stale rejection.
    func accept(generation handleGeneration: Int) -> Bool {
        guard handleGeneration == generation else {
            ledger.noteStale()
            return false
        }
        return true
    }

    /// Counts a refused use of a resource that is no longer valid (a released program in a pipeline, R02-F04).
    func noteStale() { ledger.noteStale() }

    /// Called by the host after scene teardown and before the old context is destroyed: anything
    /// still live is counted as leaked and forgotten (no GL calls on a dead context).
    func contextWillEnd() {
        // Registry-owned objects are released properly while the old context is still current.
        trimPools()
        for program in cache.values { release(program) }
        cache.removeAll()
        lru.removeAll()
        // Evicted programs still held by scenes are registry-owned: released here, not counted as leaks (FR-R02F04-011).
        for program in retired.values { release(program) }
        retired.removeAll()
        willEndContext()
        ledger.abandonAll()   // anything still live belongs to a scene that leaked it
    }

    /// Called by the host once the new context exists.
    func contextDidStart(generation: Int) { self.generation = generation }

    /// Half-float support detected for a generation (FloatRenderSupport.detect, feature 019).
    var floatSupportCache: (generation: Int, value: FloatRenderSupport)?

    /// Hook for caches (programs, pools) to drop GL names of the ending context.
    var willEndContext: () -> Void = {}

    /// Records a deduplicated warning in the ledger (shown in diagnostics); returns true when new.
    @discardableResult
    public func warn(_ message: String) -> Bool { ledger.warn(message) }

    // MARK: Textures, buffers, render targets (FR-F308, FR-F313)

    /// The context's maximum texture edge in pixels (GL_MAX_TEXTURE_SIZE), set by the host from its capabilities.
    /// Scenes size their own targets (for example simulation grids) within it; larger targets are refused.
    public internal(set) var maxTextureSize = 4096

    private func validate(_ width: Int, _ height: Int) throws(ResourceError) {
        guard width > 0, height > 0, width <= maxTextureSize, height <= maxTextureSize else {
            throw .invalidSize(width: width, height: height, max: maxTextureSize)
        }
    }

    /// Creates a width×height texture (pixels), charging width×height×bytesPerPixel; throws on invalid size or over budget.
    public func makeTexture(width: Int, height: Int, format: TextureFormat = .rgba8, label: String) throws -> Texture {
        try validate(width, height)
        let bytes = width * height * format.bytesPerPixel
        try ledger.allocate(.texture, bytes: bytes)
        let name = Self.allocateTexture(width: width, height: height, format: format)
        return Texture(handle: GPUHandle(kind: .texture, name: name, bytes: bytes, generation: generation, label: label),
                       width: width, height: height, format: format, registry: self)
    }

    /// Creates a dynamic GL buffer of `bytes`, charged to the budget; throws when over budget.
    public func makeBuffer(bytes: Int, label: String) throws -> GPUBuffer {
        try ledger.allocate(.buffer, bytes: bytes)
        var name: GLuint = 0
        vcglGenBuffers(1, &name)
        vcglBindBuffer(GLenum(GL_ARRAY_BUFFER), name)
        vcglBufferData(GLenum(GL_ARRAY_BUFFER), bytes, nil, GLenum(GL_DYNAMIC_DRAW))
        return GPUBuffer(handle: GPUHandle(kind: .buffer, name: name, bytes: bytes, generation: generation, label: label), registry: self)
    }

    /// Creates a framebuffer with one color texture (pixels), charged as a framebuffer entry; throws on invalid size,
    /// over budget or an incomplete framebuffer. With `depth` (feature 204, FR-R02F04-030…032) the target also gets a
    /// `GL_DEPTH_COMPONENT24` renderbuffer of the same size, charged as one `.renderbuffer` entry of width×height×4
    /// bytes and released with the target. Every failure leaves nothing allocated: budgets are checked before any GL
    /// object exists, and an incomplete framebuffer deletes the texture, renderbuffer and framebuffer before throwing.
    public func makeRenderTarget(width: Int, height: Int, format: TextureFormat = .rgba8, depth: Bool = false,
                                 label: String) throws -> RenderTarget {
        try validate(width, height)
        let bytes = width * height * format.bytesPerPixel
        let depthBytes = depth ? RenderTarget.depthBytes(width: width, height: height) : 0
        try ledger.allocate(.framebuffer, bytes: bytes)
        if depth {
            do { try ledger.allocate(.renderbuffer, bytes: depthBytes) } catch {
                ledger.release(.framebuffer, bytes: bytes)
                throw error
            }
        }
        let texture = Self.allocateTexture(width: width, height: height, format: format)
        var renderbuffer: GLuint = 0
        if depth {
            vcglGenRenderbuffers(1, &renderbuffer)
            vcglBindRenderbuffer(GLenum(GL_RENDERBUFFER), renderbuffer)
            vcglRenderbufferStorage(GLenum(GL_RENDERBUFFER), GLenum(GL_DEPTH_COMPONENT24), GLsizei(width), GLsizei(height))
            vcglBindRenderbuffer(GLenum(GL_RENDERBUFFER), 0)
        }
        var framebuffer: GLuint = 0
        vcglGenFramebuffers(1, &framebuffer)
        vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), framebuffer)
        vcglFramebufferTexture2D(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_TEXTURE_2D), texture, 0)
        if depth {
            vcglFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_DEPTH_ATTACHMENT), GLenum(GL_RENDERBUFFER), renderbuffer)
        }
        let status = vcglCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER))
        guard status == GLenum(GL_FRAMEBUFFER_COMPLETE) else {
            vcglDeleteFramebuffers(1, &framebuffer)
            var t = texture
            vcglDeleteTextures(1, &t)
            ledger.release(.framebuffer, bytes: bytes)
            if depth {
                vcglDeleteRenderbuffers(1, &renderbuffer)
                ledger.release(.renderbuffer, bytes: depthBytes)
            }
            throw ResourceError.incompleteFramebuffer(status)
        }
        return RenderTarget(handle: GPUHandle(kind: .framebuffer, name: framebuffer, bytes: bytes, generation: generation, label: label),
                            colorTexture: texture, depthRenderbuffer: renderbuffer, width: width, height: height, format: format,
                            registry: self)
    }

    private static func allocateTexture(width: Int, height: Int, format: TextureFormat) -> GLuint {
        var name: GLuint = 0
        vcglGenTextures(1, &name)
        vcglBindTexture(GLenum(GL_TEXTURE_2D), name)
        let f = format.gl
        vcglTexImage2D(GLenum(GL_TEXTURE_2D), 0, f.internal, GLsizei(width), GLsizei(height), 0, f.format, f.type, nil)
        vcglTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        vcglTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        vcglTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
        vcglTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
        return name
    }

    /// Releases a texture, buffer or render target. Stale or already released objects are ignored
    /// (their GL names died with the old context).
    public func release(_ resource: some GPUResource) {
        switch resource {
        case let t as Texture:
            guard !t.released else { return }
            t.released = true
            guard accept(generation: t.handle.generation) else { return }
            var name = t.handle.name
            vcglDeleteTextures(1, &name)
        case let b as GPUBuffer:
            guard !b.released else { return }
            b.released = true
            guard accept(generation: b.handle.generation) else { return }
            var name = b.handle.name
            vcglDeleteBuffers(1, &name)
        case let r as RenderTarget:
            guard !r.released else { return }
            r.released = true
            guard accept(generation: r.handle.generation) else { return }
            var fb = r.handle.name, tex = r.colorTexture
            vcglDeleteFramebuffers(1, &fb)
            vcglDeleteTextures(1, &tex)
            if r.depthRenderbuffer != 0 {
                var rb = r.depthRenderbuffer
                vcglDeleteRenderbuffers(1, &rb)
                ledger.release(.renderbuffer, bytes: RenderTarget.depthBytes(width: r.width, height: r.height))
            }
        default:
            return
        }
        ledger.release(resource.handle.kind, bytes: resource.handle.bytes)
    }

    // MARK: Render-target pool (FR-F312)

    /// Pool key: size, format and whether the target has depth storage (FR-R02F04-033).
    private struct PoolKey: Hashable { let width: Int, height: Int, format: String, depth: Bool }
    private var pool: [PoolKey: [RenderTarget]] = [:]

    /// A pooled target of this size, format and depth option (reused when one is free); targets with and without
    /// depth storage are never interchanged (feature 204, FR-R02F04-033).
    public func acquireTarget(width: Int, height: Int, format: TextureFormat = .rgba8, depth: Bool = false) throws -> RenderTarget {
        let key = PoolKey(width: width, height: height, format: "\(format)", depth: depth)
        if var free = pool[key], let target = free.popLast() {
            pool[key] = free
            return target
        }
        return try makeRenderTarget(width: width, height: height, format: format, depth: depth,
                                    label: depth ? "pool \(width)x\(height) depth" : "pool \(width)x\(height)")
    }

    /// Returns a target to the pool for reuse (under its size, format and depth option).
    public func recycle(_ target: RenderTarget) {
        guard !target.released, target.handle.generation == generation else { return }
        let key = PoolKey(width: target.width, height: target.height, format: "\(target.format)", depth: target.depthRenderbuffer != 0)
        pool[key, default: []].append(target)
    }

    /// Frees every pooled (unused) target, e.g. on a memory warning.
    public func trimPools() {
        let free = pool.values.flatMap { $0 }
        pool.removeAll()
        for target in free { release(target) }
    }

    // MARK: Programs (FR-F301–FR-F307)

    /// Expands, compiles and links a program. A failure throws diagnostics and never touches any
    /// program the caller already holds (FR-F305).
    /// `vertexName`/`fragmentName` label diagnostics (e.g. bundled file names, feature 007 T-F605).
    public func program(vertex: String, fragment: String, defines: [String: String] = [:],
                        library: ShaderLibrary = ShaderLibrary(),
                        vertexName: String = "vertex", fragmentName: String = "fragment") throws -> ShaderProgram {
        let v: ExpandedShader, f: ExpandedShader
        do {
            v = try library.expand(source: vertex, named: vertexName, defines: defines)
            f = try library.expand(source: fragment, named: fragmentName, defines: defines)
        } catch {
            ledger.noteShaderFailure()
            throw ShaderError.source(error)
        }
        let key = ShaderCacheKey.make(vertex: v, fragment: f)
        if let cached = cache[key], !cached.released {
            cacheHits += 1
            touch(key)
            return cached
        }
        compileCount += 1
        let (vs, vDiag) = ShaderProgram.compileShader(GLenum(GL_VERTEX_SHADER), v, stage: .vertex)
        try ledger.allocate(.shader, bytes: 0)
        let (fs, fDiag) = ShaderProgram.compileShader(GLenum(GL_FRAGMENT_SHADER), f, stage: .fragment)
        try ledger.allocate(.shader, bytes: 0)
        defer {
            vcglDeleteShader(vs); ledger.release(.shader, bytes: 0)
            vcglDeleteShader(fs); ledger.release(.shader, bytes: 0)
        }
        if !vDiag.isEmpty || !fDiag.isEmpty {
            ledger.noteShaderFailure()
            throw ShaderError.compile(vDiag + fDiag)
        }
        let name = vcglCreateProgram()
        vcglAttachShader(name, vs)
        vcglAttachShader(name, fs)
        vcglLinkProgram(name)
        let linkDiag = ShaderProgram.linkLog(name)
        guard linkDiag.isEmpty else {
            vcglDeleteProgram(name)
            ledger.noteShaderFailure()
            throw ShaderError.link(linkDiag)
        }
        vcglDetachShader(name, vs)
        vcglDetachShader(name, fs)
        try ledger.allocate(.program, bytes: 0)
        let program = ShaderProgram(name: name, generation: generation, cacheKey: key, registry: self)
        cache[key] = program
        touch(key)
        if cache.count > Self.maxCachedPrograms, let oldest = lru.first {
            // Eviction retires the program without deleting it: a holder may still draw with it (FR-R02F04-010).
            lru.removeFirst()
            if let evicted = cache.removeValue(forKey: oldest) {
                retired[ObjectIdentifier(evicted)] = evicted
                evictionCount += 1
            }
        }
        return program
    }

    // MARK: Program cache (FR-F306)

    /// Maximum cached programs; beyond this the least recently used leaves the cache and is retired (feature 204).
    public static let maxCachedPrograms = 64
    private var cache: [String: ShaderProgram] = [:]
    private var lru: [String] = []
    /// Programs evicted from the cache but not yet released: alive until their holder releases them or the context
    /// ends (feature 204, FR-R02F04-010/011). No reference counting; a later request for the variant compiles anew.
    private var retired: [ObjectIdentifier: ShaderProgram] = [:]
    /// Programs evicted from the cache since the registry was created (FR-R02F04-013).
    public private(set) var evictionCount = 0
    /// Evicted programs still alive because their holder has not released them yet (FR-R02F04-010).
    public var retiredProgramCount: Int { retired.count }
    /// Programs actually compiled and linked, and requests served from the cache.
    public private(set) var compileCount = 0
    /// Program requests served from the cache instead of compiling.
    public private(set) var cacheHits = 0
    /// Programs currently held in the cache.
    public var cachedProgramCount: Int { cache.count }

    private func touch(_ key: String) {
        lru.removeAll { $0 == key }
        lru.append(key)
    }

    /// Deletes a program created by this registry, cached or retired (no-op if stale or already released).
    public func release(_ program: ShaderProgram) {
        guard !program.released else { return }
        program.released = true
        if cache[program.cacheKey] === program {
            cache[program.cacheKey] = nil
            lru.removeAll { $0 == program.cacheKey }
        }
        retired.removeValue(forKey: ObjectIdentifier(program))
        guard accept(generation: program.generation) else { return }
        vcglDeleteProgram(program.name)
        ledger.release(.program, bytes: 0)
    }
}
