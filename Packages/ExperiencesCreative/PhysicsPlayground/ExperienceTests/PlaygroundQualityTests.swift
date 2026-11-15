// PlaygroundQualityTests — feature 086 (A11-P05) T-A11-504 (FR-A11-502, FR-A11-510, FR-A11-520; SC-A11-502,
// SC-A11-505; clarifications 1, 4; research D1, D3; contract contracts/stability.md). The three quality levels and the
// schema-5 state, short runs only (each test well under 10 s, no wall-clock assertion): the core's declared tiers equal
// the drawing budget's levels, the presenter's level count and the profile's names (`level-0`…`level-2`), and the
// experience wrapper forwards the shell's profile and tier; the host's tier chooses the level (tier 0 the fullest,
// clamped) and Low Power Mode (injected) level 2; each level draws its spring coils, circle points and hatch spacing
// (none at level 2, where a static body keeps its darker fill), and drawing never changes the core; in a session under
// Low Power Mode the lightest level is drawn; the digest is the same at every tier, changed mid-run on an engine or in
// a drawn session, and equal to the undrawn replay; the stored examples of schemas 1…4 restore through the engine to a
// world at world schema 4 with every body awake, the schema-4 example keeping its worlds, origin and tutorial.
import Foundation
import XCTest
@testable import PhysicsPlaygroundExperience
import PhysicsPlaygroundCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreSimulation

/// A Low Power Mode switch a test turns on and off.
@MainActor
private final class LowPowerSwitch {
    var on = false
}

@MainActor
final class PlaygroundQualityTests: XCTestCase {
    private let playgroundID = ExperienceID(rawValue: PlaygroundCore.experienceID)!

    private func makeEngine(seed: UInt64 = 7) async throws -> ExperienceEngine<PlaygroundCore> {
        var engine = ExperienceEngine<PlaygroundCore>(id: playgroundID)
        try await engine.prepare(seed: seed)
        try engine.activate()
        return engine
    }

    /// The sample world with two springs (one to a world point, one between the circle and the box) and the circle
    /// selected.
    private func springWorld() -> PhysicsWorld {
        var world = playgroundSampleWorld()
        world.springs = [
            WorldSpring(id: 0, a: .world(Vec2(5, 7.5)), b: .body(1, local: Vec2(0, 0.5)), restLength: 1.5),
            WorldSpring(id: 1, a: .body(1), b: .body(2, local: Vec2(0.6, 0)), restLength: 2),
        ]
        world.nextSpringId = 2
        world.selectedId = 1
        return world
    }

    // MARK: Declared tiers

    /// The core's three tiers equal the budget's levels, the presenter's level count and the profile's names, and
    /// the experience wrapper forwards the shell's profile and tier.
    func testTheDeclaredTiersEqualThePresenterLevelsAndTheProfile() async throws {
        XCTAssertEqual(PlaygroundCore.qualityTiers, 3)
        XCTAssertEqual(PlaygroundCore.qualityTiers, DrawingBudget.count)
        XCTAssertEqual(PlaygroundPresenter.levelCount, DrawingBudget.count)
        XCTAssertEqual(PlaygroundCore.qualityProfile.count, PlaygroundCore.qualityTiers)
        XCTAssertEqual(PlaygroundCore.qualityProfile.names, ["level-0", "level-1", "level-2"])

        let session = ExperienceSession()
        let shell = try await PlaygroundTest.open(session)
        let experience = PlaygroundExperience(shell: shell)
        XCTAssertEqual(experience.qualityProfile.names, PlaygroundCore.qualityProfile.names)
        XCTAssertEqual(experience.qualityProfile.count, 3)
        try experience.setQualityTier(2)
        XCTAssertEqual(shell.engine.qualityTier, 2, "the wrapper's tier reaches the shell")
        XCTAssertThrowsError(try experience.setQualityTier(3), "only tiers 0…2 exist")
        session.close()
    }

    // MARK: Levels

