// ShellRenderingTests — feature 188 (UA-F02) T-U02-035 (US5; SC-U02-006; contract
// specs/188-ua-f02-experience-sdk/contracts/experience-host-api.md). The shell's scene on a real render host:
// what is drawn, when steps run, context recreation, tiers, cache shedding and the GPU counts of a leave.
// Runs on iOS simulators; frames are rendered without presenting and read back (pattern of RenderHostTests).
import XCTest
import VisualCoreRendering
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreTestSupport

@MainActor
final class ShellRenderingTests: XCTestCase {
    // MARK: What is drawn

    func testCentrePixelShowsTheStateAfterPreparation() async throws {
        let (presenter, shell) = try await makeReadySampleShell()
        let host = try makeLaidOutHost(shell.scene)
        defer { host.destroy() }
        XCTAssertEqual(shell.state, .ready)
        XCTAssertEqual(presenter.setupCalls, 1)
        XCTAssertTrue(shell.isSetUp)
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(presenter.drawCalls, 1)
        let core = try XCTUnwrap(shell.engine.core)
        let found = centrePixel(of: host), expected = expectedPixel(for: core)
        XCTAssertEqual(expected.r, core.x * 17)
        XCTAssertEqual(expected.g, core.y * 17)
        XCTAssertEqual(expected.b, 0, "the tone starts at 0")
        XCTAssertTrue(pixelsMatch(found, expected), "found \(found), expected \(expected)")
    }

    func testCentrePixelFollowsAcceptedActions() async throws {
        let (_, shell) = try await makeReadySampleShell()
        let host = try makeLaidOutHost(shell.scene)
        defer { host.destroy() }
        try shell.activate()
        XCTAssertEqual(shell.handle(control: "tone", values: [0.5]), .accepted)
        let before = try XCTUnwrap(shell.engine.core)
        let direction: Double = before.x < 15 ? 1 : -1
        XCTAssertEqual(shell.handle(control: "move", values: [direction, 0]), .accepted)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let core = try XCTUnwrap(shell.engine.core)
        XCTAssertEqual(core.x, before.x + Int(direction))
        let found = centrePixel(of: host), expected = expectedPixel(for: core)
        XCTAssertEqual(expected.b, 128)
        XCTAssertTrue(pixelsMatch(found, expected), "found \(found), expected \(expected)")
    }

    // MARK: When steps run

    func testHundredTwentyFramesInReadyLeaveTheDigestUnchanged() async throws {
        let (presenter, shell) = try await makeReadySampleShell()
        let host = try makeLaidOutHost(shell.scene)
        defer { host.destroy() }
        let before = try shell.engine.digest()
        for _ in 0..<120 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertEqual(shell.state, .ready)
        XCTAssertEqual(presenter.drawCalls, 120)
        XCTAssertEqual(shell.engine.stepIndex, 0)
        XCTAssertEqual(shell.engine.core?.updateCalls, 0)
        XCTAssertEqual(try shell.engine.digest(), before)
        XCTAssertTrue(centreShowsState(host, shell))
    }

    func testFramesRunStepsWhileActive() async throws {
        let (presenter, shell) = try await makeReadySampleShell()
        let host = try makeLaidOutHost(shell.scene)
        defer { host.destroy() }
        let before = try shell.engine.digest()
        try shell.activate()
        let frames = 60
        for _ in 0..<frames { XCTAssertTrue(host.renderOneFrame(present: false)) }
        XCTAssertEqual(shell.state, .active)
        XCTAssertEqual(presenter.drawCalls, frames)
        // A test frame lasts 1/60 s and a step of the sample 1/120 s: about two steps per frame, never more than 8.
        XCTAssertGreaterThanOrEqual(shell.engine.stepIndex, frames)
        XCTAssertLessThanOrEqual(shell.engine.stepIndex, frames * 8)
        XCTAssertEqual(shell.engine.core?.ticks, shell.engine.stepIndex)
        XCTAssertNotEqual(try shell.engine.digest(), before, "the phase advanced")
        XCTAssertTrue(centreShowsState(host, shell))
    }

