// FrameChecksTests — feature 195 T-U09-008 (FR-U09-040, FR-U09-042; data-model section 3): the pure frame checks on
// small RGBA buffers built in code (rows bottom-up, as RenderHost.readPixels returns them), and the probe validation.
import Foundation
import Testing
import VisualCoreExperience

@Suite struct FrameProbeTests {
    @Test func aProbeLiesInsideTheUnitSquare() {
        #expect(FrameProbe(name: "centre", x: 0.5, y: 0.5, expected: "red") != nil)
        #expect(FrameProbe(name: "corner", x: 0, y: 1, expected: "dark") != nil)
        #expect(FrameProbe(name: "left", x: -0.01, y: 0.5, expected: "red") == nil)
        #expect(FrameProbe(name: "below", x: 0.5, y: 1.01, expected: "red") == nil)
        #expect(FrameProbe(name: "nan", x: .nan, y: 0.5, expected: "red") == nil)
        #expect(FrameProbe(name: "inf", x: 0.5, y: .infinity, expected: "red") == nil)
    }

    @Test func aProbeNeedsANameAndAKnownClass() {
        #expect(FrameProbe(name: "", x: 0.5, y: 0.5, expected: "red") == nil)
        #expect(FrameProbe(name: "p", x: 0.5, y: 0.5, expected: "purple") == nil)
        for colorClass in FrameColorClass.allCases {
            #expect(FrameProbe(name: "p", x: 0.5, y: 0.5, expected: colorClass.rawValue) != nil)
        }
    }
}

#if DEBUG || VISUALCORE_AUTOMATION
@Suite struct FrameChecksTests {
    /// A buffer of `width × height` pixels of one colour.
    private static func uniform(_ width: Int, _ height: Int, _ r: UInt8, _ g: UInt8, _ b: UInt8) -> [UInt8] {
        (0..<(width * height)).flatMap { _ in [r, g, b, UInt8(255)] }
    }

    /// A 4×4 grey gradient along x: 0, 85, 170, 255.
    private static func gradient() -> [UInt8] {
        var bytes: [UInt8] = []
        for _ in 0..<4 {
            for column in 0..<4 {
                let value = UInt8(column * 85)
                bytes += [value, value, value, 255]
            }
        }
        return bytes
    }

    @Test func aUniformFrameIsBlank() {
        #expect(!FrameChecks.isNonBlank(Self.uniform(4, 4, 120, 30, 200), width: 4, height: 4))
    }

    @Test func aSmallLumaSpreadIsBlank() {
        var bytes = Self.uniform(4, 4, 100, 100, 100)
        bytes[0] = 105; bytes[1] = 105; bytes[2] = 105
        #expect(!FrameChecks.isNonBlank(bytes, width: 4, height: 4))
    }

    @Test func aGradientIsNonBlank() {
        #expect(FrameChecks.isNonBlank(Self.gradient(), width: 4, height: 4))
    }

    @Test func blackAllowsFourOf255() {
        #expect(FrameChecks.isBlack(Self.uniform(4, 4, 4, 4, 4), width: 4, height: 4))
        #expect(FrameChecks.isBlack(Self.uniform(4, 4, 0, 0, 0), width: 4, height: 4))
        var bytes = Self.uniform(4, 4, 2, 3, 4)
        bytes[22] = 5
        #expect(!FrameChecks.isBlack(bytes, width: 4, height: 4))
        #expect(!FrameChecks.isBlack(Self.gradient(), width: 4, height: 4))
    }

    @Test func theHistogramHas16BinsSummingToThePixelCount() {
        let counts = FrameChecks.histogram(Self.gradient(), width: 4, height: 4)
        #expect(counts.count == 16)
        #expect(counts.reduce(0, +) == 16)
        #expect(counts[0] == 4)
        #expect(counts[15] == 4)
        let uniform = FrameChecks.histogram(Self.uniform(4, 4, 255, 255, 255), width: 4, height: 4, bins: 8)
        #expect(uniform.count == 8)
        #expect(uniform[7] == 16)
    }

