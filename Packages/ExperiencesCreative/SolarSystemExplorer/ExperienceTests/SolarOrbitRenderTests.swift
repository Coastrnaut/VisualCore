// SolarOrbitRenderTests — feature 104 (A14-P02) T-A14-207 (FR-A14-220, FR-A14-221; research D4; SC-A14-204). The
// orbit view rendered inside the one app's session host on the simulator, short runs only (each test under 10 s, no
// wall-clock assertion): a frame of the overview is non-blank with nine bodies, eight orbit lines and the ring; a
// date step of +365 days changes the drawn pixels where Jupiter was; focusing a body moves the camera onto it; the
// camera actions change the view and Reset view brings the first frame back; every listed probe holds across camera
// states; and nothing is released or remade mid-session (all 37 renderers of feature 105 are the same objects
// throughout). A change of focus starts a 30-frame focus flight (A14-P03 FR-A14-320), so a test that judges the focused
// view draws the flight's frames first; probes are always judged against the camera actually drawn.
import Foundation
import XCTest
@testable import SolarSystemExplorerExperience
import SolarSystemExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

@MainActor
final class SolarOrbitRenderTests: XCTestCase {
    private let size = CGSize(width: 240, height: 160)

    /// Draws the frames of a whole focus flight, so the drawn camera reaches the state's view.
    private func settle(_ session: ExperienceSession) throws {
        try SolarTest.frames(session, FocusFlight.frameCount)
    }

    /// Every probe of `shell` holds in `frame`.
    private func assertProbesHold(_ shell: ExperienceShell<SolarPresenter>, _ frame: SolarFrame, _ name: String) {
        for probe in shell.frameProbes {
            let found = FrameChecks.probe(probe, rgba: frame.rgba, width: frame.width, height: frame.height)
            XCTAssertEqual(found?.rawValue, probe.expected, "\(name) \(probe.name)")
        }
    }

    /// The RGB of `frame` at the pixel `p` (x from the left, y from the bottom).
    private func rgb(_ frame: SolarFrame, _ p: Vec2) -> (r: Int, g: Int, b: Int)? {
        let x = Int(p.x.rounded(.down)), y = Int(p.y.rounded(.down))
        guard x >= 0, y >= 0, x < frame.width, y < frame.height else { return nil }
        let i = (y * frame.width + x) * 4
        return (Int(frame.rgba[i]), Int(frame.rgba[i + 1]), Int(frame.rgba[i + 2]))
    }

    /// The number of pixels of `frame` within 24 of `color` per channel inside the square of half-size `radius`
    /// around the pixel `center`.
    private func pixels(near color: Vec4, in frame: SolarFrame, around center: Vec2, radius: Int) -> Int {
        let r = Int((color.x * 255).rounded()), g = Int((color.y * 255).rounded()), b = Int((color.z * 255).rounded())
        let cx = Int(center.x.rounded(.down)), cy = Int(center.y.rounded(.down))
        var count = 0
        for y in (cy - radius)...(cy + radius) where y >= 0 && y < frame.height {
            for x in (cx - radius)...(cx + radius) where x >= 0 && x < frame.width {
                let i = (y * frame.width + x) * 4
                if abs(Int(frame.rgba[i]) - r) <= 24 && abs(Int(frame.rgba[i + 1]) - g) <= 24
                    && abs(Int(frame.rgba[i + 2]) - b) <= 24 { count += 1 }
            }
        }
        return count
    }

    /// The identities of every renderer of `presenter`.
    private func rendererIDs(_ presenter: SolarPresenter) -> [ObjectIdentifier] {
        var ids: [ObjectIdentifier] = []
        for renderer in presenter.bodyRenderers { ids.append(ObjectIdentifier(renderer)) }
        for renderer in presenter.ringRenderers { ids.append(ObjectIdentifier(renderer)) }
        for renderer in presenter.orbitRenderers { ids.append(ObjectIdentifier(renderer)) }
        for renderer in presenter.trueOrbitRenderers { ids.append(ObjectIdentifier(renderer)) }
        if let renderer = presenter.saturnRingRenderer { ids.append(ObjectIdentifier(renderer)) }
        if let renderer = presenter.starRenderer { ids.append(ObjectIdentifier(renderer)) }
        if let renderer = presenter.markerRenderer { ids.append(ObjectIdentifier(renderer)) }
        return ids
    }