    // MARK: Context recreation

    func testAfterContextRecreationTheSampleDrawsAgainWithANewTexture() async throws {
        let (presenter, shell) = try await makeReadySampleShell()
        let host = try makeLaidOutHost(shell.scene)
        defer { host.destroy() }
        XCTAssertTrue(host.renderOneFrame(present: false))
        let digest = try shell.engine.digest()
        let first = try XCTUnwrap(presenter.texture)

        host.recreateContext()

        XCTAssertEqual(presenter.setupCalls, 2)
        XCTAssertEqual(presenter.teardownCalls, 1)
        let second = try XCTUnwrap(presenter.texture)
        XCTAssertFalse(first === second, "setup created a new texture for the new context")
        XCTAssertEqual(host.resources.stats.liveTotal, 1)
        XCTAssertEqual(host.resources.stats.leaked, 0)
        XCTAssertEqual(shell.state, .ready)
        XCTAssertTrue(shell.isSetUp)
        let drawn = presenter.drawCalls
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(presenter.drawCalls, drawn + 1)
        XCTAssertEqual(try shell.engine.digest(), digest)
        XCTAssertTrue(centreShowsState(host, shell))
    }

    // MARK: Tiers and cache shedding

    func testEachTierAndACacheSheddingLeaveTheDigestUnchangedAndTheNextFrameCorrect() async throws {
        let (presenter, shell) = try await makeReadySampleShell()
        let host = try makeLaidOutHost(shell.scene)
        defer { host.destroy() }
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(presenter.lastTier, 0)
        let digest = try shell.engine.digest()

        for tier in [1, 2, 0] {
            try shell.setQualityTier(tier)
            XCTAssertEqual(shell.engine.qualityTier, tier)
            XCTAssertEqual(try shell.engine.digest(), digest, "tier \(tier)")
            XCTAssertTrue(host.renderOneFrame(present: false))
            XCTAssertEqual(presenter.lastTier, tier)
            XCTAssertTrue(centreShowsState(host, shell), "tier \(tier)")
        }

        XCTAssertEqual(presenter.shedCalls, 0)
        try shell.shedCaches()
        XCTAssertEqual(presenter.shedCalls, 1)
        XCTAssertEqual(shell.engine.core?.cache, [])
        XCTAssertEqual(try shell.engine.digest(), digest)
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertTrue(centreShowsState(host, shell))
        XCTAssertEqual(try shell.engine.digest(), digest)
    }

    // MARK: Leaving (SC-U02-006)

    func testLiveObjectsAreAboveZeroWhileActive() async throws {
        let (_, shell) = try await makeReadySampleShell()
        let host = try makeLaidOutHost(shell.scene)
        defer { host.destroy() }
        try shell.activate()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertGreaterThan(host.resources.stats.liveTotal, 0)
        let gpu = try XCTUnwrap(shell.diagnostics.gpu)
        XCTAssertGreaterThan(gpu.objects, 0)
        XCTAssertGreaterThan(gpu.bytes, 0)
        XCTAssertEqual(gpu.leaked, 0)
    }

    func testDeactivationWithDestroyEndsInactiveWithNothingLiveOrLeaked() async throws {
        let (presenter, shell) = try await makeReadySampleShell()
        let host = try makeLaidOutHost(shell.scene)
        try shell.activate()
        XCTAssertTrue(host.renderOneFrame(present: false))

        try shell.beginDeactivation()
        XCTAssertEqual(shell.state, .deactivating)
        host.destroy()
        XCTAssertEqual(presenter.teardownCalls, 1)
        XCTAssertNil(presenter.texture)
        XCTAssertFalse(shell.isSetUp)
        try shell.finishDeactivation()

        XCTAssertEqual(shell.state, .inactive)
        XCTAssertNil(shell.engine.core)
        XCTAssertEqual(host.resources.stats.liveTotal, 0)
        XCTAssertEqual(host.resources.stats.leaked, 0)
        XCTAssertEqual(shell.diagnostics.gpu, GPUResourceCounts(objects: 0, bytes: 0, leaked: 0))
    }

