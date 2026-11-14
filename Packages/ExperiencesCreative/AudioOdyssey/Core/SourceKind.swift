// SourceKind — feature 055 (A07-P02) T-A07-204 (FR-A07-220; data-model "JourneyState" schema 2). The audio source the
// person chose: the demo signal (the first choice), the microphone or a picked file. The raw values are persisted;
// samples, features and the file URL are never state.
import Foundation

/// The audio source that drives the tunnel. The raw values are persisted (demo 0, microphone 1, file 2).
public enum SourceKind: Int, CaseIterable, Codable, Sendable {
    /// The built-in demo signal (the first choice and the fallback when microphone access is denied).
    case demo = 0
    /// The live microphone, after the person allowed access.
    case microphone = 1
    /// An audio file the person picked with the system file importer.
    case file = 2

    /// The name shown on the source buttons and spoken in the canvas description.
    public var displayName: String {
        switch self {
        case .demo: "Demo signal"
        case .microphone: "Microphone"
        case .file: "File"
        }
    }
}
