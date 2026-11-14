// ParticleReplay.swift — deterministic particles at any preview time (feature 012 T-A01-107; clarification 4).
import VisualCoreMath
import VisualCoreParameters
import VisualCoreSimulation

/// Replays a particles document from t = 0 in fixed 1/60 s steps to `min(time, 120)`, so the same seed and time always
/// give the same particles. World units are view points with the origin at the view center, y up; the fountain sits at
/// the bottom center of a `worldHeight`-tall view.
public enum ParticleReplay {
    /// Fixed simulation step (seconds).
    public static let step = 1.0 / 60
    /// Largest number of live particles.
    public static let capacity = 10_000

    /// The number of fixed steps a replay to `time` runs: `time` clamped to 0…`ArtDocument.maxPreviewTime` (120 s; a
    /// non-finite time counts as 0) divided by `step`, rounded. Both the one-shot replay and the cursor use it, so the
    /// cap is one rule (tests check it here by arithmetic instead of replaying two minutes).
    public static func stepCount(at time: Double) -> Int {
        Int((min(max(time.isFinite ? time : 0, 0), ArtDocument.maxPreviewTime) / step).rounded())
    }

    /// Particles of `document` (validated, particles family) at `time`, for a view `worldHeight` points tall.
    public static func instances(for document: ArtDocument, at time: Double, worldHeight: Double = 600) -> [ParticleInstance] {
        var system = makeSystem(document, worldHeight: worldHeight)
        let steps = stepCount(at: time)
        for _ in 0..<steps { system.step(step) }
        return system.instances()
    }

    /// A configured, unstepped system for `document`.
    public static func makeSystem(_ document: ArtDocument, worldHeight: Double = 600) -> ParticleSystem {
        let values = document.parameters
        func v(_ name: String) -> Double { values[name] ?? FamilyCatalog.family(.particles).schema.definition(name)!.defaultValue }
        let palette = FamilyCatalog.palette(document.paletteID) ?? FamilyCatalog.palette(FamilyCatalog.family(.particles).defaultPaletteID)!
        func color(_ t: Double, alpha: Double) -> Vec4 {
            let c = palette.sample(t)
            return Vec4(Palette.sRGB(fromLinear: c.x), Palette.sRGB(fromLinear: c.y), Palette.sRGB(fromLinear: c.z), alpha)
        }
        var system = ParticleSystem(capacity: capacity, seed: document.seed)
        let speed = v("speed")
        system.emitters = [Emitter(position: Vec2(0, -worldHeight * 0.42), rate: v("count"), lifetime: 1.4...2.8,
                                   speed: (speed * 0.75)...(speed * 1.25), direction: .pi / 2, spread: v("spread"),
                                   startSize: v("size"), endSize: v("size") * 0.2,
                                   startColor: color(0.95, alpha: 1), endColor: color(0.35, alpha: 0))]
        system.forces = [.gravity(Vec2(0, v("gravity"))), .drag(v("drag"))]
        return system
    }
}

/// Live, incremental replay: advancing to a later time steps forward at the fixed rate; going back rebuilds from 0. The
/// state at any time equals `ParticleReplay.instances(for:at:)`, so live frames and still previews agree.
public struct ParticleReplayCursor: Sendable {
    /// The document being replayed.
    public let document: ArtDocument
    /// World height the system was built for.
    public let worldHeight: Double
    /// Fixed steps taken so far.
    public private(set) var steps = 0
    private var system: ParticleSystem

    /// A cursor at t = 0.
    public init(document: ArtDocument, worldHeight: Double = 600) {
        self.document = document
        self.worldHeight = worldHeight
        system = ParticleReplay.makeSystem(document, worldHeight: worldHeight)
    }

    /// Moves to `time` (clamped to 0…120 s) and returns the particles there.
    public mutating func instances(at time: Double) -> [ParticleInstance] {
        let target = ParticleReplay.stepCount(at: time)
        if target < steps {
            system = ParticleReplay.makeSystem(document, worldHeight: worldHeight)
            steps = 0
        }
        while steps < target { system.step(ParticleReplay.step); steps += 1 }
        return system.instances()
    }
}
