// FloatRenderSupportTests — feature 019 T-A02-103 (G-FLOATRT; spec clarification 4; research R3).
import CVisualCoreGL
import XCTest
@testable import VisualCoreRendering

@MainActor
final class FloatRenderSupportTests: XCTestCase {
    func testDetectAgreesWithIndependentProbeAndLeavesLedgerUnchanged() throws {
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        try withContext(host, scene) { context in
            let before = context.resources.stats
            let support = FloatRenderSupport.detect(in: context.resources)
            let after = context.resources.stats
            XCTAssertEqual(before.liveCount, after.liveCount, "the probe target is released")
            XCTAssertEqual(support.extensionReported, host.capabilities.reportsColorBufferHalfFloat)
            XCTAssertEqual(context.resources.maxTextureSize, host.capabilities.maxTextureSize, "scenes can size grids within it")
            XCTAssertGreaterThan(context.resources.maxTextureSize, 0)
            // Independent probe: a raw RGBA16F framebuffer.
            var tex: GLuint = 0, fbo: GLuint = 0
            vcglGenTextures(1, &tex)
            vcglBindTexture(GLenum(GL_TEXTURE_2D), tex)
            vcglTexImage2D(GLenum(GL_TEXTURE_2D), 0, GLint(GL_RGBA16F), 4, 4, 0, GLenum(GL_RGBA), GLenum(GL_HALF_FLOAT), nil)
            vcglGenFramebuffers(1, &fbo)
            vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), fbo)
            vcglFramebufferTexture2D(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_TEXTURE_2D), tex, 0)
            let complete = vcglCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER)) == GLenum(GL_FRAMEBUFFER_COMPLETE)
            vcglBindFramebuffer(GLenum(GL_FRAMEBUFFER), context.framebuffer)
            vcglDeleteFramebuffers(1, &fbo)
            vcglDeleteTextures(1, &tex)
            XCTAssertEqual(support.probeComplete, complete && support.probeComplete, "probe never claims more than GL")
            if support.extensionReported { XCTAssertEqual(support.probeComplete, complete) }
            XCTAssertEqual(support.supported, support.extensionReported && support.probeComplete)
            print("FloatRenderSupport: extension=\(support.extensionReported) probe=\(support.probeComplete) raw=\(complete)")
            XCTAssertEqual(FloatRenderSupport.detect(in: context.resources), support, "cached per generation")
        }
    }

    func testStorageSelectionAndForcedFallback() {
        let yes = FloatRenderSupport(extensionReported: true, probeComplete: true)
        XCTAssertEqual(yes.storageFormat(), .rgba16f)
        XCTAssertEqual(yes.storageFormat(forceFallback: true), .rgba8)
        XCTAssertEqual(FloatRenderSupport(extensionReported: true, probeComplete: false).storageFormat(), .rgba8)
        XCTAssertEqual(FloatRenderSupport(extensionReported: false, probeComplete: true).storageFormat(), .rgba8)
    }

    func testCapabilitiesExtensionCheck() {
        var caps = RenderCapabilities()
        XCTAssertFalse(caps.reportsColorBufferHalfFloat)
        caps.extensions = ["GL_EXT_color_buffer_float"]
        XCTAssertTrue(caps.reportsColorBufferHalfFloat)
        caps.extensions = ["GL_EXT_color_buffer_half_float"]
        XCTAssertTrue(caps.reportsColorBufferHalfFloat)
    }

    func testDetectionIsRedoneAfterContextRecreation() throws {
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        var first: FloatRenderSupport?
        try withContext(host, scene) { first = FloatRenderSupport.detect(in: $0.resources) }
        host.recreateContext()
        try withContext(host, scene) { context in
            XCTAssertEqual(FloatRenderSupport.detect(in: context.resources), first)
            XCTAssertEqual(context.resources.stats.staleRejected, 0)
        }
    }
}
