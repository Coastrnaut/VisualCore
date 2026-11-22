// AmethystEscapePresenter — feature 363 (R02-G07-03) T-R02G0703-006 (FR-R02G0703-003, 004, 005, 007; clarifications
// Q2, Q4). Draws the adapter's immutable snapshot with `AmethystEscapeCrystalScene` at the host's quality tier (tier n
// is the catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the facet
// highlights still under Reduce Motion (the snapshot time stays at 0) and caps the glow under Reduce Flashing. A memory
// warning releases the GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing
// result reaches the kernel (renderer purity). Its probes (two backdrop corners) let the verification runner check a
// frame.
// Feature 364 (R02-G07-04) T-R02G0704-006 (FR-R02G0704-001 … 008; clarifications Q1–Q5): canvas touches go through
// `AmethystEscapeGestureController`: a shell dragged round the centre sends one `shell.rotate [k, ±1]` per whole sector
// swept (the shortest way round), a tap on the pearl sends `pearl.advance`, a tap on a shell picks it in the panel, a
// double tap on a shell isolates it (the other shells darken; again to clear; "Show all layers" and `level.next` clear
// it), two fingers orbit the camera and a double tap on empty space or `resetView()` ("Reset view") returns to the
// authored view (presentation only: never in the digest, the snapshot or the kernel). While a shell is dragged the scene
// draws the turn it would make and the description begins "Shell k would turn n sectors clockwise"; a gesture on a
// finished play says "The play is over: undo or go to the next level". A refused action is shown in the panel and its
// code kept in ``AmethystEscapePresenter/refusalLog``.
#if os(iOS)
import AmethystEscapeCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// What the controls show: the latest state the presenter described.
@MainActor
@Observable
final class AmethystEscapeMirror {
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The moves spent and the budget.
    var moves = 0
    var budget = 0
    /// A one-line status (stage, failure).
    var status = ""
    /// Each shell's name ("shell 1 (inner)") and offset (presentation only).
    var shellNames: [String] = []
    var offsets: [Int] = []
    /// The sectors per shell.
    var sectors = 0
    /// Where the pearl is, in words.
    var pearlLabel = ""
    /// The shell picked (presentation only).
    var pickedShell = 0
    /// The text of the last refused change, if any.
    var message: String?

    /// The picked shell's name, or "none".
    var pickedShellLabel: String {
        shellNames.indices.contains(pickedShell) ? shellNames[pickedShell].capitalized : "none"
    }

    /// The picked shell's turn as "turned t of N".
    var pickedOffsetLabel: String {
        guard offsets.indices.contains(pickedShell) else { return "" }
        return "turned \(offsets[pickedShell]) of \(sectors)"
    }

    /// Moves the pick by `delta` shells, wrapping.
    func pickNext(_ delta: Int) {
        guard !shellNames.isEmpty else { return }
        pickedShell = ((pickedShell + delta) % shellNames.count + shellNames.count) % shellNames.count
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct AmethystEscapeTierChange: Equatable {
    let tier: Int
    let reason: String
}

/// The presenter of Amethyst Escape.
@MainActor
final class AmethystEscapePresenter: ExperiencePresenter {
    typealias Core = AmethystEscapeExperienceCore

    let reduceMotion: Bool
    let reduceFlashing: Bool
    let mirror = AmethystEscapeMirror()
    let scene = AmethystEscapeCrystalScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G0703-004).
    private(set) var tierLog: [AmethystEscapeTierChange] = []
    /// The last snapshot of the kernel drawn (tests, the description and the gestures; never a preview).
    private(set) var lastSnapshot: AmethystEscapeSceneSnapshot?
    /// The gesture controller (feature 364): shell drags, pearl taps, selection, isolation, orbit.
    private(set) var gestures = AmethystEscapeGestureController()
    /// The reason codes of refused actions, oldest first, at most ``refusalLogLimit`` (observability).
    private(set) var refusalLog: [String] = []
    /// The most refusal codes kept.
    static let refusalLogLimit = 64

    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
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

    func draw(_ core: AmethystEscapeExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = AmethystEscapeTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(AmethystEscapeTierChange(tier: drawn.index, reason: reason))
        }
        let time = reduceMotion ? 0 : frame.time
        let snapshot = core.snapshot(time: time)
        lastSnapshot = snapshot
        scene.orbit = gestures.orbit
        scene.isolated = gestures.isolated
        try scene.render(previewed(snapshot), tier: drawn, context: context, frame: frame, animate: !reduceMotion)
    }

