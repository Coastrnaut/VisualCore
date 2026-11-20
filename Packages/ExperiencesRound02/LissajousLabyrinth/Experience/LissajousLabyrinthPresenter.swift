// LissajousLabyrinthPresenter — feature 313 (R02-G02-03) T-R02G0203-006 (FR-R02G0203-003 … 005, 007; clarifications Q4,
// Q5). Draws the adapter's immutable snapshot with `LissajousLabyrinthThreadScene` at the host's quality tier (tier n
// is the catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the tracer head
// still under Reduce Motion (the snapshot time stays at 0 and the shimmer stops) and caps the glow under Reduce
// Flashing. A memory warning releases the GPU objects; the next frame rebuilds them. The presenter only reads
// `core.snapshot`: no drawing result reaches the kernel (renderer purity, R2-G02-INV-10).
#if os(iOS)
import Foundation
import LissajousLabyrinthCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

/// What the controls show: the latest state the presenter described.
@MainActor
@Observable
final class LissajousLabyrinthMirror {
    /// The four dials; nil before the first description.
    var dials: LissajousLabyrinthDials?
    /// The play's stage.
    var stage: LissajousLabyrinthStage = .loading
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The actions spent.
    var spent = 0
    /// The action allowance.
    var allowance = 0
    /// The text of the last refused change, if any.
    var message: String?
}

/// One entry of the tier log: the tier drawn and why it changed.
struct LissajousLabyrinthTierChange: Equatable {
    let tier: Int
    let reason: String
}

/// The presenter of Lissajous Labyrinth.
@MainActor
final class LissajousLabyrinthPresenter: ExperiencePresenter {
    typealias Core = LissajousLabyrinthExperienceCore

    let reduceMotion: Bool
    let reduceFlashing: Bool
    let mirror = LissajousLabyrinthMirror()
    let scene = LissajousLabyrinthThreadScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G0203-004).
    private(set) var tierLog: [LissajousLabyrinthTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: LissajousLabyrinthSceneSnapshot?

    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
    }

    /// The tests' seam: before `setup`, replaces the thread program's fragment source with one that does not compile.
    func breakThreadShader() {
        scene.threadFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    func draw(_ core: LissajousLabyrinthExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = LissajousLabyrinthTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(LissajousLabyrinthTierChange(tier: drawn.index, reason: reason))
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

    /// The dial names in control order.
    static let dialNames: [String] = ["frequency A", "frequency B", "phase A", "phase C"]

    func describe(_ core: LissajousLabyrinthExperienceCore) -> String {
        let play = core.play
        mirror.dials = play.dials
        mirror.stage = play.stage
        mirror.levelNumber = core.levelNumber
        mirror.spent = play.spent
        mirror.allowance = play.level.allowance
        let snapshot = core.snapshot(time: 0)
        var text = "Lissajous Labyrinth level \(core.levelNumber). "
        for (index, dial) in LissajousLabyrinthDial.allCases.enumerated() {
            text += "\(Self.dialNames[index].prefix(1).uppercased() + Self.dialNames[index].dropFirst()) \(play.dials[dial]). "
        }
        text += "\(snapshot.visits.count) of \(play.level.checkpoints.count) checkpoints in order. "
        if let obstacle = snapshot.contactObstacle { text += "The path touches obstacle \(obstacle + 1). " }
        text += "Actions \(play.spent) of \(play.level.allowance). "
        switch play.stage {
        case .won: text += "The path is safe."
        case .failed: text += "Out of actions."
        default: break
        }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(LissajousLabyrinthControls(port: port, mirror: mirror))
    }
}
#endif
