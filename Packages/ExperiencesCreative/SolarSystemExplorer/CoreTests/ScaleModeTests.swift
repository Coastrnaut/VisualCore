// ScaleModeTests — feature 105 (A14-P03) T-A14-304 (FR-A14-310, FR-A14-311; SC-A14-302; clarification Q3). The two
// scale modes: the enhanced mode equals A14-P02's mapping and display radii; the true-relative mode keeps the catalog's
// ratios of radius to distance within 0.1 %; labels, names, camera distances and clip ranges.
import Foundation
import SolarSystemExplorerCore
import Testing
import VisualCoreMath

@Suite struct ScaleModeTests {
    @Test func theEnhancedModeKeepsTheOrbitViewMapping() {
        let mode = ScaleMode.enhanced
        let p = Vec3(0.3, -0.2, 0.05)
        let r = p.length
        let expected = Vec3(p.x, p.z, -p.y) * (4 * r.squareRoot() / r)
        let got = mode.scenePosition(p)
        #expect(abs(got.x - expected.x) < 1e-12 && abs(got.y - expected.y) < 1e-12 && abs(got.z - expected.z) < 1e-12)
        #expect(abs(mode.scenePosition(Vec3(30.07, 0, 0)).length - 4 * 30.07.squareRoot()) < 1e-12)
        #expect(mode.scenePosition(.zero) == .zero)
        #expect(mode.drawnRadius(index: 0) == 0.8, "the Sun: 1.6 × 0.5")
        #expect(abs(mode.drawnRadius(index: 1) - 0.25 * 0.6) < 1e-12, "Mercury: 0.25 × 0.6")
        #expect(mode.label == "Distances and sizes not to scale" && mode.name == "Enhanced")
    }

    @Test func theTrueRelativeModeKeepsTheCatalogRatios() {
        let mode = ScaleMode.trueRelative
        let model = OrbitModel.bundled
        let bodies = BodyCatalog.bundled.bodies
        for index in 1..<bodies.count {
            let body = bodies[index]
            guard let p = model.position(bodyID: body.id, day: 0) else {
                Issue.record("\(body.id) has no position")
                continue
            }
            let drawnRatio = mode.drawnRadius(index: index) / mode.scenePosition(p).length
            let catalogRatio = body.meanRadiusKm / (p.length * Units.kmPerAU)
            #expect(abs(drawnRatio / catalogRatio - 1) < 0.001, "\(body.id)")
        }
        #expect(abs(mode.drawnRadius(index: 0) / mode.drawnRadius(index: 3) - 695_700 / 6_371) < 1e-9)
        #expect(mode.drawnRadius(radiusKm: .nan, kind: .planet) == 0)
        #expect(mode.label == "Distances and sizes to one scale; small bodies marked" && mode.name == "True relative")
    }

    @Test func cameraDistancesAndClipRanges() {
        #expect(ScaleMode.enhanced.cameraDistance(zoomSteps: 0) == 60)
        #expect(ScaleMode.trueRelative.cameraDistance(zoomSteps: 0) == 120)
        #expect(abs(ScaleMode.trueRelative.cameraDistance(zoomSteps: -1) - 150) < 1e-12)
        let enhanced = ScaleMode.enhanced.clipRange(distance: 4.12)
        #expect(enhanced.near == 0.5 && enhanced.far == 200)
        let close = ScaleMode.trueRelative.clipRange(distance: 0.001)
        #expect(close.near == 1e-4 && close.far == 70.001)
        let far = ScaleMode.trueRelative.clipRange(distance: 150)
        #expect(far.near == 7.5 && far.far == 220)
        #expect(ScaleMode.allCases.map(\.rawValue) == [0, 1])
    }
}
