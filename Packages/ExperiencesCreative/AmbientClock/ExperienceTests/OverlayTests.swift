// OverlayTests — feature 132 (A18-P02) T-A18-204 (FR-A18-203, FR-A18-205, FR-A18-206; SC-A18-201, SC-A18-204;
// research D5; contracts/experience.md "Time", "Overlay"). The text the native overlay shows and the canvas label,
// with a fixed clock and an injected environment and no frame drawn: after a tick (or a `time.set` sent by anyone) the
// presenter's display equals `ClockFormatter.display(at:preferences:environment:)` for New York and Kolkata, the
// system, 12-hour and 24-hour cycles, seconds on and off and the date on and off; `describe` (and the shell's summary)
// is the display's spoken string; and the time line at the largest Dynamic Type size fits one line within 90 % of
// the width of a 320-point and a 1,024-point canvas.
import Foundation
import Testing
import CoreGraphics
import AmbientClockCore
@testable import AmbientClockExperience
import VisualCoreExperience
import VisualCoreExperienceHost

/// One format of the clock.
private struct AmbientFormat: Sendable {
    let hourCycle: Int
    let showSeconds: Bool
    let showDate: Bool
}

/// The twelve formats: every hour cycle × seconds on and off × date on and off.
private let allFormats: [AmbientFormat] = {
    var formats: [AmbientFormat] = []
    for cycle in 0..<3 {
        for seconds in [false, true] {
            for date in [false, true] {
                formats.append(AmbientFormat(hourCycle: cycle, showSeconds: seconds, showDate: date))
            }
        }
    }
    return formats
}()

/// 2026-06-15T18:05:09Z: 2:05:09 PM in New York, 11:35:09 PM in Kolkata.
private let secondsInstant = AmbientFixtures.date("2026-06-15T18:05:09Z")

