// MazeGlowTests — feature 097 (A13-P02) T-A13-205 (FR-A13-210–212; SC-A13-204; clarifications Q4–Q5; research D2,
// D2b). The beam's glow, the target rings, the selection outline and the spoken beam changes, host-only (scene trees
// and the announcement clock with synthetic frame times; no GPU), each test well under a second: every core beam line
// lies on a tracer segment and its halo under it on the same segment, never reaching more than 0.15 cell from it, at
// opacity 0.25; lit targets carry a ring and unlit ones none; the selected tile carries an outline inset 0.04 in its
// cell; a beam change is spoken at once, the next no sooner than one second of frame time later (the latest text wins),
// an unchanged beam never, and nothing reaches the sink while VoiceOver is off.
import Foundation
import XCTest
@testable import LightMazeExperience
import LightMazeCore
import VisualCoreExperience
import VisualCoreMath
import VisualCoreScenes
import VisualCoreUI

@MainActor
final class MazeGlowTests: XCTestCase {
    /// A core of level `level` in its starting orientations (or its recorded solution when `solved`), with turnable
    /// tile `select` selected when given.
    private func core(level: Int, solved: Bool = false, select: Int? = nil) throws -> MazeCore {
        var core = try mazeCore(MazeState(levelIndex: level))
        if solved {
            let solution = core.level.solution
            for position in 0..<solution.count where core.state.orientations[position] != solution[position] {
                XCTAssertTrue(core.apply(ExperienceAction(control: "tile.select", values: [Double(position)],
                                                          step: 0)).isAccepted)
                XCTAssertTrue(core.apply(ExperienceAction(control: "tile.turn", values: [], step: 0)).isAccepted)
            }
            XCTAssertTrue(core.isSolved, "level \(level + 1) solved")
        }
        if let select {
            XCTAssertTrue(core.apply(ExperienceAction(control: "tile.select", values: [Double(select)],
                                                      step: 0)).isAccepted)
        }
        return core
    }

    /// The node of `root` with the id `id`.
    private func node(_ root: SceneNode, _ id: String) -> SceneNode? {
        root.children.first { $0.id == id }
    }

    func testEveryCoreBeamLineLiesOnATracerSegmentWithACappedHaloUnderIt() throws {
        XCTAssertEqual(MazePresenter.haloWidth, 0.30)
        XCTAssertEqual(MazePresenter.haloOpacity, 0.25)
        XCTAssertEqual(MazePresenter.beamWidth, 0.08)
        XCTAssertLessThanOrEqual(MazePresenter.glowReach, 0.15, "the glow never reaches beyond 0.15 cell")
        let levels: [Int] = [0, 5, 9, 15, 19]
        var checked = 0
        for level in levels {
            let flags: [Bool] = [false, true]
            for solved in flags {
                let core = try self.core(level: level, solved: solved)
                let root = MazePresenter.scene(core)
                let segments = core.beam.segments
                let name = "level \(level + 1)\(solved ? " solved" : "")"
                var cores: [SceneNode] = []
                var halos: [SceneNode] = []
                for child in root.children where child.id.hasPrefix("beam") {
                    if child.id.hasSuffix(".halo") { halos.append(child) } else { cores.append(child) }
                }
                XCTAssertEqual(cores.count, segments.count, name)
                XCTAssertEqual(halos.count, segments.count, name)
                for (index, segment) in segments.enumerated() {
                    let line = try XCTUnwrap(node(root, "beam\(index)"), name)
                    let halo = try XCTUnwrap(node(root, "beam\(index).halo"), name)
                    XCTAssertEqual(line.primitive, .line(segment.start, segment.end, width: MazePresenter.beamWidth),
                                   "\(name) core \(index) lies on the tracer's segment")
                    XCTAssertEqual(line.color, MazePresenter.beamColor)
                    guard case .line(let a, let b, let width) = halo.primitive else {
                        XCTFail("\(name) halo \(index) is a line")
                        continue
                    }
                    XCTAssertEqual(a, segment.start, name)
                    XCTAssertEqual(b, segment.end, name)
                    XCTAssertLessThanOrEqual(width / 2, 0.15 + 1e-12, "\(name) halo \(index) half-width")
                    XCTAssertGreaterThan(width, MazePresenter.beamWidth, "the halo is wider than the core")
                    XCTAssertEqual(halo.color.w, 0.25, accuracy: 1e-12, "\(name) halo opacity")
                    XCTAssertEqual(Vec3(halo.color.x, halo.color.y, halo.color.z),
                                   Vec3(MazePresenter.beamColor.x, MazePresenter.beamColor.y,
                                        MazePresenter.beamColor.z), "the beam's colour")
                    XCTAssertLessThan(halo.z, line.z, "the halo lies under the core")
                    checked += 1
                }
                // Every core lies on some tracer segment, whatever its id.
                for line in cores {
                    guard case .line(let a, let b, _) = line.primitive else {
                        XCTFail("\(name) \(line.id) is a line")
                        continue
                    }
                    XCTAssertTrue(segments.contains { $0.start == a && $0.end == b }, "\(name) \(line.id)")
                }
            }
        }
        XCTAssertGreaterThan(checked, 20)
    }

