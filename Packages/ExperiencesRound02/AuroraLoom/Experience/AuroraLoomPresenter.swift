// AuroraLoomPresenter — feature 303 (R02-G01-03) T-R02G0103-006 (FR-R02G0103-003 … 005, 007; clarifications Q4, Q5).
// Draws the adapter's immutable snapshot with `AuroraLoomRibbonScene` at the host's quality tier (tier n is the
// catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the silk still under
// Reduce Motion (the snapshot time stays at 0 and the wave and shimmer stop) and caps the glow under Reduce Flashing.
// A memory warning releases the GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`:
// no drawing result reaches the kernel (renderer purity, R2-G01-INV-10).
#if os(iOS)
import AuroraLoomCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

/// What the controls show: the latest snapshot the presenter saw.
@MainActor
@Observable
final class AuroraLoomMirror {
    /// The six steps, the stage and the level number; nil before the first description.
    var steps: AuroraLoomSteps?
    var stage: AuroraLoomStage = .loading
    var levelNumber = 1
    var spent = 0
    var allowance = 0
}

/// One entry of the tier log: the tier drawn and why it changed.
struct AuroraLoomTierChange: Equatable {
    let tier: Int
    let reason: String
}

/// The presenter of Aurora Loom.
@MainActor
final class AuroraLoomPresenter: ExperiencePresenter {
    typealias Core = AuroraLoomExperienceCore

    let reduceMotion: Bool
    let reduceFlashing: Bool
    let mirror = AuroraLoomMirror()
    let scene = AuroraLoomRibbonScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G0103-004).
    private(set) var tierLog: [AuroraLoomTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: AuroraLoomSceneSnapshot?

    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
    }

    /// The tests' seam: before `setup`, replaces the ribbon program's fragment source with one that does not compile.
    func breakRibbonShader() {
        scene.ribbonFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    func draw(_ core: AuroraLoomExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = AuroraLoomTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(AuroraLoomTierChange(tier: drawn.index, reason: reason))
        }
        let ticks = reduceMotion ? 0 : frame.time * 120
        let snapshot = core.snapshot(time: ticks)
        lastSnapshot = snapshot
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    func teardown(_ context: RenderContext) {
        scene.release()
    }

    func shedCaches() {
        scene.release()
    }

    func describe(_ core: AuroraLoomExperienceCore) -> String {
        let play = core.play
        mirror.steps = play.steps
        mirror.stage = play.stage
        mirror.levelNumber = core.levelNumber
        mirror.spent = play.spent
        mirror.allowance = play.level.allowance
        let snapshot = core.snapshot(time: 0)
        var met = 0
        for ribbon in 0..<3 { for gate in 0..<4 where snapshot.lit(ribbon: ribbon, gate: gate) { met += 1 } }
        var text = "Aurora Loom level \(core.levelNumber). "
        for ribbon in 0..<3 {
            text += "Ribbon \(ribbon + 1): wave \(play.steps.wave[ribbon]), phase \(play.steps.phase[ribbon]). "
        }
        text += "\(met) of 12 gate crossings in harmony. Moves \(play.spent) of \(play.level.allowance). "
        switch play.stage {
        case .won: text += "The loom is in harmony."
        case .failed: text += "Out of moves."
        default: break
        }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(AuroraLoomControls(port: port, mirror: mirror))
    }
}
#endif
