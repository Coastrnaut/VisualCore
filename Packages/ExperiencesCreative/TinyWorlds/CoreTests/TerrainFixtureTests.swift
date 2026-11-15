// TerrainFixtureTests — feature 089 (A12-P01) T-A12-103 (FR-A12-111, FR-A12-112; clarification 3; research D3;
// SC-A12-101). The regression fixtures of the three presets: the world digests of seeds 1, 2 and 3 of each preset equal
// the committed values (generated once on the host and pasted here; the same values pin the manifest fixtures), are
// reproduced on a second generation, and differ pairwise within each preset and across presets.
import Foundation
import Testing
import TinyWorldsCore

@Suite struct TerrainFixtureTests {
    /// The committed world digests by preset content id and seed.
    static let fixtures: [String: [UInt32: String]] = [
        "island": [
            1: "6ad87d5fc0b62b720eae3d381c2600ef634d0acee52982bacdf688452f70f2b7",
            2: "28eac395e65fc6fcf2713725b6c5b1b2515af373ee85b76fdd5610daa2c06dec",
            3: "b05b9dc71fa964666d6d6d7c15f10485d0590611b1395ef10ff00f09d6a792d8",
        ],
        "asteroid-garden": [
            1: "7ccda10cef6cbf900d8a63fcb8fe0ae4cc730e309f0b1218a70e3f18f25fd8da",
            2: "25e90b4078828e0df874e530dcdd92d4473e177f51cd9332295e3f51167da032",
            3: "9d44402cdee8b731ee4c7ae86378e76e7db3752b33d4068ae8dd0da9a04f1bd0",
        ],
        "miniature-city": [
            1: "a82c2679d9bb729d61c166aede28cc798627e5f7189d2975dfc3c0c22d12082a",
            2: "0f7cfa9a93f4d79fb66cbea3cfdd278d2b8c2205c11aa8d8a80eb64edfa7d644",
            3: "12581638b5b7a92b00efc0e1f3ba45bdeba5d36767cdafb5ed95bbcfbcbb65d4",
        ],
    ]

    @Test(arguments: WorldPreset.all)
    func theDigestsOfSeedsOneTwoAndThreeEqualTheFixtures(preset: WorldPreset) throws {
        let expected = try #require(Self.fixtures[preset.id.contentId])
        #expect(expected.count == 3)
        var seen: Set<String> = []
        for seed: UInt32 in [1, 2, 3] {
            let digest = try TerrainGenerator.digest(preset: preset, seed: seed)
            #expect(digest == expected[seed], "\(preset.id.contentId) seed \(seed): \(digest)")
            #expect(try TerrainGenerator.digest(preset: preset, seed: seed) == digest)
            seen.insert(digest)
        }
        #expect(seen.count == 3, "seeds 1, 2 and 3 of \(preset.id.contentId) differ pairwise")
    }

    @Test func theNineFixturesAreDistinctAcrossPresets() {
        let all = Self.fixtures.values.flatMap(\.values)
        #expect(all.count == 9)
        #expect(Set(all).count == 9)
        #expect(all.allSatisfy { $0.count == 64 && $0.allSatisfy { "0123456789abcdef".contains($0) } })
    }
}