    func testLitTargetsCarryARingAndUnlitOnesNone() throws {
        let levels: [Int] = [0, 15, 19]
        for level in levels {
            let flags: [Bool] = [false, true]
            for solved in flags {
                let core = try self.core(level: level, solved: solved)
                let root = MazePresenter.scene(core)
                let lit = Set(core.beam.litTargets)
                let name = "level \(level + 1)\(solved ? " solved" : "")"
                if solved { XCTAssertFalse(lit.isEmpty, name) }
                for (index, tile) in core.board.tiles.enumerated() where tile.kind == .target {
                    let ring = node(root, "tile\(index).ring")
                    guard lit.contains(tile.cell) else {
                        XCTAssertNil(ring, "\(name): an unlit target has no ring")
                        continue
                    }
                    let found = try XCTUnwrap(ring, "\(name): a lit target carries a ring")
                    XCTAssertEqual(found.color, MazePresenter.ringColor)
                    guard case .polyline(let points, let width) = found.primitive else {
                        XCTFail("\(name): the ring is an outline")
                        continue
                    }
                    XCTAssertEqual(width, MazePresenter.ringWidth)
                    XCTAssertEqual(points.count, 5, "a closed square")
                    let half = Tile.targetSide / 2 - MazePresenter.ringInset
                    XCTAssertEqual(half, 0.25, accuracy: 1e-12, "inset 0.05 inside the target")
                    for point in points {
                        let dx = abs(point.x - tile.cell.center.x), dy = abs(point.y - tile.cell.center.y)
                        XCTAssertEqual(max(dx, dy), half, accuracy: 1e-12, name)
                    }
                }
            }
        }
    }

    func testTheSelectedTileCarriesAnOutline() throws {
        let unselected = MazePresenter.scene(try core(level: 0))
        XCTAssertNil(node(unselected, "selection"))
        let cases: [(level: Int, select: Int)] = [(0, 0), (15, 1), (19, 0)]
        for item in cases {
            let core = try self.core(level: item.level, select: item.select)
            let tile = try XCTUnwrap(core.state.selectedTileIndex)
            let center = core.board.tiles[tile].cell.center
            let outline = try XCTUnwrap(node(MazePresenter.scene(core), "selection"))
            XCTAssertEqual(outline.color, MazePresenter.selectionColor)
            guard case .polyline(let points, _) = outline.primitive else {
                XCTFail("the selection is an outline")
                continue
            }
            XCTAssertEqual(points.count, 5)
            for point in points {
                let reach = max(abs(point.x - center.x), abs(point.y - center.y))
                XCTAssertEqual(reach, 0.5 - MazePresenter.selectionInset, accuracy: 1e-12, "inset 0.04 in its cell")
            }
        }
    }

    func testBeamChangesAreSpokenAtMostOncePerSecondOfFrameTime() throws {
        let sink = RecordingAnnouncementSink()
        let presenter = MazePresenter(experienceID: MazeTest.id, voiceOverRunning: { true }, announcementSink: sink)
        let start = try core(level: 0)
        let solved = try core(level: 0, solved: true)
        XCTAssertEqual(MazePresenter.spokenBeam(start.beam), "Beam ends at the wall; not solved.")
        XCTAssertEqual(MazePresenter.spokenBeam(solved.beam), "Beam ends at the target; solved.")

        presenter.updateAnnouncements(start, delta: 1.0 / 60)
        XCTAssertEqual(sink.announced, [], "the first frame only sets the baseline")
        for _ in 0..<120 { presenter.updateAnnouncements(start, delta: 1.0 / 60) }
        XCTAssertEqual(sink.announced, [], "an unchanged beam is never spoken")

        presenter.updateAnnouncements(solved, delta: 1.0 / 60)
        XCTAssertEqual(sink.announced, ["Beam ends at the target; solved."], "a change is spoken at once")
        let firstSpoken = presenter.announcementClock

        // Two more changes inside the second: held, the latest wins.
        presenter.updateAnnouncements(start, delta: 0.1)
        presenter.updateAnnouncements(solved, delta: 0.1)
        presenter.updateAnnouncements(start, delta: 0.1)
        XCTAssertEqual(sink.announced.count, 1, "held inside the second")
        var secondSpoken: Double?
        for _ in 0..<20 {
            presenter.updateAnnouncements(start, delta: 0.05)
            if sink.announced.count == 2, secondSpoken == nil { secondSpoken = presenter.announcementClock }
        }
        XCTAssertEqual(sink.announced, ["Beam ends at the target; solved.", "Beam ends at the wall; not solved."],
                       "the latest held text, once")
        let gap = try XCTUnwrap(secondSpoken) - firstSpoken
        XCTAssertGreaterThanOrEqual(gap, 1.0 - 1e-9, "at most once per second of frame time")
        XCTAssertLessThan(gap, 1.1, "and as soon as the second has passed")
        for _ in 0..<60 { presenter.updateAnnouncements(start, delta: 1.0 / 60) }
        XCTAssertEqual(sink.announced.count, 2, "nothing more for a still beam")

        var announcer = BeamAnnouncer()
        XCTAssertEqual(announcer.offer("a", at: 0), "a")
        XCTAssertNil(announcer.offer("b", at: 0.5))
        XCTAssertNil(announcer.offer("c", at: 0.99))
        XCTAssertNil(announcer.tick(at: 0.999))
        XCTAssertEqual(announcer.tick(at: 1.0), "c")
        XCTAssertNil(announcer.tick(at: 5))
        announcer.reset()
        XCTAssertEqual(announcer, BeamAnnouncer())
    }

    func testNothingReachesTheSinkWhileVoiceOverIsOff() throws {
        let sink = RecordingAnnouncementSink()
        let presenter = MazePresenter(experienceID: MazeTest.id, voiceOverRunning: { false }, announcementSink: sink)
        presenter.updateAnnouncements(try core(level: 0), delta: 1.0 / 60)
        presenter.updateAnnouncements(try core(level: 0, solved: true), delta: 1.0 / 60)
        XCTAssertEqual(presenter.spoken, ["Beam ends at the target; solved."], "the change is still due")
        XCTAssertEqual(sink.announced, [], "but not posted without VoiceOver")
    }
}
