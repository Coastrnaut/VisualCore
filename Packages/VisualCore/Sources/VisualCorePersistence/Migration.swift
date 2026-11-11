// Migration.swift — ordered payload migrations between schema versions (feature 014 T-A01-301; FR-A01-307).
import Foundation

/// Upgrades stored payloads (JSON objects) step by step to `currentVersion`: the step registered for version `n`
/// turns a version-`n` payload into a version-`n + 1` payload. Old shapes need no old Swift types.
public struct MigrationChain: Sendable {
    /// One upgrade step from version n to n + 1.
    public typealias Step = @Sendable ([String: Any]) throws -> [String: Any]

    /// The version this build writes.
    public let currentVersion: Int
    private let steps: [Int: Step]

    /// A chain ending at `currentVersion` with `steps[n]` upgrading version n → n + 1.
    public init(currentVersion: Int, steps: [Int: Step] = [:]) {
        self.currentVersion = currentVersion
        self.steps = steps
    }

    /// `payload` migrated from `version` to `currentVersion`; throws `MigrationError.missingStep` when a step is absent
    /// and `.newerVersion` when `version` is above `currentVersion`.
    public func migrate(_ payload: [String: Any], from version: Int) throws -> [String: Any] {
        guard version <= currentVersion else { throw MigrationError.newerVersion(version) }
        var current = payload
        for v in version..<currentVersion {
            guard let step = steps[v] else { throw MigrationError.missingStep(v) }
            current = try step(current)
        }
        return current
    }
}

/// Why a migration could not run.
public enum MigrationError: Error, Equatable, Sendable {
    /// No step registered for upgrading this version.
    case missingStep(Int)
    /// The payload is newer than the chain.
    case newerVersion(Int)
}
