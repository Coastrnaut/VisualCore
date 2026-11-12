// RegistryReport — feature 187 T-U01-016 (FR-U01-050, FR-U01-051; data-model section 10).
import Foundation

/// The result of comparing the registered experience factories with the available entries of the catalog.
/// Every list is sorted by id. The package tests and the app's tests use the same check.
public struct RegistryReport: Sendable, Equatable {
    /// Available entries of the catalog for which nothing is registered.
    public let missingRegistrations: [ExperienceID]
    /// Registered ids whose entry is missing from the catalog or is not available.
    public let unexpectedRegistrations: [ExperienceID]
    /// Ids that were registered more than once, each listed once.
    public let duplicates: [ExperienceID]

    /// Creates a report from its three lists.
    public init(missingRegistrations: [ExperienceID], unexpectedRegistrations: [ExperienceID], duplicates: [ExperienceID]) {
        self.missingRegistrations = missingRegistrations
        self.unexpectedRegistrations = unexpectedRegistrations
        self.duplicates = duplicates
    }

    /// True when the registrations and the available entries match one to one.
    public var isMatch: Bool { missingRegistrations.isEmpty && unexpectedRegistrations.isEmpty && duplicates.isEmpty }
}

extension CatalogManifest {
    /// Compares registered experience ids with the available entries. It needs nothing but the catalog and the ids.
    public func registryReport(registered: [ExperienceID]) -> RegistryReport {
        var seen = Set<ExperienceID>(), repeated = Set<ExperienceID>()
        for id in registered where !seen.insert(id).inserted {
            repeated.insert(id)
        }
        let availableIDs = Set(available.map(\.id))
        return RegistryReport(missingRegistrations: availableIDs.subtracting(seen).sorted(),
                              unexpectedRegistrations: seen.subtracting(availableIDs).sorted(),
                              duplicates: repeated.sorted())
    }
}
