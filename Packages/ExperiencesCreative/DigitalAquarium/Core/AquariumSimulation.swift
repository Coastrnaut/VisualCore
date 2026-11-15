// AquariumSimulation — feature 068 (A09-P01) T-A09-102 (FR-A09-110, FR-A09-111; clarification 1; research D1),
// schooling since feature 069 (A09-P02) T-A09-204 (FR-A09-210; clarification 3; research D3). The seeded, fixed-step
// schooling of the fish. Each step (1/60 s) first computes every fish's steering force from the state at the start of
// the step (VisualCore `Steering`: separation from every neighbour, alignment and cohesion only with the same species,
// inward push near the bounds; ``parameters(for:)``), so the result does not depend on the fish order. Then every fish
// of a known species, in document order:
// 1. adds force × step to its velocity;
// 2. turns by a reduced seeded wander of ±(species turn rate × 0.35 × step) (exactly one draw per fish);
// 3. has its speed clamped to 0.5 × cruise…maximum (a zero velocity takes the current heading);
// 4. moves by velocity × step;
// 5. is clamped into the swim bounds, and each outward velocity component at a clamped edge is reflected (Phase 01).
// The heading then follows the velocity, `turn` eases (0.2 per step) toward the heading change per second, and the
// animation phase advances in proportion to speed / body length. A fish of an unknown species is only clamped (it is
// still an agent the others keep away from, in a group of its own). The clamp makes leaving the bounds impossible by
// construction; reflection never changes the speed, so no fish exceeds its maximum or drops below half its cruise.
// There is no wall-clock input: the same document, catalog and generator state give the same result. Reduce Motion
// never reaches this type (the experience halves only what it draws), and while paused the caller does not advance.
// Tuning (research D3): neighbour radius 2.5, limit 6, separation radius 1.6 × body length, weights separation 2.0,
// alignment 1.0, cohesion 0.8, boundary 3.0 with margin 1.0, maximum force 2.0 — unchanged from D3; measured over seeds
// 1…20 after 1,800 steps: Reef 20 of 20 seeds closer (SC-A09-201) and 19 aligned (SC-A09-202), Kelp 19 and 18.
// Feeding since feature 070 (A09-P03) T-A09-303 (FR-A09-302, FR-A09-303; clarification 3; research D2): each fish's
// steering force also gets ``Feeding/seekForce(for:food:)`` toward its nearest pellet within 4 units (from the state at
// the start of the step), and the sum is capped again to the species' maximum force; after every fish has moved,
// ``Feeding/step(_:catalog:dt:)`` sinks, eats and removes pellets. Without food the seek force is zero and nothing is
// re-capped, so a document without food advances bit for bit as before.
// Ambient since feature 072 (A09-P05) T-A09-502 (FR-A09-510; clarification 2; research D2): with `ambient` true every
// fish cruises at ``ambientSpeedFactor`` × its species' cruise speed, so the speed floor is 0.5 × that scaled cruise
// and the maximum speed is unchanged; every other bound holds. With `ambient` false (the default) the effective cruise
// is the species' cruise itself and every result is bit-identical to Phase 04.
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// The fixed-step schooling of the fish in a habitat document.
public enum AquariumSimulation {
    /// The fixed step in seconds.
    public static let step = 1.0 / 60
    /// The distance from a bound inside which a fish is pushed inward, in habitat units.
    public static let margin = 1.0
    /// The share of the species turn rate used by the seeded wander turn while schooling.
    public static let wanderShare = 0.35
    /// The lowest speed as a share of the species cruise speed.
    public static let minimumSpeedShare = 0.5
    /// How much of the gap to the new heading change per second `turn` closes each step.
    public static let turnSmoothing = 0.2
    /// Tail swings per unit of (speed / body length).
    public static let tailBeatsPerLength = 0.6
    /// The share of the species cruise speed fish cruise at in ambient mode (the speed floor scales with it).
    public static let ambientSpeedFactor = 0.6

    /// The steering tuning of `species`: neighbour radius 2.5 units, at most 6 neighbours, separation radius
    /// 1.6 × body length, weights separation 2.0, alignment 1.0, cohesion 0.8 and boundary 3.0, boundary margin
    /// ``margin``, maximum force 2.0 units/s².
    public static func parameters(for species: FishSpecies) -> SteeringParameters {
        SteeringParameters(neighbourRadius: 2.5, neighbourLimit: 6, separationRadius: 1.6 * species.length,
                           separationWeight: 2.0, alignmentWeight: 1.0, cohesionWeight: 0.8, boundaryWeight: 3.0,
                           boundaryMargin: margin, maxForce: 2.0)
    }

    /// The steering agents of `doc`: each fish's position and velocity, grouped by the index of its species in
    /// `catalog` (−1 − fish index for an unknown species, so it never schools).
    static func agents(_ doc: HabitatDocument, catalog: SpeciesCatalog) -> [SteeringAgent] {
        doc.fish.enumerated().map { index, fish in
            let group = catalog.species.firstIndex { $0.id == fish.speciesId } ?? (-1 - index)
            return SteeringAgent(position: fish.position, velocity: fish.velocity, group: group)
        }
    }

