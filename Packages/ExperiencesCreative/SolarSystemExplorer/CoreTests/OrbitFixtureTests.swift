// OrbitFixtureTests — feature 104 (A14-P02) T-A14-204 (FR-A14-210, 212; clarification Q3; research D5; SC-A14-201).
// The orbit regression fixture, host-free and short (a few thousand Kepler solutions): Earth's heliocentric ecliptic
// longitude atan2(y, x) at J2000.0 is 100.38° ± 0.3° (Standish's Earth is the Earth–Moon barycentre, well inside the
// tolerance); Earth's least and greatest distance over a year sampled daily are 0.98329 and 1.01671 AU ± 0.2 %; Mars
// stays within 1.381 … 1.666 AU ± 0.5 % over its period; every planet is back within 1e-6 rad of its start mean
// anomaly, and within 1e-6 relative of its start position, after one catalog sidereal period; the Sun is the origin
// and the km distance is the AU distance × 149,597,870.7.
import Foundation
import SolarSystemExplorerCore
import Testing
import VisualCoreMath

@Suite struct OrbitFixtureTests {
    private let model: OrbitModel = OrbitModel.bundled
    private let ids: [String] = ["mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune"]

    /// The least and greatest distance of `id` from the Sun over `samples` equal steps of `span` days from day 0.
    private func extremes(_ id: String, span: Double, samples: Int) throws -> (Double, Double) {
        var least: Double = .infinity
        var greatest: Double = 0
        for index in 0...samples {
            let day: Double = span * Double(index) / Double(samples)
            let distance: Double = try #require(model.distanceAU(bodyID: id, day: day))
            least = min(least, distance)
            greatest = max(greatest, distance)
        }
        return (least, greatest)
    }

    @Test func everyPlanetHasAnOrbitAndTheSunIsTheOrigin() {
        for id in ids {
            #expect(model.orbit(bodyID: id) != nil, "\(id)")
            #expect(model.position(bodyID: id, day: 0)?.isFinite == true, "\(id)")
        }
        #expect(model.position(bodyID: "sun", day: 1_234) == Vec3.zero)
        #expect(model.distanceAU(bodyID: "sun", day: 0) == 0)
        #expect(model.position(bodyID: "pluto", day: 0) == nil)
        #expect(model.position(bodyID: "earth", day: .nan) == nil)
    }

    @Test func earthLongitudeAtJ2000() throws {
        let earth: Vec3 = try #require(model.position(bodyID: "earth", day: 0))
        let longitude: Double = atan2(earth.y, earth.x) * 180 / Double.pi
        #expect(abs(longitude - 100.38) <= 0.3, "Earth longitude \(longitude)°")
        #expect(abs(earth.z) < 1e-6, "Earth stays in the ecliptic")
    }

    @Test func earthPerihelionAndAphelion() throws {
        let (least, greatest) = try extremes("earth", span: 365.256, samples: 2_000)
        #expect(abs(least - 0.98329) <= 0.98329 * 0.002, "perihelion \(least)")
        #expect(abs(greatest - 1.01671) <= 1.01671 * 0.002, "aphelion \(greatest)")
    }

    @Test func marsStaysWithinItsDistanceRange() throws {
        let (least, greatest) = try extremes("mars", span: 686.980, samples: 2_000)
        #expect(abs(least - 1.381) <= 1.381 * 0.005, "Mars least \(least)")
        #expect(abs(greatest - 1.666) <= 1.666 * 0.005, "Mars greatest \(greatest)")
        #expect(least >= 1.381 * 0.995 && greatest <= 1.666 * 1.005)
    }

    @Test func everyPlanetReturnsAfterOnePeriod() throws {
        for id in ids {
            let period: Double = try #require(BodyCatalog.bundled.body(id: id)?.siderealPeriodDays)
            let orbit: KeplerOrbit = try #require(model.orbit(bodyID: id))
            #expect(abs(orbit.period - period) <= period * 1e-12, "\(id) period agrees with the catalog")
            var difference: Double = orbit.meanAnomaly(at: period) - orbit.meanAnomaly(at: 0)
            if difference > Double.pi { difference -= 2 * Double.pi }
            if difference < -Double.pi { difference += 2 * Double.pi }
            #expect(abs(difference) < 1e-6, "\(id) mean anomaly \(difference)")
            let start: Vec3 = try #require(model.position(bodyID: id, day: 0))
            let back: Vec3 = try #require(model.position(bodyID: id, day: period))
            #expect((back - start).length <= start.length * 1e-6, "\(id) position")
        }
    }

    @Test func kilometreDistanceIsTheAUDistanceThroughTheConstant() throws {
        for id in ids {
            let au: Double = try #require(model.distanceAU(bodyID: id, day: 4_000))
            let km: Double = try #require(model.distanceKm(bodyID: id, day: 4_000))
            #expect(km == au * 149_597_870.7, "\(id)")
        }
    }
}
