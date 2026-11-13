// PaletteRenderTests — feature 022 T-A02-403 (FR-A02-401–FR-A02-403; SC-A02-401; US1 AC1–AC4; analyze C4).
import FluidArtPlaygroundCore
import VisualCoreEffects
import VisualCoreRendering
import VisualCoreSimulation
import XCTest
@testable import FluidArtPlaygroundExperience

@MainActor
final class PaletteRenderTests: XCTestCase {
    private static let size = 32

    private func config(_ palette: String) -> FluidConfiguration {
        var c = FluidConfiguration()
        c.gridWidth = Self.size
        c.gridHeight = Self.size
        c.paletteID = palette
        c.seed = 5
        return c
    }

    /// Renders the seeded field (paused, no step) at the grid size so each pixel shows one cell.
    private func render(_ palette: String) throws -> (image: StillImage, dye: FieldGrid) {
        let scene = FluidFieldsScene(configuration: config(palette), seed: .pattern)
        scene.paused = true
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 64, height: 64)
        host.view.layoutIfNeeded()
        defer { host.destroy() }
        XCTAssertTrue(host.renderOneFrame(present: false))
        let image = try host.renderOffscreen(width: Self.size, height: Self.size, time: 0)
        let dye = try XCTUnwrap(scene.readDye())
        XCTAssertEqual(scene.stepCount, 0)
        return (image, dye)
    }

    private func meanDifference(_ a: StillImage, _ b: StillImage) -> Double {
        var sum = 0.0
        for i in 0..<(a.width * a.height) { for c in 0..<3 { sum += abs(Double(a.rgba[i * 4 + c]) - Double(b.rgba[i * 4 + c])) } }
        return sum / Double(a.width * a.height * 3) / 255
    }

    /// SC-A02-401: the palettes differ clearly, and every pixel matches the palette's definition.
    func testPalettesAreDistinctAndMatchTheirDefinition() throws {
        var images: [String: StillImage] = [:]
        for palette in FluidPalette.all {
            let (image, dye) = try render(palette.id)
            images[palette.id] = image
            var worst: Float = 0
            for y in 0..<Self.size {
                for x in 0..<Self.size {
                    let d = SIMD3(dye[x, y, 0], dye[x, y, 1], dye[x, y, 2])
                    let expected = palette.displayColor(dye: d) * 255
                    let p = image.pixel(x: x, y: Self.size - 1 - y)   // StillImage rows are top-down
                    for c in 0..<3 { worst = max(worst, abs(Float(p[c]) - expected[c])) }
                }
            }
            XCTAssertLessThanOrEqual(worst, 3, "\(palette.id): max difference \(worst)/255")
            print("palette \(palette.id): max probe difference \(worst)/255")
        }
        for (a, b) in [("ink", "smoke"), ("ink", "glow"), ("smoke", "glow")] {
            let diff = meanDifference(try XCTUnwrap(images[a]), try XCTUnwrap(images[b]))
            XCTAssertGreaterThanOrEqual(diff, 0.10, "\(a) vs \(b): \(diff)")
            print("palette difference \(a)/\(b): \(diff)")
        }
    }

    /// US1 AC3 / FR-A02-403: the glow spreads light beyond the dye; Reduce Flashing adds the flash limiter.
    func testGlowBloomsAndHonorsReduceFlashing() throws {
        let model = PlaygroundModel(configuration: config("glow"))
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        host.view.frame = CGRect(x: 0, y: 0, width: 64, height: 64)
        host.view.layoutIfNeeded()
        model.scene.paused = true
        XCTAssertFalse(model.effects.bypassEffects)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let glowing = try host.renderOffscreen(width: Self.size, height: Self.size, time: 0)
        model.effects.bypassEffects = true
        let plain = try host.renderOffscreen(width: Self.size, height: Self.size, time: 0)
        let total = { (i: StillImage) in i.rgba.enumerated().reduce(0) { $1.offset % 4 == 3 ? $0 : $0 + Int($1.element) } }
        XCTAssertGreaterThan(total(glowing), total(plain), "bloom adds light")
        model.effects.reduceFlashing = true
        XCTAssertTrue(model.effects.effectiveGraph.passes.contains { $0.id == EffectScene.flashLimitPassID })

        var c = model.configuration
        c.paletteID = "ink"
        model.configuration = c
        XCTAssertTrue(model.effects.bypassEffects, "no glow for Ink")
    }

    /// US1 AC4: switching palettes keeps the fields (no rebuild).
    func testSwitchingKeepsTheFields() throws {
        let model = PlaygroundModel(configuration: config("glow"))
        defer { model.close() }
        let host = try XCTUnwrap(model.host)
        host.view.frame = CGRect(x: 0, y: 0, width: 64, height: 64)
        host.view.layoutIfNeeded()
        model.scene.paused = true
        XCTAssertTrue(host.renderOneFrame(present: false))
        let before = try XCTUnwrap(model.scene.readDye())
        for id in ["ink", "smoke", "glow"] {
            var c = model.configuration
            c.paletteID = id
            model.configuration = c
            XCTAssertTrue(host.renderOneFrame(present: false))
            XCTAssertEqual(model.scene.palette.id, id)
        }
        XCTAssertEqual(try XCTUnwrap(model.scene.readDye()), before)
        XCTAssertEqual(model.scene.setupCount, 1)
    }
}
