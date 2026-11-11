// SystemAccessibilityObserverTests — feature 016 T-A01-502 (FR-A01-506; research R8).
import UIKit
import VisualCoreSimulation
import XCTest
@testable import VisualCoreUI

@MainActor
final class SystemAccessibilityObserverTests: XCTestCase {
    func testInjectedSourceAndRefresh() {
        var value = SystemAccessibility(reduceMotion: false, dimFlashingLights: false)
        let observer = SystemAccessibilityObserver(source: { value })
        XCTAssertEqual(observer.current, value)
        value = SystemAccessibility(reduceMotion: true, dimFlashingLights: true)
        XCTAssertNotEqual(observer.current, value, "no change until refreshed")
        observer.refresh()
        XCTAssertEqual(observer.current, value)
    }

    func testChangeNotificationsRefresh() {
        for name in SystemAccessibilityObserver.changeNotifications {
            var value = SystemAccessibility()
            let observer = SystemAccessibilityObserver(source: { value })
            value = SystemAccessibility(reduceMotion: true, dimFlashingLights: true)
            NotificationCenter.default.post(name: name, object: nil)
            XCTAssertEqual(observer.current, value, "\(name.rawValue) refreshes")
        }
    }

    func testSystemValuesUsePublicAPIs() {
        let values = SystemAccessibilityObserver.systemValues()
        XCTAssertEqual(values.reduceMotion, UIAccessibility.isReduceMotionEnabled)
        let resolved = AccessibilityPreferences().resolve(values)
        XCTAssertEqual(resolved.reduceMotion, values.reduceMotion, "System choice follows the system")
    }
}
