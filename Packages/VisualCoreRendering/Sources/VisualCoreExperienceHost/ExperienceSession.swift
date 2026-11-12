// ExperienceSession — feature 189 T-U03-007 (FR-U03-001 to FR-U03-006, FR-U03-010 to FR-U03-013, FR-U03-020 to
// FR-U03-023, FR-U03-030 to FR-U03-032, FR-U03-040 to FR-U03-044, FR-U03-050 to FR-U03-053, FR-U03-070,
// FR-U03-071, FR-U03-080, FR-U03-081, FR-U03-100; research R2 to R5; contract
// specs/189-ua-f03-experience-host/contracts/session-api.md). The main-actor session that opens and closes
// experiences: it builds the experience from the request's factory, owns the one render host, follows the scene
// phase, reacts to memory warnings, turns errors into a failed state and keeps the session diagnostics. Every
// state change goes through `SessionLifecycle`; every step of a close is recorded.
import Foundation
import Observation
import UIKit
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreRendering

/// The failure code of a presenter's `setup` that threw (set by the experience shell).
private let experienceSetupFailedCode = "experience.setup-failed"

/// The session's scene: it forwards every call to the experience's scene and tells the session when a frame was
/// drawn, so that the first-frame time is the time of a frame that really happened.
@MainActor
private final class SessionScene: RenderScene {
    private let inner: any RenderScene
    /// Called after each frame the experience's scene drew without an error.
    var onFrame: (@MainActor () -> Void)?
    /// How long the last set-up that ended without an error took, in seconds; nil before one ended. The set-up
    /// is where an experience compiles its shaders (feature 192, UA-F06).
    private(set) var setupSeconds: Double?
    private let clock = ContinuousClock()

    init(inner: any RenderScene) {
        self.inner = inner
    }

    func setup(_ context: RenderContext) throws {
        let start = clock.now
        try inner.setup(context)
        let elapsed = (clock.now - start).components
        setupSeconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
    }

    func resize(_ context: RenderContext) {
        inner.resize(context)
    }

    func render(_ context: RenderContext, frame: FrameInfo) throws {
        try inner.render(context, frame: frame)
        onFrame?()
    }

    func teardown(_ context: RenderContext) {
        inner.teardown(context)
    }
}

/// The one session of the app: it opens an experience, shows it on a render host it owns, and closes it again
/// with every GPU object released.
///
/// At most one experience is open; the newest `open` wins. The owner calls `close()` before it releases the
/// session: the deinitializer only removes the memory-warning observer (a render host that is still alive then
/// destroys itself when the session lets go of it).
@MainActor @Observable
public final class ExperienceSession {
    /// Receives the snapshot of the experience at every suspension and at every close.
    public typealias SnapshotSink = @MainActor (ExperienceSnapshot) throws -> Void

    /// How a preparation was ended from outside.
    private enum Overtake {
        case closed, superseded
    }

    // MARK: Published state

    /// The session's state; changed only through the session lifecycle.
    public private(set) var state: SessionState = .idle
    /// The open (or preparing) experience; nil when idle, failed or showing a message.
    public private(set) var experience: (any Experience)?
    /// The render host of the open experience; nil without one.
    public private(set) var renderHost: RenderHost?
    /// The failure the failure view shows; cleared by `back()` and by the next open.
    public private(set) var failure: SessionFailure?
    /// The text the message view shows; cleared by `back()` and by the next open.
    public private(set) var message: String?
    /// The last scene phase given to `setScenePhase(_:)`; starts active.
    public private(set) var phase: ScenePhaseInput = .active

    // MARK: Records

    /// Render hosts created by this session and not destroyed; never above 1.
    @ObservationIgnored public private(set) var hostsAlive = 0
    /// Why the snapshot of the last open was refused; nil when none was given or it was restored.
    @ObservationIgnored public private(set) var lastRestoreRefusal: ExperienceFailure?
    /// The last snapshot that could not be taken or that the sink refused; nil when that never happened.
    @ObservationIgnored public private(set) var lastSinkFailure: ExperienceFailure?

    /// The token of the memory-warning observer; removed in the deinitializer.
    @ObservationIgnored nonisolated(unsafe) var memoryObserver: (any NSObjectProtocol)?