    /// Host tier t draws level t (clamped to 0…2), Low Power Mode draws level 2 at every tier, and the level follows
    /// the switch when it turns off again; before the first frame the level is 0.
    func testTheHostTierAndLowPowerModeChooseTheLevel() {
        XCTAssertEqual((0..<3).map { DrawingBudget.level(tier: $0, lowPower: false) }, [0, 1, 2])
        XCTAssertEqual(DrawingBudget.level(tier: -1, lowPower: false), 0)
        XCTAssertEqual(DrawingBudget.level(tier: 9, lowPower: false), 2)
        XCTAssertEqual((-1...3).map { DrawingBudget.level(tier: $0, lowPower: true) }, [2, 2, 2, 2, 2])
        let lowPower = LowPowerSwitch()
        let presenter = PlaygroundPresenter(experienceID: PlaygroundTest.id, lowPowerMode: { lowPower.on })
        XCTAssertEqual(presenter.budgetLevel, 0, "the fullest drawing before the first frame")
        XCTAssertNil(presenter.lastHostTier)
        for tier in 0..<3 {
            presenter.applyQuality(tier: tier)
            XCTAssertEqual(presenter.budgetLevel, tier)
            XCTAssertEqual(presenter.budget, DrawingBudget.levels[tier])
            XCTAssertEqual(presenter.lastHostTier, tier)
        }
        lowPower.on = true
        presenter.applyQuality(tier: 0)
        XCTAssertEqual(presenter.budgetLevel, 2, "Low Power Mode draws level 2")
        XCTAssertTrue(presenter.lastLowPower)
        lowPower.on = false
        presenter.applyQuality(tier: 0)
        XCTAssertEqual(presenter.budgetLevel, 0, "and the host's level again once it is off")
        XCTAssertFalse(presenter.lastLowPower)
    }

    /// At each level every spring is a zigzag of the level's coils, every circle outline and the selection ring a
    /// closed ring of the level's points, and the static ledge hatched at the level's spacing (not at all at level 2,
    /// where it keeps its darker fill); the arrowheads are drawn at every level; drawing reads the core only.
    func testEachLevelDrawsItsCoilsSegmentsAndHatch() throws {
        let expected: [(coils: Int, points: Int, spacing: Double?)] = [(8, 33, 0.12), (6, 24, 0.2), (4, 16, nil)]
        var world = springWorld()
        world.showVelocity = true
        world.bodies[1].velocity = Vec2(1, 0)
        let core = try playgroundCore(world)
        let copy = core
        for (level, want) in expected.enumerated() {
            let presenter = PlaygroundPresenter(experienceID: PlaygroundTest.id, lowPowerMode: { false })
            presenter.applyQuality(tier: level)
            XCTAssertEqual(presenter.budget.coils, want.coils)
            XCTAssertEqual(presenter.budget.circleSegments, want.points)
            XCTAssertEqual(presenter.budget.hatchSpacing, want.spacing)
            presenter.layOut(core, width: 1200, height: 1000)
            XCTAssertEqual(core, copy, "drawing reads the core only (level \(level))")
            XCTAssertEqual(presenter.lastSpringsDrawn, 2)
            for slot in 0..<2 {
                guard case .polyline(let points, _)? = presenter.springNodes[slot].primitive else {
                    return XCTFail("spring \(slot) has no zigzag at level \(level)")
                }
                XCTAssertEqual(points.count, 4 + 2 * want.coils, "spring \(slot) at level \(level)")
                XCTAssertEqual(points.count, PlaygroundPresenter.zigzagPoints(coils: want.coils))
            }
            guard case .polyline(let ring, _)? = presenter.edgeNodes[1].primitive else {
                return XCTFail("no circle outline at level \(level)")
            }
            XCTAssertEqual(ring.count, want.points, "circle outline at level \(level)")
            XCTAssertLessThan(((ring.first ?? .zero) - (ring.last ?? .zero)).length, 1e-6, "a closed ring")
            guard case .polyline(let selection, _)? = presenter.selectionNode.primitive else {
                return XCTFail("no selection ring at level \(level)")
            }
            XCTAssertEqual(selection.count, want.points, "selection ring at level \(level)")
            XCTAssertNotNil(presenter.headNodes[1][PlaygroundArrow.Kind.velocity.rawValue].primitive,
                            "the arrowhead at level \(level)")
            XCTAssertEqual(presenter.lastStaticDrawn, 1)
            let steel = try XCTUnwrap(PlaygroundCore.catalog.material(id: "steel"))
            XCTAssertEqual(presenter.fillNodes[0].color,
                           PlaygroundPresenter.darkened(PlaygroundPresenter.vector(steel.fill),
                                                        PlaygroundPresenter.staticFillFactor),
                           "the static ledge keeps its darker fill at level \(level)")
            if let spacing = want.spacing {
                guard case .polyline(let hatch, _)? = presenter.hatchNodes[0].primitive else {
                    return XCTFail("no hatch at level \(level)")
                }
                let lines = max(1, Int((2 * StartingScene.ledgeHalfExtents.x / spacing).rounded(.down)))
                XCTAssertEqual(hatch.count, 2 * lines, "two ends per hatch line at level \(level)")
                XCTAssertEqual(presenter.lastHatchesDrawn, 1)
            } else {
                XCTAssertNil(presenter.hatchNodes[0].primitive, "no hatch at level \(level)")
                XCTAssertEqual(presenter.lastHatchesDrawn, 0)
            }
        }
        XCTAssertGreaterThan(
            Int((2 * StartingScene.ledgeHalfExtents.x / 0.12).rounded(.down)),
            Int((2 * StartingScene.ledgeHalfExtents.x / 0.2).rounded(.down)), "level 0 hatches more densely")
    }