    /// `snapshot` with the turn of the shell being dragged, while a drag previews one; `snapshot` otherwise.
    func previewed(_ snapshot: AmethystEscapeSceneSnapshot) -> AmethystEscapeSceneSnapshot {
        guard gestures.state == .shellDrag, let shell = gestures.draggedShell, gestures.candidateSectors != 0 else {
            return snapshot
        }
        return snapshot.previewing(shell: shell, sectors: gestures.candidateSectors)
    }

    // MARK: Touch controls (feature 364)

    /// The canvas gestures send turns and advances.
    var gestureActions: Set<String> { ["shell.rotate", "pearl.advance"] }

    /// The native controls send every action a gesture can, and more.
    var nativeActions: Set<String> { Set(AmethystEscapeExperienceCore.actionIDs) }

    /// What a turn or advance gesture on a finished play shows.
    static let finishedMessage = "The play is over: undo or go to the next level"

    /// The touch-down of the current one-finger touch: its point and what it picked (for the finished-play message).
    private var touchDown: (id: Int, point: Vec2, pick: AmethystEscapePick)?

    /// Routes a canvas touch through the gesture controller and sends the actions it returns, in order; a drag on a
    /// shell (at least ``AmethystEscapeGestureController/dragDistance`` points) or a touch on the pearl on a finished
    /// play explains that the play is over (a shell tap still picks the shell).
    func pointer(_ event: PointerEvent, viewSize: Vec2, port: ExperienceActionPort) {
        guard let snapshot = lastSnapshot else { return }
        switch event.phase {
        case .began:
            let pick: AmethystEscapePick = AmethystEscapePicker.pick(
                SIMD2(Double(event.location.x), Double(event.location.y)),
                size: SIMD2(Double(viewSize.x), Double(viewSize.y)), snapshot: snapshot, orbit: gestures.orbit)
            touchDown = touchDown == nil ? (event.id, event.location, pick) : nil   // a second finger: no message
        case .cancelled:
            touchDown = nil
        default:
            break
        }
        let actions: [AmethystEscapeGestureAction] = gestures.handle(event, viewSize: viewSize, snapshot: snapshot)
        if event.phase == .ended, let down = touchDown, down.id == event.id {
            touchDown = nil
            let travel: Double = Double((event.location - down.point).length)
            let moved: Bool = down.pick != .empty
                && (down.pick == .pearl || travel >= AmethystEscapeGestureController.dragDistance)
            if moved, actions.isEmpty, snapshot.stage != .playing { mirror.message = Self.finishedMessage }
        }
        for action in actions {
            switch action {
            case .turn(let shell, let step):
                send("shell.rotate", [Double(shell), Double(step)], port: port)
            case .advance:
                send("pearl.advance", [], port: port)
            case .select(let shell):
                mirror.pickedShell = shell
            case .isolate:
                break   // the controller keeps the isolated shell; the next frame draws it
            case .resetView:
                break   // the controller has already returned to the authored orbit; the next frame draws it
            }
        }
    }

    /// Drops a touch in progress (the shell suspends the experience): a gesture under way is abandoned without an
    /// action; the orbit is presentation only and returns to the authored view.
    func cancelPointers() {
        gestures.cancel()
    }

    /// Returns the camera to the authored view ("Reset view").
    func resetView() {
        gestures.resetView()
    }

