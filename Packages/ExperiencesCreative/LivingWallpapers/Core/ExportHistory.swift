// ExportHistory — feature 141 (A19-P04) T-A19-402 (FR-A19-404; clarification Q3). The stored list of written
// exports: scene, template, orientation, format, pixel size and the moment it was made, newest first and bounded to
// 20 entries, stored as a versioned JSON envelope of kind `a19.export-history` with typed refusals. Pure Foundation;
// the experience's `HistoryStore` reads and writes it.
import Foundation

/// Why an export history file was refused. A refused file leaves an empty history.
public enum HistoryRefusal: Error, Equatable, Sendable {
    /// The file is not valid JSON, has the wrong kind, lacks a field, has a schema version below 1, or has an entry
    /// with a non-finite `madeAt` or a width or height that is not positive.
    case damaged
    /// The file was written by a newer version (schema above ``ExportHistory/schemaVersion``); the value is that
    /// version.
    case newerVersion(Int)
    /// The file is larger than ``ExportHistory/maxBytes``; the value is its size in bytes.
    case tooLarge(Int)

    /// The stable code: `damaged`, `newer-version` or `too-large`.
    public var code: String {
        switch self {
        case .damaged: return "damaged"
        case .newerVersion: return "newer-version"
        case .tooLarge: return "too-large"
        }
    }

    /// One sentence describing the refusal and naming the offending value.
    public var sentence: String {
        switch self {
        case .damaged:
            return "The export history file is damaged and was not read."
        case .newerVersion(let version):
            return "The export history file has schema version \(version), newer than version "
                + "\(ExportHistory.schemaVersion) that this version reads."
        case .tooLarge(let bytes):
            return "The export history file is \(bytes) bytes, above the limit of "
                + "\(ExportHistory.maxBytes) bytes."
        }
    }
}

/// The history of written exports (schema 1), newest first and never longer than ``bound``.
public struct ExportHistory: Equatable, Sendable, Codable {
    /// The envelope kind of an export history file.
    public static let kind = "a19.export-history"
    /// The schema version this code writes and the newest it reads.
    public static let schemaVersion = 1
    /// The largest history file accepted, in bytes.
    public static let maxBytes = 16_384
    /// The most entries a history keeps; older ones are dropped.
    public static let bound = 20

    /// One written export.
    public struct Entry: Equatable, Sendable, Codable {
        /// The scene id (one of ``SceneCatalog/scenes``).
        public let scene: String
        /// The canvas template id (one of ``CanvasTemplates/all``).
        public let template: String
        /// The canvas orientation.
        public let orientation: Orientation
        /// The file format.
        public let format: ExportFormat
        /// The written width in pixels (positive).
        public let width: Int
        /// The written height in pixels (positive).
        public let height: Int
        /// When the export was written, in seconds since 1970 (finite).
        public let madeAt: Double

        /// Creates an entry.
        public init(scene: String, template: String, orientation: Orientation, format: ExportFormat, width: Int,
                    height: Int, madeAt: Double) {
            self.scene = scene
            self.template = template
            self.orientation = orientation
            self.format = format
            self.width = width
            self.height = height
            self.madeAt = madeAt
        }

        /// Whether the entry is acceptable in a file: `madeAt` finite, width and height positive.
        var isValid: Bool { madeAt.isFinite && width > 0 && height > 0 }
    }

    /// The entries, newest first, at most ``bound``.
    public private(set) var entries: [Entry]

    /// Creates a history from `entries` (newest first), keeping only the first ``bound``; the default is empty.
    public init(entries: [Entry] = []) {
        self.entries = Array(entries.prefix(Self.bound))
    }

    private enum CodingKeys: String, CodingKey {
        case entries
    }

    /// Decodes a bare history value (not the file envelope), keeping only the first ``bound`` entries.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(entries: try container.decode([Entry].self, forKey: .entries))
    }

    /// This history with `entry` inserted as the newest, dropping the oldest entries beyond ``bound``.
    public func adding(_ entry: Entry) -> ExportHistory {
        ExportHistory(entries: [entry] + entries)
    }

    /// An empty history.
    public func cleared() -> ExportHistory {
        ExportHistory()
    }

    private struct Envelope: Codable {
        var kind: String
        var schemaVersion: Int
        var entries: [Entry]?
    }

    private struct Header: Decodable {
        var kind: String
        var schemaVersion: Int
    }

    /// The history file at schema ``schemaVersion``: the JSON envelope `{"entries", "kind", "schemaVersion"}` with
    /// sorted keys and unescaped slashes. Throws when a number is not finite.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Envelope(kind: Self.kind, schemaVersion: Self.schemaVersion, entries: entries))
    }

    /// Reads a history file. Checks, in order: size (``HistoryRefusal/tooLarge(_:)``), the envelope's kind
    /// (``HistoryRefusal/damaged``), the version (``HistoryRefusal/newerVersion(_:)``; below 1 is damaged), the body
    /// (``HistoryRefusal/damaged``), then every entry's finite `madeAt` and positive size (``HistoryRefusal/damaged``).
    /// More than ``bound`` entries are truncated to the newest ``bound``.
    public static func decode(_ data: Data) -> Result<ExportHistory, HistoryRefusal> {
        guard data.count <= maxBytes else { return .failure(.tooLarge(data.count)) }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.kind == kind,
              header.schemaVersion >= 1 else { return .failure(.damaged) }
        guard header.schemaVersion <= schemaVersion else { return .failure(.newerVersion(header.schemaVersion)) }
        guard let envelope = try? decoder.decode(Envelope.self, from: data),
              let entries = envelope.entries else { return .failure(.damaged) }
        guard entries.allSatisfy(\.isValid) else { return .failure(.damaged) }
        return .success(ExportHistory(entries: entries))
    }
}
