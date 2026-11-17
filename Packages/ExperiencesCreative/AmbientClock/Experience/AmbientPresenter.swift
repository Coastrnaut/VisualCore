// AmbientPresenter — feature 132 T-A18-203 (FR-A18-202–207; G-OVERLAY/G-BUDGETS; clarifications Q1–Q5; contracts/
// experience.md). Draws Ambient Clock through the host only and owns its presentation state:
//
//   - Background: one `FullScreenShaderScene` running `NoiseGradientTheme`, made and compiled in `setup` (so it is
//     remade after a context recreation) and released in `teardown`; a compile or link error throws
//     `NoiseGradientShaderError`, which fails the session's setup with its message. `draw` sets the uniforms from the
//     core and the frame (octaves and pixel block of the tier; the effective time: 0 with motion off or Reduce Motion
//     on, else frame time × speed) and draws exactly once.
//   - Time: the presenter reads the wall time only from its injected `ClockSource` (FR-A18-206) and the system's
//     locale and zone only from its injected environment provider, at the moment of each event. Its display model is
//     the A18-P01 `AmbientClockState` (`display`); `tick(port:)` sends `time.set` with the source's instant and
//     returns the next deadline (`ClockSchedule.nextDeadline`); `timeChanged(_:port:)` re-reads the environment,
//     sends `time.changed` and then the time again.
//   - Monitor: a `TimeChangeMonitor` over the injected `NotificationCenter` with `TimeChangeMonitor.applicationNames`
//     is started in `setup` (before the shader is built, so it runs even when the shader fails) and stopped in
//     `teardown` (`startMonitoring()`, `stopMonitoring()`). The monitor sends through the port the factory sets
//     (`port`, as Interactive Anatomy's presenter); `makeControls` and `makeCanvasOverlay` also adopt their port when
//     none is set yet. Each notification re-reads once; nothing is announced (FR-A18-205).
//   - Display order: before an action is sent the display is brought up to date, because the shell asks `describe`
//     for the canvas label inside the send; `describe(_:)` also follows the core (a new instant, a new format) so
//     actions sent by anyone else (the verification runner, a restore) show too.
//   - The canvas label is the display's spoken string (`describe`), the overlay is `ClockOverlay` and the controls
//     are `AmbientControls`; the probe is the canvas centre, `dark` (the overlay's text is not in the drawn frame).
import AmbientClockCore
import Foundation
import Observation
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

/// What the overlay and the controls show, updated only when a field changes.
@MainActor
@Observable
final class AmbientMirror {
    /// The text of the current instant; nil before the first instant.
    var display: ClockDisplay?
    /// The hour cycle's index (0 system, 1 h12, 2 h24).
    var hourCycle = 0
    /// Whether the seconds are shown.
    var showSeconds = false
    /// Whether the date line is shown.
    var showDate = true
    /// Whether the background moves.
    var motion = true
    /// The background's speed.
    var speed = AmbientCore.defaultSpeed
}

