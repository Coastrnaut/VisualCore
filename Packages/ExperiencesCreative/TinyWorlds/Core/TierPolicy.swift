// TierPolicy — feature 093 (A12-P05) T-A12-502 (FR-A12-502; SC-A12-502; clarification 3; research D2). Chooses the
// detail tier a frame is drawn at from three pressures:
//   - the host's quality level (the session's governor, which already steps down on serious or critical heat, decides
//     at most once per second and steps up only after its hold), clamped to 0…2;
//   - Low Power Mode: the lightest tier (2) while it is on;
//   - memory warnings: the lightest tier from the warning until 30 s of frame time after the last one (a repeated
//     warning restarts the hold; nothing goes below the lightest tier).
// tier = max(host level, Low Power floor, memory floor). The clock is the presenter's frame clock (the sum of frame
// times in seconds), so tests are deterministic; non-finite times are ignored. Presentation only: the tier never enters
// the world document, the state or the digest, and is never saved.
import Foundation

/// The rules that choose a frame's detail tier.
public struct TierPolicy: Equatable, Sendable {
    /// How long a memory warning holds the lightest tier, in seconds of frame time.
    public static let memoryHold: Double = 30

    /// The frame time of the last memory warning; nil when none was received.
    public private(set) var lastWarning: Double?

    /// A policy with no memory warning received.
    public init() {}

    /// Records a memory warning at frame time `now` (ignored when not finite).
    public mutating func recordMemoryWarning(at now: Double) {
        guard now.isFinite else { return }
        lastWarning = now
    }

    /// True while a memory warning holds the lightest tier at frame time `now`.
    public func memoryHeld(at now: Double) -> Bool {
        guard let lastWarning, now.isFinite else { return lastWarning != nil }
        return now - lastWarning < Self.memoryHold
    }

    /// The tier to draw at frame time `now` for the host's level `host` with Low Power Mode `lowPower`.
    public func tier(host: Int, lowPower: Bool, now: Double) -> Int {
        let hostTier = min(max(host, DetailTier.tiers.lowerBound), DetailTier.tiers.upperBound)
        let lowPowerFloor = lowPower ? DetailTier.lightest : DetailTier.tiers.lowerBound
        let memoryFloor = memoryHeld(at: now) ? DetailTier.lightest : DetailTier.tiers.lowerBound
        return max(hostTier, lowPowerFloor, memoryFloor)
    }
}
