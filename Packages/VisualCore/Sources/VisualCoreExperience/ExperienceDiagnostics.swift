// ExperienceDiagnostics — feature 188 T-U02-016 (the GPU counts the engine's deactivation takes) and T-U02-028 (the
// diagnostics value; FR-U02-060, FR-U02-061; data-model section 5).
import Foundation

/// The GPU objects of a render host at one moment, as plain numbers, so that pure code can state and check them.
public struct GPUResourceCounts: Sendable, Equatable, Codable {
    /// Live GPU objects of all kinds.
    public let objects: Int
    /// Bytes held by the live objects.
    public let bytes: Int
    /// Objects that were still live when their context ended.
    public let leaked: Int

    /// Creates the counts.
    public init(objects: Int, bytes: Int, leaked: Int) {
        self.objects = objects
        self.bytes = bytes
        self.leaked = leaked
    }
}
