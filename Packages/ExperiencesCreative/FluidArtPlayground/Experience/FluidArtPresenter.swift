// FluidArtPresenter — feature 193 (UA-F07) T-U07-021 (FR-U07-001 to FR-U07-004, FR-U07-010, FR-U07-019; research R2
// to R4; ADR-0011). Shows the CPU state of Fluid Art Playground with the app's own `FluidFieldsScene` behind its glow
// and the Reduce-Flashing limiter (`EffectScene`), and turns canvas touches into actions with the app's own
// `PointerVelocityTracker` and `PinchRecognizer`. The fluid picture is presentation: the presenter runs one GPU step
// per frame for the fluid steps the core counted since its last draw (with their time), applies each released splat
// once, and starts the fields again from the seeded dye pattern at every setup, reset and detail change.
//
// Differences from the standalone app's `PlaygroundModel` (FR-U07-003):
//   1. The time step of a GPU step is the core's steps since the last draw × 1/120 s (clamped as before by
//      `TimeStepPolicy`), not the frame delta.
//   2. The quality level comes from the session host, not from the app's own `QualityPolicy`; it sets the pressure
//      iterations and the picture's splat cap (`FluidQuality.parameters`).
//   3. Capture renders through the session's still renderer and offers the PNG to the share interface; no file is
//      written.
import FluidArtPlaygroundCore
import Foundation
import SwiftUI
import VisualCoreEffects
import VisualCoreEffectsGraph
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// The latest core and canvas size the presenter saw, for the controls.
@MainActor
@Observable
final class FluidArtMirror {
    /// The current state; nil before the first description.
    var core: FluidArtCore?
    /// The drawable size in pixels at the last draw.
    var drawableSize = CGSize(width: 1, height: 1)
}

/// The presenter of Fluid Art Playground.
@MainActor
final class FluidArtPresenter: ExperiencePresenter {
    typealias Core = FluidArtCore

    let experienceID: ExperienceID
    let mirror = FluidArtMirror()
    private let scene: FluidFieldsScene
    private let effects: EffectScene
    private let reduceFlashing: Bool

    // What the fields already show.
    private var shownSteps = 0
    private var shownResets = 0
    private var shownRebuilds = -1
    private var shownConfiguration: FluidConfiguration?
    private var queued: [Splat] = []

    // Touch translation (presentation state, never part of the digest).
    private var pointers = PointerTracker()
    private var pinch = PinchRecognizer()
    private var tracker = PointerVelocityTracker(spacing: 1)
    private var pinching = false
    private var pinchStartRadius = 0.04

    init(experienceID: ExperienceID, reduceFlashing: Bool) {
        self.experienceID = experienceID
        self.reduceFlashing = reduceFlashing
        scene = FluidFieldsScene()
        effects = EffectScene(content: scene, graph: PlaygroundModel.glowGraph)
        effects.reduceFlashing = reduceFlashing
        scene.splatSource = { [weak self] in
            guard let self else { return [] }
            defer { self.queued.removeAll() }
            return self.queued
        }
    }

    func setup(_ context: RenderContext) throws {
        try effects.setup(context)
        // A new context builds the fields from the scene's configuration: the seeded pattern (ADR-0011).
        shownRebuilds = -1
    }

    func resize(_ context: RenderContext) {
        effects.resize(context)
    }

    func draw(_ core: FluidArtCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        mirror.drawableSize = CGSize(width: context.pixelWidth, height: context.pixelHeight)
        if shownRebuilds != core.rebuilds || shownConfiguration?.seed != core.configuration.seed {
            // A detail change, the first draw or a new context: the fields restart from the pattern at the grid.
            scene.rebuildFields(configuration: core.configuration.validated(maxEdge: scene.effectiveMaxEdge).0)
            shownRebuilds = core.rebuilds
            shownResets = core.resets
            shownSteps = core.fluidSteps
            shownConfiguration = core.configuration
        } else if shownConfiguration != core.configuration {
            scene.update(configuration: core.configuration)
            shownConfiguration = core.configuration
        }
        if shownResets != core.resets {
            scene.resetFields()
            shownResets = core.resets
            shownSteps = core.fluidSteps
        }
        let parameters = FluidQuality.parameters(tier: tier, configuration: core.configuration)
        scene.qualityIterations = parameters.iterations
        let steps = core.fluidSteps - shownSteps
        if steps > 0 {
            let splats = core.batches(from: shownSteps).flatMap(\.splats).compactMap(\.splat)
            queued = Self.thin(splats, cap: parameters.splatCap * steps)
            scene.fixedDelta = Double(steps) * FluidArtCore.stepDuration
            scene.paused = false
        } else {
            queued = []
            scene.paused = true
        }
        shownSteps = core.fluidSteps
        effects.bypassEffects = !core.palette.glow && !reduceFlashing
        try effects.render(context, frame: frame)
    }

    func teardown(_ context: RenderContext) {
        effects.teardown(context)
    }

    func shedCaches() {}

    func describe(_ core: FluidArtCore) -> String {
        mirror.core = core
        return FluidCanvasDescription.text(configuration: core.configuration, storage: scene.precision ?? .unorm8,
                                           paused: core.paused, splashes: core.splashes)
    }

    /// While no splat reached the fields since the last reset, the dye only fades (ADR-0011), so a cell the seeded
    /// pattern leaves nearly empty keeps the palette's colour for no dye. The probe takes the emptiest region of the
    /// pattern on the CPU and declares its class only when the whole region classifies the same with margin.
    func probes(_ core: FluidArtCore) -> [FrameProbe] {
        guard core.untouched, let point = FluidArtProbe.emptyPoint(configuration: core.configuration),
              let expected = FluidArtProbe.expectedClass(palette: core.palette, dye: point.dye) else { return [] }
        return [FrameProbe(name: "empty-dye", x: point.x, y: point.y, expected: expected.rawValue)].compactMap { $0 }
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(FluidArtControls(port: port, mirror: mirror))
    }

