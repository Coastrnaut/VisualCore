// RenderSurfaceTests — feature 012 T-A01-105: the surface embeds the caller's host view, fills its space, exposes one
// accessible canvas element and does not own the host.
import SwiftUI
import UIKit
import XCTest
import VisualCoreRendering
@testable import VisualCoreUI

@MainActor
final class RenderSurfaceTests: XCTestCase {
    func testEmbedsHostViewWithAccessibility() throws {
        let host = try RenderHost(scene: ClearColorScene(red: 0, green: 0.5, blue: 1))
        let controller = UIHostingController(rootView: RenderSurface(host: host, accessibilityLabel: "Blue canvas", accessibilityHint: "Drag to move")
            .frame(width: 120, height: 80))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        let container = try XCTUnwrap(host.view.superview as? RenderSurfaceContainer)
        XCTAssertTrue(container.isAccessibilityElement)
        XCTAssertEqual(container.accessibilityLabel, "Blue canvas")
        XCTAssertEqual(container.accessibilityHint, "Drag to move")
        XCTAssertEqual(host.view.bounds.size, container.bounds.size)
        XCTAssertEqual(container.bounds.size, CGSize(width: 120, height: 80))
        XCTAssertTrue(host.renderOneFrame(present: false))
        window.isHidden = true
        host.destroy()
        XCTAssertEqual(host.resources.stats.leaked, 0)
    }
}
