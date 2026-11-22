// NocturneGardenPresenter — feature 383 (R02-G09-03) T-R02G0903-006 (FR-R02G0903-003, 004, 005, 007; clarifications
// Q2, Q4, Q5). Draws the adapter's immutable snapshot with `NocturneGardenGardenScene` at the host's quality tier (tier
// n is the catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the mist drift
// and the bloom sway still under Reduce Motion, and caps the glow under Reduce Flashing. The panel's picks (kind,
// column, row, size, bloom) live in the mirror as presentation state: a level opens with its first supplied kind,
// column 0, row 0, its smallest size and bloom 0, and the bloom pick is clamped to the blooms planted after every
// action, undo or redo; they never reach the kernel except through the declared controls. A memory warning releases
// the GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the
// kernel (renderer purity). Its probes (two ground corners) let the verification runner check a frame.
// Feature 384 (R02-G09-04): `pointer(_:viewSize:port:)` routes canvas touches through `NocturneGardenGestureController`
// (a tap on the bed plants the panel's kind and size, a bloom drag moves or removes it with the exact preview drawn and
// described, a pinch resizes, a lantern drag changes the sun, two fingers orbit, a double tap or "Reset view" resets);
// refused actions are shown and kept in `refusalLog` with their reason codes; the sun picker's "Set sun" reaches any
// allowed elevation in one move.
#if os(iOS)
import Foundation
import NocturneGardenCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show and choose: the latest state the presenter described and the panel's picks.
@MainActor
@Observable
final class NocturneGardenMirror {
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The moves spent and the budget.
    var moves = 0
    var budget = 0
    /// A one-line status (stage, failure).
    var status = ""
    /// The match and the leak in words.
    var measureLabel = ""
    /// The level in words.
    var targetLabel = ""
    /// The planted blooms in words, in canonical order.
    var bloomNames: [String] = []
    /// The picked kind's index in the kernel's kind order, 0 … 5.
    var kind = 0
    /// The picked anchor column and row.
    var column = 0
    var row = 0
    /// The picked size.
    var size = 1
    /// The picked bloom's index in canonical order.
    var bloom = 0
    /// The current sun elevation.
    var sun = 1
    /// The picked sun elevation (feature 384): "Set sun" sends it.
    var sunPick = 1
    /// The drag preview's words while a bloom is dragged (feature 384), or nil.
    var previewText: String?
    /// The play the picks are clamped against (a copy; never sent anywhere).
    var play: NocturneGardenPlay?
    /// The text of the last refused change, if any.
    var message: String?

    /// The picked kind in words.
    var kindLabel: String { "kind " + NocturneGardenKind.allCases[min(max(kind, 0), 5)].name }
    /// The picked column in words.
    var columnLabel: String { "column \(column)" }
    /// The picked row in words.
    var rowLabel: String { "row \(row)" }
    /// The picked size in words.
    var sizeLabel: String { "size \(size)" }
    /// The sun in words.
    var sunLabel: String { NocturneGardenLevel.sunName(sun) }
    /// The picked sun in words.
    var sunPickLabel: String { "picked " + NocturneGardenLevel.sunName(sunPick) }

    /// Moves the sun pick by `delta` over the level's allowed elevations, clamped (feature 384).
    func stepSun(_ delta: Int) {
        guard let play else { return }
        let allowed: [Int] = play.level.elevations.sorted()
        let at: Int = allowed.firstIndex(of: sunPick) ?? (allowed.firstIndex(of: sun) ?? 0)
        sunPick = allowed[min(max(at + delta, 0), allowed.count - 1)]
    }
    /// The picked bloom in words.
    var bloomLabel: String {
        bloomNames.indices.contains(bloom) ? bloomNames[bloom].capitalized : "no bloom planted"
    }

    /// Moves the kind pick by `delta` over the kinds the level supplies, wrapping.
    func pickKind(_ delta: Int) {
        guard let play else { return }
        let supplied: [Int] = Self.suppliedKinds(play.level)
        guard !supplied.isEmpty else { return }
        let at: Int = supplied.firstIndex(of: kind) ?? 0
        kind = supplied[((at + delta) % supplied.count + supplied.count) % supplied.count]
    }

