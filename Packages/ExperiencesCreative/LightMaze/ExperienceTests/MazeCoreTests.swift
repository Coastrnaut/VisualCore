// MazeCoreTests — feature 096 (A13-P01) T-A13-104 (FR-A13-120, FR-A13-121, FR-A13-122; clarification Q5; SC-A13-105).
// The adapter core of Light Maze against the experience contract, short runs only (no wall clock): the id, the six
// controls, schema 1, one quality tier and the default step; conformance over three seeds; the first state (every
// seed opens level 1); every action accepted in range; refusals by the engine and by the core (`a13.invalid-choice`)
// each leaving the state as it was; host steps changing nothing; the digest covering the state and the beam, stable;
// the snapshot round trip into another engine; damaged and newer snapshots refused; reset; the outcome; the canvas
// description of clarification Q5.
import Foundation
import XCTest
@testable import LightMazeExperience
import LightMazeCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreMath
import VisualCoreSimulation

final class MazeCoreTests: XCTestCase {
    private let mazeID = ExperienceID(rawValue: MazeCore.experienceID)!

    private func makeEngine(seed: UInt64 = 1) async throws -> ExperienceEngine<MazeCore> {
        var engine = ExperienceEngine<MazeCore>(id: mazeID)
        try await engine.prepare(seed: seed)
        try engine.activate()
        return engine
    }

