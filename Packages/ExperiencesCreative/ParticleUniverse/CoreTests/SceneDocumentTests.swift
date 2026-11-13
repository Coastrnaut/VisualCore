// SceneDocumentTests — feature 036 A04-P04 T-A04-402 (FR-A04-402, FR-A04-404, FR-A04-410…412; US2; data model;
// contracts/actions.md). Fixtures under Fixtures/scene-*.json are written by hand and never edited.
import Foundation
import Testing
import VisualCoreMath
@testable import ParticleUniverseCore

private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

private func reason(_ data: Data) -> SceneError? {
    do { _ = try SceneDocument.decode(data); return nil } catch { return error }
}

private func reason(_ make: () throws -> SceneDocument) -> SceneError? {
    do { _ = try make(); return nil } catch { return (error as? SceneError) ?? .invalidDocument("unexpected \(error)") }
}

private let scene = ParticleScene(seed: 7, emitters: [
    SceneEmitter(family: .fountain),
    SceneEmitter(family: .halo, position: Vec2(150, -20), size: 12, lifetime: 3, gradient: "ocean"),
    SceneEmitter(family: .firework, position: Vec2(-450, 0), gradient: "ember"),
])

private func document(name: String = "Nebula", force: SavedForce? = SavedForce(kind: "vortex", x: 120, y: -80, strength: 1.5),
                      trailStrength: Double = 0.6) throws(SceneError) -> SceneDocument {
    try SceneDocument(name: name, scene: scene, force: force, trailsOn: true, trailStrength: trailStrength, additive: true)
}

@Test func version2RoundTrips() throws {
    let doc = try document()
    let back = try SceneDocument.decode(try doc.encoded())
    #expect(back == doc)
    let noForce = try document(force: nil)
    #expect(try SceneDocument.decode(try noForce.encoded()) == noForce)
    // Sorted keys: the encoding is stable.
    #expect(try doc.encoded() == back.encoded())
    let text = String(decoding: try doc.encoded(), as: UTF8.self)
    #expect(text.contains("\"version\":2"))
}

@Test func version2FixtureDecodes() throws {
    let doc = try SceneDocument.decode(try fixture("scene-v2"))
    #expect(doc.name == "Nebula")
    #expect(doc.scene.emitters.count == 2)
    #expect(doc.scene.emitters[1] == SceneEmitter(family: .halo, position: Vec2(150, -20), size: 12, lifetime: 3, gradient: "ocean"))
    #expect(doc.force == SavedForce(kind: "attractor", x: 100, y: 50, strength: 1.25))
    #expect(doc.trailsOn && doc.trailStrength == 0.6 && doc.additive)
}

@Test func version1MigratesWithNoForceAndDefaultLooks() throws {
    let doc = try SceneDocument.decode(try fixture("scene-v1"))
    #expect(doc.name == SceneDocument.untitledName)
    #expect(doc.scene.seed == 24_301 && doc.scene.emitters.map(\.family) == [.fountain, .firework])
    #expect(doc.force == nil)
    #expect(doc.trailsOn == SceneDocument.defaultTrailsOn && doc.trailsOn == false)
    #expect(doc.trailStrength == SceneDocument.defaultTrailStrength && doc.trailStrength == 0.85)
    #expect(doc.additive == SceneDocument.defaultAdditive && doc.additive == false)
    // A bare scene encoded by the existing format migrates too, and a v1 file with a name keeps it.
    #expect(try SceneDocument.decode(try JSONEncoder().encode(scene)).scene == scene)
    var json = try #require(try JSONSerialization.jsonObject(with: fixture("scene-v1")) as? [String: Any])
    json["name"] = "  Old fountain  "
    #expect(try SceneDocument.decode(try JSONSerialization.data(withJSONObject: json)).name == "Old fountain")
    // Saving a migrated document writes version 2.
    #expect(try SceneDocument.decode(try doc.encoded()) == doc)
}

@Test func newerVersionIsRefused() throws {
    #expect(reason(try fixture("scene-newer")) == .unsupportedVersion(3))
    #expect(reason(Data(#"{"version":0}"#.utf8)) == .unsupportedVersion(0))
}

