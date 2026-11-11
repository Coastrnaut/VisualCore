// SceneTimeTests — feature 033 T-A04-110 (US3 AC1–AC3; SC-A04-104; manual §11 fixture 5, generic part; research R6).
import Testing
@testable import ParticleUniverseCore

private func sim(timeScale: Double = 1) throws -> SceneSimulation {
    var scene = ParticleScene.single(.fountain, seed: 3)
    scene.timeScale = timeScale
    return try SceneSimulation(scene: scene)
}

@Test func aTenSecondFrameRunsAtMostTheCap() throws {
    var s = try sim()
    #expect(s.advance(frame: 10) == SceneSimulation.maxStepsPerFrame)
    #expect(s.stepIndex == 8)
    #expect(s.droppedTime > 9.9)
}

@Test func pausedTimeIsNeverCaughtUp() throws {
    var s = try sim()
    s.advance(frame: 1.0 / 60)
    let before = s.checksum()
    s.pause()
    for _ in 0..<1_800 { #expect(s.advance(frame: 1.0 / 60) == 0) }   // 30 s in the background
    #expect(s.checksum() == before)
    s.resume()
    #expect(s.advance(frame: 0.001) == 0)
    #expect(s.stepIndex == 2)
    #expect(s.droppedTime == 0)
}

@Test func invalidFramesRunNothingAndAreCounted() throws {
    var s = try sim()
    for dt in [Double.nan, -0.5, .infinity, -.infinity] { #expect(s.advance(frame: dt) == 0) }
    #expect(s.invalidFrames == 4 && s.stepIndex == 0)
}

@Test func timeScaleChangesOnlyTheStepCount() throws {
    // R6: the fixed step is unchanged, so the same number of steps gives the same state at any time scale.
    var slow = try sim(timeScale: 0.25), normal = try sim(), fast = try sim(timeScale: 2)
    for _ in 0..<60 { slow.advance(frame: 1.0 / 60); normal.advance(frame: 1.0 / 60); fast.advance(frame: 1.0 / 60) }
    #expect(normal.stepIndex == 120)
    #expect(slow.stepIndex == 30)
    #expect(fast.stepIndex == 240)
    var reference = try sim()
    reference.run(steps: 30)
    #expect(reference.checksum() != normal.checksum())
    var slowSteps = try sim()
    slowSteps.run(steps: slow.stepIndex)
    #expect(slowSteps.checksum() == slow.checksum(), "a slow scene is the same scene, just fewer steps")
}
