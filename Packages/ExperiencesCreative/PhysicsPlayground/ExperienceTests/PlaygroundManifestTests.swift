// PlaygroundManifestTests — feature 082 (A11-P01) T-A11-106 (FR-A11-122; SC-A11-107; research D5). The scenario
// manifest of Physics Playground: valid with the nine standard scenarios and ten fixtures (free fall, two-body
// momentum, static zero mass, replay determinism, frame pacing, time scale and single step, save/restore, resume
// without catch-up, catalog refusal, body cap), its derived digests and expected results equal to what the engine
// gives when the runner plays them, the fixtures ending in the states they name, and the committed
// `scenario-manifest.json` equal to the Swift manifest (`UPDATE_SCENARIO_MANIFEST=1`, on the simulator
// `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, rewrites it).
//
// Feature 083 (A11-P02) T-A11-205 (FR-A11-222; research D5): eighteen fixtures; fixtures 1–10 on the ten-body starting
// scene (38 drops fill it), and fixtures 11–18 ending in the states they name: a resting pile in contact, the hanging
// box at the analytic stretch, the total energy bounded without gravity and drag, the hanging box's motion damped away,
// the clamped stiffness, the broad-phase world equal to the all-pairs world, the gravity and drag levels in the
// settings and in a falling circle's speed, and the stored schema-1 example restoring with the fixture's generator
// and drops.
//
// Feature 084 (A11-P03) T-A11-304 (FR-A11-321; SC-A11-305; research D5): twenty-six fixtures and schema 3; the
// rejection scenario's edit refusals; the body-cap fixture also refusing an add; fixtures 19–26 ending in the states
// they name: the added bodies centred at their points, the grabbed circle pulled to its target and let go with its own
// velocity, the pinned circle bit-identical under impacts for 1,000 steps with every number finite, the unpinned
// circle falling, the deleted bodies gone with their springs and the selection, the nudged selection, the overlays
// changing nothing but their flags, and the stored schema-2 example restoring to the fixture's world.
//
// Feature 085 (A11-P04) T-A11-404 (FR-A11-430; SC-A11-401, SC-A11-403, SC-A11-404, SC-A11-405; research D5):
// thirty-three fixtures and schema 4; the rejection scenario's `a11.no-tutorial` and fractional preset and tutorial refusals;
// fixtures 27–33 ending in the states they name: the pendulum swinging with its energy within 5 %, the spring chain's
// energy never rising by more than 0.5 % between seconds and ending below its start, the stack standing, reset
// returning to the pendulum exactly, both tutorials completed and ended, and the stored schema-3 example restoring to
// the fixture's world and generator with origin free play.
//
// Feature 086 (A11-P05) T-A11-505 (FR-A11-501, FR-A11-502, FR-A11-510; SC-A11-501, SC-A11-505; research D4):
// thirty-eight fixtures and schema 5; fixtures 34–38 ending in the states they name: the stress session finite, valid
// and inside the stage after every step with 48 bodies, the stack asleep, the settled stack woken by the falling
// circle, the replay across quality giving the same digest with the engine's tier changed during the run, and the
// stored schema-4 example restoring to the fixture's worlds, generator, origin and tutorial.
import Foundation
import Testing
@testable import PhysicsPlaygroundExperience
import PhysicsPlaygroundCore
import VisualCoreExperience
import VisualCoreMath
import VisualCoreSimulation

private let id = ExperienceID(rawValue: PlaygroundCore.experienceID)!

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func play(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String) {
    var engine = ExperienceEngine<PlaygroundCore>(id: id)
    try await engine.prepare(seed: spec.seed)
    try engine.activate()
    let initial = try engine.digest().hex
    var results: [String] = []
    for entry in spec.entries {
        try engine.run(steps: entry.steps)
        if let action = entry.action {
            results.append(engine.handle(control: action.control, values: action.values).code)
        }
    }
    return (initial, results, try engine.digest().hex)
}

/// The core after `entries`, checking `check` after every host step.
private func stepped(_ entries: [ScenarioStep], seed: UInt64 = PlaygroundCore.manifestSeed,
                     check: (PlaygroundCore) -> Void) -> PlaygroundCore {
    var core = PlaygroundCore(seed: seed)
    var step = 0
    for entry in entries {
        for _ in 0..<entry.steps {
            core.update(step: step)
            step += 1
            check(core)
        }
        if let action = entry.action {
            _ = core.apply(ExperienceAction(control: action.control, values: action.values, step: step))
        }
    }
    return core
}