    /// The steering force on every fish of `doc`, all from the same (current) state; `.zero` for a fish of an unknown
    /// species. A non-zero ``Feeding/seekForce(for:food:)`` is added and the sum capped to the species' maximum force.
    /// The force on a fish depends only on the set of fish and pellets, not on the fish order (ties in the neighbour
    /// search aside).
    static func forces(_ doc: HabitatDocument, catalog: SpeciesCatalog) -> [Vec2] {
        let agents = agents(doc, catalog: catalog)
        let bounds = SteeringBounds(minX: doc.bounds.minX, maxX: doc.bounds.maxX,
                                    minY: doc.bounds.minY, maxY: doc.bounds.maxY)
        return doc.fish.indices.map { index in
            guard let species = catalog.species(id: doc.fish[index].speciesId) else { return .zero }
            let parameters = parameters(for: species)
            let neighbours = NeighbourSearch.neighbours(of: index, in: agents, radius: parameters.neighbourRadius,
                                                        limit: parameters.neighbourLimit)
            let force = Steering.force(for: index, agents: agents, neighbours: neighbours, parameters: parameters,
                                       bounds: bounds)
            let seek = Feeding.seekForce(for: doc.fish[index], food: doc.food)
            guard seek != .zero else { return force }
            return Steering.capped(force + seek, to: parameters.maxForce)
        }
    }

    /// Advances every fish of `doc` by one ``step`` using the species of `catalog` and the generator `random` (one
    /// draw per fish whose species is known, in document order). Every steering force is computed from the state at
    /// the start of the step, the seek toward food included. A fish whose species is not in the catalog is only
    /// clamped into the bounds. After every fish has moved, ``Feeding/step(_:catalog:dt:)`` sinks, eats and removes
    /// the pellets; plants, decor and lighting are not changed. With `ambient` true the cruise speed used for the
    /// speed floor and the fallback velocity is the species' cruise × ``ambientSpeedFactor``; with `ambient` false
    /// (the default) the result is bit-identical to the advance without the parameter.
    public static func advance(_ doc: inout HabitatDocument, catalog: SpeciesCatalog, random: inout SeededRandom,
                               ambient: Bool = false) {
        let bounds = doc.bounds
        let dt = step
        let forces = forces(doc, catalog: catalog)
        for index in doc.fish.indices {
            var fish = doc.fish[index]
            guard let species = catalog.species(id: fish.speciesId) else {
                fish.position = clamped(fish.position, bounds)
                doc.fish[index] = fish
                continue
            }
            let cruise = ambient ? species.cruiseSpeed * ambientSpeedFactor : species.cruiseSpeed
            let oldHeading = fish.heading.isFinite ? fish.heading : 0
            // 1. Steering.
            var velocity = fish.velocity.isFinite
                ? fish.velocity : Vec2(cos(oldHeading), sin(oldHeading)) * cruise
            velocity += forces[index] * dt
            // 2. Reduced seeded wander turn.
            let wander = random.range(-1...1) * species.turnRate * wanderShare * dt
            let (s, c) = (sin(wander), cos(wander))
            velocity = Vec2(velocity.x * c - velocity.y * s, velocity.x * s + velocity.y * c)
            // 3. Speed between half the cruise speed and the maximum.
            var speed = velocity.length
            let direction = speed > 0 && speed.isFinite ? velocity / speed : Vec2(cos(oldHeading), sin(oldHeading))
            speed = min(max(speed.isFinite ? speed : cruise, minimumSpeedShare * cruise),
                        species.maxSpeed)
            velocity = direction * speed
            // 4. Move.
            var position = fish.position + velocity * dt
            // 5. Clamp into the bounds and reflect the outward component.
            if position.x < bounds.minX { position.x = bounds.minX; if velocity.x < 0 { velocity.x = -velocity.x } }
            if position.x > bounds.maxX { position.x = bounds.maxX; if velocity.x > 0 { velocity.x = -velocity.x } }
            if position.y < bounds.minY { position.y = bounds.minY; if velocity.y < 0 { velocity.y = -velocity.y } }
            if position.y > bounds.maxY { position.y = bounds.maxY; if velocity.y > 0 { velocity.y = -velocity.y } }
            fish.position = clamped(position, bounds)
            fish.velocity = velocity
            fish.heading = atan2(velocity.y, velocity.x)
            let change = wrappedAngle(fish.heading - oldHeading) / dt
            let turn = fish.turn.isFinite ? fish.turn : 0
            fish.turn = turn + turnSmoothing * (change - turn)
            let beats = tailBeatsPerLength * speed / species.length
            fish.animationPhase = wrappedPhase(fish.animationPhase + 2 * Double.pi * beats * dt)
            doc.fish[index] = fish
        }
        Feeding.step(&doc, catalog: catalog, dt: dt)
    }

    /// `p` clamped into `b` (a non-finite component becomes the bound's centre).
    static func clamped(_ p: Vec2, _ b: SwimBounds) -> Vec2 {
        let x = p.x.isFinite ? min(max(p.x, b.minX), b.maxX) : (b.minX + b.maxX) / 2
        let y = p.y.isFinite ? min(max(p.y, b.minY), b.maxY) : (b.minY + b.maxY) / 2
        return Vec2(x, y)
    }

    /// `angle` wrapped into −π…π.
    public static func wrappedAngle(_ angle: Double) -> Double {
        guard angle.isFinite else { return 0 }
        return atan2(sin(angle), cos(angle))
    }

    /// `phase` wrapped into 0 ≤ phase < 2π.
    static func wrappedPhase(_ phase: Double) -> Double {
        guard phase.isFinite else { return 0 }
        let full = 2 * Double.pi
        var value = phase.truncatingRemainder(dividingBy: full)
        if value < 0 { value += full }
        return value < full ? value : 0
    }
}
