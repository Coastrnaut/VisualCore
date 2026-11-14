// StereoMicrophoneAudioSource — feature 065 (A08-P05) T-A08-502 (FR-A08-501; SC-A08-502; gap G-STEREOMIC; research
// D1): the two-channel microphone of the oscilloscope, built beside the mono `MicrophoneAudioSource` (which stays
// unchanged). Permission, session, interruption and recovery behaviour mirror the mono source; the capture goes
// through the internal `StereoMicrophoneCapture` seam and reports the route's channel count (1 or 2). Contract
// specs/065-os-p05-routes-accuracy/contracts/api.md.
import AVFAudio
import Foundation
import VisualCoreAudioDSP

/// A source that writes the microphone input as left and right frames into a `StereoSampleBuffer` (FR-A08-501).
///
/// On a route with two or more input channels the first two are kept apart (``channelCount`` 2); on a one-channel
/// route channel 0 is written to both buffer channels (``channelCount`` 1). ``channelCount`` is 1 until the first
/// successful start and afterwards reflects the route of the latest capture.
///
/// `start(into:)` checks the permission first and throws without touching the audio session or engine unless the
/// state is `.granted`; it never prompts (call `MicrophonePermission.request()` beforehand). The session uses the
/// mono source's category, mode and options (`MicrophoneAudioSource.sessionCategory`, `.sessionMode`,
/// `.sessionOptions`), so music the person is playing keeps playing. The engine is created on start and released on
/// stop, which also deactivates the session with `.notifyOthersOnDeactivation`. Nothing is recorded to disk.
///
/// Recovery follows `MicrophoneAudioSource`: while running or interrupted the source observes the notification center
/// through an `AudioSessionEventMonitor` and reacts in `handle(_:)`: interruption began → capture stopped,
/// `.interrupted`; ended with permission to resume → restarted; ended without it → stays `.interrupted` until
/// `resume()`; route lost or media services reset while running → capture rebuilt. In addition a route change with
/// reason "new device available" (for example a headset plugged in) rebuilds a running capture through
/// `handleNewRoute()`, so ``channelCount`` follows the new route. A restart re-checks the permission; if it fails the
/// state becomes `.failed` with the reason. At most one capture runs at any time.
@MainActor
public final class StereoMicrophoneAudioSource: StereoAudioSource {
    /// Sample rate of the input node while running (48 kHz until the first start).
    public private(set) var sampleRate: Double = 48_000
    /// Number of distinct channels the current route delivers: 1 (written to both buffer channels) or 2.
    public private(set) var channelCount: Int = 1
    /// Current lifecycle state.
    public private(set) var state: AudioSourceState = .idle
    /// True only while `.interrupted` after an interruption ended without permission to resume (`resume()` is the
    /// way back); false otherwise.
    public private(set) var awaitsResume = false

    private let permission: any MicrophonePermission
    private let makeCapture: @MainActor () -> any StereoMicrophoneCapture
    private let center: NotificationCenter?
    private var capture: (any StereoMicrophoneCapture)?
    private var buffer: StereoSampleBuffer?
    private var monitor: AudioSessionEventMonitor?
    private var routeObserver: (any NSObjectProtocol)?
    /// Number of successful capture starts, restarts included (test hook for "no engine without permission").
    internal private(set) var engineStartCount = 0
    /// Number of captures currently running (test hook; never above 1).
    internal private(set) var runningCaptures = 0

    /// Creates a two-channel microphone source gated by `permission`, capturing with the system engine and observing
    /// the default notification center for audio-session events while running or interrupted.
    public convenience init(permission: any MicrophonePermission) {
        self.init(permission: permission, makeCapture: { SystemStereoMicrophoneCapture() }, center: .default)
    }

    /// Test seam: `makeCapture` builds the capture for every start and restart; a `nil` center installs no monitor
    /// (tests call `handle(_:)` and `handleNewRoute()` directly or post on a private center).
    init(permission: any MicrophonePermission, makeCapture: @escaping @MainActor () -> any StereoMicrophoneCapture,
         center: NotificationCenter? = nil) {
        self.permission = permission
        self.makeCapture = makeCapture
        self.center = center
    }

    isolated deinit {
        monitor?.stop()
        if let routeObserver, let center { center.removeObserver(routeObserver) }
        capture?.stop()
    }

