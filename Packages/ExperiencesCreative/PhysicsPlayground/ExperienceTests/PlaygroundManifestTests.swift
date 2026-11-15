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
    @Test func theManifestIsValidWithTheNineStandardScenariosAndEighteenFixtures() {
        let manifest = PlaygroundCore.manifest(for: id)
        let problems = ScenarioManifestValidator.problems(manifest, controls: PlaygroundCore.controls,
                                                          content: ContentRequirement(fixtures: 18))
        #expect(problems.isEmpty, "\(problems)")
        #expect(Set(manifest.scenarios.map(\.name))
                == Set(ScenarioManifest.standardNames).union((1...18).map { "fixture-\($0)" }))
        let used = Set(manifest.scenarios.flatMap { $0.entries.compactMap { $0.action?.control } })
        #expect(used.isSuperset(of: ["world.gravity", "world.drag", "world.stiffness"]), "the level actions are played")
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
        #expect(fixtures.count == 18)
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
        #expect(capEntries.compactMap(\.action).count == PlaygroundCore.capDrops + 1)
        #expect(capEntries.compactMap(\.result).last == "action.rule." + PlaygroundRule.bodyCap)
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
        #expect(!pile.contactCache.isEmpty, "the resting bodies hold contact impulses")
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
