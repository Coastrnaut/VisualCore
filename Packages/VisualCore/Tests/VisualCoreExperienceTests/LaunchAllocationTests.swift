// LaunchAllocationTests — feature 187 T-U01-007 (FR-U01-011, FR-U01-012; SC-U01-002; ADR-0009 D-02).
import Foundation
import Testing
@testable import VisualCoreExperience

@Suite struct LaunchAllocationTests {
    private func refusedCode(_ change: (inout ManifestBuilder) -> Void) -> String? {
        do {
            _ = try CatalogManifest(data: ManifestBuilder.changing(change))
            return nil
        } catch {
            guard case let .allocation(code, reason) = error, !reason.isEmpty else { return "other error: \(error)" }
            return code
        }
    }

    @Test func launchSetIsFiftyFreeAndFiftyPremium() throws {
        let manifest = try CatalogManifest(data: ManifestBuilder().data)
        let free = manifest.experiences.filter { $0.tier == .free }.map(\.code.text)
        let premium = manifest.experiences.filter { $0.tier == .premium }.map(\.code.text)
        #expect(free == (1...25).map { String(format: "A%02d", $0) } + (1...25).map { String(format: "R02-G%02d", $0) })
        #expect(premium == (3...4).flatMap { round in (1...25).map { String(format: "R%02d-G%02d", round, $0) } })
    }

    @Test func wrongTiersAreRefused() {
        #expect(refusedCode { $0.set(2, "tier", "premium") } == "A03")
        #expect(refusedCode { $0.set(29, "tier", "premium") } == "R02-G05")
        #expect(refusedCode { $0.set(56, "tier", "free") } == "R03-G07")
        #expect(refusedCode { $0.set(99, "tier", "free") } == "R04-G25")
    }

    @Test func missingAndForeignCodesAreRefused() {
        #expect(refusedCode { $0.entries.remove(at: 10) } == "A11")
        #expect(refusedCode { $0.entries.removeLast() } == "R04-G25")
        #expect(refusedCode { $0.entries.append(ManifestBuilder.entry(code: "A26", order: 101)) } == "A26")
        #expect(refusedCode { $0.entries.append(ManifestBuilder.entry(code: "R02-G26", order: 101)) } == "R02-G26")
        #expect(refusedCode { $0.entries.append(ManifestBuilder.entry(code: "R05-G01", order: 101, tier: "free")) } == "R05-G01")
        #expect(refusedCode { $0.entries.append(ManifestBuilder.entry(code: "R05-G26", order: 101)) } == "R05-G26")
        #expect(refusedCode { $0.entries.append(ManifestBuilder.entry(code: "R13-G01", order: 101)) } == "R13-G01")
    }

    @Test func premiumBacklogEntryIsAccepted() throws {
        let data = ManifestBuilder.changing { $0.entries.append(ManifestBuilder.entry(code: "R05-G01", order: 101)) }
        let manifest = try CatalogManifest(data: data)
        #expect(manifest.experiences.count == 101)
        #expect(manifest.experiences.last?.tier == .premium)
    }
}
