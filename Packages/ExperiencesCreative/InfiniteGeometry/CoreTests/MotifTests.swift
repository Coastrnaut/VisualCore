// MotifTests.swift — feature 040 (A05-P01) T-A05-103 (FR-A05-112, FR-A05-113; spec Clarifications: the motif).
import Foundation
import Testing
import VisualCoreMath
@testable import InfiniteGeometryCore

private let planeKinds: [GeometryPreset.Kind] = [.squareTiling, .hexTiling, .kaleidoscope]
private let orders = [1, 2, 3, 8, 24]

/// Independent restatement of the fundamental regions (tolerance 1e-12).
private func inRegion(_ p: Vec2, kind: GeometryPreset.Kind, order: Int) -> Bool {
    let theta = atan2(p.y, p.x), r = p.length, e = 1e-12
    switch kind {
    case .kaleidoscope: return theta >= -e && theta <= .pi / Double(order) + e && r >= 0.15 - e && r <= 0.9 + e
    case .squareTiling: return p.y >= -e && p.y <= p.x + e && p.x <= 0.5 + e
    case .hexTiling: return theta >= -e && theta <= .pi / 6 + e && r <= 0.45 + e
    case .solid: return false
    }
}

private func isStrictlyConvexCounterClockwise(_ points: [Vec2]) -> Bool {
    points.indices.allSatisfy { k in
        let a = points[k], b = points[(k + 1) % points.count], c = points[(k + 2) % points.count]
        return (b - a).cross(c - b) > 0
    }
}

@Test func planeMotifsAreConvexPolygonsInsideTheirRegion() {
    for kind in planeKinds {
        for order in orders {
            for seed in UInt64(0)..<100 {
                let motif = Motif.make(seed: seed, kind: kind, order: order)
                #expect((3...7).contains(motif.points.count), "\(kind) seed \(seed)")
                #expect(isStrictlyConvexCounterClockwise(motif.points), "\(kind) order \(order) seed \(seed)")
                #expect(motif.points.allSatisfy { inRegion($0, kind: kind, order: order) },
                        "\(kind) order \(order) seed \(seed)")
            }
        }
    }
}

@Test func planeMotifsAreFixedPointsOfTheSharedFolds() {
    // The motif lies in the same fundamental region that VisualCoreMath folds into (research D2).
    for seed in UInt64(0)..<50 {
        for order in orders {
            let group = PointGroup.dihedral(order)
            for p in Motif.make(seed: seed, kind: .kaleidoscope, order: order).points {
                #expect(group.fold(p).distance(to: p) < 1e-9, "dihedral(\(order)) seed \(seed)")
            }
        }
        for (kind, lattice) in [(GeometryPreset.Kind.squareTiling, WallpaperLattice.square), (.hexTiling, .hexagonal)] {
            for p in Motif.make(seed: seed, kind: kind, order: 1).points {
                #expect(lattice.fold(p).distance(to: p) < 1e-9, "\(lattice) seed \(seed)")
            }
        }
    }
}

@Test func solidProfilesCloseOnTheAxis() {
    for seed in UInt64(0)..<200 {
        let p = Motif.make(seed: seed, kind: .solid, order: 6).points
        #expect((5...9).contains(p.count))
        #expect(p.first!.x == 0 && p.last!.x == 0)
        #expect((-0.6 ... -0.3).contains(p.first!.y) && (0.3...0.6).contains(p.last!.y))
        #expect(p.dropFirst().dropLast().allSatisfy { (0.05...0.5).contains($0.x) })
        #expect(zip(p, p.dropFirst()).allSatisfy { $0.y < $1.y }, "heights strictly increase")
    }
}

@Test func motifsAreDeterministicAndSeedDependent() {
    for kind in GeometryPreset.Kind.allCases {
        #expect(Motif.make(seed: 42, kind: kind, order: 5) == Motif.make(seed: 42, kind: kind, order: 5))
        let distinct = Set((UInt64(0)..<20).map { Motif.make(seed: $0, kind: kind, order: 5).points })
        #expect(distinct.count == 20, "\(kind): different seeds give different motifs")
    }
}
