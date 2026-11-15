// SchoolMetrics — feature 069 (A09-P02) T-A09-204 (FR-A09-210; SC-A09-201, SC-A09-202; clarification 5). How
// strongly the fish of a habitat document school: the mean distance between fish of the same species and between fish
// of different species (over all such pairs), and the heading agreement (the length of each species' mean unit
// heading, averaged over the species with at least two fish; 1 = all parallel). Pure functions of the document.
import Foundation
import VisualCoreMath

/// Measures of how strongly the fish of a habitat document school.
public enum SchoolMetrics {
    /// The mean distance over all pairs of fish of the same species, or `nil` when there is no such pair.
    public static func meanSameSpeciesDistance(_ doc: HabitatDocument) -> Double? {
        meanDistance(doc) { $0 == $1 }
    }

    /// The mean distance over all pairs of fish of different species, or `nil` when there is no such pair.
    public static func meanCrossSpeciesDistance(_ doc: HabitatDocument) -> Double? {
        meanDistance(doc) { $0 != $1 }
    }

    /// For each species with at least two fish, the length of the mean of the fish's unit headings
    /// (cos heading, sin heading); the average of those lengths over those species, or `nil` when no species has two
    /// fish. 1 means every fish of each species swims the same way; near 0 means headings cancel out.
    public static func headingAgreement(_ doc: HabitatDocument) -> Double? {
        var sums: [String: (vector: Vec2, count: Int)] = [:]
        for fish in doc.fish {
            let entry = sums[fish.speciesId] ?? (.zero, 0)
            sums[fish.speciesId] = (entry.vector + Vec2(cos(fish.heading), sin(fish.heading)), entry.count + 1)
        }
        let lengths = sums.values.filter { $0.count >= 2 }.map { ($0.vector / Double($0.count)).length }
        guard !lengths.isEmpty else { return nil }
        return lengths.reduce(0, +) / Double(lengths.count)
    }

    /// The mean distance over all fish pairs whose species ids satisfy `include`, or `nil` when there is none.
    private static func meanDistance(_ doc: HabitatDocument, include: (String, String) -> Bool) -> Double? {
        var total = 0.0, pairs = 0
        for i in doc.fish.indices {
            for j in doc.fish.indices where j > i && include(doc.fish[i].speciesId, doc.fish[j].speciesId) {
                total += doc.fish[i].position.distance(to: doc.fish[j].position)
                pairs += 1
            }
        }
        return pairs > 0 ? total / Double(pairs) : nil
    }
}
