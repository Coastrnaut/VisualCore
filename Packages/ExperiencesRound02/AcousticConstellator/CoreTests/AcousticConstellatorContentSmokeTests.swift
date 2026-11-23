// AcousticConstellatorContentSmokeTests — feature 422 (R02-G13-02), temporary sanity check of the content pipeline
// core (the lead decides whether it stays): the first 2 manifest entries of each band generate, their plan sizes are in
// the band's plan range and at most budget − 1, and their witnesses win through the kernel's play.
import Foundation
import Testing
@testable import AcousticConstellatorCore

@Suite("Acoustic Constellator content smoke")
struct AcousticConstellatorContentSmokeTests {
    @Test("The first 2 entries of each band generate certified levels")
    func firstEntriesOfEachBand() throws {
        for band in 1...5 {
            let entries = AcousticConstellatorManifest.entries.filter { $0.band == band }.prefix(2)
            for entry in entries {
                let generated = try AcousticConstellatorGenerator.generate(entry)
                let profile = AcousticConstellatorBandProfile.of(band: band)
                #expect(profile.planRange.contains(generated.plan.size))
                #expect(generated.plan.size <= entry.budget - 1)
                #expect(AcousticConstellatorSolver.wins(generated.level, actions: generated.actions))
                #expect(generated.level.id == AcousticConstellatorGenerator.levelID(entry.number))
                #expect(generated.difficulty.actions == generated.plan.size)
                print("level \(entry.number) band \(band): skipped \(generated.skipped), plan \(generated.plan.size), "
                      + "work \(generated.plan.work), smaller \(generated.plan.smallerSets)")
            }
        }
    }

    @Test("The manifest holds 100 entries, 20 per band, numbered in order")
    func manifestShape() {
        let entries = AcousticConstellatorManifest.entries
        #expect(entries.count == 100)
        #expect(entries.map(\.number) == Array(1...100))
        for band in 1...5 { #expect(entries.filter { $0.band == band }.count == 20) }
    }

    @Test("The new refusals have stable reason codes")
    func reasonCodes() {
        #expect(AcousticConstellatorError.generation(7).reasonCode == "r02-g13.generation")
        #expect(AcousticConstellatorError.witness("x").reasonCode == "r02-g13.witness")
    }
}
