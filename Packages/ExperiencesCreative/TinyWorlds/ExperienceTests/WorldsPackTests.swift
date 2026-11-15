// WorldsPackTests — feature 092 (A12-P04) T-A12-403 (FR-A12-402, FR-A12-404, FR-A12-407; SC-A12-401, SC-A12-405;
// clarifications Q1, Q3 and Q5). The environment packs inside the experience, short runs only (each test under 10 s,
// no wall-clock assertion): `world.pack i` from the default state gives the committed digest of
// `WorldsCore.packFixtures`, the state of `WorldPack.state()` with its props and no selection; opening a pack after
// edits ("reset to pack") restores that digest exactly; out-of-range and fractional indices are refused and change
// nothing; every action, `world.pack` among them, has a native control, Open pack and Reset to pack carry their
// identifiers, and an opened pack is answered in words ("Opened the island pack."); tilt and zoom are enabled against
// the preset's limits; under Reduce Motion the drawn view moves directly to the pack's view; and a drawn frame of each
// pack is non-blank and not black, with every prop drawn.
import Foundation
import XCTest
@testable import TinyWorldsExperience
import TinyWorldsCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreDiagnostics
import VisualCoreUI

@MainActor
final class WorldsPackTests: XCTestCase {
    private let worldsID = ExperienceID(rawValue: WorldsCore.experienceID)!

    private func makeEngine(seed: UInt64 = 1) async throws -> ExperienceEngine<WorldsCore> {
        var engine = ExperienceEngine<WorldsCore>(id: worldsID)
        try await engine.prepare(seed: seed)
        try engine.activate()
        return engine
    }

    func testPackDigestsEqualTheCommittedValues() async throws {
        XCTAssertEqual(WorldsCore.packFixtures.map(\.pack), [.island, .asteroidGarden, .miniatureCity])
        XCTAssertEqual(Set(WorldsCore.packFixtures.map(\.digest)).count, 3)
        for fixture in WorldsCore.packFixtures {
            let index = fixture.pack.rawValue
            let pack = try XCTUnwrap(WorldPack.pack(index: index))
            var engine = try await makeEngine()
            XCTAssertEqual(engine.handle(control: "world.pack", values: [Double(index)]), .accepted, pack.id)
            let core = try XCTUnwrap(engine.core)
            let digest = try engine.digest().hex
            XCTAssertEqual(digest, fixture.digest, "\(pack.id): \(digest)")
            XCTAssertEqual(try worldsDigest(core), fixture.digest, pack.id)
            let expected = try pack.state().get()
            XCTAssertEqual(core.state, expected, "\(pack.id): the state of WorldPack.state()")
            XCTAssertEqual(try worldsDigest(worldsCore(expected)), fixture.digest, "\(pack.id) restores unchanged")
            XCTAssertEqual(core.preset.id, fixture.pack)
            XCTAssertEqual(core.seed, pack.seed)
            XCTAssertEqual(core.props.map(\.kind), pack.props.map(\.kind))
            XCTAssertEqual(core.selection, WorldState.noSelection, "a pack opens with no selection")
            XCTAssertEqual(core.light, pack.light)
            XCTAssertTrue(CameraPolicy.keepsClearance(core.state), pack.id)
            XCTAssertEqual(core.terrainDigest, try TerrainGenerator.digest(preset: pack.preset, seed: pack.seed))
            XCTAssertEqual(WorldsCore.expectedDigest(for: worldsID, seed: WorldsCore.manifestSeed,
                                                     entries: WorldsCore.packEntries(fixture.pack)), fixture.digest)
        }
    }

    func testResetAfterEditsRestoresTheDigestExactly() async throws {
        let edits: [(String, [Double])] = [
            ("prop.select", [0]), ("prop.rotate", [45]), ("light.azimuth", [90]), ("light.elevation", [70]),
            ("light.ambient", [0.15]), ("prop.select", [1]), ("prop.delete", []), ("view.orbit", [20, 5]),
            ("view.zoom", [1.1]), ("world.seed", []), ("world.preset", [0]),
        ]
        for fixture in WorldsCore.packFixtures {
            let index = Double(fixture.pack.rawValue)
            var engine = try await makeEngine()
            XCTAssertEqual(engine.handle(control: "world.pack", values: [index]), .accepted)
            let opened = try engine.digest().hex
            for (control, values) in edits {
                XCTAssertEqual(engine.handle(control: control, values: values), .accepted, "\(control) \(values)")
            }
            XCTAssertNotEqual(try engine.digest().hex, opened, "the edits changed the world")
            XCTAssertEqual(engine.handle(control: "world.pack", values: [index]), .accepted)
            XCTAssertEqual(try engine.digest().hex, opened, "\(fixture.pack): reset to pack restores the digest")
            XCTAssertEqual(opened, fixture.digest)
        }
        let played = WorldsCore.played(seed: WorldsCore.manifestSeed, entries: WorldsCore.packResetEntries)
        XCTAssertEqual(try worldsDigest(played), WorldsCore.packFixtures[0].digest)
        XCTAssertEqual(WorldsCore.packResetEntries.count, 12)
    }

