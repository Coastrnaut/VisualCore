// OrbitElementsTests — feature 104 (A14-P02) T-A14-204 (FR-A14-210; clarification Q2; research D2; SC-A14-201). The
// bundled Standish J2000.0 elements, host-free and short: eight sets with ids exactly the catalog planets and epoch
// "J2000.0"; the validation "e in [0, 1); a > 0; every value finite" passes for the bundle and catches a damaged set
// (e = 1, a = 0, NaN), a duplicate and a missing planet; the conversion ω = ϖ − Ω, M₀ = L − ϖ, n = 2π / period; and the
// negative stored mean longitudes (Mars, Neptune) give the same position as the value + 360°.
import Foundation
import SolarSystemExplorerCore
import Testing
import VisualCoreMath

@Suite struct OrbitElementsTests {
    private let ids: [String] = ["mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune"]

    /// `element` with the given fields replaced.
    private func damaged(_ element: OrbitElements, a: Double? = nil, e: Double? = nil, longitude: Double? = nil,
                         perihelion: Double? = nil) -> OrbitElements {
        OrbitElements(bodyID: element.bodyID, semiMajorAxisAU: a ?? element.semiMajorAxisAU,
                      eccentricity: e ?? element.eccentricity, inclinationDeg: element.inclinationDeg,
                      meanLongitudeDeg: longitude ?? element.meanLongitudeDeg,
                      perihelionLongitudeDeg: perihelion ?? element.perihelionLongitudeDeg,
                      ascendingNodeDeg: element.ascendingNodeDeg, epoch: element.epoch)
    }

    @Test func bundleHasTheEightPlanetsAndIsValid() {
        let elements: [OrbitElements] = OrbitElements.bundled
        #expect(elements.count == 8)
        var bundledIDs: [String] = []
        for element in elements {
            bundledIDs.append(element.bodyID)
            #expect(element.epoch == "J2000.0", "\(element.bodyID)")
            #expect(element.problems.isEmpty, "\(element.bodyID): \(element.problems)")
        }
        #expect(bundledIDs == ids)
        #expect(OrbitElements.problems(elements).isEmpty, "\(OrbitElements.problems(elements))")
    }

    @Test func storedValuesAreTheClarifiedOnes() throws {
        let earth = try #require(OrbitElements.bundled(bodyID: "earth"))
        #expect(earth.semiMajorAxisAU == 1.00000261 && earth.eccentricity == 0.01671123)
        #expect(earth.inclinationDeg == -0.00001531 && earth.meanLongitudeDeg == 100.46457166)
        #expect(earth.perihelionLongitudeDeg == 102.93768193 && earth.ascendingNodeDeg == 0.0)
        let mars = try #require(OrbitElements.bundled(bodyID: "mars"))
        #expect(mars.meanLongitudeDeg == -4.55343205 && mars.perihelionLongitudeDeg == -23.94362959)
        let neptune = try #require(OrbitElements.bundled(bodyID: "neptune"))
        #expect(neptune.semiMajorAxisAU == 30.06992276 && neptune.meanLongitudeDeg == -55.12002969)
    }

    @Test func damagedElementsAreCaught() throws {
        let earth = try #require(OrbitElements.bundled(bodyID: "earth"))
        let bad: [OrbitElements] = [
            damaged(earth, e: 1), damaged(earth, e: -0.1), damaged(earth, a: 0), damaged(earth, a: -1),
            damaged(earth, a: .nan), damaged(earth, longitude: .nan), damaged(earth, perihelion: .infinity),
        ]
        for element in bad {
            #expect(!element.problems.isEmpty, "\(element)")
            #expect(element.kepler(periodDays: 365.256) == nil, "\(element)")
            var list: [OrbitElements] = OrbitElements.bundled
            list[2] = element
            #expect(!OrbitElements.problems(list).isEmpty)
        }
        #expect(earth.kepler(periodDays: 0) == nil && earth.kepler(periodDays: .nan) == nil)
    }

    @Test func listProblemsCatchDuplicatesAndMissingPlanets() {
        var duplicated: [OrbitElements] = OrbitElements.bundled
        duplicated[1] = OrbitElements.bundled[0]
        let duplicateProblems: [String] = OrbitElements.problems(duplicated)
        #expect(duplicateProblems.contains("mercury: duplicate id"))
        #expect(duplicateProblems.contains("venus: no elements"))
        var unknown: [OrbitElements] = OrbitElements.bundled
        unknown.append(OrbitElements(bodyID: "pluto", semiMajorAxisAU: 39.48, eccentricity: 0.2488,
                                   inclinationDeg: 17.16, meanLongitudeDeg: 238.9, perihelionLongitudeDeg: 224.1,
                                   ascendingNodeDeg: 110.3))
        #expect(OrbitElements.problems(unknown).contains("pluto: not a catalog planet"))
    }

    @Test func conversionFollowsTheClarifiedFormulas() throws {
        let mars = try #require(OrbitElements.bundled(bodyID: "mars"))
        let orbit = try #require(mars.kepler(periodDays: 686.980))
        let radians: Double = Double.pi / 180
        let omega: Double = (-23.94362959 - 49.55953891 + 360) * radians
        let meanAnomaly: Double = (-4.55343205 + 23.94362959) * radians
        #expect(abs(orbit.argumentOfPeriapsis - omega) < 1e-12)
        #expect(abs(orbit.meanAnomalyAtEpoch - meanAnomaly) < 1e-12)
        #expect(abs(orbit.ascendingNode - 49.55953891 * radians) < 1e-12)
        #expect(abs(orbit.inclination - 1.84969142 * radians) < 1e-12)
        #expect(abs(orbit.meanMotion - 2 * Double.pi / 686.980) < 1e-15)
        #expect(orbit.semiMajorAxis == 1.52371034 && orbit.eccentricity == 0.09339410)
    }

    @Test func negativeMeanLongitudesGiveTheSamePositionAsPlus360() throws {
        let negativeIDs: [String] = ["mars", "neptune"]
        let days: [Double] = [0, 100, -2_500, 9_000]
        for id in negativeIDs {
            let element = try #require(OrbitElements.bundled(bodyID: id))
            #expect(element.meanLongitudeDeg < 0, "\(id) is stored negative")
            let period: Double = try #require(BodyCatalog.bundled.body(id: id)?.siderealPeriodDays)
            let shifted = damaged(element, longitude: element.meanLongitudeDeg + 360)
            let bothShifted = damaged(element, longitude: element.meanLongitudeDeg + 360,
                                      perihelion: element.perihelionLongitudeDeg + 360)
            let stored = try #require(element.kepler(periodDays: period))
            let plus = try #require(shifted.kepler(periodDays: period))
            let plusBoth = try #require(bothShifted.kepler(periodDays: period))
            for day in days {
                let a: Vec3 = stored.position(at: day)
                let b: Vec3 = plus.position(at: day)
                let c: Vec3 = plusBoth.position(at: day)
                let scale: Double = a.length
                #expect((a - b).length <= scale * 1e-12, "\(id) day \(day): L + 360")
                #expect((a - c).length <= scale * 1e-12, "\(id) day \(day): L and ϖ + 360")
            }
        }
    }

    @Test func normalisedDegreesWrapIntoOneTurn() {
        #expect(OrbitElements.normalizedDegrees(-4.5) == 355.5)
        #expect(OrbitElements.normalizedDegrees(360) == 0)
        #expect(OrbitElements.normalizedDegrees(725) == 5)
        #expect(OrbitElements.normalizedDegrees(0) == 0)
    }
}
