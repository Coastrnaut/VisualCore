// MicroscopicAuroraPresenter — feature 483 (R02-G19-03) T-R02G1903-006 (FR-R02G1903-003, 004, 005, 007; clarifications
// Q1, Q2, Q4, Q5). Draws the adapter's immutable snapshot with `MicroscopicAuroraDishScene` at the host's quality tier
// (tier n is the catalog's `level-n`, richest first; the levels are the Core's `qualityTiers`), keeps a log of every
// tier change with its reason, and caps the glow under Reduce Flashing. Nothing moves by time: the shown tick is the
// adapter's presentation state (`clock.show`) and is never advanced by time. The tutorial of levels 1 … 3 is shown in
// words, as presentation, not as a kernel stage. A refused action is shown in words. A memory warning releases the GPU
// objects; the next frame rebuilds them. The presenter only reads `core.snapshot`: no drawing result reaches the kernel
// (renderer purity). Its probes (two backdrop corners) let the verification runner check a frame.
#if os(iOS)
import Foundation
import MicroscopicAuroraCore
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

/// What the controls show: the latest state the presenter described, the shown tick and the panel's selection.
@MainActor
@Observable
final class MicroscopicAuroraMirror {
    /// The level number (1 … 100).
    var levelNumber = 1
    /// The actions left.
    var actionsLeft = 0
    /// The action budget.
    var budget = 0
    /// A one-line status: "Ready", "Playing", "Won" or "Failed: " and the failure in words.
    var status = ""
    /// The failure in words, if the play failed.
    var failureText: String?
    /// The progress in words (the kernel's progress description).
    var measureLabel = ""
    /// The level in words.
    var targetLabel = ""
    /// The tutorial in words on levels that have one; nil otherwise.
    var tutorialText: String?
    /// The shown tick, the adapter's.
    var shownTick = 0
    /// The play followed (a copy; never sent anywhere).
    var play: MicroscopicAuroraPlay?
    /// The text of the last refused change, if any.
    var message: String?
    /// The slot the panel edits (0 … 2).
    var slot = 0
    /// The index of the site the panel would place on.
    var siteIndex = 0
    /// The strength the panel would place (1 … 4).
    var strength = 2
    /// Whether the panel would place a counterclockwise well.
    var counterclockwise = true

    /// The level's sites (empty while no play is followed).
    var sites: [MicroscopicAuroraCell] { play?.level.sites ?? [] }
    /// The ticks swum by the followed play's predicted swim (0 while no play is followed).
    var ticksSwum: Int { play?.report.ticks ?? 0 }

    /// `value` clamped to the ticks 0 … ticks swum.
    func clampedTick(_ value: Int) -> Int { min(max(value, 0), ticksSwum) }

    /// The site the panel would place on, or nil without sites.
    var selectedSite: MicroscopicAuroraCell? {
        guard !sites.isEmpty else { return nil }
        return sites[min(max(siteIndex, 0), sites.count - 1)]
    }

    /// The wells in words.
    var wellsLabel: String {
        guard let play else { return "no wells" }
        var parts: [String] = []
        for slot in play.wells.indices { parts.append(play.level.wellDescription(slot, well: play.wells[slot])) }
        return parts.joined(separator: "; ")
    }

    /// The well the panel would place, in words.
    var selectionLabel: String {
        guard let site = selectedSite else { return "no site" }
        return "well \(slot + 1) at " + MicroscopicAuroraLevel.cellWords(site) + ", strength \(strength), "
            + (counterclockwise ? "counterclockwise" : "clockwise")
    }

    /// The shown tick in words.
    var tickLabel: String { "tick \(clampedTick(shownTick)) of \(ticksSwum)" }

    /// Takes the new `play` and presentation.
    func follow(_ play: MicroscopicAuroraPlay, shownTick: Int) {
        self.play = play
        self.shownTick = shownTick
    }

    /// A failure in words, naming what the kernel's reason names; nil without a failure.
    static func failureText(_ failure: MicroscopicAuroraFailure?) -> String? {
        switch failure {
        case let .exit(swimmer, tick)?: "Swimmer \(swimmer + 1) left the dish at tick \(tick)."
        case let .coherence(tick, group)?: "The swarm split at tick \(tick): its largest group had \(group) swimmers."
        case let .coverage(lit, needed)?: "Only \(lit) stencil cells were lit; \(needed) were needed."
        case let .connectedness(cell)?: MicroscopicAuroraLevel.cellWords(cell).capitalizedFirst
            + " is not joined to the pattern."
        case nil: nil
        }
    }

    /// A refused action's reason code in words.
    static func refusalText(code: String) -> String {
        switch code {
        case "r02-g19.stage": "the play is over: undo a failed play or go to the next level"
        case "r02-g19.action": "that well cannot be placed there, or there is nothing to undo, redo or remove"
        case "r02-g19.budget": "no actions are left: play the swim or undo a placement"
        case "r02-g19.stale": "the play changed before the action arrived"
        case "r02-g19.level": "the next level could not be made"
        case MicroscopicAuroraExperienceRule.notWhole: "the slot, cell, strength, sense and tick must be whole numbers"
        case MicroscopicAuroraExperienceRule.tick: "that tick is past the end of the swim"
        default: "that action is not available now"
        }
    }
}

private extension String {
    /// The string with its first letter in upper case.
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// One entry of the tier log: the tier drawn and why it changed.
struct MicroscopicAuroraTierChange: Equatable {
    /// The tier drawn from then on (0 … 2).
    let tier: Int
    /// Why the tier changed.
    let reason: String
}

/// The presenter of Microscopic Aurora.
@MainActor
final class MicroscopicAuroraPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = MicroscopicAuroraExperienceCore

