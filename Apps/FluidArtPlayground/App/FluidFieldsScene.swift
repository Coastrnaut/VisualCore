// FluidFieldsScene.swift — velocity and dye fields in ping-pong pairs, faded by dissipation and shown on screen
// (feature 019 T-A02-110; FR-A02-103, FR-A02-104, FR-A02-106–FR-A02-108; contracts/app-fields.md).
// All GPU work goes through VisualCore (PingPongTarget, FieldPass, FloatRenderSupport); the app creates no EGL
// context. Context loss runs teardown then setup, which rebuilds both fields from the configuration.
import FluidArtPlaygroundCore
import VisualCoreRendering
import VisualCoreSimulation

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
    /// Largest grid edge the device allows (from `RenderHost.maxRenderSize`).
    let maxEdge: Int

    /// Test seam: replaces the frame delta before it is clamped.
    var fixedDelta: Double?
    /// When true, frames show the dye without stepping.
    var paused = false

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
    private var dissipate: FieldPass?
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

    private var encoding: SignedRangeEncoding? {
        storage == .rgba8 ? SignedRangeEncoding(range: Float(configuration.velocityRange)) : nil
    }

    func setup(_ context: RenderContext) throws {
        if setupCount > 0 { rebuildCount += 1 }
        setupCount += 1
        stepCount = 0
        policy = TimeStepPolicy()
        (configuration, issues) = requested.validated(maxEdge: maxEdge)
        let r = context.resources
        let format = FloatRenderSupport.detect(in: r).storageFormat(forceFallback: forceFallback)
        storage = format
        let w = configuration.gridWidth, h = configuration.gridHeight
        do {
            let velocity = try PingPongTarget(registry: r, width: w, height: h, format: format, label: "fap.velocity")
            self.velocity = velocity
            let dye = try PingPongTarget(registry: r, width: w, height: h, format: format, label: "fap.dye")
            self.dye = dye
            dissipate = try FieldPass(registry: r, fragment: FluidShaders.dissipate, inputs: ["uField"], label: "fap.dissipate")
            display = try FieldPass(registry: r, fragment: FluidShaders.display, inputs: ["uDye"], label: "fap.display")
            velocity.read.upload(rgbaFloats: initialVelocity().values)
            dye.read.upload(rgbaFloats: initialDye().values)
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
        var v = DyeSeed.zeroVelocity(width: configuration.gridWidth, height: configuration.gridHeight).padded(toChannels: 4)
        if let encoding {
            for i in v.values.indices where i % 4 < 2 { v.values[i] = encoding.encode(v.values[i]) }
        }
        return v
    }

    func resize(_ context: RenderContext) {}

    func render(_ context: RenderContext, frame: FrameInfo) throws {
        guard let velocity, let dye, let dissipate, let display else { return }
        do {
            if !paused {
                let dt = policy.clamp(fixedDelta ?? frame.delta)
                lastStep = dt
                try dissipate.run(pair: velocity, input: "uField", uniforms: [
                    "uFactor": .float(Dissipation.factor(d: configuration.velocityDissipation, dt: dt)),
                    "uEncoded": .int(storage == .rgba8 ? 1 : 0),
                    "uRange": .float(Float(configuration.velocityRange)),
                ])
                try dissipate.run(pair: dye, input: "uField", uniforms: [
                    "uFactor": .float(Dissipation.factor(d: configuration.dyeDissipation, dt: dt)),
                    "uEncoded": .int(0),
                    "uRange": .float(1),
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
        dissipate?.release()
        display?.release()
        velocity = nil
        dye = nil
        dissipate = nil
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
