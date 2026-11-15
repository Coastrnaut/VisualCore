// Steering.swift — weighted flocking steering and nearest-neighbour search for schools of agents (feature 069 (A09-P02)
// T-A09-202 (FR-A09-201–203); contract specs/069-da-p02-schools/contracts/api.md; research D1, D2). Every term is
// weighted then capped to `maxForce`, the sum is capped again, and non-finite inputs give zero force, so the result is
// always finite and bounded. Everything is deterministic: no randomness, ties broken by index.
import Foundation
import VisualCoreMath

/// One steered agent: a position, a velocity and the group (species) it schools with.
public struct SteeringAgent: Sendable, Equatable {
    /// Position in world units.
    public var position: Vec2
    /// Velocity in world units per second.
    public var velocity: Vec2
    /// Group identifier; alignment and cohesion act only between agents of the same group.
    public var group: Int
    /// Creates an agent from its position, velocity and group.
    public init(position: Vec2, velocity: Vec2, group: Int) {
        self.position = position
        self.velocity = velocity
        self.group = group
    }

    /// True when position and velocity are both finite.
    var isFinite: Bool { position.isFinite && velocity.isFinite }
}

/// An axis-aligned rectangle that agents are steered to stay inside.
public struct SteeringBounds: Sendable, Equatable {
    /// Smallest and largest x, smallest and largest y (world units).
    public var minX: Double, maxX: Double, minY: Double, maxY: Double
    /// Creates bounds from the extremes of each axis.
    public init(minX: Double, maxX: Double, minY: Double, maxY: Double) {
        self.minX = minX
        self.maxX = maxX
        self.minY = minY
        self.maxY = maxY
    }

    /// True when every extreme is finite and each minimum is strictly below its maximum; invalid bounds add no force.
    public var isValid: Bool {
        minX.isFinite && maxX.isFinite && minY.isFinite && maxY.isFinite && minX < maxX && minY < maxY
    }
}

/// Tuning of the steering terms. Negative or non-finite values act as 0; a `neighbourLimit` of 0 or less means none.
public struct SteeringParameters: Sendable, Equatable {
    /// Largest distance at which another agent counts as a neighbour (world units).
    public var neighbourRadius: Double
    /// Largest number of neighbours considered per agent.
    public var neighbourLimit: Int
    /// Distance below which a neighbour pushes the agent away (world units).
    public var separationRadius: Double
    /// Weight of the separation term.
    public var separationWeight: Double
    /// Weight of the alignment term (match the same group's mean velocity).
    public var alignmentWeight: Double
    /// Weight of the cohesion term (move toward the same group's mean position).
    public var cohesionWeight: Double
    /// Weight of the boundary-avoidance term.
    public var boundaryWeight: Double
    /// Distance from a bound at which the inward push starts (world units); 0 disables the boundary term.
    public var boundaryMargin: Double
    /// Cap on every weighted term and on their sum (world units per second squared).
    public var maxForce: Double

    /// Creates parameters; every argument has the default schooling tuning.
    public init(neighbourRadius: Double = 2.5, neighbourLimit: Int = 6, separationRadius: Double = 1,
                separationWeight: Double = 2, alignmentWeight: Double = 1, cohesionWeight: Double = 0.8,
                boundaryWeight: Double = 3, boundaryMargin: Double = 1, maxForce: Double = 2) {
        self.neighbourRadius = neighbourRadius
        self.neighbourLimit = neighbourLimit
        self.separationRadius = separationRadius
        self.separationWeight = separationWeight
        self.alignmentWeight = alignmentWeight
        self.cohesionWeight = cohesionWeight
        self.boundaryWeight = boundaryWeight
        self.boundaryMargin = boundaryMargin
        self.maxForce = maxForce
    }
}

