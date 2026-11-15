// TutorialTests — feature 085 (A11-P04) T-A11-402 (FR-A11-410; clarification 4; research D4; SC-A11-403). The two
// tutorials, host-free and short: their names and step texts; the steps of "Controlling time" and "Springs and
// energy" complete in order only when their conditions hold; a completed step starts the next one at the context
// world's tick; several steps complete in one call when they all hold; the last step clears the progress; an invalid
// progress is cleared; advancing never changes the world.
import Foundation
import Testing
import VisualCoreMath
import VisualCoreSimulation
import PhysicsPlaygroundCore

@Suite struct TutorialTests {
    private let catalog = MaterialCatalog.bundled

    private func preset(_ id: PresetID) -> PhysicsWorld {
        var random = SeededRandom(seed: 5)
        return Presets.make(id, random: &random, catalog: catalog)
    }

    private func context(_ world: PhysicsWorld, _ starting: PhysicsWorld, origin: ExperimentOrigin = .freePlay,
                         justReset: Bool = false) -> TutorialContext {
        TutorialContext(world: world, startingWorld: starting, origin: origin, justReset: justReset)
    }

    @Test func theTutorialsHaveTheirNamesAndSteps() {
        #expect(Tutorials.all.map(\.id) == [0, 1])
        #expect(Tutorials.all.map(\.name) == ["Controlling time", "Springs and energy"])
        #expect(Tutorials.all[0].steps.map(\.text) == ["Pause the world.", "Step forward one tick.",
                                                       "Choose half speed.", "Press Reset."])
        #expect(Tutorials.all[1].steps.map(\.text) == ["Open the spring chain.", "Show the force arrows.",
                                                       "Let it run for 3 seconds."])
        #expect(Tutorials.all.allSatisfy { $0.author == "VisualCore project" && $0.license == "MIT" })
        #expect(Tutorials.start(2, tick: 0) == nil && Tutorials.start(-1, tick: 0) == nil)
        #expect(Tutorials.start(1, tick: 42) == TutorialProgress(tutorial: 1, step: 0, startTick: 42))
        #expect(Tutorials.text(Tutorials.start(0, tick: 0)) == "Pause the world.")
        #expect(Tutorials.text(nil) == nil)
    }

    @Test func controllingTimeCompletesInOrderOnlyWhenEachConditionHolds() {
        let starting = preset(.stackedObjects)
        var world = starting
        for _ in 0..<10 { WorldSimulation.advanceHostStep(&world, catalog: catalog) }
        var progress = Tutorials.start(0, tick: world.tick)
        // Half speed and a reset before their steps do not complete the pause step.
        world.timeScaleIndex = 1
        #expect(Tutorials.advance(&progress, context: context(world, starting, justReset: true)) == 0)
        #expect(progress?.step == 0)
        world.timeScaleIndex = 2
        // Step 0: pause → step 1 begins at the current tick.
        world.paused = true
        #expect(Tutorials.advance(&progress, context: context(world, starting)) == 1)
        #expect(progress == TutorialProgress(tutorial: 0, step: 1, startTick: world.tick))
        let pausedAt = world.tick
        // Running two ticks does not complete "step one tick"; nor does staying put.
        #expect(Tutorials.advance(&progress, context: context(world, starting)) == 0)
        var twice = world
        WorldSimulation.step(&twice, catalog: catalog); WorldSimulation.step(&twice, catalog: catalog)
        #expect(Tutorials.advance(&progress, context: context(twice, starting)) == 0 && progress?.step == 1)
        // Exactly one tick while paused completes it; step 2 begins at that tick.
        #expect(WorldSimulation.step(&world, catalog: catalog))
        #expect(world.tick == pausedAt + 1)
        #expect(Tutorials.advance(&progress, context: context(world, starting)) == 1)
        #expect(progress == TutorialProgress(tutorial: 0, step: 2, startTick: pausedAt + 1))
        // Step 2: a reset does not count; half speed does.
        #expect(Tutorials.advance(&progress, context: context(world, starting, justReset: true)) == 0)
        world.timeScaleIndex = 1
        #expect(Tutorials.advance(&progress, context: context(world, starting)) == 1 && progress?.step == 3)
        // Step 3: only the caller's reset report completes it; the tutorial then ends.
        #expect(Tutorials.advance(&progress, context: context(world, starting)) == 0 && progress?.step == 3)
        #expect(Tutorials.advance(&progress, context: context(starting, starting, justReset: true)) == 1)
        #expect(progress == nil)
        #expect(Tutorials.advance(&progress, context: context(starting, starting, justReset: true)) == 0)
    }

    @Test func springsAndEnergyCompletesWithTheChainArrowsAndThreeSeconds() {
        var progress = Tutorials.start(1, tick: 0)
        var world = preset(.freePlay)
        world.showForces = true
        // Free play with arrows on: the first step waits for the spring chain.
        #expect(Tutorials.advance(&progress, context: context(world, world)) == 0 && progress?.step == 0)
        // Opening the chain completes step 0; step 1 begins at the chain's tick 0.
        let chain = preset(.springChain)
        world = chain
        #expect(Tutorials.advance(&progress, context: context(world, chain, origin: .preset(2))) == 1)
        #expect(progress == TutorialProgress(tutorial: 1, step: 1, startTick: 0))
        for _ in 0..<30 { WorldSimulation.advanceHostStep(&world, catalog: catalog) }
        world.showForces = true
        #expect(Tutorials.advance(&progress, context: context(world, chain, origin: .preset(2))) == 1)
        #expect(progress == TutorialProgress(tutorial: 1, step: 2, startTick: 30))
        // 359 ticks after the step began is not enough; paused at 360 is not enough; running at 360 is.
        for _ in 0..<359 { WorldSimulation.advanceHostStep(&world, catalog: catalog) }
        #expect(world.tick == 389)
        #expect(Tutorials.advance(&progress, context: context(world, chain, origin: .preset(2))) == 0)
        WorldSimulation.advanceHostStep(&world, catalog: catalog)
        var paused = world
        paused.paused = true
        #expect(Tutorials.advance(&progress, context: context(paused, chain, origin: .preset(2))) == 0)
        let before = world
        #expect(Tutorials.advance(&progress, context: context(world, chain, origin: .preset(2))) == 1)
        #expect(progress == nil && world == before)
    }

    @Test func stepsThatAlreadyHoldCompleteTogetherWithNewStartTicks() {
        var world = preset(.springChain)
        for _ in 0..<5 { WorldSimulation.advanceHostStep(&world, catalog: catalog) }
        world.showForces = true
        var progress = Tutorials.start(1, tick: 0)
        // Origin and arrows both hold: steps 0 and 1 complete; step 2 begins at tick 5 and does not hold yet.
        #expect(Tutorials.advance(&progress, context: context(world, world, origin: .preset(2))) == 2)
        #expect(progress == TutorialProgress(tutorial: 1, step: 2, startTick: 5))
        // The caller's stepStartTick is replaced by the progress's start tick.
        var stale = context(world, world, origin: .preset(2))
        stale.stepStartTick = -1_000
        #expect(Tutorials.advance(&progress, context: stale) == 0)
    }

    @Test func anInvalidProgressIsCleared() {
        let world = preset(.pendulum)
        for bad in [TutorialProgress(tutorial: 2, step: 0, startTick: 0),
                    TutorialProgress(tutorial: 0, step: 4, startTick: 0),
                    TutorialProgress(tutorial: 1, step: -1, startTick: 0),
                    TutorialProgress(tutorial: 0, step: 0, startTick: -1)] {
            var progress: TutorialProgress? = bad
            #expect(!bad.isValid)
            #expect(Tutorials.advance(&progress, context: context(world, world)) == 0 && progress == nil)
            #expect(Tutorials.text(bad) == nil)
        }
        var none: TutorialProgress?
        #expect(Tutorials.advance(&none, context: context(world, world)) == 0 && none == nil)
    }

    @Test func progressRoundTripsAsJSON() throws {
        let progress = TutorialProgress(tutorial: 1, step: 2, startTick: 360)
        let data = try JSONEncoder().encode(progress)
        #expect(try JSONDecoder().decode(TutorialProgress.self, from: data) == progress)
    }
}
