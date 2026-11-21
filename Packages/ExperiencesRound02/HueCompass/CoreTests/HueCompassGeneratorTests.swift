// HueCompassGeneratorTests — feature 332 (R02-G04-02) T-R02G0402-004 (FR-R02G0402-001, 003; SC-R02G0402-001, 003;
// clarification Q1). Host checks of the generator: the band profiles, determinism, the band ranges and the budget on a
// few entries per band, skipped candidates re-checked as not qualifying, the start rule, the tutorial levels and the
// refusal when no candidate can qualify. Short runs; the whole catalog is checked by HueCompassCatalogTests.
import Testing
@testable import HueCompassCore

@Suite struct HueCompassGeneratorTests {
    @Test func bandProfilesTightenWithTheBand() {
        var previous: HueCompassBandProfile = HueCompassBandProfile.of(band: 1)
        #expect(previous == HueCompassBandProfile(bearingTolerance: 4, bandTolerance: 2, clearShare: 0, smallest: 1...1))
        for band in 2...5 {
            let profile: HueCompassBandProfile = HueCompassBandProfile.of(band: band)
            #expect(profile.bearingTolerance <= previous.bearingTolerance)
            #expect(profile.bandTolerance <= previous.bandTolerance)
            #expect(profile.clearShare >= previous.clearShare)
            #expect(profile.smallest.lowerBound >= previous.smallest.lowerBound)
            previous = profile
        }
        #expect(HueCompassBandProfile.of(band: 5).smallest == 2...2 && HueCompassBandProfile.of(band: 9).clearShare == 40)
    }

    @Test func candidatesAreDeterministicAndFollowTheirProfile() {
        for entry in HueCompassManifest.entries where entry.number % 10 == 1 {
            let profile: HueCompassBandProfile = HueCompassBandProfile.of(band: entry.band)
            for index in 0..<4 {
                let a: HueCompassLevel = HueCompassGenerator.candidate(entry, index: index)
                let b: HueCompassLevel = HueCompassGenerator.candidate(entry, index: index)
                #expect(a == b)
                #expect(a.id == HueCompassGenerator.levelID(entry.number) && a.allowance == entry.budget)
                #expect(a.bearingTolerance == profile.bearingTolerance && a.bandTolerance == profile.bandTolerance)
                #expect(HueCompassWheel.bearingDistance(a.start, a.target) > a.bearingTolerance)
                if profile.clearShare == 0 { #expect(!a.fog.contains(0)) }
            }
            #expect(HueCompassGenerator.candidate(entry, index: 0) != HueCompassGenerator.candidate(entry, index: 1))
        }
    }

    @Test func generatedLevelsMeetTheirBandAndSkippedOnesDoNot() throws {
        for entry in HueCompassManifest.entries where entry.number % 20 == 1 || entry.number % 20 == 7 {
            let generated: HueCompassGenerated = try HueCompassGenerator.generate(entry)
            let profile: HueCompassBandProfile = HueCompassBandProfile.of(band: entry.band)
            #expect(profile.smallest.contains(generated.solution.smallest))
            #expect(generated.solution.smallest < generated.level.allowance)
            #expect(generated.solution.ambiguity != nil)
            #expect(generated.level == HueCompassGenerator.candidate(entry, index: generated.skipped))
            #expect(generated.difficulty.smallest == generated.solution.smallest)
            #expect(generated.difficulty.work == generated.solution.work)
            #expect(generated.level.tutorial == HueCompassGenerator.tutorialLevels.contains(entry.number))
            for index in 0..<generated.skipped {
                let skipped: HueCompassLevel = HueCompassGenerator.candidate(entry, index: index)
                let solution: HueCompassSolution? = HueCompassSolver.solve(skipped)
                let qualifies: Bool = solution.map { profile.smallest.contains($0.smallest) && $0.ambiguity != nil }
                    ?? false
                #expect(!qualifies, "entry \(entry.number) skipped a qualifying candidate \(index)")
            }
            #expect(try HueCompassGenerator.generate(entry) == generated)
        }
    }

    @Test func anImpossibleProfileIsRefusedByNumber() {
        let entry: HueCompassManifestEntry = HueCompassManifest.entries[0]
        let impossible = HueCompassBandProfile(bearingTolerance: 4, bandTolerance: 2, clearShare: 0, smallest: 3...3)
        #expect(throws: HueCompassError.generation(1)) {
            try HueCompassGenerator.generate(entry, profile: impossible)
        }
        #expect(HueCompassError.generation(1).reasonCode == "r02-g04.generation")
        #expect(HueCompassError.witness("x").reasonCode == "r02-g04.witness")
    }

    @Test func levelIDsArePadded() {
        #expect(HueCompassGenerator.levelID(1) == "hue-compass-001")
        #expect(HueCompassGenerator.levelID(42) == "hue-compass-042")
        #expect(HueCompassGenerator.levelID(100) == "hue-compass-100")
    }
}
