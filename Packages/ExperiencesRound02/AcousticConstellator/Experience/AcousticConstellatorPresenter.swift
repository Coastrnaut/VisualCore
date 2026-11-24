// AcousticConstellatorPresenter — feature 423 (R02-G13-03) T-R02G1303-006 (FR-R02G1303-003, 004, 005, 007;
// clarifications Q1, Q2, Q4, Q5). Draws the adapter's immutable snapshot with `AcousticConstellatorConstellationScene`
// at the host's quality tier (tier n is the catalog's `level-n`, richest first; the levels are the Core's
// `qualityTiers`), keeps a log of every tier change with its reason, draws the stars at tick 0 without pulsing and does
// not play the listen preview under Reduce Motion, and caps the glow under Reduce Flashing. The presentation time handed
// to the snapshot is the seconds since the play last changed: the presenter notes the frame time whenever the level,
// the links, the phases, the actions spent, the stage or the failure change, so the preview of the kernel's listen
// report plays from tick 0 after every change. The panel's choice (star, partner) lives in the mirror as presentation
// state: a level opens with star 0 and partner 1 chosen, both clamped to the level's stars; it never reaches the kernel
// except through the declared `link.add`, `link.remove` and `star.nudge` controls. A refused action is shown in words.
// A memory warning releases the GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no
// drawing result reaches the kernel (renderer purity). Its probes (two sky corners) let the verification runner check a
// frame.
#if os(iOS)
import AcousticConstellatorCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

/// What the controls show and choose: the latest state the presenter described and the panel's chosen star and
/// partner.
@MainActor
@Observable
final class AcousticConstellatorMirror {
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The actions left.
    var actionsLeft = 0
    /// The action budget.
    var budget = 0
    /// A one-line status: "Ready", "Playing", "Won" or "Failed: " and the failure in words (the progress has its
    /// own line, ``measureLabel``).
    var status = ""
    /// The failure in words, if the play failed.
    var failureText: String?
    /// The progress in words (the kernel's listen report of the current state, actions left).
    var measureLabel = ""
    /// The level in words.
    var targetLabel = ""
    /// The chosen star (0-based).
    var star = AcousticConstellatorExperienceCore.openingStar
    /// The chosen partner star (0-based).
    var partner = AcousticConstellatorExperienceCore.openingPartner
    /// The play the choice is clamped against (a copy; never sent anywhere).
    var play: AcousticConstellatorPlay?
    /// The text of the last refused change, if any.
    var message: String?

    /// The number of stars of the followed level (2 while no play is followed, so star 0 and partner 1 exist).
    var starCount: Int { max(play?.level.stars.count ?? 2, 1) }
    /// The chosen star in words.
    var starLabel: String { "star \(star)" }
    /// The chosen partner in words.
    var partnerLabel: String { "partner star \(partner)" }
    /// The chosen star in words with its rate and current phase, if a play is followed.
    var starDetail: String { detail(star) ?? starLabel }
    /// The chosen partner in words with its rate and current phase, if a play is followed.
    var partnerDetail: String { detail(partner).map { "partner " + $0 } ?? partnerLabel }
    /// Whether the chosen star and partner are linked in the followed play.
    var isLinked: Bool {
        guard let play, star != partner else { return false }
        return play.links.contains(AcousticConstellatorLink.between(star, partner))
    }
    /// The chosen pair in words: the link with its gap when linked, else that the stars are not linked.
    var choiceLabel: String {
        guard let play, star != partner, star >= 0, partner >= 0, star < play.phases.count,
              partner < play.phases.count else { return starLabel + ", " + partnerLabel }
        let link = AcousticConstellatorLink.between(star, partner)
        if isLinked { return play.level.linkName(link, phases: play.phases) }
        return "star \(link.a) and star \(link.b), not linked"
    }

    /// Star `index` in words with its rate and current phase; nil without a followed play or for an unknown star.
    private func detail(_ index: Int) -> String? {
        guard let play, index >= 0, index < play.level.stars.count, index < play.phases.count else { return nil }
        return play.level.starName(index, phase: play.phases[index])
    }

    /// Moves the chosen star by `delta`, clamped to the level's stars.
    func stepStar(_ delta: Int) { star = clampedStar(star + delta) }

    /// Moves the chosen partner by `delta`, clamped to the level's stars.
    func stepPartner(_ delta: Int) { partner = clampedStar(partner + delta) }

    /// `value` clamped to the stars of the followed level.
    func clampedStar(_ value: Int) -> Int { min(max(value, 0), starCount - 1) }

    /// Takes the new `play`: a new level chooses star 0 and partner 1; otherwise the choice is clamped.
    func follow(_ play: AcousticConstellatorPlay) {
        let changedLevel: Bool = self.play?.level.id != play.level.id
        self.play = play
        if changedLevel {
            star = clampedStar(AcousticConstellatorExperienceCore.openingStar)
            partner = clampedStar(AcousticConstellatorExperienceCore.openingPartner)
        } else {
            star = clampedStar(star)
            partner = clampedStar(partner)
        }
    }

