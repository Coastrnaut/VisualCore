// SeedDerivationTests — feature 203 R02-F03 T-R02F03-002 (FR-R02F03-010..012). Golden values were computed
// independently in Python from the data-model "Sub-seed derivation" formulas (SplitMix64 finalizer and FNV-1a-64
// with 64-bit masking), never by running the Swift code. FNV-1a-64 of "" is the published offset basis and of "a"
// the published 0xaf63dc4c8601ec8c; SplitMix64's first output for state 0 is the published 0xE220A8397B1DCDAF.
import Foundation
import Testing
@testable import VisualCoreSimulation

@Test func mixEqualsSplitMixFirstOutputForStateZero() {
    #expect(SeedDerivation.mix(0x9E37_79B9_7F4A_7C15) == 0xE220_A839_7B1D_CDAF)
    var s = SplitMix64(seed: 0)
    #expect(SeedDerivation.mix(0x9E37_79B9_7F4A_7C15) == s.next())
}

@Test func fnv1a64PublishedValues() {
    #expect(SeedDerivation.fnv1a64("") == 0xCBF2_9CE4_8422_2325)
    #expect(SeedDerivation.fnv1a64("a") == 0xAF63_DC4C_8601_EC8C)
    #expect(SeedDerivation.fnv1a64("layout") == 0x9C4F_784A_A5CE_135F)
}

@Test func goldenDerivations() {
    #expect(SeedDerivation.derive(42, label: "layout") == 0x65F4_E083_E2A6_5B82)
    #expect(SeedDerivation.derive(42, index: 0) == 0xC2A6_EEBD_F397_6AD0)
    #expect(SeedDerivation.derive(42, index: 1) == 0x7BFA_87C9_2AA0_CFF0)
}

@Test func differentLabelsAndIndexesDiffer() {
    for seed: UInt64 in [0, 1, 42, .max] {
        #expect(SeedDerivation.derive(seed, label: "a") != SeedDerivation.derive(seed, label: "b"))
        #expect(SeedDerivation.derive(seed, index: 0) != SeedDerivation.derive(seed, index: 1))
        #expect(SeedDerivation.derive(seed, label: "a") != seed)
        #expect(SeedDerivation.derive(seed, index: 0) != seed)
    }
}

@Test func derivationsChain() {
    let chained = SeedDerivation.derive(SeedDerivation.derive(42, label: "layout"), index: 3)
    #expect(chained == 0x21E8_3C5D_5A08_4E86)
    #expect(chained != SeedDerivation.derive(42, index: 3))
}

@Test func generatorInitializersUseDerivedSeeds() {
    var a = SeededRandom(seed: 42, label: "layout")
    var b = SeededRandom(seed: SeedDerivation.derive(42, label: "layout"))
    #expect(a == b)
    #expect(a.seed == 0x65F4_E083_E2A6_5B82)
    #expect((0..<8).map { _ in a.next() } == (0..<8).map { _ in b.next() })
    var c = SeededRandom(seed: 42, index: 1)
    var d = SeededRandom(seed: SeedDerivation.derive(42, index: 1))
    #expect(c == d)
    #expect((0..<8).map { _ in c.next() } == (0..<8).map { _ in d.next() })
}

@Test func drawingFromOneStreamDoesNotChangeAnother() {
    var layout = SeededRandom(seed: 42, label: "layout")
    var color = SeededRandom(seed: 42, label: "color")
    let reference = { () -> [UInt64] in var r = SeededRandom(seed: 42, label: "color"); return (0..<16).map { _ in r.next() } }()
    for _ in 0..<1_000 { _ = layout.next() }
    #expect((0..<16).map { _ in color.next() } == reference)
}
