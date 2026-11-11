// FluidCanvasDescriptionTests — feature 019 T-A02-109 (FR-A02-106: spoken canvas description).
import FluidArtPlaygroundCore
import XCTest

final class FluidCanvasDescriptionTests: XCTestCase {
    func testDescriptions() {
        let c = FluidConfiguration()
        XCTAssertEqual(FluidCanvasDescription.text(configuration: c, storage: .float16, paused: false),
                       "Dye pattern slowly fading, 128 by 128 grid, half-float storage")
        XCTAssertEqual(FluidCanvasDescription.text(configuration: c, storage: .unorm8, paused: true),
                       "Dye pattern paused, 128 by 128 grid, 8-bit storage")
        var still = c
        still.dyeDissipation = 0
        XCTAssertEqual(FluidCanvasDescription.text(configuration: still, storage: .float32, paused: false),
                       "Dye pattern holding steady, 128 by 128 grid, 32-bit float storage")
        var fast = c
        fast.dyeDissipation = 6
        XCTAssertTrue(FluidCanvasDescription.text(configuration: fast, storage: .float16, paused: false).hasPrefix("Dye pattern quickly fading"))
    }
}