    private func action(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    func testIdControlsSchemaTiersAndStep() {
        XCTAssertEqual(MazeCore.experienceID, "a13.light-maze")
        let ids: [String] = MazeCore.controls.map(\.id)
        XCTAssertEqual(ids, ["level.select", "level.next", "level.previous", "tile.select", "tile.turn", "level.reset"])
        XCTAssertEqual(ids, MazeCore.actionIDs)
        XCTAssertEqual(MazeCore.levelCount, 20)
        XCTAssertEqual(MazeCore.maxTurnable, 8)
        let ranges: [[ClosedRange<Double>]] = [[0...19], [], [], [0...7], [], []]
        XCTAssertEqual(MazeCore.controls.map(\.ranges), ranges)
        XCTAssertEqual(MazeCore.migrations.currentVersion, 1)
        XCTAssertEqual(MazeCore.qualityTiers, 1)
        XCTAssertEqual(MazeCore.qualityProfile.levels.count, 1)
        XCTAssertEqual(MazeCore.stepDuration, 1.0 / 120, accuracy: 1e-15)
        XCTAssertEqual(MazeRule.invalidChoice, "a13.invalid-choice")
    }

    func testConformancePassesOverThreeSeeds() async {
        let actions: [ScriptedAction] = [
            ScriptedAction("tile.select", [0]), ScriptedAction("tile.turn"), ScriptedAction("level.next"),
            ScriptedAction("tile.select", [1]), ScriptedAction("tile.turn"), ScriptedAction("level.reset"),
            ScriptedAction("level.select", [5]), ScriptedAction("level.previous"),
        ]
        let rejected: [ScriptedAction] = [
            ScriptedAction("level.select", [0.5]), ScriptedAction("level.select", [20]),
            ScriptedAction("level.select", [.nan]), ScriptedAction("level.select", []),
            ScriptedAction("level.next", [1]), ScriptedAction("tile.select", [8]),
            ScriptedAction("tile.select", [.infinity]), ScriptedAction("tile.turn", [0]),
            ScriptedAction("level.reset", [0]), ScriptedAction("bogus"),
        ]
        let plan = ConformancePlan(seeds: [1, 2, 0xFFFF_FFFF_FFFF_FFFF], stepsPerSegment: 5, actions: actions,
                                   rejected: rejected)
        let report = await ExperienceConformance.run(MazeCore.self, id: mazeID, plan: plan)
        for entry in report.entries { XCTAssertTrue(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    func testEverySeedOpensTheFirstLevel() async throws {
        let engine = try await makeEngine(seed: 1)
        let core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.state, MazeState.initial)
        XCTAssertEqual(core.level.id, "lm-01")
        XCTAssertEqual(core.state.selection, MazeState.noSelection)
        XCTAssertEqual(core.beam, BeamTracer.trace(MazeState.initial.board))
        XCTAssertFalse(core.isSolved)
        XCTAssertNil(core.outcome)
        let seeds: [UInt64] = [0, 2, 99, .max]
        for seed in seeds {
            XCTAssertEqual(MazeCore(seed: seed).state, MazeState.initial, "seed \(seed)")
            XCTAssertEqual(try mazeDigest(MazeCore(seed: seed)), try mazeDigest(core), "seed \(seed)")
        }
    }

    func testActionsInRangeAreAccepted() async throws {
        var engine = try await makeEngine()
        let start = try engine.digest()
        XCTAssertEqual(engine.handle(control: "tile.select", values: [0]), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).state.selection, 0)
        XCTAssertEqual(try XCTUnwrap(engine.core).state.selectedTileIndex, 2, "lm-01's mirror is its third tile")
        XCTAssertNotEqual(try engine.digest(), start, "the selection is state")
        XCTAssertEqual(engine.handle(control: "tile.turn"), .accepted)
        var core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.state.orientations, [.slash])
        XCTAssertTrue(core.isSolved, "turning lm-01's mirror lights its target")
        XCTAssertEqual(core.beam.endReasons, [.target])
        XCTAssertEqual(core.outcome?.code, "level-solved")

        XCTAssertEqual(engine.handle(control: "level.next"), .accepted)
        core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.state, MazeState(levelIndex: 1), "the next level opens in its starting orientations")
        XCTAssertEqual(engine.handle(control: "level.previous"), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).state, MazeState(levelIndex: 0), "back to an unturned level 1")
        XCTAssertEqual(engine.handle(control: "level.select", values: [19]), .accepted)
        core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.level.id, "lm-20")
        XCTAssertEqual(engine.handle(control: "tile.select", values: [Double(core.state.orientations.count - 1)]),
                       .accepted)
        XCTAssertEqual(engine.handle(control: "tile.turn"), .accepted)
        XCTAssertNotEqual(try XCTUnwrap(engine.core).state.orientations, core.level.startOrientations)
        XCTAssertEqual(engine.handle(control: "level.reset"), .accepted)
        XCTAssertEqual(try XCTUnwrap(engine.core).state, MazeState(levelIndex: 19))
    }

    func testRefusalsKeepTheStateWithTheirReasons() async throws {
        var engine = try await makeEngine()
        let invalid = ActionResult.rejected(.rule(code: MazeRule.invalidChoice))
        let before = try engine.digest()
        XCTAssertEqual(engine.handle(control: "level.select", values: [20]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "level.select", values: [.nan]), .rejected(.nonFinite(index: 0)))
        XCTAssertEqual(engine.handle(control: "level.select", values: [0.5]), invalid)
        XCTAssertEqual(engine.handle(control: "level.previous"), invalid, "no level before the first")
        XCTAssertEqual(engine.handle(control: "tile.turn"), invalid, "nothing selected")
        XCTAssertEqual(engine.handle(control: "tile.select", values: [1]), invalid, "lm-01 has one turnable tile")
        XCTAssertEqual(engine.handle(control: "tile.select", values: [8]), .rejected(.outOfRange(index: 0)))
        XCTAssertEqual(engine.handle(control: "level.next", values: [1]),
                       .rejected(.wrongValueCount(expected: 0, found: 1)))
        XCTAssertEqual(engine.handle(control: "bogus", values: []), .rejected(.unknownControl("bogus")))
        XCTAssertEqual(try engine.digest(), before)
        XCTAssertEqual(engine.handle(control: "level.select", values: [19]), .accepted)
        let last = try engine.digest()
        XCTAssertEqual(engine.handle(control: "level.next"), invalid, "no level after the last")
        XCTAssertEqual(try engine.digest(), last)

        // Called directly, the core refuses by its own rules and changes nothing.
        var core = MazeCore(seed: 1)
        let original = core
        XCTAssertEqual(core.apply(action("level.select", [20])), invalid)
        XCTAssertEqual(core.apply(action("level.select", [-1])), invalid)
        XCTAssertEqual(core.apply(action("level.select", [.infinity])), invalid)
        XCTAssertEqual(core.apply(action("tile.select", [-1])), invalid)
        XCTAssertEqual(core.apply(action("tile.select", [0.5])), invalid)
        XCTAssertEqual(core.apply(action("tile.select", [.nan])), invalid)
        XCTAssertEqual(core.apply(action("tile.turn")), invalid)
        XCTAssertEqual(core.apply(action("level.previous")), invalid)
        XCTAssertEqual(core.apply(action("level.select")), .rejected(.wrongValueCount(expected: 1, found: 0)))
        XCTAssertEqual(core.apply(action("tile.turn", [0])), .rejected(.wrongValueCount(expected: 0, found: 1)))
        XCTAssertEqual(core.apply(action("bogus", [0])), .rejected(.unknownControl("bogus")))
        XCTAssertEqual(core, original, "the level, orientations, selection and beam are unchanged")
    }

    func testHostStepsChangeNothing() async throws {
        var engine = try await makeEngine()
        XCTAssertEqual(engine.handle(control: "tile.select", values: [0]), .accepted)
        let core = try XCTUnwrap(engine.core)
        let digest = try engine.digest()
        try engine.run(steps: 240)
        XCTAssertEqual(try XCTUnwrap(engine.core), core, "nothing animates")
        XCTAssertEqual(try engine.digest(), digest)
    }

    func testTheDigestCoversTheStateAndTheBeamAndIsStable() throws {
        var selected = MazeState.initial
        XCTAssertTrue(selected.selectTile(0))
        var turned = selected
        XCTAssertTrue(turned.turnSelected())
        let states: [MazeState] = [MazeState.initial, selected, turned, MazeState(levelIndex: 1),
                                   MazeState(levelIndex: 19)]
        var digests: [String] = []
        for state in states { digests.append(try mazeDigest(mazeCore(state))) }
        XCTAssertEqual(Set(digests).count, states.count, "level, orientations and selection are digested")
        XCTAssertEqual(try mazeDigest(mazeCore(MazeState.initial, seed: 9)), digests[0],
                       "the preparation seed is not state")
        for (index, state) in states.enumerated() {
            XCTAssertEqual(try mazeDigest(mazeCore(state)), digests[index], "the digest is stable")
        }

        // The beam is part of the digest: the state's text alone gives another digest.
        var builder = DigestBuilder(domain: MazeCore.experienceID)
        builder.add("a13.maze.v1|" + (String(data: MazeState.initial.encoded(), encoding: .utf8) ?? ""))
        XCTAssertNotEqual(builder.finish().hex, digests[0])
        // The solved fixtures' digests are the committed ones.
        let id = try XCTUnwrap(ExperienceID(rawValue: MazeCore.experienceID))
        for fixture in MazeCore.solvedFixtures {
            let entries = MazeCore.fixtureEntries(level: fixture.level)
            XCTAssertEqual(MazeCore.expectedDigest(for: id, seed: 1, entries: entries), fixture.digest,
                           "level \(fixture.level + 1)")
        }
    }

    func testTheSnapshotRestoresIdenticallyInAnotherEngine() async throws {
        var engine = try await makeEngine()
        for entry in MazeCore.inputEntries {
            try engine.run(steps: entry.steps)
            if let action = entry.action {
                XCTAssertEqual(engine.handle(control: action.control, values: action.values), .accepted)
            }
        }
        let snapshot = try engine.snapshot()
        XCTAssertEqual(snapshot.schemaVersion, 1)
        XCTAssertEqual(Data(snapshot.payload.utf8), try XCTUnwrap(engine.core).state.encoded())
        let saved = try XCTUnwrap(engine.core)
        var other = try await makeEngine(seed: 3)
        try other.restore(ExperienceSnapshot(data: snapshot.encoded()))
        let restored = try XCTUnwrap(other.core)
        XCTAssertEqual(restored.state, saved.state)
        XCTAssertEqual(restored.beam, saved.beam)
        XCTAssertEqual(try other.digest(), try engine.digest())
        XCTAssertEqual(engine.handle(control: "tile.turn"), .accepted)
        XCTAssertEqual(other.handle(control: "tile.turn"), .accepted)
        XCTAssertEqual(try XCTUnwrap(other.core).state, try XCTUnwrap(engine.core).state, "both continue alike")
    }

    func testDamagedAndNewerSnapshotsAreRefused() async throws {
        var engine = try await makeEngine()
        XCTAssertEqual(engine.handle(control: "level.select", values: [9]), .accepted)
        XCTAssertEqual(engine.handle(control: "tile.select", values: [2]), .accepted)
        let saved = try engine.snapshot()
        let before = try engine.digest()

        // Damaged: not JSON, truncated, and JSON with a missing or invalid key.
        XCTAssertThrowsError(try engine.restore(mazeEnvelope(Data("{not json".utf8), like: saved)))
        XCTAssertThrowsError(try engine.restore(mazeEnvelope(Data(saved.payload.utf8.prefix(20)), like: saved)))
        let damaged: [(String, (inout [String: Any]) -> Void)] = [
            ("no level", { $0["levelIndex"] = nil }),
            ("level 20", { $0["levelIndex"] = 20 }),
            ("too few orientations", { $0["orientations"] = ["slash"] }),
            ("unknown orientation", { object in
                var list = object["orientations"] as? [String] ?? []
                if !list.isEmpty { list[0] = "sideways" }
                object["orientations"] = list
            }),
            ("selection 9", { $0["selection"] = 9 }),
            ("selection -2", { $0["selection"] = -2 }),
            ("no schema", { $0["schema"] = nil }),
        ]
        for (name, change) in damaged {
            XCTAssertThrowsError(try engine.restore(mazeEnvelope(mazePayload(saved.payload, change), like: saved)),
                                 name)
        }
        // Newer: an envelope of schema 2, and a payload of schema 2 inside a schema-1 envelope.
        XCTAssertThrowsError(try engine.restore(mazeEnvelope(Data(saved.payload.utf8), like: saved, schema: 2)))
        let newerPayload = try mazePayload(saved.payload) { $0["schema"] = 2 }
        XCTAssertThrowsError(try engine.restore(mazeEnvelope(newerPayload, like: saved)))
        XCTAssertEqual(try engine.digest(), before, "every refusal leaves the state as it was")

        // The core names the reason.
        XCTAssertThrowsError(try MazeCore.restore(payload: newerPayload, seed: 1)) { error in
            XCTAssertEqual(error as? MazeRestoreError, .refused(.newerVersion))
        }
        XCTAssertThrowsError(try MazeCore.restore(payload: Data("{not json".utf8), seed: 1)) { error in
            XCTAssertEqual(error as? MazeRestoreError, .refused(.damaged))
        }
    }

    func testResetReturnsToTheFirstLevel() async throws {
        var engine = try await makeEngine(seed: 2)
        for entry in MazeCore.inputEntries {
            try engine.run(steps: entry.steps)
            if let action = entry.action { _ = engine.handle(control: action.control, values: action.values) }
        }
        XCTAssertNotEqual(try XCTUnwrap(engine.core), MazeCore(seed: 2))
        try engine.reset()
        XCTAssertEqual(try XCTUnwrap(engine.core), MazeCore(seed: 2))
        XCTAssertEqual(engine.stepIndex, 0)
    }

    func testTheOutcomeFollowsTheSolvedState() {
        var core = MazeCore(seed: 1)
        XCTAssertNil(core.outcome)
        _ = core.apply(action("tile.select", [0]))
        XCTAssertNil(core.outcome, "selecting turns nothing")
        _ = core.apply(action("tile.turn"))
        XCTAssertEqual(core.outcome?.code, "level-solved")
        _ = core.apply(action("tile.turn"))
        XCTAssertNil(core.outcome, "turned back, not solved")
        for level in [0, 9, 19] {
            let solved = MazeCore.played(seed: 1, entries: MazeCore.fixtureEntries(level: level))
            XCTAssertEqual(solved.outcome?.code, "level-solved", "level \(level + 1)")
            XCTAssertEqual(solved.state.orientations, solved.level.solution)
        }
    }

    func testTheCanvasDescriptionFollowsClarificationQ5() {
        let first = MazeCore(seed: 1)
        XCTAssertEqual(first.canvasDescription,
                       "Light Maze: level 1, First light; 1 mirror, 1 target; beam ends at the wall; not solved.")
        var solved = first
        _ = solved.apply(action("tile.select", [0]))
        _ = solved.apply(action("tile.turn"))
        XCTAssertEqual(solved.canvasDescription,
                       "Light Maze: level 1, First light; 1 mirror, 1 target; beam ends at the target; solved.")
        let two = MazeState(levelIndex: 1)
        XCTAssertEqual(MazeCore.canvasDescription(two, beam: two.beam),
                       "Light Maze: level 2, Around the corner; 2 mirrors, 1 target; beam ends at the edge; "
                       + "not solved.")
        let sixteen = MazeState(levelIndex: 15)
        XCTAssertEqual(MazeCore.canvasDescription(sixteen, beam: sixteen.beam),
                       "Light Maze: level 16, Split; 1 mirror, 1 prism, 2 targets; beams end at the edge and the "
                       + "target; not solved.")
        let twenty = MazeCore.played(seed: 1, entries: MazeCore.fixtureEntries(level: 19))
        XCTAssertEqual(twenty.canvasDescription,
                       "Light Maze: level 20, Prism maze; 5 mirrors, 1 prism, 2 targets; beams end at 2 targets; "
                       + "solved.")
        XCTAssertEqual(MazeCore.counted(1, "mirror"), "1 mirror")
        XCTAssertEqual(MazeCore.counted(0, "prism"), "0 prisms")
        XCTAssertEqual(MazeCore.endPlace(.loop, count: 1), "a loop")
        XCTAssertEqual(MazeCore.endPlace(.bounceCap, count: 2), "2 bounce limits")
        let empty = Beam(segments: [], litTargets: [], endReasons: [], droppedBranches: 0, isSolved: false)
        XCTAssertEqual(MazeCore.endWords(empty), "no beam")
        let three = Beam(segments: [], litTargets: [], endReasons: [.wall, .loop, .wall], droppedBranches: 0,
                         isSolved: false)
        XCTAssertEqual(MazeCore.endWords(three), "beams end at 2 walls and a loop")
    }
}
