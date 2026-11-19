// ColorPathTests — feature 184 (A25-P05) T-A25-503 (FR-A25-504, FR-A25-505; clarification Q1; research R3, R4;
// contracts/color.md). The preview's two precision paths through the one app's session host: each test runs with the
// intermediates at `.rgba16f` (where `FloatRenderSupport` reports it renderable; otherwise that run is skipped with the
// reason printed) and forced to `.rgba8` (`PreviewRenderer.forceStandardPrecision`, set before the first `setup`):
//
//   - identity: a 256 × 4 ramp of every code value (red rising, green falling, blue scrambled) comes back within 1/255
//     through the empty chain, an all-disabled chain and two default colour grades (the identity in linear light, the
//     only identity that goes through a slot of the path's format);
//   - mid-grey 118 with exposure +1 matches `EffectReference.applyChain(_:to:storage:)` within 2/255;
//   - blur radius 2 across a black/white vertical edge: a 5 × 5 box has no half-covered column, so the edge's middle
//     value is the linear-light midpoint of the two columns beside the edge (2/5 and 3/5 of the light), which is
//     188 ± 3 (an encoded-value blur would give about 132); both columns match the reference within 2/255;
//   - every effect, alone, on the test picture, and a four-effect chain (grade, blur, vignette, distort) match
//     `EffectReference.applyChain` with the path's storage (`.half` for `.rgba16f`, `.byte` for `.rgba8`) within 2/255
//     (4/255 with an enabled distort).
// Short runs; no clock, no sleep.
import CoreGraphics
import EffectsComposerCore
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering
@testable import EffectsComposerExperience