    /// Brings every shell back ("Show all layers").
    func showAllLayers() {
        gestures.clearIsolation()
    }

    /// Sends `control` with `values`, shows a refusal in the panel and keeps its code in ``refusalLog``; an accepted
    /// `level.next` clears the isolation.
    @discardableResult
    func send(_ control: String, _ values: [Double], port: ExperienceActionPort) -> ActionResult {
        let result = port.send(control, values)
        if result.isAccepted {
            mirror.message = nil
            if control == "level.next" { gestures.clearIsolation() }
        } else {
            mirror.message = "That change was refused: \(result.code)"
            refusalLog.append(result.code)
            if refusalLog.count > Self.refusalLogLimit { refusalLog.removeFirst(refusalLog.count - Self.refusalLogLimit) }
        }
        return result
    }

    func teardown(_ context: RenderContext) {
        scene.release()
    }

    func shedCaches() {
        scene.release()
    }

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the crystal (the camera
    /// fits the scene inside a 5 % margin), are `dark` (the backdrop clear) once a snapshot was drawn by the real scene;
    /// none otherwise.
    func probes(_ core: AmethystEscapeExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "backdrop-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "backdrop-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    func describe(_ core: AmethystEscapeExperienceCore) -> String {
        let play = core.play
        let level = play.level
        let snapshot = core.snapshot(time: 0)
        mirror.levelNumber = core.levelNumber
        mirror.moves = snapshot.moves
        mirror.budget = snapshot.budget
        mirror.sectors = snapshot.sectors
        mirror.shellNames = level.shells.indices.map { level.shellName($0) }
        mirror.offsets = snapshot.shells.map(\.offset)
        if mirror.pickedShell >= level.shells.count { mirror.pickedShell = 0 }
        let pearl = snapshot.escaped ? "outside the crystal"
            : "in \(level.shellName(snapshot.pearl.shell)), \(level.sectorName(snapshot.pearl.sector))"
        mirror.pearlLabel = "The pearl is " + pearl
        var text = ""
        if gestures.state == .shellDrag, let shell = gestures.draggedShell, level.shells.indices.contains(shell) {
            let n: Int = gestures.candidateSectors
            let name: String = level.shellName(shell)
            let sectors: String = abs(n) == 1 ? "1 sector" : "\(abs(n)) sectors"
            text += n == 0 ? name.prefix(1).uppercased() + name.dropFirst() + " would not turn. "
                : name.prefix(1).uppercased() + name.dropFirst()
                    + " would turn \(sectors) \(n > 0 ? "clockwise" : "anticlockwise"). "
        }
        if let isolated = gestures.isolated, level.shells.indices.contains(isolated) {
            text += "Showing \(level.shellName(isolated)) alone. "
        }
        text += "Amethyst Escape level \(core.levelNumber). "
        text += "\(snapshot.moves) of \(snapshot.budget) moves spent. The pearl is \(pearl). "
        text += "The exit gap is at \(level.sectorName(snapshot.exitGap)). "
        for index in level.shells.indices {
            let description = level.description(ofShell: index)
            text += description.prefix(1).uppercased() + description.dropFirst()
                + "; turned \(snapshot.shells[index].offset). "
        }
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "The pearl escaped through the exit gap."
            mirror.status = "Won"
        case .failed, .result:
            let reason: String
            switch play.failure {
            case .wedge(let shell, let sector):
                reason = "The pearl fell into the blocked wedge of \(level.shellName(shell)), "
                    + "\(level.sectorName(sector))."
            case .budget, .none: reason = "The move budget ran out before the pearl escaped."
            }
            text += reason
            mirror.status = "Failed: " + reason
        default:
            mirror.status = snapshot.moves == 0 ? "Ready" : "Playing"
        }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(AmethystEscapeControls(port: port, mirror: mirror, presenter: self))
    }
}
#endif
