// ExportOptionsTests — feature 015 T-A01-404 (FR-A01-401, FR-A01-403, FR-A01-405; SC-A01-401).
import Testing
import VisualCoreScenes
@testable import GenerativeArtStudioCore

@Test func allTwelveSizesOnAnUncappedDevice() {
    var seen = Set<String>()
    for edge in ExportOptions.offeredLongEdges {
        for aspect in ExportAspect.builtIns {
            let o = ExportOptions(longEdge: edge, aspect: aspect, maxEdge: 16384)
            #expect(o.size.longEdge == edge)
            #expect(o.size.width % 2 == 0 && o.size.height % 2 == 0)
            seen.insert(o.dimensionsLabel)
        }
    }
    #expect(seen.count == 12)
    #expect(ExportOptions(longEdge: 1080, aspect: .portrait, maxEdge: 16384).dimensionsLabel == "864 × 1080 px")
    #expect(ExportOptions(longEdge: 1080, aspect: .landscape, maxEdge: 16384).dimensionsLabel == "1080 × 608 px")
}

@Test func capsToTheDeviceLimit() {
    let capped = ExportOptions(longEdge: 4096, aspect: .story, maxEdge: 2048)
    #expect(capped.availableLongEdges == [1080, 2048])
    #expect(capped.size == ExportSize(width: 1152, height: 2048))
    #expect(ExportOptions(maxEdge: 16384).availableLongEdges == [1080, 2048, 4096])
    #expect(ExportOptions(maxEdge: 3000).availableLongEdges == [1080, 2048, 3000])
}

@Test func fileNamesAreSanitized() {
    let o = ExportOptions(longEdge: 1080, aspect: .portrait, maxEdge: 16384)
    #expect(o.fileName(for: "My Stars") == "My-Stars-864x1080.png")
    #expect(o.fileName(for: "  ") == "Untitled-864x1080.png")
    #expect(o.fileName(for: "a/b:c✨é_d-e") == "a-b-c--_d-e-864x1080.png")
    #expect(o.fileName(for: String(repeating: "x", count: 100)) == String(repeating: "x", count: 60) + "-864x1080.png")
}

@Test func formatLabelIsTheOnlyOption() {
    #expect(ExportOptions.formatLabel == "Opaque · sRGB")
    #expect(ExportOptions(maxEdge: 4096) == ExportOptions(longEdge: 2048, aspect: .square, maxEdge: 4096))
}
