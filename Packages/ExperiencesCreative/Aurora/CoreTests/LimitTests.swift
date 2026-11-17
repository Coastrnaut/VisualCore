// LimitTests — feature 153 (A21-P02) T-A21-205 (FR-A21-203; SC-A21-202; clarification Q2). The reference sky under
// every brightness limit: each preset at levels 0 and 1 and limits 0.2, 0.4, 0.6 and 0.72 has no pixel brighter than
// the limit before the encode, and none brighter than the limit + 1/255 after the 8-bit sRGB round trip; a lower limit
// dims the picture (never clips it to white); the default limit is 0.72 and keeps the A21-P01 knee byte for byte; the
// shader declares `u_limit` and the uniforms pass it. Short runs only (64 × 48 references).
import XCTest
import AuroraCore

final class LimitTests: XCTestCase {
    private let limits: [Double] = [0.2, 0.4, 0.6, 0.72]
    private let phase = 0.37

    func testEveryPresetStaysUnderEveryLimit() {
        for preset in SkyPresets.all {
            for level in SkyShader.levels {
                var previousMean: Float = 0
                for limit in limits {
                    let uniforms = SkyUniforms(scene: preset.scene, phase: phase, level: level, limit: limit)
                    let resolution = SIMD2<Float>(64, 48)
                    var largestLinear: Float = 0
                    for y in stride(from: 0, to: 48, by: 3) {
                        for x in stride(from: 0, to: 64, by: 3) {
                            let rgb = SkyReference.linearColor(uniforms, fragCoord: SIMD2(Float(x) + 0.5, Float(y) + 0.5),
                                                               resolution: resolution)
                            largestLinear = max(largestLinear, SkyReference.luminance(rgb))
                        }
                    }
                    XCTAssertLessThanOrEqual(largestLinear, Float(limit) + 1e-5, "\(preset.id) \(level) \(limit) linear")
                    let rgba = SkyReference.render(uniforms, width: 64, height: 48)
                    var largest: Float = 0, sum: Float = 0, white = 0
                    for i in stride(from: 0, to: rgba.count, by: 4) {
                        let l = SkyReference.luminance(rgba: rgba, index: i)
                        largest = max(largest, l)
                        sum += l
                        if rgba[i] == 255, rgba[i + 1] == 255, rgba[i + 2] == 255 { white += 1 }
                    }
                    let mean = sum / Float(rgba.count / 4)
                    print("aurora-limit reference \(preset.id) level \(level) limit \(limit): max luminance \(largest)")
                    XCTAssertLessThanOrEqual(largest, Float(limit) + 1 / 255, "\(preset.id) \(level) \(limit)")
                    XCTAssertEqual(white, 0, "never clipped to white")
                    XCTAssertGreaterThanOrEqual(mean + 1e-6, previousMean, "a higher limit is never darker")
                    previousMean = mean
                }
            }
        }
    }

    func testALowLimitDimsTheBrightestPixelsAndKeepsTheirHue() {
        let uniforms = SkyUniforms(scene: SkyPresets.violetVeil.scene, phase: phase, level: 0, limit: 0.72)
        let dimmed = SkyUniforms(scene: SkyPresets.violetVeil.scene, phase: phase, level: 0, limit: 0.2)
        let resolution = SIMD2<Float>(64, 48)
        var brightest = (lum: Float(0), coord: SIMD2<Float>(0, 0))
        for y in 0..<48 {
            for x in 0..<64 {
                let coord = SIMD2(Float(x) + 0.5, Float(y) + 0.5)
                let l = SkyReference.luminance(SkyReference.linearColor(uniforms, fragCoord: coord,
                                                                        resolution: resolution))
                if l > brightest.lum { brightest = (l, coord) }
            }
        }
        XCTAssertGreaterThan(brightest.lum, 0.2, "the default picture has pixels above the low limit")
        let full = SkyReference.linearColor(uniforms, fragCoord: brightest.coord, resolution: resolution)
        let low = SkyReference.linearColor(dimmed, fragCoord: brightest.coord, resolution: resolution)
        XCTAssertLessThanOrEqual(SkyReference.luminance(low), 0.2 + 1e-5)
        // The knee scales the three channels together: the ratios of the channels stay.
        let fullRatio = full / max(full.x + full.y + full.z, 1e-6)
        let lowRatio = low / max(low.x + low.y + low.z, 1e-6)
        XCTAssertEqual(fullRatio.x, lowRatio.x, accuracy: 1e-4)
        XCTAssertEqual(fullRatio.y, lowRatio.y, accuracy: 1e-4)
        XCTAssertEqual(fullRatio.z, lowRatio.z, accuracy: 1e-4)
    }

    func testTheDefaultLimitIsTheA21P01Knee() {
        XCTAssertEqual(SkyShader.luminanceCeiling, 0.72)
        XCTAssertEqual(SkyShader.kneeRatio * SkyShader.luminanceCeiling, SkyShader.kneeStart, accuracy: 1e-6)
        XCTAssertEqual(SkyShader.limitRange, 0.2...0.72)
        for preset in SkyPresets.all {
            let implicit = SkyUniforms(scene: preset.scene, phase: phase, level: 0)
            XCTAssertEqual(implicit.limit, 0.72)
            let explicit = SkyUniforms(scene: preset.scene, phase: phase, level: 0, limit: 0.72)
            XCTAssertEqual(SkyReference.render(implicit, width: 32, height: 24),
                           SkyReference.render(explicit, width: 32, height: 24))
        }
    }

    func testTheShaderTakesTheLimit() {
        XCTAssertTrue(SkyShader.uniformNames.contains("u_limit"))
        XCTAssertTrue(SkyShader.source.contains("uniform float u_limit;"))
        XCTAssertTrue(SkyShader.source.contains("0.8333333 * u_limit"))
        let uniforms = SkyUniforms(scene: SkyPresets.dawnHaze.scene, phase: 0.5, level: 1, limit: 0.4)
        XCTAssertEqual(uniforms.shaderParameters["limit"], Double(Float(0.4)))
    }
}