    @ObservationIgnored private var lifecycle = SessionLifecycle()
    @ObservationIgnored private let snapshotSink: SnapshotSink?
    @ObservationIgnored private var lastRequest: ExperienceOpenRequest?
    @ObservationIgnored private var generation = 0
    /// The generation of the open whose preparation is running.
    @ObservationIgnored private var preparingGeneration: Int?
    /// How the preparations of overtaken generations were ended; an entry is removed by the open it belongs to.
    @ObservationIgnored private var overtakes: [Int: Overtake] = [:]
    @ObservationIgnored private let clock = ContinuousClock()
    /// When the experience was activated; the first-frame time counts from here.
    @ObservationIgnored private var firstFrameStart: ContinuousClock.Instant?

    @ObservationIgnored private var timings = SessionStageTimings()

    // MARK: Quality and performance (feature 192, UA-F06)

    /// The pinned quality level, or nil for automatic. A pin beyond an experience's levels means its last
    /// level. Setting it applies to an open experience at once.
    @ObservationIgnored public var qualityPin: Int? {
        didSet {
            guard qualityPin != oldValue else { return }
            governor?.setPin(qualityPin)
            applyLevelInForce()
        }
    }
    /// Where the session reads the device conditions for its automatic level; the device itself by default.
    @ObservationIgnored public var conditions: @MainActor () -> DeviceConditions = { DeviceConditions.current() }
    /// The launch time of the process, given by the app once; it becomes part of every performance record.
    @ObservationIgnored public var launch: LaunchTiming?
    /// The performance record of the last experience that was closed or whose open failed; nil before that.
    @ObservationIgnored public private(set) var lastPerformanceRecord: PerformanceRecord?

    @ObservationIgnored private var governor: QualityGovernor?
    /// The level the open experience was last set to.
    @ObservationIgnored private var appliedLevel = 0
    /// When the governor was last asked from the frame hook, in seconds of the session's clock.
    @ObservationIgnored private var lastQualityCheck: Double?
    @ObservationIgnored private let created: ContinuousClock.Instant
    /// When the current open began; the first-present time counts from here.
    @ObservationIgnored private var openStart: ContinuousClock.Instant?
    @ObservationIgnored private var meter = PacingMeter()
    /// The host time of the last presented frame; nil after a suspension, so that no interval spans it.
    @ObservationIgnored private var lastPresentTime: Double?
    @ObservationIgnored private var presentedAny = false
    /// The registry's compile count when the experience became interactive or after the last context rebuild.
    @ObservationIgnored private var compileBaseline: Int?
    /// A context was lost and the host rebuilds it: the baseline is taken again at the next drawn frame.
    @ObservationIgnored private var rebaselinePending = false
    /// Late compilations counted before the last baseline.
    @ObservationIgnored private var lateBefore = 0
    @ObservationIgnored private var rebuilds = 0
    @ObservationIgnored private var memoryEvents = 0
    @ObservationIgnored private var lastCloseCounts: GPUResourceCounts?
    @ObservationIgnored private var lastCloseSteps: [SessionCloseStep] = []
    @ObservationIgnored private var lastFailure: SessionFailure?
    @ObservationIgnored private var opens = 0
    @ObservationIgnored private var closes = 0
    @ObservationIgnored private var failures = 0
    @ObservationIgnored private var cancelledPreparations = 0
    @ObservationIgnored private var supersededOpens = 0
    @ObservationIgnored private var memoryClosures = 0
    @ObservationIgnored private var contextRecreations = 0
    @ObservationIgnored private var sinkFailures = 0

    // MARK: Creation

