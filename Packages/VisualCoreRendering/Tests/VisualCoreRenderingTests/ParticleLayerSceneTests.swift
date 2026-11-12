// ParticleLayerSceneTests — feature 034 A04-P02 T-A04-212 (FR-A04-206; SC-A04-205; US4 AC1, AC2; contract C8).
// Simulator pixel tests: three fixed simulation states rendered offscreen; every projected particle center is lit
// with the particle's dominant channel and every sampled pixel more than 3 radii from all particles is background.
import VisualCoreMath
import VisualCoreSimulation
import XCTest
@testable import VisualCoreRendering

@MainActor
final class ParticleLayerSceneTests: XCTestCase {
    private let world = ParticleLayerScene.WorldRect.square(halfExtent: 100)   // 200 × 200 world units
    private let diameter = 6.0

    /// A fixed state: `count` particles from `emitter` stepped `steps` times under `forces`, all one color.
    private func state(_ emitter: Emitter, forces: [ParticleForce], burst: Int, steps: Int, seed: UInt64) -> [ParticleInstance] {
        var ps = ParticleSystem(capacity: 1_000, seed: seed)
        var e = emitter
        e.rate = 0; e.lifetime = 100...100; e.startSize = diameter; e.endSize = diameter; e.endColor = e.startColor
        ps.emitters = [e]
        ps.forces = forces
        ps.burst(burst)
        for _ in 0..<steps { ps.step(1.0 / 120) }
        return ps.instances()
    }

    private var states: [(name: String, particles: [ParticleInstance], channel: Int)] {
        [("center burst", state(Emitter(position: .zero, speed: 0...150, startColor: Vec4(1, 0, 0, 1)), forces: [], burst: 120, steps: 60, seed: 1), 0),
         ("attractor", state(Emitter(position: Vec2(60, 0), speed: 0...60, startColor: Vec4(0, 1, 0, 1)),
                             forces: [.attractor(point: .zero, strength: 300, radius: 300)], burst: 80, steps: 90, seed: 2), 1),
         ("vortex", state(Emitter(position: Vec2(40, 0), speed: 0...20, startColor: Vec4(0, 0, 1, 1)),
                          forces: [.vortex(point: .zero, strength: 250, radius: 300)], burst: 80, steps: 120, seed: 3), 2)]
    }

    private func makeHost(_ scene: ParticleLayerScene) throws -> RenderHost {
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        host.view.layoutIfNeeded()
        XCTAssertTrue(host.renderOneFrame(present: false))
        return host
    }

    private func check(_ image: StillImage, _ particles: [ParticleInstance], channel: Int, name: String) {
        let size = Vec2(Double(image.width), Double(image.height))
        let centers = particles.compactMap { ParticleLayerScene.viewPoint($0.position, viewSize: size, world: world) }
        XCTAssertEqual(centers.count, particles.count)
        let k = min(size.x / world.size.x, size.y / world.size.y), radiusPx = diameter / 2 * k
        var lit = 0, inside = 0
        for c in centers where c.x >= 0 && c.y >= 0 && c.x < size.x && c.y < size.y {
            inside += 1
            let p = image.pixel(x: Int(c.x), y: Int(c.y))
            let rgb = [p.x, p.y, p.z]
            if rgb[channel] >= 128 && rgb[channel] == rgb.max() { lit += 1 }
        }
        XCTAssertGreaterThan(inside, particles.count / 2, "\(name): most particles on screen")
        XCTAssertEqual(lit, inside, "\(name): 100% of on-screen particle centers lit")
        var background = 0, far = 0
        for y in stride(from: 0, to: image.height, by: 5) {
            for x in stride(from: 0, to: image.width, by: 5) {
                let q = Vec2(Double(x) + 0.5, Double(y) + 0.5)
                guard centers.allSatisfy({ $0.distance(to: q) > 3 * radiusPx }) else { continue }
                far += 1
                let p = image.pixel(x: x, y: y)
                if p.x == 0 && p.y == 0 && p.z == 0 { background += 1 }
            }
        }
        XCTAssertGreaterThan(far, 100, "\(name): enough far-away samples")
        XCTAssertEqual(background, far, "\(name): 100% of far-away samples are background")
    }