@MainActor
@Suite(.serialized) struct ColorPathTests {
    /// The 256 × 4 ramp of every code value: red is the column, green its complement, blue a scramble of it.
    static let ramp: RGBAImage = {
        let width = 256, height = 4
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                bytes[i] = UInt8(x)
                bytes[i + 1] = UInt8(255 - x)
                bytes[i + 2] = UInt8((x * 37 + y * 11) % 256)
            }
        }
        return RGBAImage(width: width, height: height, bytes: bytes)
    }()

    /// A `width × height` picture of one grey `value`.
    static func flat(_ value: UInt8, width: Int = 16, height: Int = 16) -> RGBAImage {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for i in stride(from: 0, to: bytes.count, by: 4) {
            bytes[i] = value
            bytes[i + 1] = value
            bytes[i + 2] = value
        }
        return RGBAImage(width: width, height: height, bytes: bytes)
    }

    /// A 32 × 8 picture: black in columns 0…15, white in 16…31.
    static let edge: RGBAImage = {
        let width = 32, height = 8
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<16 {
                let i = (y * width + x) * 4
                bytes[i] = 0
                bytes[i + 1] = 0
                bytes[i + 2] = 0
            }
        }
        return RGBAImage(width: width, height: height, bytes: bytes)
    }()

    /// The open experience of one path, or nil (with the reason printed) when the half-float path is not available.
    private func open(_ session: ExperienceSession, standard: Bool) async throws -> ExperienceShell<ComposerPresenter>? {
        let shell = try await ComposerTest.open(session) { presenter in
            presenter.renderer.forceStandardPrecision = standard
        }
        let format = shell.presenter.renderer.slotFormat
        if standard {
            #expect(format == .rgba8)
        } else if format != .rgba16f {
            print("ColorPathTests: half-float path skipped: FloatRenderSupport reports .rgba16f not renderable here")
            return nil
        }
        return shell
    }

    /// Makes `picture` the source and draws a frame.
    private func show(_ picture: RGBAImage, _ shell: ExperienceShell<ComposerPresenter>,
                      _ session: ExperienceSession) throws {
        shell.presenter.renderer.setSource(.imported(picture))
        try ComposerTest.draw(session)
    }

    /// The index `chain.add` takes for `effect`.
    private func index(_ effect: EffectID) -> Double {
        Double(ComposerCore.effects.firstIndex(of: effect) ?? 0)
    }

    /// The fraction `chain.set` takes for `value` of parameter `slot` of `effect`.
    private func fraction(_ effect: EffectID, _ slot: Int, _ value: Double) -> Double {
        ComposerCore.fraction(of: EffectLibrary.definition(effect).parameters[slot], value: value)
    }

    /// The largest channel difference between the last result and the reference of the core's chain on `picture`.
    private func referenceDifference(_ shell: ExperienceShell<ComposerPresenter>, on picture: RGBAImage) throws -> Int {
        let chain = try ComposerTest.core(shell).chain
        let result = try #require(shell.presenter.lastResult)
        return result.maxChannelDifference(EffectReference.applyChain(chain, to: picture,
                                                                      storage: ComposerTest.storage(shell)))
    }

    @Test(arguments: [false, true])
    func identityChainsReturnTheRampWithinOneCodeValue(standard: Bool) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        guard let shell = try await open(session, standard: standard) else { return }
        try show(Self.ramp, shell, session)
        let empty = try #require(shell.presenter.lastResult)
        #expect(empty.maxChannelDifference(Self.ramp) <= 1, "empty chain")

        ComposerTest.accept(shell, "chain.add", [index(.grade), 0])
        ComposerTest.accept(shell, "chain.add", [index(.blur), 1])
        ComposerTest.accept(shell, "chain.enable", [0, 0])
        ComposerTest.accept(shell, "chain.enable", [1, 0])
        try ComposerTest.draw(session)
        let disabled = try #require(shell.presenter.lastResult)
        #expect(disabled.maxChannelDifference(Self.ramp) <= 1, "all-disabled chain")

        ComposerTest.accept(shell, "chain.remove", [1])
        ComposerTest.accept(shell, "chain.enable", [0, 1])
        ComposerTest.accept(shell, "chain.add", [index(.grade), 1])
        try ComposerTest.draw(session)
        #expect(shell.presenter.lastPlanUsesSlot, "two grades go through a slot")
        let grades = try #require(shell.presenter.lastResult)
        let d = grades.maxChannelDifference(Self.ramp)
        #expect(d <= 1, "two default grades: \(d)/255")
        print("ColorPathTests identity \(standard ? "rgba8" : "rgba16f"): two default grades \(d)/255")
    }

    @Test(arguments: [false, true])
    func midGreyExposureMatchesTheLinearReference(standard: Bool) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        guard let shell = try await open(session, standard: standard) else { return }
        let grey = Self.flat(118)
        try show(grey, shell, session)
        ComposerTest.accept(shell, "chain.add", [index(.grade), 0])
        ComposerTest.accept(shell, "chain.set", [0, 0, fraction(.grade, 0, 1)])
        try ComposerTest.draw(session)
        let d = try referenceDifference(shell, on: grey)
        #expect(d <= 2, "mid-grey exposure +1: \(d)/255")
        let value = try #require(shell.presenter.lastResult)[8, 8, 0]
        let linear = SRGB.encode(SRGB.decode(118.0 / 255) * 2)
        #expect(abs(Int(value) - Int((linear * 255).rounded())) <= 2, "\(value) against \(linear * 255)")
    }

    @Test(arguments: [false, true])
    func blurAcrossAnEdgeAveragesLight(standard: Bool) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        guard let shell = try await open(session, standard: standard) else { return }
        try show(Self.edge, shell, session)
        ComposerTest.accept(shell, "chain.add", [index(.blur), 0])
        ComposerTest.accept(shell, "chain.set", [0, 0, fraction(.blur, 0, 2)])
        try ComposerTest.draw(session)
        #expect(try referenceDifference(shell, on: Self.edge) <= 2)
        let result = try #require(shell.presenter.lastResult)
        let dark = Float(result[15, 4, 0]) / 255, light = Float(result[16, 4, 0]) / 255
        let middle = Int((SRGB.encode((SRGB.decode(dark) + SRGB.decode(light)) / 2) * 255).rounded())
        #expect(abs(middle - 188) <= 3, "edge middle \(middle) (columns \(result[15, 4, 0]), \(result[16, 4, 0]))")
        print("ColorPathTests edge \(standard ? "rgba8" : "rgba16f"): middle \(middle)/255")
    }

    @Test(arguments: [false, true])
    func everyEffectMatchesTheReferenceWithThePathsStorage(standard: Bool) async throws {
        let session = ExperienceSession()
        defer { session.close() }
        guard let shell = try await open(session, standard: standard) else { return }
        let picture = ComposerTest.image
        var largest = 0
        for effect in ComposerCore.effects {
            ComposerTest.accept(shell, "chain.add", [index(effect), 0])
            try ComposerTest.draw(session)
            let chain = try ComposerTest.core(shell).chain
            let d = try referenceDifference(shell, on: picture)
            #expect(d <= ComposerTest.tolerance(chain), "\(effect): \(d)/255")
            largest = max(largest, d)
            ComposerTest.accept(shell, "chain.remove", [0])
        }
        let effects: [EffectID] = [.grade, .blur, .vignette, .distort]
        for (position, effect) in effects.enumerated() {
            ComposerTest.accept(shell, "chain.add", [index(effect), Double(position)])
        }
        ComposerTest.accept(shell, "chain.set", [0, 0, fraction(.grade, 0, 0.5)])
        try ComposerTest.draw(session)
        let chain = try ComposerTest.core(shell).chain
        let d = try referenceDifference(shell, on: picture)
        #expect(d <= ComposerTest.tolerance(chain), "four-effect chain: \(d)/255")
        print("ColorPathTests effects \(standard ? "rgba8" : "rgba16f"): single \(largest)/255, chain \(d)/255")
    }
}

extension ComposerPresenter {
    /// Whether the plan last drawn wrote a slot (a test helper).
    var lastPlanUsesSlot: Bool {
        renderer.lastPlan?.passes.contains { if case .slot = $0.output { return true } else { return false } } ?? false
    }
}
