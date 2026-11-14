// OriginRebaseTests — feature 054 (A07-P01) T-A07-102 (FR-A07-103; SC-A07-103; gap G-ORIGINREBASE).
import Foundation
import Testing
@testable import VisualCoreMath

@Suite struct OriginRebaseTests {
    @Test func farPositionsStayPreciseAfterRebasing() {
        let camera = Vec3(1e7, 0, 0), point = Vec3(1e7 + 0.3, 0, 0)
        // Plain Float loses the offset: the spacing of Float near 1e7 is 1.
        let plain = Float(point.x) - Float(camera.x)
        #expect(abs(Double(plain) - 0.3) > 0.1)
        var rebase = OriginRebase()
        rebase.update(camera: camera)
        let local = rebase.local(point) - rebase.local(camera)
        #expect(abs(Double(local.x) - 0.3) < 1e-3)
        #expect(abs(Double(rebase.local(point).x) - (point.x - rebase.origin.x)) < 1e-3)
        #expect(abs(rebase.local(camera).x) <= 512)
    }

    @Test func originMovesOnlyPastTheThreshold() {
        var r = OriginRebase()
        #expect(r.origin == .zero)
        r.update(camera: Vec3(1000, -1024, 1024))
        #expect(r.origin == .zero)
        r.update(camera: Vec3(1024.5, 0, 0))
        #expect(r.origin == Vec3(1024, 0, 0))
        r.update(camera: Vec3(2000, 10, -900))
        #expect(r.origin == Vec3(1024, 0, 0))
        r.update(camera: Vec3(3000, 0, 0))
        #expect(r.origin == Vec3(3072, 0, 0))
        r.update(camera: Vec3(3072, 0, -1500))
        #expect(r.origin == Vec3(3072, 0, -1024))
    }

    @Test func nonFiniteCameraIsIgnoredAndUpdatesAreDeterministic() {
        var a = OriginRebase()
        a.update(camera: Vec3(.nan, 5000, 0))
        a.update(camera: Vec3(.infinity, 0, 0))
        #expect(a.origin == .zero)
        var b = OriginRebase()
        for k in 0..<100 {
            let c = Vec3(Double(k) * 977.3, Double(k) * -13.1, 0)
            a.update(camera: c); b.update(camera: c)
        }
        #expect(a == b)
        #expect(OriginRebase.threshold == 1024)
    }
}
