// HueCompassPresenter — feature 333 (R02-G04-03) T-R02G0403-006 (FR-R02G0403-003, 004, 005, 007; clarifications Q2,
// Q4). Draws the adapter's immutable snapshot with `HueCompassCompassScene` at the host's quality tier (tier n is the
// catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the fog drift still under
// Reduce Motion (the snapshot time stays at 0) and caps the glow under Reduce Flashing. A memory warning releases the
// GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the
// kernel (renderer purity).
// Feature 334 (R02-G04-04) T-R02G0404-005 (FR-R02G0404-001 … 005; clarifications Q3, Q4): canvas touches go through
// `HueCompassGestureController` with the drawn view size and the last drawn snapshot: a released swipe sends one
// `compass.turn [steps]`, a tap on the hub one `compass.probe`; two fingers orbit the camera and a double tap on empty
// space or `resetView()` ("Reset view") returns to the authored view (presentation only: never in the digest or the
// snapshot). While a swipe previews a bearing the scene draws a ghost needle there and the description reads "Turning
// to bearing n of 96"; a refused action is shown with its reason.
#if os(iOS)
import Foundation
import HueCompassCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show: the latest state the presenter described.
@MainActor
@Observable
final class HueCompassMirror {
    /// The compass bearing, 0 … 95.
    var bearing = 0
    /// The hue band under the needle, 0 … 23.
    var bandUnderNeedle = 0
    /// The band the picker holds for the next selection, 0 … 23 (presentation only).
    var pickedBand = 0
    /// The play's stage.
    var stage: HueCompassStage = .loading
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The units spent and the allowance.
    var spent = 0
    var allowance = 0
    /// The number of clues seen.
    var clueCount = 0
    /// The text of the last refused change, if any.
    var message: String?
}

/// One entry of the tier log: the tier drawn and why it changed.
struct HueCompassTierChange: Equatable {
    let tier: Int
    let reason: String
}

/// The presenter of Hue Compass.
@MainActor
final class HueCompassPresenter: ExperiencePresenter {
    typealias Core = HueCompassExperienceCore

    let reduceMotion: Bool
    let reduceFlashing: Bool
    let mirror = HueCompassMirror()
    let scene = HueCompassCompassScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G0403-004).
    private(set) var tierLog: [HueCompassTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: HueCompassSceneSnapshot?
    /// The gesture controller (feature 334): swipes, hub taps, orbit and the swipe preview.
    private(set) var gestures = HueCompassGestureController()

    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
    }

    /// The tests' seam: before `setup`, replaces the glass program's fragment source with one that does not compile.
    func breakGlassShader() {
        scene.glassFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    func draw(_ core: HueCompassExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = HueCompassTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(HueCompassTierChange(tier: drawn.index, reason: reason))
        }
        let time = reduceMotion ? 0 : frame.time
        let snapshot = core.snapshot(time: time)
        lastSnapshot = snapshot
        scene.orbit = gestures.orbit
        scene.previewBearing = gestures.previewBearing
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    func teardown(_ context: RenderContext) {
        scene.release()
    }

    func shedCaches() {
        scene.release()
    }

    // MARK: Touch controls (feature 334)

    /// The canvas gestures send turns and probes only.
    var gestureActions: Set<String> { ["compass.turn", "compass.probe"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(HueCompassExperienceCore.actionIDs) }

    /// Routes a canvas touch through the gesture controller; a released swipe or a hub tap sends its one action.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let snapshot = lastSnapshot else { return }
        let actions: [HueCompassGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: snapshot)
        for action in actions {
            switch action {
            case .turn(let steps):
                send("compass.turn", [Double(steps)], port: port)
            case .probe:
                send("compass.probe", [], port: port)
            case .resetView:
                break   // the controller has already returned to the authored orbit; the next frame draws it
            }
        }
    }

    /// Drops a touch in progress (the shell suspends the experience): a gesture under way is abandoned without an
    /// action by starting a fresh controller, which forgets the fingers it held. The orbit is presentation only and
    /// never saved (clarification Q3), so the camera returns to the authored view with it.
    func cancelPointers() {
        gestures.cancel()
    }

    /// Returns the camera to the authored view ("Reset view").
    func resetView() {
        gestures.resetView()
    }

    /// Sends `control` with `values`; a refusal is shown with its reason.
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        mirror.message = result.isAccepted ? nil : "That change was refused: \(result.code)"
        return result
    }

    func describe(_ core: HueCompassExperienceCore) -> String {
        let play = core.play
        let snapshot = core.snapshot(time: 0)
        let band = snapshot.band(of: snapshot.bearing)
        mirror.bearing = snapshot.bearing
        mirror.bandUnderNeedle = band
        mirror.stage = play.stage
        mirror.levelNumber = core.levelNumber
        mirror.spent = play.spent
        mirror.allowance = play.level.allowance
        mirror.clueCount = snapshot.clues.count
        var text = "Hue Compass level \(core.levelNumber). "
        text += "The needle points to bearing \(snapshot.bearing) of 96, hue band \(band + 1) of 24. "
        let density: Int = snapshot.fog.indices.contains(snapshot.bearing) ? snapshot.fog[snapshot.bearing] : 0
        if let preview = gestures.previewBearing {
            text += "Turning to bearing \(preview) of 96. "
        }
        text += "Fog density here \(density) of 9. "
        if let clue = snapshot.clues.last {
            text += "Last clue at bearing \(clue.bearing): hue gap \(clue.hueGap), depth \(clue.depth). "
        }
        text += "\(snapshot.clues.count) clues seen. "
        if let selection = snapshot.selection {
            text += "Selected bearing \(selection.bearing), band \(selection.band + 1). "
        }
        text += "Units \(play.spent) of \(play.level.allowance). "
        switch play.stage {
        case .won: text += "The bearing and hue match."
        case .failed: text += "The search failed."
        default: break
        }
        if let target = snapshot.target { text += " The target was bearing \(target)." }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(HueCompassControls(port: port, mirror: mirror, resetView: { [weak self] in self?.resetView() }))
    }
}
#endif
