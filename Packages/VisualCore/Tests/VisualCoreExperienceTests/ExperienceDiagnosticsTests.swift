// ExperienceDiagnosticsTests — feature 188 T-U02-027 (US6; FR-U02-060, FR-U02-061; SC-U02-006, host part): the
// readable state of an experience in every lifecycle state.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreTestSupport

@Suite struct ExperienceDiagnosticsTests {
    @Test func everyStateHasCompleteDiagnostics() async throws {
        for state in ExperienceLifecycleState.allCases {
            let engine = try await makeSampleEngine(in: state)
            let diagnostics = engine.diagnostics()
            #expect(diagnostics.experience == SampleExperience.id)
            #expect(diagnostics.state == state)
            #expect(diagnostics.stepIndex == engine.stepIndex)
            #expect(diagnostics.qualityTier == 0)
            #expect(diagnostics.gpu == nil)
            #expect(diagnostics.rejectedTransitions == 0)
            #expect(diagnostics.rejectedOperations == 0)
            #expect(diagnostics.acceptedActions == 0 && diagnostics.rejectedActions == 0)
            #expect(diagnostics.droppedTime == 0 && diagnostics.invalidFrames == 0)
            let hasCore: Set<ExperienceLifecycleState> = [.ready, .active, .suspended, .deactivating, .failed]
            #expect((diagnostics.digest != nil) == hasCore.contains(state), "digest in \(state)")
            #expect((diagnostics.seed != nil) == (state != .registered), "seed in \(state)")
            #expect((diagnostics.lastError != nil) == (state == .failed))
        }
    }

    @Test func absentItemsAreAbsentNotInvented() async throws {
        let fresh = SampleEngine(id: SampleExperience.id).diagnostics()
        #expect(fresh.seed == nil && fresh.digest == nil && fresh.gpu == nil && fresh.lastError == nil)
        let text = try #require(String(data: try fresh.encoded(), encoding: .utf8))
        for key in ["seed", "digest", "gpu", "lastError"] { #expect(!text.contains("\"\(key)\""), "\(key) is written") }
        #expect(!text.contains("null"))

        let gone = try await makeSampleEngine(in: .inactive)
        #expect(gone.diagnostics().digest == nil)
        #expect(gone.diagnostics().seed == 42)
    }

    @Test func gpuCountsArePassedIn() async throws {
        let engine = try await makeSampleEngine(in: .active)
        let counts = GPUResourceCounts(objects: 3, bytes: 4_096, leaked: 0)
        #expect(engine.diagnostics(gpu: counts).gpu == counts)
    }

    @Test func theLastErrorStaysUntilAPreparationSucceeds() async throws {
        var engine = try await makeSampleEngine(in: .failed)
        #expect(engine.diagnostics().lastError == ExperienceFailure(code: "test.failed", message: "failed on purpose"))
        try engine.beginDeactivation()
        try engine.finishDeactivation()
        #expect(engine.diagnostics().lastError?.code == "test.failed")
        _ = try engine.beginPreparation(seed: 1)
        #expect(engine.diagnostics().lastError?.code == "test.failed")
        try engine.beginDeactivation()
        try await engine.prepare(seed: 1)
        #expect(engine.diagnostics().lastError == nil)
    }

    @Test func countersAreReported() async throws {
        var engine = try await makeSampleEngine(in: .active)
        _ = try? engine.activate()
        _ = engine.handle(control: "ping")
        _ = engine.handle(control: "jump")
        _ = try engine.advance(frame: 1.0)
        _ = try engine.advance(frame: .nan)
        let diagnostics = engine.diagnostics()
        #expect(diagnostics.rejectedOperations == 1)
        #expect(diagnostics.acceptedActions == 1 && diagnostics.rejectedActions == 1)
        #expect(diagnostics.droppedTime > 0.9)
        #expect(diagnostics.invalidFrames == 1)
        #expect(diagnostics.stepIndex == 8)
    }

    @Test func readingHasNoSideEffect() async throws {
        let engine = try await makeSampleEngine(in: .active)
        let first = engine.diagnostics()
        let second = engine.diagnostics()
        #expect(first == second)
        #expect(engine.lifecycle.rejectedOperations == 0 && engine.lifecycle.rejectedTransitions == 0)
        #expect(engine.lifecycle.state == .active)
    }

    @Test func theEncodedFormIsSortedAndRoundTrips() async throws {
        var engine = try await makeSampleEngine(in: .active, seed: .max)
        engine.fail(ExperienceFailure(code: "test.failed", message: "failed on purpose"))
        let diagnostics = engine.diagnostics(gpu: GPUResourceCounts(objects: 1, bytes: 4, leaked: 0))
        let data = try diagnostics.encoded()
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains(#""seed":"18446744073709551615""#))
        #expect(text.contains(#""state":"failed""#))
        let keys = ["acceptedActions", "digest", "droppedTime", "experience", "gpu", "invalidFrames", "lastError", "qualityTier",
                    "rejectedActions", "rejectedOperations", "rejectedTransitions", "seed", "state", "stepIndex"]
        var position = text.startIndex
        for key in keys {
            let range = try #require(text.range(of: "\"\(key)\":", range: position..<text.endIndex), "\(key) missing or out of order")
            position = range.upperBound
        }
        #expect(try JSONDecoder().decode(ExperienceDiagnostics.self, from: data) == diagnostics)
        #expect(try diagnostics.encoded() == data)
    }
}
