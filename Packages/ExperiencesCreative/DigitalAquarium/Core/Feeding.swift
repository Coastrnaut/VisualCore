// Feeding — feature 070 (A09-P03) T-A09-303 (FR-A09-301, FR-A09-302, FR-A09-303; clarification 3; research D2;
// SC-A09-301, SC-A09-302). Food pellets in the water of a habitat document (schema 3, `food`). A feed adds 3 pellets
// 0.25 units apart horizontally around a point (x − 0.25, x, x + 0.25), each clamped into the swim bounds; at most 12
// pellets are in the water, and a feed that would exceed 12 is refused whole. Each fixed step, after the fish move
// (``AquariumSimulation/advance(_:catalog:random:)``):
// 1. every pellet sinks by 0.5 units per second × dt;
// 2. every fish of a known species, in document order, eats the nearest remaining pellet whose centre is within
//    0.5 × its body length + 0.15 units (at most one pellet per fish per step; ties go to the lower pellet index);
// 3. every pellet at or below the floor of the swim bounds is removed.
// Fish within 4 units of a pellet steer toward their nearest pellet with an added force of weight 2.5, summed with the
// schooling force before the species' force cap (``AquariumSimulation``). Everything is deterministic: no random
// numbers and no wall-clock input.
import Foundation
import VisualCoreMath
import VisualCoreSimulation

/// Dropping, seeking, sinking and eating food pellets in a habitat document.
public enum Feeding {
    /// The most pellets in the water at once (``HabitatDocument/maxFood``).
    public static let maxPellets = HabitatDocument.maxFood
    /// The pellets one feed adds.
    public static let pelletsPerFeed = 3
    /// The horizontal spacing of a feed's pellets, in habitat units.
    public static let spacing = 0.25
    /// How fast pellets sink, in habitat units per second.
    public static let sinkSpeed = 0.5
    /// The distance within which a fish seeks its nearest pellet, in habitat units.
    public static let seekRange = 4.0
    /// The weight of the seek force (units/s², before the species' force cap).
    public static let seekWeight = 2.5
    /// The margin added to half a fish's body length within which it eats a pellet, in habitat units.
    public static let eatMargin = 0.15

    /// True when a feed of ``pelletsPerFeed`` pellets fits under ``maxPellets``.
    public static func canDrop(_ doc: HabitatDocument) -> Bool {
        doc.food.count + pelletsPerFeed <= maxPellets
    }

    /// Adds a feed at `point`: pellets at x − ``spacing``, x and x + ``spacing`` (y the same), each clamped into the
    /// document's swim bounds (a non-finite component becomes the bounds' centre). Returns false and leaves `doc`
    /// unchanged when the feed would exceed ``maxPellets``.
    @discardableResult
    public static func drop(at point: Vec2, into doc: inout HabitatDocument) -> Bool {
        guard canDrop(doc) else { return false }
        for offset in [-spacing, 0, spacing] {
            let raw = Vec2(point.x + offset, point.y)
            doc.food.append(FoodPellet(position: AquariumSimulation.clamped(raw, doc.bounds)))
        }
        return true
    }

    /// The seek force on `fish`: the unit vector toward the nearest pellet of `food` within ``seekRange`` (ties go to
    /// the lower index) times ``seekWeight``; `.zero` when there is none, the fish or the direction is non-finite, or
    /// the pellet sits exactly on the fish.
    public static func seekForce(for fish: FishAgent, food: [FoodPellet]) -> Vec2 {
        guard fish.position.isFinite else { return .zero }
        var best: (distance: Double, offset: Vec2)?
        for pellet in food where pellet.position.isFinite {
            let offset = pellet.position - fish.position
            let distance = offset.length
            guard distance.isFinite, distance <= seekRange else { continue }
            if best == nil || distance < best!.distance { best = (distance, offset) }
        }
        guard let best, best.distance > 0 else { return .zero }
        let force = best.offset / best.distance * seekWeight
        return force.isFinite ? force : .zero
    }

    /// One feeding step of `dt` seconds: every pellet sinks by ``sinkSpeed`` × dt; every fish of a species in
    /// `catalog`, in document order, eats the nearest remaining pellet within 0.5 × its length + ``eatMargin`` (at
    /// most one; ties go to the lower index); then every pellet at or below `doc.bounds.minY` is removed. Returns the
    /// number of pellets eaten and the number removed at the floor. Fish, plants, decor and lighting are not changed.
    @discardableResult
    public static func step(_ doc: inout HabitatDocument, catalog: SpeciesCatalog,
                            dt: Double) -> (eaten: Int, floored: Int) {
        guard !doc.food.isEmpty else { return (0, 0) }
        let sink = dt.isFinite && dt > 0 ? sinkSpeed * dt : 0
        for index in doc.food.indices { doc.food[index].position.y -= sink }
        var eaten = 0
        for fish in doc.fish {
            guard !doc.food.isEmpty, fish.position.isFinite,
                  let species = catalog.species(id: fish.speciesId) else { continue }
            let reach = 0.5 * species.length + eatMargin
            var nearest: (index: Int, distance: Double)?
            for (index, pellet) in doc.food.enumerated() {
                let distance = pellet.position.distance(to: fish.position)
                guard distance.isFinite, distance <= reach else { continue }
                if nearest == nil || distance < nearest!.distance { nearest = (index, distance) }
            }
            if let nearest {
                doc.food.remove(at: nearest.index)
                eaten += 1
            }
        }
        let before = doc.food.count
        let floor = doc.bounds.minY
        doc.food.removeAll { !$0.position.y.isFinite || $0.position.y <= floor }
        return (eaten, before - doc.food.count)
    }
}