    func testTheOverviewIsNonBlankWithBodiesOrbitsAndTheRing() async throws {
        let session = ExperienceSession()
        let shell = try await SolarTest.open(session, size: size)
        let frame = try SolarTest.picture(session)
        XCTAssertTrue(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height))
        XCTAssertFalse(FrameChecks.isBlack(frame.rgba, width: frame.width, height: frame.height))
        let presenter = shell.presenter
        XCTAssertEqual(presenter.lastBodiesDrawn, 9)
        XCTAssertEqual(presenter.lastOrbitsDrawn, 8)
        XCTAssertTrue(presenter.lastRingDrawn)
        XCTAssertEqual(presenter.lastDayOffset, 0)
        XCTAssertEqual(presenter.lastCamera, OrbitLayout.camera(state: .initial))
        XCTAssertEqual(presenter.orbitMeshes.count, 8)
        XCTAssertGreaterThan(SolarTest.pixels(near: SolarPresenter.orbitColor, in: frame), 0, "orbit lines drawn")
        XCTAssertGreaterThan(SolarTest.pixels(near: SolarPresenter.ringColor, in: frame), 0, "the ring is drawn")
        let names = shell.frameProbes.map(\.name)
        XCTAssertEqual(names, ["background", "body-0"], "the background and the Sun's centre")
        assertProbesHold(shell, frame, "overview")
        XCTAssertEqual(shell.accessibilitySummary, SolarCore.canvasDescription(selection: 0, dayOffset: 0))
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testADateStepOf365DaysChangesTheDrawnPixels() async throws {
        let session = ExperienceSession()
        let shell = try await SolarTest.open(session, size: size)
        let before = try SolarTest.picture(session)
        let canvas = Vec2(Double(before.width), Double(before.height))
        let jupiter = OrbitLayout.scenePosition(index: 5, day: 0)
        let moved = OrbitLayout.scenePosition(index: 5, day: 365)
        XCTAssertGreaterThan((moved - jupiter).length, 3, "Jupiter moves about 30° in a year")
        let was = OrbitLayout.pixel(of: jupiter, state: .initial, canvas: canvas)
        XCTAssertTrue(shell.handle(control: "date.step", values: [365]).isAccepted)
        let after = try SolarTest.picture(session)
        XCTAssertEqual(shell.presenter.lastDayOffset, 365)
        XCTAssertEqual(shell.presenter.mirror.dateLabel, "2000-12-31")
        XCTAssertNotEqual(StableHash.sha256Hex(before.rgba), StableHash.sha256Hex(after.rgba), "the frame changes")
        XCTAssertGreaterThan(SolarTest.differingPixels(before.rgba, after.rgba), 10, "the planets moved")
        XCTAssertGreaterThan(SolarTest.differingPixels(before, after, around: was, radius: 1), 0, "Jupiter left")
        assertProbesHold(shell, after, "day 365")

        // Back by a year: the first frame again.
        XCTAssertTrue(shell.handle(control: "date.step", values: [-365]).isAccepted)
        let back = try SolarTest.picture(session)
        XCTAssertEqual(StableHash.sha256Hex(before.rgba), StableHash.sha256Hex(back.rgba), "forward then back")
        session.close()
    }

