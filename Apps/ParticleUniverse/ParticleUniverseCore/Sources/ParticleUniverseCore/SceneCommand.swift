// SceneCommand.swift — control commands for a running scene, live or replayed by step index (feature 033 A04-P01
// T-A04-108; FR-A04-104; data model).

/// A change to a running scene. Commands naming an emitter or force that does not exist are ignored and counted.
public enum SceneCommand: Codable, Equatable, Sendable {
    /// Moves the scene attractor at `index` in `ParticleScene.forces` to (x, y).
    case moveAttractor(index: Int, x: Double, y: Double)
    /// Emits `count` particles from emitter `emitter` on the next step (count clamped to 1…5,000).
    case burst(emitter: Int, count: Int)
    /// Starts or stops an emitter's continuous and periodic emission.
    case setEmitting(emitter: Int, on: Bool)
}
