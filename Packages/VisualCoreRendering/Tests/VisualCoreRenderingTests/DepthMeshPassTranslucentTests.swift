// DepthMeshPassTranslucentTests — feature 126 T-A17-302 (FR-A17-306, SC-A17-303; research D1/D2): the additive
// translucent stage of DepthMeshPass. With no translucent items the pixels equal the existing draw's byte for byte; a
// translucent cube in front of an opaque one blends to the premultiplied mix src + (1 − a)·dst; behind it the opaque
// colour is unchanged; two translucent cubes give the same pixels in either submission order; a resize and a context
// recreation give the same pixels as a fresh pass. Cubes are lit with ambient 1, so every face is the flat colour
// `rgb × a` and the expected mix is exact arithmetic.
import CVisualCoreGL
import VisualCoreMath
import VisualCoreScenes
import XCTest
@testable import VisualCoreRendering

/// What the scene draws in one frame.
private enum TranslucentMode {
    /// The existing `draw(_:view:projection:fog:context:)` with the opaque items only.
    case legacy
    /// The two-list draw with the opaque items and the given translucent items.
    case twoList([DepthMeshPass.Item])
}

/// Unit cubes drawn through one DepthMeshPass with flat (ambient 1) lighting.
@MainActor
private final class TranslucentScene: RenderScene {
    static let camera = OrbitCamera(distance: 4)
    var opaque: @MainActor (TranslucentScene) -> [DepthMeshPass.Item] = { _ in [] }
    var mode: @MainActor (TranslucentScene) -> TranslucentMode = { _ in .legacy }
    private(set) var pass: DepthMeshPass?
    private(set) var renderers: [MeshRenderer] = []

    func setup(_ c: RenderContext) throws {
        pass = DepthMeshPass(registry: c.resources)
        renderers = try (0..<3).map { _ in
            let r = try MeshRenderer(mesh: .cube(), registry: c.resources)
            r.ambient = 1   // colour = rgb × a on every face, independent of the normal
            return r
        }
    }
    func resize(_ c: RenderContext) {}
    func render(_ c: RenderContext, frame: FrameInfo) throws {
        guard let pass, renderers.count == 3 else { return }
        let aspect = Double(c.pixelWidth) / Double(max(c.pixelHeight, 1))
        let view = Self.camera.view(), projection = Self.camera.projection(aspect: aspect)
        switch mode(self) {
        case .legacy:
            try pass.draw(opaque(self), view: view, projection: projection, fog: nil, context: c)
        case .twoList(let translucent):
            try pass.draw(opaque(self), translucent: translucent, camera: Self.camera, context: c)
        }
    }
    func teardown(_ c: RenderContext) {
        pass?.release()
        for r in renderers { r.release() }
        pass = nil
        renderers = []
    }

    /// An item drawing renderer `slot` translated to `position` with straight colour `color`.
    func item(_ slot: Int, at position: Vec3, _ color: Vec4) -> DepthMeshPass.Item {
        DepthMeshPass.Item(renderer: renderers[slot], model: .translation(position), color: color)
    }
}

@MainActor
final class DepthMeshPassTranslucentTests: XCTestCase {
    static let opaqueColor = Vec4(0.2, 0.4, 0.8, 1)
    static let glassColor = Vec4(1, 0.5, 0, 0.5)
    static let otherGlassColor = Vec4(0, 1, 0.5, 0.25)

    private var hosts: [RenderHost] = []

    override func tearDown() {
        for h in hosts { h.destroy() }
        hosts.removeAll()
    }

    private func makeHost(_ scene: TranslucentScene, size: CGFloat = 40) throws -> RenderHost {
        let h = try RenderHost(scene: scene)
        h.view.frame = CGRect(x: 0, y: 0, width: size, height: size)
        h.view.layoutIfNeeded()
        hosts.append(h)
        return h
    }

    /// The window framebuffer (bottom-up RGBA) after one rendered frame.
    private static func frame(_ host: RenderHost) -> [UInt8] {
        XCTAssertTrue(host.renderOneFrame(present: false))
        let pixels = host.readPixels()
        XCTAssertEqual(pixels.count, host.pixelSize.width * host.pixelSize.height * 4)
        XCTAssertEqual(vcglGetError(), GLenum(GL_NO_ERROR))
        return pixels
    }

    /// The centre pixel of a bottom-up RGBA frame of `host`'s size.
    private static func center(_ pixels: [UInt8], _ host: RenderHost) -> SIMD4<Int> {
        let w = host.pixelSize.width, h = host.pixelSize.height
        let i = ((h / 2) * w + w / 2) * 4
        guard pixels.count >= i + 4 else { return SIMD4(-1, -1, -1, -1) }
        return SIMD4(Int(pixels[i]), Int(pixels[i + 1]), Int(pixels[i + 2]), Int(pixels[i + 3]))
    }

    func testNoTranslucentItemsEqualTheExistingDrawBitForBit() throws {
        let scene = TranslucentScene()
        scene.opaque = { s in
            [s.item(0, at: Vec3(-0.3, 0, 1), Vec4(1, 0, 0, 1)), s.item(1, at: Vec3(0.3, 0, -1), Self.opaqueColor)]
        }
        let host = try makeHost(scene)
        scene.mode = { _ in .legacy }
        let legacy = Self.frame(host)
        scene.mode = { _ in .twoList([]) }
        let twoList = Self.frame(host)
        XCTAssertFalse(legacy.isEmpty)
        XCTAssertEqual(legacy, twoList, "translucent: [] is the existing draw, byte for byte")
    }