    func testFocusingABodyMovesTheCameraOntoIt() async throws {
        let session = ExperienceSession()
        let shell = try await SolarTest.open(session, size: size)
        let before = try SolarTest.picture(session)
        XCTAssertTrue(shell.handle(control: "body.select", values: [5]).isAccepted)
        try settle(session)
        let after = try SolarTest.picture(session)
        let camera = try XCTUnwrap(shell.presenter.lastCamera)
        XCTAssertEqual(camera.target, OrbitLayout.scenePosition(index: 5, day: 0), "the camera looks at Jupiter")
        XCTAssertNotEqual(StableHash.sha256Hex(before.rgba), StableHash.sha256Hex(after.rgba), "the view changes")
        // Jupiter now fills the middle of the canvas: its centre differs from the background colour.
        let middle = try XCTUnwrap(rgb(after, Vec2(Double(after.width) / 2, Double(after.height) / 2)))
        let bg = SolarPresenter.backgroundColor
        let differs = abs(middle.r - Int(bg.x * 255)) > 16 || abs(middle.g - Int(bg.y * 255)) > 16
            || abs(middle.b - Int(bg.z * 255)) > 16
        XCTAssertTrue(differs, "Jupiter at the centre: \(middle)")
        // The ring surrounds Jupiter: its top point (in the ring's own plane) is drawn in the ring colour.
        let ring = SolarPresenter.ringRadius(displayRadius: OrbitLayout.displayRadius(index: 5))
        let top = OrbitLayout.ringModel(center: camera.target, camera: camera).applyPoint(Vec3(0, ring, 0))
        let canvas = Vec2(Double(after.width), Double(after.height))
        let p = OrbitLayout.pixel(of: top, state: try SolarTest.core(shell).state, canvas: canvas)
        XCTAssertGreaterThan(pixels(near: SolarPresenter.ringColor, in: after, around: p, radius: 3), 0, "ring top")
        XCTAssertTrue(shell.presenter.mirror.distance.hasSuffix(" km)"), shell.presenter.mirror.distance)
        assertProbesHold(shell, after, "Jupiter")
        session.close()
    }

