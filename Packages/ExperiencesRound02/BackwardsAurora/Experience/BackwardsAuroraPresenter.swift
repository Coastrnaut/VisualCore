// BackwardsAuroraPresenter — feature 393 (R02-G10-03) T-R02G1003-006 (FR-R02G1003-003, 004, 005, 007; clarifications
// Q2, Q4, Q5). Draws the adapter's immutable snapshot with `BackwardsAuroraAuroraScene` at the host's quality tier (tier
// n is the catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the pulses and
// the shimmer still under Reduce Motion, and caps the glow under Reduce Flashing. The panel's chosen section (start,
// end) lives in the mirror as presentation state: a level opens with start 0 and end 1, both clamped to the wave; it
// never reaches the kernel except through the declared `wave.reverse` control. A memory warning releases the GPU
// objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the kernel
// (renderer purity). Its probes (two ground corners) let the verification runner check a frame.
#if os(iOS)
import BackwardsAuroraCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

/// What the controls show and choose: the latest state the presenter described and the panel's section.
@MainActor
@Observable
final class BackwardsAuroraMirror {
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The reversals spent and the budget.
    var spent = 0
    var budget = 0
    /// A one-line status (stage, failure).
    var status = ""
    /// The checkpoints, the worst bend and the distance in words.
    var measureLabel = ""
    /// The level in words.
    var targetLabel = ""
    /// The chosen section's start and end.
    var start = 0
    var end = 1
    /// The play the section is clamped against (a copy; never sent anywhere).
    var play: BackwardsAuroraPlay?
    /// The text of the last refused change, if any.
    var message: String?

    /// The wave's sample count (12 while no play is followed).
    var count: Int { play?.wave.count ?? 12 }
    /// The chosen start in words.
    var startLabel: String { "start at sample \(start)" }
    /// The chosen end in words.
    var endLabel: String { "end at sample \(end)" }
    /// The chosen section in words.
    var sectionLabel: String { "section \(start) to \(end), \(end - start + 1) samples" }

    /// Moves the start by `delta`, clamped to 0 … N − 2; the end follows to stay after it.
    func stepStart(_ delta: Int) {
        start = min(max(start + delta, 0), count - 2)
        if end <= start { end = start + 1 }
    }

    /// Moves the end by `delta`, clamped to 1 … N − 1; the start follows to stay before it.
    func stepEnd(_ delta: Int) {
        end = min(max(end + delta, 1), count - 1)
        if start >= end { start = end - 1 }
    }

    /// Takes the new `play`: a new level resets the section to 0 … 1; otherwise it is clamped to the wave.
    func follow(_ play: BackwardsAuroraPlay) {
        let changedLevel: Bool = self.play?.level.id != play.level.id
        self.play = play
        if changedLevel {
            start = 0
            end = 1
        } else {
            stepStart(0)
            stepEnd(0)
        }
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct BackwardsAuroraTierChange: Equatable {
    let tier: Int
    let reason: String
}

/// The presenter of Backwards Aurora.
@MainActor
final class BackwardsAuroraPresenter: ExperiencePresenter {
    typealias Core = BackwardsAuroraExperienceCore

    let reduceMotion: Bool
    let reduceFlashing: Bool
    let mirror = BackwardsAuroraMirror()
    let scene = BackwardsAuroraAuroraScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G1003-004).
    private(set) var tierLog: [BackwardsAuroraTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: BackwardsAuroraSceneSnapshot?

    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
        scene.reduceMotion = reduceMotion
    }

    /// The tests' seam: before `setup`, replaces the aurora program's fragment source with one that does not compile.
    func breakAuroraShader() {
        scene.auroraFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    /// Follows `core`'s play in the mirror when it changed.
    private func follow(_ core: BackwardsAuroraExperienceCore) {
        if mirror.play != core.play { mirror.follow(core.play) }
    }

    func draw(_ core: BackwardsAuroraExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = BackwardsAuroraTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(BackwardsAuroraTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        let time = reduceMotion ? 0 : frame.time
        let snapshot = core.snapshot(sectionStart: mirror.start, sectionEnd: mirror.end, time: time)
        lastSnapshot = snapshot
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    func teardown(_ context: RenderContext) {
        scene.release()
    }

    func shedCaches() {
        scene.release()
    }

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the aurora (the camera
    /// fits the scene inside a 5 % margin), are `dark` (the midnight ground) once a snapshot was drawn by the real
    /// scene; none otherwise.
    func probes(_ core: BackwardsAuroraExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "ground-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "ground-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    func describe(_ core: BackwardsAuroraExperienceCore) -> String {
        let play = core.play
        let level = play.level
        let wave = play.wave
        follow(core)
        mirror.levelNumber = core.levelNumber
        mirror.spent = play.spent
        mirror.budget = level.budget
        mirror.targetLabel = "Level: " + level.targetDescription()
        var checkpoints: [String] = []
        for index in level.checkpoints.indices { checkpoints.append(level.checkpointName(index, wave: wave)) }
        let distance = play.distance
        mirror.measureLabel = level.bendDescription(wave) + "; distance \(distance.numerator)/\(distance.denominator); "
            + BackwardsAuroraLevel.reversalsText(play.remaining)
        var text = "Backwards Aurora level \(core.levelNumber). "
        text += "\(play.spent) of \(level.budget) reversals spent. \(mirror.measureLabel). "
        text += checkpoints.joined(separator: "; ") + ". "
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "Every checkpoint matches and every bend is within the limit."
            mirror.status = "Won"
        case .failed, .result:
            let reason: String = BackwardsAuroraSceneSnapshot.failureText(play.failure, budget: level.budget)
                ?? "The play failed."
            text += reason
            mirror.status = "Failed: " + reason
        default:
            mirror.status = play.spent == 0 ? "Ready" : "Playing"
        }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(BackwardsAuroraControls(port: port, mirror: mirror))
    }
}
#endif