    func testThreeFixedStatesRenderAtTheirCenters() throws {
        // SC-A04-205.
        for s in states {
            let particles = s.particles
            let scene = ParticleLayerScene(world: world) { _ in particles }
            let host = try makeHost(scene)
            defer { host.destroy() }
            let image = try host.renderOffscreen(width: 200, height: 200, time: 0)
            XCTAssertEqual(scene.lastInstanceCount, particles.count, s.name)
            check(image, particles, channel: s.channel, name: s.name)
        }
    }

    func testAspectFitOnANonSquareTarget() throws {
        let particles = [ParticleInstance(position: Vec2(90, 90), size: 10, color: Vec4(1, 1, 1, 1)),
                         ParticleInstance(position: Vec2(-90, -90), size: 10, color: Vec4(1, 1, 1, 1))]
        let scene = ParticleLayerScene(world: world) { _ in particles }
        let host = try makeHost(scene)
        defer { host.destroy() }
        let image = try host.renderOffscreen(width: 300, height: 150, time: 0)
        // k = 0.75; the world square spans x 75…225 and the full height; (90, 90) is at (217.5, 7.5).
        XCTAssertEqual(image.pixel(x: 217, y: 7).x, 255)
        XCTAssertEqual(image.pixel(x: 82, y: 142).x, 255)
        XCTAssertEqual(image.pixel(x: 30, y: 75).x, 0, "outside the fitted world: background")
    }

    func testRecreationRedrawsTheSameStateAndSourceSeesFrames() throws {
        // US4 AC2: GPU objects are rebuilt from CPU state after a context recreation.
        let particles = states[1].particles
        var frames: [Double] = []
        let scene = ParticleLayerScene(world: world, background: Vec4(0, 0, 0, 1)) { frame in frames.append(frame.time); return particles }
        let host = try makeHost(scene)
        defer { host.destroy() }
        let before = try host.renderOffscreen(width: 128, height: 128, time: 1.5)
        host.recreateContext()
        XCTAssertTrue(host.renderOneFrame(present: false))
        let after = try host.renderOffscreen(width: 128, height: 128, time: 1.5)
        XCTAssertEqual(before, after)
        XCTAssertTrue(frames.contains(1.5))
        XCTAssertNil(scene.lastError)
    }

    func testFitHelpersRoundTrip() {
        let w = ParticleLayerScene.WorldRect(center: Vec2(10, -20), size: Vec2(400, 200))
        let view = Vec2(390, 844)
        for p in [Vec2(10, -20), Vec2(-190, 80), Vec2(210, -120), Vec2(3.25, 7.5)] {
            let v = ParticleLayerScene.viewPoint(p, viewSize: view, world: w)!
            let back = ParticleLayerScene.worldPoint(v, viewSize: view, world: w)!
            XCTAssertEqual(back.x, p.x, accuracy: 1e-9); XCTAssertEqual(back.y, p.y, accuracy: 1e-9)
        }
        XCTAssertEqual(ParticleLayerScene.viewPoint(Vec2(10, -20), viewSize: view, world: w), Vec2(195, 422), "center maps to the view center")
        let top = ParticleLayerScene.viewPoint(Vec2(10, 80), viewSize: view, world: w)!
        XCTAssertLessThan(top.y, 422, "y up in the world is up on screen")
        XCTAssertNil(ParticleLayerScene.fit(world: .init(center: .zero, size: Vec2(0, 1)), viewSize: view))
        XCTAssertNil(ParticleLayerScene.worldPoint(Vec2(.nan, 0), viewSize: view, world: w))
        let tiny = ParticleLayerScene.fit(world: .square(halfExtent: 500), viewSize: Vec2(40, 40))!
        XCTAssertEqual(tiny.camera.zoom, 1, "small views fit through the metrics, not the clamped camera zoom")
    }
}

/// Feature 035 T-A04-305 (FR-A04-302, FR-A04-303; contract C7): trails, the cap and the layer's lifetime in the scene.
@MainActor
final class ParticleLayerSceneTrailTests: XCTestCase {
    private var host: RenderHost?
    override func tearDown() { host?.destroy(); host = nil }

    private func makeHost(_ scene: ParticleLayerScene) throws -> RenderHost {
        let h = try RenderHost(scene: scene)
        h.view.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        h.view.layoutIfNeeded()
        host = h
        return h
    }

    /// The red channel at the view center after the last frame.
    private func centerRed(_ h: RenderHost) -> Int {
        let w = h.pixelSize.width, ht = h.pixelSize.height
        return Int(h.readPixels()[((ht / 2) * w + w / 2) * 4])
    }

