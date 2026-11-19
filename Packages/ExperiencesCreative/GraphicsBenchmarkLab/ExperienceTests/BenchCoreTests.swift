// BenchCoreTests — feature 174 (A24-P02) T-A24-208 (FR-A24-205; clarification Q3; data-model.md "BenchCore"). The
// adapter core `BenchCore`: the three actions with their ranges, the rule ids, the case choice and the request
// counters, a refused action changing nothing, the digest over the selected case only (stable, not moved by the
// counters), the snapshot round trip and the restore refusals, one quality tier `level-0`. Short runs.
import Foundation
import Testing
import VisualCoreExperience
@testable import GraphicsBenchmarkLabExperience
import GraphicsBenchmarkLabCore

@MainActor
@Suite struct BenchCoreTests {
    @Test func theThreeControlsAreDeclaredWithTheirRanges() {
        #expect(BenchCore.experienceID == "a24.graphics-benchmark-lab")
        #expect(GraphicsBenchmarkLabExperience.id?.rawValue == "a24.graphics-benchmark-lab")
        #expect(BenchCore.digestDomain == "a24.graphics-benchmark-lab.v1")
        #expect(BenchCore.schemaVersion == 1 && BenchCore.migrations.currentVersion == 1)
        #expect(BenchCore.controls.map(\.id) == BenchCore.actionIDs)
        #expect(BenchCore.actionIDs == ["case.select", "run.start", "run.stop"])
        let ranges = Dictionary(uniqueKeysWithValues: BenchCore.controls.map { ($0.id, $0.ranges) })
        #expect(ranges["case.select"] == [0...2])
        #expect(ranges["run.start"] == [])
        #expect(ranges["run.stop"] == [])
        #expect(BenchCore.qualityTiers == 1 && BenchCore.qualityProfile.names == ["level-0"])
        #expect(BenchRule.all == ["a24.not-whole", "a24.unknown-case"])
        let ids = BenchCore.cases.map(\.id)
        #expect(ids == ["quads", "alu", "particles"])
    }

    @Test func theOpeningStateIsQuadsWithNoRequest() async throws {
        let core = try await BenchCore.prepare(seed: 7)
        #expect(core == BenchCore())
        #expect(core.selectedCase == 0 && core.startRequests == 0 && core.stopRequests == 0)
        #expect(core.benchmarkCase == BenchmarkCase.quads)
        #expect(core.outcome?.code == "case-quads")
    }

    @Test func actionsChooseTheCaseAndCountTheRequests() {
        var (core, result) = BenchTest.applied(BenchCore(), "case.select", [1])
        #expect(result == .accepted && core.selectedCase == 1 && core.outcome?.code == "case-alu")
        (core, result) = BenchTest.applied(core, "case.select", [2])
        #expect(result == .accepted && core.benchmarkCase.id == "particles")
        (core, result) = BenchTest.applied(core, "run.start")
        #expect(result == .accepted && core.startRequests == 1 && core.stopRequests == 0)
        (core, result) = BenchTest.applied(core, "run.start")
        (core, result) = BenchTest.applied(core, "run.stop")
        #expect(result == .accepted && core.startRequests == 2 && core.stopRequests == 1)
        core.update(step: 3)
        #expect(core.startRequests == 2 && core.selectedCase == 2, "a step changes nothing")
        core.reset()
        #expect(core == BenchCore())
    }

    @Test func refusedActionsChangeNothing() {
        let start = BenchCore(selectedCase: 1, startRequests: 2, stopRequests: 1)
        let cases: [(control: String, values: [Double], code: String)] = [
            ("case.select", [0.5], "action.rule.a24.not-whole"),
            ("case.select", [1.5], "action.rule.a24.not-whole"),
            ("case.select", [3], "action.out-of-range"),
            ("case.select", [-1], "action.out-of-range"),
            ("case.select", [.nan], "action.non-finite"),
            ("case.select", [], "action.wrong-value-count"),
            ("case.select", [0, 1], "action.wrong-value-count"),
            ("run.start", [1], "action.wrong-value-count"),
            ("run.stop", [0], "action.wrong-value-count"),
            ("run.pause", [], "action.unknown-control"),
        ]
        for entry in cases {
            let (core, result) = BenchTest.applied(start, entry.control, entry.values)
            let code = result.code
            #expect(code == entry.code, "\(entry.control) \(entry.values)")
            #expect(core == start, "\(entry.control) \(entry.values) changed the state")
        }
    }

