// SampleExperienceTests — feature 188 T-U02-017 (US2; FR-U02-013, FR-U02-014; SC-U02-002): the committed digests of
// the sample are reproduced wherever these tests run: on the Mac host and on both simulator runtimes.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreTestSupport

@Suite struct SampleExperienceTests {
    @Test func theCommittedDigestsAreReproduced() async throws {
        #expect(SampleExperience.goldenDigests.count == 8)
        for (seed, hex) in SampleExperience.goldenDigests {
            var engine = SampleEngine(id: SampleExperience.id)
            try await engine.prepare(seed: seed)
            #expect(try engine.digest().hex == hex, "seed \(seed)")
        }
        #expect(Set(SampleExperience.goldenDigests.map(\.hex)).count == 8)
    }

    @Test func aRunOfTwoSecondsReproducesItsCommittedDigest() async throws {
        var engine = try await makeSampleEngine(in: .active, seed: 42)
        try engine.run(steps: 240)
        #expect(try engine.digest().hex == SampleExperience.digestAfter240Steps)
        #expect(engine.core?.ticks == 240)
    }

    @Test func theSampleIdIsWellFormed() {
        #expect(SampleExperience.id.rawValue == "a99.contract-sample")
        #expect(SampleExperience.id.accessibilityPrefix == "experience.a99.contract-sample")
    }
}
