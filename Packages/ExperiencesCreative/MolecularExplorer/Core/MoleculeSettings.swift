// MoleculeSettings — feature 113 (A15-P04) T-A15-402 (contracts/library.md; data-model "LabelMode", "MoleculeSettings";
// research D1, D3; clarification Q2). The person's Molecular Explorer settings, kept apart from the engine state so
// digests and replays do not change: the label mode (all, selected or none; default all; `selected` with no atom
// selected shows no label). The document `settings.json` is schema 1, sorted keys, at most 1,024 bytes:
// `{"labels":"all","schemaVersion":1}`. `decode(_:)` refuses, in this order:
// - `oversized`: more than 1,024 bytes (checked before parsing);
// - `damaged`: not JSON, or a missing key or a value of the wrong type;
// - `newer-version`: a schema version above 1;
// - `out-of-range`: a schema version below 1 or an unknown label mode.
// `DocumentRefusal` is shared with `RecentMolecules`.
import Foundation

/// Why a Molecular Explorer document (`recent.json`, `settings.json`) was refused.
public enum DocumentRefusal: String, Error, Sendable {
    /// Not JSON, or a missing key or a value of the wrong type.
    case damaged
    /// Larger than the document's byte cap.
    case oversized
    /// A schema version newer than this build reads.
    case newerVersion = "newer-version"
    /// A value outside its allowed range (see the document's rules).
    case outOfRange = "out-of-range"
}

/// Which atom labels are shown.
public enum LabelMode: String, Codable, CaseIterable, Sendable {
    /// Every atom is labelled.
    case all
    /// Only the selected atom is labelled (none when no atom is selected).
    case selected
    /// No atom is labelled.
    case none
}

/// The person's Molecular Explorer settings (`settings.json`, schema 1).
public struct MoleculeSettings: Equatable, Sendable {
    /// The schema version this build writes and reads.
    public static let schemaVersion = 1
    /// The largest accepted document, bytes.
    public static let maxBytes = 1_024
    /// The document's file name.
    public static let fileName = "settings.json"

    /// The label mode.
    public var labels: LabelMode

    /// Creates settings (labels default to ``LabelMode/all``).
    public init(labels: LabelMode = .all) {
        self.labels = labels
    }

    /// The stored shape: the label mode as text, so an unknown mode is out of range rather than damaged.
    private struct Payload: Codable {
        var labels: String
        var schemaVersion: Int
    }

    /// The settings as JSON with sorted keys (`{"labels":"all","schemaVersion":1}`).
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(Payload(labels: labels.rawValue, schemaVersion: Self.schemaVersion))) ?? Data()
    }

    /// The settings in `data`, or the first refusal in the order of the file header.
    public static func decode(_ data: Data) -> Result<MoleculeSettings, DocumentRefusal> {
        guard data.count <= maxBytes else { return .failure(.oversized) }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return .failure(.damaged) }
        guard payload.schemaVersion <= schemaVersion else { return .failure(.newerVersion) }
        guard payload.schemaVersion >= 1, let mode = LabelMode(rawValue: payload.labels) else {
            return .failure(.outOfRange)
        }
        return .success(MoleculeSettings(labels: mode))
    }
}
