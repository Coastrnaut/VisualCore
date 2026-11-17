// AmbientPresenter — feature 132 T-A18-203 (FR-A18-202–207; G-OVERLAY/G-BUDGETS; clarifications Q1–Q5; contracts/
// experience.md); feature 133 (A18-P03) T-A18-304, T-A18-306 (FR-A18-301, FR-A18-303, FR-A18-304, FR-A18-306;
// G-THEMES/G-TRANSITION/G-FAVOURITES; clarifications Q1, Q2, Q4). Draws Ambient Clock through the host only and owns
// its presentation state:
//
//   - Background: four theme scenes (`ThemeShaders.makeScene(themeIndex:)`, a `FullScreenShaderScene` each), made
//     lazily, drawn through one VisualCore `CrossfadeScene`, which owns their lifecycle while it holds them: it sets
//     up, resizes and tears down its children, and `replaceIncoming(_:context:)` sets up the new theme and tears down
//     the one it drops. The crossfade is made in `setup` with the shown theme as both children at progress 1 (so it
//     is remade after a context recreation) and released in `teardown`. A compile or link error of the noise
//     gradient at setup throws `NoiseGradientShaderError`, which fails the session's setup with its message; another
//     theme failing at setup falls back to the noise gradient.
//   - Theme change: `draw` compares the core's theme and palette with the shown ones. The first frame after `setup`
//     cuts to the core's choice; afterwards, under Reduce Motion (`transitionDuration(1.2, reduceMotion:)` is 0) the
//     change is a cut (progress 1 on that frame), else a fade of 1.2 s eased with smoothstep over the frame time from
//     the frame that saw the change. A change during a fade restarts it from the picture shown (the crossfade
//     captures it). Before a new theme is handed to the crossfade it is compiled once on its own and torn down
//     again; a theme whose fragment fails keeps the previous theme drawn, records `lastThemeError` and is not tried
//     again until the core asks for another choice (the time and its overlay are untouched). `failNextThemeCompile`
//     (a test-only seam) makes the next theme change compile a broken fragment.
//   - Draw: the incoming theme's uniforms come from the core and the frame (its count at the tier,
//     `ThemeCatalog.budget(theme:tier:)`; the pixel block of the tier; its palette from `ThemeCatalog`; the effective
//     time: 0 with motion off or Reduce Motion on, else frame time × speed); one draw outside a fade, three during
//     one (the still outgoing picture, the incoming theme and the mix).
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
//
// Feature 134 (A18-P04) T-A18-404/406 (FR-A18-401–409; G-NIGHT/G-MOTION/G-FRAMERATE/G-SCREENCARE/G-AWAKE;
// clarifications Q1–Q5; contracts/power.md):
//
//   - Frame cap: `maxFramesPerSecond` is 30 at all times (the session passes it to its render host; `FramePacing`
//     keeps its floor of 30 and its reductions for heat and for the system power-saving mode).
//   - Night: the core's `nightPolicy` (followed in `follow(_:)` and each `draw`) decides `isNightShown` from the
//     local minute of the clock source's instant in the display environment's calendar
//     (`NightPolicy.localMinute(of:calendar:)`). At night the scene's `u_night` is (night dim × idle dim, the warm
//     tint) and the overlay's text is `NightPolicy.textColor`; by day `u_night` is (idle dim, 1, 1, 1).
//   - Reduced motion: the system setting (`reduceMotion`, at creation) or the core's in-app `reduceMotion`
//     (`effectiveReduceMotion`): the themes are stills, a theme change is a cut and the drift is zero.
//   - Screen care: `currentDrift` is `ScreenCare.drift(at:reduceMotion:)` of the clock's instant (points); the overlay
//     and the scene both move by `shownDrift`, the drift rounded to `driftStep` (0.5 point), so the overlay is redrawn
//     only every few seconds. The scene's shift is that offset × `displayScale` in pixels, its y flipped (OpenGL's y
//     points up). `currentDim` is `ScreenCare.dimFactor(now:lastAction:)` of the clock's instant and
//     `lastActionInstant`, which starts at the clock's instant when the presenter is made and set up, and is renewed
//     by `noteAction()` — called by the controls' and the favourites' sends only (the ticks' `time.set` and
//     `time.changed` are not a person's action).
//   - Keep-awake: a `KeepAwakeController` over the injected `IdleTimerPort` (by default `ApplicationIdleTimer`) holds
//     the screen on while the core's `keepAwake` is on and the clock is visible: visible from `setup` and
//     `didBecomeActive`, hidden at `willResignActive`, `didEnterBackground` and `teardown`. The three notifications are
//     observed on the injected centre between `setup` and `teardown`, next to the time-change monitor. The device
//     brightness is never written.
//
// Feature 135 (A18-P05) T-A18-503 (FR-A18-501, FR-A18-502; SC-A18-501, SC-A18-502; clarifications Q1, Q2;
// contracts/qa.md "Presenter"):
//
//   - Still work: the crossfade is the child of a VisualCoreRendering `CachedScene` (`cache`), which owns it while it
//     is set up: `setup`, `resize` and `teardown` go to the cache, which forwards them to the crossfade (and through
//     it to the themes); `replaceIncoming` is still called on the crossfade itself. The picture is still (`isStill`)
//     when nothing moves (motion off, the in-app reduction or the system's Reduce Motion), the seconds are off and no
//     fade runs; then the cache is not pass-through and its key is `stillKey`, a deterministic FNV-1a mix of
//     everything the theme's picture depends on (theme, palette, tier, night dim and tint, the shown drift step, the
//     idle dim, the display scale, the uniform time and the drawable size). Each frame still sets the uniforms; the
//     theme draws again only when the key changes, otherwise the cached picture is copied. While anything moves the
//     cache is pass-through and the theme draws every frame, as before. `backgroundDrawCount` is the theme's draws.
//
// Feature 136 (A18-P06) T-A18-604 (FR-A18-603; SC-A18-602; clarification Q4): the test-only seam `failNextDraw` makes
// the next `draw` throw `AmbientDrawError.injected` once, before anything is followed, set or drawn; the seam clears
// itself and is unreachable from the interface. The session then fails with the error's message, and the favourites
// file is not touched (only a save or a removal writes it).
import AmbientClockCore
import Foundation
import Observation
import SwiftUI
import UIKit
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreSimulation

