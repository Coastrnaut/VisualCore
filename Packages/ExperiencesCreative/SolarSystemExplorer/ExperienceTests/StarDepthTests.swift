// StarDepthTests — feature 105 (A14-P03) T-A14-308 (FR-A14-303; clarification Q5 as amended during implementation:
// the true-relative far plane is the camera distance + 140, not + 70). The starfield, drawn on a sphere of 0.9 × far
// around the eye, lies beyond every body for every focus and zoom step in both scale modes, so a star never occludes a
// body: the farthest point of any body from the eye is at most |body − focus| + camera distance + drawn radius.
import Foundation
import XCTest
@testable import SolarSystemExplorerExperience
import SolarSystemExplorerCore
import VisualCoreMath

final class StarDepthTests: XCTestCase {
    func testTheStarSphereLiesBeyondEveryBodyInBothModes() {
        let days: [Double] = [0, 9_132, -18_262.5, 18_627.5]
        for mode in ScaleMode.allCases {
            for day in days {
                let bodies = FocusFlight.bodies(mode: mode, day: day)
                for focus in 0..<bodies.count {
                    for zoom in SolarState.zoomRange {
                        let distance = mode.cameraDistance(zoomSteps: zoom)
                        let far = mode.clipRange(distance: distance).far
                        let stars = SceneMeshes.starRadius(far: far)
                        var farthest = 0.0
                        for body in bodies {
                            let offset = body.center - bodies[focus].center
                            farthest = max(farthest, offset.length + distance + body.radius)
                        }
                        XCTAssertGreaterThan(stars, farthest, "\(mode) day \(day) focus \(focus) zoom \(zoom)")
                        XCTAssertLessThan(stars, far, "the stars stay inside the depth range")
                    }
                }
            }
        }
    }
}
