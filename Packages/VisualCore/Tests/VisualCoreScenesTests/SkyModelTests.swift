// SkyModelTests — feature 218 (R02-F18) T-R02F18-005 (FR-R02F18-005; SC-R02F18-004; clarification Q4).
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

@Suite struct SkyModelTests {
    /// The unit direction at `elevation` above the horizon and `azimuth` around +y (azimuth 0 is +x).
    static func direction(elevation: Double, azimuth: Double) -> Vec3 {
        Vec3(cos(elevation) * cos(azimuth), sin(elevation), cos(elevation) * sin(azimuth))
    }

    /// True when the two colours agree within `tolerance` per channel.
    static func close(_ a: Vec3, _ b: Vec3, _ tolerance: Double = 1e-12) -> Bool {
        abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance && abs(a.z - b.z) <= tolerance
    }

    /// Default parameters without the glow, so only the disc and the gradient remain.
    static func noGlow() -> SkyParameters {
        var p: SkyParameters = SkyParameters()
        p.glowStrength = 0
        return p
    }

    /// A sun 30° above the horizon towards +x: no dusk tint (|s.y| > 0.25) and full day (f = 1).
    static let daySun: Vec3 = direction(elevation: Double.pi / 6, azimuth: 0)

    @Test func zenithDirectionGivesTheZenithColour() throws {
        let p: SkyParameters = Self.noGlow()
        let c: Vec3 = try SkyModel.colour(direction: Vec3(0, 1, 0), sun: Self.daySun, parameters: p)
        #expect(Self.close(c, p.zenith))
        let glowing: Vec3 = try SkyModel.colour(direction: Vec3(0, 1, 0), sun: Self.daySun, parameters: SkyParameters())
        // d·s = 0.5, so the default glow adds 0.5 · 0.5⁶⁴ ≈ 3e-20: negligible.
        #expect(Self.close(glowing, p.zenith, 1e-15))
    }

    @Test func horizonDirectionGivesTheHorizonColour() throws {
        let p: SkyParameters = Self.noGlow()
        // Perpendicular to the sun's azimuth: d·s = 0, e = 0.
        let c: Vec3 = try SkyModel.colour(direction: Vec3(0, 0, 1), sun: Self.daySun, parameters: p)
        #expect(Self.close(c, p.horizon))
        let lengthened: Vec3 = try SkyModel.colour(direction: Vec3(0, 0, 7), sun: Self.daySun * 3, parameters: p)
        #expect(Self.close(lengthened, p.horizon), "both vectors are normalised first")
    }

    @Test func straightDownGivesTheGroundColour() throws {
        let p: SkyParameters = Self.noGlow()
        let c: Vec3 = try SkyModel.colour(direction: Vec3(0, -1, 0), sun: Self.daySun, parameters: p)
        #expect(Self.close(c, p.ground))
        let deep: Vec3 = try SkyModel.colour(direction: Self.direction(elevation: -0.2, azimuth: 2), sun: Self.daySun,
                                             parameters: p)
        #expect(Self.close(deep, p.ground), "smoothstep(0, 0.1, −e) is 1 for e ≤ −0.1")
    }

    @Test func noDiscBelowMinusTheRadius() throws {
        // Dim gradient, no dusk tint and a dim sun, so no channel saturates and the sun's share stays visible.
        var lit: SkyParameters = SkyParameters()
        lit.horizon = Vec3(0.1, 0.1, 0.1)
        lit.ground = Vec3(0.1, 0.1, 0.1)
        lit.dusk = Vec3(0, 0, 0)
        lit.sunColour = Vec3(0.3, 0.3, 0.3)
        var dark: SkyParameters = lit
        dark.sunColour = Vec3(0, 0, 0)
        // Looking straight at a sun 0.05 rad below the horizon: e = −0.05 < −r, so the sun adds nothing.
        let below: Vec3 = Self.direction(elevation: -0.05, azimuth: 1)
        let a: Vec3 = try SkyModel.colour(direction: below, sun: below, parameters: lit)
        let b: Vec3 = try SkyModel.colour(direction: below, sun: below, parameters: dark)
        #expect(a == b)
        // At e = −0.005 > −r the disc is drawn (f > 0 there), so the sun colour changes the result.
        let grazing: Vec3 = Self.direction(elevation: -0.005, azimuth: 1)
        let c: Vec3 = try SkyModel.colour(direction: grazing, sun: grazing, parameters: lit)
        let d: Vec3 = try SkyModel.colour(direction: grazing, sun: grazing, parameters: dark)
        #expect(c.x > d.x && c.y > d.y && c.z > d.z)
    }

