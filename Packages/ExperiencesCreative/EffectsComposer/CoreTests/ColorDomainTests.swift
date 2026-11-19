// ColorDomainTests — feature 184 (A25-P05) T-A25-502 (clarification Q1; research R1, R2, R4, R5; contracts/color.md).
// The CPU sRGB transfer functions round-trip every 8-bit value within 1/255; grade, blur and vignette work on linear
// light and distort and posterize on stored values; grade at its defaults is the identity within 1/255 on the test
// image; mid-grey 118 with exposure +1 is encode(min(1, 2·decode(118/255))) within 1/255; half-float storage between
// nodes differs from 8-bit storage only within 1/255 on an identity chain.
import Testing
import EffectsComposerCore

@Suite struct ColorDomainTests {
    /// A node of `effect` with its defaults changed by `values`.
    static func node(_ effect: EffectID, id: Int = 1, _ values: [String: Double] = [:]) -> EffectNode {
        var node = EffectNode(id: id, effect: effect)
        for (name, value) in values { node.values[name] = value }
        return node
    }

    /// A flat opaque `size × size` picture of grey `value`.
    static func flat(_ value: UInt8, size: Int = 8) -> RGBAImage {
        var bytes: [UInt8] = []
        for _ in 0..<(size * size) { bytes += [value, value, value, 255] }
        return RGBAImage(width: size, height: size, bytes: bytes)
    }

    /// A 256 × 1 ramp: red n, green 255 − n, blue n at column n.
    static let ramp: RGBAImage = {
        var bytes: [UInt8] = []
        for n in 0...255 { bytes += [UInt8(n), UInt8(255 - n), UInt8(n), 255] }
        return RGBAImage(width: 256, height: 1, bytes: bytes)
    }()

    @Test func theTransferFunctionsRoundTripEveryByte() {
        var largest = 0
        for n in 0...255 {
            let back = Int((SRGB.encode(SRGB.decode(Float(n) / 255)) * 255).rounded())
            largest = max(largest, abs(back - n))
        }
        #expect(largest <= 1, "largest round-trip difference \(largest)/255")
        #expect(SRGB.decode(0) == 0 && SRGB.encode(0) == 0)
        #expect(abs(SRGB.decode(1) - 1) < 1e-6 && abs(SRGB.encode(1) - 1) < 1e-6)
        #expect(abs(SRGB.decode(0.04) - 0.04 / 12.92) < 1e-7, "the linear segment below 0.04045")
        #expect(abs(SRGB.encode(0.003) - 0.003 * 12.92) < 1e-7, "the linear segment below 0.0031308")
        #expect(SRGB.decode(2) == SRGB.decode(1) && SRGB.encode(-1) == 0, "inputs are clamped to 0…1")
    }

    @Test func eachEffectHasItsDomain() {
        #expect(EffectID.grade.colorDomain == .linear)
        #expect(EffectID.blur.colorDomain == .linear)
        #expect(EffectID.vignette.colorDomain == .linear)
        #expect(EffectID.distort.colorDomain == .stored)
        #expect(EffectID.posterize.colorDomain == .stored)
    }

    @Test func gradeAtItsDefaultsIsTheIdentity() {
        for image in [TestImage.make(), Self.ramp] {
            let graded = EffectReference.apply(Self.node(.grade), to: image)
            #expect(graded.maxChannelDifference(image) <= 1)
        }
    }

    @Test func midGreyWithExposurePlusOneIsTheLinearComputation() {
        let image = Self.flat(118)
        let graded = EffectReference.apply(Self.node(.grade, ["exposure": 1]), to: image)
        let expected = SRGB.encode(min(1, 2 * SRGB.decode(118 / 255))) * 255
        for c in 0..<3 {
            #expect(abs(Float(graded[3, 3, c]) - expected) <= 1, "channel \(c): \(graded[3, 3, c]) vs \(expected)")
        }
        #expect(graded[3, 3, 3] == 255)
        #expect(Int(expected.rounded()) == 162, "not the stored-value 236 of 2·118")
    }

    @Test func halfStorageDiffersFromByteStorageOnlyWithinOneStep() {
        let chain = EffectChain(nodes: [Self.node(.grade, id: 1), Self.node(.blur, id: 2, ["radius": 0]),
                                        Self.node(.vignette, id: 3, ["amount": 0])])
        for image in [TestImage.make(), Self.ramp] {
            let byte = EffectReference.applyChain(chain, to: image, storage: .byte)
            let half = EffectReference.applyChain(chain, to: image, storage: .half)
            #expect(byte == EffectReference.apply(chain, to: image), "the default chain function stores bytes")
            #expect(half.maxChannelDifference(byte) <= 1)
            #expect(half.maxChannelDifference(image) <= 1)
        }
    }
}
