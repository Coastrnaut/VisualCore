// FluidFieldsScene.swift — velocity and dye fields in ping-pong pairs, faded by dissipation and shown on screen
// (feature 019 T-A02-110; FR-A02-103, FR-A02-104, FR-A02-106–FR-A02-108; contracts/app-fields.md).
// All GPU work goes through VisualCore (PingPongTarget, FieldPass, FloatRenderSupport); the app creates no EGL
// context. Context loss runs teardown then setup, which rebuilds both fields from the configuration.
import FluidArtPlaygroundCore
import VisualCoreRendering
import VisualCoreSimulation

/// Why the fields could not be built.
enum FluidSceneError: Error, Equatable {
    /// A seed could not be written to its field (`"velocity"` or `"dye"`).
    case seedUploadFailed(String)
}

@MainActor
final class FluidFieldsScene: RenderScene {
    /// The initial dye.
    enum SeedKind: Equatable {
        /// `DyeSeed.pattern(seed: configuration.seed)` (the canvas).
        case pattern
        /// Every cell the same color (the dissipation fixture).
        case uniform(SIMD4<Float>)
    }

    /// The configuration as requested; `configuration` holds the validated one once set up.
    let requested: FluidConfiguration
    let seed: SeedKind
    /// Use RGBA8 storage even when half-float targets work (tests of the fallback).
    let forceFallback: Bool
    /// An extra grid edge cap; the device's maximum texture size also applies at setup.
    let maxEdge: Int

    /// Test seam: writes a seed into a target (default `upload(rgbaFloats:)`).
    var uploadSeed: (RenderTarget, [Float]) -> Bool = { $0.upload(rgbaFloats: $1) }
    /// Test seam: the starting velocity (RGBA, cells per second, unencoded) instead of zero.
    var initialVelocityOverride: FieldGrid?
    /// Test seam: replaces the frame delta before it is clamped.
    var fixedDelta: Double?
    /// When true, frames show the dye without stepping.
    var paused = false

    /// The grid edge cap used by the last setup: `min(maxEdge, resources.maxTextureSize)` (FR-A02-101).
    private(set) var effectiveMaxEdge = 512
    private(set) var configuration: FluidConfiguration
    private(set) var issues: [ConfigurationIssue] = []
    private(set) var storage: TextureFormat?
    private(set) var stepCount = 0
    private(set) var setupCount = 0
    private(set) var rebuildCount = 0
    private(set) var lastStep: Double = 0
    private(set) var lastError: FieldPassError?
    private(set) var velocity: PingPongTarget?
    private(set) var dye: PingPongTarget?
    /// Splats applied since creation, and in the last frame (feature 020).
    private(set) var appliedSplats = 0
    private(set) var lastDrained = 0
    /// Splats waiting for the next stepped frame (CPU state; survives a context loss).
    private(set) var pendingSplats: [Splat] = []
    private var advect: FieldPass?
    private var splat: FieldPass?
    private var display: FieldPass?
    private var policy = TimeStepPolicy()

    init(configuration: FluidConfiguration = FluidConfiguration(), seed: SeedKind = .pattern,
         forceFallback: Bool = false, maxEdge: Int = 512) {
        requested = configuration
        self.seed = seed
        self.forceFallback = forceFallback
        self.maxEdge = maxEdge
        (self.configuration, issues) = configuration.validated(maxEdge: maxEdge)
    }

    /// The storage precision of both fields, once set up.
    var precision: StoragePrecision? {
        storage.map { $0 == .rgba16f ? .float16 : .unorm8 }
    }

    /// Velocity is stored in cells per second; RGBA8 storage encodes ±`velocityRange × 60` (spec 020 clarification 1).
    var velocityRangeCellsPerSecond: Float { Float(configuration.velocityRange * 60) }

    /// The encoding of stored velocity in RGBA8 storage (nil for half-float).
    var encoding: SignedRangeEncoding? {
        storage == .rgba8 ? SignedRangeEncoding.unorm8(range: velocityRangeCellsPerSecond) : nil
    }

    func setup(_ context: RenderContext) throws {
        if setupCount > 0 { rebuildCount += 1 }
        setupCount += 1
        stepCount = 0
        policy = TimeStepPolicy()
        let r = context.resources
        effectiveMaxEdge = min(maxEdge, r.maxTextureSize)
        (configuration, issues) = requested.validated(maxEdge: effectiveMaxEdge)
        let format = FloatRenderSupport.detect(in: r).storageFormat(forceFallback: forceFallback)
        storage = format
        let w = configuration.gridWidth, h = configuration.gridHeight
        do {
            let velocity = try PingPongTarget(registry: r, width: w, height: h, format: format, label: "fap.velocity")
            self.velocity = velocity
            let dye = try PingPongTarget(registry: r, width: w, height: h, format: format, label: "fap.dye")
            self.dye = dye
            advect = try FieldPass(registry: r, fragment: FluidShaders.advect, inputs: ["uVelocity", "uSource"], label: "fap.advect")
            splat = try FieldPass(registry: r, fragment: FluidShaders.splat, inputs: ["uField"], label: "fap.splat")
            display = try FieldPass(registry: r, fragment: FluidShaders.display, inputs: ["uDye"], label: "fap.display")
            guard uploadSeed(velocity.read, initialVelocity().values) else { throw FluidSceneError.seedUploadFailed("velocity") }
            guard uploadSeed(dye.read, initialDye().values) else { throw FluidSceneError.seedUploadFailed("dye") }
        } catch {
            releaseAll()
            throw error
        }
    }

