// BackwardsAuroraSceneSnapshot — feature 393 (R02-G10-03) T-R02G1003-002 (FR-R02G1003-002, 003, 004; clarifications
// Q1–Q5). What the renderer may read: an immutable copy of the kernel's state — the wave's samples (the ribbon is drawn
// through exactly these), the target's samples (the ghost trail), the checkpoint positions and which are matched, the
// bend limit and the positions of the bends above it (kink marks), the torn seam if the play tore, the chosen section
// (presentation state of the controls), the stage, the failure, the reversals spent, the budget, the level number and
// the presentation time; plus the palette and the three quality tiers. The renderer never holds the kernel, so no
// drawing result can change the game (renderer purity).
import Foundation

/// The palette of Backwards Aurora, sRGB components 0 … 1 (clarification Q3; the design's "deep ocean cyan, pale lilac,
/// midnight").
public enum BackwardsAuroraPalette {
    /// The midnight ground, #070B1F.
    public static let ground = rgb(0x07, 0x0B, 0x1F)
    /// The deep-ocean-cyan aurora ribbon, #1FC8D6.
    public static let ribbon = rgb(0x1F, 0xC8, 0xD6)
    /// The ribbon's shimmer and pulse highlight, #9FF4FA.
    public static let ribbonHighlight = rgb(0x9F, 0xF4, 0xFA)
    /// The glow around the ribbon, #6FE8F0.
    public static let glow = rgb(0x6F, 0xE8, 0xF0)
    /// The pale lilac ghost trail of the target, #C9B8F0.
    public static let ghost = rgb(0xC9, 0xB8, 0xF0)
    /// A checkpoint's tick and ring, #DCD3FA.
    public static let ring = rgb(0xDC, 0xD3, 0xFA)
    /// The disc of a matched checkpoint, #F4F0FF.
    public static let matched = rgb(0xF4, 0xF0, 0xFF)
    /// The cross on a bend above the limit, #FF8A7A.
    public static let kink = rgb(0xFF, 0x8A, 0x7A)
    /// The cross on a torn seam, #FF3B30.
    public static let tear = rgb(0xFF, 0x3B, 0x30)
    /// The band behind the chosen section, #2A3570.
    public static let band = rgb(0x2A, 0x35, 0x70)
    /// A spent bar of the reversal gauge, #1FC8D6.
    public static let spent = rgb(0x1F, 0xC8, 0xD6)
    /// An unspent bar of the reversal gauge, #2B3352.
    public static let unspent = rgb(0x2B, 0x33, 0x52)

    /// The catalog palette as hex strings: ground, ribbon, ghost, ring, kink.
    public static let hex: [String] = ["#070B1F", "#1FC8D6", "#C9B8F0", "#DCD3FA", "#FF8A7A"]

    /// The colour of `r`, `g`, `b` bytes.
    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// One quality tier: it changes only the trailing aurora layers, the travelling pulses and the glow shells, never
/// samples, markers, colours, the gauge or positions. Tiers are ordered richest first: index n is the catalog's
/// `level-n` (the design's "Tier 0 D3-safe" is level-2).
public struct BackwardsAuroraTier: Sendable, Equatable, Hashable {
    /// The tier index, 0 … 2 (0: richest).
    public let index: Int
    /// The aurora layers drawn: the ribbon plus the trailing copies behind it (1: the ribbon alone).
    public let trailingLayers: Int
    /// The travelling pulse beads per section of the timeline (0: none).
    public let pulses: Int
    /// The glow shells around the ribbon (0: none).
    public let glowShells: Int

    /// The three tiers, richest first: 3/2/1 layers, 2/1/0 pulses, 2/1/0 glow shells.
    public static let all: [BackwardsAuroraTier] = [
        BackwardsAuroraTier(index: 0, trailingLayers: 3, pulses: 2, glowShells: 2),
        BackwardsAuroraTier(index: 1, trailingLayers: 2, pulses: 1, glowShells: 1),
        BackwardsAuroraTier(index: 2, trailingLayers: 1, pulses: 0, glowShells: 0),
    ]