    @Test func nonFiniteValuesAreFound() {
        #expect(!FrameChecks.hasNonFinite([0, 1, -2.5]))
        #expect(!FrameChecks.hasNonFinite([]))
        #expect(FrameChecks.hasNonFinite([0, .nan]))
        #expect(FrameChecks.hasNonFinite([.infinity]))
        #expect(FrameChecks.hasNonFinite([1, -.infinity]))
    }

    @Test func theSilhouetteIsTheBoundingBoxOfTheForeground() {
        // 6×6 black with a white 2×2 square at columns 2–3, rows 2–3.
        var bytes = Self.uniform(6, 6, 0, 0, 0)
        for row in 2...3 {
            for column in 2...3 {
                let index = (row * 6 + column) * 4
                bytes[index] = 255; bytes[index + 1] = 255; bytes[index + 2] = 255
            }
        }
        let bounds = FrameChecks.silhouette(bytes, width: 6, height: 6, background: (0, 0, 0), tolerance: 8)
        #expect(bounds == FrameBounds(minX: 2, minY: 2, maxX: 3, maxY: 3))
    }

    @Test func anEmptyFrameHasNoSilhouette() {
        let bytes = Self.uniform(6, 6, 3, 3, 3)
        #expect(FrameChecks.silhouette(bytes, width: 6, height: 6, background: (0, 0, 0), tolerance: 8) == nil)
    }

    @Test func classifyGivesEveryClass() {
        #expect(FrameChecks.classify(r: 10, g: 10, b: 10) == .dark)
        #expect(FrameChecks.classify(r: 240, g: 240, b: 235) == .light)
        #expect(FrameChecks.classify(r: 220, g: 40, b: 40) == .red)
        #expect(FrameChecks.classify(r: 40, g: 220, b: 40) == .green)
        #expect(FrameChecks.classify(r: 40, g: 60, b: 230) == .blue)
        #expect(FrameChecks.classify(r: 128, g: 128, b: 128) == .other)
        #expect(FrameChecks.classify(r: 200, g: 200, b: 40) == .other)
    }

    @Test func probesMeasureYFromTheTopOfABottomUpBuffer() throws {
        // 2×2: the buffer's first row (the bottom of the image) is red, its second row (the top) is blue. The blue
        // is lifted to (60, 60, 255) because pure (0, 0, 255) has a Rec. 709 luma of 18 and classifies as dark.
        let bytes: [UInt8] = [255, 0, 0, 255, 255, 0, 0, 255,
                              60, 60, 255, 255, 60, 60, 255, 255]
        let top = try #require(FrameProbe(name: "top", x: 0.5, y: 0.0, expected: "blue"))
        let bottom = try #require(FrameProbe(name: "bottom", x: 0.5, y: 1.0, expected: "red"))
        #expect(FrameChecks.probe(top, rgba: bytes, width: 2, height: 2) == .blue)
        #expect(FrameChecks.probe(bottom, rgba: bytes, width: 2, height: 2) == .red)
        let sample = FrameChecks.pixel(bytes, width: 2, height: 2, x: 0, y: 0.25)
        #expect(sample?.b == 255)
        #expect(sample?.r == 60)
    }

    @Test func aWrongBufferSizeNeverTraps() throws {
        let short: [UInt8] = [1, 2, 3]
        #expect(!FrameChecks.isNonBlank(short, width: 4, height: 4))
        #expect(!FrameChecks.isBlack(short, width: 4, height: 4))
        #expect(FrameChecks.histogram(short, width: 4, height: 4).isEmpty)
        #expect(FrameChecks.silhouette(short, width: 4, height: 4, background: (0, 0, 0), tolerance: 0) == nil)
        #expect(FrameChecks.pixel(short, width: 4, height: 4, x: 0.5, y: 0.5) == nil)
        let probe = try #require(FrameProbe(name: "p", x: 0.5, y: 0.5, expected: "red"))
        #expect(FrameChecks.probe(probe, rgba: short, width: 4, height: 4) == nil)
        #expect(!FrameChecks.isBlack([], width: 0, height: 0))
        #expect(!FrameChecks.isNonBlank([], width: -1, height: 4))
        #expect(FrameChecks.histogram(Self.gradient(), width: Int.max, height: Int.max).isEmpty)
        #expect(FrameChecks.histogram(Self.gradient(), width: 4, height: 4, bins: 0).isEmpty)
    }
}
#endif
