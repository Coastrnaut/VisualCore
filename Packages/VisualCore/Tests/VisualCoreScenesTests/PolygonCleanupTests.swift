// PolygonCleanupTests — feature 212 (R02-F12) T-R02F12-002 (FR-R02F12-004, FR-R02F12-006, FR-R02F12-010). Repeated,
// collinear and nearly collinear points are reduced to the corners; a reversed polygon is reversed back; degenerate
// polygons are refused; plane refusals and every reason code.
import Foundation
import Testing
import VisualCoreMath
@testable import VisualCoreScenes

@Suite struct PolygonCleanupTests {
    static let up = Vec3(0, 0, 1)
    static let square = [Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(1, 1, 0), Vec3(0, 1, 0)]

    @Test func repeatedAndCollinearPointsAreRemoved() throws {
        let noisy = [Vec3(0, 0, 0), Vec3(0, 0, 0), Vec3(0.5, 0, 0), Vec3(1, 0, 0), Vec3(1, 0.5, 1e-13),
                     Vec3(1, 1, 0), Vec3(0.5, 1 + 1e-12, 0), Vec3(0, 1, 0), Vec3(0, 0, 1e-13)]
        let clean = try PolygonCleanup.clean(noisy, normal: Self.up, tolerance: 1e-9)
        #expect(clean.count == 4)
        for corner in Self.square { #expect(clean.contains { ($0 - corner).length < 1e-9 }) }
    }

    @Test func aReversedPolygonIsReversedBack() throws {
        let clean = try PolygonCleanup.clean(Self.square.reversed(), normal: Self.up, tolerance: 1e-9)
        #expect(PolygonCleanup.areaVector(clean).dot(Self.up) > 0)
        let same = try PolygonCleanup.clean(Self.square, normal: Self.up, tolerance: 1e-9)
        #expect(same == Self.square)
        #expect(abs(PolygonCleanup.areaVector(Self.square).length - 2) < 1e-12, "twice the unit area")
    }

    @Test func degeneratePolygonsAreRefused() {
        #expect(throws: ConvexSolidError.degeneratePolygon) {
            _ = try PolygonCleanup.clean([Vec3(0, 0, 0), Vec3(1, 0, 0)], normal: Self.up, tolerance: 1e-9)
        }
        #expect(throws: ConvexSolidError.degeneratePolygon) {
            _ = try PolygonCleanup.clean([Vec3(0, 0, 0), Vec3(1, 0, 0), Vec3(2, 0, 0)], normal: Self.up, tolerance: 1e-9)
        }
        #expect(throws: ConvexSolidError.nonFinite("point")) {
            _ = try PolygonCleanup.clean([Vec3(0, 0, .nan), Vec3(1, 0, 0), Vec3(1, 1, 0)], normal: Self.up, tolerance: 1e-9)
        }
    }

    @Test func planesAreValidated() throws {
        #expect(throws: ConvexSolidError.zeroNormal) { _ = try ClipPlane(normal: .zero, offset: 0) }
        #expect(throws: ConvexSolidError.nonFinite("offset")) { _ = try ClipPlane(normal: Vec3(1, 0, 0), offset: .infinity) }
        let plane = try ClipPlane(normal: Vec3(0, 3, 4), offset: 2)
        #expect(abs(plane.normal.length - 1) < 1e-15)
        #expect(abs(plane.distance(to: Vec3(0, 3, 4)) - 3) < 1e-12)
        let back = try JSONDecoder().decode(ClipPlane.self, from: JSONEncoder().encode(plane))
        #expect(back == plane)
        let codes: [ConvexSolidError] = [.nonFinite("x"), .zeroNormal, .empty, .notClosed, .notConvex, .tooComplex("x"),
                                         .degeneratePolygon, .newerSchema(2), .malformed("x")]
        #expect(Set(codes.map(\.reasonCode)).count == 9)
        #expect(codes.allSatisfy { $0.reasonCode.hasPrefix("r2-f12.") })
    }
}
