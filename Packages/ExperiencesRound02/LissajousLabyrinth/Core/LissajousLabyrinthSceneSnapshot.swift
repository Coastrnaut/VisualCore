// LissajousLabyrinthSceneSnapshot — feature 313 (R02-G02-03) T-R02G0203-002 (FR-R02G0203-002, 003, 004; clarifications
// Q1–Q4). What the renderer may read: an immutable copy of the kernel's state (the level, the four dials, the stage, the
// lap's verdict and the checkpoints' visit ticks) with the frame time, plus the palette and the three quality tiers. The
// renderer never holds the kernel, so no drawing result can change the game (renderer purity, R2-G02-INV-10).

/// The palette of Lissajous Labyrinth, sRGB components 0 … 1 (clarification Q3).
public enum LissajousLabyrinthPalette {
    /// Night background, #070B1E.
    public static let night = rgb(0x07, 0x0B, 0x1E)
    /// Cobalt, #2F5BD8 (the path's start colour).
    public static let cobalt = rgb(0x2F, 0x5B, 0xD8)
    /// Violet, #8A4FE0 (the path's end colour and the obstacles).
    public static let violet = rgb(0x8A, 0x4F, 0xE0)
    /// Copper, #D9824A (checkpoints and the tracer head).
    public static let copper = rgb(0xD9, 0x82, 0x4A)
    /// The four colours as hex strings, for the catalog: night, cobalt, violet, copper.
    public static let hex: [String] = ["#070B1E", "#2F5BD8", "#8A4FE0", "#D9824A"]

    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// One quality tier: it changes only sample density, glow and trail length, never coordinates, objective or indicators.
/// Tiers are ordered richest first, as the shared quality contract requires: index n is the catalog's `level-n` (the
/// design's "Tier 0 D3-safe" is level-2).
public struct LissajousLabyrinthTier: Sendable, Equatable, Hashable {
    /// The tier index, 0 … 2 (0: richest).
    public let index: Int
    /// The drawn sample stride: every `stride`-th of the lap's 4,096 samples.
    public let stride: Int
    /// Glow passes (0: none).
    public let glowPasses: Int
    /// The bright trail behind the tracer head, in ticks.
    public let trail: Int

    /// The three tiers, richest first: strides 1/2/4, glow passes 2/1/0, trails 512/256/128.
    public static let all: [LissajousLabyrinthTier] = [
        LissajousLabyrinthTier(index: 0, stride: 1, glowPasses: 2, trail: 512),
        LissajousLabyrinthTier(index: 1, stride: 2, glowPasses: 1, trail: 256),
        LissajousLabyrinthTier(index: 2, stride: 4, glowPasses: 0, trail: 128),
    ]

    /// The catalog name, `level-<index>`.
    public var name: String { "level-\(index)" }

    /// The drawn samples per lap (4,096 / stride).
    public var samples: Int { LissajousLabyrinthLap.ticks / stride }

    /// The tier for `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> LissajousLabyrinthTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// An immutable copy of a play for drawing.
public struct LissajousLabyrinthSceneSnapshot: Sendable, Equatable {
    /// The tracer head's speed in ticks per presentation second (a lap in about 68 s; clarification Q1).
    public static let headTicksPerSecond = 60.0

    /// The level being played.
    public let level: LissajousLabyrinthLevel
    /// The four dials.
    public let dials: LissajousLabyrinthDials
    /// The play's stage.
    public let stage: LissajousLabyrinthStage
    /// The lap's verdict for the dials (won, the first contact, or the first missed checkpoint).
    public let verdict: LissajousLabyrinthVerdict
    /// The tick at which each checkpoint is first visited in order (fewer entries than checkpoints when one is missed).
    public let visits: [Int]
    /// The presentation time in seconds (not a kernel quantity; 0 under Reduce Motion).
    public let time: Double

    /// A snapshot of `play` at presentation time `time` (a non-finite time counts as 0).
    public init(play: LissajousLabyrinthPlay, time: Double) {
        level = play.level
        dials = play.dials
        stage = play.stage
        verdict = LissajousLabyrinthLap.verdict(play.dials, level: play.level)
        visits = LissajousLabyrinthTerminal(play.dials, level: play.level).visits
        self.time = time.isFinite ? time : 0
    }

    /// The tracer head's tick: presentation time × 60, modulo the lap (0 for a negative time).
    public var headTick: Int {
        guard time > 0 else { return 0 }
        let ticks = (time * Self.headTicksPerSecond).rounded(.down)
        let lap = Double(LissajousLabyrinthLap.ticks)
        return Int(ticks.truncatingRemainder(dividingBy: lap))
    }

    /// Whether checkpoint `index` is visited in order by the lap.
    public func visited(_ index: Int) -> Bool { index < visits.count }

    /// The index of the first checkpoint not visited in order (nil when all are).
    public var nextCheckpoint: Int? { visits.count < level.checkpoints.count ? visits.count : nil }

    /// The obstacle the lap first touches, if any.
    public var contactObstacle: Int? {
        if case .contact(let obstacle, _) = verdict { return obstacle }
        return nil
    }
}