    /// Creates an idle session. `snapshotSink` receives the experience's snapshot at every suspension and close;
    /// the session itself stores nothing. The session listens for the system's memory warning.
    public init(snapshotSink: SnapshotSink? = nil) {
        self.snapshotSink = snapshotSink
        created = clock.now
        memoryObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleMemoryWarning()
            }
        }
    }

    deinit {
        if let memoryObserver {
            NotificationCenter.default.removeObserver(memoryObserver)
        }
    }

    // MARK: Diagnostics

    /// The readable record of the session at this moment; reading it changes nothing.
    public var diagnostics: SessionDiagnostics {
        SessionDiagnostics(state: state, experience: experience?.id,
                           experienceDiagnostics: experience?.diagnostics, timings: timings,
                           lastCloseCounts: lastCloseCounts, opens: opens, closes: closes, failures: failures,
                           cancelledPreparations: cancelledPreparations, supersededOpens: supersededOpens,
                           memoryClosures: memoryClosures, contextRecreations: contextRecreations,
                           sinkFailures: sinkFailures, rejectedTransitions: lifecycle.rejectedTransitions,
                           lastFailure: lastFailure, lastCloseSteps: lastCloseSteps)
    }

    // MARK: Open

    /// Opens the experience of `request`. What is open or preparing is closed completely first; then the
    /// experience is built, prepared, given a render host and activated (or, while the phase is not active, left
    /// ready with the host paused).
    ///
    /// Returns `.running` or `.suspended`, `.failed` with the failure the session now shows, `.superseded` when
    /// a newer open replaced this one during its preparation, or `.cancelled` when `close()` did.
    @discardableResult
    public func open(_ request: ExperienceOpenRequest) async -> SessionOpenResult {
        switch state {
        case .preparing, .running, .suspended:
            endCurrent(overtake: .superseded)
        case .idle, .failed, .message, .closing:
            break
        }
        failure = nil
        message = nil
        guard move(to: .preparing) else { return .superseded }
        generation += 1
        let mine = generation
        preparingGeneration = mine
        lastRequest = request
        lastRestoreRefusal = nil
        timings = SessionStageTimings()
        firstFrameStart = nil
        resetMeasurements()

        let experience = request.make()
        self.experience = experience
        let prepareStart = clock.now
        openStart = prepareStart
        var prepareError: ExperienceError?
        do {
            try await experience.prepare(seed: request.seed, timeLimit: request.timeLimit)
        } catch {
            prepareError = error
        }

        guard mine == generation else {
            // Overtaken: the newer open or the close owns the session's state now.
            release(experience)
            if overtakes.removeValue(forKey: mine) == .closed { return .cancelled }
            supersededOpens += 1
            return .superseded
        }
        preparingGeneration = nil
        timings.prepare = Self.seconds(clock.now - prepareStart)
        if let prepareError {
            return .failed(fail(SessionFailure(prepareError.failure, stage: .prepare)))
        }

        if let snapshot = request.snapshot {
            do {
                try experience.restore(snapshot)
            } catch {
                lastRestoreRefusal = error.failure
            }
        }

        // The level in force is applied before a render host exists, so that the first frame is drawn with it.
        var newGovernor = QualityGovernor(levelCount: experience.qualityProfile.count, pin: qualityPin)
        newGovernor.decide(conditions: conditions(), now: sessionSeconds)
        governor = newGovernor
        lastQualityCheck = sessionSeconds
        applyLevelInForce()

        let hostStart = clock.now
        let scene = SessionScene(inner: experience.scene)
        let host: RenderHost
        do {
            host = try RenderHost(scene: scene, budget: request.budget)
        } catch {
            let reason = ExperienceFailure(code: SessionFailure.hostFailedCode, message: String(describing: error))
            return .failed(fail(SessionFailure(reason, stage: .createHost)))
        }
        renderHost = host
        hostsAlive += 1
        scene.onFrame = { [weak self, weak host] in
            guard let self, let host, self.renderHost === host else { return }
            self.noteFrameDrawn()
        }
        host.addErrorObserver { [weak self, weak host] error in
            guard let self, let host, self.renderHost === host else { return }
            self.hostReported(error)
        }
        host.addPresentObserver { [weak self, weak host] frame in
            guard let self, let host, self.renderHost === host else { return }
            self.notePresented(frame, by: host)
        }
        timings.createHost = Self.seconds(clock.now - hostStart)
        if let setup = scene.setupSeconds {
            timings.setup = setup
            timings.programsCompiled = host.resources.compileCount
        }
        // A setup that threw inside the host's initializer was reported before the observer existed.
        if let failed = failIfExperienceFailed() { return .failed(failed) }

        guard phase == .active else {
            host.pause()
            move(to: .suspended)
            opens += 1
            return .suspended
        }
        let activateStart = clock.now
        do {
            try experience.activate()
        } catch {
            return .failed(fail(Self.sessionFailure(of: error.failure)))
        }
        timings.activate = Self.seconds(clock.now - activateStart)
        move(to: .running)
        opens += 1
        compileBaseline = host.resources.compileCount   // interactive from here
        firstFrameStart = clock.now
        host.renderOneFrame(present: false)
        if let failed = failIfExperienceFailed() { return .failed(failed) }
        if state == .failed, let failure { return .failed(failure) }
        return .running
    }

    /// Opens the last request again. Only a failed session retries; otherwise nothing happens and the result is
    /// `.superseded`.
    @discardableResult
    public func retry() async -> SessionOpenResult {
        guard state == .failed else { return .superseded }
        guard let lastRequest else {
            if let failure { return .failed(failure) }
            return .superseded
        }
        return await open(lastRequest)
    }

    // MARK: Close

    /// Closes what the session shows. Preparing: the preparation is cancelled. Running or suspended: the seven
    /// steps of `SessionCloseStep.order`; a leak or a sink error is recorded and the session still becomes idle.
    /// Failed or message: as `back()`. Idle or closing: nothing.
    public func close() {
        guard state != .idle, state != .closing else { return }
        generation += 1
        endCurrent(overtake: .closed)
    }

    /// Leaves the failure view or the message view: failed or message → idle. The diagnostics keep the failure.
    public func back() {
        guard state == .failed || state == .message else { return }
        failure = nil
        message = nil
        move(to: .idle)
    }

    // MARK: Phase, memory, context

    /// Takes the app's scene phase. Background or inactive while running: the experience is suspended, its
    /// snapshot goes to the sink, the host is paused. Active while suspended: the host and the experience
    /// resume (an experience that was prepared while not active is activated now). Otherwise the phase is
    /// only stored.
    public func setScenePhase(_ phase: ScenePhaseInput) {
        if self.phase != phase { self.phase = phase }
        switch (phase, state) {
        case (.inactive, .running), (.background, .running):
            if let experience {
                try? experience.suspend()
                handOutSnapshot(of: experience)
            }
            renderHost?.pause()
            lastPresentTime = nil   // the time away is neither a sample nor a missed refresh
            move(to: .suspended)
        case (.active, .suspended):
            resumeFromSuspension()
        default:
            break
        }
    }

    /// Reacts to a memory warning: the open experience sheds its caches; when the live bytes of the host's
    /// registry are then still above the memory-pressure limit, the experience is closed completely (with a
    /// snapshot to the sink) and the session shows the memory message.
    public func handleMemoryWarning() {
        guard state == .running || state == .suspended, let experience, let host = renderHost,
              let request = lastRequest else { return }
        let experienceState = experience.state
        guard experienceState == .ready || experienceState == .active || experienceState == .suspended else {
            return
        }
        memoryEvents += 1
        try? experience.shedCaches()
        let limit = MemoryPressureRule.limit(requested: request.memoryPressureLimit,
                                             budgetTotal: request.budget.total)
        guard MemoryPressureRule.shouldClose(liveBytes: host.resources.stats.totalBytes, limit: limit) else {
            return
        }
        message = SessionStrings.text(.memoryMessage)
        fullClose(endingIn: .message)
        memoryClosures += 1
    }

    /// Forces a context recreation of the open host (tests, recovery). When the host then has no usable
    /// context, the session fails with `session.context-lost`.
    public func recreateContext() {
        guard let host = renderHost else { return }
        closeCompileBaseline(of: host)
        host.recreateContext()
        contextRecreations += 1
        rebuilds += 1
        guard renderHost === host else { return }   // the error observer already failed the session
        if compileBaseline != nil { compileBaseline = host.resources.compileCount }
        if case .unsupported(let text) = host.lastError {
            fail(Self.contextLost(text))
        } else if host.state == .destroyed {
            fail(Self.contextLost("the render host was destroyed"))
        }
    }

    // MARK: Quality and performance

    /// The quality level the open experience is set to; 0 without one.
    public var qualityLevel: Int { experience == nil ? 0 : appliedLevel }

    /// Takes a quality decision now, from the current conditions, and applies a changed level. `now` is a time
    /// in seconds on any steady scale (tests script it); by default the session's own clock. Nothing happens
    /// unless an experience runs.
    public func refreshQuality(now: Double? = nil) {
        guard state == .running, governor != nil else { return }
        let time = now ?? sessionSeconds
        lastQualityCheck = time
        governor?.decide(conditions: conditions(), now: time)
        applyLevelInForce()
    }

    /// The performance record of the open experience at this moment; nil without one. Reading it changes
    /// nothing in the experience.
    public var performanceRecord: PerformanceRecord? {
        guard let experience, state == .running || state == .suspended else { return nil }
        return makeRecord(of: experience)
    }

    /// Seconds since the session was created, on its steady clock.
    private var sessionSeconds: Double { Self.seconds(clock.now - created) }

    /// Sets the experience to the governor's level in force when it differs from the level it has.
    private func applyLevelInForce() {
        guard let governor, let experience else { return }
        let state = experience.state
        guard state == .ready || state == .active || state == .suspended else { return }
        let level = governor.levelInForce
        guard level != appliedLevel else { return }
        do {
            try experience.setQualityTier(level)
            appliedLevel = level
        } catch {
            // An experience whose logic declares fewer tiers than its profile keeps the level it has.
        }
    }

    /// Forgets the measurements of the open before; called when a new open begins.
    private func resetMeasurements() {
        governor = nil
        appliedLevel = 0
        lastQualityCheck = nil
        openStart = nil
        meter = PacingMeter()
        lastPresentTime = nil
        presentedAny = false
        compileBaseline = nil
        rebaselinePending = false
        lateBefore = 0
        rebuilds = 0
        memoryEvents = 0
    }

    /// Adds the compilations since the baseline to the late ones; called before a context is rebuilt.
    private func closeCompileBaseline(of host: RenderHost) {
        guard let baseline = compileBaseline else { return }
        lateBefore += max(0, host.resources.compileCount - baseline)
        compileBaseline = host.resources.compileCount
    }

    /// Shader programs compiled after the experience became interactive, rebuilds after a lost context excluded.
    private var lateCompilations: Int {
        guard let baseline = compileBaseline, let host = renderHost, !rebaselinePending else { return lateBefore }
        return lateBefore + max(0, host.resources.compileCount - baseline)
    }

    /// Assembles the performance record of `experience` from what was measured so far.
    private func makeRecord(of experience: any Experience) -> PerformanceRecord {
        let device = conditions()
        let stats: ResourceLedger.Snapshot? = renderHost?.resources.stats
        let pacing = renderHost?.framePacing
        var record = PerformanceRecord(
            experience: experience.id.rawValue, presented: presentedAny, qualityLevel: appliedLevel,
            qualityPinned: qualityPin != nil, qualityLevels: experience.qualityProfile.count,
            stepsDown: governor?.stepsDown ?? 0, stepsUp: governor?.stepsUp ?? 0, thermal: device.thermal,
            lowPower: device.lowPower, frameCapFPS: pacing?.maxFPS ?? 0, renderScale: pacing?.renderScale ?? 1,
            pacing: meter.summary, gpuBytes: stats?.totalBytes ?? 0, gpuPeakBytes: stats?.peakBytes ?? 0,
            lateCompilations: lateCompilations, rebuilds: rebuilds, memoryEvents: memoryEvents)
        record.launchMs = launch?.milliseconds
        record.firstLaunch = launch?.firstLaunch
        record.prepareMs = timings.prepare.map { $0 * 1_000 }
        record.setupMs = timings.setup.map { $0 * 1_000 }
        record.firstPresentMs = timings.firstPresent.map { $0 * 1_000 }
        record.programsCompiled = timings.programsCompiled
        record.memoryFootprintBytes = ProcessMemory.footprint()
        return record
    }

    // MARK: Internals: state

    /// The one place that changes the state: through the lifecycle, then published.
    @discardableResult
    private func move(to next: SessionState) -> Bool {
        let accepted = lifecycle.transition(to: next)
        if state != lifecycle.state { state = lifecycle.state }
        return accepted
    }

    /// Ends what the session shows, for `close()` and for an open that replaces it.
    private func endCurrent(overtake: Overtake) {
        switch state {
        case .idle, .closing:
            break
        case .preparing:
            if let preparingGeneration { overtakes[preparingGeneration] = overtake }
            preparingGeneration = nil
            lastCloseSteps = []
            move(to: .closing)
            for step in SessionCloseStep.cancelOrder {
                switch step {
                case .cancelPreparation:
                    experience?.cancelPreparation()
                    cancelledPreparations += 1
                case .becomeIdle:
                    experience = nil
                    move(to: .idle)
                default:
                    break
                }
                lastCloseSteps.append(step)
            }
        case .running, .suspended:
            fullClose(endingIn: .idle)
        case .failed, .message:
            back()
        }
    }

    /// The full close of a running or suspended experience, in the order of `SessionCloseStep.order`. `end` is
    /// idle, or message for a close under memory pressure.
    private func fullClose(endingIn end: SessionState) {
        lastCloseSteps = []
        guard move(to: .closing) else { return }
        let experience = self.experience
        var registry: ResourceRegistry?
        var closeFailure: SessionFailure?
        for step in SessionCloseStep.order {
            switch step {
            case .stopClock:
                renderHost?.pause()
                if let experience, experience.state == .active { try? experience.suspend() }
                if let experience { lastPerformanceRecord = makeRecord(of: experience) }
            case .handOutSnapshot:
                if let experience { handOutSnapshot(of: experience) }
            case .beginDeactivation:
                do {
                    try experience?.beginDeactivation()
                } catch {
                    closeFailure = SessionFailure(error.failure, stage: .close)
                }
            case .destroyHost:
                registry = destroyHost()
            case .readCounts:
                readCounts(of: registry)
            case .finishDeactivation:
                do {
                    try experience?.finishDeactivation()
                } catch {
                    closeFailure = SessionFailure(error.failure, stage: .close)
                }
            case .becomeIdle:
                self.experience = nil
                firstFrameStart = nil
                governor = nil
                move(to: end)
            case .cancelPreparation:
                break
            }
            lastCloseSteps.append(step)
        }
        closes += 1
        if let closeFailure {
            lastFailure = closeFailure
            failures += 1
        }
    }

    /// Records `failure`, destroys the host when one exists (reading the counts), lets the experience end its
    /// deactivation quietly and enters the failed state. Legal from preparing, running and suspended.
    @discardableResult
    private func fail(_ failure: SessionFailure) -> SessionFailure {
        guard state == .preparing || state == .running || state == .suspended else { return failure }
        self.failure = failure
        lastFailure = failure
        failures += 1
        preparingGeneration = nil
        firstFrameStart = nil
        let experience = self.experience
        if let experience { lastPerformanceRecord = makeRecord(of: experience) }
        governor = nil
        readCounts(of: destroyHost())
        if let experience { release(experience) }
        self.experience = nil
        move(to: .failed)
        return failure
    }

    /// Fails the session when the open experience is in its failed state; returns the failure then.
    private func failIfExperienceFailed() -> SessionFailure? {
        guard let experience, experience.state == .failed else { return nil }
        return fail(Self.sessionFailure(of: Self.lastError(of: experience)))
    }

    // MARK: Internals: host

    /// An error of the session's host: a failed experience (setup or drawing threw) fails the session with the
    /// experience's error; an unrecoverable context fails it with `session.context-lost`.
    private func hostReported(_ error: RenderHostError) {
        if failIfExperienceFailed() != nil { return }
        switch error {
        case .unsupported(let text):
            fail(Self.contextLost(text))
        case .contextLost:
            contextRecreations += 1   // the host recreates its context itself after this report
            rebuilds += 1
            if let host = renderHost { closeCompileBaseline(of: host) }
            rebaselinePending = compileBaseline != nil
        case .allocation, .scene:
            break
        }
    }

    /// A frame of the experience was drawn: the first one while running sets the first-frame time.
    private func noteFrameDrawn() {
        guard state == .running else { return }
        if timings.firstFrame == nil, let firstFrameStart {
            timings.firstFrame = Self.seconds(clock.now - firstFrameStart)
        }
        if rebaselinePending, let host = renderHost {
            rebaselinePending = false
            compileBaseline = host.resources.compileCount
        }
        let now = sessionSeconds
        if let last = lastQualityCheck, now - last < QualityGovernor.minimumInterval { return }
        refreshQuality(now: now)
    }

    /// A frame reached the display: the first one ends the first-present time; every later one gives the
    /// pacing meter the interval since the frame before it.
    private func notePresented(_ frame: PresentedFrame, by host: RenderHost) {
        guard state == .running else { return }
        presentedAny = true
        if timings.firstPresent == nil, let openStart {
            timings.firstPresent = Self.seconds(clock.now - openStart)
        }
        if let last = lastPresentTime {
            meter.record(interval: frame.time - last, period: 1.0 / Double(max(host.framePacing.maxFPS, 1)))
        }
        lastPresentTime = frame.time
    }

    /// Destroys the host, when there is one, and returns its registry for the counts.
    private func destroyHost() -> ResourceRegistry? {
        guard let host = renderHost else { return nil }
        renderHost = nil   // first, so that the error observer ignores what the teardown reports
        host.destroy()
        hostsAlive -= 1
        return host.resources
    }

    /// Reads the counts of a destroyed host's registry into the record of the last close.
    private func readCounts(of registry: ResourceRegistry?) {
        guard let registry else { return }
        let stats: ResourceLedger.Snapshot = registry.stats
        lastCloseCounts = GPUResourceCounts(objects: stats.liveCount.values.reduce(0, +), bytes: stats.totalBytes,
                                            leaked: stats.leaked)
    }

    // MARK: Internals: experience

    /// Active while suspended: the host resumes, then the experience resumes, or is activated when it was
    /// prepared while the phase was not active.
    private func resumeFromSuspension() {
        guard let experience, let host = renderHost else { return }
        host.resume()
        guard renderHost === host else { return }
        let firstActivation = experience.state == .ready
        let start = clock.now
        do {
            if firstActivation {
                try experience.activate()
            } else {
                try experience.resume()
            }
        } catch {
            fail(Self.sessionFailure(of: error.failure))
            return
        }
        move(to: .running)
        governor?.resume()
        lastQualityCheck = nil
        guard firstActivation else { return }
        timings.activate = Self.seconds(clock.now - start)
        compileBaseline = host.resources.compileCount   // interactive from here
        firstFrameStart = clock.now
        host.renderOneFrame(present: false)
        _ = failIfExperienceFailed()
    }

    /// Takes the experience's snapshot and gives it to the sink. A snapshot that cannot be taken and a sink
    /// that throws are counted and recorded; neither stops the caller.
    private func handOutSnapshot(of experience: any Experience) {
        guard let snapshotSink else { return }
        let snapshot: ExperienceSnapshot
        do {
            snapshot = try experience.snapshot()
        } catch {
            sinkFailures += 1
            lastSinkFailure = error.failure
            return
        }
        do {
            try snapshotSink(snapshot)
        } catch {
            sinkFailures += 1
            lastSinkFailure = ExperienceFailure(code: SessionFailure.sinkFailedCode,
                                                message: String(describing: error))
        }
    }

    /// Lets an experience the session no longer shows end its deactivation; errors are not of interest here.
    private func release(_ experience: any Experience) {
        let experienceState = experience.state
        guard experienceState != .inactive, experienceState != .registered else { return }
        try? experience.beginDeactivation()
        try? experience.finishDeactivation()
    }

    // MARK: Internals: values

    /// The last error of a failed experience; a stated placeholder when it recorded none.
    private static func lastError(of experience: any Experience) -> ExperienceFailure {
        experience.diagnostics.lastError
            ?? ExperienceFailure(code: ExperienceFailure.unspecifiedCode,
                                 message: "the experience failed without a recorded error")
    }

    /// An experience's failure with its stage: setup for `experience.setup-failed`, drawing otherwise.
    private static func sessionFailure(of failure: ExperienceFailure) -> SessionFailure {
        SessionFailure(failure, stage: failure.code == experienceSetupFailedCode ? .setup : .draw)
    }

    /// The failure of a context that could not be recreated.
    private static func contextLost(_ text: String) -> SessionFailure {
        SessionFailure(ExperienceFailure(code: SessionFailure.contextLostCode, message: text), stage: .context)
    }

    /// A duration in seconds.
    private static func seconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) + Double(parts.attoseconds) * 1e-18
    }
}