    /// The tutorial shown on levels that have one (presentation, not a kernel stage).
    static let tutorial = "Place magnetic wells on the marked sites so the swimmers' glowing trails cover the "
        + "stencil as one pattern, without a swimmer leaving the dish or the swarm breaking apart; then play the swim."

    /// Whether Reduce Motion is on (the scene is still already).
    let reduceMotion: Bool
    /// Whether the glow gain is capped (Reduce Flashing).
    let reduceFlashing: Bool
    /// What the controls show.
    let mirror = MicroscopicAuroraMirror()
    /// The GL scene.
    let scene = MicroscopicAuroraDishScene()
    /// Every tier change with its reason, oldest first (the tier log, FR-R02G1903-004).
    private(set) var tierLog: [MicroscopicAuroraTierChange] = []
    /// The last snapshot drawn (tests and the description).
    private(set) var lastSnapshot: MicroscopicAuroraSceneSnapshot?

    /// A presenter with the given accessibility settings.
    init(reduceMotion: Bool, reduceFlashing: Bool) {
        self.reduceMotion = reduceMotion
        self.reduceFlashing = reduceFlashing
        scene.reducedFlash = reduceFlashing
    }

    /// The tests' seam: before `setup`, replaces the dish program's fragment source with one that does not compile.
    func breakDishShader() {
        scene.dishFragment = "this is not a shader;"
    }

    /// Why the scene draws its fallback; nil while the programs work.
    var fallbackReason: String? { scene.fallbackReason }

    /// The quality levels drawn, richest first: the Core's `qualityTiers` (`level-0` … `level-2`).
    var qualityLevels: [String] {
        var names: [String] = []
        for tier in 0..<Core.qualityTiers { names.append(MicroscopicAuroraTier.of(tier).name) }
        return names
    }

    /// Records the registry and the aspect.
    func setup(_ context: RenderContext) throws {
        scene.setup(context)
    }

    /// Follows the new drawable size.
    func resize(_ context: RenderContext) {
        scene.resize(context)
    }

    /// Follows `core`'s play and presentation in the mirror when they changed.
    private func follow(_ core: MicroscopicAuroraExperienceCore) {
        if mirror.play != core.play || mirror.shownTick != core.shownTick {
            mirror.follow(core.play, shownTick: core.shownTick)
        }
    }

    /// Draws `core` at host tier `tier`, logging tier changes.
    func draw(_ core: MicroscopicAuroraExperienceCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let drawn = MicroscopicAuroraTier.of(tier)
        if tierLog.last?.tier != drawn.index {
            let reason = tierLog.isEmpty ? "first frame" : "quality controller changed the tier"
            tierLog.append(MicroscopicAuroraTierChange(tier: drawn.index, reason: reason))
        }
        follow(core)
        let time: Double = frame.time.isFinite ? max(0, frame.time) : 0
        let snapshot = core.snapshot(time: time)
        lastSnapshot = snapshot
        try scene.render(snapshot, tier: drawn, context: context, frame: frame)
    }

    /// Releases every GPU object.
    func teardown(_ context: RenderContext) {
        scene.release()
    }

    /// Releases every GPU object (memory warning); the next frame rebuilds them.
    func shedCaches() {
        scene.release()
    }

    /// The frame probes of the frame last drawn: the top-left and bottom-right corners, outside the dish, the gauges
    /// and the actions bars (the camera fits the scene inside a 5 % margin), are `dark` (the abyss backdrop) once a
    /// snapshot was drawn by the real scene; none otherwise.
    func probes(_ core: MicroscopicAuroraExperienceCore) -> [FrameProbe] {
        guard lastSnapshot != nil, scene.fallbackReason == nil else { return [] }
        return [FrameProbe(name: "backdrop-top-left", x: 0.02, y: 0.02, expected: FrameColorClass.dark.rawValue),
                FrameProbe(name: "backdrop-bottom-right", x: 0.98, y: 0.98, expected: FrameColorClass.dark.rawValue)]
            .compactMap { $0 }
    }

    /// The state in words; also refreshes the mirror.
    func describe(_ core: MicroscopicAuroraExperienceCore) -> String {
        let play = core.play
        let level = play.level
        follow(core)
        mirror.levelNumber = core.levelNumber
        mirror.actionsLeft = play.actionsLeft
        mirror.budget = level.budget
        mirror.tutorialText = level.tutorial ? Self.tutorial : nil
        mirror.targetLabel = "Level: a stencil of \(level.stencil.count) cells, \(level.swimmers.count) swimmers, "
            + "\(level.sites?.count ?? 0) well sites, \(level.length) ticks per swim"
        let measure: String = level.progressDescription(report: play.report, wells: play.wells,
                                                        actionsLeft: play.actionsLeft)
        mirror.measureLabel = measure
        var text = "Microscopic Aurora level \(core.levelNumber). "
        text += measure + ". "
        switch play.stage {
        case .won, .result where play.failure == nil:
            text += "The trails covered the stencil as one pattern."
            mirror.status = "Won"
            mirror.failureText = nil
        case .failed, .result:
            let reason: String = MicroscopicAuroraMirror.failureText(play.failure) ?? "The play failed."
            text += reason
            mirror.status = "Failed: " + reason
            mirror.failureText = reason
        default:
            let played: Bool = play.records.contains { record in
                record.kind != .begin && record.kind != .dismissTutorial
            }
            mirror.status = played ? "Playing" : "Ready"
            mirror.failureText = nil
        }
        return text
    }

    /// The control panel.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        AnyView(MicroscopicAuroraControls(port: port, mirror: mirror))
    }
}
#endif
