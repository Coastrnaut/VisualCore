// EventChecksTests — feature 107 (A14-P05) T-A14-502 (FR-A14-501; SC-A14-501; clarification Q1). The seven bundled
// published events (four Mars oppositions, three Earth perihelia) and the model's agreement with each within ±3 days;
// host-free and short (a few hundred model positions per event, no wall clock).
import Foundation
import SolarSystemExplorerCore
import Testing

@Suite struct EventChecksTests {
    @Test func theSevenFixturesAreBundled() {
        let fixtures: [EventFixture] = EventFixture.bundled
        #expect(fixtures.count == 7)
        let dates: [String] = fixtures.map(\.publishedDate)
        #expect(dates == ["2003-08-28", "2018-07-27", "2020-10-13", "2022-12-08", "2000-01-03", "2020-01-05",
                          "2025-01-04"])
        for fixture in fixtures {
            #expect(fixture.toleranceDays == 3, "\(fixture.name)")
            if fixture.kind == .opposition {
                #expect(fixture.bodyID == "mars" && fixture.source == EventFixture.marsSource, "\(fixture.name)")
            } else {
                #expect(fixture.bodyID == "earth" && fixture.source == EventFixture.earthSource, "\(fixture.name)")
            }
        }
        #expect(fixtures.filter { $0.kind == .opposition }.count == 4)
        #expect(Set(fixtures.map(\.name)).count == 7)
    }

    @Test func publishedDaysAreNoonInsideTheModelRange() throws {
        #expect(EventChecks.noonDay(of: "2000-01-01") == 0)
        #expect(EventChecks.noonDay(of: "2000-01-03") == 2)
        #expect(EventChecks.noonDay(of: "2003-08-28") == 1335)
        #expect(EventChecks.noonDay(of: "2000-02-30") == nil)
        #expect(EventChecks.noonDay(of: "2000-1-01") == nil)
        #expect(EventChecks.noonDay(of: "") == nil)
        for fixture in EventFixture.bundled {
            let day: Double = try #require(fixture.publishedDay, "\(fixture.name)")
            #expect(day == day.rounded(), "\(fixture.name) is noon")
            #expect(SimulatedDate.range.contains(day), "\(fixture.name)")
            #expect(SimulatedDate(dayOffset: day)?.label == fixture.publishedDate, "\(fixture.name)")
        }
    }

    @Test func eachEventIsWithinItsTolerance() {
        let results: [EventResult] = EventChecks.evaluateBundled()
        #expect(results.count == 7)
        for result in results {
            let name = result.fixture.name
            #expect(result.modelDay.isFinite && result.offsetDays.isFinite, "\(name)")
            #expect(abs(result.offsetDays) <= 3, "\(name): offset \(result.offsetDays)")
            #expect(result.passed, "\(name)")
            if let published = result.fixture.publishedDay {
                #expect(abs(result.modelDay - published - result.offsetDays) < 1e-9, "\(name)")
            }
            #expect(EventChecks.evaluate(result.fixture) == result, "\(name) is deterministic")
        }
    }

    @Test func anOppositionHasEqualLongitudesAndAPerihelionTheLeastDistance() throws {
        let model = OrbitModel.bundled
        for result in EventChecks.evaluateBundled() {
            let day = result.modelDay
            if result.fixture.kind == .opposition {
                let difference: Double = try #require(EventChecks.longitudeDifference(bodyID: "mars", day: day))
                #expect(abs(difference) < 0.001, "\(result.fixture.name): \(difference) rad")
            } else {
                let here: Double = try #require(model.distanceAU(bodyID: "earth", day: day))
                let before: Double = try #require(model.distanceAU(bodyID: "earth", day: day - 0.5))
                let after: Double = try #require(model.distanceAU(bodyID: "earth", day: day + 0.5))
                #expect(here <= before && here <= after, "\(result.fixture.name)")
            }
        }
    }

    @Test func aBrokenFixtureDoesNotPass() {
        let badDate = EventFixture(name: "bad", kind: .opposition, bodyID: "mars", publishedDate: "2003-13-01",
                                   source: "s")
        let badBody = EventFixture(name: "pluto", kind: .perihelion, bodyID: "pluto", publishedDate: "2000-01-03",
                                   source: "s")
        // Mars is in conjunction, not opposition, in 2002-08; no opposition lies within ±10 days.
        let noEvent = EventFixture(name: "none", kind: .opposition, bodyID: "mars", publishedDate: "2002-08-10",
                                   source: "s")
        for fixture in [badDate, badBody, noEvent] {
            let result = EventChecks.evaluate(fixture)
            #expect(!result.passed && !result.offsetDays.isFinite, "\(fixture.name)")
        }
    }
}