    /// The catalog name, `level-<index>`.
    public var name: String { "level-\(index)" }

    /// The tier for `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> BackwardsAuroraTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// An immutable copy of everything the renderer may read about one Backwards Aurora play at one frame.
public struct BackwardsAuroraSceneSnapshot: Sendable, Equatable {
    /// The wave's samples, position 0 first: the ribbon passes through exactly these.
    public let samples: [Int]
    /// The target's samples: the ghost trail.
    public let target: [Int]
    /// The checkpoint positions, ascending.
    public let checkpoints: [Int]
    /// Per checkpoint: whether the wave has the target's height there.
    public let matched: [Bool]
    /// The bend limit L.
    public let bendLimit: Int
    /// The interior positions whose bend exceeds L, ascending (kink marks).
    public let kinks: [Int]
    /// The seam that tore the aurora, if the play failed by a tear.
    public let tear: Int?
    /// The chosen section's start (presentation state of the controls, clamped to the wave).
    public let sectionStart: Int
    /// The chosen section's end (presentation state of the controls, clamped to the wave, after the start).
    public let sectionEnd: Int
    /// The play's stage.
    public let stage: BackwardsAuroraStage
    /// Why the play failed, if it did.
    public let failure: BackwardsAuroraFailure?
    /// The reversals spent.
    public let spent: Int
    /// The reversal budget.
    public let budget: Int
    /// The catalog level number, 1 … 100.
    public let levelNumber: Int
    /// The presentation time in seconds (pulses and shimmer only).
    public let time: Double
    /// The freeze preview's would-be samples (feature 394, R02-G10-04): the kernel's reversal of the chosen section,
    /// drawn as a pale dashed ribbon; empty when no preview shows. Presentation only.
    public private(set) var preview: [Int] = []

    /// The snapshot of `play` at `time` for catalog level `levelNumber` with the chosen section [sectionStart,
    /// sectionEnd] (clamped so that 0 ≤ start < end ≤ N − 1).
    public init(play: BackwardsAuroraPlay, levelNumber: Int, sectionStart: Int, sectionEnd: Int, time: Double) {
        let level: BackwardsAuroraLevel = play.level
        let wave: BackwardsAuroraWave = play.wave
        let count: Int = wave.count
        samples = wave.samples
        target = level.target.samples
        checkpoints = level.checkpoints
        matched = level.matched(wave)
        bendLimit = level.bendLimit
        var sharp: [Int] = []
        for k in wave.interior where abs(wave.bend(at: k)) > level.bendLimit { sharp.append(k) }
        kinks = sharp
        if case let .tear(_, seam) = play.failure { tear = seam } else { tear = nil }
        let start: Int = min(max(sectionStart, 0), count - 2)
        self.sectionStart = start
        self.sectionEnd = min(max(sectionEnd, start + 1), count - 1)
        stage = play.stage
        failure = play.failure
        spent = play.spent
        budget = level.budget
        self.levelNumber = levelNumber
        self.time = time.isFinite ? time : 0
    }

    /// The number of samples, N.
    public var count: Int { samples.count }

    /// This snapshot with `samples` as the freeze preview (empty: none); samples of another length are ignored.
    public func withPreview(_ samples: [Int]) -> BackwardsAuroraSceneSnapshot {
        var copy = self
        copy.preview = samples.count == count ? samples : []
        return copy
    }

    /// The failure in words, naming the reversal and the seam as the kernel's reason does: "The aurora tore at seam 5
    /// on reversal 2." or "All 6 reversals were spent without a win."; nil when the play has not failed.
    public static func failureText(_ failure: BackwardsAuroraFailure?, budget: Int) -> String? {
        switch failure {
        case let .tear(move, seam)?:
            return "The aurora tore at seam \(seam) on reversal \(move + 1)."
        case .budget?:
            return budget == 1 ? "The only reversal was spent without a win."
                : "All \(budget) reversals were spent without a win."
        case nil:
            return nil
        }
    }
}