@MainActor
@Suite struct OverlayTests {
    @Test func theTextAfterATickIsTheFormattersForEveryZoneAndFormat() async throws {
        let zones = [AmbientFixtures.newYork, AmbientFixtures.kolkata]
        #expect(allFormats.count == 12)
        for zone in zones {
            let clock = FixedClock(secondsInstant)
            let box = AmbientEnvironmentBox(locale: AmbientFixtures.enUS, zone: zone)
            let shell = try await AmbientTest.shell(clock: clock, box: box)
            let presenter = shell.presenter
            for format in allFormats {
                let label = "\(zone.identifier) cycle \(format.hourCycle) seconds \(format.showSeconds) "
                    + "date \(format.showDate)"
                let set = presenter.setFormat(hourCycle: format.hourCycle, showSeconds: format.showSeconds,
                                              showDate: format.showDate, port: shell.port)
                #expect(set == .accepted, "\(label)")
                presenter.tick(port: shell.port)
                let expected = AmbientFixtures.expected(at: secondsInstant, hourCycle: format.hourCycle,
                                                        showSeconds: format.showSeconds, showDate: format.showDate,
                                                        locale: AmbientFixtures.enUS, zone: zone)
                let shown = try #require(presenter.display.display, "\(label)")
                #expect(AmbientFixtures.normalized(shown.time) == AmbientFixtures.normalized(expected.time),
                        "\(label)")
                #expect(AmbientFixtures.normalized(shown.date) == AmbientFixtures.normalized(expected.date),
                        "\(label)")
                #expect(shown.date.isEmpty == !format.showDate, "\(label)")
                #expect(presenter.mirror.display == shown, "\(label)")
                let core = try AmbientTest.core(shell)
                #expect(core.hourCycle == format.hourCycle && core.showSeconds == format.showSeconds
                        && core.showDate == format.showDate, "\(label)")
                let spoken = presenter.describe(core)
                #expect(AmbientFixtures.normalized(spoken) == AmbientFixtures.normalized(expected.spoken), "\(label)")
                #expect(shell.accessibilitySummary == shown.spoken, "\(label)")
                #expect(shell.port.summary == shown.spoken, "\(label)")
            }
        }
    }

    @Test func theTimeLinesAreTheExpectedWords() async throws {
        let cases: [(TimeZone, Int, Bool, String)] = [
            (AmbientFixtures.newYork, 0, false, "2:05 PM"), (AmbientFixtures.newYork, 1, false, "2:05 PM"),
            (AmbientFixtures.newYork, 2, false, "14:05"), (AmbientFixtures.newYork, 2, true, "14:05:09"),
            (AmbientFixtures.kolkata, 1, false, "11:35 PM"), (AmbientFixtures.kolkata, 2, false, "23:35"),
            (AmbientFixtures.kolkata, 1, true, "11:35:09 PM"),
        ]
        for (zone, cycle, seconds, words) in cases {
            let box = AmbientEnvironmentBox(locale: AmbientFixtures.enUS, zone: zone)
            let shell = try await AmbientTest.shell(clock: FixedClock(secondsInstant), box: box)
            let set = shell.presenter.setFormat(hourCycle: cycle, showSeconds: seconds, showDate: true,
                                                port: shell.port)
            #expect(set == .accepted)
            shell.presenter.tick(port: shell.port)
            let time = AmbientFixtures.normalized(shell.presenter.display.display?.time ?? "")
            #expect(time == words, "\(zone.identifier) cycle \(cycle) seconds \(seconds)")
        }
    }

    @Test func aTimeSetSentByAnyoneIsShown() async throws {
        let box = AmbientEnvironmentBox(locale: AmbientFixtures.deDE, zone: AmbientFixtures.newYork)
        let shell = try await AmbientTest.shell(clock: FixedClock(AmbientFixtures.instant), box: box)
        let instant = AmbientFixtures.date("2026-12-24T21:30:00Z")
        let result = shell.handle(control: "time.set", values: [instant.timeIntervalSince1970])
        #expect(result == .accepted)
        let core = try AmbientTest.core(shell)
        let spoken = shell.presenter.describe(core)
        let expected = AmbientFixtures.expected(at: instant, hourCycle: 0, showSeconds: false, showDate: true,
                                                locale: AmbientFixtures.deDE, zone: AmbientFixtures.newYork)
        let shown = try #require(shell.presenter.display.display)
        #expect(AmbientFixtures.normalized(shown.time) == "16:30")
        #expect(shown == expected)
        #expect(spoken == expected.spoken)
        #expect(spoken == expected.time + ", " + expected.date)
    }

    @Test func beforeTheFirstInstantTheLabelIsTheName() async throws {
        let shell = try await AmbientTest.shell(clock: FixedClock(AmbientFixtures.instant))
        let core = try AmbientTest.core(shell)
        #expect(core.instant == 0)
        #expect(shell.presenter.describe(core) == AmbientPresenter.fallbackDescription)
        #expect(shell.presenter.describe(core) == "Ambient Clock")
        #expect(shell.presenter.display.display == nil)
    }

    @Test func theProbeIsTheDarkCentre() async throws {
        let shell = try await AmbientTest.shell(clock: FixedClock(AmbientFixtures.instant))
        let probes = shell.frameProbes
        #expect(probes.count == 1)
        let probe = try #require(probes.first)
        #expect(probe.x == 0.5 && probe.y == 0.5)
        #expect(probe.expected == FrameColorClass.dark.rawValue)
        #expect(shell.presenter.nativeActions == ["clock.format", "theme.motion", "theme.speed"])
    }

    @Test func theLargestTextFitsOneLineWithinNinetyPercentOfTheWidth() {
        let canvases = [CGSize(width: 320, height: 568), CGSize(width: 568, height: 320),
                        CGSize(width: 1024, height: 768), CGSize(width: 1024, height: 1366)]
        let factor = ClockOverlay.largestDynamicTypeFactor
        #expect(factor > 3)
        let texts = [ClockOverlay.longestTime, "11:35:09 PM", "23:35:09", "2:05 PM"]
        for canvas in canvases {
            for text in texts {
                let size = ClockOverlay.timeFontSize(canvas: canvas, dynamicTypeFactor: factor,
                                                     characters: text.count)
                #expect(size > 0, "\(canvas) \(text)")
                let width = ClockOverlay.estimatedWidth(fontSize: size, characters: text.count)
                #expect(width <= 0.9 * Double(canvas.width), "\(canvas) \(text): \(width)")
                #expect(ClockOverlay.fits(canvas: canvas, dynamicTypeFactor: factor, text: text), "\(canvas) \(text)")
                #expect(size <= ClockOverlay.timeShare * Double(min(canvas.width, canvas.height)) * factor + 1e-9)
            }
        }
    }

    @Test func atTheDefaultTextSizeTheTimeIsAShareOfTheShorterSide() {
        let canvas = CGSize(width: 1024, height: 768)
        let size = ClockOverlay.timeFontSize(canvas: canvas, dynamicTypeFactor: 1, characters: 5)
        #expect(abs(size - 0.22 * 768) < 1e-9)
        #expect(ClockOverlay.timeFontSize(canvas: .zero, dynamicTypeFactor: 1) == 0)
        #expect(!ClockOverlay.fits(canvas: .zero, dynamicTypeFactor: 1))
        let base = ClockOverlay.timeFontSize(canvas: canvas, dynamicTypeFactor: 1, characters: 5)
        #expect(ClockOverlay.timeFontSize(canvas: canvas, dynamicTypeFactor: .nan, characters: 5) == base)
        #expect(ClockOverlay.minimumScaleFactor == 0.3)
        #expect(ClockOverlay.widthShare == 0.9)
    }

    @Test func theSleepIntervalIsTheTimeToTheDeadlineAtLeastFiftyMilliseconds() {
        let now = AmbientFixtures.instant
        #expect(ClockOverlay.sleepInterval(until: now.addingTimeInterval(42), now: now) == 42)
        #expect(ClockOverlay.sleepInterval(until: now, now: now) == 0.05)
        #expect(ClockOverlay.sleepInterval(until: now.addingTimeInterval(-3), now: now) == 0.05)
    }
}
