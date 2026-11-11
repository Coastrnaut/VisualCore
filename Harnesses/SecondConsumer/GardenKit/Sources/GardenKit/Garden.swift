// Garden.swift — Lumen Garden's domain model (feature 009 T-F804; FR-F803, FR-F804; data model
// specs/009-second-consumer/data-model.md). Pure and host-testable: positions in world units (points at zoom 1),
// time advanced on a fixed step by the app, randomness from a seeded generator (deterministic replay).
import Foundation
import VisualCoreMath
import VisualCoreSimulation

public enum FlowerStage: String, Sendable, Equatable { case seed, growing, bloom, harvested }

public struct Flower: Sendable, Equatable, Identifiable {
    public let id: Int
    public let position: Vec2
    public let plantedAt: Double
    /// 0…1 hue chosen at planting (seeded).
    public let hue: Double
    public internal(set) var stage: FlowerStage = .seed
    /// 0…1 progress toward bloom.
    public internal(set) var growth = 0.0
}

public enum PlantResult: Sendable, Equatable { case planted(Int), tooClose, full }
public enum TapResult: Sendable, Equatable { case harvested(Int), notReady, nothing }
public enum InteractionResult: Sendable, Equatable { case planted(Int), harvested(Int), notReady, tooClose, full }

public struct Garden: Sendable {
    public static let capacity = 24
    public static let minSpacing = 40.0
    public static let harvestRadius = 30.0
    public static let growthDuration = 4.0
    public static let seedFraction = 0.15
    public static let breezeTimeConstant = 1.0
    public static let breezeScale = 0.5
    public static let maxBreeze = 300.0

    public private(set) var flowers: [Flower] = []
    public private(set) var score = 0
    public private(set) var breeze: Vec2 = .zero
    public private(set) var time = 0.0
    private var random: SeededRandom
    private var nextID = 0

    public init(seed: UInt64) { random = SeededRandom(seed: seed) }

    /// Flowers not yet harvested.
    public var plantedCount: Int { flowers.filter { $0.stage != .harvested }.count }
    public var bloomingCount: Int { flowers.filter { $0.stage == .bloom }.count }

    /// Plants a seed unless another unharvested flower is closer than `minSpacing` or the garden is full;
    /// a harvested slot (oldest first) is reused once `capacity` slots exist.
    public mutating func plant(at p: Vec2) -> PlantResult {
        guard p.isFinite else { return .tooClose }
        if flowers.contains(where: { $0.stage != .harvested && $0.position.distance(to: p) < Self.minSpacing }) { return .tooClose }
        let flower = Flower(id: nextID, position: p, plantedAt: time, hue: random.double())
        if flowers.count < Self.capacity {
            flowers.append(flower)
        } else if let slot = flowers.indices.filter({ flowers[$0].stage == .harvested }).min(by: { flowers[$0].plantedAt < flowers[$1].plantedAt }) {
            flowers[slot] = flower
        } else {
            return .full
        }
        nextID += 1
        return .planted(flower.id)
    }

    /// Harvests the nearest bloom within `harvestRadius` (+1 score).
    public mutating func tap(at p: Vec2) -> TapResult {
        let near = flowers.indices
            .filter { flowers[$0].stage != .harvested && flowers[$0].position.distance(to: p) <= Self.harvestRadius }
            .min { flowers[$0].position.distance(to: p) < flowers[$1].position.distance(to: p) }
        guard let i = near else { return .nothing }
        guard flowers[i].stage == .bloom else { return .notReady }
        flowers[i].stage = .harvested
        score += 1
        return .harvested(flowers[i].id)
    }

    /// What a tap does in the game: harvest or report a growing flower; otherwise plant.
    public mutating func interact(at p: Vec2) -> InteractionResult {
        switch tap(at: p) {
        case .harvested(let id): return .harvested(id)
        case .notReady: return .notReady
        case .nothing:
            switch plant(at: p) {
            case .planted(let id): return .planted(id)
            case .tooClose: return .tooClose
            case .full: return .full
            }
        }
    }

    /// Sets the breeze from a drag velocity (points per second), capped at `maxBreeze`.
    public mutating func drag(velocity v: Vec2) {
        guard v.isFinite else { return }
        let b = v * Self.breezeScale
        breeze = b.length > Self.maxBreeze ? b.normalized * Self.maxBreeze : b
    }

    /// Advances growth and breeze decay by one fixed step.
    public mutating func step(_ dt: Double) {
        guard dt.isFinite, dt > 0 else { return }
        time += dt
        breeze = breeze * exp(-dt / Self.breezeTimeConstant)
        for i in flowers.indices where flowers[i].stage != .harvested {
            let g = min(1, (time - flowers[i].plantedAt) / Self.growthDuration)
            flowers[i].growth = g
            flowers[i].stage = g >= 1 - 1e-9 ? .bloom : (g < Self.seedFraction ? .seed : .growing)
            if flowers[i].stage == .bloom { flowers[i].growth = 1 }
        }
    }
}