/// Nearest-neighbour search over a small set of agents (linear scan; research D2).
public enum NeighbourSearch {
    /// The indices of at most `max(0, limit)` agents within `radius` of agent `index`, nearest first, ties by index.
    ///
    /// Agent `index` itself and agents with a non-finite position are never returned. Returns `[]` for an out-of-range
    /// `index`, a negative or non-finite `radius`, or a non-finite position of agent `index`.
    public static func neighbours(of index: Int, in agents: [SteeringAgent], radius: Double, limit: Int) -> [Int] {
        guard agents.indices.contains(index), radius.isFinite, radius >= 0, limit > 0 else { return [] }
        let own = agents[index].position
        guard own.isFinite else { return [] }
        var found: [(distance: Double, index: Int)] = []
        for (j, other) in agents.enumerated() where j != index && other.position.isFinite {
            let d = own.distance(to: other.position)
            if d <= radius { found.append((d, j)) }
        }
        found.sort { $0.distance != $1.distance ? $0.distance < $1.distance : $0.index < $1.index }
        return found.prefix(limit).map(\.index)
    }
}

/// Weighted steering forces: separation, alignment, cohesion and boundary avoidance (research D1).
public enum Steering {
    /// The steering force on agent `index` from the given neighbours and bounds.
    ///
    /// Neighbour indices that are out of range, equal to `index`, or name a non-finite agent are ignored. Separation
    /// uses every neighbour closer than `separationRadius` (coincident agents push along +x for the lower index and −x
    /// for the higher); alignment and cohesion use only neighbours of the same group; the boundary term pushes inward
    /// per axis, rising linearly from 0 at `boundaryMargin` to 1 at the bound, and is absent for invalid bounds. Each
    /// term is weighted and capped to `maxForce`, and the sum is capped again. An out-of-range `index` or a non-finite
    /// own agent gives `.zero`. The result is always finite with length ≤ `maxForce`.
    public static func force(for index: Int, agents: [SteeringAgent], neighbours: [Int],
                             parameters: SteeringParameters, bounds: SteeringBounds) -> Vec2 {
        guard agents.indices.contains(index) else { return .zero }
        let me = agents[index]
        guard me.isFinite else { return .zero }
        func safe(_ v: Double) -> Double { v.isFinite && v > 0 ? v : 0 }
        let maxForce = safe(parameters.maxForce)
        guard maxForce > 0 else { return .zero }
        let separationRadius = safe(parameters.separationRadius)

        var separation = Vec2.zero
        var velocitySum = Vec2.zero, positionSum = Vec2.zero, sameGroup = 0
        for j in neighbours where j != index && agents.indices.contains(j) {
            let other = agents[j]
            guard other.isFinite else { continue }
            let offset = me.position - other.position
            let d = offset.length
            if separationRadius > 0, d < separationRadius {
                let away = d > 0 ? offset / d : Vec2(index < j ? 1 : -1, 0)
                separation += away * (1 - d / separationRadius)
            }
            if other.group == me.group {
                velocitySum += other.velocity
                positionSum += other.position
                sameGroup += 1
            }
        }

        var total = capped(separation * safe(parameters.separationWeight), to: maxForce)
        if sameGroup > 0 {
            let n = Double(sameGroup)
            total += capped((velocitySum / n - me.velocity) * safe(parameters.alignmentWeight), to: maxForce)
            total += capped((positionSum / n - me.position) * safe(parameters.cohesionWeight), to: maxForce)
        }
        let margin = safe(parameters.boundaryMargin)
        if bounds.isValid, margin > 0 {
            func push(_ distance: Double) -> Double { distance >= margin ? 0 : min(1, 1 - distance / margin) }
            let p = me.position
            let inward = Vec2(push(p.x - bounds.minX) - push(bounds.maxX - p.x),
                              push(p.y - bounds.minY) - push(bounds.maxY - p.y))
            total += capped(inward * safe(parameters.boundaryWeight), to: maxForce)
        }
        return capped(total, to: maxForce)
    }

    /// `v` unchanged when its length is at most `limit`, otherwise `v` scaled to length `limit`; `.zero` when `v` is
    /// non-finite or `limit` is non-finite or not positive.
    public static func capped(_ v: Vec2, to limit: Double) -> Vec2 {
        guard v.isFinite, limit.isFinite, limit > 0 else { return .zero }
        let length = v.length
        guard length.isFinite else { return .zero }
        return length <= limit ? v : v / length * limit
    }
}
