// PropCatalogTests — feature 091 (A12-P03) T-A12-302 (FR-A12-301; clarification Q1; research D1; SC-A12-301). The
// prop models, host-free and short: every prop mesh validates (closed, consistently wound), stays within 2,000 vertices
// and 1.2 m of height, stands on y = 0, has one palette colour per vertex using all three colours of its palette, a
// picking box equal to its bounds, and is rebuilt identically.
import Foundation
import Testing
import TinyWorldsCore
import VisualCoreMath
import VisualCoreScenes

@Suite struct PropCatalogTests {
    @Test(arguments: PropKind.allCases)
    func everyPropMeshValidatesWithinItsBudget(kind: PropKind) throws {
        let model = PropCatalog.model(kind)
        #expect(model.kind == kind)
        let report = model.mesh.validate(requireClosed: true)
        #expect(report.isValid, "\(kind): \(report)")
        #expect(model.mesh.positions.count <= PropCatalog.maxVertices && model.mesh.positions.count > 0)
        #expect(model.mesh.triangleCount > 0)
        #expect(model.height <= PropCatalog.maxHeight && model.height > 0.3)
        #expect(abs(model.boxMin.y) <= 1e-12, "the base stands on y = 0")
        #expect(model.mesh.bounds == .box(min: model.boxMin, max: model.boxMax), "picking box = bounds")
        #expect(abs(model.boxMin.x + model.boxMax.x) < 1e-9 && abs(model.boxMin.z + model.boxMax.z) < 0.02,
                "centred on the origin")
        #expect(model.colors.count == model.mesh.positions.count)
        let palette = try #require(ContentCatalog.bundled.propPalette(id: kind.contentId))
        let paletteColours = palette.colors.map { Vec4($0.r, $0.g, $0.b, $0.a) }
        #expect(model.colors.allSatisfy { paletteColours.contains($0) }, "every vertex has a palette colour")
        #expect(Set(model.colors).count == 3, "all three palette colours are used")
    }

    @Test func modelsAreDeterministicAndDistinct() {
        for kind in PropKind.allCases {
            #expect(PropCatalog.build(kind, catalog: .bundled) == PropCatalog.model(kind), "\(kind)")
        }
        #expect(Set(PropKind.allCases.map { PropCatalog.model($0).mesh.digest }).count == 4)
        #expect(PropKind.allCases.map(\.rawValue) == [0, 1, 2, 3])
        #expect(PropKind.allCases.map(\.name) == ["Tree", "Rock", "House", "Lantern"])
    }

    @Test func aMissingPaletteGivesMidGrey() {
        let bare = ContentCatalog(palettes: [], presets: [])
        let model = PropCatalog.build(.house, catalog: bare)
        #expect(model.mesh == PropCatalog.model(.house).mesh)
        #expect(model.colors.allSatisfy { $0 == Vec4(0.5, 0.5, 0.5, 1) })
    }
}
