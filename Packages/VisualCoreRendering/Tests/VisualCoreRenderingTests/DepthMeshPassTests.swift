// DepthMeshPassTests — feature 042 T-A05-303 (FR-A05-320, SC-A05-301–303; research D1/D2/D6): a red cube near the
// camera and a green cube farther away overlap on screen; the nearer red wins at every overlap probe in both draw
// orders, on screen and through `renderOffscreen`, after a context recreation, and at another export size.
import CVisualCoreGL
import VisualCoreMath
import VisualCoreScenes
import XCTest
@testable import VisualCoreRendering

/// Two cubes drawn through one DepthMeshPass; `nearFirst` picks the draw order, `empty` draws no items.
@MainActor
private final class TwoCubeScene: RenderScene {
    var nearFirst = true
    var empty = false
    var clearColor = Vec4(0, 0, 0, 1)
    private(set) var pass: DepthMeshPass?
    private var red: MeshRenderer?
    private var green: MeshRenderer?
    static let camera = OrbitCamera(distance: 4)

    func setup(_ c: RenderContext) throws {
        pass = DepthMeshPass(registry: c.resources)
        for slot in 0..<2 {
            let r = try MeshRenderer(mesh: .cube(), registry: c.resources)
            r.lightDirection = Vec3(0, 0, 1)   // toward the camera: front faces fully lit
            r.ambient = 0.6                    // side faces stay clearly coloured
            if slot == 0 { red = r } else { green = r }
        }
    }
    func resize(_ c: RenderContext) {}
    func render(_ c: RenderContext, frame: FrameInfo) throws {
        guard let pass, let red, let green else { return }
        pass.clearColor = clearColor
        let near = DepthMeshPass.Item(renderer: red, model: .translation(Vec3(-0.3, 0, 1)), color: Vec4(1, 0, 0, 1))
        let far = DepthMeshPass.Item(renderer: green, model: .translation(Vec3(0.3, 0, -1)), color: Vec4(0, 1, 0, 1))
        try pass.draw(empty ? [] : (nearFirst ? [near, far] : [far, near]), camera: Self.camera, context: c)
    }
    func teardown(_ c: RenderContext) {
        pass?.release(); red?.release(); green?.release()
        pass = nil; red = nil; green = nil
    }
}

@MainActor
final class DepthMeshPassTests: XCTestCase {
    /// Overlap probes in normalised device coordinates (inside both cubes' projections at aspect 1).
    static let overlap: [(Double, Double)] = [(-0.04, -0.1), (-0.04, 0.1), (0, 0), (0.05, -0.05), (0.05, 0.1), (0.1, 0)]
    /// A point covered by the green cube only.
    static let greenOnly = (0.25, 0.0)

    private var hosts: [RenderHost] = []

    override func tearDown() {
        for h in hosts { h.destroy() }
        hosts.removeAll()
    }

    private func makeHost(_ scene: TwoCubeScene) throws -> RenderHost {
        let h = try RenderHost(scene: scene)
        h.view.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        h.view.layoutIfNeeded()
        hosts.append(h)
        return h
    }

    /// Top-down pixel coordinates of an NDC point in a `w`×`h` image.
    private static func pixel(_ ndc: (Double, Double), _ w: Int, _ h: Int) -> (x: Int, y: Int) {
        let x = min(w - 1, Int((ndc.0 + 1) / 2 * Double(w)))
        let yUp = min(h - 1, Int((ndc.1 + 1) / 2 * Double(h)))
        return (x, h - 1 - yUp)
    }

    /// The screen as a top-down image after one rendered frame.
    private static func screen(_ host: RenderHost) throws -> StillImage {
        XCTAssertTrue(host.renderOneFrame(present: false))
        let w = host.pixelSize.width, h = host.pixelSize.height
        return try XCTUnwrap(StillImage(width: w, height: h, bottomUpRGBA: host.readPixels()))
    }

    /// Verdict of research D6: red wins when its channel is the larger one and above 0.25.
    private static func redWins(_ p: SIMD4<UInt8>) -> Bool { p.x > p.y && Double(p.x) / 255 > 0.25 }
    private static func greenWins(_ p: SIMD4<UInt8>) -> Bool { p.y > p.x && Double(p.y) / 255 > 0.25 }

    private func assertRedWins(_ image: StillImage, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        var wins = 0
        for probe in Self.overlap {
            let (x, y) = Self.pixel(probe, image.width, image.height)
            let p = image.pixel(x: x, y: y)
            if Self.redWins(p) { wins += 1 } else { XCTFail("\(label): probe \(probe) = \(p), nearer red should win", file: file, line: line) }
        }
        XCTAssertGreaterThanOrEqual(wins, 5, label, file: file, line: line)
        let (gx, gy) = Self.pixel(Self.greenOnly, image.width, image.height)
        XCTAssertTrue(Self.greenWins(image.pixel(x: gx, y: gy)), "\(label): the farther green cube is drawn", file: file, line: line)
    }

