// AuroraLoomPresenter — feature 303 (R02-G01-03) T-R02G0103-006 (FR-R02G0103-003 … 005, 007; clarifications Q4, Q5).
// Draws the adapter's immutable snapshot with `AuroraLoomRibbonScene` at the host's quality tier (tier n is the
// catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the silk still under
// Reduce Motion (the snapshot time stays at 0 and the wave and shimmer stop) and caps the glow under Reduce Flashing.
// A memory warning releases the GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`:
// no drawing result reaches the kernel (renderer purity, R2-G01-INV-10). Feature 304 (R02-G01-04) T-R02G0104-004 routes
// canvas touches through `AuroraLoomGestureController`: one finger drags an anchor or a dial and sends one `ribbon.move` on
// release, two fingers orbit the camera (presentation only), and the selection and the drag preview are mirrored for the
// scene, the description and the controls.
#if os(iOS)
import AuroraLoomCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

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
    /// The selected ribbon (0 … 2).
    var selectedRibbon = 0
    /// The step a drag would set, while dragging.
    var preview: AuroraLoomMove?
    /// The text of the last refused move, if any.
    var message: String?
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
    /// The touch controls: arbitration, drags, orbit and selection.
    private(set) var gestures = AuroraLoomGestureController()
    /// The steps and whether the level is playing, from the latest core the presenter saw.
    private var latest: (steps: AuroraLoomSteps, playing: Bool)?

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
        latest = (core.play.steps, core.play.stage == .playing)
        scene.orbit = gestures.orbit
        scene.selectedRibbon = gestures.selectedRibbon
        scene.preview = gestures.preview
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    func teardown(_ context: RenderContext) {
        scene.release()
    }

    func shedCaches() {
        scene.release()
    }

    // MARK: Touch controls

    /// The canvas gestures send kernel moves only.
    var gestureActions: Set<String> { ["ribbon.move"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { ["ribbon.move", "play.undo", "play.redo", "level.next"] }

    /// Routes a touch through the gesture controller; a finished drag that changed a step sends one `ribbon.move`.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let latest else { return }
        let move = gestures.handle(event, viewSize: viewSize, steps: latest.steps, playing: latest.playing)
        mirror.selectedRibbon = gestures.selectedRibbon
        mirror.preview = gestures.preview
        guard let move else { return }
        let control: Double = move.control == .wave ? 0 : 1
        let result = port.send("ribbon.move", [Double(move.ribbon), control, Double(move.step)])
        mirror.message = result.isAccepted ? nil : "That move was refused: \(result.code)"
    }

    /// Ends every touch without a move.
    func cancelPointers() {
        gestures.cancel()
        mirror.preview = nil
    }

    /// Returns the camera to the authored pose.
    func resetView() {
        gestures.resetOrbit()
    }

    /// Selects `ribbon` (the steppers call this).
    func select(ribbon: Int) {
        gestures.select(ribbon: ribbon)
        mirror.selectedRibbon = gestures.selectedRibbon
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
        let selected = gestures.selectedRibbon
        text += "Ribbon \(selected + 1) selected: wave \(play.steps.wave[selected]), phase \(play.steps.phase[selected]). "
        if let preview = gestures.preview {
            text += "Dragging ribbon \(preview.ribbon + 1) \(preview.control == .wave ? "wave" : "phase") to \(preview.step). "
        }
        switch play.stage {
        case .won: text += "The loom is in harmony."
        case .failed: text += "Out of moves."
        default: break
        }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(AuroraLoomControls(port: port, mirror: mirror, resetView: { [weak self] in self?.resetView() },
                                   select: { [weak self] ribbon in self?.select(ribbon: ribbon) }))
    }
}
#endif