/// Why a draw of Ambient Clock failed on purpose (feature 136, A18-P06, T-A18-604).
enum AmbientDrawError: Error, Equatable, CustomStringConvertible {
    /// The test-only seam ``AmbientPresenter/failNextDraw`` made this draw fail.
    case injected

    /// The message the failed session shows: "The Ambient Clock draw failed: the test seam injected a failure."
    var description: String {
        switch self {
        case .injected:
            return "The Ambient Clock draw failed: the test seam injected a failure."
        }
    }
}

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
    /// The theme's index (0–3).
    var theme = 0
    /// The palette's index (0–2).
    var palette = 0
    /// Night mode: 0 off, 1 on, 2 scheduled.
    var nightMode = 0
    /// The scheduled window's start, minutes of the local day.
    var nightStart = NightPolicy.defaultStart
    /// The scheduled window's end, minutes of the local day.
    var nightEnd = NightPolicy.defaultEnd
    /// The dim factor of the scene at night.
    var nightDim = NightPolicy.defaultDim
    /// Whether the in-app reduced motion is on.
    var reduceMotion = false
    /// Whether the screen is kept on while the clock is shown.
    var keepAwake = false
    /// Whether night is shown now (the overlay's text is then `NightPolicy.textColor`).
    var isNight = false
    /// The drift offset the overlay is moved by, points (x right, y down), rounded to `AmbientPresenter.driftStep`.
    var drift = SIMD2<Double>.zero
    /// The idle dim factor the overlay's opacity is multiplied by (1, or 0.6 when idle).
    var dim = 1.0
}

