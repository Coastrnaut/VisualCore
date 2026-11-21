// ColorfallCanyonsPresenter — feature 343 (R02-G05-03) T-R02G0503-006 (FR-R02G0503-003, 004, 005, 007; clarifications
// Q2, Q4). Draws the adapter's immutable snapshot with `ColorfallCanyonsCanyonScene` at the host's quality tier (tier n
// is the catalog's `level-n`, richest first), keeps a log of every tier change with its reason, holds the flow bands
// still under Reduce Motion (the snapshot time stays at 0) and caps the glow under Reduce Flashing. A memory warning
// releases the GPU objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result
// reaches the kernel (renderer purity). Its probes (two night corners) let the verification runner check a frame.
#if os(iOS)
import ColorfallCanyonsCore
import Foundation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

/// What the controls show: the latest state the presenter described.
@MainActor
@Observable
final class ColorfallCanyonsMirror {
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The carves and valve toggles left.
    var remaining = 0
    /// The ticks run and the tick limit.
    var tick = 0
    var tickLimit = 0
    /// A one-line status (stage, failure).
    var status = ""
    /// The carvable cells in order and the index picked (presentation only).
    var carvable: [Int] = []
    var pickedIndex = 0
    /// The columns of the grid (for the cell label).
    var columns = 1
    /// The springs' names and valve states.
    var springNames: [String] = []
    var springStates: [String] = []
    /// The text of the last refused change, if any.
    var message: String?

    /// The picked cell, if any cell can be carved.
    var pickedCell: Int? {
        carvable.isEmpty ? nil : carvable[min(max(pickedIndex, 0), carvable.count - 1)]
    }

    /// The picked cell as "row r, column c" (1-based), or "none".
    var pickedCellLabel: String {
        guard let cell = pickedCell else { return "none" }
        return "row \(cell / max(columns, 1) + 1), column \(cell % max(columns, 1) + 1)"
    }

    /// Moves the pick by `delta` carvable cells, wrapping.
    func pickNext(_ delta: Int) {
        guard !carvable.isEmpty else { return }
        pickedIndex = ((pickedIndex + delta) % carvable.count + carvable.count) % carvable.count
    }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct ColorfallCanyonsTierChange: Equatable {
    let tier: Int
    let reason: String
}

/// The presenter of Colorfall Canyons.
@MainActor
final class ColorfallCanyonsPresenter: ExperiencePresenter {
    typealias Core = ColorfallCanyonsExperienceCore

    let reduceMotion: Bool
    let reduceFlashing: Bool
    let mirror = ColorfallCanyonsMirror()
    let scene = ColorfallCanyonsCanyonScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G0503-004).
    private(set) var tierLog: [ColorfallCanyonsTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: ColorfallCanyonsSceneSnapshot?

    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
    }

    /// The tests' seam: before `setup`, replaces the fluid program's fragment source with one that does not compile.
    func breakFluidShader() {
        scene.fluidFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    func draw(_ core: ColorfallCanyonsExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = ColorfallCanyonsTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(ColorfallCanyonsTierChange(tier: drawn.index, reason: reason))
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

    /// The frame probes of the frame last drawn: the top-left and bottom-right background corners, outside the terrain
    /// (the camera fits the scene inside a 5 % margin), are `dark` (the night clear) once a snapshot was drawn by the real
    /// scene; none otherwise.
    func probes(_ core: ColorfallCanyonsExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "night-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "night-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    func describe(_ core: ColorfallCanyonsExperienceCore) -> String {
        let play = core.play
        let level = play.level
        let snapshot = core.snapshot(time: 0)
        mirror.levelNumber = core.levelNumber
        mirror.remaining = play.remaining
        mirror.tick = snapshot.tick
        mirror.tickLimit = snapshot.tickLimit
        mirror.columns = level.columns
        mirror.carvable = (0..<level.cellCount).filter { level.isCarvable($0, heights: snapshot.heights) }
        mirror.springNames = snapshot.springs.map(\.color.name)
        mirror.springStates = snapshot.springs.map { spring in
            spring.supplyLeft == 0 ? "dry" : (spring.open ? "open, \(spring.supplyLeft) units left" : "closed")
        }
        var text = "Colorfall Canyons level \(core.levelNumber). "
        text += "Tick \(snapshot.tick) of \(snapshot.tickLimit); \(play.remaining) actions left. "
        for (index, spring) in snapshot.springs.enumerated() {
            text += "Spring \(index + 1), \(spring.color.name): \(mirror.springStates[index]). "
        }
        for (index, basin) in snapshot.basins.enumerated() {
            let masses = snapshot.masses[basin.cell]
            let parts = ColorfallCanyonsColor.allCases.map { "\($0.name) \(masses[$0.rawValue])" }
            text += "Basin \(index + 1) holds \(parts.joined(separator: ", ")); target \(basin.description). "
        }
        switch play.stage {
        case .won:
            text += "Every basin is filled with its colours."
            mirror.status = "Won"
        case .failed:
            let reason: String
            switch play.failure {
            case .contamination: reason = "Too much of a wrong colour entered a protected basin."
            case .overflow: reason = "A basin overflowed."
            case .time, .none: reason = "Time ran out before every basin was filled."
            }
            text += reason
            mirror.status = "Failed: " + reason
        default:
            mirror.status = "Playing"
        }
        return text
    }

    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(ColorfallCanyonsControls(port: port, mirror: mirror))
    }
}
#endif
