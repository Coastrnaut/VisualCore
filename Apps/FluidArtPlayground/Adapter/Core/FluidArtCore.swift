// FluidArtCore — feature 193 (UA-F07) T-U07-021 (FR-U07-001 to FR-U07-004; research R3, R4; data-model section 2;
// ADR-0011). The CPU state of Fluid Art Playground as an experience: the configuration, the control choices, the
// splats waiting for a step, the step counts and the seed. The fluid itself lives in GPU textures and is how this
// state is shown: the presenter runs the passes for the steps the core counted and applies each released splat once.
//
// Differences from the standalone app (FR-U07-003):
//   1. Splats are drained once per fixed step of 1/120 s with the configured cap (`maxSplatsPerFrame`), instead of
//      once per frame; the quality level's lower cap applies to the picture only (clarification 2).
//   2. A stroke action carries a sample the presenter's `PointerVelocityTracker` made: the position and the velocity
//      normalized to the view (1 = the view's width or height, per second), its phase and its pointer id. The core
//      turns it into a splat with the same arithmetic as `SplatQueue.add`.
//   3. The dye pattern's seed is the preparation seed (`configuration.seed`); the standalone app always uses 1.
//   4. `pinch` carries the new brush radius; the pinch gesture is recognized by the presenter.
//   5. The grid is the requested detail level; the presenter applies the device's size limit to the picture.
//   6. The configuration is not stored apart from the experience's saved state (the standalone app kept none).
import Foundation
import FluidArtPlaygroundCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence

/// One splat as plain values: the input of `Splat(position:radius:force:color:)`.
public struct FluidSplat: Codable, Equatable, Sendable {
    /// Position in normalized grid coordinates (origin bottom-left).
    public var x: Float, y: Float
    /// Radius as a fraction of the shorter grid edge.
    public var radius: Float
    /// Force in cells per second.
    public var forceX: Float, forceY: Float
    /// Dye colour (0…1).
    public var red: Float, green: Float, blue: Float

    /// The validated splat for the GPU; nil for a non-finite value.
    public var splat: Splat? {
        Splat(position: SIMD2(x, y), radius: radius, force: SIMD2(forceX, forceY), color: SIMD4(red, green, blue, 1))
    }
}

/// The splats one fluid step released.
public struct FluidBatch: Codable, Equatable, Sendable {
    /// The fluid step (from 0 after the last reset) they belong to.
    public var fluidStep: Int
    /// The splats, in order.
    public var splats: [FluidSplat]
}

/// The palette colour a pointer holds while it paints.
public struct FluidColorSlot: Codable, Equatable, Sendable {
    /// The pointer id.
    public var pointer: Int
    /// The index into the palette's splat colours.
    public var index: Int
}

/// The CPU state of Fluid Art Playground. Codable; schema version 1.
public struct FluidArtCore: ExperienceCore, Codable, Equatable {
    /// The experience's id in the catalog.
    public static let experienceID = "a02.fluid-art-playground"
    /// How many released batches the core keeps for the presenter: more than the steps of one frame.
    public static let keptBatches = 32
    /// The largest pointer id a stroke may name.
    public static let maxPointerID = 1_000_000.0
    /// The largest normalized velocity a stroke may carry (view sizes per second).
    public static let maxVelocity = 1_000.0

    /// The seed the state was prepared from; also the dye pattern's seed.
    public private(set) var seed: UInt64
    /// The validated configuration (grid, palette, edges, tuning).
    public private(set) var configuration: FluidConfiguration
    /// Whether the simulation is paused.
    public private(set) var paused: Bool
    /// One step was asked for while paused.
    public private(set) var stepRequested: Bool
    /// Splats waiting for a step, at most `SplatQueue.maxPending`.
    public private(set) var pending: [FluidSplat]
    /// The colour each painting pointer holds, ordered by pointer id.
    public private(set) var colorSlots: [FluidColorSlot]
    /// The next colour index for a new pointer.
    public private(set) var nextColor: Int
    /// Splash bursts added since the preparation.
    public private(set) var splashes: Int
    /// Fluid steps since the last reset or detail change.
    public private(set) var fluidSteps: Int
    /// The last released batches, oldest first.
    public private(set) var recent: [FluidBatch]
    /// Splats released since the last reset or detail change.
    public private(set) var released: Int
    /// Splats dropped by the caps.
    public private(set) var dropped: Int
    /// Resets of the canvas.
    public private(set) var resets: Int
    /// Grid rebuilds (detail changes).
    public private(set) var rebuilds: Int

