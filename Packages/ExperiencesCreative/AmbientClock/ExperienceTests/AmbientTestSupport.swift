// AmbientTestSupport — feature 132 (A18-P02) T-A18-204 (FR-A18-201–209; SC-A18-201–204). Shared helpers of the
// Ambient Clock experience tests: the fixed instant and zones, text normalization (U+202F and U+00A0 become a plain
// space), a lock-protected environment box whose locale and zone a test switches (New York → Kolkata), an engine and a
// shell without a render host (prepared and active, so actions are carried out with no frame drawn), opening the
// experience in the one app's session host with a private notification centre and a fixed clock, drawing and reading
// frames, offscreen stills at a given frame time, the formatter's expected display and the engine digest of a core.
import Foundation
import Synchronization
import Testing
import UIKit
import AmbientClockCore
@testable import AmbientClockExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

/// The fixtures of the Ambient Clock experience tests.
enum AmbientFixtures {
    /// New York (daylight saving in June: UTC−4).
    static let newYork = TimeZone(identifier: "America/New_York")!
    /// Kolkata (UTC+5:30).
    static let kolkata = TimeZone(identifier: "Asia/Kolkata")!
    /// en_US.
    static let enUS = Locale(identifier: "en_US")
    /// de_DE.
    static let deDE = Locale(identifier: "de_DE")
    /// 2026-06-15T18:05:00Z: 2:05 PM in New York, 11:35 PM in Kolkata.
    static let instant = date("2026-06-15T18:05:00Z")
    /// The thirteen keys of a schema-3 snapshot payload (A18-P04).
    static let schemaThreeKeys: Set<String> = ["hourCycle", "keepAwake", "motion", "nightDim", "nightEnd", "nightMode",
                                               "nightStart", "palette", "reduceMotion", "showDate", "showSeconds",
                                               "speed", "theme"]

    /// The instant of an ISO 8601 UTC string such as "2026-06-15T18:05:00Z".
    static func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let value = formatter.date(from: iso) else { preconditionFailure("bad fixture date \(iso)") }
        return value
    }

    /// `text` with U+202F and U+00A0 mapped to a plain space.
    static func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    /// The display the A18-P01 formatter gives for `date` with the format fields and the system `locale` and `zone`.
    static func expected(at date: Date, hourCycle: Int, showSeconds: Bool, showDate: Bool, locale: Locale,
                         zone: TimeZone) -> ClockDisplay {
        let preferences = AmbientCore.preferences(hourCycle: hourCycle, showSeconds: showSeconds, showDate: showDate)
        let environment = ClockEnvironment(preferences: preferences, systemLocale: locale, systemTimeZone: zone)
        return ClockFormatter.display(at: date, preferences: preferences, environment: environment)
    }
}

/// A locale and zone a test can switch while the presenter's environment provider reads them.
final class AmbientEnvironmentBox: Sendable {
    private let value: Mutex<(Locale, TimeZone)>

    /// A box holding `locale` and `zone` (by default en_US in New York).
    init(locale: Locale = AmbientFixtures.enUS, zone: TimeZone = AmbientFixtures.newYork) {
        value = Mutex((locale, zone))
    }

    /// The current locale and zone.
    var current: (Locale, TimeZone) { value.withLock { $0 } }

    /// Replaces the locale and zone.
    func set(locale: Locale, zone: TimeZone) {
        value.withLock { $0 = (locale, zone) }
    }

    /// Replaces the zone only.
    func set(zone: TimeZone) {
        value.withLock { $0 = ($0.0, zone) }
    }

    /// The presenter's environment provider over this box.
    var provider: AmbientPresenter.Environment {
        { [self] in self.current }
    }
}

/// A frame read back from the host: RGBA bytes, rows bottom-up.
typealias AmbientFrame = (rgba: [UInt8], width: Int, height: Int)

/// Building, opening, drawing and reading Ambient Clock.
@MainActor
enum AmbientTest {
    /// The experience id `a18.ambient-clock`.
    static var id: ExperienceID {
        AmbientClockExperience.id ?? ExperienceID(rawValue: "a18.unknown")!
    }

