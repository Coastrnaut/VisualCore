// AudioSessionEvent — feature 050 (A06-P04) T-A06-402 (FR-A06-401; SC-A06-401; gap G-INTERRUPTION; research D1, D2):
// the system's audio-session notifications translated into source events by a pure mapping, and a monitor that
// observes an injectable NotificationCenter so tests can post synthetic notifications.
import AVFAudio
import Foundation

/// A system audio-session event that an audio source reacts to (FR-A06-401).
public enum AudioSessionEvent: Equatable, Sendable {
    /// Another audio client (a call, an alarm, another app) interrupted the session.
    case interruptionBegan
    /// The interruption ended; `shouldResume` tells whether the system allows resuming without the person asking.
    case interruptionEnded(shouldResume: Bool)
    /// The input route disappeared (route change with reason "old device unavailable", for example headphones with a
    /// microphone unplugged).
    case routeLost
    /// The system's media services were reset; every audio object has to be rebuilt.
    case mediaServicesReset

    /// Maps an `AVAudioSession` notification to an event, or `nil` when it is not one the sources react to.
    ///
    /// - `AVAudioSession.interruptionNotification`: `AVAudioSessionInterruptionTypeKey` (an unsigned integer) began →
    ///   `.interruptionBegan`; ended → `.interruptionEnded(shouldResume:)` from `AVAudioSessionInterruptionOptionKey`
    ///   containing `.shouldResume`. A missing option key means no permission to resume (the system omits it then); a
    ///   missing or malformed type key, an unknown type or a malformed option value maps to `nil`.
    /// - `AVAudioSession.routeChangeNotification`: only `AVAudioSessionRouteChangeReasonKey` equal to
    ///   `.oldDeviceUnavailable` → `.routeLost`; every other reason, or a missing or malformed reason, → `nil`.
    /// - `AVAudioSession.mediaServicesWereResetNotification` → `.mediaServicesReset` (the user info is not read).
    /// - Any other name → `nil`.
    public init?(name: Notification.Name, userInfo: [AnyHashable: Any]?) {
        switch name {
        case AVAudioSession.interruptionNotification:
            guard let raw = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return nil }
            switch type {
            case .began:
                self = .interruptionBegan
            case .ended:
                let options: AVAudioSession.InterruptionOptions
                if let value = userInfo?[AVAudioSessionInterruptionOptionKey] {
                    guard let rawOptions = value as? UInt else { return nil }
                    options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
                } else {
                    options = []
                }
                self = .interruptionEnded(shouldResume: options.contains(.shouldResume))
            @unknown default:
                return nil
            }
        case AVAudioSession.routeChangeNotification:
            guard let raw = userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return nil }
            self = .routeLost
        case AVAudioSession.mediaServicesWereResetNotification:
            self = .mediaServicesReset
        default:
            return nil
        }
    }
}

/// Observes the audio-session notifications on a notification center and delivers them as `AudioSessionEvent`s on
/// the main actor (FR-A06-401; research D2).
///
/// Three observers (interruption, route change, media services reset; any posting object) are registered on
/// creation and removed by `stop()` or when the monitor is released. Notifications that map to no event are dropped.
/// Inject a private `NotificationCenter` in tests and post synthetic notifications on it.
@MainActor
public final class AudioSessionEventMonitor {
    private let center: NotificationCenter
    private var observers: [any NSObjectProtocol] = []

    /// Starts observing `center` (the default center in the app) and calls `handler` for every mapped event.
    public init(center: NotificationCenter = .default, handler: @escaping @MainActor (AudioSessionEvent) -> Void) {
        self.center = center
        let names: [Notification.Name] = [AVAudioSession.interruptionNotification,
                                          AVAudioSession.routeChangeNotification,
                                          AVAudioSession.mediaServicesWereResetNotification]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { notification in
                guard let event = AudioSessionEvent(name: notification.name, userInfo: notification.userInfo) else {
                    return
                }
                MainActor.assumeIsolated { handler(event) }
            }
        }
    }

    isolated deinit { removeObservers() }

    /// Stops observing; no event is delivered afterwards. Safe to call more than once.
    public func stop() { removeObservers() }

    private func removeObservers() {
        for observer in observers { center.removeObserver(observer) }
        observers.removeAll()
    }
}