@Suite struct PlaygroundManifestTests {
    @Test func theManifestIsValidWithTheNineStandardScenariosAndThirtyEightFixtures() throws {
        let manifest = PlaygroundCore.manifest(for: id)
        let problems = ScenarioManifestValidator.problems(manifest, controls: PlaygroundCore.controls,
                                                          content: ContentRequirement(fixtures: 38))
        #expect(problems.isEmpty, "\(problems)")
        #expect(Set(manifest.scenarios.map(\.name))
                == Set(ScenarioManifest.standardNames).union((1...38).map { "fixture-\($0)" }))
        let used = Set(manifest.scenarios.flatMap { $0.entries.compactMap { $0.action?.control } })
        #expect(used.isSuperset(of: ["world.gravity", "world.drag", "world.stiffness"]), "the level actions are played")
        #expect(used == Set(PlaygroundCore.actionIDs), "every action is played")
        let rejection = try #require(manifest.scenarios.first { $0.name == "rejection" })
        let codes = Set(rejection.entries.compactMap(\.result))
        for rule in [PlaygroundRule.noRoom, PlaygroundRule.unknownBody, PlaygroundRule.notGrabbable,
                     PlaygroundRule.noGrab, PlaygroundRule.staticBody, PlaygroundRule.noSelection,
                     PlaygroundRule.noTutorial] {
            #expect(codes.contains("action.rule." + rule), "the rejection scenario refuses with \(rule)")
        }
        #expect(manifest.kind == .creative)
        #expect(manifest.experience == id)
    }

    @Test func derivedDigestsAndResultsAreWhatTheEngineGives() async throws {
        let manifest = PlaygroundCore.manifest(for: id)
        #expect(manifest.scenarios.first { $0.name == "launch-first-frame" }?.expect.initialDigest != nil)
        for spec in manifest.scenarios {
            let played = try await play(spec)
            if let initial = spec.expect.initialDigest {
                #expect(played.initial == initial, "\(spec.name) initial: \(played.initial)")
            }
            if let final = spec.expect.finalDigest {
                #expect(played.final == final, "\(spec.name) final: \(played.final)")
            }
            let expected = spec.entries.compactMap { $0.action == nil ? nil : ($0.result ?? "accepted") }
            #expect(played.results == expected, "\(spec.name)")
        }
        let completion = try #require(manifest.scenarios.first { $0.name == "completion" })
        #expect(PlaygroundCore.played(seed: completion.seed, entries: completion.entries).outcome?.code
                == completion.expect.outcome)
    }

    @Test func theFixturesEndInTheStatesTheyName() throws {
        let seed = PlaygroundCore.manifestSeed
        let fixtures = PlaygroundCore.fixtureEntries
        let catalog = PlaygroundCore.catalog
        #expect(fixtures.count == 38)
        #expect(PlaygroundCore(seed: seed).world.bodies.count == PlaygroundCore.startingBodies)

        // 1. Free fall: the dropped circle falls under gravity for 1 s.
        let fall = PlaygroundCore.played(seed: seed, entries: fixtures[0])
        let start = PlaygroundCore.played(seed: seed, entries: Array(fixtures[0].prefix(1)))
        let dropped = try #require(fall.world.bodies.last)
        #expect(fall.world.tick == 120)
        #expect(dropped.id == start.world.bodies.last?.id)
        #expect(dropped.position.y < WorldSimulation.dropHeight - 1, "the circle fell more than a metre")

        // 2. Two-body momentum: two circles dropped; every number stays finite and the world valid.
        let two = PlaygroundCore.played(seed: seed, entries: fixtures[1])
        #expect(two.world.bodies.count == 12)
        #expect(two.world.validate(catalog: catalog).isEmpty)

        // 3. Static zero mass: the ledge never moves in 1,000 steps with bodies landing around it.
        let ledge = PlaygroundCore(seed: seed).world.bodies[0]
        #expect(ledge.isStatic)
        #expect(ledge.mass(in: catalog) == 0)
        let after = stepped(fixtures[2]) { core in
            #expect(core.world.bodies[0] == ledge)
        }
        #expect(after.world.tick == 1_000)

        // 4. Replay determinism: two plays give the same world.
        #expect(fixtures[3].compactMap(\.action).count == PlaygroundCore.recordedInputs.count)
        #expect(fixtures[3].reduce(0) { $0 + $1.steps } == PlaygroundCore.replaySteps)
        let replayA = PlaygroundCore.played(seed: seed, entries: fixtures[3])
        let replayB = PlaygroundCore.played(seed: seed, entries: fixtures[3])
        #expect(replayA == replayB)
        #expect(replayA.world.bodies.count == 14)

        // 5. Frame pacing: the same entries, so the same final state (the frame times are PlaygroundSessionTests').
        #expect(fixtures[4] == fixtures[3])
        #expect(PlaygroundCore.played(seed: seed, entries: fixtures[4]) == replayA)

        // 6. Time scale and single step: 10 ticks at ¼×, 80 at 2×, three single steps, then nothing while paused.
        let scaled = PlaygroundCore.played(seed: seed, entries: Array(fixtures[5].prefix(2)))
        #expect(scaled.world.tick == 10)
        let doubled = PlaygroundCore.played(seed: seed, entries: Array(fixtures[5].prefix(3)))
        #expect(doubled.world.tick == 90 && doubled.world.paused)
        let singles = PlaygroundCore.played(seed: seed, entries: Array(fixtures[5].prefix(6)))
        #expect(singles.world.tick == 93)
        #expect(PlaygroundCore.played(seed: seed, entries: fixtures[5]) == singles, "30 paused steps change nothing")

        // 7. Save/restore: the state round-trips through its payload and both continue alike.
        let saved = PlaygroundCore.played(seed: seed, entries: fixtures[6])
        var restored = try PlaygroundCore.restore(payload: saved.snapshotPayload(), seed: seed)
        #expect(restored == saved)
        var original = saved
        for step in 300..<450 {
            original.update(step: step)
            restored.update(step: step)
        }
        #expect(restored == original)

        // 8. Resume without catch-up: after the pause, 300 steps change nothing.
        let paused = PlaygroundCore.played(seed: seed, entries: Array(fixtures[7].prefix(2)))
        let later = PlaygroundCore.played(seed: seed, entries: fixtures[7])
        #expect(paused.world.paused && paused.world.tick == 60)
        #expect(later == paused, "no motion while paused")

        // 9. Catalog: the bundled catalog validates and every body names one of its materials.
        let decoded = MaterialCatalog.decode(catalog.encoded())
        #expect(decoded.refused.isEmpty && decoded.catalog == catalog)
        let materials = PlaygroundCore.played(seed: seed, entries: fixtures[8]).world
        #expect(materials.bodies.count == 14)
        for body in materials.bodies { #expect(catalog.material(id: body.materialId) != nil) }

        // 10. Body cap: 38 drops fill the world to 48 bodies, the 39th is refused, and the world stays valid.
        #expect(PlaygroundCore.capDrops == 38)
        let capEntries = fixtures[9]
        #expect(capEntries.compactMap(\.action).count == PlaygroundCore.capDrops + 2)
        #expect(capEntries.compactMap(\.result).suffix(2) == ["action.rule." + PlaygroundRule.bodyCap,
                                                              "action.rule." + PlaygroundRule.bodyCap])
        #expect(capEntries.compactMap(\.action).last?.control == "edit.add", "an add is refused at the cap too")
        let full = stepped(capEntries) { core in
            #expect(core.world.bodies.count <= PhysicsWorld.maxBodies)
        }
        #expect(full.world.bodies.count == PhysicsWorld.maxBodies)
        #expect(full.world.validate(catalog: catalog).isEmpty)
    }

    /// The current stretch L − L₀ of spring `index` of `world`.
    private func stretch(_ world: PhysicsWorld, _ index: Int) throws -> Double {
        let spring = world.springs[index]
        let a = try #require(world.anchorPosition(spring.a)), b = try #require(world.anchorPosition(spring.b))
        return (b - a).length - spring.restLength
    }

    /// The stiffness k' the hanging box (wood, half-size 0.3 m) uses at `level`: the level's value clamped to the
    /// stable bound 0.1·m/dt².
    private func hangingStiffness(_ level: Int) -> Double {
        let mass = 0.6 * 0.36
        return min(ForceLevels.stiffness[level], Springs2D.stableStiffness(effectiveMass: mass, dt: 1.0 / 120))
    }

    @Test func theSpringAndLevelFixturesEndInTheStatesTheyName() throws {
        let seed = PlaygroundCore.manifestSeed
        let fixtures = PlaygroundCore.fixtureEntries
        let catalog = PlaygroundCore.catalog
        let boxMass = 0.6 * 0.36
        for (index, entries) in fixtures.enumerated().dropFirst(10) {
            let world = PlaygroundCore.played(seed: seed, entries: entries).world
            #expect(world.validate(catalog: catalog).isEmpty, "fixture \(index + 1)")
            #expect(world.isFinite, "fixture \(index + 1)")
        }

        // 11. Resting pile: five boxes dropped under high drag come to rest in contact after 10 s.
        let pile = PlaygroundCore.played(seed: seed, entries: fixtures[10]).world
        #expect(pile.bodies.count == PlaygroundCore.startingBodies + 5)
        #expect(pile.dragLevel == 2)
        // Since feature 086 (A11-P05) a settled pile falls asleep and stops holding contacts; it either still holds
        // contact impulses or every dynamic body sleeps.
        // (The anchored hanging box of the starting scene never sleeps and touches nothing, so only the five dropped
        // boxes are looked at.)
        let restingAwake = pile.bodies.suffix(5).filter { !$0.asleep }
        #expect(!pile.contactCache.isEmpty || restingAwake.isEmpty, "the dropped boxes hold contact impulses or sleep")
        let fastest = pile.bodies.filter { !$0.isStatic }.map(\.velocity.length).max() ?? 0
        #expect(fastest < 0.05, "every body at rest: \(fastest) m/s")

        // 12. Spring equilibrium at level 2: the hanging box rests within 2 % of m·g/k'.
        let equilibrium = PlaygroundCore.played(seed: seed, entries: fixtures[11]).world
        #expect(equilibrium.stiffnessLevel == 2 && equilibrium.tick == PlaygroundCore.settleSteps)
        let expected12 = boxMass * 9.81 / hangingStiffness(2)
        let measured12 = try stretch(equilibrium, 0)
        #expect(abs(measured12 - expected12) <= 0.02 * expected12, "\(measured12) vs \(expected12)")

        // 13. Spring energy without gravity and drag: the total energy never rises above its value at the switch.
        let atSwitch = PlaygroundCore.played(seed: seed, entries: Array(fixtures[12].prefix(2)))
        #expect(atSwitch.world.tick == PlaygroundCore.energyLeadSteps)
        #expect(atSwitch.world.settings.gravity.length == 0 && atSwitch.world.settings.linearDrag == 0)
        let start13 = WorldDiagnostics.totalEnergy(atSwitch.world, catalog: catalog)
        #expect(WorldDiagnostics.springPotentialEnergy(atSwitch.world, catalog: catalog) > 0, "stretched springs")
        var highest = 0.0
        let end13 = stepped(fixtures[12]) { core in
            guard core.world.tick > PlaygroundCore.energyLeadSteps else { return }
            highest = max(highest, WorldDiagnostics.totalEnergy(core.world, catalog: catalog))
        }
        #expect(highest <= start13, "\(highest) J never above \(start13) J")
        #expect(WorldDiagnostics.totalEnergy(end13.world, catalog: catalog) < start13)

        // 14. Damped spring energy: soft springs and high drag; the hanging box's motion dies away.
        var peak = 0.0
        let end14 = stepped(fixtures[13]) { core in
            let v = core.world.bodies[7].velocity.length
            peak = max(peak, 0.5 * boxMass * v * v)
        }
        let box14 = end14.world.bodies[7].velocity.length
        #expect(end14.world.stiffnessLevel == 0 && end14.world.dragLevel == 2)
        #expect(peak > 0 && 0.5 * boxMass * box14 * box14 < 0.001 * peak, "the box's kinetic energy died away")

        // 15. Stiffness clamp: 400 N/m is above the hanging box's and the joined circles' bounds; the box rests at the
        // clamped stretch.
        let clamp = PlaygroundCore.played(seed: seed, entries: fixtures[14]).world
        #expect(WorldSimulation.springStiffness(clamp) == 400)
        #expect(hangingStiffness(3) < 400, "the bound is below the level")
        let circleMass = 1.2 * Double.pi * 0.3 * 0.3
        #expect(Springs2D.stableStiffness(effectiveMass: circleMass / 2, dt: 1.0 / 120) < 400)
        let expected15 = boxMass * 9.81 / hangingStiffness(3)
        let measured15 = try stretch(clamp, 0)
        #expect(abs(measured15 - expected15) <= 0.02 * expected15, "\(measured15) vs \(expected15)")

        // 16. Broad phase equals all pairs: the same ticks with every pair tested give the identical world.
        let dropped = PlaygroundCore.played(seed: seed, entries: Array(fixtures[15].prefix(6)))
        var reference = dropped.world
        for _ in 0..<PlaygroundCore.broadPhaseSteps {
            #expect(WorldSimulation.tick(&reference, catalog: catalog, pairing: .allPairs))
        }
        let broad = PlaygroundCore.played(seed: seed, entries: fixtures[15]).world
        #expect(broad.bodies.count == PlaygroundCore.startingBodies + 6)
        #expect(broad == reference)

        // 17. Gravity and drag levels: Moon without drag accelerates the dropped circle at 1.62 m/s² (it falls freely
        // for 1 s); gravity off with high drag slows it as (1/(1 + dt))^120 ≈ e^(−1); Earth and low drag at the end.
        let moon = PlaygroundCore.played(seed: seed, entries: Array(fixtures[16].prefix(4)))
        #expect(moon.world.gravityLevel == 0 && moon.world.settings.gravity.length == 0)
        let fallen = try #require(moon.world.bodies.last)
        #expect(abs(fallen.velocity.y + 1.62) <= 0.01 * 1.62, "\(fallen.velocity.y)")
        let slowed = PlaygroundCore.played(seed: seed, entries: Array(fixtures[16].prefix(6)))
        #expect(slowed.world.dragLevel == 2 && slowed.world.settings.linearDrag == 1)
        let ratio = (slowed.world.bodies.last?.velocity.length ?? 0) / fallen.velocity.length
        let decay: Double = pow(1.0 / (1.0 + 1.0 / 120.0), 120.0)
        #expect(abs(ratio - decay) <= 0.01 * decay, "\(ratio) vs \(decay)")
        let restored17 = PlaygroundCore.played(seed: seed, entries: fixtures[16]).world
        #expect(restored17.settings == WorldSettings(), "Earth and low drag")

        // 18. Schema-1 migration: the stored example restores through the step 1 → 2 with the generator and the
        // dropped bodies the fixture's actions draw, no springs and the default levels, and it then plays on.
        let paused18 = PlaygroundCore.played(seed: seed, entries: Array(fixtures[17].prefix(4)))
        #expect(paused18.world.paused && paused18.world.timeScaleIndex == 1 && paused18.world.tick == 0)
        let example = try #require(PlaygroundCore.schemaOneExample(seed: seed))
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        #expect(snapshot.schemaVersion == 1 && snapshot.seed == seed)
        let object = try #require(try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8)) as? [String: Any])
        let upgraded = try PlaygroundCore.migrations.migrate(object, from: 1)
        var migrated = try PlaygroundCore.restore(
            payload: JSONSerialization.data(withJSONObject: upgraded, options: [.sortedKeys]), seed: seed)
        #expect(migrated.world.springs.isEmpty && migrated.world.contactCache.isEmpty)
        #expect(migrated.world.gravityLevel == ForceLevels.defaultGravityLevel)
        #expect(migrated.world.dragLevel == ForceLevels.defaultDragLevel)
        #expect(migrated.world.stiffnessLevel == ForceLevels.defaultStiffnessLevel)
        #expect(migrated.generator == paused18.generator, "the same draws: a scene of six bodies and two drops")
        for (old, new) in zip(migrated.world.bodies.suffix(2), paused18.world.bodies.suffix(2)) {
            #expect(old.shape == new.shape && old.materialId == new.materialId)
            #expect(old.position == new.position && old.angle == new.angle)
        }
        #expect(migrated.world.paused == paused18.world.paused)
        #expect(migrated.world.timeScaleIndex == paused18.world.timeScaleIndex)
        _ = migrated.apply(ExperienceAction(control: "world.pause", values: [0], step: 0))
        for step in 0..<60 { migrated.update(step: step) }
        #expect(migrated.world.validate(catalog: catalog).isEmpty && migrated.world.tick == 30)
        let played18 = PlaygroundCore.played(seed: seed, entries: fixtures[17]).world
        #expect(played18.tick == 30 && !played18.paused)
    }

    /// T-A11-304 (FR-A11-321; SC-A11-302, SC-A11-303, SC-A11-305): fixtures 19–26 end in the states they name.
    @Test func theEditingFixturesEndInTheStatesTheyName() throws {
        let seed = PlaygroundCore.manifestSeed
        let fixtures = PlaygroundCore.fixtureEntries
        let catalog = PlaygroundCore.catalog
        let circle = PlaygroundCore.firstCircleId, box = PlaygroundCore.hangingBoxId
        let start = PlaygroundCore(seed: seed).world
        #expect(start.bodies[box].id == box && start.bodies[circle].id == circle)
        #expect(start.bodies[circle].position == StartingScene.pairCenters.0)

        // 19. Add at a point: a circle and a box, centred at their points, then they fall.
        let added = PlaygroundCore.played(seed: seed, entries: Array(fixtures[18].prefix(2))).world
        #expect(added.bodies.count == PlaygroundCore.startingBodies + 2)
        let newCircle = try #require(added.bodies.first { $0.id == 10 })
        let newBox = try #require(added.bodies.first { $0.id == 11 })
        #expect(newCircle.position == PlaygroundCore.addPoints.circle)
        #expect(newBox.position == PlaygroundCore.addPoints.box)
        if case .circle = newCircle.shape {} else { Issue.record("body 10 is a circle") }
        if case .box = newBox.shape {} else { Issue.record("body 11 is a box") }
        let fallen = PlaygroundCore.played(seed: seed, entries: fixtures[18]).world
        #expect(try #require(fallen.bodies.first { $0.id == 11 }).position.y < PlaygroundCore.addPoints.box.y)

        // 20. Grab, move and release: held for 1 s the circle comes near its target; let go, it keeps its velocity.
        let held = PlaygroundCore.played(seed: seed,
                                         entries: Array(fixtures[19].prefix(3)) + [ScenarioStep(steps: 120)])
        let grab = try #require(held.world.grab)
        #expect(grab.bodyId == circle && grab.target == PlaygroundCore.grabTargets[1])
        let heldBody = try #require(held.world.bodies.first { $0.id == circle })
        let anchor = heldBody.pose.toWorld(grab.localAnchor)
        #expect((anchor - grab.target).length < 0.05, "within 5 cm of the target: \((anchor - grab.target).length)")
        let released = PlaygroundCore.played(seed: seed, entries: Array(fixtures[19].prefix(4)))
        #expect(released.world.grab == nil)
        let atRelease = try #require(released.world.bodies.first { $0.id == circle })
        #expect(atRelease.velocity == heldBody.velocity, "the release changes no velocity")

        // 21. Pin with impacts: the pinned circle never moves while the added bodies land on it.
        let pinnedStart = PlaygroundCore.played(seed: seed, entries: Array(fixtures[20].prefix(3)))
        let pinned = try #require(pinnedStart.world.bodies.first { $0.id == circle })
        #expect(pinned.pinned && pinned.velocity == .zero)
        var touched = false
        let hit = stepped(fixtures[20]) { core in
            guard let body = core.world.bodies.first(where: { $0.id == circle }) else {
                Issue.record("the pinned circle is gone")
                return
            }
            #expect(body.position == pinned.position && body.angle == pinned.angle)
            #expect(body.velocity == .zero && body.angularVelocity == 0)
            #expect(core.world.isFinite)
            if core.world.contactCache.contains(where: { ($0.bodyA == circle || $0.bodyB == circle)
                && ($0.bodyA >= 10 || $0.bodyB >= 10) }) { touched = true }
        }
        #expect(hit.world.tick == PlaygroundCore.pinSteps)
        #expect(touched, "an added body landed on the pinned circle")
        #expect(hit.world.validate(catalog: catalog).isEmpty)

        // 22. Unpin and fall: pinned for 60 steps it stays; unpinned it falls.
        let stillPinned = PlaygroundCore.played(seed: seed, entries: Array(fixtures[21].prefix(1))
                                                + [ScenarioStep(steps: 60)])
        let stayed = try #require(stillPinned.world.bodies.first { $0.id == circle })
        #expect(stayed.position == start.bodies[circle].position)
        let unpinned = PlaygroundCore.played(seed: seed, entries: fixtures[21]).world
        let free = try #require(unpinned.bodies.first { $0.id == circle })
        #expect(!free.pinned && free.position.y < start.bodies[circle].position.y - 0.05, "it fell: \(free.position.y)")

        // 23. Delete with springs: both springs and the selection go with their bodies.
        let selected = PlaygroundCore.played(seed: seed, entries: Array(fixtures[22].prefix(1))).world
        #expect(selected.selectedId == box)
        let deleted = PlaygroundCore.played(seed: seed, entries: fixtures[22]).world
        #expect(deleted.bodies.count == PlaygroundCore.startingBodies - 2)
        #expect(!deleted.bodies.contains { $0.id == box || $0.id == circle })
        #expect(deleted.springs.isEmpty && deleted.selectedId == nil)
        #expect(!deleted.contactCache.contains { [box, circle].contains($0.bodyA) || [box, circle].contains($0.bodyB) })

        // 24. Selection and nudge: the selected circle gains (1, 1) + (−0.5, 1) m/s at once.
        let before24 = PlaygroundCore.played(seed: seed, entries: Array(fixtures[23].prefix(1))).world
        let nudged = PlaygroundCore.played(seed: seed, entries: Array(fixtures[23].prefix(3))).world
        let other = PlaygroundCore.secondCircleId
        let v0 = try #require(before24.bodies.first { $0.id == other }).velocity
        let v1 = try #require(nudged.bodies.first { $0.id == other }).velocity
        #expect(abs(v1.x - v0.x - 0.5) < 1e-12 && abs(v1.y - v0.y - 2) < 1e-12)
        #expect(PlaygroundCore.played(seed: seed, entries: fixtures[23]).world.selectedId == other)

        // 25. Overlays on and off: the world equals the same steps without them except for the flags.
        let overlays = PlaygroundCore.played(seed: seed, entries: fixtures[24]).world
        #expect(!overlays.showVelocity && overlays.showForces)
        var plain = PlaygroundCore.played(seed: seed, entries: [ScenarioStep(steps: 120)]).world
        plain.showForces = true
        #expect(overlays == plain)

        // 26. Schema-2 migration: the stored example restores to the world the fixture's actions give.
        let paused26 = PlaygroundCore.played(seed: seed, entries: Array(fixtures[25].prefix(7)))
        #expect(paused26.world.paused && paused26.world.tick == 0)
        let example = try #require(PlaygroundCore.schemaTwoExample(seed: seed))
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        #expect(snapshot.schemaVersion == 2 && snapshot.seed == seed)
        let object = try #require(try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8)) as? [String: Any])
        let upgraded = try PlaygroundCore.migrations.migrate(object, from: 2)
        var migrated = try PlaygroundCore.restore(
            payload: JSONSerialization.data(withJSONObject: upgraded, options: [.sortedKeys]), seed: seed)
        #expect(migrated.world == paused26.world && migrated.generator == paused26.generator,
                "the same world and generator")
        _ = migrated.apply(ExperienceAction(control: "world.pause", values: [0], step: 0))
        for step in 0..<60 { migrated.update(step: step) }
        let played26 = PlaygroundCore.played(seed: seed, entries: fixtures[25])
        #expect(migrated.world == played26.world && played26.world.tick == 30)
    }

    /// T-A11-404 (FR-A11-430; SC-A11-401, SC-A11-403, SC-A11-404): fixtures 27–33 end in the states they name.
    @Test func theExperimentFixturesEndInTheStatesTheyName() throws {
        let seed = PlaygroundCore.manifestSeed
        let fixtures = PlaygroundCore.fixtureEntries
        let catalog = PlaygroundCore.catalog
        func energy(_ core: PlaygroundCore) -> Double { WorldDiagnostics.totalEnergy(core.world, catalog: catalog) }

        // 27. Pendulum: the bob swings; without drag the total energy stays within 5 % of the start.
        let pendulumStart = PlaygroundCore.played(seed: seed, entries: Array(fixtures[26].prefix(1)))
        #expect(pendulumStart.origin == .preset(PresetID.pendulum.rawValue))
        #expect(pendulumStart.world == pendulumStart.startingWorld)
        let start27 = energy(pendulumStart)
        let pendulum = stepped(fixtures[26]) { core in
            #expect(abs(energy(core) - start27) <= 0.05 * abs(start27))
        }
        #expect(pendulum.world.tick == PlaygroundCore.presetSteps)
        let bob = try #require(pendulum.world.bodies.first { $0.id == 1 })
        #expect(bob.position != pendulumStart.world.bodies[1].position, "the bob swings")

        // 28. Spring chain: energy sampled each second never rises by more than 0.5 % and ends below its start.
        let chainStart = PlaygroundCore.played(seed: seed, entries: Array(fixtures[27].prefix(1)))
        var samples = [energy(chainStart)]
        let chain = stepped(fixtures[27]) { core in
            if core.world.tick > 0, core.world.tick.isMultiple(of: 120) { samples.append(energy(core)) }
        }
        #expect(samples.count == 11)
        for (before, after) in zip(samples, samples.dropFirst()) {
            #expect(after - before <= 0.005 * abs(before), "\(before) → \(after)")
        }
        #expect(try #require(samples.last) < samples[0])
        #expect(chain.world.springs.count == Presets.chainCount && chain.world.isFinite)

        // 29. Stacked objects: the stack stands on the floor.
        let stack = PlaygroundCore.played(seed: seed, entries: fixtures[28])
        #expect(stack.origin == .preset(PresetID.stackedObjects.rawValue))
        for (index, body) in stack.world.bodies.enumerated() {
            #expect(abs(body.position.x - Presets.stackX) < 0.05, "box \(index) stays in the stack")
            #expect(abs(body.position.y - Presets.stackHalfSize * Double(2 * index + 1)) < 0.05)
        }

        // 30. Reset to the experiment after edits and time controls.
        let beforeReset = PlaygroundCore.played(seed: seed, entries: Array(fixtures[29].dropLast()))
        #expect(beforeReset.world.paused && beforeReset.world.bodies.count == 3 && beforeReset.world.gravityLevel == 1)
        let reset = PlaygroundCore.played(seed: seed, entries: fixtures[29])
        #expect(reset.world == reset.startingWorld)
        #expect(reset.world == PlaygroundCore.played(seed: seed, entries: Array(fixtures[29].prefix(1))).world)
        #expect(!reset.world.paused && reset.world.timeScaleIndex == PhysicsWorld.normalTimeScaleIndex)
        #expect(reset.world.grab == nil && reset.world.selectedId == nil)

        // 31. "Controlling time" completes through its actions, step by step.
        for (count, step) in [(1, 0), (2, 1), (3, 2), (4, 3)] {
            let partial = PlaygroundCore.played(seed: seed, entries: Array(fixtures[30].prefix(count)))
            #expect(partial.tutorial?.tutorial == 0 && partial.tutorial?.step == step, "after \(count) entries")
        }
        let time = PlaygroundCore.played(seed: seed, entries: fixtures[30])
        #expect(time.tutorial == nil && time.world.tick == 30)

        // 32. "Springs and energy" completes when the chain opens, the arrows show and 3 s pass.
        let opened = PlaygroundCore.played(seed: seed, entries: Array(fixtures[31].prefix(3)))
        #expect(opened.tutorial == TutorialProgress(tutorial: 1, step: 2, startTick: 0))
        let springs = PlaygroundCore.played(seed: seed, entries: fixtures[31])
        #expect(springs.tutorial == nil && springs.world.showForces && springs.world.tick == Tutorials.runTicks)

        // 33. Schema-3 migration: the stored example restores to the fixture's world and generator, free play.
        let count = PlaygroundCore.schemaThreeExampleActions.count
        let paused33 = PlaygroundCore.played(seed: seed, entries: Array(fixtures[32].prefix(count)))
        #expect(paused33.world.paused && paused33.world.tick == 0 && paused33.world.grab != nil)
        let example = try #require(PlaygroundCore.schemaThreeExample(seed: seed))
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        #expect(snapshot.schemaVersion == 3 && snapshot.seed == seed)
        let object = try #require(try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8)) as? [String: Any])
        let upgraded = try PlaygroundCore.migrations.migrate(object, from: 3)
        var migrated = try PlaygroundCore.restore(
            payload: JSONSerialization.data(withJSONObject: upgraded, options: [.sortedKeys]), seed: seed)
        #expect(migrated.world == paused33.world && migrated.generator == paused33.generator)
        #expect(migrated.origin == .freePlay && migrated.tutorial == nil)
        #expect(migrated.startingWorld == ExperimentDocument.withoutEditing(paused33.world))
        _ = migrated.apply(ExperienceAction(control: "world.pause", values: [0], step: 0))
        for step in 0..<60 { migrated.update(step: step) }
        let played33 = PlaygroundCore.played(seed: seed, entries: fixtures[32])
        #expect(migrated.world == played33.world && played33.world.tick == 30)
    }

    /// T-A11-505 (FR-A11-501, FR-A11-502; SC-A11-501): fixtures 34–36 end in the states they name.
    @Test func theStabilityFixturesEndInTheStatesTheyName() throws {
        let seed = PlaygroundCore.manifestSeed
        let fixtures = PlaygroundCore.fixtureEntries
        let catalog = PlaygroundCore.catalog

        // 34. Stress: every value finite, the world valid (caps, speeds, stage) after every step; 48 bodies.
        var invalidSteps = 0
        let stress = stepped(fixtures[33]) { core in
            if !core.world.isFinite || !core.world.validate(catalog: catalog).isEmpty { invalidSteps += 1 }
        }
        #expect(invalidSteps == 0)
        #expect(stress.world.bodies.count == PhysicsWorld.maxBodies)
        #expect(stress.world.stiffnessLevel == 3 && stress.world.tick == PlaygroundCore.stressSteps)
        #expect(stress.world.selectedId == PlaygroundCore.firstCircleId)
        let stage = stress.world.settings.stageSize
        for body in stress.world.bodies {
            #expect((0...stage.x).contains(body.position.x) && (0...stage.y).contains(body.position.y),
                    "body \(body.id) inside the stage")
        }

        // 35. Settle to sleep: every box of the stack is asleep and at rest.
        let settled = PlaygroundCore.played(seed: seed, entries: fixtures[34])
        #expect(settled.origin == .preset(PresetID.stackedObjects.rawValue))
        #expect(settled.world.tick == PlaygroundCore.sleepSteps)
        #expect(settled.world.bodies.count == Presets.stackCount)
        for body in settled.world.bodies {
            #expect(body.asleep && body.velocity == .zero && body.angularVelocity == 0, "box \(body.id) sleeps")
        }

        // 36. Wake by a hit: the settled stack sleeps when the circle is added; the falling circle wakes it.
        let added = PlaygroundCore.played(seed: seed, entries: Array(fixtures[35].prefix(2)))
        #expect(added.world.bodies.count == Presets.stackCount + 1)
        #expect(added.world.bodies.prefix(Presets.stackCount).allSatisfy { $0.asleep }, "the stack sleeps")
        let circle = try #require(added.world.bodies.last)
        #expect(!circle.asleep && circle.position == PlaygroundCore.wakePoint)
        let top = try #require(added.world.bodies.prefix(Presets.stackCount).last).id
        var woken = false
        let hit = stepped(fixtures[35]) { core in
            if core.world.tick > PlaygroundCore.sleepSteps,
               let box = core.world.bodies.first(where: { $0.id == top }), !box.asleep { woken = true }
        }
        #expect(woken, "the top box woke when the circle reached it")
        #expect(hit.world.validate(catalog: catalog).isEmpty)
        #expect(hit.world.tick == PlaygroundCore.sleepSteps + PlaygroundCore.wakeSteps)
    }

    /// T-A11-505 (FR-A11-510; SC-A11-505): fixture 37 gives the same digest when the engine's quality tier changes
    /// during the run, and the overlays change nothing but their flags; fixture 38 restores the stored schema-4
    /// example to the fixture's worlds, generator, origin and tutorial.
    @Test func theQualityAndMigrationFixturesEndInTheStatesTheyName() async throws {
        let seed = PlaygroundCore.manifestSeed
        let fixtures = PlaygroundCore.fixtureEntries
        let spec = try #require(PlaygroundCore.manifest(for: id).scenarios.first { $0.name == "fixture-37" })

        // 37. Replay across quality: the tier changes at every overlay action; the digest is the manifest's.
        var engine = ExperienceEngine<PlaygroundCore>(id: id)
        try await engine.prepare(seed: seed)
        try engine.activate()
        var tiers = PlaygroundCore.qualityFixtureTiers.makeIterator()
        for entry in fixtures[36] {
            try engine.run(steps: entry.steps)
            guard let action = entry.action else { continue }
            if action.control.hasPrefix("overlay."), let tier = tiers.next() {
                try engine.setQualityTier(tier)
                #expect(engine.qualityTier == tier)
            }
            #expect(engine.handle(control: action.control, values: action.values).isAccepted, "\(action.control)")
        }
        #expect(tiers.next() == nil, "every tier was set")
        #expect(try engine.digest().hex == spec.expect.finalDigest)
        let tiered = try #require(engine.core)
        #expect(tiered == PlaygroundCore.played(seed: seed, entries: fixtures[36]))
        var replay = PlaygroundCore.played(seed: seed, entries: PlaygroundCore.replayEntries()).world
        #expect(!tiered.world.showVelocity && !tiered.world.showForces, "both overlays end off")
        replay.showVelocity = tiered.world.showVelocity
        replay.showForces = tiered.world.showForces
        #expect(tiered.world == replay, "the overlays change nothing but their flags")

        // 38. Schema-4 migration: the stored example restores to the fixture's worlds, generator, origin and tutorial.
        let count = PlaygroundCore.schemaFourExampleActions.count
        let paused38 = PlaygroundCore.played(seed: seed, entries: Array(fixtures[37].prefix(count)))
        #expect(paused38.world.paused && paused38.world.tick == 0 && paused38.tutorial != nil)
        #expect(paused38.origin == .preset(PresetID.springChain.rawValue))
        let example = try #require(PlaygroundCore.schemaFourExample(seed: seed))
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        #expect(snapshot.schemaVersion == 4 && snapshot.seed == seed)
        let object = try #require(try JSONSerialization.jsonObject(with: Data(snapshot.payload.utf8)) as? [String: Any])
        let upgraded = try PlaygroundCore.migrations.migrate(object, from: 4)
        var migrated = try PlaygroundCore.restore(
            payload: JSONSerialization.data(withJSONObject: upgraded, options: [.sortedKeys]), seed: seed)
        #expect(migrated == paused38, "the same worlds, generator, origin and tutorial")
        #expect(migrated.world.schema == PhysicsWorld.schemaVersion)
        #expect(migrated.startingWorld.schema == PhysicsWorld.schemaVersion)
        _ = migrated.apply(ExperienceAction(control: "world.pause", values: [0], step: 0))
        for step in 0..<60 { migrated.update(step: step) }
        let played38 = PlaygroundCore.played(seed: seed, entries: fixtures[37])
        #expect(migrated.world == played38.world && played38.world.tick == 30)
        #expect(migrated.tutorial == played38.tutorial)
    }

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1`
    /// rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        let manifest = PlaygroundCore.manifest(for: id)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = PlaygroundCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