    /// The palette in effect.
    public var palette: FluidPalette { FluidPalette.named(configuration.paletteID) }

    // MARK: Contract

    public static var migrations: MigrationChain { MigrationChain(currentVersion: 1) }
    public static var qualityTiers: Int { FluidQuality.tierCount }

    /// Full, Reduced and Minimal (`FluidQuality`): the solver's iterations and the picture's splat cap.
    public static var qualityProfile: QualityProfile {
        let levels = [QualityLevel(name: "full"),
                      QualityLevel(name: "reduced", iterationShare: 0.5),
                      QualityLevel(name: "minimal", elementShare: 0.5, iterationShare: 0.25)]
        return (try? QualityProfile(levels: levels)) ?? .uniform(levels: FluidQuality.tierCount)
    }

    /// The phases a stroke carries: began, moved, ended, cancelled.
    public static let strokePhases = 0...3

    public static var controls: [ExperienceControl] {
        let dissipation = FluidConfiguration.dissipationRange
        return [
            ExperienceControl(id: "stroke", ranges: [0...1, 0...1, -maxVelocity...maxVelocity,
                                                    -maxVelocity...maxVelocity, 0...3, 0...maxPointerID]),
            ExperienceControl(id: "pinch", ranges: [FluidConfiguration.brushRadiusRange]),
            ExperienceControl(id: "brush", ranges: [FluidConfiguration.brushRadiusRange]),
            ExperienceControl(id: "splash"),
            ExperienceControl(id: "pause"),
            ExperienceControl(id: "resume"),
            ExperienceControl(id: "step"),
            ExperienceControl(id: "reset"),
            ExperienceControl(id: "palette", ranges: [0...Double(FluidPalette.all.count - 1)]),
            ExperienceControl(id: "edges", ranges: [0...Double(BoundaryMode.allCases.count - 1)]),
            ExperienceControl(id: "detail", ranges: [0...Double(FluidDetail.allCases.count - 1)]),
            ExperienceControl(id: "viscosity", ranges: [FluidConfiguration.viscosityRange]),
            ExperienceControl(id: "dyeFade", ranges: [dissipation]),
            ExperienceControl(id: "motionFade", ranges: [dissipation]),
            ExperienceControl(id: "quality", ranges: [Double(FluidConfiguration.pressureIterationRange.lowerBound)
                                                      ... Double(FluidConfiguration.pressureIterationRange.upperBound)]),
            ExperienceControl(id: "tuningReset"),
        ]
    }

    public static func prepare(seed: UInt64) async throws -> FluidArtCore {
        try Task.checkCancellation()
        return FluidArtCore(seed: seed)
    }

    private init(seed: UInt64) {
        self.seed = seed
        var configuration = FluidConfiguration()
        configuration.seed = seed
        self.configuration = configuration.validated().0
        paused = false
        stepRequested = false
        pending = []
        colorSlots = []
        nextColor = 0
        splashes = 0
        fluidSteps = 0
        recent = []
        released = 0
        dropped = 0
        resets = 0
        rebuilds = 0
    }

