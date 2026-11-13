// GrowthRule — feature 192 T-U06-010 (UA-F06; FR-U06-051). The rule that decides from a series of resource samples
// whether an experience keeps growing while it runs: graphics bytes may not rise after the warm-up tenth, and the
// memory footprint may not rise by more than max(8 MiB, 5 %) between the first and the last quarter after the
// warm-up (data-model section 4; contract specs/192-ua-f06-quality-performance/contracts/performance-api.md).
// Pure integer logic: the same samples always give the same verdict.

/// One measurement of the resources an experience holds at a moment of its run.
public struct ResourceSample: Sendable, Equatable {
    /// The memory footprint of the process in bytes, or `nil` when the platform could not report it.
    public var footprintBytes: Int?
    /// The graphics memory the resource ledger accounts for, in bytes.
    public var gpuBytes: Int

    /// Creates a sample from a footprint (or `nil`) and the graphics bytes.
    public init(footprintBytes: Int?, gpuBytes: Int) {
        self.footprintBytes = footprintBytes
        self.gpuBytes = gpuBytes
    }
}

/// The result of `GrowthRule.judge(_:)` and `GrowthRule.judge(_:warmUp:)`.
public enum GrowthVerdict: Sendable, Equatable {
    /// Nothing grew. `footprintChecked` is false when at least one sample had no footprint, so that only the
    /// graphics bytes were judged.
    case flat(footprintChecked: Bool)
    /// The named quantity (`GrowthRule.gpuQuantity` or `GrowthRule.footprintQuantity`) grew by `by` bytes.
    case grew(quantity: String, by: Int)
    /// There were fewer than `GrowthRule.minimumSamples` samples; the value is the count received.
    case tooFewSamples(Int)

    /// True only for `.flat`.
    public var passes: Bool {
        if case .flat = self { return true }
        return false
    }
}

/// Decides whether a series of resource samples shows growth (FR-U06-051).
public enum GrowthRule {
    /// The smallest number of samples that can be judged: 60.
    public static let minimumSamples = 60
    /// The absolute footprint margin: 8 MiB.
    public static let footprintMarginBytes = 8 * 1024 * 1024
    /// The relative footprint margin: 5 % of the first median.
    public static let footprintMarginShare = 0.05
    /// The quantity name reported when the graphics bytes grew.
    public static let gpuQuantity = "gpu_bytes"
    /// The quantity name reported when the memory footprint grew.
    public static let footprintQuantity = "memory_footprint_bytes"

    /// Judges the samples in the order they were taken.
    ///
    /// 1. Fewer than `minimumSamples` samples give `.tooFewSamples`.
    /// 2. The warm-up is the first tenth of the samples (rounded down, at least one).
    /// 3. The largest graphics bytes after the warm-up may not exceed the largest of the warm-up; otherwise
    ///    `.grew(quantity: gpuQuantity, by:)` with the difference.
    /// 4. Only when every sample has a footprint: the median of the last quarter after the warm-up minus the
    ///    median of the first quarter after the warm-up may not exceed
    ///    `max(footprintMarginBytes, footprintMarginShare × first median)`; otherwise
    ///    `.grew(quantity: footprintQuantity, by:)` with the difference. The median of an even count is the lower
    ///    of the two middle values.
    /// 5. Otherwise `.flat`.
    public static func judge(_ samples: [ResourceSample]) -> GrowthVerdict {
        judge(samples, warmUp: nil)
    }

    /// Judges the samples as `judge(_:)` does, with the first `warmUp` samples as the warm-up instead of the first
    /// tenth (feature 193, UA-F07): a series made of repeated cycles, each of which fills its content from empty,
    /// takes its first whole cycle as the warm-up, so that growth means more than the first cycle reached. `nil`
    /// gives the tenth; a value is clamped to 1 … count − 1.
    public static func judge(_ samples: [ResourceSample], warmUp: Int?) -> GrowthVerdict {
        guard samples.count >= minimumSamples else { return .tooFewSamples(samples.count) }
        let warmCount = min(max(1, warmUp ?? samples.count / 10), samples.count - 1)
        let warm = samples[..<warmCount]
        let rest = samples[warmCount...]

        let maxWarm = warm.reduce(Int.min) { max($0, $1.gpuBytes) }
        let maxRest = rest.reduce(Int.min) { max($0, $1.gpuBytes) }
        if maxRest > maxWarm {
            return .grew(quantity: gpuQuantity, by: maxRest - maxWarm)
        }

        let restFootprints = rest.compactMap(\.footprintBytes)
        let footprintChecked = restFootprints.count == rest.count
            && warm.allSatisfy { $0.footprintBytes != nil }
        if footprintChecked {
            let quarter = max(1, restFootprints.count / 4)
            let first = median(restFootprints.prefix(quarter))
            let last = median(restFootprints.suffix(quarter))
            let margin = max(footprintMarginBytes, Int(Double(first) * footprintMarginShare))
            if last - first > margin {
                return .grew(quantity: footprintQuantity, by: last - first)
            }
        }
        return .flat(footprintChecked: footprintChecked)
    }

    /// The median of the values; for an even count the lower of the two middle values; 0 for no values.
    private static func median(_ values: ArraySlice<Int>) -> Int {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return sorted[(sorted.count - 1) / 2]
    }
}
