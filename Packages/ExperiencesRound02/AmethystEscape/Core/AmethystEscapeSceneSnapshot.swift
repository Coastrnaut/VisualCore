// AmethystEscapeSceneSnapshot — feature 363 (R02-G07-03) T-R02G0703-002 (FR-R02G0703-002, 003, 004; clarifications
// Q1–Q4). What the renderer may read: an immutable copy of the kernel's state (the sector count, every shell's apertures,
// walls, blocked wedges and offset, the pearl's pocket, the exit gap's world sector, the stage, the failure, the moves
// spent and the budget) with the level number and the presentation time, plus the palette and the three quality tiers.
// The renderer never holds the kernel, so no drawing result can change the game (renderer purity).
import Foundation

/// The palette of Amethyst Escape, sRGB components 0 … 1 (clarification Q3; the design's "amethyst purple and cool
/// platinum").
public enum AmethystEscapePalette {
    /// The dark backdrop, #0A0614.
    public static let backdrop = rgb(0x0A, 0x06, 0x14)
    /// The translucent amethyst facets, #8E4FD8.
    public static let amethyst = rgb(0x8E, 0x4F, 0xD8)
    /// The shifting facet highlights, #E3CCFF.
    public static let highlight = rgb(0xE3, 0xCC, 0xFF)
    /// The platinum wall fins, arrow and move bar, #D6DCE6.
    public static let platinum = rgb(0xD6, 0xDC, 0xE6)
    /// The dark blocked wedges, #1E1426.
    public static let blocked = rgb(0x1E, 0x14, 0x26)
    /// The pearl, #F6F2FF.
    public static let pearl = rgb(0xF6, 0xF2, 0xFF)
    /// The exit glow, #B8F0FF.
    public static let exit = rgb(0xB8, 0xF0, 0xFF)
    /// The amber failure tint, #FFB020.
    public static let amber = rgb(0xFF, 0xB0, 0x20)

    /// The catalog palette as hex strings: backdrop, amethyst, platinum, pearl, exit.
    public static let hex: [String] = ["#0A0614", "#8E4FD8", "#D6DCE6", "#F6F2FF", "#B8F0FF"]

    /// The colour of `r`, `g`, `b` bytes.
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// One quality tier: it changes only the bevel segments, the highlight layers and the glow shells, never wedges, walls,
/// pearl, exit, colours, marks or positions. Tiers are ordered richest first: index n is the catalog's `level-n` (the
/// design's "Tier 0 D3-safe" is level-2).
public struct AmethystEscapeTier: Sendable, Equatable, Hashable {
    /// The tier index, 0 … 2 (0: richest).
    public let index: Int
    /// The bevel segments per wedge edge.
    public let bevelSegments: Int
    /// The specular highlight layers of the facet shader.
    public let highlightLayers: Int
    /// The glow shells around the pearl and the exit (0: none).
    public let glowShells: Int

    /// The three tiers, richest first: 3/2/1 bevel segments, 3/2/1 highlight layers, 2/1/0 glow shells.
    public static let all: [AmethystEscapeTier] = [
        AmethystEscapeTier(index: 0, bevelSegments: 3, highlightLayers: 3, glowShells: 2),
        AmethystEscapeTier(index: 1, bevelSegments: 2, highlightLayers: 2, glowShells: 1),
        AmethystEscapeTier(index: 2, bevelSegments: 1, highlightLayers: 1, glowShells: 0),
    ]

    /// The catalog name, `level-<index>`.
    public var name: String { "level-\(index)" }

    /// The tier for `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> AmethystEscapeTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// An immutable copy of everything the renderer may read about one Amethyst Escape play at one frame.
public struct AmethystEscapeSceneSnapshot: Sendable, Equatable {
    /// A shell as the renderer sees it (own sector indices, innermost shell first).
    public struct Shell: Sendable, Equatable, Hashable {
        /// The own sectors whose outer wall is open.
        public let apertures: [Int]
        /// The radial walls: wall i stands between own sectors i and i + 1.
        public let walls: [Int]
        /// The own sectors that are blocked wedges.
        public let blocked: [Int]
        /// The shell's offset, 0 … sectors − 1: own sector s sits at world sector (s + offset) mod sectors.
        public let offset: Int
    }

