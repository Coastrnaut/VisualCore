// AppLinkTests — feature 019 T-A02-101: the unit-test bundle hosts the app and links its domain package.
import FluidArtPlaygroundCore
import XCTest

final class AppLinkTests: XCTestCase {
    func testDomainPackageLinks() { XCTAssertEqual(FluidArtPlaygroundCoreInfo.version, "0.1.0") }
}
