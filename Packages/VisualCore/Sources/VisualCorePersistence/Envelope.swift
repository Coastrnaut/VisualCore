// Envelope.swift — the stored form of a document: kind, schema version, save time and payload (feature 014 T-A01-301;
// gap G-PERSIST; contract specs/014-gas-p03-save-restore/contracts/api.md).
import Foundation

/// Metadata of a stored document: what it is (`kind`), which schema version wrote it and when.
public struct DocumentEnvelope: Sendable, Equatable {
    /// Document kind, e.g. `dev.visualcore.gas.composition`; files of another kind are reported and ignored.
    public let kind: String
    /// Schema version of the payload.
    public let schemaVersion: Int
    /// When the file was written (UTC).
    public let savedAt: Date

    /// Creates envelope metadata.
    public init(kind: String, schemaVersion: Int, savedAt: Date) {
        self.kind = kind
        self.schemaVersion = schemaVersion
        self.savedAt = savedAt
    }
}

/// Why a stored document could not be used, or an operation failed.
public enum StoreProblem: Error, Equatable, Sendable {
    /// Not JSON, not an envelope, or the payload does not decode (after migration).
    case corrupt(file: String, reason: String)
    /// An envelope of another kind.
    case wrongKind(file: String, found: String)
    /// Written by a newer schema version than this build understands; left untouched.
    case newerVersion(file: String, version: Int)
    /// Larger than the store's size limit; never read in full.
    case tooLarge(file: String, bytes: Int)
    /// No document with this id.
    case notFound(id: String)
    /// The write did not complete; the previous version (if any) is unchanged.
    case writeFailed(String)
    /// The id does not match `^[A-Za-z0-9._-]{1,128}$` (or starts with a dot).
    case invalidID(String)
}