    func testAParticleLeavesAFadingStreakAndTurningTrailsOffReleasesTheLayer() throws {
        var show = true
        let world = ParticleLayerScene.WorldRect.square(halfExtent: 16)
        let scene = ParticleLayerScene(world: world) { _ in
            show ? [ParticleInstance(position: .zero, size: 12, color: Vec4(1, 0, 0, 1))] : []
        }
        scene.trailStrength = 0.95
        let h = try makeHost(scene)
        let before = h.resources.stats.liveCount[.framebuffer] ?? 0
        XCTAssertTrue(h.renderOneFrame(present: false))
        XCTAssertNotNil(scene.trailLayer)
        XCTAssertEqual(h.resources.stats.liveCount[.framebuffer] ?? 0, before + 2)
        XCTAssertGreaterThan(centerRed(h), 200, "the particle is drawn through the layer")
        show = false
        XCTAssertTrue(h.renderOneFrame(present: false))
        let streak = centerRed(h)
        XCTAssertGreaterThan(streak, 0, "a fading streak remains without the particle")
        XCTAssertLessThan(streak, 256)
        scene.clearTrails()
        XCTAssertTrue(h.renderOneFrame(present: false))
        XCTAssertEqual(centerRed(h), 0, "cleared")
        scene.trailStrength = 0
        XCTAssertTrue(h.renderOneFrame(present: false))
        XCTAssertNil(scene.trailLayer, "no trails and no cap: the layer is released")
        XCTAssertEqual(h.resources.stats.liveCount[.framebuffer] ?? 0, before)
    }

    func testCapRoutesThroughTheLayerAndAdditiveIsBounded() throws {
        let world = ParticleLayerScene.WorldRect.square(halfExtent: 16)
        let scene = ParticleLayerScene(world: world) { _ in
            Array(repeating: ParticleInstance(position: .zero, size: 12, color: Vec4(1, 1, 1, 1)), count: 3)
        }
        scene.blend = .additive
        scene.brightnessCap = 0.6
        let h = try makeHost(scene)
        XCTAssertTrue(h.renderOneFrame(present: false))
        XCTAssertTrue(scene.usesTrailLayer)
        XCTAssertNotNil(scene.trailLayer, "the cap needs the layer even without trails")
        XCTAssertLessThanOrEqual(centerRed(h), 153)
        XCTAssertGreaterThanOrEqual(centerRed(h), 152)
    }

    func testZeroSizeDrawableReleasesTheLayerWithoutError() throws {
        // Drives an unhosted scene by hand inside one context: a normal frame creates the layer, a zero-size frame
        // releases it without error (analyze E2).
        let scene = ParticleLayerScene(world: .square(halfExtent: 16)) { _ in [] }
        scene.trailStrength = 0.9
        var createdThenReleased: (Bool, Bool)?
        var renderError: Error?
        let probe = ProbeScene(setup: { ctx in
            do {
                let target = try ctx.resources.makeRenderTarget(width: 16, height: 16, label: "zero-size probe")
                defer { ctx.resources.release(target) }
                let frame = FrameInfo(index: 0, time: 0, delta: 1.0 / 60, targetTimestamp: 0)
                try scene.setup(ctx)
                try scene.render(ctx.redirected(to: target.handle.name, width: 16, height: 16), frame: frame)
                let created = scene.trailLayer != nil
                try scene.render(ctx.redirected(to: target.handle.name, width: 0, height: 0), frame: frame)
                createdThenReleased = (created, scene.trailLayer == nil)
                scene.teardown(ctx)
            } catch { renderError = error }
        })
        let h = try RenderHost(scene: probe)
        host = h
        XCTAssertNil(renderError)
        XCTAssertEqual(createdThenReleased?.0, true, "a 16 × 16 frame creates the layer")
        XCTAssertEqual(createdThenReleased?.1, true, "a zero-size frame releases it")
    }

    func testNoTrailsKeepsTheDirectPath() throws {
        let scene = ParticleLayerScene(world: .square(halfExtent: 16)) { _ in [ParticleInstance(position: .zero, size: 12, color: Vec4(0, 1, 0, 1))] }
        let h = try makeHost(scene)
        XCTAssertTrue(h.renderOneFrame(present: false))
        XCTAssertFalse(scene.usesTrailLayer)
        XCTAssertNil(scene.trailLayer)
        let w = h.pixelSize.width, ht = h.pixelSize.height
        XCTAssertGreaterThan(Int(h.readPixels()[((ht / 2) * w + w / 2) * 4 + 1]), 200)
    }
}