/// Draws Ambient Clock and owns its presentation state (see the file header).
@MainActor
final class AmbientPresenter: ExperiencePresenter {
    /// The pure core this presenter draws.
    typealias Core = AmbientCore
    /// Supplies the system's locale and time zone at the moment of an event.
    typealias Environment = @Sendable () -> (Locale, TimeZone)

    /// The length of a theme crossfade, seconds (0 under Reduce Motion, `transitionDuration`).
    static let fadeDuration = 1.2
    /// The step the shown drift is rounded to, points (so the overlay moves at most every few seconds).
    static let driftStep = 0.5
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
    /// The saved favourites (`favourites.json` in the experience's storage), set by the factory; nil only for a
    /// presenter made without storage (tests).
    var favourites: AmbientFavourites?
    /// The crossfade drawing the themes; made in `setup`, released in `teardown`.
    private(set) var crossfade: CrossfadeScene?
    /// The scene drawn inside the cache (the crossfade); nil before `setup` and after `teardown`.
    var scene: CrossfadeScene? { crossfade }
    /// The cache around the crossfade (its owner while set up); made in `setup`, released in `teardown`.
    private(set) var cache: CachedScene?
    /// The theme scenes made so far, by theme index (lazily; their GPU objects are the crossfade's to manage).
    private var themeScenes: [Int: FullScreenShaderScene] = [:]
    /// The theme drawn (the incoming one during a fade).
    private(set) var shownTheme = 0
    /// The palette drawn (the incoming one during a fade).
    private(set) var shownPalette = 0
    /// The frame time at which the running fade started; nil when no fade runs.
    private(set) var fadeStart: Double?
    /// The choice whose theme failed to compile; not tried again until the core asks for another choice.
    private var refusedChoice: ThemeChoice?
    /// Whether the next frame cuts to the core's choice (the first frame after `setup`).
    private var cutNextChange = true
    /// The last theme compile failure (`ThemeShaderError.description`); nil after a theme was shown successfully.
    private(set) var lastThemeError: String?
    /// Test-only seam: when true, the next theme change compiles a broken fragment (and fails); reset by that change.
    var failNextThemeCompile = false
    /// Test-only seam: when true, the next `draw` throws ``AmbientDrawError/injected`` once, before it follows, sets
    /// or draws anything; the seam clears itself and nothing in the experience or its interface sets it (feature 136,
    /// A18-P06, T-A18-604).
    var failNextDraw = false
    /// The last core instant `describe` followed; nil before the first.
    private var followedInstant: Double?
    /// The number of full-screen draws of the last frame (1 when drawn, 0 otherwise); a cached still frame counts its
    /// copy as its one draw (the theme's own draws are `backgroundDrawCount`).
    private(set) var lastDrawCount = 0
    /// The uniform time of the last frame.
    private(set) var lastUniformTime = 0.0
    /// The element count of the shown theme at the last frame's tier (octaves, cells, waves or shapes).
    private(set) var lastCount = 0
    /// The A18-P02 name of `lastCount` (for the noise gradient, its octaves).
    var lastOctaves: Int { lastCount }
    /// The number of draws of the last frame (`lastDrawCount`): 1 outside a fade (the theme, or the cached picture's
    /// copy while still), 3 during one, 0 when not drawn.
    var drawCount: Int { lastDrawCount }
    /// How many times the background (the crossfade and its themes) has drawn through the cache since `setup`: one per
    /// frame while moving, one per still picture while still (`CachedScene.childDrawCount`); 0 without a cache.
    var backgroundDrawCount: Int { cache?.childDrawCount ?? 0 }
    /// Whether the core's motion is on (the core of the last frame drawn or followed).
    private(set) var coreMotion = true
    /// Whether the core shows the seconds (the core of the last frame drawn or followed).
    private(set) var coreShowSeconds = false
    /// The quality tier of the last frame drawn.
    private(set) var drawnTier = 0
    /// The drawable size of the last frame drawn, pixels.
    private(set) var drawnPixelSize = (width: 0, height: 0)
    /// The uniform time of the frame being drawn (0 while nothing moves).
    private var drawnUniformTime = 0.0
    /// How far the crossfade is (0…1); 1 when no crossfade exists.
    var fadeProgress: Double { crossfade?.progress ?? 1 }
    /// How many time-change events reached the presenter.
    private(set) var timeChangeCount = 0
    /// The frame cap: 30 frames per second at all times (clarification Q1).
    var maxFramesPerSecond: Int { 30 }
    /// The night policy of the last core followed or drawn.
    private(set) var nightPolicy = NightPolicy()
    /// The in-app reduced motion of the last core followed or drawn.
    private(set) var inAppReduceMotion = false
    /// The keep-awake setting of the last core followed or drawn.
    private(set) var keepAwakeSetting = false
    /// The instant of the last action of a person (seconds since 1970, from the clock source): the presenter's
    /// creation, its `setup` and each `noteAction()`.
    private(set) var lastActionInstant: Double
    /// The points-to-pixels factor of the canvas (the overlay sets it from its environment's display scale; 1 until
    /// then).
    var displayScale = 1.0
    /// The port that keeps the screen awake.
    let idleTimer: any IdleTimerPort
    /// Holds the screen awake while `keepAwakeSetting` is on and the clock is visible.
    let keepAwake: KeepAwakeController
    /// Whether the clock is visible: true from `setup` and `didBecomeActive`, false at `willResignActive`,
    /// `didEnterBackground` and `teardown` (and before the first `setup`).
    private(set) var isVisible = false
    /// The visibility observers on `center`; registered between `setup` and `teardown`.
    private var visibilityObservers: [any NSObjectProtocol] = []
    /// The screen uniforms of the last frame drawn (`u_night` and `u_drift`).
    private(set) var lastScreenUniforms = ThemeShaders.ScreenUniforms.day

