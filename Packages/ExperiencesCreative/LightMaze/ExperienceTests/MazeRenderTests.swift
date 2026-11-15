// MazeRenderTests — feature 096 (A13-P01) T-A13-104 (FR-A13-120, FR-A13-121; clarification Q5; research D5;
// SC-A13-105). Light Maze rendered inside the one app's session host on the simulator, short runs only (each test under
// 10 s, no wall-clock assertion): a drawn frame of levels 1, 16 and 20 is non-blank and not black, with its background
// and target probes holding; turning lm-01's mirror changes the drawn pixels where the beam ran and where it now runs;
// solving level 1 shows the lit target colour; drawing never changes the state or its digest; the camera fits the
// board and the scene tree holds what research D5 lists; the words of the controls; teardown releases every GPU
// object; and the experience's sources never create a graphics context of their own.
// Feature 097 (A13-P02) T-A13-205 (FR-A13-210; SC-A13-204): along the beam the core is brighter than its halo and the
// halo brighter than the board.
import Foundation
import XCTest
@testable import LightMazeExperience
import LightMazeCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreSimulation

@MainActor
final class MazeRenderTests: XCTestCase {
    private let size = CGSize(width: 120, height: 100)

    private func assertDrawn(_ shell: ExperienceShell<MazePresenter>, _ frame: MazeFrame, _ name: String) {
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertTrue(FrameChecks.isNonBlank(frame.rgba, width: frame.width, height: frame.height), "\(name) not blank")
        XCTAssertFalse(FrameChecks.isBlack(frame.rgba, width: frame.width, height: frame.height), "\(name) not black")
        let probes = shell.frameProbes
        XCTAssertGreaterThanOrEqual(probes.count, 2, "\(name): the background and at least one target")
        for probe in probes {
            let found = FrameChecks.probe(probe, rgba: frame.rgba, width: frame.width, height: frame.height)
            XCTAssertEqual(found?.rawValue, probe.expected, "\(name) \(probe.name)")
        }
    }