    /// The dye at step 0, before storage rounding.
    func initialDye() -> FieldGrid {
        switch seed {
        case .pattern: DyeSeed.pattern(width: configuration.gridWidth, height: configuration.gridHeight, seed: configuration.seed)
        case .uniform(let rgba): DyeSeed.uniform(width: configuration.gridWidth, height: configuration.gridHeight, rgba: rgba)
        }
    }

    /// The velocity at step 0 as uploaded (RGBA; RG encoded for RGBA8 storage).
    func initialVelocity() -> FieldGrid {
        var v = initialVelocityOverride.flatMap { $0.width == configuration.gridWidth && $0.height == configuration.gridHeight ? $0.padded(toChannels: 4) : nil }
            ?? DyeSeed.zeroVelocity(width: configuration.gridWidth, height: configuration.gridHeight).padded(toChannels: 4)
        if let encoding {
            for i in v.values.indices where i % 4 < 2 { v.values[i] = encoding.encode(v.values[i]) }
        }
        return v
    }

    func resize(_ context: RenderContext) {}

    /// Queues splats for the next stepped frame (already capped by the app's SplatQueue).
    func enqueue(_ splats: [Splat]) { pendingSplats += splats }

    /// Called once at the start of every stepped frame for that frame's splats (the playground drains its capped
    /// SplatQueue here, so the per-frame cap is per rendered frame).
    var splatSource: (() -> [Splat])?

    private func applySplats(velocity: PingPongTarget, dye: PingPongTarget, splat: FieldPass) throws(FieldPassError) {
        let batch = pendingSplats
        pendingSplats.removeAll()
        lastDrained = batch.count
        let w = configuration.gridWidth, h = configuration.gridHeight
        for s in batch {
            let point = FieldUniform.vec2(s.center(width: w, height: h))
            let radius = FieldUniform.float(s.radiusCells(width: w, height: h))
            try splat.run(pair: velocity, input: "uField", uniforms: [
                "uPoint": point, "uRadius": radius, "uValue": .vec4(SIMD4(s.force.x, s.force.y, 0, 0)),
                "uEncoded": .int(storage == .rgba8 ? 1 : 0), "uRange": .float(velocityRangeCellsPerSecond),
                "uCenter": .float(encoding?.center ?? 0.5), "uVelocity": .int(1),
            ])
            try splat.run(pair: dye, input: "uField", uniforms: [
                "uPoint": point, "uRadius": radius, "uValue": .vec4(s.color),
                "uEncoded": .int(0), "uRange": .float(1), "uCenter": .float(0.5), "uVelocity": .int(0),
            ])
            appliedSplats += 1
        }
    }

    func render(_ context: RenderContext, frame: FrameInfo) throws {
        guard let velocity, let dye, let advect, let splat, let display else { return }
        do {
            if !paused {
                let dt = policy.clamp(fixedDelta ?? frame.delta)
                lastStep = dt
                if let splatSource { pendingSplats += splatSource() }
                try applySplats(velocity: velocity, dye: dye, splat: splat)
                let encoded = FieldUniform.int(storage == .rgba8 ? 1 : 0)
                let range = FieldUniform.float(velocityRangeCellsPerSecond)
                let center = FieldUniform.float(encoding?.center ?? 0.5)
                // Clarification 5: velocity advects itself, then dye moves with the advected velocity.
                try advect.run(pair: velocity, input: "uSource", extraInputs: ["uVelocity": velocity.read], uniforms: [
                    "uDt": .float(Float(dt)), "uFactor": .float(Dissipation.factor(d: configuration.velocityDissipation, dt: dt)),
                    "uEncodedVelocity": encoded, "uSourceIsVelocity": .int(1), "uRange": range, "uCenter": center,
                ])
                try advect.run(pair: dye, input: "uSource", extraInputs: ["uVelocity": velocity.read], uniforms: [
                    "uDt": .float(Float(dt)), "uFactor": .float(Dissipation.factor(d: configuration.dyeDissipation, dt: dt)),
                    "uEncodedVelocity": encoded, "uSourceIsVelocity": .int(0), "uRange": range, "uCenter": center,
                ])
                stepCount += 1
            }
            try display.run(output: .framebuffer(name: context.framebuffer, width: context.pixelWidth, height: context.pixelHeight),
                            inputs: ["uDye": dye.read])
        } catch {
            lastError = error
            throw error
        }
    }

    func teardown(_ context: RenderContext) { releaseAll() }

    private func releaseAll() {
        velocity?.release()
        dye?.release()
        advect?.release()
        splat?.release()
        display?.release()
        velocity = nil
        dye = nil
        advect = nil
        splat = nil
        display = nil
    }

    /// The current dye (4 channels), read from the GPU; nil before setup or on a readback failure.
    /// Call with the host's context current (between frames on the main thread).
    func readDye() -> FieldGrid? {
        guard let dye, let grid = FieldGrid(width: dye.width, height: dye.height, channels: 4, values: dye.read.readFloatPixels())
        else { return nil }
        return grid
    }

    /// The current velocity (2 channels, decoded from RGBA8 storage when needed).
    func readVelocity() -> FieldGrid? {
        guard let velocity else { return nil }
        let raw = velocity.read.readFloatPixels()
        guard raw.count == velocity.width * velocity.height * 4 else { return nil }
        var out = FieldGrid(width: velocity.width, height: velocity.height, channels: 2)
        for cell in 0..<(velocity.width * velocity.height) {
            for c in 0..<2 {
                let v = raw[cell * 4 + c]
                out.values[cell * 2 + c] = encoding?.decode(v) ?? v
            }
        }
        return out
    }
}
