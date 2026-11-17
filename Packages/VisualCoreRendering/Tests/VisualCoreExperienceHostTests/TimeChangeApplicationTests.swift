// TimeChangeApplicationTests — feature 131 T-A18-103 (FR-A18-102; contract clock.md "Monitor"): the application names
// map each of the five time-change kinds exactly once, and posting each name on a private center gives one event of
// its kind.
#if canImport(UIKit)
import Foundation
import UIKit
import XCTest
import VisualCoreExperience
@testable import VisualCoreExperienceHost

final class TimeChangeApplicationTests: XCTestCase {
    func testApplicationNamesMapEachKindOnce() {
        let names = TimeChangeMonitor.applicationNames
        XCTAssertEqual(names.count, 5)
        XCTAssertEqual(Set(names.values), Set(TimeChangeKind.allCases))
        XCTAssertEqual(names.values.count, Set(names.values).count)
        XCTAssertEqual(names[UIApplication.significantTimeChangeNotification], .significantTime)
        XCTAssertEqual(names[UIApplication.willEnterForegroundNotification], .foreground)
        for (name, kind) in TimeChangeMonitor.foundationNames {
            XCTAssertEqual(names[name], kind, name.rawValue)
        }
    }

    func testEachApplicationNameGivesOneEventOfItsKind() {
        for (name, kind) in TimeChangeMonitor.applicationNames {
            let center = NotificationCenter()
            let recorder = KindLog()
            let monitor = TimeChangeMonitor(center: center, names: TimeChangeMonitor.applicationNames) { recorder.append($0) }
            monitor.start()
            center.post(name: name, object: nil)
            XCTAssertEqual(recorder.kinds, [kind], name.rawValue)
            monitor.stop()
            center.post(name: name, object: nil)
            XCTAssertEqual(recorder.kinds, [kind], name.rawValue)
        }
    }
}

/// Collects reported kinds; the monitor calls it synchronously on the posting (test) thread.
private final class KindLog: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [TimeChangeKind] = []
    var kinds: [TimeChangeKind] { lock.withLock { stored } }
    func append(_ kind: TimeChangeKind) { lock.withLock { stored.append(kind) } }
}
#endif