    /// Starts capturing into `buffer`.
    /// - Throws: `AudioSourceError.notDetermined` when permission was never asked, `.permissionDenied` when denied or
    ///   restricted, `.engineFailed` when the session or engine cannot start (for example no input route).
    public func start(into buffer: StereoSampleBuffer) throws {
        stop()
        if let error = permissionError() {
            state = .failed(Self.reason(for: error))
            throw error
        }
        self.buffer = buffer
        do {
            try startCapture(into: buffer)
        } catch {
            let (message, thrown) = Self.describe(error)
            state = .failed(message)
            throw thrown
        }
        state = .running
        if let center {
            monitor = AudioSessionEventMonitor(center: center) { [weak self] event in self?.handle(event) }
            routeObserver = center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil,
                                               queue: .main) { [weak self] notification in
                guard Self.isNewDevice(notification.userInfo) else { return }
                MainActor.assumeIsolated { self?.handleNewRoute() }
            }
        }
    }

    /// Stops capturing: removes the tap, stops the engine and deactivates the session. Safe to call when idle.
    /// A running or interrupted source becomes `.idle`; a failed source keeps its failure.
    public func stop() {
        dropMonitor()
        stopCapture()
        awaitsResume = false
        switch state {
        case .running, .interrupted: state = .idle
        case .idle, .failed: break
        }
    }

    /// Reacts to a system audio-session event, exactly as `MicrophoneAudioSource.handle(_:)`. Events while idle or
    /// failed are ignored.
    ///
    /// Running: began → capture stopped, `.interrupted`; route lost or media services reset → capture stopped and
    /// restarted (``channelCount`` follows the new route); ended → ignored. Interrupted: ended with permission to
    /// resume → restarted; ended without it → stays `.interrupted` with `awaitsResume`; began, route lost and media
    /// services reset keep it `.interrupted`. A failed restart ends in `.failed(reason)`.
    public func handle(_ event: AudioSessionEvent) {
        switch state {
        case .running:
            switch event {
            case .interruptionBegan:
                stopCapture()
                awaitsResume = false
                state = .interrupted
            case .routeLost, .mediaServicesReset:
                stopCapture()
                restart()
            case .interruptionEnded:
                break
            }
        case .interrupted:
            switch event {
            case .interruptionEnded(let shouldResume):
                if shouldResume { restart() } else { awaitsResume = true }
            case .interruptionBegan:
                awaitsResume = false
            case .routeLost, .mediaServicesReset:
                break
            }
        case .idle, .failed:
            break
        }
    }

    /// Reacts to a new input route (route change reason "new device available"): a running capture is rebuilt so
    /// ``channelCount`` follows the route; in any other state nothing happens (the next restart builds a fresh
    /// capture anyway).
    public func handleNewRoute() {
        guard state == .running else { return }
        stopCapture()
        restart()
    }

    /// Restarts capture after an interruption (for example after it ended without permission to resume). Does
    /// nothing unless the state is `.interrupted`.
    public func resume() {
        guard state == .interrupted else { return }
        restart()
    }

    /// True when `userInfo` carries the route-change reason "new device available".
    nonisolated static func isNewDevice(_ userInfo: [AnyHashable: Any]?) -> Bool {
        guard let raw = userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt else { return false }
        return AVAudioSession.RouteChangeReason(rawValue: raw) == .newDeviceAvailable
    }

    /// Restarts into the kept buffer, re-checking the permission; ends `.running` or `.failed(reason)`.
    private func restart() {
        stopCapture()
        awaitsResume = false
        if let error = permissionError() {
            fail(Self.reason(for: error))
            return
        }
        guard let buffer else {
            fail("no buffer to resume into")
            return
        }
        do {
            try startCapture(into: buffer)
            state = .running
        } catch {
            fail(Self.describe(error).message)
        }
    }

    private func fail(_ reason: String) {
        dropMonitor()
        stopCapture()
        awaitsResume = false
        state = .failed(reason)
    }

    private func startCapture(into buffer: StereoSampleBuffer) throws {
        stopCapture()
        let capture = makeCapture()
        let route = try capture.start(into: buffer)
        self.capture = capture
        runningCaptures += 1
        engineStartCount += 1
        sampleRate = route.sampleRate
        channelCount = min(max(route.channelCount, 1), 2)
    }

    private func stopCapture() {
        guard let capture else { return }
        capture.stop()
        self.capture = nil
        runningCaptures -= 1
    }

    private func dropMonitor() {
        monitor?.stop()
        monitor = nil
        if let routeObserver, let center { center.removeObserver(routeObserver) }
        routeObserver = nil
    }

    private func permissionError() -> AudioSourceError? {
        switch permission.state {
        case .granted: return nil
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .permissionDenied
        }
    }

    private static func reason(for error: AudioSourceError) -> String {
        switch error {
        case .notDetermined: return "microphone permission not determined"
        case .permissionDenied: return "microphone permission denied"
        default: return "\(error)"
        }
    }

    private static func describe(_ error: any Error) -> (message: String, thrown: AudioSourceError) {
        if let known = error as? AudioSourceError { return ("\(known)", known) }
        let message = error.localizedDescription
        return (message, .engineFailed(message))
    }
}
