// ExperienceEngineStateTests — feature 188 T-U02-021 (US3; FR-U02-041 to FR-U02-045; SC-U02-003): snapshot, restore
// and reset of the engine, proven with the sample experience.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreTestSupport

@Suite struct ExperienceEngineStateTests {
    /// Drives an active sample engine through steps and actions; `visit` is called after every segment.
    private func drive(_ engine: inout SampleEngine, segments: Int, visit: (inout SampleEngine) throws -> Void) throws {
        let moves: [[Double]] = [[1, 0], [0, 1], [-1, 0], [0, -1]]
        for index in 0..<segments {
            try engine.run(steps: 1 + index % 5)
            _ = engine.handle(control: "tone", values: [Double(index % 10) / 10])
            _ = engine.handle(control: "move", values: moves[index % 4])
            try visit(&engine)
        }
    }

    @Test func snapshotAndRestoreReproduceTheStateAtOneHundredPoints() async throws {
        var engine = try await makeSampleEngine(in: .active, seed: 42)
        var points = 0
        try drive(&engine, segments: 100) { engine in
            let snapshot = try engine.snapshot()
            let again = try engine.snapshot()
            #expect(snapshot == again)
            let decoded = try ExperienceSnapshot(data: try snapshot.encoded())
            #expect(decoded == snapshot)
            var other = SampleEngine(id: SampleExperience.id)
            let ticket = try other.beginPreparation(seed: 7)
            other.completePreparation(ticket, with: .success(try #require(engine.core)))
            // `other` now holds some prepared state under another seed; the restore must replace all of it.
            try other.reset()
            try other.restore(decoded)
            #expect(try other.digest() == (try engine.digest()))
            #expect(other.seed == 42)
            #expect(other.stepIndex == engine.stepIndex)
            #expect(snapshot.digest == (try engine.digest()))
            #expect(snapshot.schemaVersion == 2)
            points += 1
        }
        #expect(points == 100)
        #expect(engine.acceptedActions > 100)
    }

    @Test func restoreWorksInReadyActiveAndSuspended() async throws {
        var source = try await makeSampleEngine(in: .active, seed: 5)
        try source.run(steps: 12)
        _ = source.handle(control: "tone", values: [0.75])
        let snapshot = try source.snapshot()
        for state in [ExperienceLifecycleState.ready, .active, .suspended] {
            var engine = try await makeSampleEngine(in: state, seed: 99)
            try engine.restore(snapshot)
            #expect(engine.lifecycle.state == state)
            #expect(try engine.digest() == snapshot.digest)
            #expect(engine.seed == 5)
            #expect(engine.stepIndex == 12)
        }
    }

    @Test func resetEqualsAFreshPreparation() async throws {
        for index in 0..<32 {
            let seed = UInt64(index) &* 0xD1B5_4A32_D192_ED03 &+ 3
            var engine = try await makeSampleEngine(in: .active, seed: seed)
            let first = try engine.digest()
            try drive(&engine, segments: 6) { _ in }
            #expect(try engine.digest() != first)
            try engine.reset()
            #expect(try engine.digest() == first, "seed \(seed)")
            #expect(engine.stepIndex == 0)
            #expect(engine.seed == seed)
            #expect(engine.lifecycle.state == .active)
        }
    }

    @Test func resetAfterARestoreUsesTheRestoredSeed() async throws {
        var source = try await makeSampleEngine(in: .active, seed: 1234)
        let fresh = try source.digest()
        try source.run(steps: 30)
        let snapshot = try source.snapshot()
        var engine = try await makeSampleEngine(in: .active, seed: 1)
        try engine.restore(snapshot)
        try engine.reset()
        #expect(try engine.digest() == fresh)
        #expect(engine.seed == 1234)
        #expect(engine.stepIndex == 0)
    }

    @Test func aVersionOneSnapshotMigrates() async throws {
        let data = SampleExperience.snapshotV1(seed: 42)
        let snapshot = try ExperienceSnapshot(data: data)
        #expect(snapshot.schemaVersion == 1)
        var engine = try await makeSampleEngine(in: .ready, seed: 1)
        try engine.restore(snapshot)
        #expect(try engine.digest().hex == SampleExperience.snapshotV1Digest)
        #expect(engine.core?.energy == 0)
        #expect(engine.seed == 42)
        #expect(engine.stepIndex == snapshot.stepIndex)
        // A snapshot taken now is written at the current schema version.
        #expect(try engine.snapshot().schemaVersion == 2)
    }

    @Test func everyRefusalLeavesTheStateUnchanged() async throws {
        var engine = try await makeSampleEngine(in: .active, seed: 42)
        try engine.run(steps: 9)
        _ = engine.handle(control: "tone", values: [0.5])
        let good = try engine.snapshot()
        let digest = try engine.digest()
        let payload = Data(good.payload.utf8)
        let otherID = try ExperienceID("a98.another-sample")
        let wrongDigest = try #require(StateDigest(hex: String(repeating: "0", count: 64)))

        func rebuilt(experience: ExperienceID? = nil, schema: Int? = nil, digest: StateDigest? = nil,
                     payload: Data? = nil) throws -> ExperienceSnapshot {
            try ExperienceSnapshot(experience: experience ?? good.experience, schemaVersion: schema ?? good.schemaVersion,
                                   seed: good.seed, stepIndex: good.stepIndex, digest: digest ?? good.digest,
                                   payload: payload ?? payload ?? Data(good.payload.utf8))
        }

        let refused: [(String, ExperienceSnapshot)] = [
            ("snapshot.wrong-experience", try rebuilt(experience: otherID)),
            ("snapshot.newer-schema", try rebuilt(schema: 3)),
            ("snapshot.missing-migration", try rebuilt(schema: 0)),
            ("snapshot.corrupt", try rebuilt(payload: Data(#"{"x":"not a number"}"#.utf8))),
            ("snapshot.state-mismatch", try rebuilt(digest: wrongDigest)),
        ]
        for (code, snapshot) in refused {
            do {
                try engine.restore(snapshot)
                Issue.record("\(code) was restored")
            } catch {
                #expect(error.code == code)
            }
            #expect(try engine.digest() == digest, "\(code)")
            #expect(engine.seed == 42)
            #expect(engine.stepIndex == 9)
        }

        // The three refusals that happen while decoding never reach the engine.
        let encoded = try good.encoded()
        let text = try #require(String(data: encoded, encoding: .utf8))
        let decodingCases: [(String, Data)] = [
            ("snapshot.unknown-format", Data(text.replacingOccurrences(of: #""format":1"#, with: #""format":2"#).utf8)),
            ("snapshot.checksum-mismatch", Data(text.replacingOccurrences(of: #"\"tone\":0.5"#, with: #"\"tone\":0.6"#).utf8)),
            ("snapshot.too-large", encoded + Data(repeating: 0x20, count: ExperienceSnapshot.maxBytes)),
        ]
        for (code, data) in decodingCases {
            #expect(data != encoded, "\(code): the fixture equals the original")
            do {
                _ = try ExperienceSnapshot(data: data)
                Issue.record("\(code) was decoded")
            } catch {
                #expect(error.code == code)
            }
        }
        #expect(try engine.digest() == digest)
        _ = payload
    }

    @Test func snapshotRestoreAndResetAreRefusedOutsideTheirStates() async throws {
        let source = try await makeSampleEngine(in: .ready)
        var sourceCopy = source
        let snapshot = try sourceCopy.snapshot()
        let legal: Set<ExperienceLifecycleState> = [.ready, .active, .suspended]
        for state in ExperienceLifecycleState.allCases where !legal.contains(state) {
            var engine = try await makeSampleEngine(in: state)
            let before = engine
            do { _ = try engine.snapshot(); Issue.record("snapshot in \(state)") } catch {
                #expect(error == .illegalOperation(.snapshot, in: state))
            }
            do { try engine.restore(snapshot); Issue.record("restore in \(state)") } catch {
                #expect(error == .illegalOperation(.restore, in: state))
            }
            do { try engine.reset(); Issue.record("reset in \(state)") } catch {
                #expect(error == .illegalOperation(.reset, in: state))
            }
            #expect(engine.lifecycle.rejectedOperations == before.lifecycle.rejectedOperations + 3)
            #expect((try? engine.digest()) == (try? before.digest()))
            #expect(engine.stepIndex == before.stepIndex)
        }
    }
}
