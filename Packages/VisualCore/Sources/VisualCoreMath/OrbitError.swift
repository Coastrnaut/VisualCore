// OrbitError — feature 215 (R02-F15) T-R02F15-002 (FR-R02F15-008; clarification Q5). The refusals of the conic-orbit
// and eclipse-geometry types, each with a stable reason code `r2-f15.*` that consumers log with their experience id,
// seed and tick.

/// A refusal of a conic-orbit, phase-stepping, disk-overlap or eclipse request.
public enum OrbitError: Error, Equatable, Sendable {
    /// The orbital elements are not finite, or q ≤ 0, e < 0 or μ ≤ 0; the payload names the offending element.
    case invalidElements(String)
    /// A step or span is not finite, not positive, or reversed.
    case invalidStep
    /// A tick lies outside 0 … ``PhaseStepper/maxTick``; the payload is the tick asked for.
    case tickLimit(Int)
    /// A disk or body radius is not finite and positive, or a distance is negative or not finite.
    case invalidDisk
    /// The observer lies inside the source, the occluder or the ground sphere.
    case observerInside
    /// A passage listing would exceed ``PhaseStepper/maxPassages``; the payload is the count it would need.
    case spanLimit(Int)
    /// A stored orbit has a schema newer than ``ConicOrbit/schema``; the payload is that schema.
    case newerSchema(Int)
    /// A stored orbit is damaged or incomplete; the payload describes the damage.
    case malformed(String)

    /// The stable reason code, `r2-f15.<kebab-case>`.
    public var reasonCode: String {
        switch self {
        case .invalidElements: "r2-f15.invalid-elements"
        case .invalidStep: "r2-f15.invalid-step"
        case .tickLimit: "r2-f15.tick-limit"
        case .invalidDisk: "r2-f15.invalid-disk"
        case .observerInside: "r2-f15.observer-inside"
        case .spanLimit: "r2-f15.span-limit"
        case .newerSchema: "r2-f15.newer-schema"
        case .malformed: "r2-f15.malformed"
        }
    }
}
