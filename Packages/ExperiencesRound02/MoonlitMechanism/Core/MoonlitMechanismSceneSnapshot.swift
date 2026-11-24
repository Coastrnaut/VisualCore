// MoonlitMechanismSceneSnapshot — feature 433 (R02-G14-03) T-R02G1403-002 (FR-R02G1403-002, 003, 004;
// clarifications Q1–Q5). What the renderer may read: an immutable copy of the kernel's state — the gears with their
// phases at the shown key frame, blades, depths, centres and slot tables, the lamp height and count, the wall size, the
// shown key frame with its cast, target and forbidden cells, the kernel's run report of the current set-up (alignment
// errors and per-key-frame counts), the stage, the failure, the actions left and the budget, the level number and the
// presentation time; plus the palette and the three quality tiers. The renderer never holds the kernel, so no drawing
// result can change the game (renderer purity), and the drawn shadows are the kernel's cast cells.
import Foundation

/// The palette of Moonlit Mechanism, as linear colours 0 … 1 (aged gold, lunar blue and ink on paper).
public enum MoonlitMechanismPalette {
    /// The night backdrop, #070A14.
    public static let night = rgb(0x07, 0x0A, 0x14)
    /// The paper wall, #E8DFC8.
    public static let paper = rgb(0xE8, 0xDF, 0xC8)
    /// The ink shadows, #1A1822.
    public static let ink = rgb(0x1A, 0x18, 0x22)
    /// The translucent gear body, #C9A24A (alpha ``gearAlpha``).
    public static let gear = rgb(0xC9, 0xA2, 0x4A)
    /// The gear rim, #E2C277.
    public static let rim = rgb(0xE2, 0xC2, 0x77)
    /// The translucent blade spokes, #B08A3C (alpha ``bladeAlpha``).
    public static let blade = rgb(0xB0, 0x8A, 0x3C)
    /// The lamp, #8FB4E8.
    public static let lamp = rgb(0x8F, 0xB4, 0xE8)
    /// The lamp's glow, #B7CFF2.
    public static let lampGlow = rgb(0xB7, 0xCF, 0xF2)
    /// The target outline (and the dotted missing cells), #4A6FA8.
    public static let target = rgb(0x4A, 0x6F, 0xA8)
    /// The forbidden marks, #B03A3A.
    public static let forbidden = rgb(0xB0, 0x3A, 0x3A)
    /// The stray-cell hatching, #7A3A5A.
    public static let stray = rgb(0x7A, 0x3A, 0x5A)
    /// The outline of what a failure names, #FF6B4A.
    public static let broken = rgb(0xFF, 0x6B, 0x4A)
    /// A lit key-frame card, #C9A24A.
    public static let cardLit = rgb(0xC9, 0xA2, 0x4A)
    /// An unlit key-frame card, #2A2A38.
    public static let cardUnlit = rgb(0x2A, 0x2A, 0x38)
    /// A lit alignment pip, #8FB4E8.
    public static let alignLit = rgb(0x8F, 0xB4, 0xE8)
    /// An unlit alignment pip, #2A2A38.
    public static let alignUnlit = rgb(0x2A, 0x2A, 0x38)
    /// A lit moves bar, #E2C277.
    public static let movesLit = rgb(0xE2, 0xC2, 0x77)
    /// An unlit moves bar, #2A2A38.
    public static let movesUnlit = rgb(0x2A, 0x2A, 0x38)
    /// The glow shells, #F2E2B0.
    public static let glow = rgb(0xF2, 0xE2, 0xB0)
    /// The gear body's opacity.
    public static let gearAlpha: Double = 0.6
    /// The blade spokes' opacity.
    public static let bladeAlpha: Double = 0.5

    /// The palette's main hex values (night, paper, ink, gold, lunar blue), as registered in the catalog.
    public static let hex: [String] = ["#070A14", "#E8DFC8", "#1A1822", "#C9A24A", "#8FB4E8"]

    /// The linear colour of 8-bit components.
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// A quality tier: what the scene draws beyond the shared content (clarification Q2). Stars of the show — gears,
/// blades, shadow cells, targets, marks, gauges, colours and positions — are the same at every tier.
public struct MoonlitMechanismTier: Sendable, Equatable, Hashable {
    /// The tier's index, 0 (richest) … 2 (the design's "Tier 0, D3-safe").
    public let index: Int
    /// The rim's segments per tooth.
    public let segmentsPerTooth: Int
    /// Whether each shadow square has a soft feather edge.
    public let softEdge: Bool
    /// The glow shells around the lamp and the lit cards.
    public let glowShells: Int

