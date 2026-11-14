// DemoResponseTraceTests — feature 057 (A07-P04) T-A07-402 (FR-A07-420; SC-A07-404; research D4; data-model
// "DemoResponseTrace"). The response trace on synthetic loud frames (16 bands with a moving sine pattern and an onset
// every 15 frames, 120 frames at 1/60 s): two runs are identical, the primary rises by at least 25% of its range in
// every world with the world's default mapping, every point stays in its bounds, silence stays at rest, and `maxRise`
// measures from rest.
import Foundation
import Testing
import AudioOdysseyCore

@Suite struct DemoResponseTraceTests {
    private static let step = 1.0 / 60
    private static let frameCount = 120

    /// Loud synthetic frames: a ramp up over the first 30 frames times a sine pattern moving across the 16 bands.
    private static func loudFrames() -> (bands: [[Float]], flux: [Float], onsets: [Bool]) {
        var bands: [[Float]] = []
        var flux: [Float] = []
        var onsets: [Bool] = []
        for i in 0..<frameCount {
            let ramp = min(1, Double(i + 1) / 30)
            bands.append((0..<16).map { b in
                Float(ramp * (0.6 + 0.4 * sin(Double(i) * 0.3 + Double(b) * 0.7)))
            })
            flux.append(Float(ramp * (0.5 + 0.5 * sin(Double(i) * 0.9))))
            onsets.append(i % 15 == 0)
        }
        return (bands, flux, onsets)
    }

    private static func run(_ world: JourneyWorld, reduceMotion: Bool = false) -> [DemoResponseTrace.TracePoint] {
        let frames = loudFrames()
        return DemoResponseTrace.run(bandFrames: frames.bands, flux: frames.flux, onsets: frames.onsets, world: world,
                                     mapping: WorldMapping.defaults(for: world), step: step, reduceMotion: reduceMotion)
    }

    @Test func twoRunsAreIdentical() {
        for world in JourneyWorld.allCases {
            let first = Self.run(world)
            let second = Self.run(world)
            #expect(first.count == Self.frameCount)
            #expect(first == second)
            for (a, b) in zip(first, second) {
                #expect(abs(a.primary - b.primary) <= 1e-6 && abs(a.light - b.light) <= 1e-6)
            }
        }
    }

    @Test func loudFramesRaiseThePrimaryByAQuarterInEveryWorld() {
        for world in JourneyWorld.allCases {
            let trace = Self.run(world)
            let rise = DemoResponseTrace.maxRise(trace, world: world)
            #expect(rise >= 0.25, "\(world) rose \(rise)")
            let upper = WorldResponse.maxPrimary(for: world)
            #expect(trace.allSatisfy { (0...upper).contains($0.primary) && (0.30...0.70).contains($0.light) })
            #expect(trace.map(\.light).max()! > 0.35)
        }
    }

    @Test func calmMotionKeepsThePrimaryWithinHalfTheRange() {
        for world in JourneyWorld.allCases {
            let trace = Self.run(world, reduceMotion: true)
            #expect(trace.allSatisfy { $0.primary <= WorldResponse.maxPrimary(for: world) / 2 + 1e-12 })
        }
    }

    @Test func silenceStaysAtRest() {
        let silent = [[Float]](repeating: [Float](repeating: 0, count: 16), count: Self.frameCount)
        for world in JourneyWorld.allCases {
            let trace = DemoResponseTrace.run(
                bandFrames: silent, flux: [Float](repeating: 0, count: Self.frameCount),
                onsets: [Bool](repeating: false, count: Self.frameCount), world: world,
                mapping: WorldMapping.defaults(for: world), step: Self.step)
            #expect(trace.count == Self.frameCount)
            #expect(trace.allSatisfy {
                $0.primary == WorldResponse.restPrimary(for: world) && $0.light == 0.35
            })
            #expect(DemoResponseTrace.maxRise(trace, world: world) == 0)
        }
    }

    @Test func runStopsAtTheShortestInputAndMaxRiseOfEmptyIsZero() {
        let frames = Self.loudFrames()
        let trace = DemoResponseTrace.run(bandFrames: frames.bands, flux: Array(frames.flux.prefix(10)),
                                          onsets: frames.onsets, world: .tunnel,
                                          mapping: WorldMapping.defaults(for: .tunnel), step: Self.step)
        #expect(trace.count == 10)
        #expect(DemoResponseTrace.maxRise([], world: .landscape) == 0)
        let top = DemoResponseTrace.TracePoint(primary: 0.6, light: 0.5)
        #expect(abs(DemoResponseTrace.maxRise([top], world: .landscape) - 1) < 1e-12)
    }
}