    /// One fixed step: while running, or once after `step` while paused, the pending splats are released under the
    /// configured cap and the fluid advances one step.
    public mutating func update(step: Int) {
        guard !paused || stepRequested else { return }
        stepRequested = false
        let batch = drain(cap: configuration.maxSplatsPerFrame)
        if !batch.isEmpty {
            recent.append(FluidBatch(fluidStep: fluidSteps, splats: batch))
            if recent.count > Self.keptBatches { recent.removeFirst(recent.count - Self.keptBatches) }
            released += batch.count
        }
        fluidSteps += 1
    }

    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        switch action.control {
        case "stroke":
            let phase = Int(v[4].rounded()), pointer = Int(v[5].rounded())
            stroke(x: v[0], y: v[1], vx: v[2], vy: v[3], phase: phase, pointer: pointer)
        case "pinch", "brush":
            set { $0.brushRadius = v[0] }
        case "splash":
            splash()
        case "pause":
            guard !paused else { return .rejected(.rule(code: "a02.already-paused")) }
            paused = true
        case "resume":
            guard paused else { return .rejected(.rule(code: "a02.not-paused")) }
            paused = false
            stepRequested = false
        case "step":
            guard paused else { return .rejected(.rule(code: "a02.not-paused")) }
            stepRequested = true
        case "reset":
            clearInput()
            resets += 1
            restartFields()
        case "palette":
            set { $0.paletteID = FluidPalette.all[Int(v[0].rounded())].id }
        case "edges":
            set { $0.boundaryMode = BoundaryMode.allCases[Int(v[0].rounded())] }
        case "detail":
            let level = FluidDetail.allCases[Int(v[0].rounded())]
            guard level != FluidDetail(grid: configuration) else { return .rejected(.rule(code: "a02.same-detail")) }
            clearInput()
            set { level.apply(to: &$0) }
            rebuilds += 1
            restartFields()
        case "viscosity":
            set { $0.viscosity = v[0] }
        case "dyeFade":
            set { $0.dyeDissipation = v[0] }
        case "motionFade":
            set { $0.velocityDissipation = v[0] }
        case "quality":
            set { $0.pressureIterations = Int(v[0].rounded()) }
        case "tuningReset":
            var fresh = FluidConfiguration()
            fresh.gridWidth = configuration.gridWidth
            fresh.gridHeight = configuration.gridHeight
            fresh.seed = seed
            configuration = fresh.validated().0
        default:
            return .rejected(.unknownControl(action.control))
        }
        return .accepted
    }

    public mutating func reset() {
        self = FluidArtCore(seed: seed)
    }

    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(seed)
        let c = configuration
        builder.add(c.version)
        builder.add(c.gridWidth)
        builder.add(c.gridHeight)
        try builder.add(c.dyeDissipation)
        try builder.add(c.velocityDissipation)
        try builder.add(c.viscosity)
        builder.add(c.pressureIterations)
        try builder.add(c.velocityRange)
        builder.add(c.seed)
        try builder.add(c.brushRadius)
        try builder.add(c.forceScale)
        builder.add(c.maxSplatsPerFrame)
        builder.add(c.boundaryMode.rawValue)
        builder.add(c.paletteID)
        builder.add(paused)
        builder.add(stepRequested)
        builder.add(count: pending.count)
        for splat in pending { try add(splat, to: &builder) }
        builder.add(count: colorSlots.count)
        for slot in colorSlots {
            builder.add(slot.pointer)
            builder.add(slot.index)
        }
        builder.add(nextColor)
        builder.add(splashes)
        builder.add(fluidSteps)
        builder.add(count: recent.count)
        for batch in recent {
            builder.add(batch.fluidStep)
            builder.add(count: batch.splats.count)
            for splat in batch.splats { try add(splat, to: &builder) }
        }
        builder.add(released)
        builder.add(dropped)
        builder.add(resets)
        builder.add(rebuilds)
    }

    // MARK: Domain

    /// The batches released at fluid steps `from ..< fluidSteps`, for the presenter.
    public func batches(from first: Int) -> [FluidBatch] {
        recent.filter { $0.fluidStep >= first }
    }

    /// `canvas-painted` once a splat reached the fields since the last reset or rebuild (feature 193; the
    /// validator needs an outcome for the completion scenario). Derived, never stored.
    public var outcome: ExperienceOutcome? {
        released > 0 ? ExperienceOutcome(code: "canvas-painted") : nil
    }

    /// Whether no splat reached the fields since the last reset or rebuild: the dye then only fades.
    public var untouched: Bool { released == 0 }

    /// One tracker sample as `SplatQueue.add` turns it into a splat.
    private mutating func stroke(x: Double, y: Double, vx: Double, vy: Double, phase: Int, pointer: Int) {
        if phase == 3 {
            colorSlots.removeAll { $0.pointer == pointer }
            return
        }
        let colors = palette.splatColors
        let index: Int
        if let slot = colorSlots.first(where: { $0.pointer == pointer }) {
            index = slot.index
        } else {
            index = nextColor % colors.count
            nextColor += 1
            colorSlots.append(FluidColorSlot(pointer: pointer, index: index))
            colorSlots.sort { $0.pointer < $1.pointer }
        }
        let rgb = colors[index % colors.count]
        let force = SIMD2(Float(vx * Double(configuration.gridWidth)), Float(-vy * Double(configuration.gridHeight)))
            * Float(configuration.forceScale)
        if let splat = Splat(position: SIMD2(Float(x), Float(1 - y)), radius: Float(configuration.brushRadius),
                             force: force, color: SIMD4(rgb, 1)) {
            push(FluidSplat(splat))
        }
        if phase == 2 { colorSlots.removeAll { $0.pointer == pointer } }
    }

    /// Splash burst k, as `SplatQueue.addSplash`.
    private mutating func splash() {
        let k = splashes
        let angle = Double(k) * SplatQueue.splashAngleDegrees * .pi / 180
        let force = SIMD2(Float(cos(angle)), Float(sin(angle))) * SplatQueue.splashForce
        let rgb = palette.splatColors[k % palette.splatColors.count]
        splashes += 1
        if let splat = Splat(position: SIMD2(0.5, 0.5), radius: Float(configuration.brushRadius), force: force,
                             color: SIMD4(rgb, 1)) {
            push(FluidSplat(splat))
        }
    }

    private mutating func push(_ splat: FluidSplat) {
        pending.append(splat)
        if pending.count > SplatQueue.maxPending {
            pending.removeFirst(pending.count - SplatQueue.maxPending)
            dropped += 1
        }
    }

    /// `SplatQueue.drain(max:)`: over the cap, the evenly spaced indices `round(i·(n−1)/(cap−1))`.
    private mutating func drain(cap requested: Int) -> [FluidSplat] {
        let cap = max(1, requested)
        let all = pending
        pending.removeAll()
        guard all.count > cap else { return all }
        dropped += all.count - cap
        if cap == 1 { return [all[all.count - 1]] }
        let n = all.count
        return (0..<cap).map { i in all[Int((Double(i) * Double(n - 1) / Double(cap - 1)).rounded())] }
    }

    /// Strokes end and queued splats are dropped (reset and detail change).
    private mutating func clearInput() {
        pending.removeAll()
        colorSlots.removeAll()
    }

    /// The fields restart from the seed: the step count and the released batches start again.
    private mutating func restartFields() {
        fluidSteps = 0
        recent.removeAll()
        released = 0
    }

    /// Changes the configuration through its validation.
    private mutating func set(_ change: (inout FluidConfiguration) -> Void) {
        var next = configuration
        change(&next)
        configuration = next.validated().0
    }

    private func add(_ splat: FluidSplat, to builder: inout DigestBuilder) throws(DigestError) {
        for value in [splat.x, splat.y, splat.radius, splat.forceX, splat.forceY, splat.red, splat.green, splat.blue] {
            try builder.add(Double(value))
        }
    }
}

extension FluidSplat {
    /// The plain values of a validated splat.
    public init(_ splat: Splat) {
        x = splat.position.x
        y = splat.position.y
        radius = splat.radius
        forceX = splat.force.x
        forceY = splat.force.y
        red = splat.color.x
        green = splat.color.y
        blue = splat.color.z
    }
}
