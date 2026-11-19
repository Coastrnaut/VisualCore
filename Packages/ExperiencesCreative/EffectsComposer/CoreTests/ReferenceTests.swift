// ReferenceTests — feature 180 (A25-P01) T-A25-108 (FR-A25-104; SC-A25-104; clarifications Q1, Q4). The test image
// has the bytes of clarification Q4; the CPU reference leaves the picture unchanged for the identities (grade at its
// defaults, blur radius 0, distort amplitude 0, vignette amount 0) and for a disabled node; spot values of each
// formula; a chain applies its enabled nodes in order.
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
        // grade: contrast 1.5 maps b to (1.5·b − 63.75)/255: 125 → 123.75 → 124, 68 → 38.25 → 38, 0 → 0 (clamped).
        let contrast = EffectReference.apply(Self.node(.grade, ["contrast": 1.5]), to: image)
        #expect(contrast.pixel(x: 31, y: 17) == SIMD4(124, 38, 0, 255))
        // grade: saturation 0 gives the Rec. 709 luma in every channel.
        let grey = EffectReference.apply(Self.node(.grade, ["saturation": 0]), to: image)
        let l = (0.2126 * 125 + 0.7152 * 68 + 0.0722 * 0) as Float
        let luma = UInt8(l.rounded())
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
        // blur radius 1 at an interior pixel: the mean of the 3 × 3 block around it.
        let blurred = EffectReference.apply(Self.node(.blur, ["radius": 1]), to: image)
        var sum = SIMD4<Int>(repeating: 0)
        for j in -1...1 {
            for i in -1...1 { sum &+= SIMD4<Int>(truncatingIfNeeded: image.pixel(x: 20 + i, y: 20 + j)) }
        }
        let mean = SIMD4<UInt8>((0..<4).map { UInt8((Float(sum[$0]) / 9).rounded()) })
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