    func testNearerMeshWinsInBothOrdersOnScreen() throws {
        let scene = TwoCubeScene()
        let host = try makeHost(scene)
        XCTAssertEqual(host.pixelSize.width, host.pixelSize.height, "square view: probes assume aspect 1")
        for nearFirst in [true, false] {
            scene.nearFirst = nearFirst
            assertRedWins(try Self.screen(host), nearFirst ? "near then far" : "far then near")
        }
        XCTAssertEqual(vcglGetError(), GLenum(GL_NO_ERROR))
    }

    func testOffscreenEqualsScreenAtTheViewSize() throws {
        let scene = TwoCubeScene()
        let host = try makeHost(scene)
        for nearFirst in [true, false] {
            scene.nearFirst = nearFirst
            let onScreen = try Self.screen(host)
            let offscreen = try host.renderOffscreen(width: onScreen.width, height: onScreen.height, time: 0)
            assertRedWins(offscreen, "offscreen, near first \(nearFirst)")
            for probe in Self.overlap + [Self.greenOnly, (0.9, 0.9)] {
                let (x, y) = Self.pixel(probe, onScreen.width, onScreen.height)
                let a = onScreen.pixel(x: x, y: y), b = offscreen.pixel(x: x, y: y)
                for c in 0..<4 {
                    XCTAssertLessThanOrEqual(abs(Int(a[c]) - Int(b[c])), 2, "probe \(probe) channel \(c): \(a) vs \(b)")
                }
            }
        }
    }

    func testOffscreenAtAnotherSizeShowsTheNearerMesh() throws {
        let scene = TwoCubeScene()
        let host = try makeHost(scene)
        for nearFirst in [true, false] {
            scene.nearFirst = nearFirst
            let image = try host.renderOffscreen(width: 64, height: 48, time: 0)
            let (x, y) = Self.pixel((0, 0), 64, 48)
            XCTAssertTrue(Self.redWins(image.pixel(x: x, y: y)), "64×48, near first \(nearFirst): \(image.pixel(x: x, y: y))")
        }
        assertRedWins(try Self.screen(host), "screen after the export")
    }

    func testRecreatedContextMatchesAndKeepsLedgerCounts() throws {
        let scene = TwoCubeScene()
        let host = try makeHost(scene)
        let before = try Self.screen(host)
        let counts = host.resources.stats.liveCount
        host.recreateContext()
        let after = try Self.screen(host)
        XCTAssertEqual(after.width, before.width)
        assertRedWins(after, "after recreation")
        for probe in Self.overlap + [Self.greenOnly] {
            let (x, y) = Self.pixel(probe, before.width, before.height)
            let a = before.pixel(x: x, y: y), b = after.pixel(x: x, y: y)
            for c in 0..<4 { XCTAssertLessThanOrEqual(abs(Int(a[c]) - Int(b[c])), 2, "probe \(probe): \(a) vs \(b)") }
        }
        XCTAssertEqual(host.resources.stats.liveCount, counts, "same live resources after recreation")
        XCTAssertEqual(host.resources.stats.leaked, 0)
    }

    func testEmptyItemsClearToTheClearColour() throws {
        let scene = TwoCubeScene()
        scene.empty = true
        scene.clearColor = Vec4(0, 0, 1, 1)
        let host = try makeHost(scene)
        let image = try Self.screen(host)
        for probe in Self.overlap + [Self.greenOnly] {
            let (x, y) = Self.pixel(probe, image.width, image.height)
            XCTAssertEqual(image.pixel(x: x, y: y), SIMD4(0, 0, 255, 255), "probe \(probe)")
        }
    }

    func testZeroSizeContextDrawsNothing() throws {
        var thrown: Error?
        var targetsBefore = -1, targetsAfter = -2
        let scene = ProbeScene(setup: { ctx in
            let pass = DepthMeshPass(registry: ctx.resources)
            let r = try MeshRenderer(mesh: .cube(), registry: ctx.resources)
            targetsBefore = ctx.resources.stats.liveCount[.framebuffer] ?? 0
            do {
                try pass.draw([.init(renderer: r, color: Vec4(1, 0, 0, 1))], camera: OrbitCamera(distance: 4),
                              context: ctx.redirected(to: ctx.framebuffer, width: 0, height: 0))
            } catch { thrown = error }
            targetsAfter = ctx.resources.stats.liveCount[.framebuffer] ?? 0
            pass.release()
            r.release()
        })
        let h = try RenderHost(scene: scene)
        h.view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        h.view.layoutIfNeeded()
        hosts.append(h)
        XCTAssertNil(thrown)
        XCTAssertEqual(targetsAfter, targetsBefore, "no target is allocated for a zero-sized context")
    }
}
