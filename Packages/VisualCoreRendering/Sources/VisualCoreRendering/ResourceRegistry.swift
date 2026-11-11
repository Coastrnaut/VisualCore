// ResourceRegistry.swift — one per RenderHost: creates and tracks GPU objects against budgets,
// rejects stale generations and reports leaks (feature 004 T-F311/T-F313/T-F315; FR-F305–FR-F313,
// FR-F316). Contract: specs/004-resources-shaders/contracts/resources-shaders-api.md.
import CVisualCoreGL
import VisualCoreDiagnostics
import VisualCoreShaderSource

@MainActor
public final class ResourceRegistry {
    public private(set) var generation: Int
    private var ledger: ResourceLedger
    public var budget: ResourceBudget { ledger.budget }
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

    /// Called by the host after scene teardown and before the old context is destroyed: anything
    /// still live is counted as leaked and forgotten (no GL calls on a dead context).
    func contextWillEnd() {
        // Registry-owned objects are released properly while the old context is still current.
        trimPools()
        for program in cache.values { release(program) }
        cache.removeAll()
        lru.removeAll()
        willEndContext()
        ledger.abandonAll()   // anything still live belongs to a scene that leaked it
    }

    /// Called by the host once the new context exists.
    func contextDidStart(generation: Int) { self.generation = generation }

    /// Hook for caches (programs, pools) to drop GL names of the ending context.
    var willEndContext: () -> Void = {}

    /// Records a deduplicated warning in the ledger (shown in diagnostics); returns true when new.
    @discardableResult
    public func warn(_ message: String) -> Bool { ledger.warn(message) }

    // MARK: Textures, buffers, render targets (FR-F308, FR-F313)

    /// Set by the host from its capabilities.
    var maxTextureSize = 4096

    private func validate(_ width: Int, _ height: Int) throws(ResourceError) {
        guard width > 0, height > 0, width <= maxTextureSize, height <= maxTextureSize else {
            throw .invalidSize(width: width, height: height, max: maxTextureSize)
        }
    }

    public func makeTexture(width: Int, height: Int, format: TextureFormat = .rgba8, label: String) throws -> Texture {
        try validate(width, height)
        let bytes = width * height * format.bytesPerPixel
        try ledger.allocate(.texture, bytes: bytes)
        let name = Self.allocateTexture(width: width, height: height, format: format)
        return Texture(handle: GPUHandle(kind: .texture, name: name, bytes: bytes, generation: generation, label: label),
                       width: width, height: height, format: format, registry: self)
    }

    public func makeBuffer(bytes: Int, label: String) throws -> GPUBuffer {
        try ledger.allocate(.buffer, bytes: bytes)
        var name: GLuint = 0
        vcglGenBuffers(1, &name)
        vcglBindBuffer(GLenum(GL_ARRAY_BUFFER), name)
        vcglBufferData(GLenum(GL_ARRAY_BUFFER), bytes, nil, GLenum(GL_DYNAMIC_DRAW))
        return GPUBuffer(handle: GPUHandle(kind: .buffer, name: name, bytes: bytes, generation: generation, label: label), registry: self)
    }

    public func makeRenderTarget(width: Int, height: Int, format: TextureFormat = .rgba8, label: String) throws -> RenderTarget {
        try validate(width, height)
        let bytes = width * height * format.bytesPerPixel
        try ledger.allocate(.framebuffer, bytes: bytes)
        let texture = Self.allocateTexture(width: width, height: height, format: format)
        var framebuffer: GLuint = 0
        vcglGenFramebuffers(1, &framebuffer)
        vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), framebuffer)
        vcglFramebufferTexture2D(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_TEXTURE_2D), texture, 0)
        let status = vcglCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER))
        guard status == GLenum(GL_FRAMEBUFFER_COMPLETE) else {
            vcglDeleteFramebuffers(1, &framebuffer)
            var t = texture
            vcglDeleteTextures(1, &t)
            ledger.release(.framebuffer, bytes: bytes)
            throw ResourceError.incompleteFramebuffer(status)
        }
        return RenderTarget(handle: GPUHandle(kind: .framebuffer, name: framebuffer, bytes: bytes, generation: generation, label: label),
                            colorTexture: texture, width: width, height: height, format: format, registry: self)
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
        default:
            return
        }
        ledger.release(resource.handle.kind, bytes: resource.handle.bytes)
    }

    // MARK: Render-target pool (FR-F312)

    private struct PoolKey: Hashable { let width: Int, height: Int, format: String }
    private var pool: [PoolKey: [RenderTarget]] = [:]

    /// A pooled target of this size and format (reused when one is free).
    public func acquireTarget(width: Int, height: Int, format: TextureFormat = .rgba8) throws -> RenderTarget {
        let key = PoolKey(width: width, height: height, format: "\(format)")
        if var free = pool[key], let target = free.popLast() {
            pool[key] = free
            return target
        }
        return try makeRenderTarget(width: width, height: height, format: format, label: "pool \(width)x\(height)")
    }

    /// Returns a target to the pool for reuse.
    public func recycle(_ target: RenderTarget) {
        guard !target.released, target.handle.generation == generation else { return }
        pool[PoolKey(width: target.width, height: target.height, format: "\(target.format)"), default: []].append(target)
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
            if let evicted = cache[oldest] { release(evicted) }
        }
        return program
    }

    // MARK: Program cache (FR-F306)

    public static let maxCachedPrograms = 64
    private var cache: [String: ShaderProgram] = [:]
    private var lru: [String] = []
    /// Programs actually compiled and linked, and requests served from the cache.
    public private(set) var compileCount = 0
    public private(set) var cacheHits = 0
    public var cachedProgramCount: Int { cache.count }

    private func touch(_ key: String) {
        lru.removeAll { $0 == key }
        lru.append(key)
    }

    /// Deletes a program created by this registry (no-op if stale or already released).
    public func release(_ program: ShaderProgram) {
        guard !program.released else { return }
        program.released = true
        if cache[program.cacheKey] === program {
            cache[program.cacheKey] = nil
            lru.removeAll { $0 == program.cacheKey }
        }
        guard accept(generation: program.generation) else { return }
        vcglDeleteProgram(program.name)
        ledger.release(.program, bytes: 0)
    }
}
