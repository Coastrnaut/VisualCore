// ImageComparisonTests — feature 012 T-A01-103.
import Testing
import VisualCoreTestSupport

@Test func identicalImages() {
    let a: [UInt8] = [10, 20, 30, 255, 40, 50, 60, 0]
    let d = ImageComparison.compare(a, a)
    #expect(d.meanAbsolute == 0)
    #expect(d.maxAbsolute == 0)
    #expect(d.fractionWithin(0) == 1)
}

@Test func differencesIgnoreAlpha() {
    let a: [UInt8] = [10, 20, 30, 255, 0, 0, 0, 255]
    let b: [UInt8] = [12, 20, 27, 0, 0, 0, 10, 255]
    let d = ImageComparison.compare(a, b)
    #expect(d.maxAbsolute == 10)
    #expect(abs(d.meanAbsolute - 15.0 / 6) < 1e-12)
    #expect(abs(d.fractionWithin(2) - 4.0 / 6) < 1e-12)
    #expect(abs(d.fractionWithin(3) - 5.0 / 6) < 1e-12)
    #expect(d.fractionWithin(255) == 1)
}

@Test func mismatchedBuffersAreInfinitelyDifferent() {
    #expect(ImageComparison.compare([1, 2, 3, 4], [1, 2, 3]).meanAbsolute == .infinity)
    #expect(ImageComparison.compare([], []).fractionWithin(255) == 0)
}

@Test func statistics() {
    let black: [UInt8] = [0, 0, 0, 255, 0, 0, 0, 255]
    let white: [UInt8] = [255, 255, 255, 255]
    #expect(ImageStatistics.meanLuminance(black) == 0)
    #expect(abs(ImageStatistics.meanLuminance(white) - 1) < 1e-12)
    #expect(ImageStatistics.distinctColors(black + white) == 2)
    #expect(ImageStatistics.distinctColors([0, 0, 0, 255, 7, 7, 7, 255]) == 1)   // same 5-bit bucket
    #expect(ImageStatistics.meanLuminance([]) == 0)
}
