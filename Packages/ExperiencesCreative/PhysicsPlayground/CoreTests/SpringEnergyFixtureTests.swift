// SpringEnergyFixtureTests — feature 085 (A11-P04) T-A11-402 (FR-A11-420; clarification 5; SC-A11-404). The phase's
// regression fixture (manual §11 fixture 4), host-free and short, with `WorldDiagnostics.totalEnergy` (kinetic +
// gravitational + spring potential):
// - Spring chain preset (Earth gravity, drag low, stiffness level 2), 1,200 ticks (10 s): the total energy sampled at
//   every whole second never rises by more than 0.5 % of the previous sample and ends below its start.
// - Pendulum preset (Earth gravity, drag none, stiffness level 3), 600 ticks (5 s): the total energy at every tick
//   stays within 5 % of its start (the swing itself is checked in PresetTests).
// Measured on the host (2026-11-15): spring chain total energy 41.4208 J at the start, then per second 41.2355, 41.1171,
// 41.0776, 41.0261, 40.9824, 40.9756, 40.9655, 40.9489, 40.9453 and 40.9465 J (the largest rise, in the last second, is
// 0.0028 %, and the end is 1.15 % below the start); pendulum total energy 142.465 J at the start and 141.993 J after
// 600 ticks, the largest deviation from the start 0.35 % (the spring's damping takes the radial oscillation's energy).
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import PhysicsPlaygroundCore

@Suite struct SpringEnergyFixtureTests {
    private let catalog = MaterialCatalog.bundled

    private func preset(_ id: PresetID) -> PhysicsWorld {
        var random = SeededRandom(seed: 1)
        return Presets.make(id, random: &random, catalog: catalog)
    }

    @Test func theSpringChainsEnergyNeverRisesAndEndsBelowItsStart() {
        var world = preset(.springChain)
        #expect(world.gravityLevel == 2 && world.dragLevel == 1 && world.stiffnessLevel == 2)
        let start = WorldDiagnostics.totalEnergy(world, catalog: catalog)
        var samples = [start]
        for tick in 1...1_200 {
            #expect(WorldSimulation.tick(&world, catalog: catalog))
            if tick.isMultiple(of: 120) { samples.append(WorldDiagnostics.totalEnergy(world, catalog: catalog)) }
        }
        let rises = zip(samples, samples.dropFirst()).map { ($1 - $0) / abs($0) }
        #expect(samples.count == 11)
        #expect(rises.allSatisfy { $0 <= 0.005 }, "largest rise \(rises.max() ?? 0)")
        #expect(samples.last! < start)
        #expect(world.validate(catalog: catalog).isEmpty)
    }

    @Test func thePendulumsEnergyStaysWithinFivePercent() {
        var world = preset(.pendulum)
        #expect(world.gravityLevel == 2 && world.dragLevel == 0 && world.stiffnessLevel == 3)
        let start = WorldDiagnostics.totalEnergy(world, catalog: catalog)
        var deviation = 0.0
        for _ in 1...600 {
            #expect(WorldSimulation.tick(&world, catalog: catalog))
            let energy = WorldDiagnostics.totalEnergy(world, catalog: catalog)
            deviation = max(deviation, abs(energy - start) / abs(start))
        }
        #expect(deviation <= 0.05, "largest deviation \(deviation)")
        #expect(world.validate(catalog: catalog).isEmpty)
    }
}
