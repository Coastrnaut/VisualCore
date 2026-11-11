// ResourceRegistryTests — feature 004 T-F312 (US2; SC-F303, SC-F305, FR-F308–FR-F313, FR-F316).
import CVisualCoreGL
import UIKit
import VisualCoreDiagnostics
import XCTest
@testable import VisualCoreRendering

@MainActor
final class ResourceRegistryTests: XCTestCase {
    private func host(_ scene: RenderScene, budget: ResourceBudget = ResourceBudget()) throws -> RenderHost {
        let h = try RenderHost(scene: scene, budget: budget)
        h.view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        h.view.layoutIfNeeded()
        return h
    }

    func testOverBudgetTextureIsRefusedWithoutAllocating() throws {
        var caught: Error?
        let scene = ProbeScene(setup: { ctx in
            do { _ = try ctx.resources.makeTexture(width: 1024, height: 1024, label: "too big") } catch let e { caught = e }
        })
        let h = try host(scene, budget: ResourceBudget(total: 1 << 20))
        guard case .overBudget(.texture, requested: 4 << 20, available: 1 << 20)? = caught as? ResourceBudgetError else {
            return XCTFail("expected overBudget, got \(String(describing: caught))")
        }
        XCTAssertEqual(h.resources.stats.liveCount[.texture], 0)
        XCTAssertEqual(h.resources.stats.totalBytes, 0)
    }

    func testInvalidSizesAreRejectedBeforeTheGPU() throws {
        var errors: [ResourceError] = []
        let scene = ProbeScene(setup: { ctx in
            for (w, h) in [(0, 4), (4, 0), (1 << 20, 4)] {
                do { _ = try ctx.resources.makeTexture(width: w, height: h, label: "bad") }
                catch let e as ResourceError { errors.append(e) }
            }
        })
        let h = try host(scene)
        XCTAssertEqual(errors.count, 3)
        XCTAssertEqual(h.resources.stats.liveCount[.texture], 0)
    }

    func testStaleHandleIsRejectedAfterRecreation() throws {
        var texture: Texture?
        let scene = ProbeScene(setup: { ctx in if texture == nil { texture = try ctx.resources.makeTexture(width: 4, height: 4, label: "t") } })
        let h = try host(scene)
        h.recreateContext()
        texture?.bind(unit: 0)
        XCTAssertEqual(h.resources.stats.staleRejected, 1)
        XCTAssertEqual(h.resources.stats.leaked, 1, "the unreleased texture is counted as leaked at recreation")
    }

    func testHundredRecreationsWithBalancedSceneLeakNothing() throws {
        let scene = AllocatingScene()
        let h = try host(scene)
        for _ in 0..<100 { h.recreateContext() }
        XCTAssertEqual(h.generation, 101)
        XCTAssertEqual(h.resources.stats.liveTotal, 3)
        h.destroy()
        XCTAssertEqual(h.resources.stats.liveTotal, 0)
        XCTAssertEqual(h.resources.stats.totalBytes, 0)
        XCTAssertEqual(h.resources.stats.leaked, 0)
        XCTAssertEqual(scene.setups, 101)
    }

    func testRenderTargetRendersAndReadsBack() throws {
        var pixels: [UInt8] = []
        let scene = ProbeScene(setup: { ctx in
            let target = try ctx.resources.makeRenderTarget(width: 16, height: 8, label: "rt")
            target.bind()
            vcglViewport(0, 0, 16, 8)
            vcglClearColor(0, 0, 1, 1)
            vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
            pixels = target.readPixels()
            ctx.resources.release(target)
        })
        let h = try host(scene)
        XCTAssertEqual(pixels.count, 16 * 8 * 4)
        XCTAssertGreaterThan(Int(pixels[2]), 250)
        XCTAssertEqual(h.resources.stats.liveCount[.framebuffer], 0)
        XCTAssertEqual(h.resources.stats.liveCount[.texture], 0)
        XCTAssertEqual(h.resources.stats.peakBytes, 16 * 8 * 4)
    }

    func testMemoryWarningTrimsPooledTargets() throws {
        let scene = ProbeScene(setup: { ctx in
            let a = try ctx.resources.acquireTarget(width: 8, height: 8)
            let b = try ctx.resources.acquireTarget(width: 8, height: 8)
            ctx.resources.recycle(a)
            ctx.resources.recycle(b)
            let again = try ctx.resources.acquireTarget(width: 8, height: 8)   // reuse, not a new allocation
            ctx.resources.recycle(again)
        })
        let h = try host(scene)
        XCTAssertEqual(h.resources.stats.liveCount[.framebuffer], 2, "two pooled targets")
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        XCTAssertEqual(h.resources.stats.liveCount[.framebuffer], 0)
        XCTAssertEqual(h.resources.stats.totalBytes, 0)
    }

    func testBufferUploadIsAccounted() throws {
        let scene = ProbeScene(setup: { ctx in
            let buffer = try ctx.resources.makeBuffer(bytes: 1024, label: "vbo")
            buffer.upload([Float](repeating: 1, count: 256))
        })
        let h = try host(scene)
        XCTAssertEqual(h.resources.stats.liveBytes[.buffer], 1024)
    }
}

/// Creates three objects in setup and releases them in teardown.
@MainActor
final class AllocatingScene: RenderScene {
    var setups = 0
    private var texture: Texture?, buffer: GPUBuffer?, target: RenderTarget?
    func setup(_ context: RenderContext) throws {
        setups += 1
        texture = try context.resources.makeTexture(width: 4, height: 4, label: "tex")
        buffer = try context.resources.makeBuffer(bytes: 64, label: "buf")
        target = try context.resources.makeRenderTarget(width: 4, height: 4, label: "rt")
    }
    func resize(_ context: RenderContext) {}
    func render(_ context: RenderContext, frame: FrameInfo) throws {}
    func teardown(_ context: RenderContext) {
        texture.map(context.resources.release); buffer.map(context.resources.release); target.map(context.resources.release)
        texture = nil; buffer = nil; target = nil
    }
}
