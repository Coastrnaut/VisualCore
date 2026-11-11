// ExportGeometryTests — feature 015 T-A01-401 (FR-A01-401, FR-A01-405, SC-A01-401; research R5).
import Testing
@testable import VisualCoreScenes

private let unlimited = ExportGeometry(maxEdge: 16384)

@Test func twelveCombinationsHaveExactDimensions() {
    let expected: [Int: [String: (Int, Int)]] = [
        1080: ["square": (1080, 1080), "portrait": (864, 1080), "landscape": (1080, 608), "story": (608, 1080)],
        2048: ["square": (2048, 2048), "portrait": (1638, 2048), "landscape": (2048, 1152), "story": (1152, 2048)],
        4096: ["square": (4096, 4096), "portrait": (3276, 4096), "landscape": (4096, 2304), "story": (2304, 4096)],
    ]
    for (edge, rows) in expected {
        for aspect in ExportAspect.builtIns {
            let s = unlimited.size(longEdge: edge, aspect: aspect)
            let want = rows[aspect.id]!
            #expect(s.width == want.0 && s.height == want.1, "\(edge) \(aspect.id): \(s.width)x\(s.height)")
            #expect(s.width % 2 == 0 && s.height % 2 == 0)
            #expect(s.longEdge == edge)
        }
    }
}

@Test func capsAtDeviceEdgeAndHardEdge() {
    let device = ExportGeometry(maxEdge: 2048)
    #expect(device.clampedLongEdge(4096) == 2048)
    #expect(device.size(longEdge: 4096, aspect: .landscape) == ExportSize(width: 2048, height: 1152))
    let odd = ExportGeometry(maxEdge: 3001)
    #expect(odd.effectiveMaxEdge == 3000)
    let huge = ExportGeometry(maxEdge: 16384, maxPixels: .max)
    #expect(huge.effectiveMaxEdge == 8192)
    #expect(huge.size(longEdge: 10000, aspect: .story).height == 8192)
}

@Test func pixelCountCapShrinksWithEvenEdges() {
    let g = ExportGeometry(maxEdge: 8192)           // 8192² = 67.1 MP > 64 MP
    let s = g.size(longEdge: 8192, aspect: .square)
    #expect(s.pixelCount <= ExportGeometry.defaultMaxPixels)
    #expect(s.width == 8000 && s.height == 8000)
    let small = ExportGeometry(maxEdge: 4096, maxPixels: 1_000_000)
    let p = small.size(longEdge: 4096, aspect: .portrait)
    #expect(p.pixelCount <= 1_000_000 && p.width % 2 == 0 && p.height % 2 == 0)
}

@Test func invalidRatiosAreRejectedAndTinySizesClamp() {
    #expect(ExportAspect(id: "x", title: "x", width: 0, height: 1) == nil)
    #expect(ExportAspect(id: "x", title: "x", width: 3, height: -2) == nil)
    let wide = ExportAspect(id: "pano", title: "Pano", width: 100, height: 1)!
    #expect(unlimited.size(longEdge: 1080, aspect: wide) == ExportSize(width: 1080, height: 10))
    let ultra = ExportAspect(id: "u", title: "U", width: 10000, height: 1)!
    #expect(unlimited.size(longEdge: 1080, aspect: ultra).height == 2)
    #expect(unlimited.size(longEdge: 0, aspect: .square) == ExportSize(width: 2, height: 2))
    #expect(ExportGeometry(maxEdge: 0).effectiveMaxEdge == 2)
}
