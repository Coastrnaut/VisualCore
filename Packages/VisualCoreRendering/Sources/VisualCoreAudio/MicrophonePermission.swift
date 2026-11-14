// MicrophonePermission — feature 047 T-A06-103 (FR-A06-104; gap G-MICPERMISSION): the system record permission
// behind a protocol so the microphone source is testable with a double. Gaps G-AUDIOSOURCE and G-FILESOURCE are
// closed by the sibling files.
import AVFAudio
import Foundation

/// The microphone permission as the app sees it (FR-A06-104).
public enum MicrophonePermissionState: Equatable, Sendable {
    /// The person has not been asked yet.
    case notDetermined
    /// Recording is allowed.
    case granted
    /// The person declined.
    case denied
    /// Recording is blocked by policy (for example parental controls). Never produced by
    /// `SystemMicrophonePermission`, because the system record permission has no such value; kept so doubles and
    /// future system values can report it, and treated like `denied`.
    case restricted
}

/// Reads and requests the microphone permission.
@MainActor
public protocol MicrophonePermission: AnyObject {
    /// The current permission state.
    var state: MicrophonePermissionState { get }
    /// Asks the person (shows the system prompt when not determined) and returns the resulting state.
    func request() async -> MicrophonePermissionState
}

/// The system microphone permission, read from `AVAudioApplication`.
///
/// Mapping: `.undetermined` → `.notDetermined`, `.denied` → `.denied`, `.granted` → `.granted`. The system has no
/// restricted value, so `.restricted` is never produced here; unknown future values map to `.notDetermined`.
@MainActor
public final class SystemMicrophonePermission: MicrophonePermission {
    /// Creates the system permission reader.
    public init() {}

    /// The current state, mapped from `AVAudioApplication.shared.recordPermission`.
    public var state: MicrophonePermissionState { Self.map(AVAudioApplication.shared.recordPermission) }

    /// Requests record permission from the system and returns the mapped state afterwards.
    public func request() async -> MicrophonePermissionState {
        _ = await AVAudioApplication.requestRecordPermission()
        return state
    }

    /// Maps a system record permission value to `MicrophonePermissionState`.
    public nonisolated static func map(_ permission: AVAudioApplication.recordPermission) -> MicrophonePermissionState {
        switch permission {
        case .undetermined: return .notDetermined
        case .denied: return .denied
        case .granted: return .granted
        @unknown default: return .notDetermined
        }
    }
}
