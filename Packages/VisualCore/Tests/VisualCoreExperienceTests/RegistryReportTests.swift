// RegistryReportTests — feature 187 T-U01-015 (FR-U01-050, FR-U01-051; SC-U01-007; data-model section 10).
import Foundation
import Testing
@testable import VisualCoreExperience

@Suite struct RegistryReportTests {
    private func manifest(available: [Int]) throws -> CatalogManifest {
        try CatalogManifest(data: ManifestBuilder.changing { b in available.forEach { b.set($0, "available", true) } })
    }

    private func id(_ text: String) -> ExperienceID { ExperienceID(rawValue: text)! }

    @Test func matchingSetsAreAMatch() throws {
        let report = try manifest(available: [0, 2]).registryReport(registered: [id("a03.e3"), id("a01.e1")])
        #expect(report.isMatch)
        #expect(report.missingRegistrations.isEmpty && report.unexpectedRegistrations.isEmpty && report.duplicates.isEmpty)
    }

    @Test func availableEntryWithoutARegistrationIsListed() throws {
        let report = try manifest(available: [2, 0, 30]).registryReport(registered: [id("a01.e1")])
        #expect(!report.isMatch)
        #expect(report.missingRegistrations == [id("a03.e3"), id("r02-g06.e31")])
        #expect(report.unexpectedRegistrations.isEmpty && report.duplicates.isEmpty)
    }

    @Test func registrationWithoutAnAvailableEntryIsListed() throws {
        // a02.e2 is in the catalog but not available; z-ids are not in the catalog at all.
        let report = try manifest(available: [0]).registryReport(registered: [id("a01.e1"), id("r12-g25.nowhere"), id("a02.e2")])
        #expect(!report.isMatch)
        #expect(report.unexpectedRegistrations == [id("a02.e2"), id("r12-g25.nowhere")])
        #expect(report.missingRegistrations.isEmpty && report.duplicates.isEmpty)
    }

    @Test func duplicateRegistrationIsListedOnce() throws {
        let report = try manifest(available: [0, 1]).registryReport(registered: [id("a02.e2"), id("a01.e1"), id("a02.e2"), id("a02.e2")])
        #expect(!report.isMatch)
        #expect(report.duplicates == [id("a02.e2")])
        #expect(report.missingRegistrations.isEmpty && report.unexpectedRegistrations.isEmpty)
    }

    @Test func todaysCatalogWithTheIntegratedExperiencesRegisteredIsAMatch() throws {
        let manifest = try CatalogFixture.manifest()
        let integrated = ["a01.generative-art-studio", "a02.fluid-art-playground", "a03.fractal-explorer",
                         "a04.particle-universe", "a05.infinite-geometry"].compactMap(ExperienceID.init(rawValue:))
        #expect(manifest.registryReport(registered: integrated).isMatch)
        #expect(manifest.registryReport(registered: []).missingRegistrations == integrated)
    }
}
