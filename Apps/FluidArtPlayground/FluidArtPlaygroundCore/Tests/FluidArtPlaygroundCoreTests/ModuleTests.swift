// ModuleTests — feature 019 T-A02-101: the GPU-free domain package builds and links on the host.
import FluidArtPlaygroundCore
import XCTest

final class ModuleTests: XCTestCase {
    func testVersion() { XCTAssertEqual(FluidArtPlaygroundCoreInfo.version, "0.1.0") }
}