    /// A presenter reading the time from `clock`, the system locale and zone from `environment`, observing the
    /// time-change and visibility notifications on `center`; with `reduceMotion` on the background never moves;
    /// keep-awake writes `idleTimer` (by default the application's idle timer).
    init(clock: any ClockSource = SystemClock(),
         environment: @escaping Environment = AmbientPresenter.systemEnvironment,
         center: NotificationCenter = .default, reduceMotion: Bool = false,
         idleTimer: any IdleTimerPort = ApplicationIdleTimer()) {
        self.clock = clock
        self.environment = environment
        self.center = center
        self.reduceMotion = reduceMotion
        self.idleTimer = idleTimer
        keepAwake = KeepAwakeController(port: idleTimer)
        lastActionInstant = clock.now.timeIntervalSince1970
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
        refreshScreenState()
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

    // MARK: Night, motion and screen care

    /// Whether reduced motion applies: the system setting at creation or the in-app setting of the last core.
    var effectiveReduceMotion: Bool { reduceMotion || inAppReduceMotion }

    /// Whether night is shown now: the night policy at the local minute of the clock source's instant in the display
    /// environment's calendar.
    var isNightShown: Bool {
        nightPolicy.isNight(localMinute: NightPolicy.localMinute(of: clock.now, calendar: display.environment.calendar))
    }

    /// The screen-care drift now, points (x right, y down): `ScreenCare.drift(at:reduceMotion:)` of the clock
    /// source's instant, zero under reduced motion.
    var currentDrift: SIMD2<Double> {
        ScreenCare.drift(at: clock.now.timeIntervalSince1970, reduceMotion: effectiveReduceMotion)
    }

    /// The drift the overlay and the scene are moved by: `currentDrift` rounded to `driftStep`.
    var shownDrift: SIMD2<Double> {
        let drift = currentDrift
        return SIMD2((drift.x / Self.driftStep).rounded() * Self.driftStep,
                     (drift.y / Self.driftStep).rounded() * Self.driftStep)
    }

    /// The idle dim factor now: `ScreenCare.dimFactor(now:lastAction:)` of the clock source's instant and
    /// `lastActionInstant` (1, or 0.6 after 600 s without an action).
    var currentDim: Double {
        ScreenCare.dimFactor(now: clock.now.timeIntervalSince1970, lastAction: lastActionInstant)
    }

    /// The scene's night and drift uniforms now: (night dim × idle dim, tint) at night, (idle dim, 1, 1, 1) by day;
    /// the drift is `shownDrift` × `displayScale` in pixels with y flipped.
    var screenUniforms: ThemeShaders.ScreenUniforms {
        let night = isNightShown
        let scale = displayScale.isFinite && displayScale > 0 ? displayScale : 1
        let drift = shownDrift
        return ThemeShaders.ScreenUniforms(dim: (night ? nightPolicy.dim : 1) * currentDim,
                                           tint: night ? NightPolicy.tint : SIMD3(1, 1, 1),
                                           drift: SIMD2(drift.x * scale, -drift.y * scale))
    }

    /// A person acted (a control or a favourite sent an action): the last-action instant becomes the clock source's
    /// instant, which ends the idle dim.
    func noteAction() {
        lastActionInstant = clock.now.timeIntervalSince1970
        refreshScreenState()
    }

    /// Adopts the night policy, the in-app reduced motion, the motion and seconds settings and the keep-awake setting
    /// of `core`; keep-awake is updated when its setting changes.
    private func adoptScreenSettings(_ core: AmbientCore) {
        let policy = core.nightPolicy
        if nightPolicy != policy { nightPolicy = policy }
        if inAppReduceMotion != core.reduceMotion { inAppReduceMotion = core.reduceMotion }
        if coreMotion != core.motion { coreMotion = core.motion }
        if coreShowSeconds != core.showSeconds { coreShowSeconds = core.showSeconds }
        if keepAwakeSetting != core.keepAwake {
            keepAwakeSetting = core.keepAwake
            keepAwake.update(setting: keepAwakeSetting, visible: isVisible)
        }
    }

    /// Brings the mirror's night, drift and dim up to now (each written only when it changes).
    private func refreshScreenState() {
        let night = isNightShown, drift = shownDrift, dim = currentDim
        if mirror.isNight != night { mirror.isNight = night }
        if mirror.drift != drift { mirror.drift = drift }
        if mirror.dim != dim { mirror.dim = dim }
    }

    // MARK: Still work

    /// Whether the background's picture is still: no motion (the core's motion off, the in-app reduction or the
    /// system's Reduce Motion), the seconds off and no fade running (`fadeProgress` 1).
    var isStill: Bool {
        (effectiveReduceMotion || !coreMotion) && !coreShowSeconds && fadeProgress >= 1
    }

    /// The identity of the still picture: an FNV-1a mix (64-bit, deterministic across runs) of the shown theme and
    /// palette, the tier and size of the last frame drawn, whether night is shown with the night dim and tint, the
    /// shown drift step, the idle dim, the display scale and the uniform time. It changes whenever the theme's
    /// picture would.
    var stillKey: Int {
        let night = isNightShown
        let tint = night ? NightPolicy.tint : SIMD3(1, 1, 1)
        let drift = shownDrift
        var mix = StillKeyMix()
        mix.add(shownTheme)
        mix.add(shownPalette)
        mix.add(drawnTier)
        mix.add(night ? 1 : 0)
        mix.add(night ? nightPolicy.dim : 1)
        mix.add(tint.x)
        mix.add(tint.y)
        mix.add(tint.z)
        mix.add(drift.x)
        mix.add(drift.y)
        mix.add(currentDim)
        mix.add(displayScale)
        mix.add(drawnUniformTime)
        mix.add(drawnPixelSize.width)
        mix.add(drawnPixelSize.height)
        return mix.value
    }

    /// A 64-bit FNV-1a mix of integers and doubles (by their bit patterns, with -0 as 0), independent of `Hasher`'s
    /// per-process seed.
    struct StillKeyMix {
        /// The running hash (FNV-1a offset basis at the start).
        private(set) var state: UInt64 = 0xcbf2_9ce4_8422_2325

        /// Mixes the eight bytes of `word`, low byte first.
        mutating func add(word: UInt64) {
            var rest = word
            for _ in 0..<8 {
                state ^= rest & 0xff
                state = state &* 0x0000_0100_0000_01b3
                rest >>= 8
            }
        }

        /// Mixes an integer.
        mutating func add(_ value: Int) { add(word: UInt64(bitPattern: Int64(value))) }

        /// Mixes a double by its bit pattern (-0 is mixed as 0).
        mutating func add(_ value: Double) { add(word: (value == 0 ? 0 : value).bitPattern) }

        /// The hash as an `Int`.
        var value: Int { Int(truncatingIfNeeded: state) }
    }

    // MARK: Visibility and keep-awake

    /// Sets whether the clock is visible and updates keep-awake.
    func setVisible(_ visible: Bool) {
        isVisible = visible
        keepAwake.update(setting: keepAwakeSetting, visible: visible)
    }

    /// Observes `didBecomeActive` (visible), `willResignActive` and `didEnterBackground` (hidden) on `center`; each
    /// is handled on the main actor — at once when posted on the main thread.
    private func startVisibilityObservers() {
        guard visibilityObservers.isEmpty else { return }
        let names: [(Notification.Name, Bool)] = [(UIApplication.didBecomeActiveNotification, true),
                                                  (UIApplication.willResignActiveNotification, false),
                                                  (UIApplication.didEnterBackgroundNotification, false)]
        for (name, visible) in names {
            let token = center.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
                if Thread.isMainThread {
                    MainActor.assumeIsolated { self?.setVisible(visible) }
                } else {
                    Task { @MainActor in self?.setVisible(visible) }
                }
            }
            visibilityObservers.append(token)
        }
    }

