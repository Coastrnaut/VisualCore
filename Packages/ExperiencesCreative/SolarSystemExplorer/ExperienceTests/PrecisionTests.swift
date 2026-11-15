// PrecisionTests — feature 105 (A14-P03) T-A14-307 (FR-A14-322; SC-A14-304; clarification Q5; research D5). For both
// scale modes, every body as the focus and zoom steps −1, 0 and 12, every body's camera-relative Float position differs
// from its Double relative position by less than 0.1 pixel at 2,000 pixels and a 60° field of view.
//
// Why it holds (from the values asserted below, not from timing): Float(x) rounds to nearest, so each component's error
// is at most 2⁻²⁴ · |component| and the vector error at most 2⁻²⁴ · |p − target| ≈ 5.96e-8 · |p − target| (asserted per
// body). The tightest limit is at zoom 12: a pixel is 2 · d · tan 30° / 2,000, so 0.1 px is 2.38e-4 units in the
// enhanced mode (d = 60 / 1.25¹² = 4.12) and 4.76e-4 in the true-relative mode (d = 8.25). The farthest relative
// position is under 44 units (enhanced, Neptune 21.9 units out on the far side) or under 125 units (true-relative,
// Neptune about 60 units out), so the error is under 2.7e-6 or 7.5e-6: about 90 and 60 times below the limit.
import Foundation
import XCTest
@testable import SolarSystemExplorerExperience
import SolarSystemExplorerCore
import VisualCoreMath

final class PrecisionTests: XCTestCase {
    private let fieldOfView = Double.pi / 3
    private let heightPixels = 2_000.0

    func testCameraRelativeFloatErrorIsBelowATenthOfAPixel() {
        let zooms: [Int] = [-1, 0, 12]
        let unitRoundoff: Double = 1.0 / 16_777_216   // 2^-24
        for mode in ScaleMode.allCases {
            let bodies = FocusFlight.bodies(mode: mode, day: 0)
            XCTAssertEqual(bodies.count, 9)
            var worstRatio = 0.0
            for zoom in zooms {
                let distance = mode.cameraDistance(zoomSteps: zoom)
                let limit = 0.1 * CameraRelative.pixelSize(distance: distance, fovY: fieldOfView,
                                                           heightPixels: heightPixels)
                XCTAssertGreaterThan(limit, 0)
                for focus in 0..<bodies.count {
                    let target = bodies[focus].center
                    for (k, body) in bodies.enumerated() {
                        let exact = body.center - target
                        let f = CameraRelative.relative(body.center, to: target)
                        let back = Vec3(Double(f.x), Double(f.y), Double(f.z))
                        let error = (back - exact).length
                        XCTAssertLessThanOrEqual(error, unitRoundoff * exact.length * 1.000_001,
                                                 "\(mode) zoom \(zoom) focus \(focus) body \(k): rounding bound")
                        XCTAssertLessThan(error, limit, "\(mode) zoom \(zoom) focus \(focus) body \(k)")
                        worstRatio = max(worstRatio, error / limit)
                    }
                }
            }
            // At least a factor of ten to spare in every case (see the header's arithmetic).
            XCTAssertLessThan(worstRatio, 0.1, "\(mode)")
        }
    }

    func testPixelSize() {
        // 2 · 60 · tan 30° / 2,000 = 0.034641.
        XCTAssertEqual(CameraRelative.pixelSize(distance: 60, fovY: fieldOfView, heightPixels: heightPixels),
                       0.034_641, accuracy: 1e-6)
        XCTAssertEqual(CameraRelative.pixelSize(distance: 60, fovY: fieldOfView, heightPixels: 0), 0)
    }

    func testRelativeIsComputedInDoubleBeforeConversion() {
        // Two points 1e-6 apart, 1e3 from the origin: a Float of each would lose the difference.
        let target = Vec3(1_000, 0, 0)
        let p = Vec3(1_000.000_001, 0, 0)
        let f = CameraRelative.relative(p, to: target)
        XCTAssertEqual(Double(f.x), 1e-6, accuracy: 1e-12)
        XCTAssertEqual(f.y, 0)
        XCTAssertEqual(f.z, 0)
    }
}
