// WaveKnotKeeperAccessibilityTests — feature 326 (R02-G03-06) T-R02G0306-006 (FR-R02G0306-001 … 006;
// SC-R02G0306-001 … 004; clarifications Q1–Q5).
// On the simulator, through the one app's session host, modelled on Lissajous Labyrinth's feature-316 tests. Recorded
// feedback: the presenter's route is an `ExperienceFeedback` with a `RecordingHapticSink`, a
// `RecordingAnnouncementSink`, a clock moved by hand (1 s before every action, beyond the haptic planner's 0.05 s and the
// announcement planner's 0.5 s) and VoiceOver reported running; a selection, two moves, undo, redo, a refusal, a fresh
// play and a mode change record exactly `WaveKnotKeeperFeedbackPlan.after(old:new:)` and `refused(code:)` in the sinks
// and in the presenter's feedback log (the selection, move, refusal and level texts are also written out). Level 1 is
// won with the panel's operations alone: the point picker's increment and decrement (`point.select` of the next or
// previous point, the shorter way round) and the direction buttons (`point.move` of the mirror's selected point),
// following the certified solution; every step is announced and the win is announced as an outcome with a success
// haptic. A drag preview (finger down and moved, not released) adds no announcement; its release is announced once.
// Sound: the presenter makes its own `WaveKnotKeeperSound` with the real `AmbientLoopPlayer`, so the state table, the
// offers and a failing `play()` use a `WaveKnotKeeperSound` with a fake player; the presenter's sound is only driven
// with the sound off or off screen (no audio starts): the recipe offered at the first state, level openings, summary
// changes and play ends, not on a selection, no player made. Reduce Flashing: the drawn lights (every crossing level,
// the match and the glow) are sampled through off-screen stills at frame times 1/60 s apart (the presenter eases its
// lights by the frame time it is drawn at) over a move that changes the crossings followed by undo/redo every frame, and
// over the certified win. Reduce Motion: two stills at different times are byte-identical and the drawn snapshot keeps
// time 0 and one pulse. Labels: SwiftUI's accessibility tree is not inspectable from a unit test, so the label and value
// strings built outside the view body (direction titles and spoken names, the progress value, mode names, level titles,
// the goal line), the mirror values the modifiers read, the controls' action coverage and the panel's layout at the
// largest accessibility text size (320 and 1024 points wide) are checked. Synthetic data, explicit types, plain loops,
// no sleep, no wall-clock assertion; each test well under 10 s.
#if os(iOS)
import CoreGraphics
import Foundation
import SwiftUI
import Testing
import UIKit
import WaveKnotKeeperCore
@testable import WaveKnotKeeperExperience
import VisualCoreAudioDSP
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreSimulation
import VisualCoreUI

/// A clock the accessibility tests move by hand.
@MainActor
final class WaveKnotKeeperAccessClock {
    /// The current time in seconds.
    var now: Double = 100

    /// Moves the clock forward by `seconds`.
    func advance(_ seconds: Double = 1) { now += seconds }
}

/// A loop player that records what it was asked; `play()` fails when `succeeds` is false.
@MainActor
final class WaveKnotKeeperFakeLoop: WaveKnotKeeperLoopPlaying {
    /// Whether `play()` may play.
    var isEnabled: Bool = false
    /// Whether the loop plays.
    private(set) var isPlaying: Bool = false
    /// How many times `play()` was called.
    private(set) var plays: Int = 0
    /// How many times `stop()` was called.
    private(set) var stops: Int = 0
    /// Whether `play()` succeeds.
    let succeeds: Bool

    /// A fake loop whose `play()` succeeds when `succeeds` is true.
    init(succeeds: Bool) {
        self.succeeds = succeeds
    }

    /// Starts the loop when enabled and `succeeds`; false otherwise.
    @discardableResult
    func play() -> Bool {
        plays += 1
        guard isEnabled, succeeds else { return false }
        isPlaying = true
        return true
    }

    /// Stops the loop.
    func stop() {
        stops += 1
        isPlaying = false
    }
}

/// Makes fake loops and keeps them.
@MainActor
final class WaveKnotKeeperFakeLoopFactory {
    /// Whether the loops made from now on succeed in `play()`.
    var succeeds: Bool = true
    /// Every loop made, oldest first.
    private(set) var made: [WaveKnotKeeperFakeLoop] = []

    /// Makes and keeps one fake loop.
    func make() -> WaveKnotKeeperFakeLoop {
        let loop: WaveKnotKeeperFakeLoop = WaveKnotKeeperFakeLoop(succeeds: succeeds)
        made.append(loop)
        return loop
    }

    /// A sound policy starting from `recipe` that makes its players here.
    func sound(_ recipe: AmbientLoopRecipe) -> WaveKnotKeeperSound {
        WaveKnotKeeperSound(recipe: recipe, makePlayer: { _ in self.make() })
    }
}

/// One drawn frame's light levels: every crossing level by mark key, the target match and the win glow.
struct WaveKnotKeeperLightSample {
    /// The crossing levels by mark key (a key missing here is at 0).
    let crossings: [WaveKnotKeeperLights.Key: Double]
    /// The target-match level.
    let match: Double
    /// The win glow.
    let glow: Double
}

/// Helpers of the accessibility tests.
@MainActor
enum WaveKnotKeeperAccess {
    typealias Shell = ExperienceShell<WaveKnotKeeperPresenter>
    typealias Plan = WaveKnotKeeperFeedbackPlan

    /// A recording route on a presenter.
    struct Recorder {
        let haptics: RecordingHapticSink
        let announcements: RecordingAnnouncementSink
        let clock: WaveKnotKeeperAccessClock
    }

    /// The still size of the Reduce Flashing and Reduce Motion tests (aspect 1.5).
    static let stillWidth: Int = 96
    static let stillHeight: Int = 64
    /// The frame rate of the sampled stills.
    static let frameRate: Double = 60
    /// The readable width of the panel, padding included (clarification Q5).
    static let readableWidth: CGFloat = 520

    /// Opens level `seed % 100 + 1` at a 360 × 240-point view (one frame drawn).
    static func open(_ session: ExperienceSession, seed: UInt64 = 0, reduceMotion: Bool = false,
                     reduceFlashing: Bool = false) async throws -> Shell {
        try await WaveKnotKeeperTest.open(session, seed: seed, reduceMotion: reduceMotion,
                                          reduceFlashing: reduceFlashing, size: CGSize(width: 360, height: 240))
    }

