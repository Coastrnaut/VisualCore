// SymmetryTests — feature 040 (A05-P01) T-A05-102 (FR-A05-101 to FR-A05-103, SC-A05-101; G-SYMMETRY).
import Foundation
import Testing
@testable import VisualCoreMath

private let tolerance = 1e-9

/// True when `a` and `b` agree within `tolerance` in both components.
private func near(_ a: Vec2, _ b: Vec2) -> Bool { abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance }

/// Rotates `p` counter-clockwise by `angle` radians (independent of the code under test).
private func rotated(_ p: Vec2, _ angle: Double) -> Vec2 {
    Vec2(cos(angle) * p.x - sin(angle) * p.y, sin(angle) * p.x + cos(angle) * p.y)
}

/// 1,000 deterministic points in [-3, 3)² from a 64-bit LCG (no Foundation randomness).
private func samplePoints(count: Int = 1_000, seed: UInt64 = 0x5EED_A05) -> [Vec2] {
    var state = seed
    func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(1 << 53)
    }
    return (0..<count).map { _ in Vec2(next() * 6 - 3, next() * 6 - 3) }
}

private let sampledGroups: [PointGroup] = [
    .cyclic(1), .cyclic(2), .cyclic(3), .cyclic(5), .cyclic(6), .cyclic(12), .cyclic(24),
    .dihedral(1), .dihedral(3), .dihedral(6), .dihedral(24),
]

@Test func orderOneIsIdentityForCyclicAndPointPlusMirrorForDihedral() {
    let p = Vec2(0.7, 0.2)
    #expect(PointGroup.cyclic(1).images(of: p) == [p], "cyclic 1 has exactly 1 image, the point itself")
    #expect(PointGroup.cyclic(1).fold(p) == p || near(PointGroup.cyclic(1).fold(p), p), "cyclic 1 fold is identity")
    // Dihedral 1 is the group {identity, mirror across the x axis}: 2 images.
    #expect(PointGroup.dihedral(1).imageCount == 2)
    #expect(PointGroup.dihedral(1).images(of: p) == [p, Vec2(0.7, -0.2)])
}

@Test func imageCountsForEveryOrder() {
    for n in PointGroup.orderRange {
        #expect(PointGroup.cyclic(n).order == n)
        #expect(PointGroup.cyclic(n).imageCount == n)
        #expect(PointGroup.dihedral(n).imageCount == 2 * n)
        #expect(PointGroup.cyclic(n).images(of: Vec2(0.7, 0.2)).count == n)
        #expect(PointGroup.dihedral(n).images(of: Vec2(0.7, 0.2)).count == 2 * n)
        #expect(PointGroup.cyclic(n).isOrderInRange && PointGroup.dihedral(n).isOrderInRange)
    }
}

@Test func outOfRangeOrdersAreClamped() {
    #expect(PointGroup.cyclic(0).order == 1 && !PointGroup.cyclic(0).isOrderInRange)
    #expect(PointGroup.cyclic(-3).imageCount == 1)
    #expect(PointGroup.dihedral(99).order == 24 && PointGroup.dihedral(99).imageCount == 48)
    #expect(PointGroup.cyclic(25).images(of: Vec2(1, 0)).count == 24)
}

