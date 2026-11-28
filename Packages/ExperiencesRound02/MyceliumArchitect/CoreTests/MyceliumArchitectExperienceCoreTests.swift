// MyceliumArchitectExperienceCoreTests — feature 513 (R02-G22-03) T-R02G2203-002 (FR-R02G2203-003, 004, 005, 008, 009;
// SC-R02G2203-002, 004; clarifications Q4, Q5; research R10–R12). The adapter of Mycelium Architect's kernel to the
// shared experience contract: the ten controls with their declared ranges; every control accepted and refused as stated
// (the engine's range and count refusals, `r02-g22.not-whole`, the kernel's own codes, `r02-g22.pulse` without touching
// the kernel); the shown pulse reset to the pulses run after every other accepted action and kept by a refusal; the
// digest (domain `r02-g22.mycelium-architect.v1`: level number and play fingerprint) unchanged across 200 seeded
// snapshots (seed 2_513) under tier changes, time steps and shown-pulse changes, and every snapshot equal to the
// kernel's report; snapshot schema 1 `{level, records}` restored through the kernel's replay, damaged payloads refused;
// the table of certified candidates equal to what the generator skips (recomputed in 20 groups of 5) and the pinned
// catalog digest of R02-G22-02 over the levels it names; level 1 won through the controls by its witness plan; the
// scenario manifest (standard scenarios, `full-playthrough`, `hero`, R2-G22-QA-001 … 080 and three fixtures) valid,
// equal to the committed `scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1` rewrites it) and its digests, results
// and outcomes equal to what `ExperienceEngine` gives, every acceptance row ending in the state of its family.
// Host-run (`swift test`); explicit types, plain loops (CI type-check rule). Modelled on
// `BinaryGardensExperienceCoreTests` and `BinaryGardensScenariosTests` (feature 503). Feature 515 (R02-G22-05)
// T-R02G2205-004 (clarification Q5): schema 2 `{level, mode, progress, records, tutorial}` and digest v2, fifteen
// controls, `level.next` to the next open level (no wrap; `r02-g22.locked` when none); the progression itself is tested
// in `MyceliumArchitectProgressionCoreTests`.
import Foundation
@testable import MyceliumArchitectCore
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreSimulation

/// The id of the experience.
private let coreID: ExperienceID = ExperienceID(rawValue: MyceliumArchitectExperienceCore.experienceID)!

/// The pinned catalog digest of R02-G22-02.
private let pinnedCatalogDigest: String = "3a2b82b6363ef37ad1678847640b07e33f58e2ac2127ef39e9a34ff32797b040"