    func testADrawnFrameOfLevelsOneSixteenAndTwentyIsNonBlank() async throws {
        let session = ExperienceSession()
        let shell = try await MazeTest.open(session, size: size)
        let levels: [Int] = [0, 15, 19]
        for level in levels {
            XCTAssertTrue(shell.handle(control: "level.select", values: [Double(level)]).isAccepted)
            let frame = try MazeTest.picture(session)
            let name = "level \(level + 1)"
            assertDrawn(shell, frame, name)
            let core = try MazeTest.core(shell)
            XCTAssertEqual(shell.presenter.lastSegmentsDrawn, core.beam.segments.count, name)
            XCTAssertEqual(shell.frameProbes.count, 1 + core.board.targetCells.count, name)
        }
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testTurningTheFirstMirrorChangesTheBeamPixels() async throws {
        let session = ExperienceSession()
        let shell = try await MazeTest.open(session, size: size)
        let before = try MazeTest.picture(session)
        let board = try MazeTest.core(shell).board
        let canvas = Vec2(Double(before.width), Double(before.height))
        // lm-01: the beam turns south at the mirror (2, 2) toward the wall; turned, it runs north to the target.
        let southOfMirror = MazePresenter.pixel(of: Vec2(2.5, 1.5), board: board, canvas: canvas)
        let northOfMirror = MazePresenter.pixel(of: Vec2(2.5, 3.5), board: board, canvas: canvas)
        XCTAssertTrue(shell.handle(control: "tile.select", values: [0]).isAccepted)
        XCTAssertTrue(shell.handle(control: "tile.turn").isAccepted)
        let after = try MazeTest.picture(session)
        assertDrawn(shell, after, "turned")
        XCTAssertNotEqual(StableHash.sha256Hex(before.rgba), StableHash.sha256Hex(after.rgba), "the frame changes")
        XCTAssertGreaterThan(MazeTest.differingPixels(before, after, around: northOfMirror, radius: 1), 0,
                             "the beam now runs north of the mirror")
        XCTAssertGreaterThan(MazeTest.differingPixels(before, after, around: southOfMirror, radius: 1), 0,
                             "the beam no longer runs south of the mirror")
        XCTAssertGreaterThan(MazeTest.pixels(near: MazePresenter.beamColor, in: after), 0, "the beam is drawn")

        // The same state draws the same frame once the solved border has settled (feature 099: the border brightens
        // once over 0.6 s of frame time; 40 frames of 1/60 s pass it).
        try MazeTest.frames(session, 40)
        let settled = try MazeTest.picture(session)
        let again = try MazeTest.picture(session)
        XCTAssertEqual(StableHash.sha256Hex(settled.rgba), StableHash.sha256Hex(again.rgba), "a still state holds")
        session.close()
    }

    func testSolvingLevelOneShowsTheLitTargetColour() async throws {
        let session = ExperienceSession()
        let shell = try await MazeTest.open(session, size: size)
        let unlit = try MazeTest.picture(session)
        XCTAssertEqual(MazeTest.pixels(near: MazePresenter.litTargetColor, in: unlit), 0, "no lit target yet")
        XCTAssertGreaterThan(MazeTest.pixels(near: MazePresenter.targetColor, in: unlit), 0, "the unlit target")
        XCTAssertTrue(shell.handle(control: "tile.select", values: [0]).isAccepted)
        XCTAssertTrue(shell.handle(control: "tile.turn").isAccepted)
        XCTAssertTrue(try MazeTest.core(shell).isSolved)
        let lit = try MazeTest.picture(session)
        XCTAssertGreaterThan(MazeTest.pixels(near: MazePresenter.litTargetColor, in: lit), 0, "the lit target colour")
        XCTAssertGreaterThan(MazeTest.pixels(near: MazePresenter.ringColor, in: lit), 0, "its ring")
        let probe = try XCTUnwrap(shell.frameProbes.first { $0.name == "target-2-4" })
        XCTAssertEqual(probe.expected, "green")
        XCTAssertEqual(FrameChecks.probe(probe, rgba: lit.rgba, width: lit.width, height: lit.height)?.rawValue,
                       "green")
        session.close()
    }

    /// The luminance (0…255) of the brightest pixel of `frame` within one pixel of the pixel `at` (x from the left, y
    /// from the bottom).
    private func luminance(_ frame: MazeFrame, at point: Vec2) -> Double {
        let cx = Int(point.x.rounded(.down)), cy = Int(point.y.rounded(.down))
        var best = 0.0
        for y in (cy - 1)...(cy + 1) where y >= 0 && y < frame.height {
            for x in (cx - 1)...(cx + 1) where x >= 0 && x < frame.width {
                let i = (y * frame.width + x) * 4
                let value = 0.2126 * Double(frame.rgba[i]) + 0.7152 * Double(frame.rgba[i + 1])
                    + 0.0722 * Double(frame.rgba[i + 2])
                best = max(best, value)
            }
        }
        return best
    }

    func testTheBeamPathIsBrighterThanTheBoard() async throws {
        let session = ExperienceSession()
        let shell = try await MazeTest.open(session, size: CGSize(width: 240, height: 200))
        let frame = try MazeTest.picture(session)
        let core = try MazeTest.core(shell)
        let board = core.board
        let canvas = Vec2(Double(frame.width), Double(frame.height))
        // lm-01: the beam runs east from the emitter (0, 2) to the mirror (2, 2), then south to the wall (2, 0).
        let empty = luminance(frame, at: MazePresenter.pixel(of: Vec2(1.5, 3.5), board: board, canvas: canvas))
        XCTAssertGreaterThan(core.beam.segments.count, 1)
        for (index, segment) in core.beam.segments.enumerated() {
            let middle = (segment.start + segment.end) / 2
            let bright = luminance(frame, at: MazePresenter.pixel(of: middle, board: board, canvas: canvas))
            XCTAssertGreaterThan(bright, empty + 40, "segment \(index): the beam's core outshines the board")
        }
        // Beside the first segment, 0.11 cell off its line: inside the halo (0.15) and outside the core (0.04).
        let first = try XCTUnwrap(core.beam.segments.first)
        let middle = (first.start + first.end) / 2
        let halo = luminance(frame, at: MazePresenter.pixel(of: middle + Vec2(0, 0.11), board: board, canvas: canvas))
        let line = luminance(frame, at: MazePresenter.pixel(of: middle, board: board, canvas: canvas))
        let outside = luminance(frame, at: MazePresenter.pixel(of: middle + Vec2(0, 0.3), board: board, canvas: canvas))
        XCTAssertGreaterThan(halo, outside + 8, "the halo brightens the board beside the beam")
        XCTAssertGreaterThan(line, halo + 20, "the core stays brighter than its halo, so the path stays legible")
        XCTAssertEqual(outside, empty, accuracy: 6, "beyond the glow the board is untouched")
        session.close()
    }

    func testDrawingNeverChangesTheState() async throws {
        let session = ExperienceSession()
        let shell = try await MazeTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "level.select", values: [19]).isAccepted)
        XCTAssertTrue(shell.handle(control: "tile.select", values: [1]).isAccepted)
        let core = try MazeTest.core(shell)
        let digest = try shell.engine.digest()
        try MazeTest.frames(session, 15)
        _ = shell.accessibilitySummary
        _ = shell.frameProbes
        XCTAssertEqual(try MazeTest.core(shell), core, "the presenter reads the core only")
        XCTAssertEqual(try shell.engine.digest(), digest)