    /// Injects a recording feedback route (VoiceOver running, the test's clock) into `shell`'s presenter.
    static func record(_ shell: Shell) -> Recorder {
        let haptics: RecordingHapticSink = RecordingHapticSink()
        let announcements: RecordingAnnouncementSink = RecordingAnnouncementSink()
        let clock: WaveKnotKeeperAccessClock = WaveKnotKeeperAccessClock()
        shell.presenter.feedback = ExperienceFeedback(hapticSink: haptics, announcementSink: announcements,
                                                      clock: { clock.now }, voiceOverRunning: { true })
        return Recorder(haptics: haptics, announcements: announcements, clock: clock)
    }

    /// Injects a route that records into throwaway sinks with VoiceOver off (no system haptic or announcement).
    static func quiet(_ shell: Shell) {
        shell.presenter.feedback = ExperienceFeedback(hapticSink: RecordingHapticSink(),
                                                      announcementSink: RecordingAnnouncementSink(),
                                                      voiceOverRunning: { false })
    }

    /// The current core of `shell`.
    static func core(_ shell: Shell) throws -> WaveKnotKeeperExperienceCore {
        try #require(shell.engine.core)
    }

    /// The texts of `plans` that are announced, in order.
    static func texts(_ plans: [Plan]) -> [String] {
        var result: [String] = []
        for plan in plans {
            if let text = plan.text, plan.kind != nil { result.append(text) }
        }
        return result
    }

    /// The haptics of `plans`, in order.
    static func haptics(_ plans: [Plan]) -> [HapticKind] {
        var result: [HapticKind] = []
        for plan in plans {
            if let haptic = plan.haptic { result.append(haptic) }
        }
        return result
    }

    /// The feedback log entries after the first `count`.
    static func log(_ presenter: WaveKnotKeeperPresenter, after count: Int) -> [Plan] {
        Array(presenter.feedbackLog.dropFirst(count))
    }

    /// The plain direction word, written out here: right, left, up, down, over, under (+x, −x, +y, −y, +z, −z).
    static func word(_ direction: WaveKnotKeeperDirection) -> String {
        switch direction {
        case .plusX: return "right"
        case .minusX: return "left"
        case .plusY: return "up"
        case .minusY: return "down"
        case .plusZ: return "over"
        case .minusZ: return "under"
        }
    }

    /// "1 crossing" or "c crossings", written out here.
    static func crossingsText(_ count: Int) -> String { count == 1 ? "1 crossing" : "\(count) crossings" }

    /// "1 move" or "s moves", written out here.
    static func movesText(_ count: Int) -> String { count == 1 ? "1 move" : "\(count) moves" }

    /// The announcement of a move of `point` in `direction` that left `core` playing, with `prefix` ("", "Undone: ",
    /// "Redone: "), written out from clarification Q1.
    static func moveText(_ core: WaveKnotKeeperExperienceCore, point: Int, direction: WaveKnotKeeperDirection,
                         prefix: String) -> String {
        let summary: WaveKnotKeeperSummary = core.play.summary
        let target: WaveKnotKeeperTarget = core.play.level.target
        var text: String = "\(prefix)Point \(point + 1) moved \(word(direction)). "
        if summary.degenerate {
            text += "Two strands overlap in the view. Target \(crossingsText(target.crossings)), writhe \(target.writhe). "
        } else {
            text += "\(crossingsText(summary.crossings)), writhe \(summary.writhe); "
            text += "target \(target.crossings), \(target.writhe). "
        }
        text += "Moves \(core.play.spent) of \(core.play.level.allowance)."
        return text
    }

    /// The level announcement of `core`, written out: "Level n, band b, <mode>." and the tutorial instruction.
    static func levelText(_ core: WaveKnotKeeperExperienceCore, mode: String) -> String {
        let number: Int = core.levelNumber
        var text: String = "Level \(number), band \((number - 1) / 20 + 1), \(mode)."
        if core.tutorial != .done { text += " " + core.tutorial.text }
        return text
    }

    /// The first move of `play` the kernel refuses with a `.move(…)` reason; nil when none.
    static func refusedMove(_ play: WaveKnotKeeperPlay) -> WaveKnotKeeperMove? {
        let directions: [WaveKnotKeeperDirection] = WaveKnotKeeperExperienceCore.directionOrder
        for point in 0..<play.points.count {
            for direction in directions {
                let move: WaveKnotKeeperMove = WaveKnotKeeperMove(point: point, direction: direction)
                if WaveKnotKeeperGestureScript.isRefusedMove(move, play) { return move }
            }
        }
        return nil
    }

    /// The set of crossing-mark keys of `play`'s rope at level `number`.
    static func markKeys(_ play: WaveKnotKeeperPlay, number: Int) -> Set<WaveKnotKeeperLights.Key> {
        let snapshot: WaveKnotKeeperSceneSnapshot = WaveKnotKeeperSceneSnapshot(play: play, levelNumber: number,
                                                                                selected: nil, time: 0)
        var keys: Set<WaveKnotKeeperLights.Key> = []
        for mark in snapshot.crossings {
            keys.insert(WaveKnotKeeperLights.Key(first: mark.first, second: mark.second))
        }
        return keys
    }

    /// A legal move of `core`'s play that keeps it playing and changes its crossing marks (checked by trial on a
    /// copy), preferring one that changes the crossing count; nil when none.
    static func crossingMove(_ core: WaveKnotKeeperExperienceCore) -> WaveKnotKeeperMove? {
        let play: WaveKnotKeeperPlay = core.play
        let opening: Set<WaveKnotKeeperLights.Key> = markKeys(play, number: core.levelNumber)
        let directions: [WaveKnotKeeperDirection] = WaveKnotKeeperExperienceCore.directionOrder
        var fallback: WaveKnotKeeperMove?
        for point in 0..<play.points.count {
            for direction in directions {
                let move: WaveKnotKeeperMove = WaveKnotKeeperMove(point: point, direction: direction)
                var trial: WaveKnotKeeperPlay = play
                do {
                    try trial.apply(move, expecting: trial.fingerprint)
                } catch {
                    continue
                }
                guard trial.stage == .playing else { continue }
                guard markKeys(trial, number: core.levelNumber) != opening else { continue }
                if trial.summary.crossings != play.summary.crossings { return move }
                if fallback == nil { fallback = move }
            }
        }
        return fallback
    }

    /// The picker steps from `current` to `target` among `count` points, the shorter way round: the step (+1
    /// increment, −1 decrement) and how many.
    static func pickerSteps(from current: Int, to target: Int, count: Int) -> (delta: Int, steps: Int) {
        guard count > 0 else { return (1, 0) }
        let forward: Int = ((target - current) % count + count) % count
        if forward <= count / 2 { return (1, forward) }
        return (-1, count - forward)
    }