/// The digest of `core` as the engine writes it.
private func digest(of core: MyceliumArchitectExperienceCore) throws -> String {
    var builder: DigestBuilder = DigestBuilder(domain: coreID.rawValue)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

#if DEBUG || VISUALCORE_AUTOMATION
/// The manifest, built once per test process (it certifies 80 levels and more).
private let builtManifest: ScenarioManifest = MyceliumArchitectExperienceCore.manifest(for: coreID)
#endif

@Suite struct MyceliumArchitectExperienceCoreTests {
    typealias Core = MyceliumArchitectExperienceCore
    typealias Cell = MyceliumArchitectCell

    /// The seed of every seeded test of this feature.
    static let seed: UInt64 = 2_513

    /// The opening of level `number`.
    static func core(_ number: Int) throws -> Core { try Core.opening(number: number) }

    /// `core` after `control` with `values`, which must be accepted.
    static func accepted(_ core: Core, _ control: String, _ values: [Double] = []) -> Core {
        var next: Core = core
        let result: ActionResult = next.apply(ExperienceAction(control: control, values: values, step: 0))
        #expect(result.isAccepted, "\(control) \(values): \(result.code)")
        return next
    }

    /// The code `core` gives `control` with `values`; checks that a refusal changes nothing, the shown pulse included.
    static func code(_ core: Core, _ control: String, _ values: [Double] = []) throws -> String {
        var next: Core = core
        let result: ActionResult = next.apply(ExperienceAction(control: control, values: values, step: 0))
        if !result.isAccepted {
            #expect(next == core && next.shownPulse == core.shownPulse, "\(control) \(values) changed the state")
            #expect(try digest(of: next) == digest(of: core))
        }
        return result.code
    }

    /// The values of `cell`.
    static func values(_ cell: Cell) -> [Double] { [Double(cell.column), Double(cell.row)] }

    @Test func theFifteenControlsAreDeclaredWithTheirRanges() {
        var ids: [String] = []
        for control in Core.controls { ids.append(control.id) }
        #expect(ids == Core.actionIDs && ids.count == 15)
        #expect(Core.experienceID == "r02-g22.mycelium-architect" && Core.schemaVersion == 2)
        #expect(Core.digestDomain == "r02-g22.mycelium-architect.v2")
        for control in Core.controls {
            switch control.id {
            case "cell.nutrient", "cell.blocker", "cell.clear":
                #expect(control.ranges == [0...31, 0...31], "\(control.id)")
            case "root.seed", "root.unseed":
                #expect(control.ranges == [0...7], "\(control.id)")
            case "growth.show":
                #expect(control.ranges == [0...128], "\(control.id)")
            case "level.select":
                #expect(control.ranges == [1...100], "\(control.id)")
            case "mode.daily":
                #expect(control.ranges == [1...9999, 1...12, 1...31], "\(control.id)")
            default:
                #expect(control.ranges.isEmpty, "\(control.id)")
            }
        }
        // Three quality tiers, best first, named as the scene's tiers.
        #expect(Core.qualityTiers == 3)
        let profile: QualityProfile = Core.qualityProfile
        var names: [String] = []
        for level in profile.levels { names.append(level.name) }
        #expect(names == ["level-0", "level-1", "level-2"])
        var tierNames: [String] = []
        for tier in MyceliumArchitectTier.all { tierNames.append(tier.name) }
        #expect(tierNames == names)
        #expect(profile.levels[0].elementShare == 1 && profile.levels[1].elementShare == 0.5)
        #expect(profile.levels[2].elementShare == 0 && profile.levels[2].effectPasses == 0)
        #expect(MyceliumArchitectPalette.hex == ["#06070A", "#2FE08A", "#E08A3C", "#7B3FB8", "#12161C"])
    }

    @Test func everyControlIsAcceptedAsStated() throws {
        let opening: Core = try Self.core(1)
        let level: MyceliumArchitectLevel = opening.play.level
        let sites: [Cell] = try #require(level.sites)
        #expect(opening.levelNumber == 1 && opening.play.stage == .playing && opening.play.actionsSpent == 0)
        #expect(opening.shownPulse == opening.play.report.pulsesRun)
        var core: Core = Self.accepted(opening, "cell.nutrient", Self.values(sites[0]))
        #expect(core.play.arrangement.nutrients == [sites[0]] && core.play.actionsSpent == 1)
        core = Self.accepted(core, "cell.blocker", Self.values(sites[1]))
        #expect(core.play.arrangement.blockers == [sites[1]] && core.play.actionsSpent == 2)
        core = Self.accepted(core, "cell.clear", Self.values(sites[0]))
        core = Self.accepted(core, "cell.clear", Self.values(sites[1]))
        #expect(core.play.arrangement.nutrients.isEmpty && core.play.arrangement.blockers.isEmpty)
        core = Self.accepted(core, "root.seed", [2])
        #expect(core.play.arrangement.seeds == [.east] && core.shownPulse == core.play.report.pulsesRun)
        #expect(core.play.report.pulsesRun > 0)
        core = Self.accepted(core, "root.unseed", [2])
        #expect(core.play.arrangement.seeds.isEmpty && core.play.actionsSpent == 6)
        core = Self.accepted(core, "play.undo")
        #expect(core.play.arrangement.seeds == [.east] && core.play.actionsSpent == 5)
        core = Self.accepted(core, "play.redo")
        #expect(core.play.arrangement.seeds.isEmpty)
        core = Self.accepted(core, "play.undo")
        // The shown pulse: every pulse 0 … the pulses run, presentation only.
        let before: String = try digest(of: core)
        let pulses: Int = core.play.report.pulsesRun
        for pulse in 0...pulses {
            let shown: Core = Self.accepted(core, "growth.show", [Double(pulse)])
            let shownDigest: String = try digest(of: shown)
            #expect(shown.shownPulse == pulse && shown == core && shownDigest == before)
            #expect(shown.snapshot(time: 0).shownPulse == pulse)
        }
        // The run wins (the arrangement of level 1's witness: seed east); the shown pulse stays presentation.
        core = Self.accepted(core, "growth.show", [0])
        core = Self.accepted(core, "growth.run")
        #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode)
        #expect(core.shownPulse == pulses, "the run shows the whole growth again")
        core = Self.accepted(core, "growth.show", [1])
        #expect(core.shownPulse == 1)
        // The next level (opened by the campaign win), a fresh play; since feature 515 no wrap from 100 to 1.
        core = Self.accepted(core, "level.next")
        #expect(core.levelNumber == 2 && core.play.actionsSpent == 0 && core.play.stage == .playing)
        #expect(core.shownPulse == core.play.report.pulsesRun && core.outcome == nil)
        #expect(try Self.code(try Self.core(100), "level.next") == "action.rule.r02-g22.locked")
    }

    @Test func everyControlIsRefusedAsStated() throws {
        let opening: Core = try Self.core(1)
        let level: MyceliumArchitectLevel = opening.play.level
        let sites: [Cell] = try #require(level.sites)
        let outOfRange: String = "action.out-of-range"
        let wrongCount: String = "action.wrong-value-count"
        let notWhole: String = "action.rule.r02-g22.not-whole"
        let kernel: String = "action.rule.r02-g22.action"
        let stage: String = "action.rule.r02-g22.stage"
        let budget: String = "action.rule.r02-g22.budget"
        let pulse: String = "action.rule.r02-g22.pulse"
        // Outside the declared ranges, non-finite values and wrong counts: refused before the kernel.
        let ranged: [(String, [Double])] = [
            ("cell.nutrient", [32, 0]), ("cell.nutrient", [-1, 0]), ("cell.blocker", [0, 32]),
            ("cell.clear", [0, -1]), ("root.seed", [8]), ("root.seed", [-1]), ("root.unseed", [8]),
            ("growth.show", [129]), ("growth.show", [-1]),
        ]
        for (control, values) in ranged {
            #expect(try Self.code(opening, control, values) == outOfRange, "\(control) \(values)")
        }
        #expect(try Self.code(opening, "root.seed", [Double.nan]) != "accepted")
        #expect(try Self.code(opening, "cell.nutrient", [Double.infinity, 0]) != "accepted")
        let counted: [(String, [Double])] = [
            ("cell.nutrient", []), ("cell.nutrient", [1]), ("cell.blocker", [1, 1, 1]), ("cell.clear", [1]),
            ("root.seed", []), ("root.unseed", [1, 1]), ("growth.run", [1]), ("play.undo", [1]), ("play.redo", [1]),
            ("level.next", [1]), ("growth.show", []), ("growth.show", [1, 1]),
        ]
        for (control, values) in counted {
            #expect(try Self.code(opening, control, values) == wrongCount, "\(control) \(values)")
        }
        // Fractions: the adapter's own code.
        let fractions: [(String, [Double])] = [
            ("cell.nutrient", [0.5, 0]), ("cell.blocker", [1, 1.5]), ("cell.clear", [2.5, 2]), ("root.seed", [0.5]),
            ("root.unseed", [6.5]), ("growth.show", [0.5]),
        ]
        for (control, values) in fractions {
            #expect(try Self.code(opening, control, values) == notWhole, "\(control) \(values)")
        }
        // The kernel's own refusals: the root, off the board (within the ranges), not a site, a clear without a placed
        // item, an unseed of a direction not seeded, nothing to undo or redo.
        #expect(try Self.code(opening, "cell.nutrient", Self.values(level.root)) == kernel)
        #expect(try Self.code(opening, "cell.blocker", Self.values(level.root)) == kernel)
        #expect(try Self.code(opening, "cell.nutrient", [31, 31]) == kernel)
        let nonSite: Cell = try #require(Core.emptyNonSite(level))
        #expect(try Self.code(opening, "cell.nutrient", Self.values(nonSite)) == kernel)
        #expect(try Self.code(opening, "cell.blocker", Self.values(nonSite)) == kernel)
        #expect(try Self.code(opening, "cell.clear", Self.values(sites[0])) == kernel)
        #expect(try Self.code(opening, "root.unseed", [0]) == kernel)
        #expect(try Self.code(opening, "play.undo") == kernel)
        #expect(try Self.code(opening, "play.redo") == kernel)
        // Limits: level 1 allows one nutrient, one blocker and one seed.
        let placed: Core = Self.accepted(Self.accepted(Self.accepted(opening, "cell.nutrient", Self.values(sites[0])),
                                                       "cell.blocker", Self.values(sites[1])), "root.seed", [2])
        #expect(try Self.code(placed, "cell.nutrient", Self.values(sites[2])) == kernel)
        #expect(try Self.code(placed, "cell.blocker", Self.values(sites[2])) == kernel)
        #expect(try Self.code(placed, "cell.nutrient", Self.values(sites[0])) == kernel, "a taken cell")
        #expect(try Self.code(placed, "root.seed", [0]) == kernel, "the seed limit")
        #expect(try Self.code(placed, "root.seed", [2]) == kernel, "already seeded")
        // A pulse above the pulses run: the adapter's code, the kernel untouched.
        let runs: Int = placed.play.report.pulsesRun
        let shownBefore: Core = Self.accepted(placed, "growth.show", [0])
        #expect(try Self.code(shownBefore, "growth.show", [Double(runs + 1)]) == pulse)
        #expect(try Self.code(shownBefore, "growth.show", [128]) == pulse)
        #expect(try Self.code(opening, "growth.show", [Double(opening.play.report.pulsesRun + 1)]) == pulse)
        // A refusal keeps the shown pulse; an accepted action shows the pulses run again.
        #expect(try Self.code(shownBefore, "cell.nutrient", Self.values(level.root)) == kernel)
        let undone: Core = Self.accepted(shownBefore, "play.undo")
        #expect(shownBefore.shownPulse == 0 && undone.shownPulse == undone.play.report.pulsesRun)
        // The budget: level 1's whole budget spent toggling a nutrient, then refused.
        var spent: Core = opening
        for index in 0..<level.budget {
            spent = Self.accepted(spent, index % 2 == 0 ? "cell.nutrient" : "cell.clear", Self.values(sites[3]))
        }
        #expect(spent.play.actionsLeft == 0)
        let next: String = level.budget % 2 == 0 ? "cell.nutrient" : "cell.clear"
        #expect(try Self.code(spent, next, Self.values(sites[3])) == budget)
        // A won play is final: arrangement actions, the run and undo are refused by stage; showing still works.
        let won: Core = Self.accepted(Self.accepted(opening, "root.seed", [2]), "growth.run")
        #expect(try Self.code(won, "cell.nutrient", Self.values(sites[0])) == stage)
        #expect(try Self.code(won, "growth.run") == stage)
        #expect(try Self.code(won, "play.undo") == stage)
        #expect(try Self.code(won, "play.redo") == stage)
        #expect(try Self.code(won, "growth.show", [Double(won.play.report.pulsesRun + 1)]) == pulse)
        // A failed play: undo returns to playing.
        let failed: Core = Self.accepted(opening, "growth.run")
        #expect(failed.play.stage == .failed && failed.outcome?.code == Core.failedCode)
        #expect(try Self.code(failed, "root.seed", [2]) == stage)
        let retried: Core = Self.accepted(failed, "play.undo")
        let retriedDigest: String = try digest(of: retried)
        let openingDigest: String = try digest(of: opening)
        #expect(retried.play.stage == .playing && retriedDigest == openingDigest)
    }

    @Test func theDigestIgnoresTierTimeAndShownPulseAcross200SeededSnapshots() throws {
        var random: SeededRandom = SeededRandom(seed: Self.seed)
        let numbers: [Int] = [1, 21, 41, 61, 81]
        var openings: [Core] = []
        for number in numbers { openings.append(try Self.core(number)) }
        var digests: Set<String> = []
        for sample in 0..<200 {
            var core: Core = openings[sample % openings.count]
            let moves: Int = random.int(0...4)
            for _ in 0..<moves {
                let legal: [MyceliumArchitectAction] = Core.legalMoves(core.play)
                guard !legal.isEmpty else { break }
                let action: MyceliumArchitectAction = legal[random.int(0...(legal.count - 1))]
                let scripted: ScriptedAction = Core.scripted(action)
                core = Self.accepted(core, scripted.control, scripted.values)
            }
            if random.int(0...4) == 0 { core = Self.accepted(core, "growth.run") }
            let base: String = try digest(of: core)
            digests.insert(base)
            let report: MyceliumArchitectReport = core.play.report
            var varied: Core = core
            for _ in 0..<3 {
                varied.setQualityTier(random.int(-1...3))
                varied.update(step: random.int(0...1_000))
                let pulse: Int = random.int(0...report.pulsesRun)
                varied = Self.accepted(varied, "growth.show", [Double(pulse)])
                let time: Double = random.double() * 600
                let snapshot: MyceliumArchitectSceneSnapshot = varied.snapshot(time: time)
                #expect(try digest(of: varied) == base, "sample \(sample)")
                #expect(varied == core && varied.renderTier == MyceliumArchitectTier.of(varied.qualityTier))
                // The snapshot is the kernel's report, the shown pulse presentation.
                #expect(snapshot.shownPulse == pulse && snapshot.time == time && snapshot.pulsesRun == report.pulsesRun)
                #expect(snapshot.grown == report.grown && snapshot.parents == report.parents)
                #expect(snapshot.totalWeight == report.totalWeight && snapshot.stage == core.play.stage)
                #expect(snapshot.arrangement == core.play.arrangement && snapshot.actionsLeft == core.play.actionsLeft)
                #expect(snapshot.fitScale == 1.9 / Double(max(core.play.level.width, core.play.level.height)))
                var shown: Int = 0
                for index in snapshot.grown.indices where snapshot.isShown(index) { shown += 1 }
                var expected: Int = 0
                for grownPulse in report.grownPulses where grownPulse <= pulse { expected += 1 }
                #expect(shown == expected, "sample \(sample)")
                for terminal in report.terminalPulses.indices {
                    let reached: Bool = report.terminalPulses[terminal].map { $0 <= pulse } ?? false
                    #expect(snapshot.isReached(terminal) == reached, "sample \(sample)")
                    if let weight = report.terminalPathWeights[terminal] {
                        let cell: Cell = core.play.level.terminals[terminal]
                        let index: Int = try #require(snapshot.grown.firstIndex(of: cell))
                        #expect(snapshot.pathWeights[index] == weight, "the kernel's path weight")
                    }
                }
            }
        }
        #expect(digests.count > 20, "the samples cover many states: \(digests.count)")
    }

    /// The fields of a schema-2 payload after its level number: campaign mode, level 1 open, no records (feature 515).
    static let restOfPayload: String = ",\"mode\":{\"mode\":\"campaign\"},"
        + "\"progress\":{\"frontier\":1,\"solved\":[]},\"records\":[]}"

    @Test func theSnapshotRoundTripsAndDamagedPayloadsAreRefused() throws {
        let opening: Core = try Self.core(1)
        let sites: [Cell] = try #require(opening.play.level.sites)
        var core: Core = Self.accepted(opening, "cell.nutrient", Self.values(sites[0]))
        core = Self.accepted(core, "root.seed", [2])
        core = Self.accepted(core, "play.undo")
        core = Self.accepted(core, "growth.show", [0])
        let payload: Data = try core.snapshotPayload()
        let object: [String: Any] = try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(Set(object.keys) == ["level", "mode", "progress", "records", "tutorial"])
        let restored: Core = try Core.restore(payload: payload, seed: Self.seed)
        let restoredDigest: String = try digest(of: restored)
        let savedDigest: String = try digest(of: core)
        #expect(restored == core && restoredDigest == savedDigest)
        #expect(restored.play.canRedo && restored.shownPulse == restored.play.report.pulsesRun)
        #expect(restored.openingNumber == Core.levelNumber(forSeed: Self.seed))
        var reset: Core = restored
        reset.reset()
        #expect(reset.levelNumber == Core.levelNumber(forSeed: Self.seed) && reset.play.actionsSpent == 0)
        // Damaged payloads change nothing and are refused with their reason.
        #expect(throws: MyceliumArchitectRestoreRefusal.damaged) {
            _ = try Core.restore(payload: Data("{\"level\":1}".utf8), seed: 0)
        }
        #expect(throws: MyceliumArchitectRestoreRefusal.damaged) {
            _ = try Core.restore(payload: Data("not json".utf8), seed: 0)
        }
        #expect(throws: MyceliumArchitectRestoreRefusal.levelNumber(0)) {
            _ = try Core.restore(payload: Data(("{\"level\":0" + Self.restOfPayload).utf8), seed: 0)
        }
        #expect(throws: MyceliumArchitectRestoreRefusal.levelNumber(101)) {
            _ = try Core.restore(payload: Data(("{\"level\":101" + Self.restOfPayload).utf8), seed: 0)
        }
        var moved: [String: Any] = object
        moved["level"] = 2
        let otherLevel: Data = try JSONSerialization.data(withJSONObject: moved, options: [.sortedKeys])
        #expect(throws: MyceliumArchitectRestoreRefusal.kernel(.malformed("seed 0"))) {
            _ = try Core.restore(payload: otherLevel, seed: 0)
        }
        // A won play restores won.
        let won: Core = Self.accepted(Self.accepted(opening, "root.seed", [2]), "growth.run")
        let back: Core = try Core.restore(payload: try won.snapshotPayload(), seed: 0)
        #expect(back == won && back.outcome?.code == Core.wonCode)
    }

    @Test func level1IsWonThroughTheControlsByItsWitnessPlan() async throws {
        #expect(Core.certifiedActions(1) == [.seed(.east)])
        var engine: ExperienceEngine<Core> = ExperienceEngine<Core>(id: coreID)
        try await engine.prepare(seed: 0)
        try engine.activate()
        for action in Core.certifiedActions(1) + [.run] {
            let scripted: ScriptedAction = Core.scripted(action)
            #expect(engine.handle(control: scripted.control, values: scripted.values).isAccepted)
        }
        let core: Core = try #require(engine.core)
        #expect(core.levelNumber == 1 && core.play.stage == .won && core.outcome?.code == Core.wonCode)
        #expect(core.play.report.terminalsReached == core.play.level.terminals.count)
    }

    @Test(arguments: 0..<20) func theCertifiedCandidateTableIsWhatTheGeneratorSkips(group: Int) throws {
        #expect(Core.certifiedCandidates.count == 100)
        for number in (5 * group + 1)...(5 * group + 5) {
            let previous: MyceliumArchitectLevel? = number > 1 ? try Core.level(number: number - 1) : nil
            let entry: MyceliumArchitectManifestEntry = MyceliumArchitectManifest.entries[number - 1]
            let generated: MyceliumArchitectGeneratedLevel = try MyceliumArchitectGenerator.generate(
                entry, previous: previous)
            #expect(generated.skipped == Core.certifiedCandidates[number - 1], "level \(number)")
            #expect(try Core.generated(number: number) == generated, "level \(number)")
        }
    }

    @Test func theTableNamesThePinnedCatalog() throws {
        var numbers: [Int] = []
        for number in Core.levelNumbers { numbers.append(number) }
        #if DEBUG || VISUALCORE_AUTOMATION
        Core.prewarm(numbers)
        #endif
        var levels: [MyceliumArchitectLevel] = []
        for number in numbers { levels.append(try Core.level(number: number)) }
        #expect(MyceliumArchitectGenerator.digest(levels) == pinnedCatalogDigest)
        #expect(Core.levelNumber(forSeed: 0) == 1 && Core.levelNumber(forSeed: 2_513) == 14)
        #expect(throws: MyceliumArchitectError.level("number")) { _ = try Core.level(number: 0) }
    }

    #if DEBUG || VISUALCORE_AUTOMATION
    @Test func theManifestIsAValidRoundTwoGame() {
        let manifest: ScenarioManifest = builtManifest
        let problems: [String] = ScenarioManifestValidator.problems(
            manifest, controls: Core.controls, content: ContentRequirement(fixtures: 3, acceptance: 80, levels: 100))
        #expect(problems.isEmpty, "\(problems)")
        var acceptanceNames: [String] = []
        var rowIDs: [String] = []
        var titles: [String] = []
        for row in 1...80 {
            acceptanceNames.append(Core.acceptanceName(row))
            rowIDs.append(Core.acceptanceRowID(row))
            titles.append(Core.acceptanceTitle(row))
        }
        #expect(rowIDs[0] == "R2-G22-QA-001" && rowIDs[79] == "R2-G22-QA-080")
        #expect(Set(rowIDs).count == 80 && Set(titles).count == 80)
        // The archived titles of rows 1, 22 and 80 (round2.md section 6.22.19).
        #expect(titles[0] == "Truth and state transitions: fresh install and zero-history start")
        #expect(titles[21] == "Numeric and geometry edge: mid-level save/resume")
        #expect(titles[79] == "Integration, privacy and devices: resume after an app process kill")
        var names: [String] = []
        for spec in manifest.scenarios { names.append(spec.name) }
        #expect(names == ScenarioManifest.standardNames + ["full-playthrough", "hero"] + acceptanceNames
            + ["fixture-level-1-solved", "fixture-run-fails", "fixture-undo-redo"])
        #expect(manifest.kind == .game && manifest.round == 2 && manifest.experience == coreID)
        // The archived rows 1 … 20 name these levels (round2.md: 074, 081, … 037, 044, 051, … 007).
        let named: [Int] = [74, 81, 88, 95, 2, 9, 16, 23, 30, 37, 44, 51, 58, 65, 72, 79, 86, 93, 100, 7]
        #expect(Array(Core.acceptanceLevels.prefix(20)) == named)
        #expect(Set(Core.acceptanceLevels).count == 80)
        var declared: Set<String> = []
        for control in Core.controls { declared.insert(control.id) }
        var used: Set<String> = []
        for spec in manifest.scenarios {
            if spec.name.hasPrefix("acceptance-") {
                #expect(spec.entries.count >= 2, "\(spec.name)")
            } else {
                #expect(spec.seed == Core.manifestSeed, "\(spec.name)")
            }
            #expect(spec.entries.count <= 64, "\(spec.name) is short")
            for entry in spec.entries {
                if let action = entry.action { used.insert(action.control) }
            }
        }
        #expect(used == declared, "\(declared.subtracting(used))")
        #expect(!Core.heroEntries.isEmpty && Core.rejectionEntries.count >= 30 && Core.inputActions.count == 2)
    }

    @Test func derivedDigestsResultsAndOutcomesAreWhatTheEngineGives() async throws {
        var outcomes: [String: Int] = [:]
        for spec in builtManifest.scenarios {
            var engine: ExperienceEngine<Core> = ExperienceEngine<Core>(id: coreID)
            try await engine.prepare(seed: spec.seed)
            try engine.activate()
            let initial: String = try engine.digest().hex
            var results: [String] = []
            for entry in spec.entries {
                try engine.run(steps: entry.steps)
                if let action = entry.action {
                    results.append(engine.handle(control: action.control, values: action.values).code)
                }
            }
            if let expected = spec.expect.initialDigest { #expect(initial == expected, "\(spec.name)") }
            if let expected = spec.expect.finalDigest {
                #expect(try engine.digest().hex == expected, "\(spec.name)")
            }
            var expectedResults: [String] = []
            for entry in spec.entries where entry.action != nil { expectedResults.append(entry.result ?? "accepted") }
            #expect(results == expectedResults, "\(spec.name): \(results)")
            if let outcome = spec.expect.outcome {
                #expect(engine.core?.outcome?.code == outcome, "\(spec.name)")
                outcomes[outcome, default: 0] += 1
            }
        }
        // Won: completion, full-playthrough, the solved fixture, the five odd witness rows, the rendering and the
        // persistence rows; failed: the failing fixture and the five even witness rows (exhausted paths).
        #expect(outcomes[Core.wonCode] == 28 && outcomes[Core.failedCode] == 6, "\(outcomes)")
    }

    /// The kernel record kinds of `core`'s play after its opening records (begin and the tutorial's dismissal).
    static func kinds(_ core: Core) -> [MyceliumArchitectRecord.Kind] {
        var result: [MyceliumArchitectRecord.Kind] = []
        for record in core.play.records where record.kind != .begin && record.kind != .dismissTutorial {
            result.append(record.kind)
        }
        return result
    }

    /// The number of `code` among `results`.
    static func count(_ code: String, in results: [String]) -> Int {
        var total: Int = 0
        for each in results where each == code { total += 1 }
        return total
    }

    @Test func everyAcceptanceRowEndsInTheStateOfItsFamily() throws {
        var runFailures: Set<String> = []
        for row in 1...80 {
            let level: Int = Core.acceptanceLevel(row)
            let name: String = Core.acceptanceName(row)
            let spec: ScenarioSpec = try #require(builtManifest.scenarios.first { $0.name == name })
            #expect(spec.seed == UInt64(level - 1), "\(name)")
            var results: [String] = []
            for entry in spec.entries where entry.action != nil { results.append(entry.result ?? "accepted") }
            let core: Core = try #require(Core.played(seed: spec.seed, entries: spec.entries), "\(name)")
            let opening: String = try #require(Core.expectedDigest(for: coreID, seed: spec.seed, entries: []))
            let final: String = try digest(of: core)
            let kinds: [MyceliumArchitectRecord.Kind] = Self.kinds(core)
            switch Core.acceptanceFamily(row) {
            case .truth:
                let probe: MyceliumArchitectAction = try #require(Core.probeMove(level), "\(name)")
                let expected: [String] = [Core.outOfRangeCode, Core.pulseCode, Core.kernelActionCode,
                                          Core.kernelActionCode, Core.kernelActionCode]
                #expect(results == ["accepted", expected[(row - 1) % 5]], "\(name): \(results)")
                #expect(kinds == [MyceliumArchitectPlay.kind(of: probe)] && core.play.stage == .playing, "\(name)")
            case .witness:
                if row % 2 == 1 {
                    #expect(core.play.stage == .won && Self.count(Core.acceptedCode, in: results) == results.count)
                    #expect(Self.count(.undo, in: kinds) == 2 && Self.count(.run, in: kinds) == 2, "\(name)")
                    let perturbed: Core? = Core.played(seed: spec.seed, entries: Array(spec.entries.dropLast(4)))
                    #expect(perturbed?.play.stage == .failed, "\(name): the perturbed plan fails")
                    if let failure = perturbed?.play.failure { runFailures.insert(failure.code) }
                } else {
                    #expect(core.play.stage == .failed && core.play.actionsLeft == 0, "\(name)")
                    #expect(Array(results.suffix(3)) == [Core.budgetCode, "accepted", Core.stageCode], "\(name)")
                    if let failure = core.play.failure { runFailures.insert(failure.code) }
                }
            case .numeric:
                #expect(final == opening && core.play.stage == .playing && core.play.actionsSpent == 0, "\(name)")
                #expect(Self.count(Core.outOfRangeCode, in: results) == 3, "\(name)")
                #expect(Self.count(Core.kernelActionCode, in: results) == 2, "\(name)")
                #expect(Self.count(Core.notWholeCode, in: results) == 1, "\(name)")
                #expect(Self.count(Core.pulseCode, in: results) == 1, "\(name)")
                #expect(core.shownPulse == core.play.report.pulsesRun, "\(name)")
            case .touch:
                let probe: MyceliumArchitectAction = try #require(Core.probeMove(level), "\(name)")
                let moved: String = try #require(Core.expectedDigest(for: coreID, seed: spec.seed,
                                                                     entries: [Core.actionEntry(probe)]))
                #expect(final == moved && final != opening, "\(name)")
                #expect(core.shownPulse == Core.touchPulse(level) && results.last == Core.kernelActionCode, "\(name)")
            case .rendering:
                #expect(core.play.stage == .won && results.last == Core.stageCode, "\(name)")
                var tiered: Core = core
                for tier in 0..<Core.qualityTiers {
                    tiered.setQualityTier(tier)
                    let snapshot: MyceliumArchitectSceneSnapshot = tiered.snapshot(time: Double(tier) * 0.75)
                    #expect(snapshot.isWon && snapshot.failure == nil, "\(name)")
                    for terminal in snapshot.terminalPulses.indices { #expect(snapshot.isReached(terminal)) }
                    #expect(try digest(of: tiered) == final, "\(name): tier \(tier)")
                }
            case .accessibility:
                #expect(core.play.stage == .playing && Array(kinds.suffix(2)) == [.run, .undo], "\(name)")
                let beforeRun: String = try #require(Core.expectedDigest(for: coreID, seed: spec.seed,
                                                                         entries: Array(spec.entries.dropLast(2))))
                #expect(final == beforeRun, "\(name): the honest retry")
                let failedRun: Core? = Core.played(seed: spec.seed, entries: Array(spec.entries.dropLast()))
                let failure: MyceliumArchitectFailure = try #require(failedRun?.play.failure, "\(name)")
                runFailures.insert(failure.code)
                #expect(!core.play.level.failureDescription(failure).isEmpty, "\(name): named in words")
            case .persistence:
                #expect(core.play.stage == .won && Array(kinds.prefix(4).dropFirst()) == [.undo, .redo, .undo])
                let restored: Core = try Core.restore(payload: core.snapshotPayload(), seed: spec.seed)
                let restoredDigest: String = try digest(of: restored)
                #expect(restored == core && restoredDigest == final, "\(name)")
            case .integration:
                #expect(core.levelNumber == Core.nextLevel(after: level) && core.play.stage == .playing, "\(name)")
                #expect(core.play.actionsSpent == 0 && kinds.count == 2 && kinds.last == .undo, "\(name)")
                #expect(results.last == Core.kernelActionCode, "\(name)")
            }
        }
        #expect(runFailures.isSubset(of: Set(Core.preferredFailures)) && runFailures.count >= 2, "\(runFailures)")
    }

    /// The number of `kind` among `kinds`.
    static func count(_ kind: MyceliumArchitectRecord.Kind, in kinds: [MyceliumArchitectRecord.Kind]) -> Int {
        var total: Int = 0
        for each in kinds where each == kind { total += 1 }
        return total
    }

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1`
    /// rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        var object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: builtManifest.encoded()) as? [String: Any])
        var controlIDs: [String] = []
        for control in Core.controls { controlIDs.append(control.id) }
        object["controls"] = controlIDs
        let data: Data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
    #endif
}
