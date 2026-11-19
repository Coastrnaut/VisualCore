// BeamProfileTests — feature 209 (R02-F09) T-R02F09-002 (FR-R02F09-002, FR-R02F09-004; SC-R02F09-002). The falloff is
// exp(−4 r²) inside the beam and 0 outside, the distance to a segment measures to its interior and its ends, and a beam
// of zero length is a round point.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

@Suite struct BeamProfileTests {
    @Test func falloffValues() {
        #expect(BeamProfile.falloff(0) == 1)
        #expect(abs(BeamProfile.falloff(0.5) - exp(-1)) < 1e-15)
        #expect(abs(BeamProfile.falloff(1) - exp(-4)) < 1e-15)
        #expect(BeamProfile.falloff(1.0001) == 0)
        #expect(BeamProfile.falloff(-0.5) == BeamProfile.falloff(0.5))
        var previous = 2.0
        for i in 0...100 {
            let value = BeamProfile.falloff(Double(i) / 100)
            #expect(value <= previous)
            previous = value
        }
    }

    @Test func distanceToSegmentInteriorEndsAndDegenerate() {
        let a = Vec3(0, 0, 0), b = Vec3(2, 0, 0)
        #expect(abs(BeamProfile.distanceToSegment(point: Vec3(1, 0.5, 0), a: a, b: b) - 0.5) < 1e-15)
        #expect(abs(BeamProfile.distanceToSegment(point: Vec3(3, 0, 0), a: a, b: b) - 1) < 1e-15)
        #expect(abs(BeamProfile.distanceToSegment(point: Vec3(-1, 1, 0), a: a, b: b) - 2.0.squareRoot()) < 1e-15)
        #expect(abs(BeamProfile.distanceToSegment(point: Vec3(0, 3, 4), a: a, b: a) - 5) < 1e-15)
    }

    @Test func aZeroLengthBeamIsARoundPoint() {
        let c = Vec3(1, 1, 0)
        for k in 0..<12 {
            let angle = Double(k) * .pi / 6
            let p = c + Vec3(cos(angle), sin(angle), 0) * 0.25
            #expect(abs(BeamProfile.coverage(point: p, a: c, b: c, width: 1) - exp(-1)) < 1e-12)
        }
        #expect(BeamProfile.coverage(point: c, a: c, b: c, width: 0) == 0)
    }
}
