// FacetedForgePresenter — feature 373 (R02-G08-03) T-R02G0803-006 (FR-R02G0803-003, 004, 005, 007; clarifications
// Q2, Q4, Q5). Draws the adapter's immutable snapshot with `FacetedForgeCrystalScene` at the host's quality tier (tier
// n is the catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the shimmer
// still and shows the opening without easing under Reduce Motion, and caps the glow under Reduce Flashing. The preview
// choice (piece, direction, depth) lives in the mirror as presentation state: it starts at piece 0, direction 0 and
// the middle crossing depth, and is clamped to the play after every cut, undo or redo; it never reaches the kernel. A
// memory warning releases the GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no
// drawing result reaches the kernel (renderer purity). Its probes (two ground corners) let the verification runner
// check a frame.
#if os(iOS)
import FacetedForgeCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

/// What the controls show and choose: the latest state the presenter described and the preview choice.
@MainActor
@Observable
final class FacetedForgeMirror {
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The cuts spent and the budget.
    var cuts = 0
    var budget = 0
    /// A one-line status (stage, failure).
    var status = ""
    /// The target in words.
    var targetLabel = ""
    /// Each piece in words, in canonical order.
    var pieceNames: [String] = []
    /// The preview choice (presentation only).
    var choice = FacetedForgePreviewChoice(piece: 0, direction: 0, depth: 0)
    /// The play the choice is clamped against (a copy; never sent anywhere).
    var play: FacetedForgePlay?
    /// The text of the last refused change, if any.
    var message: String?

    /// The chosen piece in words.
    var pieceLabel: String {
        pieceNames.indices.contains(choice.piece) ? pieceNames[choice.piece].capitalized : "none"
    }

    /// The chosen direction in words.
    var directionLabel: String { "direction " + FacetedForgeDirection.all[choice.direction].name }

    /// The chosen depth in words.
    var depthLabel: String { "depth \(choice.depth)" }

    /// Moves the piece pick by `delta`, wrapping; the depth moves to the middle crossing depth of the new piece.
    func pickPiece(_ delta: Int) {
        guard let play, !play.pieces.isEmpty else { return }
        let count = play.pieces.count
        let piece = ((choice.piece + delta) % count + count) % count
        choice = Self.middle(FacetedForgePreviewChoice(piece: piece, direction: choice.direction, depth: 0), play)
    }

    /// Moves the direction pick by `delta`, wrapping over the 13 directions; the depth moves to the middle crossing
    /// depth.
    func pickDirection(_ delta: Int) {
        guard let play else { return }
        let count = FacetedForgeDirection.all.count
        let direction = ((choice.direction + delta) % count + count) % count
        choice = Self.middle(FacetedForgePreviewChoice(piece: choice.piece, direction: direction, depth: 0), play)
    }

    /// Moves the depth by `step` crossing depths of the chosen piece.
    func stepDepth(_ step: Int) {
        guard let play else { return }
        choice = choice.steppingDepth(step, in: play)
    }

    /// Takes the new `play` and clamps the choice to it (after a cut, undo, redo or a new level).
    func follow(_ play: FacetedForgePlay) {
        let changedLevel = self.play?.level.id != play.level.id
        self.play = play
        choice = changedLevel ? FacetedForgePreviewChoice.initial(play) : choice.clamped(to: play)
    }

    /// `choice` with its depth set to the middle of the depths whose plane crosses its piece.
    static func middle(_ choice: FacetedForgePreviewChoice, _ play: FacetedForgePlay) -> FacetedForgePreviewChoice {
        guard play.pieces.indices.contains(choice.piece) else { return choice.clamped(to: play) }
        var crossing: [Int] = []
        for depth in FacetedForgeHalfSpace.depths
        where play.pieces[choice.piece].isCrossed(direction: choice.direction, depth: depth) {
            crossing.append(depth)
        }
        guard !crossing.isEmpty else { return choice }
        return FacetedForgePreviewChoice(piece: choice.piece, direction: choice.direction,
                                         depth: crossing[crossing.count / 2])
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct FacetedForgeTierChange: Equatable {
    let tier: Int
    let reason: String
}

/// The presenter of Faceted Forge.
@MainActor
final class FacetedForgePresenter: ExperiencePresenter {
    typealias Core = FacetedForgeExperienceCore

    let reduceMotion: Bool
    let reduceFlashing: Bool
    let mirror = FacetedForgeMirror()
    let scene = FacetedForgeCrystalScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G0803-004).
    private(set) var tierLog: [FacetedForgeTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: FacetedForgeSceneSnapshot?

    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
        scene.reduceMotion = reduceMotion
    }

    /// The tests' seam: before `setup`, replaces the crystal program's fragment source with one that does not compile.
    func breakCrystalShader() {
        scene.crystalFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    /// The preview choice of `core`'s play, following it when the play changed.
    private func choice(for core: FacetedForgeExperienceCore) -> FacetedForgePreviewChoice {
        if mirror.play != core.play { mirror.follow(core.play) }
        return mirror.choice
    }

    func draw(_ core: FacetedForgeExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = FacetedForgeTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(FacetedForgeTierChange(tier: drawn.index, reason: reason))
        }
        let time = reduceMotion ? 0 : frame.time
        let snapshot = core.snapshot(choice: choice(for: core), time: time)
        lastSnapshot = snapshot
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    func teardown(_ context: RenderContext) {
        scene.release()
    }

    func shedCaches() {
        scene.release()
    }

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the crystal (the camera
    /// fits the scene inside a 5 % margin), are `dark` (the ground clear) once a snapshot was drawn by the real scene;
    /// none otherwise.
    func probes(_ core: FacetedForgeExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "ground-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "ground-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// Piece `index` of `play` in words: "piece 2: a quarter of the crystal, 6 faces" (the whole crystal is named as
    /// such).
    static func pieceName(_ index: Int, _ play: FacetedForgePlay) -> String {
        let share = play.shares[index]
        let faces = play.pieces[index].faceCount
        if share == .one { return "piece \(index + 1): the whole crystal, \(faces) faces" }
        return play.level.pieceName(index, share: share, faces: faces)
    }

    func describe(_ core: FacetedForgeExperienceCore) -> String {
        let play = core.play
        let level = play.level
        let choice = choice(for: core)
        mirror.levelNumber = core.levelNumber
        mirror.cuts = play.cuts
        mirror.budget = level.budget
        mirror.pieceNames = play.pieces.indices.map { Self.pieceName($0, play) }
        mirror.targetLabel = "Target: " + level.targetDescription()
        var text = "Faceted Forge level \(core.levelNumber). "
        text += "\(play.cuts) of \(level.budget) cuts spent. Target: \(level.targetDescription()). "
        text += "\(play.pieces.count) " + (play.pieces.count == 1 ? "piece: " : "pieces: ")
        text += mirror.pieceNames.joined(separator: "; ") + ". "
        text += "Next cut: piece \(choice.piece + 1), direction \(FacetedForgeDirection.all[choice.direction].name), "
        text += "depth \(choice.depth). "
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "The pieces match the target."
            mirror.status = "Won"
        case .failed, .result:
            let reason: String
            switch play.failure {
            case .sliver(let piece, let cut):
                reason = "Cut \(cut + 1) left piece \(piece + 1) thinner than the sliver limit."
            case .budget, .none: reason = "The cut budget ran out before the pieces matched the target."
            }
            text += reason
            mirror.status = "Failed: " + reason
        default:
            mirror.status = play.cuts == 0 ? "Ready" : "Playing"
        }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(FacetedForgeControls(port: port, mirror: mirror))
    }
}
#endif
