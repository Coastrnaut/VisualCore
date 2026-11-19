// ReferenceTests — feature 180 (A25-P01) T-A25-108 (FR-A25-104; SC-A25-104; clarifications Q1, Q4). The test image
// has the bytes of clarification Q4; the CPU reference leaves the picture unchanged for the identities (grade at its
// defaults, blur radius 0, distort amplitude 0, vignette amount 0) and for a disabled node; spot values of each
// formula; a chain applies its enabled nodes in order.
// A25-P05: grade, blur and vignette work on linear light (T-A25-502), so the grade and blur spot values are now the
// linear computations (contrast pivot 0.18, luma and mean of decoded values, encoded again); tolerances unchanged.
import Testing
import EffectsComposerCore

@Suite struct ReferenceTests {
    /// A node of `effect` with its defaults changed by `values`.
    static func node(_ effect: EffectID, _ values: [String: Double] = [:], enabled: Bool = true) -> EffectNode {
        var node = EffectNode(id: 1, effect: effect, enabled: enabled)
        for (name, value) in values { node.values[name] = value }
        return node
    }

    @Test func theTestImageHasTheBytesOfClarificationQ4() {
        let image = TestImage.make()
        #expect(TestImage.size == 64)
        #expect(image.width == 64 && image.height == 64 && image.bytes.count == 64 * 64 * 4)
        #expect(image.pixel(x: 0, y: 0) == SIMD4(0, 0, 255, 255))
        #expect(image.pixel(x: 63, y: 0) == SIMD4(255, 0, 0, 255), "(63/8 + 0) = 7 is odd")
        #expect(image.pixel(x: 0, y: 63) == SIMD4(0, 255, 0, 255))
        #expect(image.pixel(x: 63, y: 63) == SIMD4(255, 255, 255, 255))
        #expect(image.pixel(x: 8, y: 0) == SIMD4(32, 0, 0, 255), "⌊255·8/63⌋ = 32, square (1, 0) is odd")
        #expect(image.pixel(x: 31, y: 17) == SIMD4(125, 68, 0, 255), "125 = ⌊255·31/63⌋; square (3, 2) is odd")
        #expect(image == TestImage.make(), "the image is deterministic")
    }

    @Test func theIdentitiesLeaveThePictureUnchanged() {
        let image = TestImage.make()
        #expect(EffectReference.apply(Self.node(.grade), to: image) == image, "grade at its defaults")
        #expect(EffectReference.apply(Self.node(.blur, ["radius": 0]), to: image) == image, "blur radius 0")
        #expect(EffectReference.apply(Self.node(.distort, ["amplitude": 0]), to: image) == image, "distort amplitude 0")
        #expect(EffectReference.apply(Self.node(.vignette, ["amount": 0]), to: image) == image, "vignette amount 0")
    }

    @Test func aDisabledNodeLeavesThePictureUnchanged() {
        let image = TestImage.make()
        for effect in EffectID.allCases {
            #expect(EffectReference.apply(Self.node(effect, enabled: false), to: image) == image, "\(effect)")
        }
    }

    @Test func eachFormulaGivesItsSpotValues() {
        let image = TestImage.make()
        // grade: contrast 1.5 maps linear c to (c − 0.18)·1.5 + 0.18: 125 (c 0.2051) → 0.2177 → 128.48 → 128;
        // 68 (c 0.0595) → −0.0008 → 0 (clamped); 0 → 0.
        let contrast = EffectReference.apply(Self.node(.grade, ["contrast": 1.5]), to: image)
        #expect(contrast.pixel(x: 31, y: 17) == SIMD4(128, 0, 0, 255))
        // grade: saturation 0 gives the encoded Rec. 709 luma of the linear values in every channel (82.27 → 82).
        let grey = EffectReference.apply(Self.node(.grade, ["saturation": 0]), to: image)
        let l = 0.2126 * SRGB.decode(125 / 255) + 0.7152 * SRGB.decode(68 / 255) + 0.0722 * SRGB.decode(0)
        let luma = UInt8((SRGB.encode(l) * 255).rounded())
        #expect(luma == 82)
        #expect(grey.pixel(x: 31, y: 17) == SIMD4(luma, luma, luma, 255))
        // posterize 2 levels: each channel 0 or 255 by x ≥ 0.5.
        let two = EffectReference.apply(Self.node(.posterize, ["levels": 2]), to: image)
        #expect(two.pixel(x: 31, y: 17) == SIMD4(0, 0, 0, 255))
        #expect(two.pixel(x: 40, y: 40) == SIMD4(255, 255, 255, 255))
        // vignette amount 1, radius 0.2, softness 0.05: the corners go black, the centre keeps its value.
        let strong = Self.node(.vignette, ["amount": 1, "radius": 0.2, "softness": 0.05])
        let dark = EffectReference.apply(strong, to: image)
        #expect(dark.pixel(x: 0, y: 0) == SIMD4(0, 0, 0, 255))
        #expect(dark.pixel(x: 31, y: 31) == image.pixel(x: 31, y: 31))
        // blur radius 1 at an interior pixel: the encoded mean of the linear values of the 3 × 3 block around it.
        let blurred = EffectReference.apply(Self.node(.blur, ["radius": 1]), to: image)
        var sum = SIMD3<Float>(repeating: 0)
        for j in -1...1 {
            for i in -1...1 {
                let p = image.pixel(x: 20 + i, y: 20 + j)
                sum += SRGB.decode(SIMD3(Float(p.x), Float(p.y), Float(p.z)) / 255)
            }
        }
        let encoded = SRGB.encode(sum / 9)
        let mean = SIMD4<UInt8>((0..<3).map { UInt8((encoded[$0] * 255).rounded()) } + [255])
        #expect(blurred.pixel(x: 20, y: 20) == mean)
    }

    @Test func aChainAppliesItsEnabledNodesInOrder() {
        let image = TestImage.make()
        let grade = Self.node(.grade, ["contrast": 2])
        var posterize = Self.node(.posterize, ["levels": 4])
        posterize.id = 2
        let forward = EffectReference.apply(EffectChain(nodes: [grade, posterize]), to: image)
        #expect(forward == EffectReference.apply(posterize, to: EffectReference.apply(grade, to: image)))
        let reverse = EffectReference.apply(EffectChain(nodes: [posterize, grade]), to: image)
        #expect(forward != reverse, "the order changes the picture")
        posterize.enabled = false
        #expect(EffectReference.apply(EffectChain(nodes: [grade, posterize]), to: image)
                == EffectReference.apply(grade, to: image))
        #expect(EffectReference.apply(EffectChain(), to: image) == image)
    }
}
