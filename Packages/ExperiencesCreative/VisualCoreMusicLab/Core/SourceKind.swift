// SourceKind — feature 047 (A06-P01) T-A06-104 (FR-A06-101, FR-A06-121; data-model "MusicLabState"). The three kinds
// of sound source VisualCore Music Lab can draw, and the microphone permission as the domain mirrors it. GPU-free and
// device-free: the audio objects themselves live in the experience (VisualCoreAudio).

/// The kind of sound source the person chose.
public enum SourceKind: String, Sendable, Codable, CaseIterable {
    /// The built-in, deterministic demo signal (no permission, no file).
    case demo
    /// An audio file the person picked with the system file importer.
    case file
    /// The live microphone input, only with permission.
    case microphone

    /// The name shown in the status line and spoken by the canvas description.
    public var displayName: String {
        switch self {
        case .demo: "Demo signal"
        case .file: "Audio file"
        case .microphone: "Microphone"
        }
    }
}

/// The microphone permission as Music Lab mirrors it from the system. The system stays the authority; the mirror only
/// lets the domain refuse the microphone as a rule while access is off (FR-A06-104).
public enum MicrophoneAccess: Int, Sendable, Codable, CaseIterable {
    /// Never asked: choosing the microphone asks once.
    case notDetermined = 0
    /// Allowed: the microphone can run.
    case granted = 1
    /// Refused by the person: the microphone is refused, the way to Settings is shown.
    case denied = 2
    /// Not allowed on this device (for example by Screen Time): refused like `denied`.
    case restricted = 3

    /// Whether choosing the microphone is refused as a rule (denied or restricted).
    public var refusesMicrophone: Bool { self == .denied || self == .restricted }
}
