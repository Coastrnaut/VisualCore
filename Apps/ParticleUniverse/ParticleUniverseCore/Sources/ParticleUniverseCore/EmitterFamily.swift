// EmitterFamily.swift — the four emitter families of the sandbox (feature 033 A04-P01 T-A04-105; FR-A04-106;
// spec clarification 4). World units: the scene is the square −500…500 on both axes, y up.
import VisualCoreMath
import VisualCoreSimulation

/// A named emitter preset: shape, emission mode, parameters and the forces it brings.
public enum EmitterFamily: String, CaseIterable, Codable, Sendable {
    /// A point near the bottom spraying upward under gravity.
    case fountain
    /// A horizontal line near the top letting particles fall slowly.
    case curtain
    /// A ring around the center emitting outward.
    case halo
    /// Periodic bursts from the center, slowed by drag.
    case firework

    /// The family's name in the UI.
    public var title: String {
        switch self {
        case .fountain: "Fountain"
        case .curtain: "Curtain"
        case .halo: "Halo"
        case .firework: "Firework"
        }
    }

    /// What the family does, for VoiceOver and the description line.
    public var spokenDescription: String {
        switch self {
        case .fountain: "A fountain near the bottom sprays particles upward; gravity pulls them back down."
        case .curtain: "A line across the top releases particles that drift slowly downward like a curtain."
        case .halo: "A ring around the center sends particles outward in every direction."
        case .firework: "Bursts of particles explode from the center every one and a half seconds and slow down."
        }
    }

    /// The family's emitter (unclamped values are all in range).
    public func emitter() -> Emitter {
        switch self {
        case .fountain:
            Emitter(position: Vec2(0, -400), rate: 600, lifetime: 2...4, speed: 300...450, direction: .pi / 2, spread: 0.6,
                    startSize: 6, endSize: 1, startColor: Vec4(1, 0.78, 0.3, 1), endColor: Vec4(1, 0.3, 0.1, 0))
        case .curtain:
            Emitter(position: Vec2(0, 450), rate: 800, lifetime: 2...3, speed: 40...90, direction: -.pi / 2, spread: 0.2,
                    startSize: 5, endSize: 2, startColor: Vec4(0.4, 0.9, 1, 1), endColor: Vec4(0.2, 0.4, 1, 0),
                    shape: .line(halfLength: 400, angle: 0))
        case .halo:
            Emitter(position: .zero, rate: 700, lifetime: 1.5...2.5, speed: 60...120, direction: 0, spread: 0.3,
                    startSize: 5, endSize: 1, startColor: Vec4(0.8, 0.5, 1, 1), endColor: Vec4(0.4, 0.2, 1, 0),
                    shape: .ring(radius: 200), radial: true)
        case .firework:
            Emitter(position: .zero, rate: 0, lifetime: 1...2, speed: 100...260, direction: 0, spread: 2 * .pi,
                    startSize: 6, endSize: 0, startColor: Vec4(1, 1, 0.8, 1), endColor: Vec4(1, 0.4, 0.6, 0),
                    burst: EmitterBurst(count: 400, interval: 1.5))
        }
    }

    /// Forces the family brings with it.
    public func forces() -> [ParticleForce] {
        switch self {
        case .fountain: [.gravity(Vec2(0, -150))]
        case .curtain, .halo: []
        case .firework: [.drag(0.8)]
        }
    }
}
