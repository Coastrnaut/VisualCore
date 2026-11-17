// SkyRenderTests — feature 152 (A21-P01) T-A21-106 (FR-A21-104, FR-A21-105; SC-A21-102; clarifications Q2, Q3). Each
// preset at levels 0 and 1 drawn off screen at 64 × 48 through VisualCore's `FullScreenShaderScene` matches
// `SkyReference` (mean absolute channel difference ≤ 2/255, largest ≤ 8/255); every pixel's luminance ≤ 0.75 and the
// mean ≥ 0.02; level 1 uses fewer octaves; after `recreateContext` and after a resize the drawing matches again; a
// broken shader reports its name; the twinkle stays within ±30 %. `AuroraOffscreen` is the drawing helper the other
// render tests of this target share.
import XCTest
import AuroraCore
import VisualCoreRendering

/// Off-screen drawing of `aurora-sky.frag` for the tests (feature 152 T-A21-106, T-A21-108).
@MainActor
enum AuroraOffscreen {
    /// The reference size.
    static let width = 64, height = 48

    /// A full-screen scene running `source` (by default the sky) under the name `aurora-sky.frag`.
    static func makeScene(source: String = SkyShader.source) -> FullScreenShaderScene {
        FullScreenShaderScene(fragment: source, fragmentName: SkyShader.fragmentName, bundle: ShaderBundle(files: [:]))
    }

    /// A host with a small live surface that has drawn one frame.
    static func makeHost(_ scene: FullScreenShaderScene) throws -> RenderHost {
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 16, height: 12)
        host.view.layoutIfNeeded()
        XCTAssertTrue(host.renderOneFrame(present: false))
        return host
    }

    /// Binds `uniforms` and draws off screen at `width` × `height` and frame time `time`; RGBA8 rows top-down.
    static func draw(_ host: RenderHost, _ scene: FullScreenShaderScene, _ uniforms: SkyUniforms,
                     width: Int = width, height: Int = height, time: Double = 0) throws -> [UInt8] {
        scene.parameters = uniforms.shaderParameters
        scene.palette = uniforms.palette
        return try host.renderOffscreen(width: width, height: height, time: time).rgba
    }

    /// Mean and largest absolute difference of the colour channels, in 8-bit steps.
    static func difference(_ a: [UInt8], _ b: [UInt8]) -> (mean: Double, max: Int) {
        guard a.count == b.count, !a.isEmpty else { return (.infinity, .max) }
        var sum = 0, largest = 0
        for i in stride(from: 0, to: a.count, by: 4) {
            for c in 0..<3 {
                let d = abs(Int(a[i + c]) - Int(b[i + c]))
                sum += d
                largest = max(largest, d)
            }
        }
        return (Double(sum) / Double(a.count / 4 * 3), largest)
    }

    /// Largest and mean Rec. 709 luminance of the sRGB-decoded pixels.
    static func luminance(_ rgba: [UInt8]) -> (max: Float, mean: Float) {
        var largest: Float = 0, sum: Float = 0
        for i in stride(from: 0, to: rgba.count, by: 4) {
            let l = SkyReference.luminance(rgba: rgba, index: i)
            largest = max(largest, l)
            sum += l
        }
        return (largest, sum / Float(max(rgba.count / 4, 1)))
    }
}

@MainActor
final class SkyRenderTests: XCTestCase {
    private let phase = 0.37

    func testEachPresetMatchesItsReferenceAtBothLevelsWithinTheBrightnessRange() throws {
        let scene = AuroraOffscreen.makeScene()
        let host = try AuroraOffscreen.makeHost(scene)
        defer { host.destroy() }
        XCTAssertNil(scene.errorMessage)
        for preset in SkyPresets.all {
            for level in SkyShader.levels {
                let uniforms = SkyUniforms(scene: preset.scene, phase: phase, level: level)
                let gpu = try AuroraOffscreen.draw(host, scene, uniforms)
                let reference = SkyReference.render(uniforms, width: AuroraOffscreen.width, height: AuroraOffscreen.height)
                let diff = AuroraOffscreen.difference(gpu, reference)
                let lum = AuroraOffscreen.luminance(gpu)
                print("aurora-sky \(preset.id) level \(level): mean diff \(diff.mean)/255, max diff \(diff.max)/255, "
                      + "max luminance \(lum.max), mean luminance \(lum.mean)")
                XCTAssertLessThanOrEqual(diff.mean, 2, "\(preset.id) level \(level) mean difference")
                XCTAssertLessThanOrEqual(diff.max, 8, "\(preset.id) level \(level) largest difference")
                XCTAssertLessThanOrEqual(lum.max, 0.75, "\(preset.id) level \(level) brightest pixel")
                XCTAssertGreaterThanOrEqual(lum.mean, 0.02, "\(preset.id) level \(level) mean luminance")
                let refLum = AuroraOffscreen.luminance(reference)
                XCTAssertLessThanOrEqual(refLum.max, 0.75)
                XCTAssertGreaterThanOrEqual(refLum.mean, 0.02)
            }
        }
    }

