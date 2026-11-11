// ParticleSceneTests — feature 033 T-A04-111 (FR-A04-105; US4 AC1/AC2; SC-A04-105).
import Foundation
import Testing
import VisualCoreMath
@testable import ParticleUniverseCore

private let valid = ParticleScene(seed: 42, particleLimit: 5_000, timeScale: 1.5,
                                  emitters: [SceneEmitter(family: .fountain), SceneEmitter(family: .halo, position: Vec2(10, -20))],
                                  forces: [.attractor(x: 0, y: 0, strength: 300, radius: 300), .drag(k: 0.2), .gravity(x: 0, y: -9)])

private func reason(_ scene: ParticleScene) -> SceneError? {
    do { try scene.validate(); return nil } catch { return error }
}

@Test func validSceneRoundTrips() throws {
    #expect(reason(valid) == nil)
    let data = try JSONEncoder().encode(valid)
    let back = try JSONDecoder().decode(ParticleScene.self, from: data)
    #expect(back == valid)
    #expect(ParticleScene.single(.firework).particleLimit == 4_000 && ParticleScene.single(.firework).timeScale == 1)
}

@Test func everyInvalidCaseIsRejectedWithItsReason() {
    func with(_ edit: (inout ParticleScene) -> Void) -> ParticleScene { var s = valid; edit(&s); return s }
    #expect(reason(with { $0.version = 2 }) == .unsupportedVersion(2))
    #expect(reason(with { $0.particleLimit = 99 }) == .limitOutOfRange(99))
    #expect(reason(with { $0.particleLimit = 20_001 }) == .limitOutOfRange(20_001))
    #expect(reason(with { $0.timeScale = .nan }) == .nonFinite("timeScale"))
    #expect(reason(with { $0.timeScale = 0.2 }) == .timeScaleOutOfRange(0.2))
    #expect(reason(with { $0.timeScale = 2.5 }) == .timeScaleOutOfRange(2.5))
    #expect(reason(with { $0.emitters = [] }) == .emitterCount(0))
    #expect(reason(with { $0.emitters = Array(repeating: SceneEmitter(family: .halo), count: 9) }) == .emitterCount(9))
    #expect(reason(with { $0.emitters[1].position = Vec2(.infinity, 0) }) == .nonFinite("emitters[1].position"))
    #expect(reason(with { $0.forces = Array(repeating: .drag(k: 1), count: 9) }) == .forceCount(9))
    #expect(reason(with { $0.forces[2] = .gravity(x: .nan, y: 0) }) == .nonFinite("forces[2]"))
    #expect(reason(with { $0.forces[1] = .drag(k: -1) }) == .invalidForce(1))
    #expect(reason(with { $0.forces[0] = .attractor(x: 0, y: 0, strength: 1, radius: 0) }) == .invalidForce(0))
}

@Test func decodingRejectsInvalidData() throws {
    var json = try #require(String(data: JSONEncoder().encode(valid), encoding: .utf8))
    json = json.replacingOccurrences(of: "\"particleLimit\":5000", with: "\"particleLimit\":50")
    #expect(throws: SceneError.limitOutOfRange(50)) { try JSONDecoder().decode(ParticleScene.self, from: Data(json.utf8)) }

    let v2 = try #require(String(data: JSONEncoder().encode(valid), encoding: .utf8))
        .replacingOccurrences(of: "\"version\":1", with: "\"version\":2")
    #expect(throws: SceneError.unsupportedVersion(2)) { try JSONDecoder().decode(ParticleScene.self, from: Data(v2.utf8)) }

    let truncated = Data(try JSONEncoder().encode(valid).prefix(30))
    #expect(throws: (any Error).self) { try JSONDecoder().decode(ParticleScene.self, from: truncated) }
    let unknownFamily = try #require(String(data: JSONEncoder().encode(valid), encoding: .utf8))
        .replacingOccurrences(of: "\"halo\"", with: "\"comet\"")
    #expect(throws: (any Error).self) { try JSONDecoder().decode(ParticleScene.self, from: Data(unknownFamily.utf8)) }
}

@Test func sceneForcesMapToVisualCoreForces() {
    #expect(SceneForce.gravity(x: 1, y: 2).particleForce == .gravity(Vec2(1, 2)))
    #expect(SceneForce.drag(k: 0.5).particleForce == .drag(0.5))
    #expect(SceneForce.attractor(x: 1, y: 2, strength: 3, radius: 4).particleForce == .attractor(point: Vec2(1, 2), strength: 3, radius: 4))
    #expect(SceneEmitter(family: .halo, position: Vec2(10, -20)).emitter().position == Vec2(10, -20))
    #expect(SceneEmitter(family: .fountain).emitter() == EmitterFamily.fountain.emitter())
}