    /// The point the picker's increment (+1) or decrement (−1) selects from `selected` among `count` points, as
    /// `WaveKnotKeeperControls.pointPicker` computes it.
    static func pickerNext(_ selected: Int, delta: Int, count: Int) -> Int {
        delta > 0 ? (selected + 1) % count : (selected + count - 1) % count
    }

    /// Draws an off-screen still of `session` at frame time `time` and returns the presenter's drawn light levels.
    static func sample(_ session: ExperienceSession, _ presenter: WaveKnotKeeperPresenter,
                       time: Double) throws -> WaveKnotKeeperLightSample {
        _ = try WaveKnotKeeperTest.still(session, width: stillWidth, height: stillHeight, time: time)
        let lights: WaveKnotKeeperLights = presenter.lights
        var crossings: [WaveKnotKeeperLights.Key: Double] = [:]
        for (key, light) in lights.crossings { crossings[key] = light.level }
        return WaveKnotKeeperLightSample(crossings: crossings, match: lights.match, glow: lights.glow)
    }

    /// The samples as one vector per frame over every key seen (sorted; 0 where a key is absent), then match, glow.
    static func vectors(_ samples: [WaveKnotKeeperLightSample]) -> [[Double]] {
        var seen: Set<WaveKnotKeeperLights.Key> = []
        for sample in samples {
            for key in sample.crossings.keys { seen.insert(key) }
        }
        let keys: [WaveKnotKeeperLights.Key] = seen.sorted { ($0.first, $0.second) < ($1.first, $1.second) }
        var result: [[Double]] = []
        for sample in samples {
            var row: [Double] = []
            for key in keys { row.append(sample.crossings[key] ?? 0) }
            row.append(sample.match)
            row.append(sample.glow)
            result.append(row)
        }
        return result
    }

    /// Whether any value of `vectors` lies strictly between 0 and 1 (a light caught mid-fade).
    static func anyMidFade(_ vectors: [[Double]]) -> Bool {
        for row in vectors {
            for value in row where value > 0 && value < 1 { return true }
        }
        return false
    }

    /// The first `UIScrollView` in `view`'s hierarchy (breadth first), or nil.
    static func scrollView(in view: UIView) -> UIScrollView? {
        var queue: [UIView] = [view]
        var index: Int = 0
        while index < queue.count {
            let current: UIView = queue[index]
            index += 1
            if let scroll = current as? UIScrollView { return scroll }
            for sub in current.subviews { queue.append(sub) }
        }
        return nil
    }
}

@MainActor
@Suite(.serialized) struct WaveKnotKeeperAccessibilityTests {
    typealias Access = WaveKnotKeeperAccess
    typealias Teaching = WaveKnotKeeperTeaching
    typealias Script = WaveKnotKeeperGestureScript
    typealias Plan = WaveKnotKeeperFeedbackPlan
    typealias Presenter = WaveKnotKeeperPresenter

    // MARK: Recorded feedback (FR-R02G0306-002, 003; SC-R02G0306-002)

    /// A selection, two moves, undo, redo, a refusal, a fresh play and a mode change: the sinks receive exactly the
    /// plans of `WaveKnotKeeperFeedbackPlan`, in order, and the feedback log holds the same plans; texts written out.
    @Test func recordedFeedbackThroughThePresenter() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let announcedBase: Int = presenter.announcements.count
        var expected: [Plan] = []
        let opening: WaveKnotKeeperExperienceCore = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        #expect(opening.play.stage == .playing)
        try #require(opening.play.points.count >= 2)

        // A selection: "Point n selected.", a state announcement without a haptic.
        let pick: Int = opening.selected == 1 ? 0 : 1
        recorder.clock.advance()
        let selected: ActionResult = presenter.send("point.select", [Double(pick)], port: shell.port)
        #expect(selected == .accepted, "\(selected.code)")
        let afterSelect: WaveKnotKeeperExperienceCore = try Access.core(shell)
        let selectPlan: Plan = Plan.after(old: opening, new: afterSelect)
        #expect(selectPlan.text == "Point \(pick + 1) selected.", "\(selectPlan.text ?? "nil")")
        #expect(selectPlan.kind == .state)
        #expect(selectPlan.haptic == nil)
        expected.append(selectPlan)

        // Two accepted moves: state announcements with a selection haptic, texts written out.
        var previous: WaveKnotKeeperExperienceCore = afterSelect
        var lastMove: WaveKnotKeeperMove?
        for index in 0..<2 {
            let move: WaveKnotKeeperMove = try #require(Teaching.nonWinningMove(previous), "a non-winning move \(index)")
            recorder.clock.advance()
            let moved: ActionResult = Teaching.send(move, shell)
            #expect(moved == .accepted, "\(moved.code)")
            let next: WaveKnotKeeperExperienceCore = try Access.core(shell)
            try #require(next.play.stage == .playing)
            let plan: Plan = Plan.after(old: previous, new: next)
            let want: String = Access.moveText(next, point: move.point, direction: move.direction, prefix: "")
            #expect(plan.text == want, "\(plan.text ?? "nil")")
            #expect(plan.kind == .state)
            #expect(plan.haptic == .selection)
            expected.append(plan)
            previous = next
            lastMove = move
        }
        let undoneMove: WaveKnotKeeperMove = try #require(lastMove)

