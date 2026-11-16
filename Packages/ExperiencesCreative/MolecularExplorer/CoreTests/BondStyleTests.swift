// BondStyleTests — feature 112 (A15-P03) T-A15-303 (FR-A15-321; clarification Q4; SC-A15-303). Bond styles and the
// scene's styled sticks, host-free and short: the four styles by order and origin; caffeine's four double bonds give
// two sticks of 0.07 Å per half in ball-and-stick, 0.09 Å either side of the bond line; benzene's double-bond sticks
// are offset within the ring's plane; inferred bonds give one 0.06 Å stick on the line; a bond with no neighbour is
// offset perpendicular to the least-aligned axis; every scene stays within the 1,500-item budget.
import Foundation
import Testing
import VisualCoreMath
@testable import MolecularExplorerCore

@Suite struct BondStyleTests {
    /// The library molecule with `id`.
    private func molecule(_ id: String) -> Molecule? {
        MoleculeLibrary.molecules.first { $0.id == id }
    }

    /// The position of `atom`.
    private func position(_ atom: Atom) -> Vec3 { Vec3(atom.x, atom.y, atom.z) }

    @Test func theStylesFollowOrderAndOrigin() {
        #expect(BondStyle.style(order: 1, origin: .recorded) == BondStyle(sticks: 1, radius: 0.12, offsets: [0]))
        #expect(BondStyle.style(order: 2, origin: .recorded) == BondStyle(sticks: 2, radius: 0.07,
                                                                         offsets: [-0.09, 0.09]))
        #expect(BondStyle.style(order: 3, origin: .recorded) == BondStyle(sticks: 3, radius: 0.06,
                                                                         offsets: [-0.12, 0, 0.12]))
        for order in 1...3 {
            #expect(BondStyle.style(order: order, origin: .inferred) == BondStyle(sticks: 1, radius: 0.06,
                                                                                 offsets: [0]))
        }
        #expect(BondStyle.style(order: 1, origin: .recorded).radius == DisplayMode.stickRadius)
    }

    @Test func caffeineDoubleBondsGiveTwoSticksPerHalf() throws {
        let caffeine = try #require(molecule("caffeine"))
        let doubles = caffeine.bonds.filter { $0.order == 2 }.map { [$0.a, $0.b] }
        #expect(doubles == [[0, 8], [1, 9], [5, 10], [6, 7]])
        let scene = MoleculeScene(molecule: caffeine, mode: .ballAndStick)
        #expect(scene.bondHalves.count == 2 * caffeine.bonds.count)
        #expect(scene.sticks.count == 2 * caffeine.bonds.count + 2 * doubles.count && scene.itemCount == 82)
        for (index, bond) in caffeine.bonds.enumerated() {
            let pa = position(caffeine.atoms[bond.a]), pb = position(caffeine.atoms[bond.b])
            let axis = (pb - pa).normalized
            for half in [scene.bondHalves[2 * index], scene.bondHalves[2 * index + 1]] {
                #expect(half.order == bond.order && half.origin == .recorded)
                if bond.order == 2 {
                    #expect(half.sticks.count == 2 && half.radius == 0.07)
                    let gap = half.sticks[1].from - half.sticks[0].from
                    #expect(abs(gap.length - 0.18) <= 1e-9 && abs(gap.dot(axis)) <= 1e-9)
                    #expect(((half.sticks[0].from + half.sticks[1].from) * 0.5 - half.from).length <= 1e-9)
                    #expect((half.sticks[1].to - half.sticks[0].to - gap).length <= 1e-9, "parallel sticks")
                } else {
                    #expect(half.sticks == [MoleculeScene.Stick(from: half.from, to: half.to, symbol: half.symbol,
                                                                 radius: 0.12)])
                }
                #expect(half.sticks.allSatisfy { $0.symbol == half.symbol && $0.radius == half.radius })
            }
        }
        #expect(MoleculeScene(molecule: caffeine, mode: .spaceFilling).sticks.isEmpty)
    }

    @Test func benzeneDoubleBondsLieInTheRingPlane() throws {
        let benzene = try #require(molecule("benzene"))
        let ring = (0..<6).map { position(benzene.atoms[$0]) }
        #expect(benzene.atoms[0..<6].allSatisfy { $0.symbol == "C" })
        let ringNormal = (ring[1] - ring[0]).cross(ring[2] - ring[0]).normalized
        let doubles = benzene.bonds.filter { $0.order == 2 }
        #expect(doubles.count == 3)
        for bond in doubles {
            let side = BondStyle.sideDirection(bond: bond, atoms: benzene.atoms, bonds: benzene.bonds)
            let pa = position(benzene.atoms[bond.a]), pb = position(benzene.atoms[bond.b])
            let neighbour = try #require(benzene.bonds.first { ($0.a == bond.a || $0.b == bond.a) && $0 != bond })
            let n = neighbour.a == bond.a ? neighbour.b : neighbour.a
            #expect(n < 6, "the first neighbouring bond is a ring bond")
            let localNormal = (pb - pa).cross(position(benzene.atoms[n]) - pa).normalized
            #expect(abs(side.length - 1) <= 1e-12 && abs(side.dot((pb - pa).normalized)) <= 1e-12)
            #expect(abs(side.dot(localNormal)) < 1e-6, "in the plane of the neighbouring bond")
            #expect(abs(side.dot(ringNormal)) < 1e-3, "in the ring's plane")
            #expect(side == BondStyle.sideDirection(bond: bond, atoms: benzene.atoms, bonds: benzene.bonds))
        }
    }

    @Test func inferredBondsGiveOneThinStick() throws {
        let water = try #require(molecule("water"))
        let estimate = try Molecule.make(id: "water-inferred", title: "Water", atoms: water.atoms,
                                         bonds: BondInference.bonds(for: water.atoms),
                                         source: MoleculeLibrary.source(id: "water-inferred", cid: 962)).get()
        let scene = MoleculeScene(molecule: estimate, mode: .ballAndStick)
        #expect(scene.bondHalves.count == 4 && scene.sticks.count == 4)
        for half in scene.bondHalves {
            #expect(half.origin == .inferred && half.radius == 0.06)
            #expect(half.sticks == [MoleculeScene.Stick(from: half.from, to: half.to, symbol: half.symbol,
                                                         radius: 0.06)])
        }
    }

    @Test func aLoneBondUsesTheLeastAlignedAxis() throws {
        let atoms = [Atom(symbol: "N", x: 0, y: 0, z: 0), Atom(symbol: "N", x: 1.1, y: 0, z: 0)]
        let bond = Bond(a: 0, b: 1, order: 3, origin: .recorded)
        let nitrogen = try Molecule.make(id: "nitrogen", title: "Nitrogen", atoms: atoms, bonds: [bond],
                                         source: MoleculeLibrary.source(id: "nitrogen", cid: 947)).get()
        #expect(BondStyle.sideDirection(bond: bond, atoms: atoms, bonds: [bond]) == Vec3(0, 0, 1))
        let scene = MoleculeScene(molecule: nitrogen, mode: .ballAndStick)
        #expect(scene.sticks.count == 6 && scene.bondHalves.allSatisfy { $0.sticks.count == 3 && $0.radius == 0.06 })
        let first = scene.bondHalves[0]
        #expect((first.sticks[0].from - Vec3(0, 0, -0.12)).length <= 1e-12)
        #expect(first.sticks[1].from == Vec3(0, 0, 0) && (first.sticks[2].to - Vec3(0.55, 0, 0.12)).length <= 1e-12)
        let tilted = [Atom(symbol: "C", x: 0, y: 0, z: 0), Atom(symbol: "C", x: 0.9, y: 0.2, z: 0.8)]
        let side = BondStyle.sideDirection(bond: Bond(a: 0, b: 1, order: 2, origin: .recorded), atoms: tilted,
                                           bonds: [])
        #expect(abs(side.length - 1) <= 1e-12 && abs(side.dot(Vec3(0.9, 0.2, 0.8))) <= 1e-12)
    }

    @Test func everySceneStaysWithinTheBudget() {
        for molecule in MoleculeLibrary.molecules {
            for mode in DisplayMode.allCases {
                let scene = MoleculeScene(molecule: molecule, mode: mode)
                #expect(scene.itemCount == scene.atoms.count + scene.sticks.count)
                #expect(scene.itemCount <= MoleculeScene.drawBudget, "\(molecule.id) \(mode.name)")
                #expect(scene.sticks == scene.bondHalves.flatMap(\.sticks))
            }
        }
    }
}