    /// Canvas touches, as the standalone app handles them: a second finger starts a pinch that resizes the brush;
    /// otherwise the tracker's samples become `stroke` actions with values normalized to the view.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard viewSize.x > 0, viewSize.y > 0, let core = mirror.core else { return }
        pointers.handle(event)
        pinch.handle(event, tracker: pointers)
        if !pinching, pointers.count >= 2 {
            pinching = true
            pinchStartRadius = core.configuration.brushRadius
            for id in pointers.active.keys {
                _ = tracker.handle(PointerEvent(id: id, phase: .cancelled, location: event.location,
                                                timestamp: event.timestamp))
                port.send("stroke", [0, 0, 0, 0, 3, Double(id)])
            }
        }
        if pinching {
            if pinch.state.isActive {
                let range = FluidConfiguration.brushRadiusRange
                let radius = min(max(pinchStartRadius * pinch.scale, range.lowerBound), range.upperBound)
                if radius != core.configuration.brushRadius { port.send("pinch", [radius]) }
            }
            if pointers.count == 0 {
                pinching = false
                pinch.reset()
            }
            return
        }
        let spacing = core.configuration.brushRadius * min(viewSize.x, viewSize.y) / 2
        if tracker.activeCount == 0, abs(tracker.spacing - spacing) > 1e-9 {
            tracker = PointerVelocityTracker(spacing: spacing)
        }
        if event.phase == .cancelled { port.send("stroke", [0, 0, 0, 0, 3, Double(event.id)]) }
        for sample in tracker.handle(event) {
            let phase: Double = sample.phase == .began ? 0 : sample.phase == .ended ? 2 : 1
            port.send("stroke", [min(max(sample.position.x / viewSize.x, 0), 1),
                                 min(max(sample.position.y / viewSize.y, 0), 1),
                                 Self.clampVelocity(sample.velocity.x / viewSize.x),
                                 Self.clampVelocity(sample.velocity.y / viewSize.y), phase, Double(sample.id)])
        }
    }

    private static func clampVelocity(_ value: Double) -> Double {
        value.isFinite ? min(max(value, -FluidArtCore.maxVelocity), FluidArtCore.maxVelocity) : 0
    }

    /// At most `cap` splats, evenly spaced as `SplatQueue.drain` keeps them.
    static func thin(_ splats: [Splat], cap requested: Int) -> [Splat] {
        let cap = max(1, requested)
        guard splats.count > cap else { return splats }
        if cap == 1 { return [splats[splats.count - 1]] }
        let n = splats.count
        return (0..<cap).map { i in splats[Int((Double(i) * Double(n - 1) / Double(cap - 1)).rounded())] }
    }
}

/// The frame probe of Fluid Art Playground, derived on the CPU from the seeded dye pattern.
enum FluidArtProbe {
    /// The side of the square region searched, as a share of the grid's shorter edge.
    static let regionShare = 0.2

    /// The centre of the region whose largest dye amount is smallest, in FrameChecks' coordinates (from the top),
    /// and that largest amount; nil when even that region holds visible dye.
    static func emptyPoint(configuration: FluidConfiguration) -> (x: Double, y: Double, dye: SIMD3<Float>)? {
        let w = 32, h = 32
        let grid = DyeSeed.pattern(width: w, height: h, seed: configuration.seed,
                                   colors: FluidPalette.named(configuration.paletteID).splatColors)
        let half = max(1, Int(Double(min(w, h)) * regionShare / 2))
        var best: (x: Int, y: Int, dye: SIMD3<Float>, peak: Float)?
        for cy in half..<(h - half) {
            for cx in half..<(w - half) {
                var peak = SIMD3<Float>(repeating: 0)
                for y in (cy - half)...(cy + half) {
                    for x in (cx - half)...(cx + half) {
                        peak = SIMD3(max(peak.x, grid[x, y, 0]), max(peak.y, grid[x, y, 1]), max(peak.z, grid[x, y, 2]))
                    }
                }
                let largest = max(peak.x, peak.y, peak.z)
                if largest < (best?.peak ?? .infinity) { best = (cx, cy, peak, largest) }
            }
        }
        guard let best, best.peak < 0.25 else { return nil }
        // Grid row 0 is the bottom (GL); FrameChecks measures y from the top.
        return ((Double(best.x) + 0.5) / Double(w), 1 - (Double(best.y) + 0.5) / Double(h), best.dye)
    }

    /// The class of the palette's colour for every dye amount from none to `dye`, each channel moved by ±4 levels;
    /// nil when two of them differ.
    static func expectedClass(palette: FluidPalette, dye: SIMD3<Float>) -> FrameColorClass? {
        var found: FrameColorClass?
        for step in 0...8 {
            let amount = dye * (Float(step) / 8)
            let colour = palette.displayColor(dye: amount)
            for offset in [-4, 0, 4] {
                let c = FrameChecks.classify(r: level(colour.x, offset), g: level(colour.y, offset),
                                             b: level(colour.z, offset))
                if found == nil { found = c } else if found != c { return nil }
            }
        }
        return found
    }

    private static func level(_ value: Float, _ offset: Int) -> UInt8 {
        UInt8(clamping: Int((min(max(value, 0), 1) * 255).rounded()) + offset)
    }
}
