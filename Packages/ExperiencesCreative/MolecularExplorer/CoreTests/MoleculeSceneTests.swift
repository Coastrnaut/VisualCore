// MoleculeSceneTests — feature 111 (A15-P02) T-A15-202 (FR-A15-201, FR-A15-202, FR-A15-210; SC-A15-201). The scene of
// a molecule, host-free and short: the manual's regression fixture (built-in water and ethanol produce the expected
// atom count: 3 atoms and 2 bonds → 4 halves, 9 atoms and 8 bonds → 16 halves); every half of all five library
// molecules starts at its atom's centre and ends at the bond midpoint within 1e-9 Å; space-filling draws atoms at their
// van der Waals radius and no halves, ball-and-stick at 0.30 × with sticks of 0.12 Å; a one-atom molecule has no halves
// and a bounding radius equal to its display radius; the scene is deterministic and within the draw budget.
import Foundation
import Testing
import VisualCoreMath
@testable import MolecularExplorerCore

@Suite struct MoleculeSceneTests {
    /// The library molecule with `id`.
    private func molecule(_ id: String) -> Molecule? {
        MoleculeLibrary.molecules.first { $0.id == id }
    }

    /// The van der Waals radius of `symbol`.
    private func vdw(_ symbol: String) -> Double {
        Elements.element(symbol: symbol)?.vanDerWaalsRadius ?? -1
    }

    @Test func waterAndEthanolProduceTheExpectedCounts() throws {
        let water = try #require(molecule("water"))
        let ethanol = try #require(molecule("ethanol"))
        let waterScene = MoleculeScene(molecule: water, mode: .ballAndStick)
        let ethanolScene = MoleculeScene(molecule: ethanol, mode: .ballAndStick)
        #expect(waterScene.atoms.count == 3 && water.bonds.count == 2 && waterScene.bondHalves.count == 4)
        #expect(ethanolScene.atoms.count == 9 && ethanol.bonds.count == 8 && ethanolScene.bondHalves.count == 16)
        #expect(waterScene.itemCount == 7 && ethanolScene.itemCount == 25)
    }

    @Test func everyHalfRunsFromItsAtomCentreToTheMidpoint() {
        #expect(MoleculeLibrary.molecules.count == 5)
        for molecule in MoleculeLibrary.molecules {
            let scene = MoleculeScene(molecule: molecule, mode: .ballAndStick)
            #expect(scene.bondHalves.count == 2 * molecule.bonds.count, "\(molecule.id)")
            for (index, bond) in molecule.bonds.enumerated() where 2 * index + 1 < scene.bondHalves.count {
                let a = molecule.atoms[bond.a], b = molecule.atoms[bond.b]
                let pa = Vec3(a.x, a.y, a.z), pb = Vec3(b.x, b.y, b.z)
                let middle = (pa + pb) * 0.5
                let first = scene.bondHalves[2 * index], second = scene.bondHalves[2 * index + 1]
                #expect((first.from - pa).length <= 1e-9 && (first.to - middle).length <= 1e-9, "\(molecule.id)")
                #expect((second.from - pb).length <= 1e-9 && (second.to - middle).length <= 1e-9, "\(molecule.id)")
                #expect(first.symbol == a.symbol && second.symbol == b.symbol)
                #expect(first.radius == DisplayMode.stickRadius && second.radius == DisplayMode.stickRadius)
            }
        }
    }

    @Test func theModesSetTheRadiiAndTheSticks() {
        #expect(DisplayMode.allCases.map(\.rawValue) == [0, 1])
        #expect(DisplayMode.allCases.map(\.name) == ["ball-and-stick", "space-filling"])
        #expect(DisplayMode.ballAndStick.atomRadiusFactor == 0.30 && DisplayMode.spaceFilling.atomRadiusFactor == 1.00)
        #expect(DisplayMode.ballAndStick.showsBonds && !DisplayMode.spaceFilling.showsBonds)
        for molecule in MoleculeLibrary.molecules {
            let filling = MoleculeScene(molecule: molecule, mode: .spaceFilling)
            let balls = MoleculeScene(molecule: molecule, mode: .ballAndStick)
            #expect(filling.bondHalves.isEmpty && filling.atoms.count == molecule.atoms.count, "\(molecule.id)")
            for (index, atom) in molecule.atoms.enumerated() {
                #expect(filling.atoms[index].radius == vdw(atom.symbol))
                #expect(abs(balls.atoms[index].radius - 0.30 * vdw(atom.symbol)) <= 1e-12)
                #expect(balls.atoms[index].radius > DisplayMode.stickRadius, "sticks stay inside the atoms")
                #expect(filling.atoms[index].position == Vec3(atom.x, atom.y, atom.z))
            }
            #expect(filling.centre == balls.centre && filling.boundingRadius > balls.boundingRadius)
        }
    }

    @Test func aSingleAtomHasNoHalvesAndIsFramedByItsRadius() throws {
        let atom = Atom(symbol: "C", x: 1, y: -2, z: 3)
        let single = try Molecule.make(id: "carbon", title: "Carbon", atoms: [atom], bonds: [],
                                       source: MoleculeLibrary.source(id: "carbon", cid: 1)).get()
        for mode in DisplayMode.allCases {
            let scene = MoleculeScene(molecule: single, mode: mode)
            #expect(scene.atoms.count == 1 && scene.bondHalves.isEmpty)
            #expect(scene.centre == Vec3(1, -2, 3))
            #expect(scene.boundingRadius == scene.atoms[0].radius && scene.boundingRadius > 0)
        }
    }

    @Test func theSceneIsDeterministicBoundedAndWithinBudget() {
        for molecule in MoleculeLibrary.molecules {
            for mode in DisplayMode.allCases {
                let scene = MoleculeScene(molecule: molecule, mode: mode)
                #expect(scene == MoleculeScene(molecule: molecule, mode: mode), "\(molecule.id)")
                #expect(scene.itemCount <= MoleculeScene.drawBudget && scene.isWithinBudget)
                for item in scene.atoms {
                    #expect((item.position - scene.centre).length + item.radius <= scene.boundingRadius + 1e-12)
                    #expect(scene.boundingRadius >= item.radius)
                }
            }
        }
        #expect(MoleculeScene.drawBudget == 1_500)
    }
}
