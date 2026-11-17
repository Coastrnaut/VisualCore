// FallbackTests — feature 155 (A21-P04) T-A21-408 (FR-A21-403; SC-A21-403; clarification Q4; contracts/lowpower.md
// "Fallback"). Through the one app's session host, drawn off screen at 64 × 48: a forced compile failure of
// `aurora-sky.frag` (the presenter's seam), a host that reports no fragment `highp`, and a change whose second sky
// cannot be built each show the fallback still sky (the sky colour at the top to 0.6 × at the horizon, under the limit,
// never the grey of a failed shader) with "This device shows a simpler sky."; when the fallback fails too, the frame
// is the sky colour. Short runs only.
import CoreGraphics
import Foundation
import SwiftUI
import Testing
import AuroraCore
@testable import AuroraExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct FallbackTests {
    /// A precision report.
    typealias Precision = RenderCapabilities.ShaderPrecision

    /// The largest channel difference of `a` and `b`.
    private static func distance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        Swift.max(Swift.abs(a.x - b.x), Swift.abs(a.y - b.y), Swift.abs(a.z - b.z))
    }

    /// The expected fallback pixel (sRGB, 0…255) of row `row` (top-down) of a `height`-row still for `sky` (linear).
    private func expected(_ sky: SIMD3<Float>, row: Int, height: Int) -> SIMD3<Float> {
        let y = (Float(height - row) - 0.5) / Float(height)
        let scale = SkyShader.fallbackHorizon + (1 - SkyShader.fallbackHorizon) * y
        return SkyPicture.encoded(sky * scale) * 255
    }

    /// Checks that `rgba` (64 × 48, top-down) is the fallback gradient of `sky` under `limit` and not grey.
    private func checkGradient(_ rgba: [UInt8], sky: SIMD3<Float>, limit: Double,
                               sourceLocation: SourceLocation = #_sourceLocation) {
        let width = AuroraTest.width, height = AuroraTest.height
        var largest: Float = 0
        for row in [0, height / 2, height - 1] {
            let want = expected(sky, row: row, height: height)
            for x in [0, width / 2, width - 1] {
                let i = (row * width + x) * 4
                let got = SIMD3<Float>(Float(rgba[i]), Float(rgba[i + 1]), Float(rgba[i + 2]))
                largest = max(largest, Self.distance(got, want))
            }
        }
        #expect(largest <= 2, "the gradient: \(largest) 8-bit steps off", sourceLocation: sourceLocation)
        let top = Int(rgba[2]), bottom = Int(rgba[((height - 1) * width) * 4 + 2])
        #expect(top > bottom, "darker at the horizon: \(top) \(bottom)", sourceLocation: sourceLocation)
        #expect(!(rgba[0] == rgba[1] && rgba[1] == rgba[2]), "not grey", sourceLocation: sourceLocation)
        #expect(AuroraTest.luminance(rgba).max <= Float(limit) + 1 / 255, "under the limit",
                sourceLocation: sourceLocation)
    }

    @Test func aCompileFailureShowsTheFallbackSky() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session) { $0.breakShaders(sky: true, fallback: false) }
        let presenter = shell.presenter
        #expect(presenter.picture.mode == .fallback)
        #expect(presenter.picture.failure?.contains(SkyShader.fragmentName) == true, "\(presenter.picture.failure ?? "")")
        #expect(presenter.mirror.skyNotice == "This device shows a simpler sky.")
        #expect(AuroraPresenter.fallbackMessage == "This device shows a simpler sky.")
        AuroraTest.accept(shell, "light.limit", [0.2])
        let sky = presenter.picture.skyColour
        checkGradient(try AuroraTest.still(session), sky: sky, limit: 0.2)
        // A change of preset changes the fallback's colour; nothing else is built.
        AuroraTest.accept(shell, "preset.select", [1])
        try AuroraTest.draw(session, frames: 3)
        #expect(!presenter.transition.isChanging && presenter.picture.mode == .fallback)
        let violet = SkyInputs(scene: SkyPresets.violetVeil.scene, hue: 0).palette[0]
        #expect(presenter.picture.skyColour == violet)
        checkGradient(try AuroraTest.still(session), sky: violet, limit: 0.2)
        let renders = ImageRenderer(content: presenter.makeControls(shell.port).frame(width: 390))
        #expect(renders.uiImage != nil, "the controls render with the notice")
    }

    @Test func aMissingHighpShowsTheFallbackSky() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session) { presenter in
            presenter.fragmentHighp = { Precision(rangeMin: 0, rangeMax: 0, precisionBits: 0) }
        }
        let presenter = shell.presenter
        #expect(presenter.picture.mode == .fallback && presenter.picture.failure == "no fragment highp")
        #expect(presenter.mirror.skyNotice == AuroraPresenter.fallbackMessage)
        #expect(!presenter.transition.isSetUp, "the full sky was not built")
        checkGradient(try AuroraTest.still(session), sky: presenter.picture.skyColour, limit: SkyCore.defaultLimit)
    }

    @Test func aReportedHighpDrawsTheFullSky() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session) { presenter in
            presenter.fragmentHighp = { Precision(rangeMin: 127, rangeMax: 127, precisionBits: 23) }
        }
        #expect(shell.presenter.picture.mode == .sky && shell.presenter.mirror.skyNotice == nil)
    }

    @Test func aChangeThatCannotBuildItsSecondSkyFallsBack() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session)
        let presenter = shell.presenter
        #expect(presenter.picture.mode == .sky)
        presenter.transition.fragment = "this is not a shader;"   // the next sky built fails
        AuroraTest.accept(shell, "preset.select", [2])
        try AuroraTest.draw(session)
        #expect(presenter.picture.mode == .fallback && presenter.mirror.skyNotice == AuroraPresenter.fallbackMessage)
        #expect(!presenter.transition.isSetUp && !presenter.transition.isChanging)
        let dawn = SkyInputs(scene: SkyPresets.dawnHaze.scene, hue: 0).palette[0]
        checkGradient(try AuroraTest.still(session), sky: dawn, limit: SkyCore.defaultLimit)
    }

    @Test func whenTheFallbackFailsTooTheSkyColourRemains() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AuroraTest.open(session) { $0.breakShaders(sky: true, fallback: true) }
        let presenter = shell.presenter
        #expect(presenter.picture.mode == .clear)
        #expect(presenter.mirror.skyNotice == AuroraPresenter.fallbackMessage)
        let rgba = try AuroraTest.still(session)
        let want = SkyPicture.encoded(presenter.picture.skyColour) * 255
        var largest: Float = 0
        var i = 0
        while i + 3 < rgba.count {
            let got = SIMD3<Float>(Float(rgba[i]), Float(rgba[i + 1]), Float(rgba[i + 2]))
            largest = max(largest, Self.distance(got, want))
            i += 4
        }
        #expect(largest <= 1, "the sky colour everywhere: \(largest)")
        #expect(!(rgba[0] == rgba[1] && rgba[1] == rgba[2]), "not grey: \(rgba[0]) \(rgba[1]) \(rgba[2])")
    }
}