@Test func nonFiniteAndTruncatedAreRefused() throws {
    #expect(reason(try fixture("scene-nan")) == .nonFinite("trailStrength"))
    guard case .invalidDocument = reason(try fixture("scene-truncated")) else { Issue.record("truncated accepted"); return }
    guard case .invalidDocument = reason(Data("not json".utf8)) else { Issue.record("garbage accepted"); return }
    guard case .invalidDocument = reason(Data(#"{"name":"x"}"#.utf8)) else { Issue.record("no version accepted"); return }
    // An invalid scene inside a valid document keeps the scene's own reason.
    let v2 = String(decoding: try fixture("scene-v2"), as: UTF8.self)
    #expect(reason(Data(v2.replacingOccurrences(of: "\"particleLimit\" : 4000", with: "\"particleLimit\" : 50").utf8))
            == .limitOutOfRange(50))
}

@Test func nameIsOneToSixtyFourCharactersAfterTrimming() throws {
    #expect(try document(name: "  Nebula \n").name == "Nebula")
    #expect(try document(name: String(repeating: "a", count: 64)).name.count == 64)
    #expect(reason { try document(name: "   ") } == .invalidDocument("name"))
    #expect(reason { try document(name: "") } == .invalidDocument("name"))
    #expect(reason { try document(name: String(repeating: "a", count: 65)) } == .invalidDocument("name"))
    // The same rule on decode.
    var doc = try document()
    doc.name = String(repeating: "b", count: 65)
    #expect(throws: SceneError.invalidDocument("name")) { try doc.encoded() }
    let text = String(decoding: try document().encoded(), as: UTF8.self).replacingOccurrences(of: "\"Nebula\"", with: "\"  \"")
    #expect(reason(Data(text.utf8)) == .invalidDocument("name"))
}

@Test func forceAndLooksAreRangeChecked() {
    let h = PlacedForce.worldHalfExtent
    #expect(reason { try document(force: SavedForce(kind: "wind", x: -h, y: h, strength: PlacedForce.strengthRange.lowerBound)) } == nil)
    #expect(reason { try document(force: SavedForce(kind: "wind", x: 0, y: 0, strength: PlacedForce.strengthRange.upperBound)) } == nil)
    #expect(reason { try document(force: SavedForce(kind: "wind", x: h + 1, y: 0, strength: 1)) } == .invalidDocument("force.x"))
    #expect(reason { try document(force: SavedForce(kind: "wind", x: 0, y: -h - 1, strength: 1)) } == .invalidDocument("force.y"))
    #expect(reason { try document(force: SavedForce(kind: "wind", x: 0, y: 0, strength: 0.05)) } == .invalidDocument("force.strength"))
    #expect(reason { try document(force: SavedForce(kind: "wind", x: 0, y: 0, strength: 2.5)) } == .invalidDocument("force.strength"))
    #expect(reason { try document(force: SavedForce(kind: "tornado", x: 0, y: 0, strength: 1)) } == .invalidDocument("force.kind"))
    #expect(reason { try document(force: SavedForce(kind: "wind", x: .nan, y: 0, strength: 1)) } == .nonFinite("force.x"))
    #expect(reason { try document(force: SavedForce(kind: "wind", x: 0, y: .infinity, strength: 1)) } == .nonFinite("force.y"))
    #expect(reason { try document(trailStrength: 1.01) } == .invalidDocument("trailStrength"))
    #expect(reason { try document(trailStrength: -0.01) } == .invalidDocument("trailStrength"))
    #expect(reason { try document(trailStrength: .nan) } == .nonFinite("trailStrength"))
    var bad = scene
    bad.emitters[0].position = Vec2(.nan, 0)
    #expect(reason { try SceneDocument(name: "x", scene: bad, force: nil, trailsOn: false, trailStrength: 0.5, additive: false) }
            == .nonFinite("emitters[0].position"))
}

@Test func openActionsFollowTheContract() throws {
    let doc = try document()
    let actions = doc.openActions()
    #expect(actions.map { $0.id } == ["scene.begin", "emitter.define", "emitter.define", "emitter.define", "force.define", "look.define"])
    #expect(actions[0].values == [3])
    let fountain = EmitterFamily.fountain.emitter().position
    #expect(actions[1].values == [0, fountain.x, fountain.y, 0, 0, 0])
    let ocean = Double(try #require(SceneDocument.gradientIDs.firstIndex(of: "ocean")))
    #expect(actions[2].values == [2, 150, -20, 12, 3, ocean])
    let ember = Double(try #require(SceneDocument.gradientIDs.firstIndex(of: "ember")))
    #expect(actions[3].values == [3, -450, 0, 0, 0, ember])
    #expect(actions[4].values == [Double(SceneDocument.forceKindIndex("vortex")), 120, -80, 1.5])
    #expect(SceneDocument.forceKindIndex("vortex") == PlacedForceKind.allCases.count)
    #expect(actions[5].values == [1, 0.6, 1])
    let none = try document(force: nil).openActions()
    #expect(none[4].id == "force.define" && none[4].values == [0, 0, 0, 1])
    #expect(SceneDocument.familyIndex(.firework) == 3 && SceneDocument.gradientIndex(nil) == 0 && SceneDocument.forceKindIndex(nil) == 0)
}

@Test func openActionsStayWithinLimits() throws {
    let full = ParticleScene(emitters: Array(repeating: SceneEmitter(family: .curtain, size: 48, lifetime: 8, gradient: "mono"),
                                             count: ParticleScene.maxEmitters))
    let doc = try SceneDocument(name: "Full", scene: full, force: nil, trailsOn: false, trailStrength: 0, additive: false)
    let actions = doc.openActions()
    #expect(actions.count == 11 && actions.count <= SceneDocument.maxOpenActions)
    #expect(actions.allSatisfy { $0.values.count <= 8 && $0.values.allSatisfy(\.isFinite) })
}

@Test func defineValuesInvertToTheDocument() throws {
    let doc = try document()
    let actions = doc.openActions()
    let emitters = try actions.filter { $0.id == "emitter.define" }.map { try SceneDocument.emitter(fromDefine: $0.values) }
    #expect(emitters == doc.scene.emitters)
    #expect(try SceneDocument.force(fromDefine: actions[4].values) == doc.force)
    #expect(try SceneDocument.force(fromDefine: [0, 0, 0, 1]) == nil)
    for bad: [Double] in [[9, 0, 0, 0, 0, 0], [0, 600, 0, 0, 0, 0], [0, 0, 0, 60, 0, 0], [0, 0, 0, 0, 9, 0],
                          [0, .nan, 0, 0, 0, 0], [0, 0, 0, 0, 0, 99], [0, 0, 0, 0, 0], [0.5, 0, 0, 0, 0, 0]] {
        #expect(throws: SceneError.self) { try SceneDocument.emitter(fromDefine: bad) }
    }
    for bad: [Double] in [[1, 0, 0, 3], [6, 0, 0, 1], [1, 501, 0, 1], [1, 0, 0, .nan], [1, 0, 0]] {
        #expect(throws: SceneError.self) { try SceneDocument.force(fromDefine: bad) }
    }
}
