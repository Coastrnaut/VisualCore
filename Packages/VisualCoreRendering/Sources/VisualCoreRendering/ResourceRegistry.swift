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
        ledger.abandonAll()
        willEndContext()
    }

    /// Called by the host once the new context exists.
    func contextDidStart(generation: Int) { self.generation = generation }

    /// Hook for caches (programs, pools) to drop GL names of the ending context.
    var willEndContext: () -> Void = {}

    func warn(_ message: String) -> Bool { ledger.warn(message) }

    // MARK: Programs (FR-F301–FR-F307)

    /// Expands, compiles and links a program. A failure throws diagnostics and never touches any
    /// program the caller already holds (FR-F305).
    public func program(vertex: String, fragment: String, defines: [String: String] = [:],
                        library: ShaderLibrary = ShaderLibrary()) throws -> ShaderProgram {
        let v: ExpandedShader, f: ExpandedShader
        do {
            v = try library.expand(source: vertex, named: "vertex", defines: defines)
            f = try library.expand(source: fragment, named: "fragment", defines: defines)
        } catch {
            ledger.noteShaderFailure()
            throw ShaderError.source(error)
        }
        let key = ShaderCacheKey.make(vertex: v, fragment: f)
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
        return ShaderProgram(name: name, generation: generation, cacheKey: key, registry: self)
    }

    /// Deletes a program created by this registry (no-op if stale or already released).
    public func release(_ program: ShaderProgram) {
        guard !program.released else { return }
        program.released = true
        guard accept(generation: program.generation) else { return }
        vcglDeleteProgram(program.name)
        ledger.release(.program, bytes: 0)
    }
}
