// CatalogFixtureTests — feature 103 (A14-P01) T-A14-102 (FR-A14-103; clarification Q3; SC-A14-101). The regression
// fixture of the phase, host-free and short: independent approximate values from general reference — sidereal periods
// in Julian years (0.241, 0.615, 1.000, 1.881, 11.86, 29.46, 84.01, 164.8) and mean radii in km rounded to four
// significant figures (2,440, 6,052, 6,371, 3,390, 69,910, 58,230, 25,360, 24,620) — agree with every planet of the
// stored catalog within 1 % relative (the period converted to years through 365.25 days), and the distances in AU
// increase strictly from Mercury to Neptune.
import Foundation
import SolarSystemExplorerCore
import Testing

@Suite struct CatalogFixtureTests {
    /// The relative tolerance per quantity (1 % for periods and radii).
    private let tolerance: Double = 0.01
    private let ids: [String] = ["mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune"]
    private let periodsYears: [Double] = [0.241, 0.615, 1.000, 1.881, 11.86, 29.46, 84.01, 164.8]
    private let radiiKm: [Double] = [2_440, 6_052, 6_371, 3_390, 69_910, 58_230, 25_360, 24_620]

    /// The relative difference of `value` from `reference`.
    private func relative(_ value: Double, _ reference: Double) -> Double { abs(value - reference) / reference }

    @Test func everyPlanetsPeriodMatchesTheFixture() throws {
        for index in 0..<ids.count {
            let body = try #require(BodyCatalog.bundled.body(id: ids[index]))
            let years: Double = try #require(body.siderealPeriodYears, "\(body.id) has a period")
            #expect(relative(years, periodsYears[index]) <= tolerance, "\(body.id): \(years) years")
        }
    }

    @Test func everyPlanetsRadiusMatchesTheFixture() throws {
        for index in 0..<ids.count {
            let body = try #require(BodyCatalog.bundled.body(id: ids[index]))
            #expect(relative(body.meanRadiusKm, radiiKm[index]) <= tolerance, "\(body.id): \(body.meanRadiusKm) km")
        }
    }

    @Test func distancesInAUIncreaseFromMercuryToNeptune() throws {
        let planets: [CelestialBody] = BodyCatalog.bundled.bodies.filter { $0.kind == .planet }
        #expect(planets.map(\.id) == ids)
        var last: Double = 0
        for planet in planets {
            let au: Double = try #require(planet.semiMajorAxisAU)
            #expect(au > last, "\(planet.id): \(au) AU")
            last = au
        }
        #expect(last > 30 && last < 30.2, "Neptune near 30.18 AU")
    }

    @Test func theFixtureWouldCatchAOnePercentError() throws {
        let earth = try #require(BodyCatalog.bundled.body(id: "earth"))
        #expect(relative(earth.meanRadiusKm * 1.011, radiiKm[2]) > tolerance)
        let jupiterYears: Double = try #require(BodyCatalog.bundled.body(id: "jupiter")?.siderealPeriodYears)
        #expect(relative(jupiterYears * 0.985, periodsYears[4]) > tolerance)
    }
}