    func testDeactivationAfterAContextRecreationEndsInactiveWithNothingLiveOrLeaked() async throws {
        let (presenter, shell) = try await makeReadySampleShell()
        let host = try makeLaidOutHost(shell.scene)
        try shell.activate()
        XCTAssertTrue(host.renderOneFrame(present: false))
        host.recreateContext()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertTrue(centreShowsState(host, shell))

        try shell.beginDeactivation()
        host.destroy()
        try shell.finishDeactivation()

        XCTAssertEqual(shell.state, .inactive)
        XCTAssertEqual(presenter.setupCalls, 2)
        XCTAssertEqual(presenter.teardownCalls, 2)
        XCTAssertEqual(host.resources.stats.liveTotal, 0)
        XCTAssertEqual(host.resources.stats.leaked, 0)
        XCTAssertEqual(shell.diagnostics.gpu, GPUResourceCounts(objects: 0, bytes: 0, leaked: 0))
    }

    func testDeactivationWithReplaceSceneEndsInactiveWithNothingLiveOrLeaked() async throws {
        let (presenter, shell) = try await makeReadySampleShell()
        let host = try makeLaidOutHost(shell.scene)
        defer { host.destroy() }
        try shell.activate()
        XCTAssertTrue(host.renderOneFrame(present: false))

        try shell.beginDeactivation()
        host.replaceScene(ClearColorScene(red: 1, green: 0, blue: 0))
        XCTAssertEqual(presenter.teardownCalls, 1)
        try shell.finishDeactivation()

        XCTAssertEqual(shell.state, .inactive)
        XCTAssertEqual(host.resources.stats.liveTotal, 0)
        XCTAssertEqual(host.resources.stats.leaked, 0)
        XCTAssertEqual(shell.diagnostics.gpu, GPUResourceCounts(objects: 0, bytes: 0, leaked: 0))
        // The host lives on with the other scene, and nothing reaches the presenter any more.
        let drawn = presenter.drawCalls
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(presenter.drawCalls, drawn)
        XCTAssertGreaterThan(centrePixel(of: host).r, 250)
    }

    func testAPresenterThatKeepsItsTextureEndsInFailedWithGpuLeak() async throws {
        let (presenter, shell) = try await makeReadySampleShell()
        presenter.keepsTextureOnTeardown = true
        let host = try makeLaidOutHost(shell.scene)
        try shell.activate()
        XCTAssertTrue(host.renderOneFrame(present: false))

        try shell.beginDeactivation()
        host.destroy()
        XCTAssertEqual(presenter.teardownCalls, 1)
        let error = refusal { try shell.finishDeactivation() }

        XCTAssertEqual(error?.code, "experience.gpu-leak")
        guard case .gpuLeak(let live, let leaked)? = error else {
            return XCTFail("expected gpuLeak, got \(String(describing: error))")
        }
        XCTAssertGreaterThan(live + leaked, 0)
        XCTAssertEqual(live, host.resources.stats.liveTotal)
        XCTAssertEqual(leaked, host.resources.stats.leaked)
        XCTAssertEqual(shell.state, .failed)
        XCTAssertEqual(shell.diagnostics.lastError?.code, "experience.gpu-leak")
    }

    func testAKeptTextureIsFoundWithReplaceSceneToo() async throws {
        let (presenter, shell) = try await makeReadySampleShell()
        presenter.keepsTextureOnTeardown = true
        let host = try makeLaidOutHost(shell.scene)
        defer { host.destroy() }
        XCTAssertTrue(host.renderOneFrame(present: false))

        try shell.beginDeactivation()
        host.replaceScene(ClearColorScene())
        let error = refusal { try shell.finishDeactivation() }

        XCTAssertEqual(error, .gpuLeak(live: 1, leaked: 0), "the context still lives, so the texture is live")
        XCTAssertEqual(shell.state, .failed)
    }
}