    /// Removes the visibility observers.
    private func stopVisibilityObservers() {
        for token in visibilityObservers { center.removeObserver(token) }
        visibilityObservers = []
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

    /// A theme and one of its palettes.
    struct ThemeChoice: Equatable {
        /// The theme's index (0–3).
        var theme: Int
        /// The palette's index (0–2).
        var palette: Int
    }

    /// The scene of theme `index` (clamped), made on first use.
    private func themeScene(_ index: Int) -> FullScreenShaderScene {
        let theme = ThemeShaders.clamped(index)
        if let made = themeScenes[theme] { return made }
        let made = ThemeShaders.makeScene(themeIndex: theme)
        themeScenes[theme] = made
        return made
    }

    /// Starts the monitor, then makes the crossfade with the shown theme as both children at progress 1 inside a new
    /// `CachedScene` and sets the cache (and through it the crossfade) up with the host's registry (again after a
    /// recreation). A shader error of the noise gradient throws
    /// ``NoiseGradientShaderError``; another theme's error falls back to the noise gradient (`lastThemeError`).
    func setup(_ context: RenderContext) throws {
        startMonitoring()
        startVisibilityObservers()
        lastActionInstant = clock.now.timeIntervalSince1970
        setVisible(true)
        refreshScreenState()
        crossfade = nil
        cache = nil
        themeScenes = [:]
        fadeStart = nil
        refusedChoice = nil
        cutNextChange = true
        var theme = shownTheme
        while true {
            let shown = themeScene(theme)
            let made = CrossfadeScene(from: shown, to: shown)
            made.progress = 1
            let wrapped = CachedScene(child: made)
            try wrapped.setup(context)
            guard let message = shown.errorMessage else {
                crossfade = made
                cache = wrapped
                if theme != shownTheme { shownPalette = 0 }
                shownTheme = theme
                return
            }
            wrapped.teardown(context)
            themeScenes[theme] = nil
            guard theme != 0 else { throw NoiseGradientShaderError(message: message) }
            lastThemeError = ThemeShaderError(theme: theme, message: message).description
            theme = 0
        }
    }

    /// Passes the new drawable size to the cache, which releases its picture and resizes the crossfade (which resizes
    /// its children and releases its targets).
    func resize(_ context: RenderContext) {
        cache?.resize(context)
    }

    /// Follows a new theme or palette of `core` (a cut or a fade), sets the incoming theme's uniforms of `tier` and
    /// the effective time from `core` and `frame`, advances the fade and draws the crossfade through the cache: in
    /// pass-through while anything moves, else keyed by `stillKey` (the theme draws only for a new still picture).
    /// Throws ``AmbientDrawError/injected`` once while ``failNextDraw`` is set (it is cleared first).
    func draw(_ core: AmbientCore, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        if failNextDraw {
            failNextDraw = false
            throw AmbientDrawError.injected
        }
        lastDrawCount = 0
        adoptScreenSettings(core)
        guard let crossfade, let cache else { return }
        let wanted = ThemeChoice(theme: core.theme, palette: core.palette)
        if wanted != ThemeChoice(theme: shownTheme, palette: shownPalette), wanted != refusedChoice {
            show(wanted, crossfade: crossfade, context: context, frame: frame, cut: cutNextChange)
        }
        cutNextChange = false
        if let start = fadeStart {
            let duration = transitionDuration(Self.fadeDuration, reduceMotion: effectiveReduceMotion)
            let linear = duration > 0 ? min(max((frame.time - start) / duration, 0), 1) : 1
            crossfade.progress = linear * linear * (3 - 2 * linear)
            if linear >= 1 { fadeStart = nil }
        }
        let time = NoiseGradientTheme.effectiveTime(frameTime: frame.time, speed: core.speed, motion: core.motion,
                                                    reduceMotion: effectiveReduceMotion)
        let screen = screenUniforms
        let incoming = themeScene(shownTheme)
        incoming.resize(context)
        incoming.parameters = ThemeShaders.parameters(theme: shownTheme, tier: tier)
            .merging(ThemeShaders.screenParameters(screen)) { _, new in new }
        incoming.palette = ThemeShaders.palette(theme: shownTheme, palette: shownPalette)
        incoming.fixedTime = time
        drawnTier = tier
        drawnPixelSize = (context.pixelWidth, context.pixelHeight)
        drawnUniformTime = time
        let still = isStill
        cache.passThrough = !still
        if still { cache.key = stillKey }
        try cache.render(context, frame: frame)
        lastUniformTime = time
        lastScreenUniforms = screen
        refreshScreenState()
        lastCount = ThemeCatalog.budget(theme: shownTheme, tier: tier)
        let progress = crossfade.progress
        lastDrawCount = progress > 0 && progress < 1 ? 3 : 1
    }

    /// Shows `choice`: a new theme is first compiled on its own (and torn down again); when it fails the previous
    /// theme stays, `lastThemeError` is set and the choice is refused until another one is asked for. Then the
    /// crossfade restarts from the picture shown towards the theme (`replaceIncoming`) and either cuts (`cut`, or
    /// Reduce Motion) or starts a fade at the frame's time.
    private func show(_ choice: ThemeChoice, crossfade: CrossfadeScene, context: RenderContext, frame: FrameInfo,
                      cut: Bool) {
        let theme = ThemeShaders.clamped(choice.theme)
        if theme != shownTheme {
            let broken = failNextThemeCompile
            failNextThemeCompile = false
            let candidate = broken ? ThemeShaders.makeScene(themeIndex: theme, broken: true) : themeScene(theme)
            if candidate !== crossfade.from, let message = compileProblem(of: candidate, context: context) {
                lastThemeError = ThemeShaderError(theme: theme, message: message).description
                refusedChoice = choice
                return
            }
        }
        do {
            try crossfade.replaceIncoming(themeScene(theme), context: context)
        } catch {
            lastThemeError = ThemeShaderError(theme: theme, message: String(describing: error)).description
            refusedChoice = choice
            return
        }
        shownTheme = theme
        shownPalette = min(max(choice.palette, 0), AmbientCore.paletteCount - 1)
        refusedChoice = nil
        lastThemeError = nil
        if cut || transitionDuration(Self.fadeDuration, reduceMotion: effectiveReduceMotion) == 0 {
            crossfade.progress = 1
            fadeStart = nil
        } else {
            crossfade.progress = 0
            fadeStart = frame.time
        }
    }

    /// Compiles `scene` on its own and tears it down again; the first diagnostic, or nil when it compiled.
    private func compileProblem(of scene: FullScreenShaderScene, context: RenderContext) -> String? {
        do {
            try scene.setup(context)
        } catch {
            scene.teardown(context)
            return String(describing: error)
        }
        let message = scene.errorMessage
        scene.teardown(context)
        return message
    }

    /// Releases the cache (and with it the crossfade and the theme scenes it holds), stops the monitor and the visibility
    /// observers and releases keep-awake (the clock is no longer visible).
    func teardown(_ context: RenderContext) {
        stopMonitoring()
        stopVisibilityObservers()
        setVisible(false)
        cache?.teardown(context)
        cache = nil
        crossfade = nil
        themeScenes = [:]
        fadeStart = nil
        lastDrawCount = 0
    }

    // MARK: Words, probes and views

    /// Brings the display and the mirror up to `core`: a new core instant (other than 0) is shown, and the core's
    /// format becomes the display's preferences; the night, motion and keep-awake settings are adopted (keep-awake
    /// follows a changed setting at once).
    func follow(_ core: AmbientCore) {
        adoptScreenSettings(core)
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
        if mirror.theme != core.theme { mirror.theme = core.theme }
        if mirror.palette != core.palette { mirror.palette = core.palette }
        if mirror.nightMode != core.nightMode { mirror.nightMode = core.nightMode }
        if mirror.nightStart != core.nightStart { mirror.nightStart = core.nightStart }
        if mirror.nightEnd != core.nightEnd { mirror.nightEnd = core.nightEnd }
        if mirror.nightDim != core.nightDim { mirror.nightDim = core.nightDim }
        if mirror.reduceMotion != core.reduceMotion { mirror.reduceMotion = core.reduceMotion }
        if mirror.keepAwake != core.keepAwake { mirror.keepAwake = core.keepAwake }
        refreshScreenState()
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
        return AnyView(AmbientControls(port: port, mirror: mirror, presenter: self, favourites: favourites))
    }

    /// The actions of the native controls: the format, motion, speed, theme, palette, night mode, window and dim,
    /// reduced motion and keep-awake (`time.set` and `time.changed` are sent by the presenter itself; a favourite
    /// sends the four theme actions).
    var nativeActions: Set<String> {
        ["clock.format", "theme.motion", "theme.speed", "theme.select", "theme.palette", "night.mode", "night.window",
         "night.dim", "motion.reduce", "screen.keepAwake"]
    }

    /// The preset of what the controls show (theme, palette, speed, motion); nil when out of range.
    var currentPreset: ThemePreset? {
        try? ThemePreset(theme: mirror.theme, palette: mirror.palette, speed: mirror.speed, motion: mirror.motion)
    }
}
