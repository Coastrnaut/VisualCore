// LinearAlgebraTests — feature 006 T-F502 (FR-F501, FR-F509).
import Foundation
import Testing
@testable import VisualCoreMath

func close(_ a: Double, _ b: Double, _ eps: Double = 1e-12) -> Bool { abs(a - b) <= eps }
func close(_ a: Vec2, _ b: Vec2, _ eps: Double = 1e-12) -> Bool { close(a.x, b.x, eps) && close(a.y, b.y, eps) }
func close(_ a: Vec3, _ b: Vec3, _ eps: Double = 1e-12) -> Bool { close(a.x, b.x, eps) && close(a.y, b.y, eps) && close(a.z, b.z, eps) }
func isIdentity(_ m: Mat4, _ eps: Double = 1e-12) -> Bool {
    (0..<4).allSatisfy { i in let r = m.row(i); let e = Mat4.identity.row(i)
        return close(r.x, e.x, eps) && close(r.y, e.y, eps) && close(r.z, e.z, eps) && close(r.w, e.w, eps) }
}

@Test func vectorBasics() {
    #expect(Vec2(3, 4).length == 5)
    #expect(Vec2(1, 0).cross(Vec2(0, 1)) == 1)
    #expect(Vec3(1, 0, 0).cross(Vec3(0, 1, 0)) == Vec3(0, 0, 1))
    #expect(Vec2.zero.normalized == .zero)
    #expect(Vec4(0, 0, 0, 0).mix(Vec4(1, 2, 3, 4), 0.5) == Vec4(0.5, 1, 1.5, 2))
}

@Test func mat3TRSComposesAndInverts() throws {
    let m = Mat3.trs(Vec2(10, -5), .pi / 3, Vec2(2, 0.5))
    let p = Vec2(1.25, -7)
    let inv = try #require(m.inverse)
    #expect(close(inv.apply(m.apply(p)), p))
    #expect(close(Mat3.rotation(.pi / 2).apply(Vec2(1, 0)), Vec2(0, 1)))
    #expect(Mat3.scale(Vec2(0, 1)).inverse == nil)
    #expect(close(Mat3.translation(Vec2(3, 4)).applyVector(Vec2(1, 1)), Vec2(1, 1)), "directions ignore translation")
}

@Test func mat4InverseTimesMatrixIsIdentity() throws {
    let m = Mat4.translation(Vec3(1, 2, 3)) * Mat4.rotation(Quat(axis: Vec3(1, 1, 0), angle: 0.7)) * Mat4.scale(Vec3(2, 3, 4))
    let inv = try #require(m.inverse)
    #expect(isIdentity(inv * m))
    let p = Mat4.perspective(fovY: 1, aspect: 1.5, near: 0.1, far: 100)
    #expect(isIdentity(try #require(p.inverse) * p, 1e-9))
    #expect(Mat4.scale(Vec3(1, 0, 1)).inverse == nil)
}

@Test func lookAtPutsTargetOnNegativeZ() {
    let v = Mat4.lookAt(eye: Vec3(0, 0, 5), target: .zero, up: Vec3(0, 1, 0))
    #expect(close(v.applyPoint(.zero), Vec3(0, 0, -5)))
    let proj = Mat4.perspective(fovY: .pi / 3, aspect: 1, near: 1, far: 10)
    #expect(close(proj.applyPoint(Vec3(0, 0, -1)).z, -1, 1e-12), "near plane maps to -1")
    #expect(close(proj.applyPoint(Vec3(0, 0, -10)).z, 1, 1e-12), "far plane maps to +1")
}

@Test func quaternionMatchesMatrixAndSlerps() {
    let q = Quat(axis: Vec3(0, 0, 1), angle: .pi / 2)
    #expect(close(q.rotate(Vec3(1, 0, 0)), Vec3(0, 1, 0)))
    let axis = Vec3(0.3, -0.5, 0.8)
    let r = Quat(axis: axis, angle: 1.1), v = Vec3(2, -1, 0.5)
    #expect(close(r.rotate(v), r.matrix.applyVector(v)))
    #expect(close((r * r.conjugate).w, 1))
    let half = Quat.identity.slerp(q, 0.5)
    #expect(close(half.rotate(Vec3(1, 0, 0)), Vec3(cos(.pi / 4), sin(.pi / 4), 0)))
    #expect(close(Quat.identity.slerp(q, 1).rotate(Vec3(1, 0, 0)), Vec3(0, 1, 0)))
}

@Test func floatsAreColumnMajor() {
    let m = Mat4.translation(Vec3(7, 8, 9))
    #expect(Array(m.floats[12...14]) == [7, 8, 9])
    #expect(Array(Mat3.translation(Vec2(5, 6)).floats[6...7]) == [5, 6])
}
