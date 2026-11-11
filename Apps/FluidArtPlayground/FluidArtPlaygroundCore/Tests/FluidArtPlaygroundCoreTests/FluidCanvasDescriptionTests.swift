// FluidCanvasDescriptionTests — feature 019 T-A02-109 (FR-A02-106: spoken canvas description).
import FluidArtPlaygroundCore
import XCTest

final class FluidCanvasDescriptionTests: XCTestCase {
    func testDescriptions() {
        let c = FluidConfiguration()
        XCTAssertEqual(FluidCanvasDescription.text(configuration: c, storage: .float16, paused: false),
                       "Dye pattern slowly fading, 128 by 128 grid, half-float storage, glowing dye palette")
        XCTAssertEqual(FluidCanvasDescription.text(configuration: c, storage: .unorm8, paused: true),
                       "Dye pattern paused, 128 by 128 grid, 8-bit storage, glowing dye palette")
        var still = c
        still.dyeDissipation = 0
        XCTAssertEqual(FluidCanvasDescription.text(configuration: still, storage: .float32, paused: false),
                       "Dye pattern holding steady, 128 by 128 grid, 32-bit float storage, glowing dye palette")
        var fast = c
        fast.dyeDissipation = 6
        XCTAssertTrue(FluidCanvasDescription.text(configuration: fast, storage: .float16, paused: false).hasPrefix("Dye pattern quickly fading"))
        XCTAssertTrue(FluidCanvasDescription.text(configuration: c, storage: .float16, paused: false, splashes: 1).hasSuffix(", 1 splash added"))
        XCTAssertTrue(FluidCanvasDescription.text(configuration: c, storage: .float16, paused: false, splashes: 3).hasSuffix(", 3 splashes added"))
    
        var ink = c
        ink.paletteID = "ink"
        XCTAssertTrue(FluidCanvasDescription.text(configuration: ink, storage: .float16, paused: false).hasSuffix(", ink palette"))
    }
}
