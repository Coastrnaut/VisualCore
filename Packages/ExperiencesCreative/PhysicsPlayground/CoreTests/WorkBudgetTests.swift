// WorkBudgetTests — feature 086 (A11-P05) T-A11-502 (FR-A11-503; clarification 2; research D2; SC-A11-504). The
// counted work per tick, host-free and short:
// - The measured tick gives the identical world as the plain tick and counts nothing else.
// - At 48 awake bodies and 16 springs (the stress scene of seed 1 with every body woken), every tick of 120 keeps the
//   stated budget: narrow-phase tests ≤ 1,320, contact points ≤ 2 × contacts, solver point updates = iterations ×
//   contact points (≤ the budget).
// - A host timing: the median tick time over 600 ticks at 48 bodies and 16 springs, every body woken every 60 ticks.
//   It is printed for research.md and never asserted (no wall-clock assertions; CI runners are slower).
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import PhysicsPlaygroundCore

@Suite struct WorkBudgetTests {
    private let catalog = MaterialCatalog.bundled

    @Test func theMeasuredTickGivesTheSameWorld() {
        var random = SeededRandom(seed: 9)
        var plain = StartingScene.make(random: &random, catalog: catalog)
        var measured = plain
        var work = WorkCount()
        for _ in 0..<240 {
            #expect(WorldSimulation.tick(&plain, catalog: catalog))
            #expect(WorldSimulation.tick(&measured, catalog: catalog, work: &work))
            #expect(work.budgetProblems(iterations: measured.settings.iterations).isEmpty)
        }
        #expect(plain.encoded() == measured.encoded())
        // A refused tick changes neither the world nor the count.
        var broken = measured
        broken.bodies[1].velocity = Vec2(.nan, 0)
        let kept = work
        #expect(!WorldSimulation.tick(&broken, catalog: catalog, work: &work) && work == kept)
        #expect(WorkCount.maxNarrowPhaseTests == 1_320)
    }

    @Test func fortyEightAwakeBodiesAndSixteenSpringsStayWithinTheBudget() {
        var (world, _) = StressScene.make(seed: 1)
        #expect(WorldSimulation.setGravityLevel(&world, 2))
        #expect(world.bodies.count == 48 && world.springs.count == 16)
        #expect(world.bodies.filter(\.isAwakeDynamic).count == 47 && world.bodies.filter(\.isStatic).count == 1)
        let iterations = world.settings.iterations
        var largest = WorkCount(), first = WorkCount(), work = WorkCount()
        for tick in 0..<120 {
            #expect(WorldSimulation.tick(&world, catalog: catalog, work: &work))
            if tick == 0 { first = work }
            #expect(work.narrowPhaseTests <= 1_320)
            #expect(work.contactPoints <= 2 * work.contacts)
            #expect(work.solverPointUpdates == iterations * work.contactPoints)
            #expect(work.budgetProblems(iterations: iterations).isEmpty)
            largest = WorkCount(narrowPhaseTests: max(largest.narrowPhaseTests, work.narrowPhaseTests),
                                contacts: max(largest.contacts, work.contacts),
                                contactPoints: max(largest.contactPoints, work.contactPoints),
                                solverPointUpdates: max(largest.solverPointUpdates, work.solverPointUpdates))
        }
        print("work at 48 awake bodies and 16 springs, first tick: \(first); largest over 120 ticks: \(largest)")
        #expect(first.narrowPhaseTests > 0 && first.contacts > 0)
    }

    @Test func hostTimingOfSixHundredTicksIsPrinted() {
        var (world, _) = StressScene.make(seed: 2)
        var durations: [Duration] = []
        let clock = ContinuousClock()
        var work = WorkCount(), tests = 0
        for tick in 0..<600 {
            if tick.isMultiple(of: 60) { Sleep.wakeAll(&world) }
            let start = clock.now
            WorldSimulation.tick(&world, catalog: catalog, work: &work)
            durations.append(clock.now - start)
            tests += work.narrowPhaseTests
        }
        let sorted = durations.sorted()
        let median = sorted[sorted.count / 2], slowest = sorted[sorted.count - 1]
        print("host timing: median tick \(median), slowest \(slowest) over 600 ticks at 48 bodies and 16 springs "
              + "(mean narrow-phase tests \(tests / 600)); not asserted")
        #expect(world.tick > 0 && world.isFinite)
    }
}