    /// The three tiers, richest first.
    public static let all: [MoonlitMechanismTier] = [
        MoonlitMechanismTier(index: 0, segmentsPerTooth: 6, softEdge: true, glowShells: 2),
        MoonlitMechanismTier(index: 1, segmentsPerTooth: 4, softEdge: true, glowShells: 1),
        MoonlitMechanismTier(index: 2, segmentsPerTooth: 2, softEdge: false, glowShells: 0),
    ]

    /// The tier's name, `level-0` … `level-2`.
    public var name: String { "level-\(index)" }

    /// The tier of `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> MoonlitMechanismTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// An immutable copy of what the renderer may read (see the file header).
public struct MoonlitMechanismSceneSnapshot: Sendable, Equatable {
    /// The gears (teeth, starting phases of the level, blades, depths, centres, parents, alignments, slot tables).
    public let gears: [MoonlitMechanismGear]
    /// The gears' phases at the shown key frame (the set-up turned by its handle turns).
    public let phases: [Int]
    /// The set-up phases (before any key frame's turns).
    public let setUpPhases: [Int]
    /// The lamp height.
    public let height: Int
    /// The number of lamp heights.
    public let lampHeights: Int
    /// The wall width W.
    public let width: Int
    /// The wall height H.
    public let rows: Int
    /// The shown key frame, 0 … key frames − 1.
    public let shownFrame: Int
    /// The key frames.
    public let keyFrames: [MoonlitMechanismKeyFrame]
    /// The shown key frame's cast cells (the kernel's).
    public let cast: [Int]
    /// The shown key frame's target cells.
    public let target: [Int]
    /// The forbidden cells.
    public let forbidden: [Int]
    /// The kernel's run report of the current set-up.
    public let report: MoonlitMechanismRunReport
    /// The stage.
    public let stage: MoonlitMechanismStage
    /// The failure, if the play failed.
    public let failure: MoonlitMechanismFailure?
    /// The actions left.
    public let actionsLeft: Int
    /// The action budget.
    public let budget: Int
    /// The level number, 1 … 100.
    public let levelNumber: Int
    /// The presentation time in seconds (never negative or non-finite).
    public let time: Double

    /// A snapshot of `play` with key frame `shownFrame` shown (clamped to the level's key frames).
    public init(play: MoonlitMechanismPlay, shownFrame: Int, levelNumber: Int, time: Double) {
        let level: MoonlitMechanismLevel = play.level
        let frame: Int = min(max(shownFrame, 0), level.keyFrames.count - 1)
        gears = level.gears
        setUpPhases = play.phases
        phases = play.report.frames[frame].phases
        height = play.height
        lampHeights = level.lampHeights
        width = level.width
        rows = level.rows
        self.shownFrame = frame
        keyFrames = level.keyFrames
        cast = play.report.frames[frame].cast
        target = level.keyFrames[frame].target
        forbidden = level.forbidden
        report = play.report
        stage = play.stage
        failure = play.failure
        actionsLeft = play.actionsLeft
        budget = level.budget
        self.levelNumber = levelNumber
        self.time = time.isFinite ? max(0, time) : 0
    }

    /// The shown key frame's report.
    public var shownReport: MoonlitMechanismFrameReport { report.frames[shownFrame] }

    /// The shown key frame's target cells left uncovered (sorted).
    public var missingCells: [Int] {
        let cast: Set<Int> = Set(self.cast)
        return target.filter { !cast.contains($0) }
    }

    /// The shown key frame's cast cells outside its target (sorted).
    public var strayCells: [Int] {
        let target: Set<Int> = Set(self.target)
        return cast.filter { !target.contains($0) }
    }

    /// The covered fraction of key frame `index` (covered / target cells), 0 … 1.
    public func coveredFraction(_ index: Int) -> Double {
        let frame: MoonlitMechanismFrameReport = report.frames[index]
        let total: Int = frame.covered + frame.missing
        return total == 0 ? 0 : Double(frame.covered) / Double(total)
    }

    /// Whether the mesh of gear `index` with its parent is aligned (always true for the driver).
    public func isAligned(_ index: Int) -> Bool { report.errors[index] == 0 }

    /// Whether the play is won.
    public var isWon: Bool { stage == .won }
}
