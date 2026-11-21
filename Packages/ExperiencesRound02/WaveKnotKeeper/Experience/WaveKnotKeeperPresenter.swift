// WaveKnotKeeperPresenter — feature 323 (R02-G03-03) T-R02G0303-006 (FR-R02G0303-003 … 005, 007; clarifications Q4,
// Q5). Draws the adapter's immutable snapshot with `WaveKnotKeeperRopeScene` at the host's quality tier (tier n is the
// catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the caustic pulses still
// under Reduce Motion (the snapshot time stays at 0) and caps the glow under Reduce Flashing. A memory warning releases
// the GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the
// kernel (renderer purity, R2-G03-INV-10).
#if os(iOS)
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import WaveKnotKeeperCore

/// What the controls show: the latest state the presenter described.
@MainActor
@Observable
final class WaveKnotKeeperMirror {
    /// The rope's point count; 0 before the first description.
    var pointCount = 0
    /// The selected point (presentation only).
    var selected = 0
    /// The play's stage.
    var stage: WaveKnotKeeperStage = .loading
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The moves spent.
    var spent = 0
    /// The move allowance.
    var allowance = 0
    /// The rope's crossings and writhe, and the target's.
    var crossings = 0
    var writhe = 0
    var targetCrossings = 0
    var targetWrithe = 0
    /// The text of the last refused change, if any.
    var message: String?
}

/// One entry of the tier log: the tier drawn and why it changed.
struct WaveKnotKeeperTierChange: Equatable {
    let tier: Int
    let reason: String
}

/// The presenter of Wave Knot Keeper.
@MainActor
final class WaveKnotKeeperPresenter: ExperiencePresenter {
    typealias Core = WaveKnotKeeperExperienceCore

    let reduceMotion: Bool
    let reduceFlashing: Bool
    let mirror = WaveKnotKeeperMirror()
    let scene = WaveKnotKeeperRopeScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G0303-004).
    private(set) var tierLog: [WaveKnotKeeperTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: WaveKnotKeeperSceneSnapshot?

    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
    }

    /// The tests' seam: before `setup`, replaces the rope program's fragment source with one that does not compile.
    func breakRopeShader() {
        scene.ropeFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    func draw(_ core: WaveKnotKeeperExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = WaveKnotKeeperTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(WaveKnotKeeperTierChange(tier: drawn.index, reason: reason))
        }
        let time = reduceMotion ? 0 : frame.time
        let snapshot = core.snapshot(time: time)
        lastSnapshot = snapshot
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    func teardown(_ context: RenderContext) {
        scene.release()
    }

    func shedCaches() {
        scene.release()
    }

    func describe(_ core: WaveKnotKeeperExperienceCore) -> String {
        let play = core.play
        let snapshot = core.snapshot(time: 0)
        mirror.pointCount = play.points.count
        mirror.selected = snapshot.selected ?? 0
        mirror.stage = play.stage
        mirror.levelNumber = core.levelNumber
        mirror.spent = play.spent
        mirror.allowance = play.level.allowance
        mirror.crossings = snapshot.summary.crossings
        mirror.writhe = snapshot.summary.writhe
        mirror.targetCrossings = play.level.target.crossings
        mirror.targetWrithe = play.level.target.writhe
        var text = "Wave Knot Keeper level \(core.levelNumber). "
        text += "A rope of \(play.points.count) points with \(snapshot.summary.crossings) crossings, "
        text += "writhe \(snapshot.summary.writhe). "
        text += "Target: \(play.level.target.crossings) crossings, writhe \(play.level.target.writhe). "
        if snapshot.summary.degenerate { text += "Two strands overlap in the view. " }
        if let selected = snapshot.selected { text += "Point \(selected + 1) selected. " }
        text += "Moves \(play.spent) of \(play.level.allowance). "
        switch play.stage {
        case .won: text += "The knot matches."
        case .failed: text += "Out of moves."
        default: break
        }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(WaveKnotKeeperControls(port: port, mirror: mirror))
    }
}
#endif
