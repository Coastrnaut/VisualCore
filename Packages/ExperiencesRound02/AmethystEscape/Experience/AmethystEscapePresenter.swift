// AmethystEscapePresenter — feature 363 (R02-G07-03) T-R02G0703-006 (FR-R02G0703-003, 004, 005, 007; clarifications
// Q2, Q4). Draws the adapter's immutable snapshot with `AmethystEscapeCrystalScene` at the host's quality tier (tier n
// is the catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the facet
// highlights still under Reduce Motion (the snapshot time stays at 0) and caps the glow under Reduce Flashing. A memory
// warning releases the GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing
// result reaches the kernel (renderer purity). Its probes (two backdrop corners) let the verification runner check a
// frame.
#if os(iOS)
import AmethystEscapeCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

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
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: AmethystEscapeSceneSnapshot?

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
        try scene.render(snapshot, tier: drawn, context: context, frame: frame, animate: !reduceMotion)
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
        var text = "Amethyst Escape level \(core.levelNumber). "
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
        AnyView(AmethystEscapeControls(port: port, mirror: mirror))
    }
}
#endif