    func testRefusedPackIndicesChangeNothing() async throws {
        var engine = try await makeEngine()
        XCTAssertEqual(engine.handle(control: "world.pack", values: [1]), .accepted)
        let before = try engine.digest()
        XCTAssertEqual(engine.handle(control: "world.pack", values: [3]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "world.pack", values: [-1]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "world.pack", values: [.nan]), .rejected(.nonFinite(index: 0)))
        XCTAssertEqual(engine.handle(control: "world.pack", values: [0.5]),
                       .rejected(.rule(code: WorldsRule.invalidChoice)))
        XCTAssertEqual(engine.handle(control: "world.pack", values: []), .rejected(.wrongValueCount(expected: 1,
                                                                                                   found: 0)))
        XCTAssertEqual(try engine.digest(), before)

        var core = WorldsCore(seed: 1)
        let start = core
        for value in [1.5, -1, 3, .infinity, .nan] {
            XCTAssertEqual(core.apply(ExperienceAction(control: "world.pack", values: [value], step: 0)),
                           .rejected(.rule(code: WorldsRule.invalidChoice)), "\(value)")
        }
        XCTAssertEqual(core, start)
        XCTAssertEqual(WorldsCore.refused(.underWater), .rejected(.rule(code: "a12.under-water")),
                       "a broken pack is refused with its placement code")
    }

    func testEveryActionHasAControlAndPacksAreAnsweredInWords() async throws {
        let presenter = WorldsPresenter(experienceID: WorldsTest.id)
        XCTAssertTrue(WorldsCore.actionIDs.contains("world.pack"))
        XCTAssertEqual(presenter.nativeActions, Set(WorldsCore.actionIDs))
        XCTAssertEqual(GestureAlternatives.missing(gesture: presenter.gestureActions, native: presenter.nativeActions),
                       [])
        XCTAssertEqual(WorldsCore.controls.last?.id, "world.pack")
        XCTAssertEqual(WorldsCore.controls.last?.ranges, [0...2])
        let port = TinyWorldsExperience.make(id: WorldsTest.id).port
        for name in ["pack", "open-pack", "reset-pack"] {
            XCTAssertEqual(port.identifier(name), "experience.a12.tiny-worlds.\(name)")
        }
        XCTAssertEqual(WorldPack.all.map { WorldsPresenter.packWords($0) },
                       ["Opened the island pack.", "Opened the asteroid garden pack.",
                        "Opened the miniature city pack."])
        XCTAssertEqual(WorldsPresenter.editWords("world.pack", [1], result: .accepted, before: .initial,
                                                 after: try WorldPack.asteroidGarden.state().get()),
                       "Opened the asteroid garden pack.")
        XCTAssertEqual(WorldsPresenter.editWords("world.pack", [0], result: .rejected(.rule(code: "a12.under-water")),
                                                 before: .initial, after: .initial),
                       "Not done: that point is under water.")

        // Tilt and zoom against the preset's limits: the island's pitch stops at 70° and its distance at 12 m.
        let island = CameraPolicy.limits(for: .island)
        let high = WorldView(yaw: 0, pitch: island.pitch.upperBound, distance: island.distance.lowerBound)
        XCTAssertFalse(WorldsControls.canTiltUp(high, preset: .island))
        XCTAssertFalse(WorldsControls.canZoomIn(high, preset: .island))
        XCTAssertTrue(WorldsControls.canTiltUp(high, preset: .asteroidGarden), "75° is the garden's top")
        XCTAssertTrue(WorldsControls.canZoomIn(high, preset: .miniatureCity), "10 m is the city's nearest")
        XCTAssertTrue(WorldsControls.canTiltDown(high, preset: .island))
        XCTAssertTrue(WorldsControls.canZoomOut(high, preset: .island))

        // Open pack through the presenter is shown and spoken; Reset to pack sends the current preset's index.
        let sink = RecordingAnnouncementSink()
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session, announcements: sink)
        let result = shell.presenter.send("world.pack", [1]) { shell.handle(control: $0, values: $1) }
        XCTAssertTrue(result.isAccepted)
        XCTAssertEqual(shell.presenter.mirror.message, "Opened the asteroid garden pack.")
        XCTAssertTrue(sink.announced.contains("Opened the asteroid garden pack."), "\(sink.announced)")
        try WorldsTest.frames(session, 1)
        XCTAssertEqual(shell.presenter.mirror.presetIndex, 1)
        let opened = try shell.engine.digest().hex
        XCTAssertTrue(shell.handle(control: "light.azimuth", values: [10]).isAccepted)
        let reset = shell.presenter.send("world.pack", [Double(shell.presenter.mirror.presetIndex)]) {
            shell.handle(control: $0, values: $1)
        }
        XCTAssertTrue(reset.isAccepted)
        XCTAssertEqual(try shell.engine.digest().hex, opened)
        session.close()
    }

    func testUnderReduceMotionThePackViewIsDrawnDirectly() async throws {
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session, reduceMotion: true)
        XCTAssertTrue(shell.handle(control: "world.pack", values: [2]).isAccepted)
        try WorldsTest.frames(session, 1)
        let core = try WorldsTest.core(shell)
        XCTAssertEqual(shell.presenter.lastDrawnView, core.view, "the camera moves directly")
        XCTAssertEqual(core.view, try WorldPack.miniatureCity.state().get().view)
        session.close()
    }

    func testADrawnFrameOfEachPackIsNonBlank() async throws {
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session, size: CGSize(width: 120, height: 100))
        for pack in WorldPack.all {
            XCTAssertTrue(shell.handle(control: "world.pack", values: [Double(pack.presetIndex)]).isAccepted)
            try WorldsTest.settle(session, shell)
            let frame = try WorldsTest.picture(session)
            XCTAssertTrue(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height), pack.id)
            XCTAssertFalse(FrameChecks.isBlack(frame.rgba, width: frame.width, height: frame.height), pack.id)
            XCTAssertEqual(shell.presenter.lastPropsDrawn, pack.props.count, pack.id)
            XCTAssertEqual(shell.presenter.lastPartsDrawn, pack.preset.hasSea ? 2 : 1, pack.id)
            XCTAssertEqual(shell.presenter.lastLight, pack.light, pack.id)
        }
        session.close()
    }
}
