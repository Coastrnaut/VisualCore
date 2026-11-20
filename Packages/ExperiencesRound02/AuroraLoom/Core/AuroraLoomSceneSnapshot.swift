// AuroraLoomSceneSnapshot — feature 303 (R02-G01-03) T-R02G0103-002 (FR-R02G0103-002, 003, 004; clarifications Q1–Q4).
// What the renderer may read: an immutable copy of the kernel's state (the level, the six steps, the stage and the
// failure) with the frame time, plus the palette and the three quality tiers. The renderer never holds the kernel, so no
// drawing result can change the game (renderer purity, R2-G01-INV-10).

/// The palette of Aurora Loom, linear-free sRGB components 0 … 1.
public enum AuroraLoomPalette {
    /// Night background, #07121A.
    public static let night = rgb(0x07, 0x12, 0x1A)
    /// Polar teal, #1FD1B4.
    public static let teal = rgb(0x1F, 0xD1, 0xB4)
    /// Magenta, #E0389C.
    public static let magenta = rgb(0xE0, 0x38, 0x9C)
    /// Acid gold, #D8E83A.
    public static let gold = rgb(0xD8, 0xE8, 0x3A)
    /// The ribbon colours by ribbon index: teal, magenta, gold.
    public static let ribbons: [SIMD3<Double>] = [teal, magenta, gold]
    /// The four colours as hex strings, for the catalog: night, teal, magenta, gold.
    public static let hex: [String] = ["#07121A", "#1FD1B4", "#E0389C", "#D8E83A"]

    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SIMD3<Double> {
        SIMD3(Double(r) / 255, Double(g) / 255, Double(b) / 255)
    }
}

/// One quality tier: it changes only density, layers and glow, never coordinates, objective or indicators. Tiers are
/// ordered as the shared quality contract requires, richest first: index n is the catalog's `level-n` (the design's
/// "Tier 2 dense spectacle" is level-0, its "Tier 0 D3-safe minimal layers" is level-2).
public struct AuroraLoomTier: Sendable, Equatable, Hashable {
    /// The tier index, 0 … 2 (0: richest).
    public let index: Int
    /// Drawn sheets per ribbon.
    public let layers: Int
    /// Segments along the loom per ribbon.
    public let segments: Int
    /// Glow passes (0: none).
    public let glowPasses: Int

    /// The three tiers, richest first: 5/3/1 layers, 128/64/32 segments, 2/1/0 glow passes.
    public static let all: [AuroraLoomTier] = [
        AuroraLoomTier(index: 0, layers: 5, segments: 128, glowPasses: 2),
        AuroraLoomTier(index: 1, layers: 3, segments: 64, glowPasses: 1),
        AuroraLoomTier(index: 2, layers: 1, segments: 32, glowPasses: 0),
    ]

    /// The catalog name, `level-<index>`.
    public var name: String { "level-\(index)" }

    /// The tier for `index`, clamped to 0 … 2.
    public static func of(_ index: Int) -> AuroraLoomTier {
        all[min(max(index, 0), all.count - 1)]
    }
}

/// An immutable copy of a play for drawing.
public struct AuroraLoomSceneSnapshot: Sendable, Equatable {
    /// The level being played.
    public let level: AuroraLoomLevel
    /// The six steps.
    public let steps: AuroraLoomSteps
    /// The life stage.
    public let stage: AuroraLoomStage
    /// The furthest-off gate when failed.
    public let failure: AuroraLoomMismatch?
    /// The frame time in ticks of 1/120 s (≥ 0); only the picture moves with it.
    public let time: Double

    /// A snapshot of `play` at `time` ticks (negative or non-finite times become 0).
    public init(play: AuroraLoomPlay, time: Double) {
        level = play.level
        steps = play.steps
        stage = play.stage
        failure = play.failure
        self.time = time.isFinite ? max(time, 0) : 0
    }

    /// The whole tick the picture shows: ⌊time⌋ modulo two periods.
    public var tick: Int {
        let span = 2 * level.period
        let whole = Int(min(time, Double(Int.max / 2)).rounded(.down))
        return whole % span
    }

    /// Whether `ribbon` meets `gate`'s target within the tolerance at the shown tick (drives the lit rings).
    public func lit(ribbon: Int, gate: Int) -> Bool {
        abs(AuroraLoomHarmony.residual(ribbon: ribbon, gate: gate, tick: tick, steps: steps, level: level))
            <= level.tolerance
    }
}
