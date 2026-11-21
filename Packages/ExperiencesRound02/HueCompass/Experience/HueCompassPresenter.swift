// HueCompassPresenter — feature 333 (R02-G04-03) T-R02G0403-006 (FR-R02G0403-003, 004, 005, 007; clarifications Q2,
// Q4). Draws the adapter's immutable snapshot with `HueCompassCompassScene` at the host's quality tier (tier n is the
// catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the fog drift still under
// Reduce Motion (the snapshot time stays at 0) and caps the glow under Reduce Flashing. A memory warning releases the
// GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the
// kernel (renderer purity).
#if os(iOS)
import Foundation
import HueCompassCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

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
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    func teardown(_ context: RenderContext) {
        scene.release()
    }

    func shedCaches() {
        scene.release()
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
        AnyView(HueCompassControls(port: port, mirror: mirror))
    }
}
#endif
