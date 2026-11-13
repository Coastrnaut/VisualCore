// ReplayFixtureTests — feature 033 T-A04-109 (manual §11 fixture 1; FR-A04-104; US2; SC-A04-103; spec clarification 5,
// analyze U1/U2). The fixture is written once with PU_WRITE_FIXTURE=1 and never edited; a schema or behavior change
// must add replay-v2.json instead.
import Foundation
import Testing
import VisualCoreMath
@testable import ParticleUniverseCore

/// The committed replay fixture, schema 1.
struct ReplayFixture: Codable, Equatable {
    struct Control: Codable, Equatable { var step: Int; var command: SceneCommand }
    struct Expected: Codable, Equatable {
        /// FNV-1a checksum, hexadecimal.
        var checksum: String
        var live: Int
        var dropped: Int
        /// The first 8 positions as `Double.bitPattern` hexadecimal pairs (exact comparison).
        var positions: [[String]]
    }
    var schema: Int
    var scene: ParticleScene
    var controls: [Control]
    var steps: Int
    var expected: Expected
}

private func hex(_ v: UInt64) -> String { "0x" + String(v, radix: 16) }

/// The fixture's inputs (clarification 5 and analyze U1/U2).
private func fixtureInputs() -> (ParticleScene, [ReplayFixture.Control], Int) {
    let scene = ParticleScene(seed: 0x5EED, emitters: [SceneEmitter(family: .fountain), SceneEmitter(family: .firework)],
                              forces: [.attractor(x: 0, y: 0, strength: 300, radius: 300)])
    let controls = [ReplayFixture.Control(step: 120, command: .moveAttractor(index: 0, x: 150, y: 100)),
                    ReplayFixture.Control(step: 240, command: .burst(emitter: 1, count: 200)),
                    ReplayFixture.Control(step: 360, command: .setEmitting(emitter: 0, on: false))]
    return (scene, controls, 600)
}

private func simulate(_ scene: ParticleScene, _ controls: [ReplayFixture.Control]) throws -> SceneSimulation {
    try SceneSimulation(scene: scene, controls: controls.map { (step: $0.step, command: $0.command) })
}

private func expected(of sim: SceneSimulation) -> ReplayFixture.Expected {
    ReplayFixture.Expected(checksum: hex(sim.checksum()), live: sim.liveCount, dropped: sim.droppedCount,
                           positions: sim.positions(first: 8).map { [hex($0.x.bitPattern), hex($0.y.bitPattern)] })
}

private let sourceURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/replay-v1.json")

private func loadFixture() throws -> ReplayFixture {
    let url = try #require(Bundle.module.url(forResource: "replay-v1", withExtension: "json", subdirectory: "Fixtures"))
    return try JSONDecoder().decode(ReplayFixture.self, from: Data(contentsOf: url))
}

@Test func writeFixtureWhenAsked() throws {
    guard ProcessInfo.processInfo.environment["PU_WRITE_FIXTURE"] == "1" else { return }
    let (scene, controls, steps) = fixtureInputs()
    var sim = try simulate(scene, controls)
    sim.run(steps: steps)
    let fixture = ReplayFixture(schema: 1, scene: scene, controls: controls, steps: steps, expected: expected(of: sim))
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(fixture).write(to: sourceURL)
}

@Test func replayReproducesTheFixtureBitForBit() throws {
    // US2 AC1 / SC-A04-103.
    let f = try loadFixture()
    #expect(f.schema == 1)
    let (scene, controls, steps) = fixtureInputs()
    #expect(f.scene == scene && f.controls == controls && f.steps == steps, "the fixture's inputs are the documented ones")
    var sim = try simulate(f.scene, f.controls)
    sim.run(steps: f.steps)
    #expect(expected(of: sim) == f.expected)
    #expect(f.expected.live > 0 && f.expected.positions.count == 8)
}

@Test func anotherSeedGivesAnotherScene() throws {
    // US2 AC2.
    let f = try loadFixture()
    var scene = f.scene
    scene.seed &+= 1
    var sim = try simulate(scene, f.controls)
    sim.run(steps: f.steps)
    #expect(hex(sim.checksum()) != f.expected.checksum)
}

@Test func frameLengthsDoNotChangeTheReplay() throws {
    // US2 AC3 / SC-A04-103: 1/60 s and 1/30 s frames reach the same 600 steps and the fixture's checksum.
    let f = try loadFixture()
    for (frame, count) in [(1.0 / 60, 300), (1.0 / 30, 150)] {
        var sim = try simulate(f.scene, f.controls)
        for _ in 0..<count { sim.advance(frame: frame) }
        #expect(sim.stepIndex == f.steps, "frame \(frame)")
        #expect(hex(sim.checksum()) == f.expected.checksum, "frame \(frame)")
    }
}
