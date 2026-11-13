// FluidPaletteTests — feature 022 T-A02-402 (FR-A02-401; spec 022 clarification 1).
import FluidArtPlaygroundCore
import Foundation
import XCTest

final class FluidPaletteTests: XCTestCase {
    func testThreePalettesWithSixColorsEach() {
        XCTAssertEqual(FluidPalette.all.map(\.id), ["ink", "smoke", "glow"])
        XCTAssertEqual(FluidPalette.all.map(\.name), ["Ink", "Smoke", "Glowing dye"])
        for p in FluidPalette.all {
            XCTAssertEqual(p.splatColors.count, 6, p.id)
            XCTAssertTrue(p.splatColors.allSatisfy { c in (0...1).contains(c.x) && (0...1).contains(c.y) && (0...1).contains(c.z) })
        }
        XCTAssertEqual(FluidPalette.named("nope").id, "glow")
        XCTAssertTrue(FluidPalette.named("glow").glow)
        XCTAssertFalse(FluidPalette.named("ink").glow || FluidPalette.named("smoke").glow)
    }

    func testInkDarkensPaper() {
        let ink = FluidPalette.named("ink")
        XCTAssertEqual(ink.displayColor(dye: .zero), SIMD3(0.96, 0.94, 0.88), "no dye shows paper")
        let dark = ink.displayColor(dye: SIMD3(0.5, 0.5, 0.5))
        XCTAssertEqual(dark.x, 0.96 * Float(exp(-1.0)), accuracy: 1e-6)
        XCTAssertLessThan(ink.displayColor(dye: SIMD3(1, 1, 1)).x, dark.x, "more ink is darker")
    }

    func testSmokeIsGrayOnDark() {
        let smoke = FluidPalette.named("smoke")
        XCTAssertEqual(smoke.displayColor(dye: .zero), SIMD3(0.04, 0.04, 0.05))
        let c = smoke.displayColor(dye: SIMD3(0.9, 0.2, 0.4))
        XCTAssertEqual(c.x, c.y, accuracy: 1e-6, "no hue")
        XCTAssertGreaterThan(c.x, 0.3)
        XCTAssertTrue(smoke.splatColors.allSatisfy { $0.x == $0.y && $0.y == $0.z }, "gray splats")
    }

    func testGlowIsDyeOnBlack() {
        let glow = FluidPalette.named("glow")
        XCTAssertEqual(glow.displayColor(dye: .zero), .zero)
        XCTAssertEqual(glow.displayColor(dye: SIMD3(2, 0.5, -1)), SIMD3(1, 0.5, 0))
    }
}
