// ContentSwipeBackTests — feature 020 T-A02-213: the content swipe-back is off while the canvas screen is visible
// and restored afterwards.
import SwiftUI
import UIKit
import XCTest
@testable import VisualCoreUI

@MainActor
final class ContentSwipeBackTests: XCTestCase {
    func testDisablesAndRestoresContentPopGesture() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let root = UIViewController()
        let nav = UINavigationController(rootViewController: root)
        window.rootViewController = nav
        window.makeKeyAndVisible()
        let gesture = try XCTUnwrap(nav.interactiveContentPopGestureRecognizer, "iOS 26+ provides the content pop gesture")
        XCTAssertTrue(gesture.isEnabled)

        let canvas = UIHostingController(rootView: Color.black.contentSwipeBackDisabled())
        nav.pushViewController(canvas, animated: false)
        canvas.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        let blocker = try XCTUnwrap(find(ContentSwipeBackBlocker.Controller.self, in: canvas))
        blocker.apply()
        XCTAssertFalse(gesture.isEnabled, "drags on the canvas do not navigate back")

        blocker.restore()
        XCTAssertTrue(gesture.isEnabled, "restored when the screen goes away")
        window.isHidden = true
    }

    func testEnabledFlagKeepsGesture() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let nav = UINavigationController(rootViewController: UIViewController())
        window.rootViewController = nav
        window.makeKeyAndVisible()
        let canvas = UIHostingController(rootView: Color.black.contentSwipeBackDisabled(false))
        nav.pushViewController(canvas, animated: false)
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        try XCTUnwrap(find(ContentSwipeBackBlocker.Controller.self, in: canvas)).apply()
        XCTAssertEqual(nav.interactiveContentPopGestureRecognizer?.isEnabled, true)
        window.isHidden = true
    }

    private func find<T: UIViewController>(_ type: T.Type, in controller: UIViewController) -> T? {
        if let match = controller as? T { return match }
        for child in controller.children { if let match = find(type, in: child) { return match } }
        return nil
    }
}
