// ParticlePresenter — feature 193 (UA-F07) T-U07-027 (FR-U07-001 to FR-U07-004, FR-U07-010, FR-U07-019; research R4,
// R5; clarification 2). Draws the core of Particle Universe with VisualCore's `ParticleLayerScene` over the app's world
// square (`ParticleStage.world`). The scene's source reads the core's particles, capped by the quality level, and never
// steps the simulation. Taps and drags on the canvas become `force.place` actions at the world point under the
// finger, normalized to the world square.
//
// Differences from the standalone app's `SceneModel` and `ParticleStage` (FR-U07-003):
//   1. The render callback only reads: the core steps the simulation (the standalone `gpuFrame` advanced it).
//   2. The quality level comes from the session host and caps the drawn count; the simulation keeps its limit.
//   3. There is no CPU preview renderer: a GPU failure fails the session's setup and shows its failure view.
//   4. Feature 037 A04-P05 T-A04-506 (FR-A04-510 to FR-A04-512; research D2): a `FrameBudgetMonitor` fed with each
//      drawn frame's time while the core plays lowers the drawn detail on slow frames; the presenter draws at the
//      coarser of the host's tier and the monitor's. It is not a logged action and never changes the simulation.
import Foundation
import ParticleUniverseCore
import SwiftUI
import UIKit
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

/// The latest core the presenter saw and the canvas size in points, for the controls and the probe.
@MainActor
@Observable
final class ParticleMirror {
    var core: ParticleCore?
    var canvasSize = Vec2(390, 390)
}

/// The error of a draw failed on purpose through `ParticlePresenter.failNextDraw` (feature 038 A04-P06 T-A04-608,
/// FR-A04-612; research D1): it lets a test prove the host-to-session failure path.
enum ParticleDrawError: Error, Equatable {
    /// The draw was failed by the test seam.
    case injected
}

/// The presenter of Particle Universe.
@MainActor
final class ParticlePresenter: ExperiencePresenter {
    typealias Core = ParticleCore

    /// The probe point, measured from the top left: the top middle, far from every emitter's placement.
    static let probePoint = (x: 0.5, y: 0.02)

    let experienceID: ExperienceID
    let mirror = ParticleMirror()
    let reduceMotion: Bool
    private let reduceFlashing: Bool
    private let pointsPerPixel: Double
    private var particles: [ParticleInstance] = []
    /// The drawn-detail controller: records frame times while the core plays and restarts while it is paused, on
    /// setup and on teardown (feature 037 A04-P05).
    var detail = FrameBudgetMonitor()
    /// The display interval seen from the host's target timestamps; it sets `detail.budget` (T-A04-516).
    private(set) var interval = FrameIntervalEstimate()
    /// The tier of the last draw: the coarser of the host's tier and `detail.tier`.
    private(set) var drawnTier = 0
    /// The number of particles of the last draw.
    var drawnCount: Int { particles.count }
    /// Set only by tests; the next draw throws `ParticleDrawError.injected` and clears the flag (feature 038
    /// A04-P06 T-A04-608, research D1).
    var failNextDraw = false
    /// The brightness cap of the scene: 0.6 with Reduce Flashing and 1 without it, set by each draw (T-A04-608,
    /// FR-A04-613).
    var brightnessCap: Double { scene.brightnessCap }
    private lazy var scene = ParticleLayerScene(world: ParticleStage.world, background: Vec4(0, 0, 0, 1)) { [weak self] _ in
        self?.particles ?? []
    }

    /// The saved scenes of this experience (feature 036 A04-P04).
    let library: ParticleLibrary

    init(experienceID: ExperienceID, storage: ExperienceStorage, reduceMotion: Bool, reduceFlashing: Bool,
         displayScale: Double) {
        self.experienceID = experienceID
        library = ParticleLibrary(storage: storage)
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        pointsPerPixel = 1 / max(displayScale, 1)
    }

    func setup(_ context: RenderContext) throws {
        detail.restart()
        interval.reset()
        try scene.setup(context)
    }

    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    func draw(_ core: ParticleCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        if failNextDraw {
            failNextDraw = false
            throw ParticleDrawError.injected
        }
        mirror.canvasSize = Vec2(Double(max(1, context.pixelWidth)) * pointsPerPixel,
                                 Double(max(1, context.pixelHeight)) * pointsPerPixel)
        noteFrameTarget(index: frame.index, target: frame.targetTimestamp)
        if core.playing {
            detail.record(frameTime: frame.delta)
        } else {
            detail.restart()
        }
        drawnTier = max(tier, detail.tier)
        particles = core.instances(tier: drawnTier)
        scene.trailStrength = core.trailsOn ? core.trailStrength : 0
        scene.blend = core.additive ? .additive : .normal
        scene.brightnessCap = reduceFlashing ? 0.6 : 1
        try scene.render(context, frame: frame)
    }

    func teardown(_ context: RenderContext) {
        scene.teardown(context)
        particles = []
        detail.restart()
        interval.reset()
    }

    /// Feeds one frame's index and target presentation time to the interval estimate; when the estimate differs
    /// from the monitor's budget by more than 10%, rebuilds the monitor for the new budget at the same tier (its
    /// windows start empty). Before any estimate the budget stays 1/60 s (T-A04-516, FR-A04-510).
    func noteFrameTarget(index: Int, target: Double) {
        guard let seen = interval.observe(index: index, target: target),
              abs(seen - detail.budget) > 0.1 * detail.budget else { return }
        detail = FrameBudgetMonitor(budget: seen, maxTier: detail.maxTier, tier: detail.tier)
    }

    func describe(_ core: ParticleCore) -> String {
        mirror.core = core
        let force = core.placedForce.map {
            "\($0.kind.title) at \(Int($0.position.x.rounded())), \(Int($0.position.y.rounded())), which \($0.kind.spokenDescription)"
        } ?? "no force placed"
        return "Particle scene: \(core.selectedEntry.family.title), \(force), \(core.playing ? "playing" : "paused")."
    }

    /// The top middle of the canvas shows the black background while no particle covers it: the particles' world
    /// positions and sizes are CPU state, and the view point maps to the world with the scene's own `worldPoint`.
    /// Without trails only (a trail keeps earlier frames).
    func probes(_ core: ParticleCore) -> [FrameProbe] {
        guard !core.trailsOn else { return [] }
        let size = mirror.canvasSize
        guard let world = ParticleLayerScene.worldPoint(Vec2(size.x * Self.probePoint.x, size.y * Self.probePoint.y),
                                                        viewSize: size, world: ParticleStage.world) else { return [] }
        // A margin of 24 world units around each particle's radius covers glow and rounding.
        let covered = core.simulation.instances().contains { $0.position.distance(to: world) < $0.size / 2 + 24 }
        guard !covered else { return [] }
        return [FrameProbe(name: "background-top", x: Self.probePoint.x, y: Self.probePoint.y, expected: "dark")]
            .compactMap { $0 }
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(ParticleControls(port: port, mirror: mirror, library: library, reduceMotion: reduceMotion))
    }

    /// A tap or a drag on the canvas places the force under the finger, as `SceneModel.touch(at:in:)` does.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard event.phase == .began || event.phase == .moved,
              let world = ParticleLayerScene.worldPoint(event.location, viewSize: viewSize, world: ParticleStage.world)
        else { return }
        let half = PlacedForce.worldHalfExtent
        let x = min(max(world.x / (2 * half) + 0.5, 0), 1), y = min(max(world.y / (2 * half) + 0.5, 0), 1)
        port.send("force.place", [x, y])
    }
}
