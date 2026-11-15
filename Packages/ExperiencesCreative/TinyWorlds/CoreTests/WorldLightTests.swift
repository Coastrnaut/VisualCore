// WorldLightTests — feature 091 (A12-P03) T-A12-302 (FR-A12-310; clarification Q3; research D3). The world light,
// host-free and short: the default (30°, 50°, 0.35); the unit direction (cos e · sin a, sin e, cos e · cos a); azimuth
// wrapping, elevation and ambient ranges with refusals that change nothing; clamping initialiser; a face lit head-on
// receives less light once the light moves away; the JSON round trip and refused out-of-range payloads.
import Foundation
import Testing
import TinyWorldsCore
import VisualCoreMath

@Suite struct WorldLightTests {
    private func close(_ a: Vec3, _ b: Vec3, _ tolerance: Double = 1e-12) -> Bool {
        abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance && abs(a.z - b.z) <= tolerance
    }

    @Test func theDefaultLightAndItsDirection() {
        let light = WorldLight.default
        #expect(light.azimuth == 30 && light.elevation == 50 && light.ambient == 0.35 && light.isValid)
        let a = 30 * Double.pi / 180, e = 50 * Double.pi / 180
        #expect(close(light.direction, Vec3(cos(e) * sin(a), sin(e), cos(e) * cos(a))))
        #expect(abs(light.direction.length - 1) < 1e-12)
        #expect(WorldLight.elevationRange == 10...85 && WorldLight.ambientRange == 0.1...0.6)
    }

    @Test func theDirectionFollowsAzimuthAndElevation() {
        var light = WorldLight.default
        light.setAzimuth(0); light.setElevation(10)
        let e = 10 * Double.pi / 180
        #expect(close(light.direction, Vec3(0, sin(e), cos(e))))
        light.setAzimuth(90)
        #expect(close(light.direction, Vec3(cos(e), sin(e), 0)))
        light.setAzimuth(180); light.setElevation(85)
        let high = 85 * Double.pi / 180
        #expect(close(light.direction, Vec3(0, sin(high), -cos(high))))
        for azimuth in stride(from: 0.0, to: 360, by: 15) {
            light.setAzimuth(azimuth)
            #expect(abs(light.direction.length - 1) < 1e-12 && light.direction.y > 0)
        }
    }

    @Test func azimuthWrapsAndOutOfRangeValuesAreRefused() {
        var light = WorldLight.default
        for (input, expected) in [(-30.0, 330.0), (360, 0), (725, 5), (-720, 0), (359.5, 359.5), (-0.0, 0)] {
            #expect(light.setAzimuth(input) && light.azimuth == expected, "\(input)")
            #expect(light.azimuth.sign == .plus)
        }
        light = .default
        let before = light
        #expect(!light.setAzimuth(.nan) && !light.setAzimuth(.infinity))
        #expect(!light.setElevation(9.99) && !light.setElevation(85.01) && !light.setElevation(.nan))
        #expect(!light.setAmbient(0.09) && !light.setAmbient(0.61) && !light.setAmbient(-.infinity))
        #expect(light == before, "refusals change nothing")
        #expect(light.setElevation(10) && light.setElevation(85) && light.elevation == 85)
        #expect(light.setAmbient(0.1) && light.setAmbient(0.6) && light.ambient == 0.6)
        let clamped = WorldLight(azimuth: -90, elevation: 0, ambient: 1)
        #expect(clamped == WorldLight(azimuth: 270, elevation: 10, ambient: 0.6))
        #expect(WorldLight(azimuth: .nan, elevation: .infinity, ambient: .nan) == .default)
    }

    /// A face whose normal points at the light receives full diffuse light; moving the light away darkens it.
    @Test func aFaceLitHeadOnIsDarkerAfterTheLightMovesAway() {
        var light = WorldLight.default
        let normal = light.direction
        func diffuse() -> Double { max(0, normal.dot(light.direction)) }
        let headOn = diffuse()
        #expect(abs(headOn - 1) < 1e-12)
        light.setAzimuth(light.azimuth + 90)
        #expect(diffuse() < headOn - 0.1)
        light.setElevation(10)
        #expect(diffuse() < headOn - 0.1)
    }

    @Test func theJSONRoundTripIsExactAndInvalidPayloadsAreRefused() throws {
        var light = WorldLight.default
        light.setAzimuth(123.456789012345)
        light.setElevation(33.3)
        light.setAmbient(0.123456789)
        let data = try JSONEncoder().encode(light)
        #expect(try JSONDecoder().decode(WorldLight.self, from: data) == light)
        #expect(String(decoding: data, as: UTF8.self).contains("\"ambient\":0.123456789"))
        for bad in ["{\"ambient\":0.35,\"azimuth\":360,\"elevation\":50}",
                    "{\"ambient\":0.35,\"azimuth\":-1,\"elevation\":50}",
                    "{\"ambient\":0.35,\"azimuth\":30,\"elevation\":86}",
                    "{\"ambient\":0.05,\"azimuth\":30,\"elevation\":50}",
                    "{\"azimuth\":30,\"elevation\":50}"] {
            #expect(throws: (any Error).self, "\(bad)") {
                _ = try JSONDecoder().decode(WorldLight.self, from: Data(bad.utf8))
            }
        }
    }
}