    /// In a session under (injected) Low Power Mode every frame is drawn at level 2: springs of four coils, no hatch.
    func testLowPowerModeDrawsTheLightestLevelInASession() async throws {
        let session = ExperienceSession()
        let shell = try await PlaygroundTest.open(session, lowPowerMode: { true })
        try PlaygroundTest.frames(session, 2)
        let presenter = shell.presenter
        XCTAssertTrue(presenter.lastLowPower)
        XCTAssertEqual(presenter.budgetLevel, 2)
        XCTAssertEqual(presenter.lastStaticDrawn, 1, "the ledge is still drawn darker")
        XCTAssertEqual(presenter.lastHatchesDrawn, 0, "but not hatched")
        guard case .polyline(let points, _)? = presenter.springNodes[0].primitive else {
            return XCTFail("no hanging spring")
        }
        XCTAssertEqual(points.count, PlaygroundPresenter.zigzagPoints(coils: 4))
        session.close()
    }

    // MARK: Determinism

    /// The tier is presentation only: an engine whose tier changes mid-run keeps the state and the digest of the same
    /// run without tier changes, and the core's `setQualityTier` changes nothing.
    func testTheDigestIsTheSameAtEveryTier() async throws {
        var plain = try await makeEngine()
        var tiered = try await makeEngine()
        for engine in [plain, tiered] { XCTAssertEqual(engine.qualityTier, 0) }
        let actions: [(String, [Double])] = [("world.drop", [0]), ("world.stiffness", [3]), ("edit.select", [9]),
                                             ("edit.nudge", [1, 0.5]), ("world.drop", [1])]
        for (index, tier) in [2, 1, 0, 2, 1].enumerated() {
            try tiered.setQualityTier(tier)
            XCTAssertEqual(tiered.qualityTier, tier)
            let (control, values) = actions[index]
            XCTAssertTrue(plain.handle(control: control, values: values).isAccepted, control)
            XCTAssertTrue(tiered.handle(control: control, values: values).isAccepted, control)
            try plain.run(steps: 40)
            try tiered.run(steps: 40)
            XCTAssertEqual(tiered.core, plain.core, "tier \(tier)")
            XCTAssertEqual(try tiered.digest(), try plain.digest(), "tier \(tier)")
        }
        for tier in 0..<PlaygroundCore.qualityTiers {
            var copy = try XCTUnwrap(plain.core)
            copy.setQualityTier(tier)
            XCTAssertEqual(copy, plain.core, "the core stores no tier")
        }
    }

    /// A drawn session whose tier changes between frames equals the undrawn replay of the same actions at the same
    /// steps.
    func testADrawnSessionAtChangingTiersEqualsTheUndrawnReplay() async throws {
        let session = ExperienceSession()
        let shell = try await PlaygroundTest.open(session)
        var entries: [ScenarioStep] = []
        var last = 0
        func send(_ control: String, _ values: [Double]) {
            let step = shell.engine.stepIndex
            XCTAssertTrue(shell.handle(control: control, values: values).isAccepted, control)
            entries.append(ScenarioStep(steps: step - last, action: ScriptedAction(control, values)))
            last = step
        }
        for (tier, action) in [(2, ("world.drop", [0.0])), (0, ("overlay.velocity", [1.0])),
                               (1, ("world.drop", [1.0]))] {
            try shell.setQualityTier(tier)
            send(action.0, action.1)
            try PlaygroundTest.frames(session, 15)
            XCTAssertEqual(shell.presenter.lastHostTier, shell.engine.qualityTier, "the frame drew the engine's tier")
        }
        entries.append(ScenarioStep(steps: shell.engine.stepIndex - last))
        let bare = PlaygroundCore.played(seed: 7, entries: entries)
        XCTAssertEqual(try PlaygroundTest.core(shell), bare, "the drawn session equals the undrawn replay")
        var builder = DigestBuilder(domain: playgroundID.rawValue)
        try bare.writeDigest(into: &builder)
        XCTAssertEqual(try shell.engine.digest().hex, builder.finish().hex)
        session.close()
    }

    // MARK: Stored examples