/// Draws Ambient Clock and owns its presentation state (see the file header).
@MainActor
final class AmbientPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = AmbientCore
    /// Supplies the system's locale and time zone at the moment of an event.
    typealias Environment = @Sendable () -> (Locale, TimeZone)

    /// The canvas label before any instant is known.
    static let fallbackDescription = "Ambient Clock"
    /// The system environment: `Locale.current` and `TimeZone.current` when called.
    nonisolated static let systemEnvironment: Environment = { (Locale.current, TimeZone.current) }

    /// The only source of the wall time.
    let clock: any ClockSource
    /// The provider of the system's locale and zone.
    let environment: Environment
    /// The notification centre the monitor observes.
    let center: NotificationCenter
    /// Whether Reduce Motion was on when the experience was made: the background is then still.
    let reduceMotion: Bool
    /// What the overlay and the controls show.
    let mirror = AmbientMirror()
    /// The port of the shell, for the monitor's actions; set by the factory (or adopted from the controls or the
    /// overlay).
    weak var port: ExperienceActionPort?
    /// The display model (A18-P01): the instant, the preferences, the system locale and zone and the text.
    private(set) var display: AmbientClockState {
        didSet { if mirror.display != display.display { mirror.display = display.display } }
    }
    /// The time-change monitor (`applicationNames` over `center`); running between `setup` and `teardown`.
    private(set) var monitor: TimeChangeMonitor?
    /// The theme's full-screen scene; made in `setup`, released in `teardown`.
    private(set) var scene: FullScreenShaderScene?
    /// The last core instant `describe` followed; nil before the first.
    private var followedInstant: Double?
    /// The number of full-screen draws of the last frame (1 when drawn, 0 otherwise).
    private(set) var lastDrawCount = 0
    /// The uniform time of the last frame.
    private(set) var lastUniformTime = 0.0
    /// The noise octaves of the last frame.
    private(set) var lastOctaves = 0
    /// How many time-change events reached the presenter.
    private(set) var timeChangeCount = 0

    /// A presenter reading the time from `clock`, the system locale and zone from `environment`, observing the
    /// time-change notifications on `center`; with `reduceMotion` on the background never moves.
    init(clock: any ClockSource = SystemClock(),
         environment: @escaping Environment = AmbientPresenter.systemEnvironment,
         center: NotificationCenter = .default, reduceMotion: Bool = false) {
        self.clock = clock
        self.environment = environment
        self.center = center
        self.reduceMotion = reduceMotion
        let (locale, zone) = environment()
        display = AmbientClockState(preferences: ClockPreferences(), systemLocale: locale, systemTimeZone: zone)
    }

    // MARK: Time

    /// Shows the clock source's instant and sends it as `time.set` through `port` (the display is updated first, so
    /// it is correct even when the action is refused while the experience cannot take actions) and returns the next
    /// deadline: a whole minute after the instant, or a whole second with seconds shown.
    @discardableResult
    func tick(port: ExperienceActionPort) -> Date {
        let now = clock.now
        adoptEnvironmentIfChanged()
        display.apply(.timeSet(now))
        port.send("time.set", [now.timeIntervalSince1970])
        return display.nextDeadline
            ?? ClockSchedule.nextDeadline(after: now, showSeconds: display.preferences.showSeconds,
                                          calendar: display.environment.calendar)
    }

    /// A time-change event of `kind`: re-reads the environment into the display, sends `time.changed` with the kind's
    /// index through `port`, then sends the time again (`tick(port:)`).
    func timeChanged(_ kind: TimeChangeKind, port: ExperienceActionPort) {
        timeChangeCount += 1
        let (locale, zone) = environment()
        display.apply(.timeChanged(kind, systemLocale: locale, systemTimeZone: zone))
        port.send("time.changed", [AmbientCore.value(of: kind)])
        tick(port: port)
    }

    /// Rebuilds the display with the environment's locale and zone when they differ from the display's (by
    /// identifier); keeps the preferences and the instant. Used before a `time.set`, for a change no notification
    /// reported (a notification goes through `timeChanged`, which counts its recomputation).
    private func adoptEnvironmentIfChanged() {
        let (locale, zone) = environment()
        guard locale.identifier != display.systemLocale.identifier
                || zone.identifier != display.systemTimeZone.identifier else { return }
        var rebuilt = AmbientClockState(preferences: display.preferences, systemLocale: locale, systemTimeZone: zone)
        if let now = display.now { rebuilt.apply(.timeSet(now)) }
        display = rebuilt
    }

    /// Sends `clock.format` with `hourCycle` (0 system, 1 h12, 2 h24), `showSeconds` and `showDate` through `port`;
    /// the display follows the accepted core in `describe`.
    @discardableResult
    func setFormat(hourCycle: Int, showSeconds: Bool, showDate: Bool, port: ExperienceActionPort) -> ActionResult {
        let preferences = AmbientCore.preferences(hourCycle: hourCycle, showSeconds: showSeconds, showDate: showDate)
        return port.send("clock.format", AmbientCore.formatValues(preferences))
    }

    // MARK: Monitor

    /// Starts the time-change monitor (made on first use); each notification calls `timeChanged(_:port:)` on the
    /// main actor — at once when posted on the main thread — through `port`, and nothing when no port is set.
    func startMonitoring() {
        if monitor == nil {
            monitor = TimeChangeMonitor(center: center, names: TimeChangeMonitor.applicationNames) { [weak self] kind in
                guard let self else { return }
                if Thread.isMainThread {
                    MainActor.assumeIsolated { self.observe(kind) }
                } else {
                    Task { @MainActor in self.observe(kind) }
                }
            }
        }
        monitor?.start()
    }

    /// Stops the time-change monitor; nothing is sent afterwards.
    func stopMonitoring() {
        monitor?.stop()
    }

    /// A notification of `kind` while monitoring: `timeChanged(_:port:)` through `port` when one is set.
    private func observe(_ kind: TimeChangeKind) {
        guard monitor?.isRunning == true, let port else { return }
        timeChanged(kind, port: port)
    }

    // MARK: Render scene

    /// Starts the monitor, then makes and compiles the theme's scene with the host's registry (again after a
    /// recreation); a shader error throws ``NoiseGradientShaderError``.
    func setup(_ context: RenderContext) throws {
        startMonitoring()
        scene = nil
        let made = NoiseGradientTheme.makeScene()
        try made.setup(context)
        if let message = made.errorMessage {
            made.teardown(context)
            throw NoiseGradientShaderError(message: message)
        }
        scene = made
    }

    /// Passes the new drawable size to the scene.
    func resize(_ context: RenderContext) {
        scene?.resize(context)
    }

    /// Sets the uniforms of `tier` and the effective time from `core` and `frame`, and draws the theme once.
    func draw(_ core: AmbientCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        lastDrawCount = 0
        guard let scene else { return }
        let time = NoiseGradientTheme.effectiveTime(frameTime: frame.time, speed: core.speed, motion: core.motion,
                                                    reduceMotion: reduceMotion)
        scene.resize(context)
        scene.parameters = NoiseGradientTheme.parameters(tier: tier)
        scene.palette = NoiseGradientTheme.palette
        scene.fixedTime = time
        try scene.render(context, frame: frame)
        lastUniformTime = time
        lastOctaves = AmbientCore.octaves(forTier: tier)
        lastDrawCount = 1
    }

    /// Releases the scene and stops the monitor.
    func teardown(_ context: RenderContext) {
        stopMonitoring()
        scene?.teardown(context)
        scene = nil
        lastDrawCount = 0
    }

    // MARK: Words, probes and views

    /// Brings the display and the mirror up to `core`: a new core instant (other than 0) is shown, and the core's
    /// format becomes the display's preferences.
    func follow(_ core: AmbientCore) {
        if followedInstant != core.instant {
            followedInstant = core.instant
            if let date = core.date, display.now != date { display.apply(.timeSet(date)) }
        }
        let preferences = core.preferences
        if display.preferences != preferences { display.apply(.prefsSet(preferences)) }
        if mirror.hourCycle != core.hourCycle { mirror.hourCycle = core.hourCycle }
        if mirror.showSeconds != core.showSeconds { mirror.showSeconds = core.showSeconds }
        if mirror.showDate != core.showDate { mirror.showDate = core.showDate }
        if mirror.motion != core.motion { mirror.motion = core.motion }
        if mirror.speed != core.speed { mirror.speed = core.speed }
    }

    /// The canvas label: the display's spoken string (time, and the date when shown), or "Ambient Clock" before the
    /// first instant. Nothing is announced.
    func describe(_ core: AmbientCore) -> String {
        follow(core)
        return display.display?.spoken ?? Self.fallbackDescription
    }

    /// One probe at the canvas centre, expected `dark` (every palette blend is dark).
    func probes(_ core: AmbientCore) -> [FrameProbe] {
        [FrameProbe(name: "background", x: 0.5, y: 0.5, expected: FrameColorClass.dark.rawValue)].compactMap { $0 }
    }

    /// The clock's time and date over the canvas (``ClockOverlay``); the host draws it with hit testing off and hidden
    /// from assistive technology. Adopts `port` for the monitor when none is set.
    func makeCanvasOverlay(_ port: ExperienceActionPort) -> AnyView? {
        if self.port == nil { self.port = port }
        return AnyView(ClockOverlay(presenter: self, mirror: mirror, port: port))
    }

    /// The native controls (``AmbientControls``), sending through `port`; adopts `port` for the monitor when none is
    /// set.
    func makeControls(_ port: ExperienceActionPort) -> AnyView {
        if self.port == nil { self.port = port }
        return AnyView(AmbientControls(port: port, mirror: mirror, presenter: self))
    }

    /// The actions of the native controls: the format, motion and speed (`time.set` and `time.changed` are sent by
    /// the presenter itself).
    var nativeActions: Set<String> { ["clock.format", "theme.motion", "theme.speed"] }
}
