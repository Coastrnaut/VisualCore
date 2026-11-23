// EchoCartographerPresenter — feature 403 (R02-G11-03) T-R02G1103-006 (FR-R02G1103-003, 004, 005, 007; clarifications
// Q2, Q4, Q5). Draws the adapter's immutable snapshot with `EchoCartographerChamberScene` at the host's quality tier
// (tier n is the catalog's `level-n`, richest first), keeps a log of every tier change with its reason, draws the rings
// and flares at rest under Reduce Motion, and caps the glow under Reduce Flashing. The presentation time handed to the
// snapshot is the seconds since the last pulse: the presenter notes the frame time whenever the play's last echo
// changes. The panel's cursor (column, row) lives in the mirror as presentation state: a level opens with the cursor on
// the entry, clamped to the chamber; it never reaches the kernel except through the declared `cell.*` controls. A memory
// warning releases the GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing
// result reaches the kernel (renderer purity). Its probes (two ground corners) let the verification runner check a
// frame.
// Feature 404 (R02-G11-04): `pointer(_:viewSize:port:)` routes canvas touches through
// `EchoCartographerGestureController` with the drawn snapshot and play: pulses, claims and marks go through the port
// (refusals are shown and kept with their code in `refusalLog`), cursor moves go to the mirror, and the scene draws the
// controller's orbit; "Reset view" and a double tap on empty space return to the authored view.
#if os(iOS)
import EchoCartographerCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show and choose: the latest state the presenter described and the panel's cursor.
@MainActor
@Observable
final class EchoCartographerMirror {
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The energy left and the budget.
    var energy = 0
    var budget = 0
    /// A one-line status (stage, failure).
    var status = ""
    /// The progress and the last echo in words.
    var measureLabel = ""
    /// The level in words.
    var targetLabel = ""
    /// The cursor's column and row.
    var column = 0
    var row = 0
    /// The play the cursor is clamped against (a copy; never sent anywhere).
    var play: EchoCartographerPlay?
    /// The text of the last refused change, if any.
    var message: String?

    /// The chamber's width and height (5 while no play is followed).
    var width: Int { play?.level.chamber.width ?? 5 }
    var height: Int { play?.level.chamber.height ?? 5 }
    /// The cursor's cell.
    var cursor: EchoCartographerCell { EchoCartographerCell(x: column, y: row) }
    /// The cursor's column in words.
    var columnLabel: String { "column \(column)" }
    /// The cursor's row in words.
    var rowLabel: String { "row \(row)" }
    /// The cursor's cell in words, with what is known of it.
    var cursorLabel: String {
        guard let play else { return columnLabel + ", " + rowLabel }
        return play.level.cellName(cursor, knowledge: play.knowledge)
    }

    /// Moves the cursor's column by `delta`, clamped to the chamber.
    func stepColumn(_ delta: Int) { column = min(max(column + delta, 0), width - 1) }

    /// Moves the cursor's row by `delta`, clamped to the chamber.
    func stepRow(_ delta: Int) { row = min(max(row + delta, 0), height - 1) }

