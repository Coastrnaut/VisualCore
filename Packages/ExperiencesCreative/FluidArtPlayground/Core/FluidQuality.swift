// FluidQuality.swift — what each automatic quality tier means for the fluid (feature 021 T-A02-308; FR-A02-308;
// spec 021 clarification 4). VisualCore's QualityPolicy picks the tier; this maps it to solver work, lowering pressure
// iterations before the splat cap so touches stay responsive (manual §12).

/// The playground's quality tiers: Full, Reduced, Minimal.
public enum FluidQuality {
    /// Tier names, best first.
    public static let names = ["Full", "Reduced", "Minimal"]
    /// Number of tiers.
    public static var tierCount: Int { names.count }

    /// Pressure iterations and splat cap for `tier` (clamped to 0…2), from the user's configured values:
    /// Full = both as configured; Reduced = half the iterations (≥ 1); Minimal = a quarter of the iterations (≥ 1) and
    /// half the splat cap (≥ 1).
    public static func parameters(tier: Int, configuration c: FluidConfiguration) -> (iterations: Int, splatCap: Int) {
        switch min(max(tier, 0), tierCount - 1) {
        case 0: (c.pressureIterations, c.maxSplatsPerFrame)
        case 1: (max(1, c.pressureIterations / 2), c.maxSplatsPerFrame)
        default: (max(1, c.pressureIterations / 4), max(1, c.maxSplatsPerFrame / 2))
        }
    }

    /// The display name of `tier` (clamped).
    public static func name(_ tier: Int) -> String { names[min(max(tier, 0), tierCount - 1)] }
}
