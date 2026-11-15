// SolarBodiesRenderTests — feature 105 (A14-P03) T-A14-308 (FR-A14-301–303, FR-A14-311, FR-A14-312, FR-A14-320;
// clarifications Q1–Q4; contracts/bodies.md). The 3D bodies rendered inside the one app's session host on the
// simulator, short runs only (each test under 10 s, no wall-clock assertion): Earth focused close up shows its blue
// ocean and Jupiter its bands (the blue-to-red ratio, which lighting cannot change, varies across the disc); Saturn's
// ring is drawn beyond its disc along the ring's line through Saturn; switching the scale mode changes the pixels, the
// Scale control's value, the legend and the spoken description and announces the new description, and switching back
// draws the first frame again; markers are drawn only in the true-relative mode and only for bodies under 2 pixels;
// with Reduce Motion the drawn camera reaches a new focus on the first frame, without it on the 30th, and a new focus
// during a flight starts from the current view; a context recreation redraws the same picture within a pixel tolerance.
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
import VisualCoreUI

@MainActor
final class SolarBodiesRenderTests: XCTestCase {
    private let size = CGSize(width: 240, height: 160)

    /// Opens Solar System Explorer in `session` with `reduceMotion` and `sink`, lays the view out and draws a frame
    /// (as `SolarTest.open`, with the presenter's Reduce Motion and announcement sink chosen).
    private func open(_ session: ExperienceSession, reduceMotion: Bool = false,
                      sink: (any AnnouncementSink)? = nil) async throws -> ExperienceShell<SolarPresenter> {
        let id = SolarTest.id
        var made: ExperienceShell<SolarPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
            let shell = SolarSystemExplorerExperience.make(id: id, reduceMotion: reduceMotion, announcementSink: sink)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(origin: .zero, size: size)
            view.layoutIfNeeded()
        }
        let shell = try XCTUnwrap(made)
        try SolarTest.frames(session, 1)
        return shell
    }

    /// Draws the frames of a whole focus flight.
    private func settle(_ session: ExperienceSession) throws {
        try SolarTest.frames(session, FocusFlight.frameCount)
    }

    /// Focuses `index`, zooms in `zoom` steps and turns the camera to the body's sunlit side, `offset` 15° steps past
    /// the direction to the Sun (so the eye can stay clear of the Sun's clearance).
    private func focusSunlit(_ shell: ExperienceShell<SolarPresenter>, index: Int, zoom: Int, offset: Int = 0) {
        XCTAssertTrue(shell.handle(control: "body.select", values: [Double(index)]).isAccepted)
        for _ in 0..<zoom { XCTAssertTrue(shell.handle(control: "camera.zoom", values: [1]).isAccepted) }
        let position = OrbitLayout.scenePosition(index: index, day: 0)
        let steps = Int((atan2(-position.x, -position.z) * 180 / Double.pi / 15).rounded()) + offset
        for _ in 0..<abs(steps) {
            XCTAssertTrue(shell.handle(control: "camera.orbit", values: [steps < 0 ? -1 : 1]).isAccepted)
        }
    }

    /// The RGB of `frame` at the pixel `p` (x from the left, y from the bottom).
    private func rgb(_ frame: SolarFrame, _ p: Vec2) -> (r: Int, g: Int, b: Int)? {
        let x = Int(p.x.rounded(.down)), y = Int(p.y.rounded(.down))
        guard x >= 0, y >= 0, x < frame.width, y < frame.height else { return nil }
        let i = (y * frame.width + x) * 4
        return (Int(frame.rgba[i]), Int(frame.rgba[i + 1]), Int(frame.rgba[i + 2]))
    }

    /// The centre pixel and the pixel radius of the body at `index` through the camera of `state`.
    private func disc(_ index: Int, _ state: SolarState, _ frame: SolarFrame) -> (center: Vec2, radius: Double) {
        let canvas = Vec2(Double(frame.width), Double(frame.height))
        let center = OrbitLayout.scenePosition(index: index, day: state.dayOffset, mode: state.scaleMode)
        let radius = OrbitLayout.pixelRadius(state.scaleMode.drawnRadius(index: index), at: center, state: state,
                                             height: canvas.y)
        return (OrbitLayout.pixel(of: center, state: state, canvas: canvas), radius)
    }

    /// Every probe of `shell` holds in `frame`.
    private func assertProbesHold(_ shell: ExperienceShell<SolarPresenter>, _ frame: SolarFrame, _ name: String) {
        XCTAssertFalse(shell.frameProbes.isEmpty, "\(name): at least one probe")
        for probe in shell.frameProbes {
            let found = FrameChecks.probe(probe, rgba: frame.rgba, width: frame.width, height: frame.height)
            XCTAssertEqual(found?.rawValue, probe.expected, "\(name) \(probe.name)")
        }
    }

    func testEarthAndJupiterAreDrawnInTheirColours() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        // Earth close up from its sunlit side, 45° off the Sun's direction (looking straight sunward, the eye would come
        // within the Sun's clearance and be pushed out): blue ocean inside the disc.
        focusSunlit(shell, index: 3, zoom: 12, offset: 3)
        try settle(session)
        var frame = try SolarTest.picture(session)
        var state = try SolarTest.core(shell).state
        XCTAssertEqual(shell.presenter.lastCamera, OrbitLayout.camera(state: state), "the flight has ended")
        let earth = disc(3, state, frame)
        XCTAssertGreaterThan(earth.radius, 20, "Earth fills part of the canvas")
        var blue = 0, sampled = 0
        let reach = Int(earth.radius * 0.8)
        for dy in -reach...reach {
            for dx in -reach...reach where dx * dx + dy * dy <= reach * reach {
                guard let c = rgb(frame, Vec2(earth.center.x + Double(dx), earth.center.y + Double(dy))) else { continue }
                sampled += 1
                if SolarPresenter.classify(red: c.r, green: c.g, blue: c.b) == "blue" { blue += 1 }
            }
        }
        XCTAssertGreaterThan(sampled, 1_000)
        XCTAssertGreaterThan(blue, sampled / 20, "ocean pixels: \(blue) of \(sampled)")
        assertProbesHold(shell, frame, "Earth")

        // Jupiter close up: the blue-to-red ratio varies along the disc's vertical line (bands, not light).
        XCTAssertTrue(shell.handle(control: "view.reset", values: []).isAccepted)
        focusSunlit(shell, index: 5, zoom: 12)
        try settle(session)
        frame = try SolarTest.picture(session)
        state = try SolarTest.core(shell).state
        let jupiter = disc(5, state, frame)
        XCTAssertGreaterThan(jupiter.radius, 20)
        var lowest = Double.infinity, highest = 0.0
        let span = Int(jupiter.radius * 0.8)
        for dy in -span...span {
            guard let c = rgb(frame, Vec2(jupiter.center.x, jupiter.center.y + Double(dy))), c.r >= 40 else { continue }
            let ratio = Double(c.b) / Double(c.r)
            lowest = min(lowest, ratio)
            highest = max(highest, ratio)
        }
        XCTAssertGreaterThan(highest - lowest, 0.08, "bands: blue/red from \(lowest) to \(highest)")
        assertProbesHold(shell, frame, "Jupiter")
        session.close()
    }

    func testSaturnsRingIsVisibleAroundSaturn() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        XCTAssertTrue(shell.handle(control: "body.select", values: [6]).isAccepted)
        for _ in 0..<10 { XCTAssertTrue(shell.handle(control: "camera.zoom", values: [1]).isAccepted) }
        try settle(session)
        let frame = try SolarTest.picture(session)
        XCTAssertTrue(shell.presenter.lastSaturnRingDrawn)
        let state = try SolarTest.core(shell).state
        let saturn = disc(6, state, frame)
        let center = OrbitLayout.scenePosition(index: 6, day: 0)
        let radius = OrbitLayout.displayRadius(index: 6)
        // Points of the ring halfway between its inner edge and the Cassini division, on its line through Saturn along
        // the scene x axis (the tilt axis, so they stay in the ring plane); with yaw 0 that line is horizontal on the
        // canvas.
        let record = RingRecord.saturn
        let middle = (record.innerKm + record.cassiniInnerKm) / 2 / SceneMeshes.saturnRadiusKm * radius
        let canvas = Vec2(Double(frame.width), Double(frame.height))
        let bg = SolarPresenter.backgroundColor
        let sides: [Double] = [-1, 1]
        for side in sides {
            let point = center + Vec3(side * middle, 0, 0)
            let p = OrbitLayout.pixel(of: point, state: state, canvas: canvas)
            XCTAssertGreaterThan((p - saturn.center).length, saturn.radius + 2, "side \(side): beyond the disc")
            let c = try XCTUnwrap(rgb(frame, p))
            let differs = abs(c.r - Int(bg.x * 255)) > 16 || abs(c.g - Int(bg.y * 255)) > 16
                || abs(c.b - Int(bg.z * 255)) > 16
            XCTAssertTrue(differs, "side \(side): the ring is drawn at \(p): \(c)")
        }
        assertProbesHold(shell, frame, "Saturn")
        session.close()
    }

    func testSwitchingTheScaleModeChangesThePixelsTheControlAndTheWords() async throws {
        let session = ExperienceSession()
        let sink = RecordingAnnouncementSink()
        let shell = try await open(session, sink: sink)
        let presenter = shell.presenter
        let first = try SolarTest.picture(session)
        XCTAssertEqual(presenter.mirror.scaleMode, .enhanced)
        XCTAssertEqual(SolarControls.scaleWords(presenter.mirror.scaleMode), "Enhanced, Distances and sizes not to scale")
        XCTAssertEqual(SolarControls.legendText(presenter.mirror.scaleMode), "Distances and sizes not to scale")
        XCTAssertEqual(presenter.lastOrbitsDrawn, 8)
        XCTAssertEqual(sink.announced, [], "nothing announced before a change")

        XCTAssertTrue(shell.port.send("scale.mode", [1]).isAccepted)
        let description = shell.accessibilitySummary
        XCTAssertTrue(description.hasSuffix("Distances and sizes to one scale; small bodies marked."), description)
        XCTAssertEqual(sink.announced, [description], "the change is announced with the new description")
        XCTAssertEqual(presenter.lastAnnouncement, description)
        XCTAssertEqual(presenter.mirror.scaleMode, .trueRelative)
        XCTAssertEqual(presenter.mirror.scaleName, "True relative")
        XCTAssertEqual(SolarControls.scaleWords(presenter.mirror.scaleMode),
                       "True relative, Distances and sizes to one scale; small bodies marked")
        XCTAssertEqual(SolarControls.legendText(presenter.mirror.scaleMode),
                       "Distances and sizes to one scale; small bodies marked")
        try settle(session)
        let trueFrame = try SolarTest.picture(session)
        let state = try SolarTest.core(shell).state
        XCTAssertEqual(state.scaleMode, .trueRelative)
        XCTAssertEqual(presenter.lastScaleMode, .trueRelative)
        XCTAssertEqual(presenter.lastCamera, OrbitLayout.camera(state: state))
        XCTAssertEqual(presenter.mirror.cameraDistance, 120, accuracy: 1e-12)
        XCTAssertEqual(presenter.lastOrbitsDrawn, 8, "the true-relative orbits")
        XCTAssertNotEqual(StableHash.sha256Hex(first.rgba), StableHash.sha256Hex(trueFrame.rgba))
        XCTAssertGreaterThan(SolarTest.differingPixels(first.rgba, trueFrame.rgba), 100, "the view changes")
        assertProbesHold(shell, trueFrame, "true relative")
        XCTAssertEqual(shell.port.send("scale.mode", [0.5]).code, "action.rule.a14.invalid-choice")

        // Back to the enhanced mode: announced again, and once the flight ends the first frame again.
        XCTAssertTrue(shell.port.send("scale.mode", [0]).isAccepted)
        XCTAssertTrue(shell.accessibilitySummary.hasSuffix("Distances and sizes not to scale."))
        XCTAssertEqual(sink.announced.count, 2)
        XCTAssertEqual(presenter.announcementCount, 2)
        try settle(session)
        let back = try SolarTest.picture(session)
        XCTAssertEqual(StableHash.sha256Hex(back.rgba), StableHash.sha256Hex(first.rgba), "the first frame again")
        session.close()
    }

    func testMarkersAreDrawnOnlyInTheTrueRelativeModeForBodiesUnderTwoPixels() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        let presenter = shell.presenter
        XCTAssertEqual(presenter.lastMarkersDrawn, 0, "no marker in the enhanced mode")
        XCTAssertEqual(presenter.lastMarkedBodies, [])
        XCTAssertTrue(shell.handle(control: "scale.mode", values: [1]).isAccepted)
        XCTAssertTrue(shell.handle(control: "body.select", values: [5]).isAccepted)
        let zooms: [Int] = [0, 6, 12]
        var current = 0
        for zoom in zooms {
            while current < zoom {
                XCTAssertTrue(shell.handle(control: "camera.zoom", values: [1]).isAccepted)
                current += 1
            }
            try settle(session)
            let frame = try SolarTest.picture(session)
            let eye = try XCTUnwrap(presenter.lastEye)
            let camera = try XCTUnwrap(presenter.lastCamera)
            let height = Double(frame.height)
            let expected = OrbitLayout.markerIndices(mode: .trueRelative, day: 0, eye: eye, heightPixels: height)
            XCTAssertEqual(presenter.lastMarkedBodies, expected, "zoom \(zoom)")
            XCTAssertEqual(presenter.lastMarkersDrawn, expected.count)
            for index in 0..<SolarCore.bodyCount {
                let center = OrbitLayout.scenePosition(index: index, day: 0, mode: .trueRelative)
                let pixels = OrbitLayout.pixelRadius(ScaleMode.trueRelative.drawnRadius(index: index), at: center,
                                                     eye: eye, heightPixels: height)
                XCTAssertEqual(expected.contains(index), pixels < 2, "zoom \(zoom) body \(index): \(pixels) px")
            }
            // On this canvas every true-relative body is under 2 pixels, so all nine are marked.
            XCTAssertEqual(expected.count, 9, "zoom \(zoom)")
            // Jupiter's marker ring (6 pixels) is drawn in its colour around its centre.
            let jupiter = OrbitLayout.scenePosition(index: 5, day: 0, mode: .trueRelative)
            let p = OrbitLayout.pixel(of: jupiter, camera: camera, canvas: Vec2(Double(frame.width), height))
            XCTAssertGreaterThan(pixelsNear(SceneMeshes.markerColor(index: 5), in: frame, around: p, radius: 8), 0,
                                 "zoom \(zoom): Jupiter's marker")
            assertProbesHold(shell, frame, "markers at zoom \(zoom)")
        }
        XCTAssertTrue(shell.handle(control: "scale.mode", values: [0]).isAccepted)
        try settle(session)
        XCTAssertEqual(presenter.lastMarkersDrawn, 0, "markers go with the true-relative mode")
        XCTAssertEqual(presenter.lastMarkedBodies, [])
        session.close()
    }

    /// The number of pixels of `frame` within 24 of `color` per channel inside the square of half-size `radius`
    /// around the pixel `center`.
    private func pixelsNear(_ color: Vec4, in frame: SolarFrame, around center: Vec2, radius: Int) -> Int {
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

    func testReduceMotionCutsTheFlightAndAFlightRestartsFromTheCurrentView() async throws {
        let jupiter = OrbitLayout.scenePosition(index: 5, day: 0)
        // Reduce Motion: the new focus on the first frame.
        let still = ExperienceSession()
        let cut = try await open(still, reduceMotion: true)
        XCTAssertTrue(cut.presenter.reduceMotion)
        XCTAssertTrue(cut.handle(control: "body.select", values: [5]).isAccepted)
        try SolarTest.frames(still, 1)
        XCTAssertEqual(cut.presenter.lastCamera?.target, jupiter, "cut in one frame")
        still.close()

        // Without it: eased over 30 frames.
        let session = ExperienceSession()
        let shell = try await open(session)
        let presenter = shell.presenter
        XCTAssertTrue(shell.handle(control: "body.select", values: [5]).isAccepted)
        try SolarTest.frames(session, 1)
        let firstTarget = try XCTUnwrap(presenter.lastCamera?.target)
        XCTAssertNotEqual(firstTarget, jupiter, "frame 1 is on the way")
        XCTAssertLessThan(firstTarget.length, jupiter.length * 0.05, "frame 1 is near the start (smoothstep)")
        try SolarTest.frames(session, FocusFlight.frameCount - 2)
        XCTAssertEqual(presenter.flightFrame, FocusFlight.frameCount - 1)
        XCTAssertNotEqual(presenter.lastCamera?.target, jupiter, "frame 29 is not there yet")
        try SolarTest.frames(session, 1)
        XCTAssertEqual(presenter.lastCamera?.target, jupiter, "frame 30 reaches Jupiter")
        XCTAssertEqual(presenter.lastCamera, OrbitLayout.camera(state: try SolarTest.core(shell).state))

        // A new focus mid-flight starts from the view drawn at that moment.
        XCTAssertTrue(shell.handle(control: "body.select", values: [3]).isAccepted)
        try SolarTest.frames(session, 10)
        let midway = try XCTUnwrap(presenter.lastCamera?.target)
        XCTAssertTrue(shell.handle(control: "body.select", values: [8]).isAccepted)
        try SolarTest.frames(session, 1)
        let restarted = try XCTUnwrap(presenter.lastCamera?.target)
        let neptune = OrbitLayout.scenePosition(index: 8, day: 0)
        XCTAssertLessThan((restarted - midway).length, 0.05 * (neptune - midway).length,
                          "the restart continues from the current view")
        XCTAssertEqual(presenter.flightFrame, 1)
        try settle(session)
        XCTAssertEqual(presenter.lastCamera?.target, neptune)
        session.close()
    }

    func testAContextRecreationRedrawsWithinAPixelTolerance() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        XCTAssertTrue(shell.handle(control: "body.select", values: [6]).isAccepted)
        for _ in 0..<6 { XCTAssertTrue(shell.handle(control: "camera.zoom", values: [1]).isAccepted) }
        try settle(session)
        let before = try SolarTest.picture(session)
        let presenter = shell.presenter
        let renderers = presenter.rendererBuildCount
        let meshes = presenter.meshBuildCount
        session.recreateContext()
        XCTAssertEqual(session.state, .running)
        try SolarTest.frames(session, 1)
        let after = try SolarTest.picture(session)
        XCTAssertEqual(presenter.rendererBuildCount, renderers + 1, "the renderers are made once on the new context")
        XCTAssertEqual(presenter.meshBuildCount, meshes, "surfaces and rings are CPU data and survive")
        XCTAssertEqual(before.width, after.width)
        let differing = SolarTest.differingPixels(before.rgba, after.rgba)
        XCTAssertLessThanOrEqual(differing, before.width * before.height / 100, "within 1 % of the pixels")
        assertProbesHold(shell, after, "after recreation")
        session.close()
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0)
    }
}