        // Describing and building the scene of a core in a presenter of its own leaves the value as it was.
        let presenter = MazePresenter(experienceID: MazeTest.id)
        let copy = core
        _ = presenter.describe(core)
        _ = presenter.probes(core)
        _ = MazePresenter.scene(core)
        XCTAssertEqual(core, copy)
        XCTAssertEqual(presenter.probes(core), [], "no probe before the first frame")
        session.close()
    }

    func testTheCameraFitsTheBoardAndTheSceneHoldsItsParts() throws {
        let five = MazeState.initial.board
        let camera = MazePresenter.camera(board: five, canvas: Vec2(120, 100))
        XCTAssertEqual(camera.center, Vec2(25, 25))
        XCTAssertEqual(camera.zoom, 100.0 / 60.0, accuracy: 1e-12, "five cells and two half-cell margins")
        let centre = MazePresenter.pixel(of: Vec2(2.5, 2.5), board: five, canvas: Vec2(120, 100))
        XCTAssertEqual(centre.x, 60, accuracy: 1e-9)
        XCTAssertEqual(centre.y, 50, accuracy: 1e-9)
        let corner = MazePresenter.pixel(of: Vec2(0, 0), board: five, canvas: Vec2(120, 100))
        XCTAssertEqual(corner.y, 100.0 / 60.0 * 5, accuracy: 1e-9, "half a cell of margin below the board")
        XCTAssertGreaterThan(corner.x, 0.02 * 120, "the background probe stays outside the board")
        let big = Board(width: 12, height: 12, tiles: [])
        XCTAssertEqual(MazePresenter.camera(board: big, canvas: Vec2(13, 13)).zoom, 0.1, accuracy: 1e-12)
        XCTAssertEqual(MazePresenter.camera(board: Board(width: 4, height: 4, tiles: []),
                                            canvas: Vec2(3000, 3000)).zoom, 60, accuracy: 1e-9)

        // lm-01: the board, 8 grid lines, 4 tiles and the beam; a selection outline once selected; a ring once lit.
        var core = MazeCore(seed: 1)
        var root = MazePresenter.scene(core)
        XCTAssertEqual(root.scale, Vec2(MazePresenter.unit, MazePresenter.unit))
        var ids: [String] = root.children.map(\.id)
        XCTAssertEqual(ids.count, 1 + 8 + 4 + 2 * core.beam.segments.count, "a halo and a core per segment")
        XCTAssertTrue(ids.contains("board"))
        XCTAssertTrue(ids.contains("tile0.wall") && ids.contains("tile1.emitter") && ids.contains("tile2.mirror")
                      && ids.contains("tile3.target"))
        XCTAssertFalse(ids.contains("selection"))
        let beam = try XCTUnwrap(root.children.first { $0.id == "beam0" })
        let first = try XCTUnwrap(core.beam.segments.first)
        XCTAssertEqual(beam.primitive, .line(first.start, first.end, width: MazePresenter.beamWidth))
        XCTAssertEqual(beam.color, MazePresenter.beamColor)
        let target = try XCTUnwrap(root.children.first { $0.id == "tile3.target" })
        XCTAssertEqual(target.color, MazePresenter.targetColor)
        let emitter = try XCTUnwrap(root.children.first { $0.id == "tile1.emitter" })
        if case .polygon(let points) = emitter.primitive {
            XCTAssertEqual(points.count, 3)
            XCTAssertEqual(points[0].x, 0.88, accuracy: 1e-12, "the tip points east")
        } else {
            XCTFail("the emitter is a triangle")
        }

        _ = core.apply(ExperienceAction(control: "tile.select", values: [0], step: 0))
        _ = core.apply(ExperienceAction(control: "tile.turn", values: [], step: 0))
        root = MazePresenter.scene(core)
        ids = root.children.map(\.id)
        XCTAssertTrue(ids.contains("selection"))
        XCTAssertTrue(ids.contains("tile3.ring"))
        XCTAssertEqual(try XCTUnwrap(root.children.first { $0.id == "tile3.target" }).color,
                       MazePresenter.litTargetColor)
        let mirror = try XCTUnwrap(root.children.first { $0.id == "tile2.mirror" })
        XCTAssertEqual(mirror.primitive, .line(Vec2(2, 2), Vec2(3, 3), width: MazePresenter.mirrorWidth),
                       "the turned mirror lies on the slash diagonal")

        // A level with a prism draws its core line.
        let sixteen = try mazeCore(MazeState(levelIndex: 15))
        XCTAssertTrue(MazePresenter.scene(sixteen).children.contains { $0.id.hasSuffix(".prism.core") })
    }

    func testTheWordsOfTheControls() async throws {
        var state = MazeState.initial
        XCTAssertEqual(MazePresenter.selectedWords(state), "No tile selected")
        XCTAssertTrue(state.selectTile(0))
        XCTAssertEqual(MazePresenter.selectedWords(state), "Mirror 1 of 1, leaning left, column 3, row 3")
        XCTAssertTrue(state.turnSelected())
        XCTAssertEqual(MazePresenter.selectedWords(state), "Mirror 1 of 1, leaning right, column 3, row 3")
        XCTAssertEqual(MazePresenter.answerWords(control: "tile.turn", result: .accepted), "")
        let refused = ActionResult.rejected(.rule(code: MazeRule.invalidChoice))
        XCTAssertEqual(MazePresenter.answerWords(control: "level.next", result: refused), "This is the last level.")
        XCTAssertEqual(MazePresenter.answerWords(control: "level.previous", result: refused),
                       "This is the first level.")
        XCTAssertEqual(MazePresenter.answerWords(control: "tile.turn", result: refused),
                       "Select a mirror or prism first.")
        XCTAssertEqual(MazeControls.nextTile(selection: -1, count: 3), 0)
        XCTAssertEqual(MazeControls.nextTile(selection: 2, count: 3), 0)
        XCTAssertEqual(MazeControls.previousTile(selection: -1, count: 3), 2)
        XCTAssertEqual(MazeControls.previousTile(selection: 0, count: 3), 2)
        XCTAssertNil(MazeControls.nextTile(selection: -1, count: 0))
        XCTAssertEqual(MazeControls.levelWords(index: 0, count: 20), "Level 1 of 20")
        XCTAssertEqual(MazeControls.sentence("level 1, First light"), "Level 1, First light")
        XCTAssertEqual(MazeControls.sentence(""), "Loading")

        let session = ExperienceSession()
        let shell = try await MazeTest.open(session, size: size)
        let names: [String] = ["previous-level", "next-level", "select-previous", "select-next", "turn",
                               "reset-level", "undo", "status", "message"]
        for name in names {
            XCTAssertEqual(shell.port.identifier(name), "experience.a13.light-maze.\(name)")
        }
        XCTAssertEqual(shell.port.send("level.previous").code, "action.rule.a13.invalid-choice")
        XCTAssertTrue(shell.port.send("level.next").isAccepted)
        XCTAssertTrue(shell.accessibilitySummary.hasPrefix("Light Maze: level 2,"), shell.accessibilitySummary)
        session.close()
    }

    func testTeardownReleasesEveryGPUObject() async throws {
        let session = ExperienceSession()
        let shell = try await MazeTest.open(session, size: size)
        XCTAssertTrue(shell.handle(control: "level.select", values: [19]).isAccepted)
        try MazeTest.frames(session, 2)
        XCTAssertNotNil(shell.presenter.primitives)
        XCTAssertNotNil(shell.presenter.root, "the scene tree")
        session.close()
        XCTAssertFalse(shell.presenter.isLive)
        XCTAssertNil(shell.presenter.primitives)
        XCTAssertEqual(shell.presenter.lastSegmentsDrawn, 0)
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
