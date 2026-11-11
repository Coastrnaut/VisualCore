// EffectRenderer.swift — runs a validated effect graph on pooled targets (feature 005; FR-F402–FR-F408,
// FR-F411). Contract: specs/005-effects-graph/contracts/effects-api.md.
import CVisualCoreGL
import VisualCoreEffectsGraph
import VisualCoreRendering

@MainActor
public final class EffectRenderer {
    public let graph: EffectGraphDescription
    public let quotaBytes: Int
    let registry: ResourceRegistry
    /// Passes that failed to build or run this generation; they pass their first input through.
    public private(set) var failedPasses: Set<String> = []
    /// Execution order of the last frame (tests, diagnostics).
    public private(set) var lastOrder: [String] = []
    public private(set) var lastWarnings: [String] = []
    /// Test hook: passes forced to fail at build time (fault injection, T-F413).
    var injectedFailures: Set<String> = []

    private var runners: [String: EffectPassRunner] = [:]
    private var fallback: CopyPass?
    private var generation = -1
    private var heldTargets: [RenderTarget] = []

    /// Validates the graph structure before any GPU work (throws `EffectGraphError`).
    public init(graph: EffectGraphDescription, registry: ResourceRegistry, quotaBytes: Int = EffectGraphValidator.defaultQuota) throws {
        _ = try EffectGraphValidator.validate(graph, width: 1, height: 1, quotaBytes: Int.max)
        self.graph = graph
        self.registry = registry
        self.quotaBytes = quotaBytes
    }

    /// Drops GPU state (programs, histories); the next frame rebuilds it. Called on resize/recreation.
    public func invalidate() {
        releaseHeld()
        // Objects of an ended context died with it; release only same-generation ones.
        if generation == registry.generation { for runner in runners.values { runner.release(registry) } }
        runners.removeAll()
        fallback = nil
        failedPasses.removeAll()
        generation = -1
    }

    /// Renders the graph over `scene` and returns its output target, valid until the next call.
    public func render(scene: RenderTarget, time: Double, delta: Double) throws -> RenderTarget {
        releaseHeld()
        if registry.generation != generation { invalidate(); generation = registry.generation }
        let validated = try EffectGraphValidator.validate(graph, width: scene.width, height: scene.height, quotaBytes: quotaBytes)
        lastOrder = validated.order
        lastWarnings = validated.warnings
        var outputs: [String: RenderTarget] = [effectSceneSource: scene]
        for id in validated.order {
            guard let pass = graph.passes.first(where: { $0.id == id }) else { continue }
            let width = max(1, Int((Double(scene.width) * pass.scale).rounded()))
            let height = max(1, Int((Double(scene.height) * pass.scale).rounded()))
            let params = validated.parameters[id] ?? [:]
            let format: TextureFormat = pass.type == "bloom" && (params["hdr"]?.first ?? 0) >= 0.5 ? .rgba16f : .rgba8
            let target = try registry.acquireTarget(width: width, height: height, format: format)
            heldTargets.append(target)
            var inputs: [String: RenderTarget] = [:]
            for (slot, source) in pass.inputs { inputs[slot] = outputs[source] }
            let io = PassIO(inputs: inputs, output: target, params: params, time: time, delta: delta, registry: registry)
            if let runner = runner(for: pass) {
                do { try runner.run(io) } catch { fail(pass.id, error) ; try passThrough(io) }
            } else {
                try passThrough(io)
            }
            outputs[pass.output] = target
        }
        guard let result = outputs[graph.output] else { throw EffectGraphError.missingOutput(graph.output) }
        return result
    }

    private func runner(for pass: EffectPassDescription) -> EffectPassRunner? {
        if failedPasses.contains(pass.id) { return nil }
        if let r = runners[pass.id] { return r }
        do {
            if injectedFailures.contains(pass.id) { throw ShaderError.compile([]) }
            let r = try EffectRenderer.makeRunner(type: pass.type, registry: registry)
            runners[pass.id] = r
            return r
        } catch {
            fail(pass.id, error)
            return nil
        }
    }

    static func makeRunner(type: String, registry: ResourceRegistry) throws -> EffectPassRunner {
        switch type {
        case "copy": return try CopyPass(registry: registry)
        case "colorMatrix": return try ColorMatrixPass(registry: registry)
        case "blur": return try BlurPass(registry: registry)
        case "bloom": return try BloomPass(registry: registry)
        case "distort": return try DistortPass(registry: registry)
        case "composite": return try CompositePass(registry: registry)
        case "feedback": return try FeedbackPass(registry: registry)
        default: throw EffectGraphError.unknownType(type, pass: "")
        }
    }

    /// FR-F408: reported once per pass and generation.
    private func fail(_ id: String, _ error: Error) {
        guard failedPasses.insert(id).inserted else { return }
        _ = registry.warn("effect pass \(id) failed: \(error); passing its input through")
    }

    private func passThrough(_ io: PassIO) throws {
        if fallback == nil { fallback = try CopyPass(registry: registry) }
        try fallback?.run(io)
    }

    private func releaseHeld() {
        for t in heldTargets { registry.recycle(t) }
        heldTargets.removeAll()
    }
}