    @Test func nightIsDarkerThanDayInEveryChannel() throws {
        let p: SkyParameters = SkyParameters()
        let day: Vec3 = Self.direction(elevation: 0.5236, azimuth: 0)   // s.y ≈ 0.5
        let night: Vec3 = Vec3(day.x, -day.y, day.z)                     // s.y ≈ −0.5
        var compared: Int = 0
        for i in 0..<12 {
            for j in 0..<7 {
                let d: Vec3 = Self.direction(elevation: (Double(j) - 3) * 0.45, azimuth: Double(i) * Double.pi / 6 + 0.1)
                let a: Vec3 = try SkyModel.colour(direction: d, sun: day, parameters: p)
                let b: Vec3 = try SkyModel.colour(direction: d, sun: night, parameters: p)
                #expect(b.x < a.x && b.y < a.y && b.z < a.z)
                compared += 1
            }
        }
        #expect(compared == 84)
    }

    @Test func finiteAndInRangeForEverySunPosition() throws {
        let p: SkyParameters = SkyParameters()
        let sunElevations: [Double] = [-Double.pi / 2, -0.5, -0.1, 0, 0.004, 0.1, 0.6, Double.pi / 2]
        var checked: Int = 0
        for elevation in sunElevations {
            let s: Vec3 = elevation == Double.pi / 2 ? Vec3(0, 1, 0)
                : (elevation == -Double.pi / 2 ? Vec3(0, -1, 0) : Self.direction(elevation: elevation, azimuth: 0.7))
            for i in 0..<24 {
                for j in 0...16 {
                    let e: Double = (Double(j) / 16 - 0.5) * Double.pi
                    let d: Vec3 = j == 16 ? Vec3(0, 1, 0)
                        : (j == 0 ? Vec3(0, -1, 0) : Self.direction(elevation: e, azimuth: Double(i) * Double.pi / 12))
                    let c: Vec3 = try SkyModel.colour(direction: d, sun: s, parameters: p)
                    #expect(c.isFinite)
                    for v in [c.x, c.y, c.z] { #expect(v >= 0 && v <= 1) }
                    checked += 1
                }
            }
            // Looking straight at the sun.
            let atSun: Vec3 = try SkyModel.colour(direction: s, sun: s, parameters: p)
            #expect(atSun.isFinite)
            for v in [atSun.x, atSun.y, atSun.z] { #expect(v >= 0 && v <= 1) }
        }
        #expect(checked == 8 * 24 * 17)
    }

    @Test func refusesZeroAndNonFiniteDirections() {
        let p: SkyParameters = SkyParameters()
        let bad: [(Vec3, Vec3)] = [(Vec3(0, 0, 0), Self.daySun), (Vec3(Double.nan, 1, 0), Self.daySun),
                                   (Vec3(0, Double.infinity, 0), Self.daySun), (Vec3(0, 1, 0), Vec3(0, 0, 0)),
                                   (Vec3(0, 1, 0), Vec3(0, Double.nan, 0)), (Vec3(0, 1, 0), Vec3(-Double.infinity, 0, 0))]
        for (d, s) in bad {
            #expect(throws: SkyError.direction) { _ = try SkyModel.colour(direction: d, sun: s, parameters: p) }
        }
        #expect(SkyError.direction.reasonCode == "r2-f18.direction")
    }

    @Test func refusesInvalidParameters() {
        var p: SkyParameters = SkyParameters()
        p.sunRadius = 0
        #expect(throws: SkyError.skyParameter("sunRadius")) {
            _ = try SkyModel.colour(direction: Vec3(0, 1, 0), sun: Self.daySun, parameters: p)
        }
        var q: SkyParameters = SkyParameters()
        q.zenith = Vec3(0.2, Double.nan, 0.5)
        #expect(throws: SkyError.skyParameter("zenith")) {
            _ = try SkyModel.colour(direction: Vec3(0, 1, 0), sun: Self.daySun, parameters: q)
        }
    }
}