    /// Moves the column pick by `delta`, clamped to the bed.
    func stepColumn(_ delta: Int) {
        guard let play else { return }
        column = min(max(column + delta, 0), play.level.width - 1)
    }

    /// Moves the row pick by `delta`, clamped to the bed.
    func stepRow(_ delta: Int) {
        guard let play else { return }
        row = min(max(row + delta, 0), play.level.height - 1)
    }

    /// Moves the size pick by `delta` over the level's allowed sizes, clamped.
    func stepSize(_ delta: Int) {
        guard let play else { return }
        let sizes: [Int] = play.level.sizes.sorted()
        let at: Int = sizes.firstIndex(of: size) ?? 0
        size = sizes[min(max(at + delta, 0), sizes.count - 1)]
    }

    /// Moves the bloom pick by `delta`, wrapping over the planted blooms.
    func pickBloom(_ delta: Int) {
        guard let play, !play.blooms.isEmpty else { return }
        let count: Int = play.blooms.count
        bloom = ((bloom + delta) % count + count) % count
    }

    /// Takes the new `play`: a new level resets the picks; otherwise the bloom pick is clamped to the blooms planted.
    func follow(_ play: NocturneGardenPlay) {
        let changedLevel: Bool = self.play?.level.id != play.level.id
        let sunChanged: Bool = sun != play.elevation
        self.play = play
        sun = play.elevation
        if changedLevel || sunChanged { sunPick = play.elevation }
        if changedLevel {
            kind = Self.suppliedKinds(play.level).first ?? 0
            column = 0
            row = 0
            size = play.level.sizes.min() ?? 1
            bloom = 0
        } else {
            bloom = min(bloom, max(play.blooms.count - 1, 0))
        }
    }

    /// The kind indices (kernel order) the level supplies, ascending.
    static func suppliedKinds(_ level: NocturneGardenLevel) -> [Int] {
        var result: [Int] = []
        for kind in NocturneGardenKind.allCases where level.supplyCount(kind) > 0 { result.append(kind.order) }
        return result
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct NocturneGardenTierChange: Equatable {
    let tier: Int
    let reason: String
}

/// The presenter of Nocturne Garden.
@MainActor
final class NocturneGardenPresenter: ExperiencePresenter {
    typealias Core = NocturneGardenExperienceCore

    let reduceMotion: Bool
    let reduceFlashing: Bool
    let mirror = NocturneGardenMirror()
    let scene = NocturneGardenGardenScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G0903-004).
    private(set) var tierLog: [NocturneGardenTierChange] = []
    /// The last snapshot drawn (tests and the description); never carries a drag's preview.
    private(set) var lastSnapshot: NocturneGardenSceneSnapshot?
    /// The play last drawn (the gestures read it).
    private(set) var lastPlay: NocturneGardenPlay?
    /// The gesture controller (feature 384): plant, drag with preview, pinch, sun, orbit.
    private(set) var gestures = NocturneGardenGestureController()
    /// The reason codes of refused actions, oldest first, at most ``refusalLogLimit`` (observability).
    private(set) var refusalLog: [String] = []
    /// The most refusal codes kept.
    static let refusalLogLimit = 64

    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
        scene.reduceMotion = reduceMotion
    }

