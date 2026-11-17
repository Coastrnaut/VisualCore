// TimeChangeMonitorTests — feature 131 T-A18-102 (FR-A18-102; contract clock.md "Monitor"): each Foundation name posted
// on a private center gives exactly one handler call with its kind; none after `stop()`; an unnamed notification is
// ignored; `start()` twice observes once; `isRunning` follows the state.
import Foundation
import Synchronization
import Testing
@testable import VisualCoreExperience

/// Collects the kinds a monitor reports.
private final class KindRecorder: Sendable {
    private let kinds = Mutex<[TimeChangeKind]>([])
    var all: [TimeChangeKind] { kinds.withLock { $0 } }
    func record(_ kind: TimeChangeKind) { kinds.withLock { $0.append(kind) } }
}

@Suite struct TimeChangeMonitorTests {
    private func monitor(_ center: NotificationCenter, _ recorder: KindRecorder) -> TimeChangeMonitor {
        TimeChangeMonitor(center: center) { recorder.record($0) }
    }

    @Test func foundationNamesMapTheThreeFoundationKinds() {
        let names = TimeChangeMonitor.foundationNames
        #expect(names.count == 3)
        #expect(names[.NSSystemTimeZoneDidChange] == .timeZone)
        #expect(names[NSLocale.currentLocaleDidChangeNotification] == .locale)
        #expect(names[.NSCalendarDayChanged] == .calendarDay)
    }

    @Test func eachFoundationNameGivesOneCallWithItsKind() {
        for (name, kind) in TimeChangeMonitor.foundationNames {
            let center = NotificationCenter()
            let recorder = KindRecorder()
            let subject = monitor(center, recorder)
            subject.start()
            center.post(name: name, object: nil)
            #expect(recorder.all == [kind], "\(name.rawValue)")
            subject.stop()
        }
    }

    @Test func noCallAfterStop() {
        let center = NotificationCenter()
        let recorder = KindRecorder()
        let subject = monitor(center, recorder)
        subject.start()
        subject.stop()
        for name in TimeChangeMonitor.foundationNames.keys { center.post(name: name, object: nil) }
        #expect(recorder.all.isEmpty)
    }

    @Test func unnamedNotificationIsIgnored() {
        let center = NotificationCenter()
        let recorder = KindRecorder()
        let subject = monitor(center, recorder)
        subject.start()
        center.post(name: Notification.Name("VisualCore.Unrelated"), object: nil)
        #expect(recorder.all.isEmpty)
        subject.stop()
    }

    @Test func startingTwiceObservesOnce() {
        let center = NotificationCenter()
        let recorder = KindRecorder()
        let subject = monitor(center, recorder)
        subject.start()
        subject.start()
        center.post(name: .NSCalendarDayChanged, object: nil)
        center.post(name: .NSSystemTimeZoneDidChange, object: nil)
        #expect(recorder.all == [.calendarDay, .timeZone])
        subject.stop()
    }

    @Test func isRunningFollowsStartAndStop() {
        let subject = TimeChangeMonitor(center: NotificationCenter()) { _ in }
        #expect(!subject.isRunning)
        subject.start()
        #expect(subject.isRunning)
        subject.stop()
        #expect(!subject.isRunning)
        subject.stop()
        #expect(!subject.isRunning)
        subject.start()
        #expect(subject.isRunning)
    }

    @Test func deinitStopsObserving() {
        let center = NotificationCenter()
        let recorder = KindRecorder()
        do {
            let subject = monitor(center, recorder)
            subject.start()
            center.post(name: .NSCalendarDayChanged, object: nil)
        }
        center.post(name: .NSCalendarDayChanged, object: nil)
        #expect(recorder.all == [.calendarDay])
    }

    @Test func customNamesAreHonoured() {
        let center = NotificationCenter()
        let recorder = KindRecorder()
        let custom = Notification.Name("VisualCore.Foreground")
        let subject = TimeChangeMonitor(center: center, names: [custom: .foreground]) { recorder.record($0) }
        subject.start()
        center.post(name: custom, object: nil)
        center.post(name: .NSCalendarDayChanged, object: nil)
        #expect(recorder.all == [.foreground])
        subject.stop()
    }
}
