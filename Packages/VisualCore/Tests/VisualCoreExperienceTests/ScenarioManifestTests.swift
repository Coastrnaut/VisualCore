// ScenarioManifestTests — feature 195 T-U09-004 (FR-U09-001, FR-U09-002, FR-U09-003, FR-U09-005; data-model
// section 2): loading of scenario manifests and every rule of the manifest validator.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import Testing
import VisualCoreExperience

@Suite struct ScenarioManifestTests {
    private static let digestA = String(repeating: "a", count: 64)
    private static let controls = [ExperienceControl(id: "tap"), ExperienceControl(id: "move", ranges: [0...1, 0...1])]
    private static let creativeContent = ContentRequirement(fixtures: 2)

    private static let schemaOneJSON = """
    {"schema":1,"experience":"a05.infinite-geometry","kind":"creative","scenarios":[
      {"name":"input-response","seed":"18446744073709551615","entries":[
        {"steps":10,"action":{"control":"move","values":[0.5,0.25]},"result":"accepted"},
        {"steps":0,"digest":"\(String(repeating: "b", count: 64))"}],
       "expect":{"finalDigest":"\(String(repeating: "c", count: 64))","probes":{"marker":"red"}},"cycles":3}]}
    """

    private func id(_ text: String) throws -> ExperienceID { try ExperienceID(text) }

    private func refusal(_ data: Data) -> ScenarioManifestError? {
        do {
            _ = try ScenarioManifest(data: data)
            return nil
        } catch {
            return error
        }
    }

    private func spec(_ name: String, entries: [ScenarioStep]? = nil,
                      expect: ScenarioExpectations = ScenarioExpectations()) -> ScenarioSpec {
        ScenarioSpec(name: name, seed: 7,
                     entries: entries ?? [ScenarioStep(steps: 5, action: ScriptedAction("tap"), result: "accepted")],
                     expect: expect)
    }

    private func standard() -> [ScenarioSpec] { ScenarioManifest.standardNames.map { spec($0) } }

    private func creative(_ scenarios: [ScenarioSpec]) throws -> ScenarioManifest {
        ScenarioManifest(experience: try id("a05.infinite-geometry"), kind: .creative, scenarios: scenarios)
    }

    private func completeCreative() -> [ScenarioSpec] { standard() + [spec("fixture-1"), spec("fixture-2")] }

    private func replacing(_ name: String, with replacement: ScenarioSpec, in scenarios: [ScenarioSpec]) -> [ScenarioSpec] {
        scenarios.map { $0.name == name ? replacement : $0 }
    }

    private func problems(_ manifest: ScenarioManifest, content: ContentRequirement) -> [String] {
        ScenarioManifestValidator.problems(manifest, controls: Self.controls, content: content)
    }

    private func game(round: Int?, acceptance: Int, faults: Int) throws -> ScenarioManifest {
        let extra = [spec("full-playthrough"), spec("hero")]
            + (0..<acceptance).map { spec("acceptance-\($0)") } + (0..<faults).map { spec("fault-\($0)") }
        return ScenarioManifest(experience: try id("r02-g01.sample-game"), kind: .game, round: round,
                                scenarios: standard() + extra)
    }

    // MARK: Loading