    /// A prepared, active engine of the core alone.
    static func engine(seed: UInt64 = 1) async throws -> ExperienceEngine<AmbientCore> {
        var engine = ExperienceEngine<AmbientCore>(id: id)
        try await engine.prepare(seed: seed)
        try engine.activate()
        return engine
    }

    /// The shell of the factory with `clock`, the provider of `box` and `center`, prepared and active but without a
    /// render host: actions are carried out and no frame is ever drawn.
    static func shell(clock: FixedClock, box: AmbientEnvironmentBox = AmbientEnvironmentBox(),
                      center: NotificationCenter = NotificationCenter(),
                      reduceMotion: Bool = false) async throws -> ExperienceShell<AmbientPresenter> {
        let shell = AmbientClockExperience.make(id: id, clock: clock, environment: box.provider, center: center,
                                                reduceMotion: reduceMotion)
        try await shell.prepare(seed: 1)
        try shell.activate()
        return shell
    }

    /// The core of `shell`.
    static func core(_ shell: ExperienceShell<AmbientPresenter>) throws -> AmbientCore {
        try #require(shell.engine.core)
    }

    /// Opens Ambient Clock in `session` through the factory (with `clock`, the provider of `box`, `center` and
    /// `reduceMotion`), lays the view out at `size` points and draws one frame. A session without a quality pin is
    /// pinned to level 0, so the automatic level never changes a frame between two readings.
    static func open(_ session: ExperienceSession, clock: FixedClock = FixedClock(AmbientFixtures.instant),
                     box: AmbientEnvironmentBox = AmbientEnvironmentBox(),
                     center: NotificationCenter = NotificationCenter(), reduceMotion: Bool = false,
                     size: CGSize = CGSize(width: 200, height: 200)) async throws -> ExperienceShell<AmbientPresenter> {
        let id = self.id
        let provider = box.provider
        var made: ExperienceShell<AmbientPresenter>?
        if session.qualityPin == nil { session.qualityPin = 0 }
        let request = ExperienceOpenRequest(id: id, seed: 1, snapshot: nil, refusedSnapshotFails: false) {
            let shell = AmbientClockExperience.make(id: id, clock: clock, environment: provider, center: center,
                                                    reduceMotion: reduceMotion)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        #expect(opened == .running)
        let view = try #require(session.renderHost?.view)
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutIfNeeded()
        let shell = try #require(made)
        let host = try #require(session.renderHost)
        let drawn = host.renderOneFrame(present: false)
        #expect(drawn)
        return shell
    }

    /// The pixels of a freshly drawn frame with its width and height.
    static func picture(_ session: ExperienceSession) throws -> AmbientFrame {
        let host = try #require(session.renderHost)
        let drawn = host.renderOneFrame(present: false)
        #expect(drawn)
        let size = host.pixelSize
        return (host.readPixels(), size.width, size.height)
    }

    /// The scene drawn offscreen at `width` × `height` pixels at frame time `time` (rows top-down).
    static func still(_ session: ExperienceSession, time: Double, width: Int = 96, height: Int = 96) throws
        -> StillImage {
        let host = try #require(session.renderHost)
        return try host.renderOffscreen(width: width, height: height, time: time)
    }

    /// The number of pixels whose RGB differs in some channel.
    static func differingPixels(_ a: [UInt8], _ b: [UInt8]) -> Int {
        guard a.count == b.count else { return max(a.count, b.count) / 4 }
        var count = 0
        var i = 0
        while i + 3 < a.count {
            if a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2] { count += 1 }
            i += 4
        }
        return count
    }
}

/// The digest of `core` as the engine computes it (the experience id as domain).
func ambientDigest(_ core: AmbientCore) throws -> String {
    var builder = DigestBuilder(domain: AmbientCore.experienceID)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

/// `core` after `control` with `values` applied directly, with the result.
func ambientApplied(_ core: AmbientCore, _ control: String, _ values: [Double]) -> (AmbientCore, ActionResult) {
    var next = core
    let result = next.apply(ExperienceAction(control: control, values: values, step: 0))
    return (next, result)
}
