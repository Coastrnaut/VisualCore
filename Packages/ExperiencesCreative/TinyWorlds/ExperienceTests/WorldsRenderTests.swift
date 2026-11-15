// WorldsRenderTests — feature 089 (A12-P01) T-A12-104 (FR-A12-120, FR-A12-121; clarifications 3 and 4; SC-A12-103).
// Tiny Worlds rendered inside the one app's session host on the simulator, short runs only (each test under 10 s, no
// wall-clock assertion): a drawn frame of each preset is non-blank and not black, with its background probe holding
// where one is declared; drawing never changes the state or its digest; turning the view changes the frame but not
// the terrain (no rebuild, the same terrain digest); the camera, light and background follow the file header of
// `WorldsPresenter`; the description names the world, the seed and the view in words; teardown releases every GPU
// object; and the experience's sources never create a graphics context of their own.
import Foundation
import XCTest
@testable import TinyWorldsExperience
import TinyWorldsCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

@MainActor
final class WorldsRenderTests: XCTestCase {
    private let size = CGSize(width: 120, height: 100)

    private func assertDrawn(_ shell: ExperienceShell<WorldsPresenter>,
                             _ frame: (rgba: [UInt8], width: Int, height: Int), _ name: String) {
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertTrue(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height), "\(name) not blank")
        XCTAssertFalse(FrameChecks.isBlack(frame.rgba, width: frame.width, height: frame.height), "\(name) not black")
        for probe in shell.frameProbes {
            let found = FrameChecks.probe(probe, rgba: frame.rgba, width: frame.width, height: frame.height)
            XCTAssertEqual(found?.rawValue, probe.expected, "\(name) \(probe.name)")
        }
    }

    func testADrawnFrameOfEachPresetIsNonBlank() async throws {
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session, size: size)
        for index in 0..<WorldPreset.all.count {
            XCTAssertTrue(shell.handle(control: "world.preset", values: [Double(index)]).isAccepted)
            let frame = try WorldsTest.picture(session)
            let name = WorldPreset.all[index].name
            assertDrawn(shell, frame, name)
            XCTAssertEqual(shell.presenter.lastPartsDrawn, WorldPreset.all[index].hasSea ? 2 : 1, name)
            if index != WorldPresetID.miniatureCity.rawValue {
                XCTAssertEqual(shell.frameProbes.count, 1, "\(name): the background beyond the world is probed")
            }
        }
        XCTAssertEqual(shell.frameProbes.isEmpty, true, "the miniature city's sea lies on the blue threshold")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testDrawingNeverChangesTheState() async throws {
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "world.preset", values: [1]).isAccepted)
        XCTAssertTrue(shell.handle(control: "view.orbit", values: [40, -10]).isAccepted)
        let core = try WorldsTest.core(shell)
        let digest = try shell.engine.digest()
        try WorldsTest.frames(session, 15)
        _ = shell.accessibilitySummary
        _ = shell.frameProbes
        XCTAssertEqual(try WorldsTest.core(shell), core, "the presenter reads the core only")
        XCTAssertEqual(try shell.engine.digest(), digest)

        // Drawing a core in a presenter of its own leaves the value as it was.
        let presenter = WorldsPresenter(experienceID: WorldsTest.id)
        let copy = core
        _ = presenter.describe(core)
        _ = presenter.probes(core)
        XCTAssertEqual(core, copy)
        session.close()
    }

    func testTurningTheViewChangesTheFrameAndNotTheTerrain() async throws {
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session, size: size)
        let before = try WorldsTest.picture(session)
        let terrain = try WorldsTest.core(shell).terrainDigest
        let builds = shell.presenter.rebuildCount
        XCTAssertTrue(shell.handle(control: "view.orbit", values: [90, 20]).isAccepted)
        let after = try WorldsTest.picture(session)
        assertDrawn(shell, after, "turned")
        XCTAssertNotEqual(StableHash.sha256Hex(before.rgba), StableHash.sha256Hex(after.rgba), "the frame changes")
        XCTAssertGreaterThan(WorldsTest.differingPixels(before.rgba, after.rgba), 0)
        XCTAssertEqual(try WorldsTest.core(shell).terrainDigest, terrain, "the terrain digest stays")
        XCTAssertEqual(shell.presenter.rebuildCount, builds, "the view never rebuilds the renderers")

        // The same view draws the same frame.
        let again = try WorldsTest.picture(session)
        XCTAssertEqual(StableHash.sha256Hex(after.rgba), StableHash.sha256Hex(again.rgba), "a still view holds")
        session.close()
    }

    func testTheCameraLightAndBackgroundFollowTheView() throws {
        let camera = WorldsPresenter.camera(.default)
        XCTAssertEqual(camera.target, Vec3(0, 0.3, 0))
        XCTAssertEqual(camera.distance, 18, accuracy: 1e-12)
        XCTAssertEqual(camera.yaw, 45 * Double.pi / 180, accuracy: 1e-12)
        XCTAssertEqual(camera.pitch, 35 * Double.pi / 180, accuracy: 1e-12)
        XCTAssertEqual(camera.near, 0.1)
        XCTAssertEqual(camera.far, 100)
        XCTAssertGreaterThan(camera.eye.x, 0, "the default eye is east of the centre")
        XCTAssertGreaterThan(camera.eye.z, 0, "and north of it")
        XCTAssertGreaterThan(camera.eye.y, WorldPreset.heightRange.upperBound)
        XCTAssertEqual(WorldsPresenter.lightDirection.length, 1, accuracy: 1e-12)
        XCTAssertEqual(WorldsPresenter.ambient, 0.35)

        XCTAssertEqual(WorldsPresenter.backgroundColor(.island), Vec4(0.16, 0.42, 0.62, 1))
        XCTAssertEqual(WorldsPresenter.backgroundColor(.asteroidGarden), Vec4(0.03, 0.03, 0.08, 1))
        XCTAssertEqual(WorldsPresenter.colorClass(WorldsPresenter.backgroundColor(.island)), "blue")
        XCTAssertEqual(WorldsPresenter.colorClass(WorldsPresenter.backgroundColor(.asteroidGarden)), "dark")
        XCTAssertNil(WorldsPresenter.colorClass(WorldsPresenter.backgroundColor(.miniatureCity)))
        XCTAssertEqual(WorldsPresenter.vector(RGBA(0.5, 0.4, 0.2, 0.5)), Vec4(0.25, 0.2, 0.1, 0.5), "premultiplied")

        // The default view leaves the top-left corner to the background.
        let point = try XCTUnwrap(WorldsPresenter.backgroundPoint(view: .default, size: Vec2(120, 100)))
        XCTAssertEqual(point.x, 0.04)
        XCTAssertEqual(point.y, 0.04)
        let presenter = WorldsPresenter(experienceID: WorldsTest.id)
        XCTAssertEqual(presenter.probes(WorldsCore(seed: 1)), [], "no probe before the first frame")
    }

    func testTheDescriptionNamesTheWorldSeedAndView() async throws {
        XCTAssertEqual(WorldsPresenter.description(preset: .island, seed: 1, view: .default),
                       "Tiny Worlds: Island, seed 1; view from the north-east, 35 degrees up, 18 metres away.")
        var view = WorldView.default
        XCTAssertTrue(view.orbit(yawDegrees: 135, pitchDegrees: -25))
        XCTAssertTrue(view.zoom(0.6))
        XCTAssertEqual(WorldsPresenter.description(preset: .miniatureCity, seed: 4_000_000_000, view: view),
                       "Tiny Worlds: Miniature city, seed 4000000000; view from the south, 10 degrees up, "
                       + "30 metres away.")
        XCTAssertEqual(["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"],
                       stride(from: 0.0, to: 360, by: 45).map { WorldsPresenter.compass(yawDegrees: $0) })
        XCTAssertEqual(WorldsPresenter.compass(yawDegrees: -45), "north-west")
        XCTAssertEqual(WorldsPresenter.compass(yawDegrees: -180), "south")
        XCTAssertEqual(WorldsPresenter.compass(yawDegrees: 20), "north")
        XCTAssertEqual(WorldsControls.sentence("island, seed 1"), "Island, seed 1")
        XCTAssertEqual(WorldsControls.sentence(""), "Loading")
        XCTAssertTrue(WorldsControls.canTiltUp(.default))
        XCTAssertTrue(WorldsControls.canZoomOut(.default))
        var top = WorldView.default
        top.orbit(yawDegrees: 0, pitchDegrees: 180)
        top.zoom(2)
        XCTAssertFalse(WorldsControls.canTiltUp(top))
        XCTAssertFalse(WorldsControls.canZoomIn(top))
        XCTAssertTrue(WorldsControls.canTiltDown(top))

        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session, size: size)
        XCTAssertTrue(shell.accessibilitySummary.hasPrefix("Tiny Worlds: Island, seed 1;"))
        XCTAssertTrue(shell.handle(control: "view.orbit", values: [180, 0]).isAccepted)
        XCTAssertTrue(shell.accessibilitySummary.contains("view from the south-west"), shell.accessibilitySummary)
        XCTAssertTrue(shell.handle(control: "view.reset").isAccepted)
        XCTAssertTrue(shell.accessibilitySummary.contains("view from the north-east"))
        for name in ["preset", "new-seed", "turn-left", "turn-right", "tilt-up", "tilt-down", "zoom-in", "zoom-out",
                     "reset-view", "status"] {
            XCTAssertEqual(shell.port.identifier(name), "experience.a12.tiny-worlds.\(name)")
        }
        session.close()
    }

    func testTeardownReleasesEveryGPUObject() async throws {
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "world.preset", values: [2]).isAccepted)
        try WorldsTest.frames(session, 2)
        XCTAssertEqual(shell.presenter.renderers.count, 2)
        XCTAssertNotNil(shell.presenter.renderersKey)
        session.close()
        XCTAssertFalse(shell.presenter.isLive)
        XCTAssertTrue(shell.presenter.renderers.isEmpty)
        XCTAssertNil(shell.presenter.renderersKey)
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0)
        XCTAssertEqual(shell.state, .inactive, "closed without a GPU leak")
    }

    func testTheExperienceNeverCreatesAGraphicsContextOfItsOwn() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Experience")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        XCTAssertGreaterThanOrEqual(files.count, 5)
        // Split so the repository's own source scanners do not read this list as a use.
        let forbidden = ["egl" + "CreateContext", "egl" + "GetDisplay", "egl" + "GetPlatformDisplay",
                         "EAGL" + "Context", "MTL" + "CreateSystemDefaultDevice", "RenderHost" + "(",
                         "CVisualCore" + "GL", "vc" + "gl", "AV" + "AudioEngine", "AV" + "AudioPlayer"]
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for word in forbidden {
                XCTAssertFalse(text.contains(word), "\(file.lastPathComponent) mentions \(word)")
            }
        }
    }
}
