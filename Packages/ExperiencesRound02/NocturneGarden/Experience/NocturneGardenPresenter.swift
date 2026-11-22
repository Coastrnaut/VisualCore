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
// Feature 385 (R02-G09-05) T-R02G0905-005 (FR-R02G0905-001 … 005): the mirror carries the tutorial instruction, the
// hint revealed so far (`showHint()` reveals the next of three levels; the bounded search runs off the main actor and
// any change of the play hides it), the failure explanation, the mode, the open levels with their stars and the goal;
// `retry` starts the level again in its mode, `undoMove` takes back the last move, and the daily level is chosen from
// the local calendar date read here (`playDaily(port:date:)`), never in the core.
// Feature 386 (R02-G09-06) T-R02G0906-005 (FR-R02G0906-001 … 006; clarifications Q1 … Q5): the presenter routes
// `NocturneGardenFeedbackPlan.after(old:new:)` (an announcement and a haptic) through its feedback route (`feedback`,
// injectable; the shared `ExperienceFeedback` by default) and keeps a feedback log; refusals are shown and announced in
// words (`refused(code:)`), and a revealed hint is announced as `state`; picker changes and drag previews are not
// announced (the pickers speak their values). The scene's lights (`NocturneGardenLights`: the blooms' glow and the leak
// crosses) step toward the drawn snapshot every frame (0.15 s fades, 0.45 s under Reduce Flashing). The ambient loop
// (`NocturneGardenSound`) is offered the recipe of the planted blooms, the sun and the stage (`NocturneGardenSoundRecipe`)
// when a level or mode opens and when that recipe changes. The mirror carries the summary element's text and the sound
// choice. Presentation only.
// Feature 387 (R02-G09-07) T-R02G0907-005 (clarifications Q2, Q4, Q5): the mirror carries whether a verified replay
// exists for the level and the replay position; `startReplay`, `stepReplay` and `stopReplay` send `replay.start
// [level]`, `replay.step` and `replay.stop`; the Sound toggle saves the choice through `settings.sound [0/1]`
// (`saveSound(on:port:)`), and the restored choice (`core.soundOn`) is applied when the experience opens or the value
// changes; the results a restore dropped (`core.reconciliationDropped`) are announced once as `state` ("n saved
// results could not be checked and were removed.", "1 saved result could not be checked and was removed.").
#if os(iOS)
import Foundation
import NocturneGardenCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation
import VisualCoreAudioDSP

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
    /// The tutorial instruction; nil when the tutorial is done (feature 385).
    var instruction: String?
    /// The hint level revealed (0 … 3) and its text (feature 385).
    var hintLevel = 0
    var hintText: String?
    /// The failure explanation while the play has failed (feature 385).
    var failureText: String?
    /// The mode (feature 385).
    var mode: NocturneGardenMode = .campaign
    /// The highest open level and the stars of each won level (feature 385).
    var frontier = 1
    var stars: [Int: Int] = [:]
    /// The certified smallest move count of the current level (the goal, feature 385).
    var smallest = 0
    /// The level the picker holds, 1 … 100 (presentation only; only open levels can be chosen).
    var pickedLevel = 1
    /// The play the picks are clamped against (a copy; never sent anywhere).
    var play: NocturneGardenPlay?
    /// The text of the last refused change, if any.
    var message: String?
    /// The summary element's text (feature 386).
    var summary = ""
    /// Whether the ambient sound is on (feature 386; off by default).
    var soundOn = false
    /// Whether the current level has a verified solution to replay (feature 387).
    var replayAvailable = false
    /// Whether a replay is running (feature 387).
    var replaying = false
    /// The moves of the running replay played so far (0 when no replay runs; feature 387).
    var replayPosition = 0
    /// The moves of the running replay's trace (0 when no replay runs; feature 387).
    var replayLength = 0

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
    /// The picked bloom in words, its first letter upper case ("Bloom 1: rose at column 2, row 3, size 1"; feature 386:
    /// only the first letter, so VoiceOver reads the name as written).
    var bloomLabel: String {
        guard bloomNames.indices.contains(bloom) else { return "no bloom planted" }
        let name: String = bloomNames[bloom]
        return name.prefix(1).uppercased() + name.dropFirst()
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
    /// The latest core described (feature 385): hints and retry read it.
    private(set) var latestCore: NocturneGardenExperienceCore?
    /// The play the shown hint belongs to (level, mode and fingerprint); nil when no hint is shown (feature 385).
    private var hintKey: String?
    /// The hint searched for a play, by that play's key: one search per play, every level from it (feature 385).
    private var hintCache: (key: String, hints: [NocturneGardenHint?])?
    /// The search under way, off the main actor, for the play of ``hintKey`` (feature 385).
    private(set) var hintSearch: Task<Void, Never>?
    /// The text shown while the search runs.
    static let searchingText = "Finding a hint…"
    /// The date whose daily level is being played, so Retry restarts that level after midnight too (feature 385).
    private(set) var dailyDate: DateComponents?

    /// The feedback route of announcements and haptics (feature 386; tests inject their own).
    var feedback: ExperienceFeedback = .shared
    /// Every routed feedback plan, oldest first (feature 386; tests and diagnostics).
    private(set) var feedbackLog: [NocturneGardenFeedbackPlan] = []
    /// The eased light levels drawn by the scene (feature 386).
    private(set) var lights: NocturneGardenLights
    /// The frame time of the last draw, for easing the lights; nil before the first frame (which settles them).
    private var lastFrameTime: Double?
    /// The ambient sound (feature 386).
    let sound: NocturneGardenSound
    /// The last leaking cells drawn, so their crosses can fade out after an undo (feature 386).
    private(set) var fadingLeak: [Int] = []

    init(reduceMotion: Bool, reduceFlashing: Bool) {
        lights = NocturneGardenLights(reducedFlash: reduceFlashing)
        sound = NocturneGardenSound(recipe: NocturneGardenSoundRecipe.recipe(blooms: 0, sun: 1, stage: .loading))
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
        // The lights settle on the very first frame only; every later change, a level change included, fades.
        if let last = lastFrameTime {
            lights.step(toward: snapshot, elapsed: frame.time > last ? frame.time - last : 0)
        } else {
            lights.settle(to: snapshot)
        }
        lastFrameTime = frame.time
        // The crosses fade out where the leak was after an undo (the last leaking cells).
        if snapshot.leakFailure {
            fadingLeak = snapshot.leaking
        } else if lights.leak <= 0 {
            fadingLeak = []
        }
        scene.lights = lights
        scene.fadingLeak = fadingLeak
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
        let previous: NocturneGardenExperienceCore? = latestCore
        absorbProgress(core)
        if let previous {
            route(NocturneGardenFeedbackPlan.after(old: previous, new: core))
            let opened: Bool = previous.levelNumber != core.levelNumber || previous.mode != core.mode
            if opened || Self.recipe(previous) != Self.recipe(core) { sound.offer(Self.recipe(core)) }
        } else {
            // The first described state offers its recipe, so the sound never holds a placeholder.
            sound.offer(Self.recipe(core))
        }
        mirror.summary = NocturneGardenFeedbackPlan.summaryText(core: core)
        // Feature 387: the saved sound choice is applied when it first appears or changes.
        if previous == nil || previous?.soundOn != core.soundOn {
            if core.soundOn { sound.offer(Self.recipe(core)) }
            sound.setWanted(core.soundOn)
            mirror.soundOn = core.soundOn
        }
        if !droppedAnnounced, core.reconciliationDropped > 0 {
            droppedAnnounced = true
            route(NocturneGardenFeedbackPlan(text: Self.droppedText(core.reconciliationDropped), kind: .state,
                                             haptic: nil))
        }
        if let result = core.progress.solved[core.levelNumber] {
            mirror.replayAvailable = result.verified && !result.trace.isEmpty && !Self.isReplay(core.mode)
        } else {
            mirror.replayAvailable = false
        }
        if case .replay(let level) = core.mode {
            mirror.replaying = true
            mirror.replayPosition = core.play.records.count
            mirror.replayLength = core.progress.solved[level]?.trace.count ?? 0
        } else {
            mirror.replaying = false
            mirror.replayPosition = 0
            mirror.replayLength = 0
        }
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
        if let preview = mirror.previewText { text += "Dragging: \(preview). " }   // T-R02G0904-014
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "The shadow matches the target."
            if let stars = mirror.stars[core.levelNumber] { text += " Stars: \(stars) of 3." }
            mirror.status = "Won"
        case .failed, .result:
            let reason: String = mirror.failureText ?? play.failureReason ?? "The play failed."
            text += reason
            mirror.status = "Failed: " + reason
        default:
            mirror.status = play.moves == 0 ? "Ready" : "Playing"
        }
        if let instruction = mirror.instruction { text += " Tutorial: " + instruction }
        if let hint = mirror.hintText { text += " Hint: " + hint }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(NocturneGardenControls(port: port, mirror: mirror, presenter: self,
                                       resetView: { [weak self] in self?.resetView() },
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

    // MARK: Teaching and progression (feature 385, R02-G09-05)

    /// Takes the core's teaching and progress state into the mirror: the tutorial instruction, the failure
    /// explanation, the mode, the open levels with their stars and the goal; a change of the play hides the hint.
    private func absorbProgress(_ core: NocturneGardenExperienceCore) {
        if latestCore?.levelNumber != core.levelNumber { mirror.pickedLevel = core.levelNumber }
        latestCore = core
        if let key = hintKey, key != Self.hintKey(core) { clearHint() }
        mirror.instruction = core.tutorial == .done ? nil : core.tutorial.text
        mirror.failureText = NocturneGardenFailureExplanation(play: core.play)?.text
        mirror.mode = core.mode
        mirror.frontier = core.progress.frontier
        var stars: [Int: Int] = [:]
        for (number, result) in core.progress.solved { stars[number] = result.stars }
        mirror.stars = stars
        mirror.smallest = core.certifiedSmallest
    }

    /// The key of the play a hint belongs to: level, mode and fingerprint.
    private static func hintKey(_ core: NocturneGardenExperienceCore) -> String {
        "\(core.levelNumber)/\(core.mode)/\(core.play.fingerprint)"
    }

    /// Hides the hint shown and drops a search under way.
    private func clearHint() {
        hintSearch?.cancel()
        hintSearch = nil
        hintKey = nil
        mirror.hintLevel = 0
        mirror.hintText = nil
    }

    /// Reveals the next hint level (up to 3) for the current play; the hint is hidden when the play has none (won).
    /// Hints never change the state: no action is sent. The bounded search runs once per play in a detached task,
    /// never on the frame: meanwhile the panel reads "Finding a hint…", and the result is shown only if the play it
    /// belongs to is still the current one; later levels come from the cache.
    func showHint() {
        guard let core = latestCore else { return }
        let key: String = Self.hintKey(core)
        let next: Int = hintKey == key ? min(mirror.hintLevel + 1, 3) : 1
        if let cached = hintCache, cached.key == key {
            reveal(cached.hints, level: next, key: key)
            return
        }
        guard hintSearch == nil || hintKey != key else { return }   // the search for this play is running
        hintKey = key
        mirror.hintLevel = next
        mirror.hintText = Self.searchingText
        let play: NocturneGardenPlay = core.play
        hintSearch = Task.detached(priority: .userInitiated) { [weak self] in
            var hints: [NocturneGardenHint?] = []
            for level in 1...3 { hints.append(NocturneGardenHints.hint(level: level, play: play)) }
            await self?.finishSearch(hints, key: key)
        }
    }

    /// Takes the three hint levels searched for the play of `key`: cached, and shown when that play is still current.
    private func finishSearch(_ hints: [NocturneGardenHint?], key: String) {
        // A search for a play that is no longer the hinted one (hidden or replaced since) owns nothing: it must not
        // clear a newer search's handle or overwrite the cache.
        guard hintKey == key else { return }
        hintSearch = nil
        hintCache = (key, hints)
        guard let core = latestCore, Self.hintKey(core) == key else { return }
        reveal(hints, level: mirror.hintLevel, key: key)
    }

    /// Shows `hints`' level `level` for the play of `key`, or hides the hint when the play has none.
    private func reveal(_ hints: [NocturneGardenHint?], level: Int, key: String) {
        guard hints.indices.contains(level - 1), let hint = hints[level - 1] else {
            clearHint()
            return
        }
        let revealed: Bool = mirror.hintLevel != level || mirror.hintText != hint.text
        hintKey = key
        mirror.hintLevel = level
        mirror.hintText = hint.text
        if revealed { route(NocturneGardenFeedbackPlan.hint(text: hint.text)) }   // feature 386: announced as state
    }

    /// Ends the tutorial of the current level.
    func dismissTutorial(port: ExperienceActionPort) {
        send("tutorial.dismiss", [], port: port)
    }

    /// Takes back the last move (`play.undo`); after a failure this returns the play to playing.
    @discardableResult
    func undoMove(port: ExperienceActionPort) -> ActionResult {
        send("play.undo", [], port: port)
    }

    /// The action and values that start the current level again in its mode: `mode.practice` in practice, the daily
    /// date's `mode.daily` in daily mode, `level.select` of the level in campaign.
    func retryAction(date: DateComponents) -> (control: String, values: [Double]) {
        guard let core = latestCore else { return ("mode.campaign", []) }
        switch core.mode {
        case .practice: return ("mode.practice", [])
        case .daily: return ("mode.daily", Self.dateValues(dailyDate ?? date))
        case .campaign: return ("level.select", [Double(core.levelNumber)])
        case .replay(let level): return ("replay.start", [Double(level)])   // feature 387: replay from the start
        }
    }

    /// Starts the current level again in its mode; in daily mode with the date that opened it (today's local date
    /// when none is known).
    @discardableResult
    func retry(port: ExperienceActionPort, date: DateComponents = NocturneGardenPresenter.today()) -> ActionResult {
        let action = retryAction(date: date)
        return send(action.control, action.values, port: port)
    }

    /// Plays the daily level of `date` (the local calendar date by default; the core never reads a clock).
    @discardableResult
    func playDaily(port: ExperienceActionPort, date: DateComponents = NocturneGardenPresenter.today()) -> ActionResult {
        let result = send("mode.daily", Self.dateValues(date), port: port)
        if result.isAccepted { dailyDate = date }
        return result
    }

    /// The local calendar date now, as Gregorian year, month and day in the current time zone.
    static func today() -> DateComponents {
        Calendar(identifier: .gregorian).dateComponents(in: .current, from: Date())
    }

    /// The values of `mode.daily` for `date`: year, month, day (0 for a missing part, which the engine refuses).
    static func dateValues(_ date: DateComponents) -> [Double] {
        [Double(date.year ?? 0), Double(date.month ?? 0), Double(date.day ?? 0)]
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
            let plan = NocturneGardenFeedbackPlan.refused(code: result.code)
            mirror.message = plan.text
            route(plan)
            refusalLog.append(result.code)
            if refusalLog.count > Self.refusalLogLimit {
                refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit)
            }
        }
        return result
    }

    // MARK: Feedback and sound (feature 386)

    /// Plays `plan` through the feedback route (its haptic and its announcement) and logs it; `.none` does nothing.
    func route(_ plan: NocturneGardenFeedbackPlan) {
        guard plan != .none else { return }
        if let haptic = plan.haptic { feedback.haptic(haptic) }
        if let text = plan.text, let kind = plan.kind { feedback.announce(text, kind: kind) }
        feedbackLog.append(plan)
    }

    /// The ambient recipe of `core`: its planted blooms, its sun and its stage.
    static func recipe(_ core: NocturneGardenExperienceCore) -> AmbientLoopRecipe {
        NocturneGardenSoundRecipe.recipe(blooms: core.play.blooms.count, sun: core.play.elevation,
                                         stage: core.play.stage)
    }

    /// Turns the ambient sound on or off; turning it on plays the recipe of the current garden.
    func setSound(on: Bool) {
        if on, let core = latestCore { sound.offer(Self.recipe(core)) }
        sound.setWanted(on)
        mirror.soundOn = on
    }

    /// Saves the sound choice through `settings.sound [0/1]` (feature 387); the described change turns the loop on or
    /// off.
    @discardableResult
    func saveSound(on: Bool, port: ExperienceActionPort) -> ActionResult {
        send("settings.sound", [on ? 1 : 0], port: port)
    }

    // MARK: Replay (feature 387)

    /// Starts the replay of the current level's best stored solution (`replay.start [level]`).
    @discardableResult
    func startReplay(port: ExperienceActionPort) -> ActionResult {
        send("replay.start", [Double(mirror.levelNumber)], port: port)
    }

    /// Plays the next move of the running replay (`replay.step`).
    @discardableResult
    func stepReplay(port: ExperienceActionPort) -> ActionResult {
        send("replay.step", [], port: port)
    }

    /// Stops the running replay and returns to the campaign (`replay.stop`).
    @discardableResult
    func stopReplay(port: ExperienceActionPort) -> ActionResult {
        send("replay.stop", [], port: port)
    }

    /// Whether the dropped-results announcement was made (once per presenter; feature 387).
    private var droppedAnnounced = false

    /// The announcement of `count` saved results dropped by a restore (feature 387).
    static func droppedText(_ count: Int) -> String {
        count == 1 ? "1 saved result could not be checked and was removed."
            : "\(count) saved results could not be checked and were removed."
    }

    /// Whether `mode` is a replay (feature 387).
    static func isReplay(_ mode: NocturneGardenMode) -> Bool {
        if case .replay = mode { return true }
        return false
    }

    /// The controls view appeared (the loop may play).
    func controlsAppeared() { sound.setOnScreen(true) }

    /// The controls view disappeared (the loop stops).
    func controlsDisappeared() { sound.setOnScreen(false) }

    /// The scene became active or inactive.
    func sceneActive(_ active: Bool) { sound.setActive(active) }
}
#endif