    @Test func schemaOneLoads() throws {
        let manifest = try ScenarioManifest(data: Data(Self.schemaOneJSON.utf8))
        #expect(manifest.experience.rawValue == "a05.infinite-geometry")
        #expect(manifest.kind == .creative)
        #expect(manifest.round == nil)
        #expect(manifest.scenarios.count == 1)
        let first = try #require(manifest.scenarios.first)
        #expect(first.name == "input-response")
        #expect(first.seed == UInt64.max)
        #expect(first.cycles == 3)
        #expect(first.seconds == nil)
        #expect(first.entries == [
            ScenarioStep(steps: 10, action: ScriptedAction("move", [0.5, 0.25]), result: "accepted"),
            ScenarioStep(steps: 0, digest: String(repeating: "b", count: 64)),
        ])
        #expect(first.expect.finalDigest == String(repeating: "c", count: 64))
        #expect(first.expect.probes == ["marker": "red"])
        #expect(first.expect.outcome == nil)
    }

    @Test func aNewerSchemaIsRefused() {
        let text = Self.schemaOneJSON.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2")
        #expect(refusal(Data(text.utf8)) == .newerSchema(2))
    }

    @Test func schemaZeroIsUnknown() {
        let text = Self.schemaOneJSON.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":0")
        #expect(refusal(Data(text.utf8)) == .unknownSchema(0))
    }

    @Test func moreThanFourMebibytesIsRefused() {
        let data = Data(repeating: 32, count: ScenarioManifest.maxBytes + 1)
        #expect(refusal(data) == .tooLarge(ScenarioManifest.maxBytes + 1))
    }

    @Test func damagedJSONIsUnreadable() {
        let damaged = Data(Self.schemaOneJSON.dropLast(5).utf8)
        let error = refusal(damaged)
        guard case .unreadable = error else {
            Issue.record("expected unreadable, got \(String(describing: error))")
            return
        }
        #expect(error?.code == "manifest.unreadable")
    }

    @Test func aSeedWrittenAsANumberIsUnreadable() {
        let text = Self.schemaOneJSON.replacingOccurrences(of: "\"18446744073709551615\"", with: "42")
        let error = refusal(Data(text.utf8))
        guard case .unreadable = error else {
            Issue.record("expected unreadable, got \(String(describing: error))")
            return
        }
    }

    @Test func encodingRoundTrips() throws {
        let manifest = try ScenarioManifest(experience: id("r03-g02.sample-game"), kind: .game, round: 3,
                                            scenarios: completeCreative() + [
                                                ScenarioSpec(name: "endurance", seed: 12_345_678_901,
                                                             entries: [ScenarioStep(steps: 3)],
                                                             expect: ScenarioExpectations(initialDigest: Self.digestA,
                                                                                          resetDigest: true),
                                                             seconds: 60),
                                            ])
        let data = manifest.encoded()
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"seed\":\"12345678901\""))
        #expect(text.hasPrefix("{\"experience\":"))
        let decoded = try ScenarioManifest(data: data)
        #expect(decoded == manifest)
    }

    @Test func aSpecConvertsToAnExperienceScenario() {
        let spec = ScenarioSpec(name: "input-response", seed: 99, entries: [
            ScenarioStep(steps: 4, action: ScriptedAction("move", [1, 0]), result: "accepted"),
            ScenarioStep(steps: 2),
        ])
        let expected = ExperienceScenario(seed: 99, entries: [
            ExperienceScenario.Entry(steps: 4, action: ScriptedAction("move", [1, 0])),
            ExperienceScenario.Entry(steps: 2, action: nil),
        ])
        #expect(spec.scenario == expected)
    }

    @Test func theStandardNamesAreTheNine() {
        #expect(ScenarioManifest.standardNames == [
            "launch-first-frame", "input-response", "completion", "rejection", "save-restore", "reset",
            "suspend-resume", "teardown-reentry", "cancel-prepare",
        ])
        #expect(ScenarioManifest.schemaVersion == 1)
        #expect(ScenarioManifest.maxBytes == 4_194_304)
    }

    // MARK: Validator, creative

    @Test func aCompleteCreativeManifestHasNoProblem() throws {
        let manifest = try creative(completeCreative())
        #expect(problems(manifest, content: Self.creativeContent).isEmpty)
    }

    @Test func aMissingStandardScenarioIsNamed() throws {
        let manifest = try creative(completeCreative().filter { $0.name != "cancel-prepare" })
        #expect(problems(manifest, content: Self.creativeContent) == ["missing scenario cancel-prepare"])
    }

    @Test func aDuplicateNameIsAProblem() throws {
        let manifest = try creative(completeCreative() + [spec("reset")])
        #expect(problems(manifest, content: Self.creativeContent) == ["duplicate scenario reset"])
    }

    @Test func aBadNameIsAProblem() throws {
        let manifest = try creative(completeCreative() + [spec("Bad_Name")])
        let found = problems(manifest, content: Self.creativeContent)
        #expect(found == ["scenario Bad_Name: the name is not 1 to 64 characters of a-z, 0-9 and -"])
    }

    @Test func aNameOfSixtyFiveCharactersIsAProblem() throws {
        let long = String(repeating: "x", count: 65)
        let manifest = try creative(completeCreative() + [spec(long)])
        #expect(problems(manifest, content: Self.creativeContent).count == 1)
    }

    @Test func moreThanAThousandScenariosIsAProblem() throws {
        let base = completeCreative()
        let extra = (0..<(1_001 - base.count)).map { spec("extra-\($0)") }
        let manifest = try creative(base + extra)
        #expect(manifest.scenarios.count == 1_001)
        #expect(problems(manifest, content: Self.creativeContent) == ["too many scenarios: 1001 (at most 1000)"])
    }

    @Test func moreThanTenThousandEntriesIsAProblem() throws {
        let long = spec("fixture-long", entries: Array(repeating: ScenarioStep(steps: 0), count: 10_001))
        let manifest = try creative(completeCreative() + [long])
        let found = problems(manifest, content: Self.creativeContent)
        #expect(found == ["scenario fixture-long: too many entries: 10001 (at most 10000)"])
    }

    @Test func aRejectionScenarioMaySendInvalidActionsThatItExpectsRejected() throws {
        let rejection = spec("rejection", entries: [
            ScenarioStep(steps: 0, action: ScriptedAction("fly"), result: "action.unknown-control"),
            ScenarioStep(steps: 0, action: ScriptedAction("tap", [1]), result: "action.wrong-value-count"),
        ])
        let manifest = try creative(replacing("rejection", with: rejection, in: completeCreative()))
        #expect(problems(manifest, content: Self.creativeContent) == [])
        // Without an expected rejection the same entry is a problem.
        let careless = spec("rejection", entries: [ScenarioStep(steps: 0, action: ScriptedAction("fly"), result: "accepted")])
        let other = try creative(replacing("rejection", with: careless, in: completeCreative()))
        #expect(problems(other, content: Self.creativeContent) == ["scenario rejection: unknown control fly"])
    }

    @Test func anUnknownControlIsAProblem() throws {
        let rejection = spec("rejection", entries: [ScenarioStep(steps: 1, action: ScriptedAction("fly"))])
        let manifest = try creative(replacing("rejection", with: rejection, in: completeCreative()))
        #expect(problems(manifest, content: Self.creativeContent) == ["scenario rejection: unknown control fly"])
    }

    @Test func aWrongValueCountIsAProblem() throws {
        let input = spec("input-response", entries: [ScenarioStep(steps: 1, action: ScriptedAction("move", [0.5]))])
        let manifest = try creative(replacing("input-response", with: input, in: completeCreative()))
        let found = problems(manifest, content: Self.creativeContent)
        #expect(found == ["scenario input-response: control move takes 2 values, entry 1 gives 1"])
    }

    @Test func aControlWithoutRangesTakesNoValues() throws {
        let input = spec("input-response", entries: [ScenarioStep(steps: 1, action: ScriptedAction("tap", [1]))])
        let manifest = try creative(replacing("input-response", with: input, in: completeCreative()))
        let found = problems(manifest, content: Self.creativeContent)
        #expect(found == ["scenario input-response: control tap takes 0 values, entry 1 gives 1"])
    }

    @Test func anOutcomeWithoutAnActionIsAProblem() throws {
        let completion = spec("completion", entries: [ScenarioStep(steps: 30)],
                              expect: ScenarioExpectations(outcome: "target-reached"))
        let manifest = try creative(replacing("completion", with: completion, in: completeCreative()))
        let found = problems(manifest, content: Self.creativeContent)
        #expect(found == ["scenario completion: outcome expected without an action before it"])
    }

    @Test func aFinalDigestWithoutAnActionIsAProblem() throws {
        let input = spec("input-response", entries: [ScenarioStep(steps: 30)],
                         expect: ScenarioExpectations(finalDigest: Self.digestA))
        let manifest = try creative(replacing("input-response", with: input, in: completeCreative()))
        let found = problems(manifest, content: Self.creativeContent)
        #expect(found == ["scenario input-response: final digest expected without an action before it"])
    }

    @Test func anEntryDigestBeforeTheFirstActionIsAProblem() throws {
        let input = spec("input-response", entries: [
            ScenarioStep(steps: 3, digest: Self.digestA),
            ScenarioStep(steps: 1, action: ScriptedAction("tap"), result: "accepted"),
        ])
        let manifest = try creative(replacing("input-response", with: input, in: completeCreative()))
        let found = problems(manifest, content: Self.creativeContent)
        #expect(found == ["scenario input-response: entry 1 digest expected without an action before it"])
    }

    @Test func expectationsWithoutActionsAreAllowedInLaunchAndReset() throws {
        let launch = spec("launch-first-frame", entries: [ScenarioStep(steps: 1, digest: Self.digestA)],
                          expect: ScenarioExpectations(initialDigest: Self.digestA, finalDigest: Self.digestA,
                                                       outcome: "none-yet", probes: ["marker": "red"]))
        let reset = spec("reset", entries: [ScenarioStep(steps: 10)],
                         expect: ScenarioExpectations(finalDigest: Self.digestA, resetDigest: true))
        let scenarios = replacing("reset", with: reset,
                                  in: replacing("launch-first-frame", with: launch, in: completeCreative()))
        let manifest = try creative(scenarios)
        #expect(problems(manifest, content: Self.creativeContent).isEmpty)
    }

    @Test func anInitialDigestNeedsNoAction() throws {
        let input = spec("input-response", entries: [ScenarioStep(steps: 1)],
                         expect: ScenarioExpectations(initialDigest: Self.digestA))
        let manifest = try creative(replacing("input-response", with: input, in: completeCreative()))
        #expect(problems(manifest, content: Self.creativeContent).isEmpty)
    }

    @Test func aCreativeExperienceNeedsItsFixtures() throws {
        let manifest = try creative(standard() + [spec("fixture-1")])
        #expect(problems(manifest, content: Self.creativeContent) == ["too few fixture scenarios: 1 of 2"])
    }

    // MARK: Validator, games

    @Test func aCompleteRoundTwoGamePasses() throws {
        let manifest = try game(round: 2, acceptance: 80, faults: 0)
        let found = problems(manifest, content: ContentRequirement(acceptance: 80, faults: 50, levels: 10))
        #expect(found.isEmpty)
    }

    @Test func seventyNineAcceptanceScenariosAreTooFew() throws {
        let manifest = try game(round: 2, acceptance: 79, faults: 0)
        let found = problems(manifest, content: ContentRequirement(acceptance: 80))
        #expect(found == ["too few acceptance scenarios: 79 of 80"])
    }

    @Test func aGameNeedsFullPlaythroughAndHero() throws {
        let base = try game(round: 2, acceptance: 80, faults: 0)
        let manifest = ScenarioManifest(experience: base.experience, kind: .game, round: 2,
                                        scenarios: base.scenarios.filter { $0.name != "hero" && $0.name != "full-playthrough" })
        let found = problems(manifest, content: ContentRequirement(acceptance: 80))
        #expect(found == ["missing scenario full-playthrough", "missing scenario hero"])
    }

    @Test func aCompleteRoundThreeGamePasses() throws {
        let manifest = try game(round: 3, acceptance: 80, faults: 50)
        #expect(problems(manifest, content: ContentRequirement(acceptance: 80, faults: 50)).isEmpty)
    }

    @Test func fortyNineFaultScenariosAreTooFew() throws {
        let manifest = try game(round: 4, acceptance: 80, faults: 49)
        let found = problems(manifest, content: ContentRequirement(acceptance: 80, faults: 50))
        #expect(found == ["too few fault scenarios: 49 of 50"])
    }

    @Test func aGameWithoutARoundIsAProblem() throws {
        let manifest = try game(round: nil, acceptance: 80, faults: 0)
        #expect(problems(manifest, content: ContentRequirement(acceptance: 80)) == ["game without a round"])
    }

    @Test func limitsOnStepsCyclesAndSecondsAreChecked() throws {
        let teardown = ScenarioSpec(name: "teardown-reentry", seed: 1,
                                    entries: [ScenarioStep(steps: 100_001, action: ScriptedAction("tap"))],
                                    cycles: 51, seconds: 0)
        let manifest = try creative(replacing("teardown-reentry", with: teardown, in: completeCreative()))
        let found = problems(manifest, content: Self.creativeContent)
        #expect(found == [
            "scenario teardown-reentry: cycles 51 outside 1…50",
            "scenario teardown-reentry: seconds 0 outside 1…600",
            "scenario teardown-reentry: entry 1: steps 100001 outside 0…100000",
        ])
    }
}
#endif