@Test func imagesOfAGenericPointAreDistinctWithEqualLength() {
    let p = Vec2(0.7, 0.2) // on no mirror line of any order 1…24
    for n in PointGroup.orderRange {
        for group in [PointGroup.cyclic(n), .dihedral(n)] {
            let images = group.images(of: p)
            #expect(images.first == p, "identity first")
            for (k, a) in images.enumerated() {
                #expect(abs(a.length - p.length) <= tolerance)
                for b in images[(k + 1)...] { #expect(a.distance(to: b) > 1e-6, "\(group) images distinct") }
            }
        }
    }
}

@Test func imagesRepeatWithTheGroupPeriod() {
    let p = Vec2(0.7, 0.2)
    for n in PointGroup.orderRange {
        let step = 2 * Double.pi / Double(n)
        let cyc = PointGroup.cyclic(n).images(of: p)
        for k in 0..<n { #expect(near(rotated(cyc[k], step), cyc[(k + 1) % n]), "cyclic \(n) image \(k)") }
        let dih = PointGroup.dihedral(n).images(of: p)
        #expect(Array(dih[0..<n]).enumerated().allSatisfy { near($0.element, cyc[$0.offset]) }, "rotations first")
        #expect(dih[n] == Vec2(p.x, -p.y), "then the mirror across the x axis")
        for k in 0..<n {
            #expect(near(rotated(dih[n + k], step), dih[n + (k + 1) % n]), "dihedral \(n) mirror image \(k)")
        }
    }
}

@Test(arguments: sampledGroups)
func pointGroupFoldIsIdempotentAndOrbitInvariant(_ group: PointGroup) {
    let wedge = 2 * Double.pi / Double(group.order)
    for p in samplePoints() {
        let f = group.fold(p)
        #expect(near(group.fold(f), f), "\(group) fold idempotent at \(p)")
        #expect(abs(f.length - p.length) <= tolerance, "fold keeps the radius")
        // atan2 gives −π…π; the fold's angle is in 0…2π (order 1 keeps the whole circle), so normalize first.
        let raw = atan2(f.y, f.x), theta = raw < -tolerance ? raw + 2 * Double.pi : raw
        if case .dihedral = group {
            #expect(theta >= -tolerance && theta <= wedge / 2 + tolerance, "dihedral wedge 0 ≤ θ ≤ π/n")
        } else {
            #expect(theta >= -tolerance && (theta < wedge || group.order == 1), "cyclic wedge 0 ≤ θ < 2π/n")
        }
        for image in group.images(of: p) {
            #expect(near(group.fold(image), f), "\(group) every image folds to the same point")
        }
    }
}

@Test func pointGroupOriginAndMirrorLines() {
    for n in PointGroup.orderRange {
        for group in [PointGroup.cyclic(n), .dihedral(n)] {
            #expect(group.fold(.zero) == .zero)
            #expect(group.images(of: .zero).allSatisfy { near($0, .zero) })
            #expect(near(group.fold(Vec2(2, 0)), Vec2(2, 0)), "the x axis is inside the fundamental region")
        }
        let onMirror = rotated(Vec2(1.5, 0), Double.pi / Double(n))
        #expect(near(PointGroup.dihedral(n).fold(onMirror), onMirror), "the π/n mirror line is fixed")
        #expect(near(PointGroup.dihedral(n).fold(Vec2(onMirror.x, -onMirror.y)), onMirror), "−π/n mirrors onto π/n")
    }
    #expect(PointGroup.cyclic(4).fold(Vec2(.nan, 1)) == .zero)
}

@Test func latticeBasisAndImageCounts() {
    #expect(WallpaperLattice.square.pointGroupImages == 8)
    #expect(WallpaperLattice.hexagonal.pointGroupImages == 12)
    #expect(WallpaperLattice.square.basis.0 == Vec2(1, 0) && WallpaperLattice.square.basis.1 == Vec2(0, 1))
    #expect(near(WallpaperLattice.hexagonal.basis.1, Vec2(0.5, 3.0.squareRoot() / 2)))
}

@Test func cellCentersByRing() {
    for lattice in [WallpaperLattice.square, .hexagonal] {
        #expect(lattice.cellCenters(rings: 0) == [.zero])
        #expect(lattice.cellCenters(rings: -2) == [.zero])
        let two = lattice.cellCenters(rings: 2)
        #expect(Set(two).count == two.count, "centres distinct")
        #expect(Array(two.prefix(lattice.cellCenters(rings: 1).count)) == lattice.cellCenters(rings: 1),
                "centre first, then ring by ring")
        #expect(lattice.cellCenters(rings: 2) == two, "deterministic order")
        #expect(lattice.images(of: Vec2(0.1, 0.05), rings: 1).count
                == lattice.cellCenters(rings: 1).count * lattice.pointGroupImages)
    }
    #expect(WallpaperLattice.square.cellCenters(rings: 1).count == 9)
    #expect(WallpaperLattice.square.cellCenters(rings: 2).count == 25)
    #expect(WallpaperLattice.hexagonal.cellCenters(rings: 1).count == 7)
    #expect(WallpaperLattice.hexagonal.cellCenters(rings: 2).count == 19)
    #expect(WallpaperLattice.hexagonal.cellCenters(rings: 1).dropFirst().allSatisfy { abs($0.length - 1) <= tolerance })
}

@Test(arguments: [WallpaperLattice.square, .hexagonal])
func latticeFoldIsIdempotentPeriodicAndOrbitInvariant(_ lattice: WallpaperLattice) {
    let (a, b) = lattice.basis
    for p in samplePoints() {
        let f = lattice.fold(p)
        #expect(near(lattice.fold(f), f), "\(lattice) fold idempotent at \(p)")
        for t in [a, b, -a, -b, a + b] {
            #expect(near(lattice.fold(p + t), f), "\(lattice) fold periodic under \(t)")
        }
        switch lattice {
        case .square:
            #expect(f.y >= 0 && f.y <= f.x + tolerance && f.x <= 0.5 + tolerance, "0 ≤ y ≤ x ≤ ½")
        case .hexagonal:
            #expect(f.y >= -tolerance && atan2(f.y, f.x) <= Double.pi / 6 + tolerance && f.x <= 0.5 + tolerance,
                    "30°-60°-90° triangle")
        }
        for image in lattice.images(of: p, rings: 1) {
            #expect(near(lattice.fold(image), f), "\(lattice) every image folds to the same point")
        }
    }
}

@Test func latticeOriginAndMirrorLines() {
    for lattice in [WallpaperLattice.square, .hexagonal] {
        #expect(lattice.fold(.zero) == .zero)
        for c in lattice.cellCenters(rings: 2) { #expect(near(lattice.fold(c), .zero), "lattice points fold to 0") }
        #expect(near(lattice.fold(Vec2(0.3, 0)), Vec2(0.3, 0)), "the x axis mirror is inside the region")
        #expect(lattice.fold(Vec2(.infinity, 0)) == .zero)
    }
    #expect(near(WallpaperLattice.square.fold(Vec2(0.3, 0.3)), Vec2(0.3, 0.3)), "diagonal mirror fixed")
    #expect(near(WallpaperLattice.square.fold(Vec2(-0.2, 0.4)), Vec2(0.4, 0.2)))
    let thirty = Vec2(0.4 * cos(Double.pi / 6), 0.4 * sin(Double.pi / 6))
    #expect(near(WallpaperLattice.hexagonal.fold(thirty), thirty), "the 30° mirror line is fixed")
}