    @Test func theEngineGivesTheSameRefusals() async throws {
        var engine = try await BenchTest.engine()
        let before = try engine.digest().hex
        let fraction = engine.handle(control: "case.select", values: [0.5]).code
        let outside = engine.handle(control: "case.select", values: [3]).code
        let count = engine.handle(control: "run.start", values: [1]).code
        #expect(fraction == "action.rule.a24.not-whole")
        #expect(outside == "action.out-of-range")
        #expect(count == "action.wrong-value-count")
        let after = try engine.digest().hex
        #expect(after == before)
    }

    @Test func theDigestCoversTheSelectedCaseOnly() throws {
        let quads = try BenchTest.digest(BenchCore())
        let again = try BenchTest.digest(BenchCore())
        #expect(quads == again, "the digest is stable")
        let counted = try BenchTest.digest(BenchCore(selectedCase: 0, startRequests: 5, stopRequests: 3))
        #expect(counted == quads, "the request counters are not in the digest")
        var digests: Set<String> = []
        for index in 0..<3 {
            digests.insert(try BenchTest.digest(BenchCore(selectedCase: index)))
        }
        #expect(digests.count == 3, "each case has its own digest")
    }

    @Test func aSnapshotRoundTrips() throws {
        let core = BenchCore(selectedCase: 2, startRequests: 4, stopRequests: 3)
        let payload = try core.snapshotPayload()
        let text = String(decoding: payload, as: UTF8.self)
        #expect(text == #"{"selectedCase":2,"startRequests":4,"stopRequests":3}"#)
        let restored = try BenchCore.restore(payload: payload, seed: 9)
        #expect(restored == core)
    }

    @Test func damagedAndOutOfRangeSnapshotsAreRefused() {
        let cases: [(text: String, refusal: BenchRestoreRefusal)] = [
            ("", .damaged),
            ("[]", .damaged),
            (#"{"selectedCase":1}"#, .damaged),
            (#"{"selectedCase":1.5,"startRequests":0,"stopRequests":0}"#, .damaged),
            (#"{"selectedCase":"alu","startRequests":0,"stopRequests":0}"#, .damaged),
            (#"{"selectedCase":3,"startRequests":0,"stopRequests":0}"#, .outOfRange("selectedCase")),
            (#"{"selectedCase":-1,"startRequests":0,"stopRequests":0}"#, .outOfRange("selectedCase")),
            (#"{"selectedCase":0,"startRequests":-1,"stopRequests":0}"#, .outOfRange("startRequests")),
            (#"{"selectedCase":0,"startRequests":0,"stopRequests":-2}"#, .outOfRange("stopRequests")),
        ]
        for entry in cases {
            var refusal: BenchRestoreRefusal?
            do {
                _ = try BenchCore.restore(payload: Data(entry.text.utf8), seed: 1)
            } catch let error as BenchRestoreRefusal {
                refusal = error
            } catch {
                Issue.record("another error for \(entry.text): \(error)")
            }
            #expect(refusal == entry.refusal, "\(entry.text)")
        }
    }

    @Test func aRefusedRestoreLeavesTheShellUnchanged() async throws {
        let shell = try await BenchTest.shell()
        BenchTest.accept(shell, "case.select", [1])
        let before = try BenchTest.core(shell)
        let current = try shell.snapshot()
        let damaged = try ExperienceSnapshot(experience: shell.id, schemaVersion: current.schemaVersion,
                                             seed: current.seed, stepIndex: current.stepIndex,
                                             digest: current.digest,
                                             payload: Data(#"{"selectedCase":7,"startRequests":0,"stopRequests":0}"#.utf8))
        var refused = false
        do { try shell.restore(damaged) } catch { refused = true }
        #expect(refused)
        let after = try BenchTest.core(shell)
        #expect(after == before)
    }

    @Test func theUnknownCaseRuleIsTheCoresOwnGuard() {
        // The declared range 0…2 equals the built-in cases' indices, so the engine refuses any other index first; the
        // rule id stays declared for a direct call with a whole index outside the list.
        #expect(BenchCore.caseRange == 0...Double(BenchCore.cases.count - 1))
        #expect(BenchRule.unknownCase == "a24.unknown-case")
    }
}