    /// Takes the new `play`: a new level puts the cursor on the entry; otherwise it is clamped to the chamber.
    func follow(_ play: EchoCartographerPlay) {
        let changedLevel: Bool = self.play?.level.id != play.level.id
        self.play = play
        if changedLevel {
            column = play.level.entry.x
            row = play.level.entry.y
        } else {
            stepColumn(0)
            stepRow(0)
        }
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct EchoCartographerTierChange: Equatable {
    let tier: Int
    let reason: String
}

/// The presenter of Echo Cartographer.
@MainActor
final class EchoCartographerPresenter: ExperiencePresenter {
    typealias Core = EchoCartographerExperienceCore

    let reduceMotion: Bool
    let reduceFlashing: Bool
    let mirror = EchoCartographerMirror()
    let scene = EchoCartographerChamberScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G1103-004).
    private(set) var tierLog: [EchoCartographerTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: EchoCartographerSceneSnapshot?
    /// The last echo seen and the frame time it was first drawn (the rings' clock starts there).
    private var pulseEcho: EchoCartographerEcho?
    private var pulseSeen = false
    private var pulseStart: Double = 0
    /// The play last drawn (the gestures read it).
    private(set) var lastPlay: EchoCartographerPlay?
    /// The gesture controller (feature 404): taps, marker drags, held claims, double taps, orbit.
    private(set) var gestures = EchoCartographerGestureController()
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

    /// The tests' seam: before `setup`, replaces the chamber program's fragment source with one that does not compile.
    func breakChamberShader() {
        scene.chamberFragment = "this is not a shader;"
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
    private func follow(_ core: EchoCartographerExperienceCore) {
        if mirror.play != core.play { mirror.follow(core.play) }
    }

    /// The seconds since the last pulse at frame time `now`: the clock restarts whenever the play's last echo changes
    /// (a new pulse, or an undo or redo that brings another echo back).
    func pulseTime(_ core: EchoCartographerExperienceCore, now: Double) -> Double {
        let echo: EchoCartographerEcho? = core.play.lastEcho
        if !pulseSeen || echo != pulseEcho {
            pulseSeen = true
            pulseEcho = echo
            pulseStart = now
        }
        return max(0, now - pulseStart)
    }

    func draw(_ core: EchoCartographerExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = EchoCartographerTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(EchoCartographerTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        let time = pulseTime(core, now: frame.time)
        let snapshot = core.snapshot(time: time)
        lastSnapshot = snapshot
        lastPlay = core.play
        gestures.tick(at: ProcessInfo.processInfo.systemUptime)
        scene.orbit = gestures.orbit
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    func teardown(_ context: RenderContext) {
        scene.release()
    }

    func shedCaches() {
        scene.release()
    }

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the chamber (the camera
    /// fits the scene inside a 5 % margin), are `dark` (the abyss ground) once a snapshot was drawn by the real scene;
    /// none otherwise.
    func probes(_ core: EchoCartographerExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "ground-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "ground-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    func describe(_ core: EchoCartographerExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        mirror.levelNumber = core.levelNumber
        mirror.energy = play.energy
        mirror.budget = level.energy
        mirror.targetLabel = "Level: " + level.levelDescription()
        var measure: String = level.progressDescription(located: play.located.count, energy: play.energy)
        if let echo = play.lastEcho { measure += "; " + level.echoDescription(echo) }
        mirror.measureLabel = measure
        var text = "Echo Cartographer level \(core.levelNumber). "
        text += measure + ". "
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "Every beacon is located."
            mirror.status = "Won"
        case .failed, .result:
            let reason: String = EchoCartographerSceneSnapshot.failureText(play.failure) ?? "The play failed."
            text += reason
            mirror.status = "Failed: " + reason
        default:
            mirror.status = play.records.isEmpty ? "Ready" : "Playing"
        }
        if play.stage == .won || play.stage == .failed || play.stage == .result {
            text += " " + Self.finishedMessage + "."
        }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(EchoCartographerControls(mirror: mirror,
                                         resetView: { [weak self] in self?.resetView() },
                                         sender: { [weak self] control, values in
                                             self?.send(control, values, port: port)
                                         }))
    }

    // MARK: Touch controls (feature 404, R02-G11-04)

    /// The canvas gestures send pulses, claims and marks; the cursor and the orbit are presentation state.
    var gestureActions: Set<String> { ["cell.pulse", "cell.claim", "cell.mark"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(EchoCartographerExperienceCore.actionIDs) }

    /// What a gesture on a finished play shows.
    static let finishedMessage = "The play is over: undo or go to the next level"

    /// Routes a canvas touch through the gesture controller with the drawn snapshot and play and applies what it
    /// returns, in order: pulses, claims and marks are sent through the port, cursor moves go to the mirror; a
    /// one-finger gesture that ends on a won, failed or finished play explains that the play is over.
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let snapshot = lastSnapshot, let play = lastPlay else { return }
        let before: EchoCartographerGestureController.State = gestures.state
        let actions: [EchoCartographerGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: snapshot,
                                                                       play: play)
        let finished: Bool = play.stage == .won || play.stage == .failed || play.stage == .result
        let oneFinger: Bool = before == .cellPress || before == .markerDrag || before == .cellDrag || before == .held
        if event.phase == .ended, finished, oneFinger {
            mirror.message = Self.finishedMessage
        }
        for action in actions {
            switch action {
            case let .pulse(x, y):
                send("cell.pulse", [Double(x), Double(y)], port: port)
            case let .claim(x, y):
                send("cell.claim", [Double(x), Double(y)], port: port)
            case let .mark(x, y):
                send("cell.mark", [Double(x), Double(y)], port: port)
            case let .moveCursor(x, y):
                mirror.column = x
                mirror.row = y
                mirror.stepColumn(0)
                mirror.stepRow(0)
            case .resetView:
                break   // the controller has already returned to the authored orbit; the next frame draws it
            }
        }
        scene.orbit = gestures.orbit
    }

    /// Returns the camera to the authored view ("Reset view"; presentation only).
    func resetView() {
        gestures.resetView()
        scene.orbit = gestures.orbit
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
