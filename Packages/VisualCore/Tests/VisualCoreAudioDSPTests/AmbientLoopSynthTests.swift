// AmbientLoopSynthTests — feature 155 (A21-P04) T-A21-402 (FR-A21-405; gap G-LOOP): the ambient loop is
// deterministic, has seconds × 48,000 samples, stays finite and within ±gain (reaching the gain), is seamless at the
// wrap (the last-to-first step is no larger than the largest step inside the buffer), round-trips through JSON, and
// renders nothing for an invalid recipe.
import Foundation
import Testing
@testable import VisualCoreAudioDSP

private let recipes: [AmbientLoopRecipe] = [
    .gentle,
    AmbientLoopRecipe(seconds: 4, partials: [AmbientLoopPartial(cyclesPerLoop: 1, amplitude: 1)], swellCycles: 1,
                      gain: 0.3),
    AmbientLoopRecipe(seconds: 16, partials: [AmbientLoopPartial(cyclesPerLoop: 1_000, amplitude: 0.5),
                                              AmbientLoopPartial(cyclesPerLoop: 1_501, amplitude: 0.4),
                                              AmbientLoopPartial(cyclesPerLoop: 2_003, amplitude: 0.3),
                                              AmbientLoopPartial(cyclesPerLoop: 3_007, amplitude: 0.2),
                                              AmbientLoopPartial(cyclesPerLoop: 4_001, amplitude: 0.1),
                                              AmbientLoopPartial(cyclesPerLoop: 5_003, amplitude: 0.05)],
                      swellCycles: 3, gain: 0.1),
    AmbientLoopRecipe(seconds: 5, partials: [AmbientLoopPartial(cyclesPerLoop: 777, amplitude: 0.8),
                                             AmbientLoopPartial(cyclesPerLoop: 1_111, amplitude: 0.0)],
                      swellCycles: 1, gain: 0.05),
]

/// The largest absolute step between adjacent samples inside the buffer (not across the wrap).
private func largestInternalStep(_ samples: [Float]) -> Float {
    var largest: Float = 0
    for index in 1..<samples.count {
        largest = max(largest, abs(samples[index] - samples[index - 1]))
    }
    return largest
}

@Test func renderingIsIdenticalTwice() {
    for recipe in recipes {
        #expect(AmbientLoopSynth.render(recipe) == AmbientLoopSynth.render(recipe))
    }
}

@Test func sampleCountIsSecondsTimesRate() {
    #expect(AmbientLoopRecipe.sampleRate == 48_000)
    for recipe in recipes {
        #expect(recipe.isValid)
        #expect(AmbientLoopSynth.render(recipe).count == recipe.seconds * 48_000)
        #expect(recipe.sampleCount == recipe.seconds * 48_000)
    }
    #expect(AmbientLoopRecipe.gentle.seconds == 8)
}

@Test func samplesAreFiniteWithinAndReachingTheGain() {
    for recipe in recipes {
        let samples = AmbientLoopSynth.render(recipe)
        let gain = Float(recipe.gain)
        #expect(samples.allSatisfy { $0.isFinite && abs($0) <= gain })
        let peak = samples.reduce(Float(0)) { max($0, abs($1)) }
        #expect(abs(peak - gain) <= 1e-6, "the loop is normalised to its gain")
    }
    var silent = AmbientLoopRecipe.gentle
    silent.gain = 0
    #expect(AmbientLoopSynth.render(silent).allSatisfy { $0 == 0 })
    var zeroAmplitudes = AmbientLoopRecipe.gentle
    zeroAmplitudes.partials = [AmbientLoopPartial(cyclesPerLoop: 10, amplitude: 0)]
    let zeros = AmbientLoopSynth.render(zeroAmplitudes)
    #expect(zeros.count == zeroAmplitudes.sampleCount)
    #expect(zeros.allSatisfy { $0 == 0 })
}

@Test func theWrapIsSeamless() {
    for recipe in recipes {
        let samples = AmbientLoopSynth.render(recipe)
        let wrapStep = abs(samples[0] - samples[samples.count - 1])
        #expect(wrapStep <= largestInternalStep(samples), "seconds \(recipe.seconds): wrap step \(wrapStep)")
    }
}

@Test func theSwellChangesTheLevelSlowly() {
    // A single unit partial under a one-cycle swell: the quietest second is well below the loudest one.
    let recipe = AmbientLoopRecipe(seconds: 8, partials: [AmbientLoopPartial(cyclesPerLoop: 800, amplitude: 1)],
                                   swellCycles: 1, gain: 0.3)
    let samples = AmbientLoopSynth.render(recipe)
    let second = 48_000
    let peaks = (0..<8).map { index in
        samples[(index * second)..<((index + 1) * second)].reduce(Float(0)) { max($0, abs($1)) }
    }
    let loudest = peaks.max() ?? 0
    let quietest = peaks.min() ?? 0
    #expect(quietest > 0, "the swell never falls silent")
    #expect(quietest < 0.6 * loudest)
}

@Test func recipesRoundTripThroughJSON() throws {
    let data = try JSONEncoder().encode(recipes)
    #expect(try JSONDecoder().decode([AmbientLoopRecipe].self, from: data) == recipes)
}

@Test func invalidRecipesRenderAnEmptyBuffer() {
    let valid = AmbientLoopRecipe.gentle
    var invalid: [AmbientLoopRecipe] = []
    for seconds in [3, 17, 0, -8] {
        var recipe = valid
        recipe.seconds = seconds
        invalid.append(recipe)
    }
    var none = valid
    none.partials = []
    invalid.append(none)
    var seven = valid
    seven.partials = Array(repeating: AmbientLoopPartial(cyclesPerLoop: 100, amplitude: 0.1), count: 7)
    invalid.append(seven)
    for cycles in [0, -1] {
        var recipe = valid
        recipe.partials[0].cyclesPerLoop = cycles
        invalid.append(recipe)
    }
    for amplitude in [-0.1, 1.1, .nan, .infinity] {
        var recipe = valid
        recipe.partials[1].amplitude = amplitude
        invalid.append(recipe)
    }
    for swell in [0, -2] {
        var recipe = valid
        recipe.swellCycles = swell
        invalid.append(recipe)
    }
    for gain in [-0.01, 0.31, .nan, .infinity] {
        var recipe = valid
        recipe.gain = gain
        invalid.append(recipe)
    }
    for recipe in invalid {
        #expect(!recipe.isValid)
        #expect(AmbientLoopSynth.render(recipe).isEmpty)
    }
}
