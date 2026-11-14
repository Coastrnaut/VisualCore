// AquariumSimulation — feature 068 (A09-P01) T-A09-102 (FR-A09-110, FR-A09-111; clarification 1; research D1). The
// seeded, fixed-step bounded wander of this phase. Each step (1/60 s) every fish, in document order:
// 1. turns by a seeded random amount within ±(species turn rate × step);
// 2. eases its speed toward the species cruise speed (never above the maximum);
// 3. steers inward when closer than `margin` (1 unit) to a bound, turning toward the inside by at most
//    `steerRate` × step (stronger the closer it is);
// 4. moves by velocity × step;
// 5. is clamped into the swim bounds, and each outward velocity component at a clamped edge is reflected.
// The heading then follows the velocity, and the animation phase advances in proportion to speed / body length. The
// clamp makes leaving the bounds impossible by construction; reflection never changes the speed, so no fish exceeds its
// maximum. There is no wall-clock input: the same document, catalog and generator state give the same result. Reduce
// Motion never reaches this type (the experience halves only what it draws), so the state never depends on it.
// Bounded steering with neighbours (schools) replaces steps 1–2 in A09-P02; the bounds guarantee stays.
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// The fixed-step bounded wander of the fish in a habitat document.
public enum AquariumSimulation {
    /// The fixed step in seconds.
    public static let step = 1.0 / 60
    /// The distance from a bound inside which a fish steers inward, in habitat units.
    public static let margin = 1.0
    /// The largest inward steering turn per second, in radians (at the bound itself).
    public static let steerRate = 3.0
    /// How quickly the speed eases toward the cruise speed, per second.
    public static let easeRate = 1.5
    /// Tail swings per unit of (speed / body length).
    public static let tailBeatsPerLength = 0.6

    /// Advances every fish of `doc` by one ``step`` using the species of `catalog` and the generator `random` (one
    /// draw per fish whose species is known). A fish whose species is not in the catalog is only clamped into the
    /// bounds; plants, decor and lighting are not changed.
    public static func advance(_ doc: inout HabitatDocument, catalog: SpeciesCatalog, random: inout SeededRandom) {
        let bounds = doc.bounds
        let dt = step
        for index in doc.fish.indices {
            var fish = doc.fish[index]
            guard let species = catalog.species(id: fish.speciesId) else {
                fish.position = clamped(fish.position, bounds)
                doc.fish[index] = fish
                continue
            }
            // 1. Seeded random turn.
            var heading = fish.heading + random.range(-1...1) * species.turnRate * dt
            // 2. Ease the speed toward cruise, never above the maximum.
            var speed = fish.velocity.isFinite ? fish.velocity.length : species.cruiseSpeed
            speed += (species.cruiseSpeed - speed) * min(1, easeRate * dt)
            speed = min(max(speed, 0), species.maxSpeed)
            // 3. Inward steering near a bound.
            let push = inwardPush(fish.position, bounds)
            if push.x != 0 || push.y != 0 {
                let strength = min(1, push.length)
                let target = atan2(push.y, push.x)
                let difference = wrappedAngle(target - heading)
                let limit = steerRate * strength * dt
                heading += min(max(difference, -limit), limit)
            }
            var velocity = Vec2(cos(heading), sin(heading)) * speed
            // 4. Move.
            var position = fish.position + velocity * dt
            // 5. Clamp into the bounds and reflect the outward component.
            if position.x < bounds.minX { position.x = bounds.minX; if velocity.x < 0 { velocity.x = -velocity.x } }
            if position.x > bounds.maxX { position.x = bounds.maxX; if velocity.x > 0 { velocity.x = -velocity.x } }
            if position.y < bounds.minY { position.y = bounds.minY; if velocity.y < 0 { velocity.y = -velocity.y } }
            if position.y > bounds.maxY { position.y = bounds.maxY; if velocity.y > 0 { velocity.y = -velocity.y } }
            fish.position = clamped(position, bounds)
            fish.velocity = velocity
            fish.heading = speed > 0 ? atan2(velocity.y, velocity.x) : wrappedAngle(heading)
            let beats = tailBeatsPerLength * speed / species.length
            fish.animationPhase = wrappedPhase(fish.animationPhase + 2 * Double.pi * beats * dt)
            doc.fish[index] = fish
        }
    }

    /// The inward push at `p`: per axis, 0 farther than ``margin`` from both bounds, rising linearly to 1 at a bound,
    /// pointing into the bounds.
    static func inwardPush(_ p: Vec2, _ b: SwimBounds) -> Vec2 {
        var push = Vec2.zero
        if p.x < b.minX + margin { push.x += min(1, (b.minX + margin - p.x) / margin) }
        if p.x > b.maxX - margin { push.x -= min(1, (p.x - (b.maxX - margin)) / margin) }
        if p.y < b.minY + margin { push.y += min(1, (b.minY + margin - p.y) / margin) }
        if p.y > b.maxY - margin { push.y -= min(1, (p.y - (b.maxY - margin)) / margin) }
        return push
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