    /// The stored examples of schemas 1…4 restore through the engine with the digests they name, to a world at world
    /// schema 4 with every body awake and 0 rest ticks; the registry's check accepts all four.
    func testTheStoredExamplesOfSchemasOneToFourRestore() async throws {
        let examples = try [PlaygroundCore.schemaOneExample(), PlaygroundCore.schemaTwoExample(),
                            PlaygroundCore.schemaThreeExample(), PlaygroundCore.schemaFourExample()].map {
            try XCTUnwrap($0)
        }
        XCTAssertEqual(examples.map(\.version), [1, 2, 3, 4])
        for example in examples {
            let snapshot = try ExperienceSnapshot(data: example.snapshot)
            XCTAssertEqual(snapshot.schemaVersion, example.version)
            var engine = try await makeEngine(seed: 3)
            try engine.restore(snapshot)
            XCTAssertEqual(try engine.digest().hex, example.expectedDigest, "schema \(example.version)")
            let core = try XCTUnwrap(engine.core)
            for world in [core.world, core.startingWorld] {
                XCTAssertEqual(world.schema, PhysicsWorld.schemaVersion, "schema \(example.version)")
                XCTAssertEqual(world.validate(), [], "schema \(example.version)")
                XCTAssertTrue(world.bodies.allSatisfy { !$0.asleep && $0.restTicks == 0 }, "every body awake")
            }
            XCTAssertEqual(core.preparationSeed, snapshot.seed)
            try engine.run(steps: 30)
            XCTAssertEqual(try XCTUnwrap(engine.core).world.validate(), [], "it plays on (schema \(example.version))")
        }
        let problems = await SnapshotMigrationCheck.problems(for: PlaygroundCore.self, id: playgroundID,
                                                              examples: examples)
        XCTAssertEqual(problems, [])
    }

    /// The stored A11-P04 payload is written as A11-P04 wrote it (both worlds at world schema 3, bodies without the
    /// sleep keys) and restores through the step 4 → 5 to the same worlds, generator, origin and tutorial; the step
    /// refuses a world already at world schema 4 and a payload without the schema-4 keys, and the restore refuses the
    /// schema-4 payload without the step.
    func testTheSchemaFourExampleRestoresThroughTheStepFourToFive() async throws {
        let example = try XCTUnwrap(PlaygroundCore.schemaFourExample())
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        XCTAssertEqual(snapshot.schemaVersion, 4)
        XCTAssertEqual(snapshot.stepIndex, 0)
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8))
                                    as? [String: Any])
        XCTAssertEqual(Set(payload.keys), ["origin", "random", "startingWorld", "tutorial", "world"],
                       "exactly the A11-P04 keys")
        for name in ["world", "startingWorld"] {
            let world = try XCTUnwrap(payload[name] as? [String: Any])
            XCTAssertEqual(world["schema"] as? Int, 3, name)
            for body in try XCTUnwrap(world["bodies"] as? [[String: Any]]) {
                XCTAssertNil(body["asleep"], "an A11-P04 body has no asleep key")
                XCTAssertNil(body["restTicks"], "an A11-P04 body has no restTicks key")
                XCTAssertNotNil(body["pinned"])
            }
        }
        let stored = PlaygroundCore.schemaFourExampleState()
        XCTAssertEqual(stored.origin, .preset(PresetID.springChain.rawValue))
        XCTAssertNotNil(stored.tutorial, "a tutorial runs")
        XCTAssertNotEqual(stored.world, stored.startingWorld, "a box was dropped after the chain opened")
        XCTAssertThrowsError(try PlaygroundCore.restore(payload: Data(snapshot.payload.utf8), seed: 7),
                             "a schema-4 payload needs the step 4 → 5")

        var engine = try await makeEngine(seed: 3)
        try engine.restore(snapshot)
        XCTAssertEqual(try engine.digest().hex, example.expectedDigest)
        let core = try XCTUnwrap(engine.core)
        XCTAssertEqual(core.world, PhysicsWorld.migrated(fromSchemaThree: stored.world))
        XCTAssertEqual(core.startingWorld, PhysicsWorld.migrated(fromSchemaThree: stored.startingWorld))
        XCTAssertEqual(core.state.random, stored.random)
        XCTAssertEqual(core.origin, stored.origin)
        XCTAssertEqual(core.tutorial, stored.tutorial)
        var expected = PlaygroundCore(seed: 7)
        for item in PlaygroundCore.schemaFourExampleActions {
            _ = expected.apply(ExperienceAction(control: item.control, values: item.values, step: 0))
        }
        XCTAssertEqual(core.world, expected.world, "the same world the A11-P04 actions give")
        XCTAssertEqual(core.startingWorld, expected.startingWorld)
        XCTAssertEqual(core.generator, expected.generator)

        let current = try XCTUnwrap(try JSONSerialization.jsonObject(with: PlaygroundCore(seed: 7).snapshotPayload())
                                    as? [String: Any])
        XCTAssertThrowsError(try PlaygroundCore.migratedToSchemaFive(current)) { error in
            XCTAssertEqual(error as? PlaygroundRestoreError, .notSchemaFour(4))
        }
        let three = try ExperienceSnapshot(data: try XCTUnwrap(PlaygroundCore.schemaThreeExample()).snapshot)
        let threePayload = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(three.payload.utf8))
                                         as? [String: Any])
        XCTAssertThrowsError(try PlaygroundCore.migratedToSchemaFive(threePayload), "a Phase 03 payload needs 3 → 4")
    }
}