    func testTranslucentInFrontBlendsPremultiplied() throws {
        let scene = TranslucentScene()
        scene.opaque = { s in [s.item(0, at: Vec3(0, 0, -1), Self.opaqueColor)] }
        let host = try makeHost(scene)
        scene.mode = { _ in .twoList([]) }
        let dst = Self.center(Self.frame(host), host)
        scene.mode = { s in .twoList([s.item(1, at: Vec3(0, 0, 1), Self.glassColor)]) }
        let mixed = Self.center(Self.frame(host), host)
        let a = Self.glassColor.w
        let src = [Self.glassColor.x * a, Self.glassColor.y * a, Self.glassColor.z * a, a]
        for c in 0..<4 {
            let expected = (src[c] + (1 - a) * Double(dst[c]) / 255) * 255
            XCTAssertLessThanOrEqual(abs(Double(mixed[c]) - expected), 1.0,
                                     "channel \(c): \(mixed) vs src + (1 − a)·dst = \(expected) over \(dst)")
        }
        XCTAssertNotEqual(mixed, dst, "the translucent cube changes the pixel")
    }

    func testTranslucentBehindOpaqueLeavesTheOpaquePixel() throws {
        let scene = TranslucentScene()
        scene.opaque = { s in [s.item(0, at: Vec3(0, 0, 1), Self.opaqueColor)] }
        let host = try makeHost(scene)
        scene.mode = { _ in .twoList([]) }
        let alone = Self.center(Self.frame(host), host)
        scene.mode = { s in .twoList([s.item(1, at: Vec3(0, 0, -1), Self.glassColor)]) }
        let behind = Self.center(Self.frame(host), host)
        XCTAssertEqual(behind, alone, "a translucent item behind an opaque one is occluded")
    }

    func testTwoTranslucentItemsGiveTheSamePixelsInEitherOrder() throws {
        let scene = TranslucentScene()
        scene.opaque = { s in [s.item(0, at: Vec3(0, 0, -1.5), Self.opaqueColor)] }
        let host = try makeHost(scene)
        let near: @MainActor (TranslucentScene) -> DepthMeshPass.Item = { s in s.item(1, at: Vec3(0.1, 0, 1), Self.glassColor) }
        let far: @MainActor (TranslucentScene) -> DepthMeshPass.Item = { s in s.item(2, at: Vec3(-0.1, 0, 0), Self.otherGlassColor) }
        scene.mode = { s in .twoList([near(s), far(s)]) }
        let nearFirst = Self.frame(host)
        scene.mode = { s in .twoList([far(s), near(s)]) }
        let farFirst = Self.frame(host)
        XCTAssertFalse(nearFirst.isEmpty)
        XCTAssertEqual(nearFirst, farFirst, "back-to-front sorting makes the result independent of submission order")
    }

    func testBackToFrontSortsFarthestFirstAndKeepsTies() throws {
        let scene = TranslucentScene()
        _ = try makeHost(scene)   // runs setup, which makes the renderers
        XCTAssertEqual(scene.renderers.count, 3)
        let view = TranslucentScene.camera.view()   // eye at (0, 0, 4) looking down −z
        let a = scene.item(0, at: Vec3(0, 0, 1), Self.glassColor)
        let b = scene.item(1, at: Vec3(0, 0, -2), Self.glassColor)
        var c = scene.item(2, at: .zero, Self.glassColor)
        c.center = Vec3(0, 0, -1)   // the model-space sort point moves c between a and b
        let tieFirst = scene.item(0, at: Vec3(1, 0, 1), Self.otherGlassColor)
        let order = DepthMeshPass.backToFront([a, tieFirst, c, b], view: view).map { $0.model.applyPoint($0.center) }
        XCTAssertEqual(order, [Vec3(0, 0, -2), Vec3(0, 0, -1), Vec3(0, 0, 1), Vec3(1, 0, 1)],
                       "farthest first; equal depths keep submission order")
    }

    func testResizeAndRecreationMatchAFreshPass() throws {
        let glass: @MainActor (TranslucentScene) -> TranslucentMode = { s in
            .twoList([s.item(1, at: Vec3(0, 0, 1), Self.glassColor), s.item(2, at: Vec3(0.2, 0, 0), Self.otherGlassColor)])
        }
        let opaque: @MainActor (TranslucentScene) -> [DepthMeshPass.Item] = { s in [s.item(0, at: Vec3(0, 0, -1), Self.opaqueColor)] }
        let scene = TranslucentScene()
        scene.opaque = opaque
        scene.mode = glass
        let host = try makeHost(scene, size: 40)
        _ = Self.frame(host)
        host.view.frame = CGRect(x: 0, y: 0, width: 48, height: 48)
        host.view.layoutIfNeeded()
        let resized = Self.frame(host)

        let freshScene = TranslucentScene()
        freshScene.opaque = opaque
        freshScene.mode = glass
        let fresh = try makeHost(freshScene, size: 48)
        let reference = Self.frame(fresh)
        XCTAssertEqual(host.pixelSize.width, fresh.pixelSize.width)
        XCTAssertEqual(host.pixelSize.height, fresh.pixelSize.height)
        XCTAssertEqual(resized, reference, "after a resize the translucent draw equals a fresh pass")

        host.recreateContext()
        let recreated = Self.frame(host)
        XCTAssertEqual(recreated, reference, "after a context recreation the translucent draw equals a fresh pass")
        XCTAssertEqual(host.resources.stats.leaked, 0)
    }
}
