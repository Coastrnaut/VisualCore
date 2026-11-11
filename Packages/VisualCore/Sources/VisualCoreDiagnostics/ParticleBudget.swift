// ParticleBudget.swift — particle-count shares per quality tier (feature 034 A04-P02 T-A04-204; gap G-PQUALITY;
// FR-A04-203; spec clarification 2; research R3). `QualityPolicy` chooses the tier; the budget turns it into a count cap
// for any instanced workload (particles, sprites, instances).

/// Maps a quality tier to a share of a requested count, with a floor.
///
/// `limit(requested:tier:) = min(requested, max(minimum, ⌊requested × share(tier)⌋))`, so the result never exceeds the
/// request and never falls below `minimum` unless less was requested.
public struct ParticleBudget: Sendable, Equatable {
    /// Shares for tiers 0, 1, 2, … (each 0…1); tiers past the end use the last share.
    public let shares: [Double]
    /// The smallest limit a tier may give (≥ 0), unless the request is smaller.
    public let minimum: Int

    /// The default budget: shares 1, 0.6, 0.35, 0.2 for four tiers, minimum 100.
    public static let standard = ParticleBudget(shares: [1, 0.6, 0.35, 0.2], minimum: 100)

    /// Shares are clamped to 0…1 (non-finite become 1) and an empty list becomes `[1]`; a negative minimum becomes 0.
    public init(shares: [Double], minimum: Int) {
        let s = shares.map { $0.isFinite ? min(max($0, 0), 1) : 1 }
        self.shares = s.isEmpty ? [1] : s
        self.minimum = max(0, minimum)
    }

    /// The share for `tier`, clamped to the available tiers.
    public func share(tier: Int) -> Double { shares[min(max(tier, 0), shares.count - 1)] }

    /// The effective count for a `requested` count at `tier` (0 when nothing positive was requested).
    public func limit(requested: Int, tier: Int) -> Int {
        guard requested > 0 else { return 0 }
        let scaled = Int((Double(requested) * share(tier: tier)).rounded(.down))
        return min(requested, max(minimum, scaled))
    }
}
