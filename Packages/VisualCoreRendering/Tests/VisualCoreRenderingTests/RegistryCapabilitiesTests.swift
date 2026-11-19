// RegistryCapabilitiesTests — feature 175 (A24-P03) T-A24-302 (FR-A24-303, U-RENDERINFO): the registry carries the
// current generation's RenderCapabilities, so a scene callback sees the same report as RenderHost.capabilities.
import VisualCoreDiagnostics
import XCTest
@testable import VisualCoreRendering

/// Records the registry's capabilities as seen inside setup and render.
@MainActor
private final class CapabilitiesProbeScene: RenderScene {
    var seenInSetup: RenderCapabilities?
    var seenInRender: RenderCapabilities?
    func setup(_ context: RenderContext) throws { seenInSetup = context.resources.renderCapabilities }
    func resize(_ context: RenderContext) {}
    func render(_ context: RenderContext, frame: FrameInfo) throws { seenInRender = context.resources.renderCapabilities }
    func teardown(_ context: RenderContext) {}
}

@MainActor
final class RegistryCapabilitiesTests: XCTestCase {
    func testTheRegistryStartsEmptyBeforeAnyContext() {
        XCTAssertEqual(ResourceRegistry(budget: ResourceBudget(), generation: 0).renderCapabilities, RenderCapabilities())
    }

    func testTheRegistrysCopyEqualsTheHostsCapabilitiesAndFollowsRecreation() throws {
        let scene = CapabilitiesProbeScene()
        let host = try RenderHost(scene: scene)
        defer { host.destroy() }
        _ = try host.renderOffscreen(width: 8, height: 8, time: 0)
        XCTAssertEqual(scene.seenInRender, host.capabilities)
        XCTAssertEqual(host.resources.renderCapabilities, host.capabilities)
        XCTAssertFalse(host.capabilities.extensions.isEmpty)
        XCTAssertEqual(scene.seenInRender?.generation, host.generation)

        host.recreateContext()
        _ = try host.renderOffscreen(width: 8, height: 8, time: 0)
        XCTAssertEqual(host.generation, 2)
        XCTAssertEqual(scene.seenInSetup, host.capabilities, "setup of the new generation already sees its report")
        XCTAssertEqual(scene.seenInRender, host.capabilities)
        XCTAssertEqual(scene.seenInRender?.generation, 2)
        XCTAssertEqual(scene.seenInRender?.extensions, host.capabilities.extensions)
    }
}