    func testLevelOneUsesFewerOctavesAndDrawsLessDetail() throws {
        XCTAssertEqual(SkyShader.octaves(forLevel: 0), 5)
        XCTAssertEqual(SkyShader.octaves(forLevel: 1), 3)
        XCTAssertLessThan(SkyShader.octaves(forLevel: 1), SkyShader.octaves(forLevel: 0))
        let sky = SkyPresets.polarNight.scene
        let full = SkyReference.render(SkyUniforms(scene: sky, phase: phase, level: 0), width: 64, height: 48)
        let reduced = SkyReference.render(SkyUniforms(scene: sky, phase: phase, level: 1), width: 64, height: 48)
        XCTAssertGreaterThan(AuroraOffscreen.difference(full, reduced).max, 0, "the octave count reaches the formulas")
    }

    func testDrawingMatchesAgainAfterContextRecreationAndResize() throws {
        let scene = AuroraOffscreen.makeScene()
        let host = try AuroraOffscreen.makeHost(scene)
        defer { host.destroy() }
        let uniforms = SkyUniforms(scene: SkyPresets.violetVeil.scene, phase: phase, level: 0)
        let reference = SkyReference.render(uniforms, width: 64, height: 48)
        let before = try AuroraOffscreen.draw(host, scene, uniforms)

        host.recreateContext()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertNil(scene.errorMessage)
        let afterLoss = try AuroraOffscreen.draw(host, scene, uniforms)
        XCTAssertEqual(AuroraOffscreen.difference(before, afterLoss).max, 0, "the rebuilt program draws the same")
        XCTAssertLessThanOrEqual(AuroraOffscreen.difference(afterLoss, reference).mean, 2)
        XCTAssertLessThanOrEqual(AuroraOffscreen.difference(afterLoss, reference).max, 8)

        let large = try AuroraOffscreen.draw(host, scene, uniforms, width: 128, height: 96)
        let largeReference = SkyReference.render(uniforms, width: 128, height: 96)
        let largeDiff = AuroraOffscreen.difference(large, largeReference)
        print("aurora-sky resize 128x96: mean diff \(largeDiff.mean)/255, max diff \(largeDiff.max)/255")
        XCTAssertLessThanOrEqual(largeDiff.mean, 2)
        XCTAssertLessThanOrEqual(largeDiff.max, 8)

        host.view.frame = CGRect(x: 0, y: 0, width: 24, height: 18)
        host.view.layoutIfNeeded()
        XCTAssertTrue(host.renderOneFrame(present: false))
        let back = try AuroraOffscreen.draw(host, scene, uniforms)
        XCTAssertEqual(AuroraOffscreen.difference(before, back).max, 0, "back at 64 × 48 after the resizes")
        XCTAssertEqual(host.resources.stats.leaked, 0)
    }

    func testBrokenShaderReportsItsName() throws {
        let broken = SkyShader.source.replacingOccurrences(of: "color = vec4(vc_srgbEncode(rgb), 1.0);",
                                                           with: "color = vec4(au_missing);")
        XCTAssertNotEqual(broken, SkyShader.source)
        let scene = AuroraOffscreen.makeScene(source: broken)
        let host = try AuroraOffscreen.makeHost(scene)
        defer { host.destroy() }
        let message = scene.errorMessage ?? ""
        XCTAssertTrue(message.contains("aurora-sky"), message)
    }

    func testTwinkleStaysWithinThirtyPercentAndLoops() {
        for cx in 0..<16 {
            for cy in 0..<8 {
                let cell = SIMD2(Float(cx) + 101, Float(cy) + 211)
                for step in 0...20 {
                    let factor = SkyReference.twinkle(cell: cell, phase: Float(step) / 20)
                    XCTAssertGreaterThanOrEqual(factor, 0.7 - 1e-5)
                    XCTAssertLessThanOrEqual(factor, 1.3 + 1e-5)
                }
                XCTAssertEqual(SkyReference.twinkle(cell: cell, phase: 0), SkyReference.twinkle(cell: cell, phase: 1))
            }
        }
    }

    func testShaderDeclaresItsUniformsAndIncludesTheLibrary() {
        for name in SkyShader.uniformNames {
            XCTAssertTrue(SkyShader.source.contains("uniform float \(name);"), name)
        }
        XCTAssertTrue(SkyShader.source.contains("#include \"vc/noise.glsl\""))
        XCTAssertEqual(SkyShader.fragmentName, "aurora-sky.frag")
        let uniforms = SkyUniforms(scene: SkyPresets.dawnHaze.scene, phase: 0.5, level: 1)
        XCTAssertEqual(Set(uniforms.shaderParameters.keys),
                       Set(SkyShader.uniformNames.map { String($0.dropFirst(2)) }))
        XCTAssertEqual(uniforms.palette.count, SkyPresets.dawnHaze.scene.palette.count)
    }
}
