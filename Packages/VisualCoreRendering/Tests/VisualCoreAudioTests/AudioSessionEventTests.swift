// AudioSessionEventTests — feature 050 (A06-P04) T-A06-402 (FR-A06-401; SC-A06-401; gap G-INTERRUPTION; research D1,
// D2): every audio-session notification kind maps to the right event (including the resume flag), other route-change
// reasons, malformed or missing user info and unrelated names map to nothing, and the monitor delivers events posted
// on a private notification center until it is stopped. No real audio session is touched; each test runs well under
// 2 s.
import AVFAudio
import Foundation
import XCTest
@testable import VisualCoreAudio

/// Collects delivered events (a reference, so main-actor handlers can append without capturing a mutable local).
@MainActor
private final class EventRecorder {
    var events: [AudioSessionEvent] = []
}

@MainActor
final class AudioSessionEventTests: XCTestCase {
    private typealias Session = AVAudioSession

    private func interruption(_ type: Session.InterruptionType, options: Session.InterruptionOptions? = nil)
        -> [AnyHashable: Any] {
        var info: [AnyHashable: Any] = [AVAudioSessionInterruptionTypeKey: NSNumber(value: type.rawValue)]
        if let options { info[AVAudioSessionInterruptionOptionKey] = NSNumber(value: options.rawValue) }
        return info
    }

    private func route(_ reason: Session.RouteChangeReason) -> [AnyHashable: Any] {
        [AVAudioSessionRouteChangeReasonKey: NSNumber(value: reason.rawValue)]
    }

    // MARK: Mapping table (SC-A06-401)

    func testInterruptionBeganMaps() {
        XCTAssertEqual(AudioSessionEvent(name: Session.interruptionNotification, userInfo: interruption(.began)),
                       .interruptionBegan)
    }

    func testInterruptionEndedWithResumeMaps() {
        XCTAssertEqual(AudioSessionEvent(name: Session.interruptionNotification,
                                         userInfo: interruption(.ended, options: .shouldResume)),
                       .interruptionEnded(shouldResume: true))
    }

    func testInterruptionEndedWithoutResumeMaps() {
        XCTAssertEqual(AudioSessionEvent(name: Session.interruptionNotification,
                                         userInfo: interruption(.ended, options: [])),
                       .interruptionEnded(shouldResume: false))
        // The system omits the option key when resuming is not allowed.
        XCTAssertEqual(AudioSessionEvent(name: Session.interruptionNotification, userInfo: interruption(.ended)),
                       .interruptionEnded(shouldResume: false))
    }

    func testPlainUIntValuesMapToo() {
        let info: [AnyHashable: Any] = [AVAudioSessionInterruptionTypeKey: Session.InterruptionType.ended.rawValue,
                                        AVAudioSessionInterruptionOptionKey: Session.InterruptionOptions.shouldResume
                                            .rawValue]
        XCTAssertEqual(AudioSessionEvent(name: Session.interruptionNotification, userInfo: info),
                       .interruptionEnded(shouldResume: true))
    }

    func testRouteLostOnlyForOldDeviceUnavailable() {
        XCTAssertEqual(AudioSessionEvent(name: Session.routeChangeNotification, userInfo: route(.oldDeviceUnavailable)),
                       .routeLost)
        for reason: Session.RouteChangeReason in [.newDeviceAvailable, .categoryChange, .override, .unknown,
                                                  .wakeFromSleep, .noSuitableRouteForCategory,
                                                  .routeConfigurationChange] {
            XCTAssertNil(AudioSessionEvent(name: Session.routeChangeNotification, userInfo: route(reason)),
                         "reason \(reason.rawValue)")
        }
    }

    func testMediaServicesResetMaps() {
        XCTAssertEqual(AudioSessionEvent(name: Session.mediaServicesWereResetNotification, userInfo: nil),
                       .mediaServicesReset)
        XCTAssertEqual(AudioSessionEvent(name: Session.mediaServicesWereResetNotification, userInfo: ["x": 1]),
                       .mediaServicesReset)
    }

    func testMalformedOrMissingUserInfoMapsToNil() {
        let interruptionName = Session.interruptionNotification
        XCTAssertNil(AudioSessionEvent(name: interruptionName, userInfo: nil))
        XCTAssertNil(AudioSessionEvent(name: interruptionName, userInfo: [:]))
        XCTAssertNil(AudioSessionEvent(name: interruptionName, userInfo: [AVAudioSessionInterruptionTypeKey: "began"]))
        XCTAssertNil(AudioSessionEvent(name: interruptionName,
                                       userInfo: [AVAudioSessionInterruptionTypeKey: NSNumber(value: 99)]))
        XCTAssertNil(AudioSessionEvent(name: interruptionName,
                                       userInfo: [AVAudioSessionInterruptionTypeKey:
                                                      NSNumber(value: AVAudioSession.InterruptionType.ended.rawValue),
                                                  AVAudioSessionInterruptionOptionKey: "resume"]))
        let routeName = Session.routeChangeNotification
        XCTAssertNil(AudioSessionEvent(name: routeName, userInfo: nil))
        XCTAssertNil(AudioSessionEvent(name: routeName, userInfo: [AVAudioSessionRouteChangeReasonKey: "lost"]))
        XCTAssertNil(AudioSessionEvent(name: routeName,
                                       userInfo: [AVAudioSessionRouteChangeReasonKey: NSNumber(value: 999)]))
    }

    func testUnrelatedNameMapsToNil() {
        XCTAssertNil(AudioSessionEvent(name: Notification.Name("vc.unrelated"), userInfo: interruption(.began)))
        XCTAssertNil(AudioSessionEvent(name: Session.silenceSecondaryAudioHintNotification, userInfo: nil))
    }

    // MARK: Monitor (research D2)

    private func pump(until condition: () -> Bool, limit: TimeInterval = 1) {
        let deadline = Date().addingTimeInterval(limit)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    func testMonitorDeliversEventsFromPrivateCenterUntilStopped() {
        let center = NotificationCenter()
        let recorder = EventRecorder()
        let monitor = AudioSessionEventMonitor(center: center) { recorder.events.append($0) }

        center.post(name: Session.interruptionNotification, object: nil, userInfo: interruption(.began))
        center.post(name: Session.routeChangeNotification, object: nil, userInfo: route(.newDeviceAvailable))
        center.post(name: Session.routeChangeNotification, object: nil, userInfo: route(.oldDeviceUnavailable))
        center.post(name: Session.mediaServicesWereResetNotification, object: nil)
        center.post(name: Session.interruptionNotification, object: nil,
                    userInfo: interruption(.ended, options: .shouldResume))
        let expected: [AudioSessionEvent] = [.interruptionBegan, .routeLost, .mediaServicesReset,
                                             .interruptionEnded(shouldResume: true)]
        pump { recorder.events.count >= expected.count }
        XCTAssertEqual(recorder.events, expected, "unmapped route change dropped, order kept")

        monitor.stop()
        monitor.stop()
        center.post(name: Session.interruptionNotification, object: nil, userInfo: interruption(.began))
        center.post(name: Session.mediaServicesWereResetNotification, object: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(recorder.events, expected, "nothing after stop()")
    }

    func testReleasedMonitorDeliversNothing() {
        let center = NotificationCenter()
        let recorder = EventRecorder()
        var monitor: AudioSessionEventMonitor? = AudioSessionEventMonitor(center: center) {
            recorder.events.append($0)
        }
        XCTAssertNotNil(monitor)
        monitor = nil
        center.post(name: Session.mediaServicesWereResetNotification, object: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertTrue(recorder.events.isEmpty)
    }
}
