// FixtureSupport — feature 173 (A24-P01) T-A24-107 (FR-A24-106, SC-A24-101). Loads the committed sample sets of
// `Fixtures/*.json`: each holds a description, a sample set and the summary computed by hand from the nearest-rank
// rule of clarification Q2. Every value is synthetic. A deterministic shuffle lets a test reorder a set's measured
// values without breaking the set's frame order.
import Foundation
import GraphicsBenchmarkLabCore

/// One committed fixture: a sample set and its hand-computed summary.
struct SampleFixture: Decodable, Sendable {
    /// What the fixture covers and how its expectation follows from the rule.
    let description: String
    /// The sample set, in frame order.
    let samples: [FrameSample]
    /// The summary computed by hand.
    let expected: Summary
}

/// A named fixture as loaded from the test bundle.
struct NamedFixture: Sendable {
    /// The file name without the `.json` extension.
    let name: String
    /// The fixture's content.
    let fixture: SampleFixture
}

/// The committed fixtures.
enum SampleFixtures {
    /// The fixture names every run must find, one per edge case of T-A24-107.
    static let names: [String] = [
        "one-to-hundred-shuffled", "empty", "single", "all-equal", "ties-at-p95", "count-19", "count-20", "count-99",
        "count-100", "warm-up-only", "warm-up-and-cool-down", "dropped-frames", "without-gpu", "with-gpu",
    ]

    /// Loads the fixture `name` from the bundle's `Fixtures` directory.
    static func load(_ name: String) throws -> SampleFixture {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw FixtureMissing(name: name)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SampleFixture.self, from: data)
    }

    /// Every fixture of ``names``, in that order.
    static func all() throws -> [NamedFixture] {
        var loaded: [NamedFixture] = []
        for name in names { loaded.append(NamedFixture(name: name, fixture: try load(name))) }
        return loaded
    }

    /// The fixture files present in the bundle, by name, sorted.
    static func bundledNames() -> [String] {
        let urls = Bundle.module.urls(forResourcesWithExtension: "json", subdirectory: "Fixtures") ?? []
        return urls.map { $0.deletingPathExtension().lastPathComponent }.sorted()
    }

    /// `samples` with the measured frames' values (interval, CPU, GPU, dropped) permuted by a fixed linear
    /// congruential generator seeded with `seed`. Frame indices and phases stay in place, so the set stays valid;
    /// measured frames without an interval keep their place, so the set's first frame keeps having none.
    static func shuffledMeasuredValues(_ samples: [FrameSample], seed: UInt64) -> [FrameSample] {
        var slots: [Int] = []
        for (index, sample) in samples.enumerated() where sample.phase == .measure && sample.intervalMs != nil {
            slots.append(index)
        }
        var order = slots
        var state = seed
        if order.count > 1 {
            for i in stride(from: order.count - 1, to: 0, by: -1) {
                state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                let j = Int((state >> 33) % UInt64(i + 1))
                order.swapAt(i, j)
            }
        }
        var result = samples
        for (slot, source) in zip(slots, order) {
            let from = samples[source]
            let to = samples[slot]
            result[slot] = FrameSample(frameIndex: to.frameIndex, phase: to.phase, intervalMs: from.intervalMs,
                                       cpuMs: from.cpuMs, gpuMs: from.gpuMs, dropped: from.dropped)
        }
        return result
    }
}

/// A fixture file that is not in the test bundle.
struct FixtureMissing: Error, CustomStringConvertible {
    /// The missing fixture's name.
    let name: String
    /// "fixture <name>.json is not in the bundle".
    var description: String { "fixture \(name).json is not in the bundle" }
}