    /// A refused action's reason code in words.
    static func refusalText(code: String) -> String {
        switch code {
        case "r02-g13.stage": "the play is over: undo or go to the next level"
        case "r02-g13.action": "that change is not allowed for these stars"
        case "r02-g13.stale": "the play changed before the action arrived"
        case "r02-g13.level": "the next level could not be made"
        case AcousticConstellatorExperienceRule.notWhole: "a star and a step must be whole numbers"
        default: "that action is not available now"
        }
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct AcousticConstellatorTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Acoustic Constellator.
@MainActor
final class AcousticConstellatorPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = AcousticConstellatorExperienceCore

    /// Whether the stars are drawn at tick 0 without pulsing and the preview is not played (Reduce Motion).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show and choose.
    let mirror = AcousticConstellatorMirror()
    /// The GL scene.
    let scene = AcousticConstellatorConstellationScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G1303-004).
    private(set) var tierLog: [AcousticConstellatorTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: AcousticConstellatorSceneSnapshot?

    /// What restarts the preview clock: the play's level, links, phases, actions spent, stage and failure.
    private struct PlayKey: Equatable {
        let levelNumber: Int
        let links: [AcousticConstellatorLink]
        let phases: [Int]
        let actionsSpent: Int
        let stage: AcousticConstellatorStage
        let failure: AcousticConstellatorFailure?
    }

    /// The play last seen and the frame time it was first drawn (the preview clock starts there).
    private var playKey: PlayKey?
    private var playStart: Double = 0

    /// A presenter with the given accessibility settings.
    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
        scene.reduceMotion = reduceMotion
    }

    /// The tests' seam: before `setup`, replaces the constellation program's fragment source with one that does not
    /// compile.
    func breakConstellationShader() {
        scene.constellationFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    /// Records the registry and the aspect.
    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    /// Follows the new drawable size.
    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    /// Follows `core`'s play in the mirror when it changed.
    private func follow(_ core: AcousticConstellatorExperienceCore) {
        if mirror.play != core.play { mirror.follow(core.play) }
    }

    /// The seconds since the play last changed at frame time `now`: the clock restarts whenever the level, the links,
    /// the phases, the actions spent, the stage or the failure change (a link, an unlink, a nudge, a listen, an undo, a
    /// redo or a new level).
    func previewTime(_ core: AcousticConstellatorExperienceCore, now: Double) -> Double {
        let play: AcousticConstellatorPlay = core.play
        let key = PlayKey(levelNumber: core.levelNumber, links: play.links, phases: play.phases,
                          actionsSpent: play.actionsSpent, stage: play.stage, failure: play.failure)
        if key != playKey {
            playKey = key
            playStart = now
        }
        let elapsed: Double = now - playStart
        return elapsed.isFinite ? max(0, elapsed) : 0
    }

    /// Draws `core` at host tier `tier`, logging tier changes.
    func draw(_ core: AcousticConstellatorExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = AcousticConstellatorTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(AcousticConstellatorTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        let time = previewTime(core, now: frame.time)
        let snapshot = core.snapshot(time: time)
        lastSnapshot = snapshot
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    /// Releases every GPU object.
    func teardown(_ context: RenderContext) {
        scene.release()
    }

    /// Releases every GPU object (memory warning); the next frame rebuilds them.
    func shedCaches() {
        scene.release()
    }

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the constellation and
    /// its gauges (the camera fits the scene inside a 6 % margin), are `dark` (the night sky) once a snapshot was drawn
    /// by the real scene; none otherwise.
    func probes(_ core: AcousticConstellatorExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "sky-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "sky-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// The state in words; also refreshes the mirror.
    func describe(_ core: AcousticConstellatorExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        let pairs: String = level.symbol.count == 1 ? "1 pair" : "\(level.symbol.count) pairs"
        mirror.targetLabel = "Level: link the symbol's \(pairs) among \(level.stars.count) stars and hold "
            + "\(level.hold) coherent ticks within \(level.window); threshold \(level.threshold), "
            + "\(level.fixedLinks.count) fixed links"
        let measure: String = play.progressDescription
        mirror.measureLabel = measure
        var text = "Acoustic Constellator level \(core.levelNumber). "
        text += measure + ". "
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "The symbol rings together."
            mirror.status = "Won"
            mirror.failureText = nil
        case .failed, .result:
            let reason: String = AcousticConstellatorSceneSnapshot.failureText(play.failure) ?? "The play failed."
            text += reason
            mirror.status = "Failed: " + reason
            mirror.failureText = reason
        default:
            mirror.status = play.records.isEmpty ? "Ready" : "Playing"
            mirror.failureText = nil
        }
        return text
    }

    /// The control panel.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(AcousticConstellatorControls(port: port, mirror: mirror))
    }
}
#endif