    func testTheCameraActionsChangeTheViewAndResetRestoresIt() async throws {
        let session = ExperienceSession()
        let shell = try await SolarTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "body.select", values: [3]).isAccepted)
        try settle(session)
        let first = try SolarTest.picture(session)
        var previous = StableHash.sha256Hex(first.rgba)
        let actions: [(control: String, value: Double)] = [("camera.orbit", 1), ("camera.tilt", 1),
                                                           ("camera.zoom", 1), ("camera.orbit", -1),
                                                           ("camera.tilt", -1), ("camera.zoom", -1)]
        for action in actions {
            XCTAssertTrue(shell.handle(control: action.control, values: [action.value]).isAccepted, action.control)
            let frame = try SolarTest.picture(session)
            let hash = StableHash.sha256Hex(frame.rgba)
            XCTAssertNotEqual(hash, previous, "\(action.control) \(action.value) changes the view")
            previous = hash
            let state = try SolarTest.core(shell).state
            XCTAssertEqual(shell.presenter.lastCamera, OrbitLayout.camera(state: state))
            XCTAssertEqual(shell.presenter.mirror.pitchDegrees, state.pitchDegrees)
            XCTAssertEqual(shell.presenter.mirror.zoomSteps, state.zoomSteps)
            XCTAssertEqual(shell.presenter.mirror.yawDegrees, state.yawDegrees)
            assertProbesHold(shell, frame, "\(action.control) \(action.value)")
        }
        XCTAssertTrue(shell.handle(control: "camera.orbit", values: [1]).isAccepted)
        XCTAssertTrue(shell.handle(control: "camera.zoom", values: [1]).isAccepted)
        XCTAssertNotEqual(StableHash.sha256Hex(try SolarTest.picture(session).rgba), StableHash.sha256Hex(first.rgba))
        XCTAssertTrue(shell.handle(control: "view.reset", values: []).isAccepted)
        let reset = try SolarTest.picture(session)
        XCTAssertEqual(StableHash.sha256Hex(reset.rgba), StableHash.sha256Hex(first.rgba), "Reset view")
        session.close()
    }

    func testEveryListedProbeHoldsAcrossCameraStates() async throws {
        let session = ExperienceSession()
        let shell = try await SolarTest.open(session, size: size)
        // Neptune close up, the camera turned to its sunlit side: its centre probe is robust blue.
        XCTAssertTrue(shell.handle(control: "body.select", values: [8]).isAccepted)
        for _ in 0..<8 { XCTAssertTrue(shell.handle(control: "camera.zoom", values: [1]).isAccepted) }
        let neptune = OrbitLayout.scenePosition(index: 8, day: 0)
        let sunward = atan2(-neptune.x, -neptune.z) * 180 / Double.pi
        let steps = Int((sunward / 15).rounded())
        for _ in 0..<abs(steps) {
            XCTAssertTrue(shell.handle(control: "camera.orbit", values: [steps < 0 ? -1 : 1]).isAccepted)
        }
        try settle(session)
        var frame = try SolarTest.picture(session)
        let probe = try XCTUnwrap(shell.frameProbes.first { $0.name == "body-8" }, "Neptune is large and lit")
        XCTAssertEqual(probe.expected, "blue")
        assertProbesHold(shell, frame, "Neptune sunlit")

        // Other states: whatever is listed holds.
        let moves: [(control: String, value: Double)] = [("camera.tilt", 1), ("camera.tilt", 1), ("camera.tilt", 1),
                                                         ("camera.tilt", 1), ("body.select", 0), ("view.reset", 0),
                                                         ("body.select", 4), ("date.step", 30), ("camera.zoom", -1)]
        for move in moves {
            let values: [Double] = move.control == "view.reset" ? [] : [move.value]
            XCTAssertTrue(shell.handle(control: move.control, values: values).isAccepted, move.control)
            frame = try SolarTest.picture(session)
            assertProbesHold(shell, frame, "\(move.control) \(move.value)")
        }
        session.close()
    }

    func testNothingIsReleasedOrRemadeMidSession() async throws {
        let session = ExperienceSession()
        let shell = try await SolarTest.open(session, size: size)
        let presenter = shell.presenter
        XCTAssertEqual(presenter.bodyRenderers.count, 9)
        XCTAssertEqual(presenter.ringRenderers.count, 9)
        XCTAssertEqual(presenter.orbitRenderers.count, 8)
        XCTAssertEqual(presenter.trueOrbitRenderers.count, 8)
        let ids = rendererIDs(presenter)
        XCTAssertEqual(ids.count, 37, "9 bodies, 9 rings, 2 × 8 orbits, Saturn's ring, the stars and the marker")
        let builds = presenter.rendererBuildCount
        let rings = presenter.ringBuildCount
        let meshes = presenter.meshBuildCount
        let moves: [(control: String, values: [Double])] = [("date.step", [365]), ("body.select", [3]),
                                                            ("camera.orbit", [1]), ("camera.tilt", [-1]),
                                                            ("camera.zoom", [1]), ("body.next", []),
                                                            ("date.step", [-30]), ("view.reset", []),
                                                            ("scale.mode", [1]), ("body.select", [8]),
                                                            ("scale.mode", [0])]
        for move in moves {
            XCTAssertTrue(shell.handle(control: move.control, values: move.values).isAccepted, move.control)
            try SolarTest.frames(session, 1)
            XCTAssertEqual(rendererIDs(presenter), ids, "\(move.control): the same renderers")
        }
        XCTAssertEqual(presenter.rendererBuildCount, builds, "the renderers are made once")
        XCTAssertEqual(presenter.ringBuildCount, rings)
        XCTAssertEqual(presenter.meshBuildCount, meshes)
        XCTAssertEqual(builds, 1)
        XCTAssertEqual(meshes, 1)
        session.close()
        XCTAssertTrue(presenter.bodyRenderers.isEmpty)
        XCTAssertTrue(presenter.ringRenderers.isEmpty)
        XCTAssertTrue(presenter.orbitRenderers.isEmpty, "released together in teardown")
        XCTAssertTrue(presenter.trueOrbitRenderers.isEmpty, "released together in teardown")
        XCTAssertNil(presenter.saturnRingRenderer)
        XCTAssertNil(presenter.starRenderer)
        XCTAssertNil(presenter.markerRenderer)
        XCTAssertEqual(presenter.lastOrbitsDrawn, 0)
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0)
    }
}