        // Undo names the move that was undone (its direction, not the step back).
        recorder.clock.advance()
        let undone: ActionResult = presenter.send("play.undo", [], port: shell.port)
        #expect(undone == .accepted, "\(undone.code)")
        let afterUndo: WaveKnotKeeperExperienceCore = try Access.core(shell)
        let undoPlan: Plan = Plan.after(old: previous, new: afterUndo)
        #expect(undoPlan.text == Access.moveText(afterUndo, point: undoneMove.point, direction: undoneMove.direction,
                                                 prefix: "Undone: "), "\(undoPlan.text ?? "nil")")
        #expect(undoPlan.kind == .state)
        #expect(undoPlan.haptic == .selection)
        expected.append(undoPlan)

        // Redo.
        recorder.clock.advance()
        let redone: ActionResult = presenter.send("play.redo", [], port: shell.port)
        #expect(redone == .accepted, "\(redone.code)")
        let afterRedo: WaveKnotKeeperExperienceCore = try Access.core(shell)
        let redoPlan: Plan = Plan.after(old: afterUndo, new: afterRedo)
        #expect(redoPlan.text == Access.moveText(afterRedo, point: undoneMove.point, direction: undoneMove.direction,
                                                 prefix: "Redone: "), "\(redoPlan.text ?? "nil")")
        #expect(redoPlan.kind == .state)
        #expect(redoPlan.haptic == .selection)
        expected.append(redoPlan)

        // A refusal: a move the kernel refuses (or, when none exists, a locked level), in words with an error haptic.
        let digest: String = try WaveKnotKeeperTest.digest(shell)
        let code: String
        let words: String
        let refused: ActionResult
        recorder.clock.advance()
        if let bad = Access.refusedMove(afterRedo.play) {
            code = WaveKnotKeeperError.move("").reasonCode
            words = "That move is not allowed: it would leave the space, meet another point, pass through a strand "
                + "outside a gate or pull the rope too tight."
            refused = Teaching.send(bad, shell)
        } else {
            code = WaveKnotKeeperExperienceRule.locked
            words = "That level is not open yet."
            refused = presenter.send("level.select", [2], port: shell.port)
        }
        #expect(!refused.isAccepted)
        #expect(refused.code.contains(code), "\(refused.code)")
        let refusedPlan: Plan = Plan.refused(code: refused.code)
        #expect(refusedPlan.text == words, "\(refusedPlan.text ?? "nil")")
        #expect(refusedPlan.text == Plan.refusalText(code: code))
        #expect(refusedPlan.kind == .rejection)
        #expect(refusedPlan.haptic == .error)
        #expect(presenter.mirror.message == words, "the panel shows the same words")
        #expect(try WaveKnotKeeperTest.digest(shell) == digest, "a refusal changes nothing")
        expected.append(refusedPlan)

        // A fresh play of level 1: a level announcement, no haptic.
        recorder.clock.advance()
        let picked: ActionResult = presenter.send("level.select", [1], port: shell.port)
        #expect(picked == .accepted, "\(picked.code)")
        #expect(presenter.mirror.message == nil, "an accepted action clears the refusal")
        let fresh: WaveKnotKeeperExperienceCore = try Access.core(shell)
        let levelPlan: Plan = Plan.after(old: afterRedo, new: fresh)
        #expect(levelPlan.text == Access.levelText(fresh, mode: "Campaign"), "\(levelPlan.text ?? "nil")")
        #expect(levelPlan.kind == .level)
        #expect(levelPlan.haptic == nil)
        expected.append(levelPlan)

        // A mode change: practice.
        recorder.clock.advance()
        let practice: ActionResult = presenter.send("mode.practice", [], port: shell.port)
        #expect(practice == .accepted, "\(practice.code)")
        let practising: WaveKnotKeeperExperienceCore = try Access.core(shell)
        let modePlan: Plan = Plan.after(old: fresh, new: practising)
        #expect(modePlan.text == Access.levelText(practising, mode: "Practice"), "\(modePlan.text ?? "nil")")
        #expect(modePlan.kind == .level)
        #expect(modePlan.haptic == nil)
        expected.append(modePlan)

        #expect(Access.log(presenter, after: logBase) == expected)
        #expect(recorder.announcements.announced == Access.texts(expected))
        #expect(recorder.haptics.played == Access.haptics(expected))
        #expect(Array(presenter.announcements.dropFirst(announcedBase)) == Access.texts(expected))
        #expect(recorder.announcements.announced.count == expected.count, "every plan here is announced")
    }

    // MARK: The panel alone (SC-R02G0306-001)

    /// Level 1 (seed 0) is won with the point picker's increment and decrement and the direction buttons alone,
    /// following the certified solution: every step announced, the win announced as an outcome with a success haptic.
    @Test func levelOneWonWithThePickerAndDirectionButtons() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, seed: 0)
        let presenter: Presenter = shell.presenter
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let opening: WaveKnotKeeperExperienceCore = try Access.core(shell)
        #expect(opening.levelNumber == 1)
        let generated: WaveKnotKeeperGenerated = try WaveKnotKeeperExperienceCore.generated(number: 1)
        let moves: [WaveKnotKeeperMove] = generated.solution.moves
        try #require(!moves.isEmpty)
        let count: Int = presenter.mirror.pointCount
        #expect(count == opening.play.points.count)
        try #require(count > 0)

        var announced: Int = 0
        var hapticsWanted: [HapticKind] = []
        var previous: WaveKnotKeeperExperienceCore = opening
        for (step, move) in moves.enumerated() {
            // The point picker: increment or decrement until the move's point is selected.
            let way: (delta: Int, steps: Int) = Access.pickerSteps(from: presenter.mirror.selected, to: move.point,
                                                                   count: count)
            for _ in 0..<way.steps {
                let index: Int = Access.pickerNext(presenter.mirror.selected, delta: way.delta, count: count)
                recorder.clock.advance()
                let result: ActionResult = presenter.send("point.select", [Double(index)], port: shell.port)
                #expect(result == .accepted, "\(result.code)")
                announced += 1
                let text: String = "Point \(index + 1) selected."
                #expect(presenter.announcements.last == text, "\(presenter.announcements.last ?? "nil")")
                #expect(recorder.announcements.announced.last == text)
                #expect(presenter.mirror.selected == index)
                previous = try Access.core(shell)
            }
            #expect(presenter.mirror.selected == move.point, "step \(step): the picker reached point \(move.point)")

            // The direction button: `point.move` of the mirror's selected point.
            let direction: Int = Teaching.directionIndex(move.direction)
            #expect(WaveKnotKeeperControls.titles.indices.contains(direction))
            recorder.clock.advance()
            let result: ActionResult = presenter.send("point.move", [Double(presenter.mirror.selected),
                                                                      Double(direction)], port: shell.port)
            #expect(result == .accepted, "step \(step): \(result.code)")
            let next: WaveKnotKeeperExperienceCore = try Access.core(shell)
            let plan: Plan = Plan.after(old: previous, new: next)
            let text: String = try #require(plan.text, "step \(step) is announced")
            announced += 1
            if let haptic = plan.haptic { hapticsWanted.append(haptic) }
            #expect(presenter.announcements.last == text, "\(presenter.announcements.last ?? "nil")")
            #expect(recorder.announcements.announced.last == text)
            previous = next
        }

        let won: WaveKnotKeeperExperienceCore = try Access.core(shell)
        #expect(won.play.stage == .won)
        #expect(won.play.spent == generated.solution.shortest)
        let winText: String = "The knot matches. Level won in \(Access.movesText(won.play.spent)), 3 of 3 stars."
        let plans: [Plan] = Access.log(presenter, after: logBase)
        #expect(plans.last?.text == winText, "\(plans.last?.text ?? "nil")")
        #expect(plans.last?.kind == .outcome)
        #expect(plans.last?.haptic == .success)
        #expect(presenter.announcements.last == winText)
        #expect(recorder.announcements.announced.last == winText)
        #expect(recorder.announcements.announced.count == announced, "every step announced")
        #expect(recorder.haptics.played == hapticsWanted, "\(recorder.haptics.played)")
        #expect(recorder.haptics.played.last == .success)
        #expect(presenter.mirror.stage == .won)
    }

    // MARK: Gesture preview (edge case)

    /// A finger down on a handle and moved along a legal move's step (not released) adds no announcement, plan or
    /// haptic beyond the touch's selection; the release announces the move once.
    @Test func aDragPreviewIsNotAnnounced() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Script.open(session)
        let presenter: Presenter = shell.presenter
        let drag: Script.Drag = try #require(try Script.findDragOnSomeLevel(session, shell, accept: Script.isLegal),
                                             "a legal move whose handle and drag direction can be scripted")
        let recorder: Access.Recorder = Access.record(shell)
        let logBase: Int = presenter.feedbackLog.count
        let announcedBase: Int = presenter.announcements.count
        let beforeTouch: WaveKnotKeeperExperienceCore = try Access.core(shell)
        var time: Double = 0

        // Finger down: the handle is selected (announced as a selection when it changes, no haptic).
        recorder.clock.advance()
        Script.touch(shell, id: 1, .began, at: drag.start, time: &time)
        let afterTouch: WaveKnotKeeperExperienceCore = try Access.core(shell)
        #expect(afterTouch.selected == drag.point)
        let touchPlan: Plan = Plan.after(old: beforeTouch, new: afterTouch)
        var expected: [Plan] = []
        if touchPlan != .none { expected.append(touchPlan) }
        #expect(touchPlan.haptic == nil, "a selection plays no haptic")
        #expect(Access.log(presenter, after: logBase) == expected)
        let digest: String = try WaveKnotKeeperTest.digest(shell)
        let announcedAfterTouch: Int = recorder.announcements.announced.count
        let logAfterTouch: Int = presenter.feedbackLog.count

        // Moved halfway and to the release point: a preview, nothing announced or planned.
        recorder.clock.advance()
        let half: Vec2 = Vec2((drag.start.x + drag.end.x) / 2, (drag.start.y + drag.end.y) / 2)
        Script.touch(shell, id: 1, .moved, at: half, time: &time)
        recorder.clock.advance()
        Script.touch(shell, id: 1, .moved, at: drag.end, time: &time)
        #expect(presenter.gestures.preview != nil, "the drag previews a move")
        #expect(recorder.announcements.announced.count == announcedAfterTouch, "the preview is not announced")
        #expect(presenter.feedbackLog.count == logAfterTouch, "the preview plans nothing")
        #expect(recorder.haptics.played.isEmpty, "the preview plays no haptic")
        #expect(try WaveKnotKeeperTest.digest(shell) == digest, "nothing is sent before the release")

        // Release: the move is announced once.
        recorder.clock.advance()
        Script.touch(shell, id: 1, .ended, at: drag.end, time: &time)
        let after: WaveKnotKeeperExperienceCore = try Access.core(shell)
        #expect(after.play.spent == afterTouch.play.spent + 1, "exactly one move")
        let plan: Plan = Plan.after(old: afterTouch, new: after)
        let text: String = try #require(plan.text)
        if after.play.stage == .playing {
            #expect(text == Access.moveText(after, point: drag.point, direction: drag.direction, prefix: ""), "\(text)")
        }
        expected.append(plan)
        #expect(Access.log(presenter, after: logBase) == expected)
        #expect(Array(presenter.announcements.dropFirst(announcedBase)) == Access.texts(expected),
                "the release is announced once")
        #expect(recorder.announcements.announced == Access.texts(expected))
        #expect(recorder.haptics.played == Access.haptics(expected))
    }

    // MARK: Sound (FR-R02G0306-006; SC-R02G0306-004)

    /// The loop plays exactly when wanted, on screen and active, over all 8 combinations; the sound off makes no
    /// player; each input turned off stops the loop and on again plays it with the same player.
    @Test func soundStateTable() throws {
        for combination in 0..<8 {
            let wanted: Bool = combination & 1 != 0
            let onScreen: Bool = combination & 2 != 0
            let active: Bool = combination & 4 != 0
            let factory: WaveKnotKeeperFakeLoopFactory = WaveKnotKeeperFakeLoopFactory()
            let sound: WaveKnotKeeperSound = factory.sound(WaveKnotKeeperSoundRecipe.quiet)
            sound.setOnScreen(onScreen)
            sound.setActive(active)
            sound.setWanted(wanted)
            let expected: Bool = wanted && onScreen && active
            #expect(sound.shouldPlay == expected, "combination \(combination)")
            #expect(sound.started == expected, "combination \(combination)")
            #expect(sound.playersMade == (expected ? 1 : 0), "combination \(combination)")
            #expect((factory.made.last?.isPlaying ?? false) == expected, "combination \(combination)")
            if !wanted {
                #expect(factory.made.isEmpty, "sound off makes no player (combination \(combination))")
                #expect(sound.player == nil)
            }
        }

        let factory: WaveKnotKeeperFakeLoopFactory = WaveKnotKeeperFakeLoopFactory()
        let sound: WaveKnotKeeperSound = factory.sound(WaveKnotKeeperSoundRecipe.quiet)
        sound.setOnScreen(true)
        sound.setWanted(true)
        let loop: WaveKnotKeeperFakeLoop = try #require(factory.made.first)
        #expect(loop.isPlaying)
        for input in 0..<3 {
            switch input {
            case 0: sound.setWanted(false)
            case 1: sound.setOnScreen(false)
            default: sound.setActive(false)
            }
            #expect(!loop.isPlaying, "input \(input) off stops")
            #expect(!sound.started)
            switch input {
            case 0: sound.setWanted(true)
            case 1: sound.setOnScreen(true)
            default: sound.setActive(true)
            }
            #expect(loop.isPlaying, "input \(input) on plays")
            #expect(sound.started)
        }
        #expect(sound.playersMade == 1, "the same recipe keeps its player")
    }

    /// Offers: a different recipe while playing makes a new player and stops the old one; the same recipe does not;
    /// any offer while the sound is off makes none but is kept for the next start. A `play()` that fails leaves
    /// `started` false and the choice on.
    @Test func soundOffersAndAFailingPlay() throws {
        let generated: WaveKnotKeeperGenerated = try WaveKnotKeeperExperienceCore.generated(number: 1)
        let play: WaveKnotKeeperPlay = WaveKnotKeeperPlay(level: generated.level)
        let playing: AmbientLoopRecipe = WaveKnotKeeperSoundRecipe.recipe(summary: play.summary,
                                                                          target: generated.level.target,
                                                                          stage: .playing)
        let won: AmbientLoopRecipe = WaveKnotKeeperSoundRecipe.recipe(summary: play.summary,
                                                                      target: generated.level.target, stage: .won)
        try #require(playing != won, "a won play sounds different")

        let silent: WaveKnotKeeperFakeLoopFactory = WaveKnotKeeperFakeLoopFactory()
        let off: WaveKnotKeeperSound = silent.sound(WaveKnotKeeperSoundRecipe.quiet)
        off.setOnScreen(true)
        off.offer(playing)
        off.offer(won)
        #expect(off.playersMade == 0)
        #expect(silent.made.isEmpty)
        #expect(off.recipe == won, "kept for the next start")

        let factory: WaveKnotKeeperFakeLoopFactory = WaveKnotKeeperFakeLoopFactory()
        let sound: WaveKnotKeeperSound = factory.sound(playing)
        sound.setOnScreen(true)
        sound.setWanted(true)
        #expect(sound.playersMade == 1)
        sound.offer(playing)
        #expect(sound.playersMade == 1, "the same recipe keeps the player")
        sound.offer(won)
        #expect(sound.playersMade == 2, "a new recipe makes a new player")
        #expect(factory.made.count == 2)
        if factory.made.count == 2 {
            #expect(!factory.made[0].isPlaying, "the old player stopped")
            #expect(factory.made[1].isPlaying)
        }
        sound.offer(won)
        #expect(sound.playersMade == 2)

        let failing: WaveKnotKeeperFakeLoopFactory = WaveKnotKeeperFakeLoopFactory()
        failing.succeeds = false
        let broken: WaveKnotKeeperSound = failing.sound(playing)
        broken.setOnScreen(true)
        broken.setWanted(true)
        #expect(broken.playersMade == 1)
        #expect(!broken.started)
        #expect(broken.wanted)
        #expect(broken.shouldPlay)
        #expect(failing.made.first?.plays == 1)
        #expect(failing.made.first?.isPlaying == false)
        #expect(failing.made.first?.stops == 0)
    }

    /// The presenter's own sound (real `AmbientLoopPlayer`; never started here: the sound is off, or on while off
    /// screen): the first state's recipe is offered; a selection offers nothing; a move that changes the summary, a
    /// fresh play and the end of a play offer their recipe; turning the sound on keeps the choice on, makes no player
    /// and leaves the game unaffected.
    @Test func presenterSoundOffersAtOpeningsChangesAndEnds() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        // Level 2 (seed 1): level 1 has no move that changes the crossing marks without winning.
        let shell = try await Access.open(session, seed: 1)
        let presenter: Presenter = shell.presenter
        Access.quiet(shell)
        presenter.controlsAppeared()
        #expect(!presenter.sound.wanted)
        #expect(presenter.mirror.soundOn == false, "the sound is off by default")
        let opening: WaveKnotKeeperExperienceCore = try Access.core(shell)
        #expect(presenter.sound.recipe == Presenter.recipe(opening), "the first state offers its recipe")

        // A selection offers nothing.
        let held: AmbientLoopRecipe = presenter.sound.recipe
        #expect(presenter.send("point.select", [1], port: shell.port) == .accepted)
        #expect(presenter.sound.recipe == held, "a selection does not offer a recipe")

        // A move that changes the summary offers the new recipe.
        let move: WaveKnotKeeperMove = try #require(Access.crossingMove(opening), "a move that changes the crossings")
        #expect(Teaching.send(move, shell) == .accepted)
        let moved: WaveKnotKeeperExperienceCore = try Access.core(shell)
        #expect(presenter.sound.recipe == Presenter.recipe(moved), "a summary change offers its recipe")
        if moved.play.summary.crossings != opening.play.summary.crossings {
            #expect(presenter.sound.recipe != held, "another crossing count sounds different")
        }

        // A fresh play (Retry) offers the opening recipe.
        #expect(presenter.retry(port: shell.port, date: DateComponents()) == .accepted)
        let fresh: WaveKnotKeeperExperienceCore = try Access.core(shell)
        #expect(fresh.play.spent == 0)
        #expect(presenter.sound.recipe == Presenter.recipe(fresh))

        // The certified win of the opened level: the end of the play offers the won recipe.
        try Teaching.playCertified(fresh.levelNumber, shell)
        let won: WaveKnotKeeperExperienceCore = try Access.core(shell)
        #expect(won.play.stage == .won)
        let wonRecipe: AmbientLoopRecipe = WaveKnotKeeperSoundRecipe.recipe(summary: won.play.summary,
                                                                            target: won.play.level.target, stage: .won)
        #expect(presenter.sound.recipe == wonRecipe, "the end of the play offers the won recipe")

        // Turning the sound on while off screen: the choice is on, no player is made, the game goes on unaffected.
        presenter.controlsDisappeared()
        presenter.sceneActive(false)
        #expect(presenter.send("level.select", [1], port: shell.port) == .accepted)
        presenter.setSound(on: true)
        #expect(presenter.mirror.soundOn)
        #expect(presenter.sound.wanted)
        #expect(!presenter.sound.shouldPlay)
        #expect(!presenter.sound.started)
        let current: WaveKnotKeeperExperienceCore = try Access.core(shell)
        #expect(presenter.sound.recipe == Presenter.recipe(current))
        let digest: String = try WaveKnotKeeperTest.digest(shell)
        let next: WaveKnotKeeperMove = try #require(Teaching.nonWinningMove(current))
        #expect(Teaching.send(next, shell) == .accepted, "the game goes on with the sound on")
        #expect(try WaveKnotKeeperTest.digest(shell) != digest)
        #expect(presenter.mirror.soundOn, "the choice stays on")
        presenter.setSound(on: false)
        #expect(!presenter.mirror.soundOn)
        #expect(!presenter.sound.wanted)
        #expect(presenter.sound.playersMade == 0, "no player was made")
        #expect(!presenter.sound.started)
    }

    // MARK: Reduce Flashing (FR-R02G0306-004; SC-R02G0306-003)

    /// Under Reduce Flashing, drawn frames 1/60 s apart: a move that changes the crossing marks fades its lights (a
    /// level is caught mid-fade), then undo and redo alternate every frame for 2 s and the lights are held 2 s; no
    /// element (crossing level, match, glow) crosses half its range more than 3 times per second, and the lights settle.
    @Test func drawnLightsSurviveMoveUndoFlicker() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        // Level 2 (seed 1): level 1 has no move that changes the crossing marks without winning.
        let shell = try await Access.open(session, seed: 1, reduceFlashing: true)
        let presenter: Presenter = shell.presenter
        Access.quiet(shell)
        #expect(presenter.lights.reducedFlash)
        let opening: WaveKnotKeeperExperienceCore = try Access.core(shell)
        let move: WaveKnotKeeperMove = try #require(Access.crossingMove(opening), "a move that changes the crossings")

        let base: Double = 100
        var samples: [WaveKnotKeeperLightSample] = [try Access.sample(session, presenter, time: base)]
        #expect(shell.port.send("point.move", Teaching.values(move)) == .accepted)
        var applied: Bool = true
        for frame in 1...240 {
            if frame > 1 && frame <= 120 {
                let result: ActionResult = shell.port.send(applied ? "play.undo" : "play.redo")
                #expect(result == .accepted, "frame \(frame): \(result.code)")
                applied.toggle()
            }
            samples.append(try Access.sample(session, presenter, time: base + Double(frame) / Access.frameRate))
            #expect(presenter.scene.lights == presenter.lights, "frame \(frame): the scene draws the eased lights")
            let opacity: Float = WaveKnotKeeperRopeScene.glowOpacity(presenter.lights)
            #expect(opacity >= 0.8 && opacity <= 1, "frame \(frame): glow opacity \(opacity)")
        }
        #expect(try Access.core(shell).play.stage == .playing)
        let vectors: [[Double]] = Access.vectors(samples)
        #expect(Access.anyMidFade(vectors), "the crossing lights fade rather than switch")
        let crossings: Double = WaveKnotKeeperLights.maxHalfRangeCrossingsPerSecond(vectors,
                                                                                    frameRate: Access.frameRate)
        #expect(crossings <= 3, "move/undo flicker of \(move): \(crossings) crossings per second")
        #expect(presenter.lights.isSettled, "the lights settle once the flicker stops")
    }

    /// The drawn lights over the certified win of level 1, sampled 1/60 s apart: under Reduce Flashing no element
    /// crosses half its range more than 3 times per second and the glow takes at least 24 frames (0.4 s) to reach
    /// full; without it the glow reaches full within 10 frames (0.15 s and float rounding).
    @Test(arguments: [true, false])
    func drawnLightsFadeOverAWin(reduceFlashing: Bool) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, reduceFlashing: reduceFlashing)
        let presenter: Presenter = shell.presenter
        Access.quiet(shell)
        #expect(presenter.lights.reducedFlash == reduceFlashing)

        let base: Double = 100
        var samples: [WaveKnotKeeperLightSample] = [try Access.sample(session, presenter, time: base)]
        #expect(presenter.lights.glow == 0)
        let generated: WaveKnotKeeperGenerated = try WaveKnotKeeperExperienceCore.generated(number: 1)
        for move in generated.solution.moves {
            let result: ActionResult = shell.port.send("point.move", Teaching.values(move))
            #expect(result == .accepted, "\(result.code)")
        }
        #expect(try Access.core(shell).play.stage == .won)
        var reached: Int?
        for frame in 1...90 {
            let sample: WaveKnotKeeperLightSample = try Access.sample(session, presenter,
                                                                      time: base + Double(frame) / Access.frameRate)
            samples.append(sample)
            if reached == nil, sample.glow == 1 { reached = frame }
        }
        #expect(presenter.lights.glow == 1)
        #expect(presenter.lights.match == 1, "the won rope matches the target")
        #expect(presenter.lights.isSettled)
        #expect(WaveKnotKeeperRopeScene.glowOpacity(presenter.lights) == 1)
        let glowFrame: Int = try #require(reached, "the glow reaches full")
        let crossings: Double = WaveKnotKeeperLights.maxHalfRangeCrossingsPerSecond(Access.vectors(samples),
                                                                                    frameRate: Access.frameRate)
        if reduceFlashing {
            #expect(crossings <= 3, "Reduce Flashing: \(crossings) crossings per second")
            #expect(glowFrame >= 24, "Reduce Flashing: the glow took \(glowFrame) frames")
        } else {
            #expect(glowFrame <= 10, "normal: the glow took \(glowFrame) frames")
        }
    }

    // MARK: Reduce Motion (FR-R02G0306-004; SC-R02G0306-003)

    /// Under Reduce Motion two stills at different times are byte-identical and the drawn snapshot keeps time 0 and one
    /// pulse; without it the drawn snapshots carry their times and different pulses.
    @Test func reduceMotionStillsIdentical() async throws {
        do {
            let session = ExperienceSession()
            defer { session.close() }
            let shell = try await Access.open(session, reduceMotion: true)
            Access.quiet(shell)
            let first: [UInt8] = try WaveKnotKeeperTest.still(session, width: Access.stillWidth,
                                                              height: Access.stillHeight, time: 0.25)
            let firstDrawn: WaveKnotKeeperSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            let second: [UInt8] = try WaveKnotKeeperTest.still(session, width: Access.stillWidth,
                                                               height: Access.stillHeight, time: 1.3)
            let secondDrawn: WaveKnotKeeperSceneSnapshot = try #require(shell.presenter.lastSnapshot)
            #expect(WaveKnotKeeperTest.nonNightPixels(first) > 0, "the still shows the scene")
            #expect(first == second, "Reduce Motion: stills at 0.25 s and 1.3 s are identical")
            #expect(firstDrawn.time == 0)
            #expect(secondDrawn.time == 0)
            #expect(firstDrawn.pulse == secondDrawn.pulse)
            let core: WaveKnotKeeperExperienceCore = try Access.core(shell)
            #expect(secondDrawn == core.snapshot(time: 0))
        }

        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session, reduceMotion: false)
        Access.quiet(shell)
        _ = try WaveKnotKeeperTest.still(session, width: Access.stillWidth, height: Access.stillHeight, time: 0.25)
        let firstDrawn: WaveKnotKeeperSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        _ = try WaveKnotKeeperTest.still(session, width: Access.stillWidth, height: Access.stillHeight, time: 1.3)
        let secondDrawn: WaveKnotKeeperSceneSnapshot = try #require(shell.presenter.lastSnapshot)
        #expect(Swift.abs(firstDrawn.time - 0.25) < 1e-9, "\(firstDrawn.time)")
        #expect(Swift.abs(secondDrawn.time - 1.3) < 1e-9, "\(secondDrawn.time)")
        #expect(firstDrawn.pulse != secondDrawn.pulse, "without Reduce Motion the pulses move")
    }

    // MARK: Labels and values (FR-R02G0306-001, 005)

    /// The label and value strings built outside the view body and the mirror values the modifiers read: the six
    /// direction titles and spoken names, the picker's "n of N", the progress value, the mode names, the level titles,
    /// the goal line; the controls cover every action; the sound is off by default.
    @Test func labelsValuesAndActionCoverage() async throws {
        let directions: [WaveKnotKeeperDirection] = WaveKnotKeeperDirection.allCases
        let titles: [String] = WaveKnotKeeperControls.titles
        let spoken: [String] = WaveKnotKeeperControls.spoken
        #expect(directions.count == 6)
        #expect(titles == ["+x", "−x", "+y", "−y", "Over", "Under"])
        #expect(spoken == ["right", "left", "up", "down", "towards you (over)", "away from you (under)"])
        for index in 0..<directions.count where index < spoken.count {
            #expect(!titles[index].isEmpty)
            let label: String = "Move the selected point \(spoken[index])"
            #expect(label.contains(Access.word(directions[index])), "\(label)")
            #expect(Plan.directionWord(directions[index]) == Access.word(directions[index]))
        }
        #expect(WaveKnotKeeperControls.modeName(.campaign) == "Campaign")
        #expect(WaveKnotKeeperControls.modeName(.practice) == "Practice")
        #expect(WaveKnotKeeperControls.modeName(.daily(level: 1)) == "Daily level")
        #expect(WaveKnotKeeperControls.levelTitle(7, stars: nil) == "Level 7")
        #expect(WaveKnotKeeperControls.levelTitle(7, stars: 1) == "Level 7 · 1 star")
        #expect(WaveKnotKeeperControls.levelTitle(7, stars: 3) == "Level 7 · 3 stars")
        #expect(WaveKnotKeeperControls.readableWidth == Access.readableWidth)
        #expect(WaveKnotKeeperControls.isDaily(.daily(level: 42)))
        #expect(!WaveKnotKeeperControls.isDaily(.campaign))

        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        let presenter: Presenter = shell.presenter
        Access.quiet(shell)
        let core: WaveKnotKeeperExperienceCore = try Access.core(shell)
        #expect(presenter.nativeActions == Set(WaveKnotKeeperExperienceCore.actionIDs))
        #expect(presenter.gestureActions.isSubset(of: presenter.nativeActions))
        #expect(presenter.mirror.soundOn == false)
        let mirror: WaveKnotKeeperMirror = presenter.mirror
        #expect(mirror.pointCount == core.play.points.count)
        #expect(mirror.pointCount > 0)
        #expect(mirror.selected >= 0 && mirror.selected < mirror.pointCount)
        let pickerValue: String = "\(mirror.selected + 1) of \(mirror.pointCount)"
        #expect(pickerValue == "1 of \(core.play.points.count)", "\(pickerValue)")
        let allowance: Int = core.play.level.allowance
        #expect(WaveKnotKeeperControls.progressValue(mirror) == "Level 1, moves 0 of \(allowance)")
        #expect(WaveKnotKeeperControls.goal(mirror)
                == "Campaign · goal: \(allowance) moves allowed, best possible \(core.certifiedShortest)")

        // The values follow the mirror: a selection and a move.
        #expect(presenter.send("point.select", [1], port: shell.port) == .accepted)
        #expect("\(presenter.mirror.selected + 1) of \(presenter.mirror.pointCount)"
                == "2 of \(core.play.points.count)")
        let move: WaveKnotKeeperMove = try #require(Teaching.nonWinningMove(try Access.core(shell)))
        #expect(Teaching.send(move, shell) == .accepted)
        #expect(WaveKnotKeeperControls.progressValue(presenter.mirror) == "Level 1, moves 1 of \(allowance)")
        #expect(presenter.send("mode.practice", [], port: shell.port) == .accepted)
        #expect(WaveKnotKeeperControls.goal(presenter.mirror).hasPrefix("Practice · goal: 64 moves allowed"))
        #expect(WaveKnotKeeperControls.modeName(presenter.mirror.mode) == "Practice")
        #expect(shell.accessibilitySummary.hasPrefix("Wave Knot Keeper level 1. "))
    }

    /// The panel at the largest accessibility text size in a window 320 points wide (iPhone SE) and 1024 points wide
    /// (iPad): the fitting width stays within the window, the hosted scroll view's content stays within the window and
    /// the readable width (padding included), and the text grows taller than at the default size on the iPhone width.
    @Test func panelAtTheLargestTextSize() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await Access.open(session)
        Access.quiet(shell)
        let screens: [CGSize] = [CGSize(width: 320, height: 568), CGSize(width: 1024, height: 1366)]
        let sizes: [DynamicTypeSize] = [.large, .accessibility5]
        for screen in screens {
            var heights: [CGFloat] = []
            for size in sizes {
                let frame: CGRect = CGRect(origin: .zero, size: screen)
                let window: UIWindow = UIWindow(frame: frame)
                let controller: UIHostingController<AnyView> =
                    UIHostingController(rootView: AnyView(shell.controls.environment(\.dynamicTypeSize, size)))
                window.rootViewController = controller
                window.isHidden = false
                controller.view.frame = frame
                window.layoutIfNeeded()
                controller.view.layoutIfNeeded()
                let what: String = "\(Int(screen.width)) pt at \(size)"
                let fitting: CGSize = controller.sizeThatFits(in: CGSize(width: screen.width,
                                                                         height: .greatestFiniteMagnitude))
                #expect(fitting.width.isFinite && fitting.height.isFinite, "\(what): fitting \(fitting)")
                #expect(fitting.width <= screen.width + 0.5, "\(what): fitting width \(fitting.width)")
                let scroll: UIScrollView = try #require(Access.scrollView(in: controller.view), "\(what): scroll view")
                let content: CGSize = scroll.contentSize
                let limit: CGFloat = min(screen.width, Access.readableWidth) + 0.5
                #expect(content.width <= limit, "\(what): content width \(content.width)")
                #expect(content.height > 0, "\(what): content height")
                heights.append(content.height)
                window.isHidden = true
            }
            if screen.width < 400 && heights.count == 2 {
                #expect(heights[1] > heights[0], "the text grows: \(heights)")
            }
        }
        shell.presenter.controlsDisappeared()
        #expect(shell.presenter.sound.playersMade == 0, "showing the panel with the sound off makes no player")
    }
}
#endif
