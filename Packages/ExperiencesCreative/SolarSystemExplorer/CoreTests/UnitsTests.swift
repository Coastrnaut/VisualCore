// UnitsTests — feature 103 (A14-P01) T-A14-102 (FR-A14-102; clarification Q2; SC-A14-102). The explicit unit
// conversions, host-free and short: 1 AU is exactly 149,597,870.7 km and back; 365.25 days are exactly one Julian year
// and back; every catalog distance and period agrees in both units through the constants; non-finite and negative
// inputs are refused; the locale-free number text rounds, trims and groups deterministically.
import Foundation
import SolarSystemExplorerCore
import Testing

@Suite struct UnitsTests {
    @Test func oneAstronomicalUnitConvertsExactlyBothWays() {
        #expect(Units.kmPerAU == 149_597_870.7 && Units.daysPerJulianYear == 365.25)
        #expect(Units.km(fromAU: 1) == 149_597_870.7)
        #expect(Units.au(fromKm: 149_597_870.7) == 1)
        #expect(Units.years(fromDays: 365.25) == 1 && Units.days(fromYears: 1) == 365.25)
        #expect(Units.au(fromKm: 0) == 0 && Units.km(fromAU: 0) == 0)
        #expect(Units.km(fromAU: 2) == 299_195_741.4 && Units.days(fromYears: 4) == 1_461)
    }

    @Test func everyCatalogValueAgreesInBothUnits() throws {
        let bodies: [CelestialBody] = BodyCatalog.bundled.bodies
        for body in bodies where body.kind == .planet {
            let km: Double = try #require(body.semiMajorAxisKm)
            let au: Double = try #require(Units.au(fromKm: km))
            let back: Double = try #require(Units.km(fromAU: au))
            #expect(abs(back - km) <= km * 1e-15, "\(body.id) axis round trip")
            #expect(au == km / 149_597_870.7, "\(body.id) AU through the constant")
            let days: Double = try #require(body.siderealPeriodDays)
            let years: Double = try #require(Units.years(fromDays: days))
            let daysBack: Double = try #require(Units.days(fromYears: years))
            #expect(abs(daysBack - days) <= days * 1e-15, "\(body.id) period round trip")
        }
        let earth = try #require(BodyCatalog.bundled.body(id: "earth"))
        let earthAU: Double = try #require(earth.semiMajorAxisAU)
        #expect(abs(earthAU - 1) < 0.0001)
    }

    @Test func nonFiniteAndNegativeInputsAreRefused() {
        let bad: [Double] = [-1, -0.000001, -Double.greatestFiniteMagnitude, .infinity, -.infinity, .nan]
        for value in bad {
            #expect(Units.au(fromKm: value) == nil, "\(value)")
            #expect(Units.km(fromAU: value) == nil, "\(value)")
            #expect(Units.years(fromDays: value) == nil, "\(value)")
            #expect(Units.days(fromYears: value) == nil, "\(value)")
            #expect(!Units.isMagnitude(value), "\(value)")
        }
        #expect(Units.km(fromAU: Double.greatestFiniteMagnitude) == nil, "an overflowing result is refused")
        #expect(Units.days(fromYears: Double.greatestFiniteMagnitude) == nil)
    }

    @Test func numberTextIsLocaleFreeAndGrouped() {
        #expect(Units.text(6_371.0, fractionDigits: 1, trimZeros: true) == "6,371")
        #expect(Units.text(2_439.7, fractionDigits: 1, trimZeros: true) == "2,439.7")
        #expect(Units.text(0.387_098, fractionDigits: 3) == "0.387")
        #expect(Units.text(1.000_016, fractionDigits: 3) == "1.000")
        #expect(Units.text(695_700, fractionDigits: 0) == "695,700")
        #expect(Units.text(-1_234_567.891, fractionDigits: 2) == "-1,234,567.89")
        #expect(Units.text(-0.0001, fractionDigits: 2, trimZeros: true) == "0")
        #expect(Units.text(.nan, fractionDigits: 2) == "—" && Units.storedText(.infinity) == "—")
        #expect(Units.storedText(57.909e6) == "57,909,000")
        #expect(Units.storedText(1_432.041e6) == "1,432,041,000")
        #expect(Units.storedText(4_514.953e6) == "4,514,953,000")
        #expect(Units.storedText(149_597_870.7) == "149,597,870.7")
        #expect(Units.storedText(0.034) == "0.034" && Units.storedText(60_189.0) == "60,189")
        #expect(Units.storedText(10_759.22) == "10,759.22" && Units.storedText(999) == "999")
    }
}
