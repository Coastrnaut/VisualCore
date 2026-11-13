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

    /// The configuration as requested; `configuration` holds the validated one once set up. A Simulation detail
    /// change replaces it through `rebuildFields(configuration:)` (feature 023).
    private(set) var requested: FluidConfiguration
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
    /// One step requested while paused (feature 023 FR-A02-501); cleared by the next frame.
    private(set) var stepRequested = false
    /// A field reset requested for the next frame (feature 023 FR-A02-503).
    private(set) var resetRequested = false
    /// Field resets applied since creation.
    private(set) var resetCount = 0

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
    /// Divergence, pressure and the viscosity scratch (feature 021), created and released with the other fields.
    private(set) var divergenceField: PingPongTarget?
    private(set) var pressure: PingPongTarget?
    private var scratch: PingPongTarget?
    /// Pressure iterations chosen by the quality policy; nil uses the configuration's value (feature 021).
    var qualityIterations: Int?
    /// Pressure iterations the last step used.
    private(set) var lastPressureIterations = 0
    private var advect: FieldPass?
    private var splat: FieldPass?
    private var display: FieldPass?
    private var divergencePass: FieldPass?
    private var fillPass: FieldPass?
    private var pressurePass: FieldPass?
    private var gradientPass: FieldPass?
    private var diffusePass: FieldPass?
    private var copyPass: FieldPass?
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
            divergenceField = try PingPongTarget(registry: r, width: w, height: h, format: format, label: "fap.divergence")
            pressure = try PingPongTarget(registry: r, width: w, height: h, format: format, label: "fap.pressure")
            scratch = try PingPongTarget(registry: r, width: w, height: h, format: format, label: "fap.scratch")
            divergencePass = try FieldPass(registry: r, fragment: FluidShaders.divergence, inputs: ["uVelocity"], label: "fap.divergence")
            fillPass = try FieldPass(registry: r, fragment: FluidShaders.fill, inputs: [], label: "fap.fill")
            pressurePass = try FieldPass(registry: r, fragment: FluidShaders.pressure, inputs: ["uPressure", "uDivergence"], label: "fap.pressure")
            gradientPass = try FieldPass(registry: r, fragment: FluidShaders.gradient, inputs: ["uVelocity", "uPressure"], label: "fap.gradient")
            diffusePass = try FieldPass(registry: r, fragment: FluidShaders.diffuse, inputs: ["uX", "uB"], label: "fap.diffuse")
            copyPass = try FieldPass(registry: r, fragment: FluidShaders.copy, inputs: ["uField"], label: "fap.copy")
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
        case .pattern: DyeSeed.pattern(width: configuration.gridWidth, height: configuration.gridHeight, seed: configuration.seed,
                                       colors: palette.splatColors)
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
                "uDyeMax": .float(Splat.dyeCeiling),
            ])
            try splat.run(pair: dye, input: "uField", uniforms: [
                "uPoint": point, "uRadius": radius, "uValue": .vec4(s.color),
                "uEncoded": .int(0), "uRange": .float(1), "uCenter": .float(0.5), "uVelocity": .int(0),
                "uDyeMax": .float(Splat.dyeCeiling),
            ])
            appliedSplats += 1
        }
    }

    /// A grid change waiting for the next frame (feature 023 FR-A02-511).
    private(set) var pendingRebuild: FluidConfiguration?
    /// True when the last grid change could not be built and the previous grid was restored.
    private(set) var rebuildFellBack = false

    /// Rebuilds the field targets for `configuration`'s grid on the next frame (Simulation detail; FR-A02-511):
    /// the passes and fields are released and set up again with the device cap, restarting from the seed. If that
    /// fails, the previous grid is set up again and `rebuildFellBack` is set. The renderer is kept.
    func rebuildFields(configuration new: FluidConfiguration) { pendingRebuild = new }

    private func applyRebuild(_ new: FluidConfiguration, context: RenderContext) throws {
        pendingRebuild = nil
        let previous = requested
        releaseAll()
        requested = new
        do {
            try setup(context)
            rebuildFellBack = false
        } catch {
            requested = previous
            rebuildFellBack = true
            try setup(context)
        }
        resetRequested = false
    }

    /// Runs exactly one step on the next frame while paused; ignored (and cleared) while running (FR-A02-501).
    func requestStep() { stepRequested = true }

    /// On the next frame: the starting dye (current seed and palette), zero velocity, pressure and divergence, step
    /// count 0, no pending splats. The renderer and the targets are kept; the pause state is unchanged (FR-A02-503).
    func resetFields() { resetRequested = true }

    private func applyReset(velocity: PingPongTarget, dye: PingPongTarget) throws {
        resetRequested = false
        guard uploadSeed(velocity.read, initialVelocity().values) else { throw FluidSceneError.seedUploadFailed("velocity") }
        guard uploadSeed(dye.read, initialDye().values) else { throw FluidSceneError.seedUploadFailed("dye") }
        if let fillPass {
            for pair in [pressure, divergenceField].compactMap({ $0 }) {
                try fillPass.run(output: .target(pair.read), inputs: [:], uniforms: activeUniforms(fillPass))
            }
        }
        pendingSplats.removeAll()
        stepCount = 0
        policy = TimeStepPolicy()
        resetCount += 1
    }

    func render(_ context: RenderContext, frame: FrameInfo) throws {
        if let pendingRebuild { try applyRebuild(pendingRebuild, context: context) }
        guard let velocity, let dye, let advect, let splat, let display else { return }
        do {
            if resetRequested { try applyReset(velocity: velocity, dye: dye) }
            let stepping = !paused || stepRequested
            stepRequested = false
            if stepping {
                let dt = policy.clamp(fixedDelta ?? frame.delta)
                lastStep = dt
                if let splatSource { pendingSplats += splatSource() }
                try applySplats(velocity: velocity, dye: dye, splat: splat)
                let encoded = FieldUniform.int(storage == .rgba8 ? 1 : 0)
                let range = FieldUniform.float(velocityRangeCellsPerSecond)
                let center = FieldUniform.float(encoding?.center ?? 0.5)
                // Spec 021 clarification 5: advect velocity, viscosity, projection, then dye by the projected velocity.
                try advect.run(pair: velocity, input: "uSource", extraInputs: ["uVelocity": velocity.read], uniforms: [
                    "uDt": .float(Float(dt)), "uFactor": .float(Dissipation.factor(d: configuration.velocityDissipation, dt: dt)),
                    "uEncodedVelocity": encoded, "uSourceIsVelocity": .int(1), "uRange": range, "uCenter": center,
                ])
                try solve(velocity: velocity, dt: dt)
                try advect.run(pair: dye, input: "uSource", extraInputs: ["uVelocity": velocity.read], uniforms: [
                    "uDt": .float(Float(dt)), "uFactor": .float(Dissipation.factor(d: configuration.dyeDissipation, dt: dt)),
                    "uEncodedVelocity": encoded, "uSourceIsVelocity": .int(0), "uRange": range, "uCenter": center,
                ])
                stepCount += 1
            }
            try display.run(output: .framebuffer(name: context.framebuffer, width: context.pixelWidth, height: context.pixelHeight),
                            inputs: ["uDye": dye.read], uniforms: paletteUniforms)
        } catch {
            if let pass = error as? FieldPassError { lastError = pass }
            throw error
        }
    }

    /// The display uniforms of the active palette (feature 022).
    var palette: FluidPalette { FluidPalette.named(configuration.paletteID) }
    private var paletteUniforms: [String: FieldUniform] {
        let p = palette
        return ["uMode": .int(Int32(p.mode.rawValue)), "uBackground": .vec4(SIMD4(p.background, 1))]
    }

    /// The solver uniforms shared by every pass (encoding, ranges, edge mode).
    private var solverUniforms: [String: FieldUniform] {
        let v = velocityRangeCellsPerSecond
        return ["uWalls": .int(configuration.boundaryMode == .walls ? 1 : 0), "uEncoded": .int(storage == .rgba8 ? 1 : 0),
                "uCenter": .float(encoding?.center ?? 0.5), "uRangeV": .float(v), "uRangeD": .float(v * 2), "uRangeP": .float(v * 4)]
    }

    /// The shared solver uniforms (plus `extra`) that `pass`'s program actually uses: the compiler removes unused
    /// ones, and FieldPass rejects names that are not active.
    private func activeUniforms(_ pass: FieldPass, _ extra: [String: FieldUniform] = [:]) -> [String: FieldUniform] {
        solverUniforms.merging(extra) { $1 }.filter { pass.program.uniforms[$0.key] != nil }
    }

    /// The pressure iterations used now: the quality tier's value, never more than the configured value.
    var activePressureIterations: Int {
        min(configuration.pressureIterations, max(1, qualityIterations ?? configuration.pressureIterations))
    }

    /// Viscosity (if any), divergence, Jacobi pressure from zero and gradient subtraction (FluidSolver on the GPU).
    private func solve(velocity: PingPongTarget, dt: Double) throws(FieldPassError) {
        guard let divergenceField, let pressure, let scratch, let divergencePass, let fillPass, let pressurePass,
              let gradientPass, let diffusePass, let copyPass else { return }
        func uniforms(_ pass: FieldPass, _ extra: [String: FieldUniform] = [:]) -> [String: FieldUniform] {
            activeUniforms(pass, extra)
        }
        if configuration.viscosity > 0 {
            try copyPass.run(output: .target(scratch.write), inputs: ["uField": velocity.read])
            scratch.swap()
            let alpha = Float(1 / (configuration.viscosity * FluidSolver.viscosityScale * dt))
            for _ in 0..<FluidSolver.viscosityIterations {
                try diffusePass.run(pair: velocity, input: "uX", extraInputs: ["uB": scratch.read], uniforms: uniforms(diffusePass, ["uAlpha": .float(alpha)]))
            }
        }
        try divergencePass.run(output: .target(divergenceField.write), inputs: ["uVelocity": velocity.read], uniforms: uniforms(divergencePass))
        divergenceField.swap()
        try fillPass.run(output: .target(pressure.read), inputs: [:], uniforms: uniforms(fillPass))
        let iterations = activePressureIterations
        lastPressureIterations = iterations
        for _ in 0..<iterations {
            try pressurePass.run(pair: pressure, input: "uPressure", extraInputs: ["uDivergence": divergenceField.read],
                                 uniforms: uniforms(pressurePass))
        }
        try gradientPass.run(pair: velocity, input: "uVelocity", extraInputs: ["uPressure": pressure.read],
                             uniforms: uniforms(gradientPass))
    }

    /// Applies new tuning from the next frame without rebuilding the fields (feature 021 FR-A02-306): viscosity,
    /// dissipation, pressure iterations, edge mode and splat settings. The grid size and velocity range are kept.
    func update(configuration new: FluidConfiguration) {
        var c = new
        c.gridWidth = configuration.gridWidth
        c.gridHeight = configuration.gridHeight
        c.velocityRange = configuration.velocityRange
        c.seed = configuration.seed
        configuration = c.validated(maxEdge: effectiveMaxEdge).0
    }

    func teardown(_ context: RenderContext) { releaseAll() }

    private func releaseAll() {
        velocity?.release()
        dye?.release()
        advect?.release()
        splat?.release()
        display?.release()
        for pair in [divergenceField, pressure, scratch] { pair?.release() }
        for pass in [divergencePass, fillPass, pressurePass, gradientPass, diffusePass, copyPass] { pass?.release() }
        divergenceField = nil
        pressure = nil
        scratch = nil
        divergencePass = nil
        fillPass = nil
        pressurePass = nil
        gradientPass = nil
        diffusePass = nil
        copyPass = nil
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

    /// The result of `fieldCheck()`: blow-up detectors, not physics claims (spec 023 FR-A02-507).
    struct FieldCheck: Equatable {
        /// Largest velocity magnitude in cells per second.
        var maxVelocity: Float = 0
        /// Largest dye channel.
        var maxDye: Float = 0
        /// Largest |pressure|.
        var maxPressure: Float = 0
        /// The first failed rule, or nil when every value is finite and in range.
        var firstBad: String?
        /// True when no rule failed.
        var passed: Bool { firstBad == nil }
    }

    /// Reads velocity, pressure and dye back and checks them (feature 023 T-A02-508; FR-A02-507): all values
    /// finite; dye channels in 0…4; |v|·Δt ≤ the longer grid edge; |p| ≤ 10⁴; in RGBA8 storage the velocity must not
    /// sit entirely at the encoding's extremes. Call between frames with the host's context current.
    func fieldCheck() -> FieldCheck {
        var check = FieldCheck()
        guard let velocity, let dye, let pressure else {
            check.firstBad = "fields not set up"
            return check
        }
        let cells = velocity.width * velocity.height
        let rawV = velocity.read.readFloatPixels(), rawD = dye.read.readFloatPixels(), rawP = pressure.read.readFloatPixels()
        guard rawV.count == cells * 4, rawD.count == cells * 4, rawP.count == cells * 4 else {
            check.firstBad = "readback failed"
            return check
        }
        let pressureEncoding = storage == .rgba8 ? SignedRangeEncoding.unorm8(range: velocityRangeCellsPerSecond * 4) : nil
        let dt = Float(lastStep > 0 ? lastStep : 1.0 / 60)
        let edge = Float(max(velocity.width, velocity.height))
        var extremes = 0
        for cell in 0..<cells {
            let x = cell % velocity.width, y = cell / velocity.width
            let vx = encoding?.decode(rawV[cell * 4]) ?? rawV[cell * 4]
            let vy = encoding?.decode(rawV[cell * 4 + 1]) ?? rawV[cell * 4 + 1]
            if storage == .rgba8 {
                for c in 0..<2 where rawV[cell * 4 + c] <= 0 || rawV[cell * 4 + c] >= 1 { extremes += 1 }
            }
            let speed = (vx * vx + vy * vy).squareRoot()
            let p = pressureEncoding?.decode(rawP[cell * 4]) ?? rawP[cell * 4]
            let d = rawD[cell * 4..<cell * 4 + 3]
            check.maxVelocity = max(check.maxVelocity, speed.isFinite ? speed : .infinity)
            check.maxPressure = max(check.maxPressure, abs(p))
            check.maxDye = max(check.maxDye, d.max() ?? 0)
            guard check.firstBad == nil else { continue }
            if !speed.isFinite { check.firstBad = "velocity not finite at (\(x), \(y))" }
            else if !p.isFinite { check.firstBad = "pressure not finite at (\(x), \(y))" }
            else if d.contains(where: { !$0.isFinite }) { check.firstBad = "dye not finite at (\(x), \(y))" }
            else if d.contains(where: { $0 < 0 || $0 > 4 }) { check.firstBad = "dye out of 0…4 at (\(x), \(y))" }
            else if speed * dt > edge { check.firstBad = "velocity \(speed) cells/s moves past the grid at (\(x), \(y))" }
            else if abs(p) > 10_000 { check.firstBad = "pressure \(p) beyond 10⁴ at (\(x), \(y))" }
        }
        if check.firstBad == nil, storage == .rgba8, extremes == cells * 2 {
            check.firstBad = "velocity saturated at the encoding's extremes everywhere"
        }
        return check
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