    /// The tests' seam: before `setup`, replaces the garden program's fragment source with one that does not compile.
    func breakGardenShader() {
        scene.gardenFragment = "this is not a shader;"
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
    private func follow(_ core: NocturneGardenExperienceCore) {
        if mirror.play != core.play { mirror.follow(core.play) }
    }

    func draw(_ core: NocturneGardenExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = NocturneGardenTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(NocturneGardenTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        let time = reduceMotion ? 0 : frame.time
        let snapshot = core.snapshot(time: time)
        lastSnapshot = snapshot
        lastPlay = core.play
        scene.orbit = gestures.orbit
        let shown: NocturneGardenSceneSnapshot
        if let preview = gestures.preview {
            shown = snapshot.withPreview(preview.cells)
            mirror.previewText = preview.text
        } else {
            shown = snapshot
            mirror.previewText = nil
        }
        try scene.render(shown, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    func teardown(_ context: RenderContext) {
        scene.release()
    }

    func shedCaches() {
        scene.release()
    }

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the garden (the camera
    /// fits the scene inside a 5 % margin), are `dark` (the midnight ground) once a snapshot was drawn by the real
    /// scene; none otherwise.
    func probes(_ core: NocturneGardenExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "ground-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "ground-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    func describe(_ core: NocturneGardenExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        mirror.levelNumber = core.levelNumber
        mirror.moves = play.moves
        mirror.budget = level.budget
        mirror.bloomNames = play.blooms.indices.map { level.bloomName($0, bloom: play.blooms[$0]) }
        mirror.targetLabel = "Level: " + level.targetDescription()
        let match = play.match
        mirror.measureLabel = level.matchText(shared: match.shared, either: match.either) + "; "
            + level.leakText(play.leak) + "; " + NocturneGardenLevel.sunName(play.elevation)
        var text = "Nocturne Garden level \(core.levelNumber). "
        text += "\(play.moves) of \(level.budget) moves spent. \(mirror.measureLabel). "
        text += play.blooms.isEmpty ? "No bloom planted. " : mirror.bloomNames.joined(separator: "; ") + ". "
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "The shadow matches the target."
            mirror.status = "Won"
        case .failed, .result:
            let reason: String = play.failureReason ?? "The play failed."
            text += reason
            mirror.status = "Failed: " + reason
        default:
            mirror.status = play.moves == 0 ? "Ready" : "Playing"
        }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(NocturneGardenControls(port: port, mirror: mirror, resetView: { [weak self] in self?.resetView() },
                                       sender: { [weak self] control, values in
                                           self?.send(control, values, port: port)
                                       }))
    }

    // MARK: Touch controls (feature 384, R02-G09-04)

    /// The canvas gestures send plants, moves, removals, resizes and sun changes.
    var gestureActions: Set<String> { ["bloom.plant", "bloom.move", "bloom.remove", "bloom.resize", "sun.set"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(NocturneGardenExperienceCore.actionIDs) }

    /// What a gesture that would change a finished play shows.
    static let finishedMessage = "The play is over: undo or go to the next level"

    /// Routes a canvas touch through the gesture controller with the panel's kind and size and applies what it
    /// returns, in order: a chosen bloom goes to the mirror, every other action is sent through the port; a gesture that
    /// would change a finished play explains that the play is over.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let snapshot = lastSnapshot, let play = lastPlay else { return }
        let kind: NocturneGardenKind = NocturneGardenKind.allCases[min(max(mirror.kind, 0), 5)]
        let wasPlaying: Bool = play.stage == .playing
        let before: NocturneGardenGestureController.State = gestures.state
        let actions: [NocturneGardenGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: snapshot,
                                                                     play: play, kind: kind, size: mirror.size)
        if event.phase == .ended, !wasPlaying, actions.isEmpty,
           [.bedPress, .bloomDrag, .lanternDrag, .pinch].contains(before) {
            mirror.message = Self.finishedMessage
        }
        for action in actions {
            switch action {
            case let .plant(kind, column, row, size):
                send("bloom.plant", [Double(kind.order), Double(column), Double(row), Double(size)], port: port)
            case let .move(bloom, column, row):
                send("bloom.move", [Double(bloom), Double(column), Double(row)], port: port)
            case let .remove(bloom):
                send("bloom.remove", [Double(bloom)], port: port)
            case let .resize(bloom, size):
                send("bloom.resize", [Double(bloom), Double(size)], port: port)
            case let .sun(elevation):
                send("sun.set", [Double(elevation)], port: port)
            case let .choose(bloom):
                mirror.bloom = bloom
            case .resetView:
                break   // the controller has already returned to the authored orbit; the next frame draws it
            }
        }
    }

    /// Returns the camera to the authored view ("Reset view"; presentation only).
    func resetView() {
        gestures.resetView()
    }

    /// Sends `control` with `values`, shows a refusal in the panel and keeps its code in ``refusalLog``.
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        if result.isAccepted {
            mirror.message = nil
        } else {
            mirror.message = "That change was refused: \(result.code)"
            refusalLog.append(result.code)
            if refusalLog.count > Self.refusalLogLimit {
                refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit)
            }
        }
        return result
    }
}
#endif