    /// The sectors per shell, 6 … 12.
    public let sectors: Int
    /// The shells, innermost first.
    public let shells: [Shell]
    /// The pearl's pocket (its sector is absolute, a world sector).
    public let pearl: AmethystEscapePocket
    /// The exit gap's world sector: (the outer shell's exit aperture + its offset) mod sectors.
    public let exitGap: Int
    /// The play's stage.
    public let stage: AmethystEscapeStage
    /// Why the play failed, if it did.
    public let failure: AmethystEscapeFailure?
    /// The moves spent.
    public let moves: Int
    /// The level's move budget.
    public let budget: Int
    /// The level number, 1 … 100.
    public let levelNumber: Int
    /// The presentation time in seconds (facet highlights only; never read by the rules).
    public let time: Double

    /// Whether the pearl has left through the exit gap (it is drawn on the exit arrow).
    public var escaped: Bool { stage == .won || (stage == .result && failure == nil) }

    /// A snapshot of `play` at presentation time `time` (non-finite times become 0).
    public init(play: AmethystEscapePlay, levelNumber: Int, time: Double) {
        let level: AmethystEscapeLevel = play.level
        let offsets: [Int] = play.crystal.offsets
        sectors = level.sectors
        shells = level.shells.indices.map { index in
            let shell: AmethystEscapeShell = level.shells[index]
            return Shell(apertures: shell.apertures, walls: shell.walls, blocked: shell.blocked, offset: offsets[index])
        }
        pearl = play.crystal.pearl
        exitGap = ((level.exitGap + offsets[level.outermost]) % level.sectors + level.sectors) % level.sectors
        stage = play.stage
        failure = play.failure
        moves = play.moves
        budget = level.budget
        self.levelNumber = levelNumber
        self.time = time.isFinite ? time : 0
    }
}

// Feature 364 (R02-G07-04) T-R02G0704-002 (FR-R02G0704-006; clarification Q5): the drag preview.
extension AmethystEscapeSceneSnapshot {
    /// A copy of this snapshot with shell `shell`'s offset turned by `sectors` (positive: clockwise from above, the
    /// kernel's +1) modulo the sector count, the pearl's absolute sector turned with it when it rests in that shell,
    /// and the exit gap's world sector following the outer shell; everything else unchanged. An unknown shell gives
    /// the snapshot unchanged. Presentation only: the kernel never sees a preview.
    public func previewing(shell: Int, sectors turn: Int) -> AmethystEscapeSceneSnapshot {
        guard shells.indices.contains(shell), sectors > 0 else { return self }
        let step: Int = ((turn % sectors) + sectors) % sectors
        guard step != 0 else { return self }
        var turned: [Shell] = shells
        let old: Shell = shells[shell]
        turned[shell] = Shell(apertures: old.apertures, walls: old.walls, blocked: old.blocked,
                              offset: (old.offset + step) % sectors)
        let pearl: AmethystEscapePocket = self.pearl.shell == shell
            ? AmethystEscapePocket(shell: shell, sector: (self.pearl.sector + step) % sectors) : self.pearl
        let exit: Int = shell == shells.count - 1 ? (exitGap + step) % sectors : exitGap
        return AmethystEscapeSceneSnapshot(sectors: sectors, shells: turned, pearl: pearl, exitGap: exit, stage: stage,
                                           failure: failure, moves: moves, budget: budget, levelNumber: levelNumber,
                                           time: time)
    }

    /// Every field given (the preview's copy).
    private init(sectors: Int, shells: [Shell], pearl: AmethystEscapePocket, exitGap: Int, stage: AmethystEscapeStage,
                 failure: AmethystEscapeFailure?, moves: Int, budget: Int, levelNumber: Int, time: Double) {
        self.sectors = sectors
        self.shells = shells
        self.pearl = pearl
        self.exitGap = exitGap
        self.stage = stage
        self.failure = failure
        self.moves = moves
        self.budget = budget
        self.levelNumber = levelNumber
        self.time = time
    }
}
