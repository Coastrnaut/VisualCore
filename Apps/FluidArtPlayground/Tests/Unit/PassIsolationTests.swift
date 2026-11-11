// PassIsolationTests — feature 022 T-A02-406 (FR-A02-407; SC-A02-404; US4; manual Phase 04 regression fixture
// "every ping-pong pass writes to a different target from its sampled input").
import FluidArtPlaygroundCore
import VisualCoreRendering
import XCTest
@testable import FluidArtPlayground

@MainActor
final class PassIsolationTests: XCTestCase {
    override func tearDown() {
        MainActor.assumeIsolated { FieldPass.runObserver = nil }
        super.tearDown()
    }

    func testNoPassSamplesItsOutputOverWholeFrames() throws {
        var total = 0
        for palette in FluidPalette.all {
            for fallback in [false, true] {
                var c = FluidConfiguration()
                c.gridWidth = 16
                c.gridHeight = 16
                c.paletteID = palette.id
                c.viscosity = 0.3
                let scene = FluidFieldsScene(configuration: c, seed: .pattern, forceFallback: fallback)
                scene.fixedDelta = 1.0 / 60
                let host = try RenderHost(scene: scene)
                host.view.frame = CGRect(x: 0, y: 0, width: 64, height: 64)
                host.view.layoutIfNeeded()
                defer { host.destroy() }
                XCTAssertTrue(host.renderOneFrame(present: false))   // setup frame
                var runs: [FieldPass.Run] = []
                FieldPass.runObserver = { runs.append($0) }
                let splatsPerFrame = 2
                let expected = 2 * splatsPerFrame + 2 + (1 + FluidSolver.viscosityIterations) + 1 + 1
                    + scene.activePressureIterations + 1 + 1
                for frame in 0..<10 {
                    runs.removeAll()
                    scene.enqueue([
                        try XCTUnwrap(Splat(position: SIMD2(0.3, 0.4), radius: 0.1, force: SIMD2(200, 50), color: .one)),
                        try XCTUnwrap(Splat(position: SIMD2(0.7, 0.6), radius: 0.1, force: SIMD2(-150, 80), color: .one)),
                    ])
                    XCTAssertTrue(host.renderOneFrame(present: false))
                    XCTAssertNil(scene.lastError)
                    XCTAssertEqual(runs.count, expected, "\(palette.id) frame \(frame): pass list")
                    let violations = runs.filter { !$0.outputIsFramebuffer && $0.inputs.values.contains($0.output) }
                    XCTAssertEqual(violations.count, 0, "\(palette.id) frame \(frame): \(violations)")
                    total += runs.count
                }
                FieldPass.runObserver = nil
            }
        }
        print("pass isolation: \(total) field-pass runs over 60 frames, 0 sampled their own output")
    }
}
