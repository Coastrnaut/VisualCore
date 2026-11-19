// FixtureTests — feature 173 (A24-P01) T-A24-107 (FR-A24-106, SC-A24-101; User Stories 2 and 4). Every committed
// fixture's summary equals its hand-computed expectation exactly, and reordering the measured values of a set gives
// the same summary.
import Foundation
import Testing
import GraphicsBenchmarkLabCore

@Suite struct FixtureTests {
    @Test func everyCaseHasACommittedFixtureAndNothingElseIsBundled() {
        let bundled = SampleFixtures.bundledNames()
        let named = SampleFixtures.names.sorted()
        #expect(bundled == named, "bundled: \(bundled)")
    }

    @Test func everyFixtureMatchesItsExpectedSummaryExactly() throws {
        let fixtures = try SampleFixtures.all()
        let count = fixtures.count
        #expect(count == SampleFixtures.names.count)
        for named in fixtures {
            let summary = try Summary.make(named.fixture.samples)
            let expected = named.fixture.expected
            #expect(summary == expected, "\(named.name): \(summary)")
        }
    }

    @Test func aShuffledSetGivesTheSameSummary() throws {
        let fixtures = try SampleFixtures.all()
        for named in fixtures {
            let sorted = try Summary.make(named.fixture.samples)
            for seed: UInt64 in [1, 173, 0xA24] {
                let shuffled = SampleFixtures.shuffledMeasuredValues(named.fixture.samples, seed: seed)
                let summary = try Summary.make(shuffled)
                #expect(summary == sorted, "\(named.name) seed \(seed)")
            }
        }
    }

    @Test func theShuffledFixtureIsNotInSortedOrder() throws {
        let fixture = try SampleFixtures.load("one-to-hundred-shuffled")
        var intervals: [Double] = []
        for sample in fixture.samples {
            if let interval = sample.intervalMs { intervals.append(interval) }
        }
        let sorted = intervals.sorted()
        let ascending = (1...100).map { Double($0) }
        #expect(intervals != sorted)
        #expect(sorted == ascending)
    }

    @Test func expectedFlagsAreSortedAndUnique() throws {
        let fixtures = try SampleFixtures.all()
        for named in fixtures {
            let flags = named.fixture.expected.flags
            let normalised = Array(Set(flags)).sorted()
            #expect(flags == normalised, "\(named.name): \(flags)")
        }
    }
}
