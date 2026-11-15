// WaterEffectsTests — feature 071 (A09-P04) T-A09-403 (FR-A09-401–404, 410; SC-A09-401, 403). Bubbles, motes and
// depth layers from the step count, host-free and short: for both bundled habitats at every step of one minute
// (3,600 steps) at most 48 bubbles, each between the vent height and the surface and within the wobble of a vent;
// the newest bubble sits at its vent when released; a bubble reaches the surface and is gone by the next release
// cycle; the same step gives the same output; Reduce Motion halves the rise and removes the wobble; no vents or a
// negative step give nothing; 24 motes inside 0…16 × 1.5…8.5 that wrap after crossing x 16; layers, scales, tints
// and the tint mix.
import Foundation
import Testing
import DigitalAquariumCore
import VisualCoreMath

@Suite struct WaterEffectsTests {
    private let habitats = SpeciesCatalog.bundled.habitats

    @Test func theConstantsMatchTheContract() {
        #expect(WaterEffects.maxBubbles == 48)
        #expect(WaterEffects.bubblesPerVent == 24)
        #expect(WaterEffects.releaseInterval == 20)
        #expect(WaterEffects.moteCount == 24)
        #expect(WaterEffects.riseSpeed == 1.2)
        #expect(WaterEffects.wobble == 0.08)
        #expect(WaterEffects.wobbleHz == 1.5)
        #expect(WaterEffects.surface == 9.0)
        #expect(WaterEffects.ventY == 1.0)
        #expect(WaterEffects.moteSpeed == 0.05)
    }

    @Test(arguments: [false, true])
    func everyBubbleStaysBetweenItsVentAndTheSurfaceForOneMinute(reduceMotion: Bool) {
        let tolerance = WaterEffects.wobble + 1e-9
        for habitat in habitats {
            #expect(habitat.vents.count == 2)
            var violations = 0
            for step in 0...3_600 {
                let bubbles = WaterEffects.bubbles(step: step, vents: habitat.vents, reduceMotion: reduceMotion)
                if bubbles.count > WaterEffects.maxBubbles { violations += 1 }
                for bubble in bubbles {
                    let nearest = habitat.vents.map { abs(bubble.x - $0) }.min() ?? .infinity
                    if bubble.y < WaterEffects.ventY || bubble.y >= WaterEffects.surface
                        || nearest > (reduceMotion ? 1e-12 : tolerance) {
                        violations += 1
                    }
                }
            }
            #expect(violations == 0, "\(habitat.id) reduceMotion \(reduceMotion)")
        }
    }

    @Test func twoVentsGiveTwentyBubblesEachOnceSteady() {
        // A bubble lives (9 − 1) / 1.2 s = 400 steps, so a vent releasing every 20 steps keeps 20 alive.
        let reef = habitats[0]
        #expect(WaterEffects.bubbles(step: 1_000, vents: reef.vents, reduceMotion: false).count == 40)
        // Reduce Motion: 800 steps of life would be 40 per vent; the cap keeps 24 per vent, 48 in all.
        #expect(WaterEffects.bubbles(step: 2_000, vents: reef.vents, reduceMotion: true).count == 48)
        // Four vents: the total is still capped at 48.
        let four = WaterEffects.bubbles(step: 2_000, vents: [2, 6, 10, 14], reduceMotion: false)
        #expect(four.count == 48)
        #expect(Array(four.prefix(20)).allSatisfy { abs($0.x - 2) <= WaterEffects.wobble + 1e-9 })
    }

    @Test func theNewestBubbleSitsAtItsVentWhenReleased() {
        for habitat in habitats {
            for k in 0..<30 {
                let release = 20 * k
                let bubbles = WaterEffects.bubbles(step: release, vents: habitat.vents, reduceMotion: false)
                let newest = bubbles[0]
                #expect(newest.y == WaterEffects.ventY)
                #expect(abs(newest.x - habitat.vents[0]) <= WaterEffects.wobble + 1e-9)
                // The second vent releases 10 steps later.
                let later = WaterEffects.bubbles(step: release + 10, vents: habitat.vents, reduceMotion: false)
                #expect(later.contains { $0.y == WaterEffects.ventY
                                         && abs($0.x - habitat.vents[1]) <= WaterEffects.wobble + 1e-9 })
            }
        }
        #expect(WaterEffects.bubbles(step: 9, vents: [4, 12], reduceMotion: false).count == 1)
        #expect(WaterEffects.bubbles(step: 10, vents: [4, 12], reduceMotion: false).count == 2)
    }

    @Test func aBubbleReachesTheSurfaceAndIsGoneByTheNextReleaseCycle() throws {
        // The first bubble of a single vent (released at step 0) is just below the surface at step 399 ...
        let before = WaterEffects.bubbles(step: 399, vents: [8], reduceMotion: false)
        #expect(before.count == 20)
        let oldest = try #require(before.last)
        #expect(oldest.y > 8.95 && oldest.y < WaterEffects.surface)
        // ... and gone at the next release (step 400 releases bubble 20; bubble 0 has reached y 9).
        let after = WaterEffects.bubbles(step: 400, vents: [8], reduceMotion: false)
        #expect(after.count == 20)
        #expect(after.allSatisfy { $0.y < WaterEffects.surface })
        let afterOldest = try #require(after.last)
        #expect(abs(afterOldest.y - (1 + 1.2 * 380.0 / 60.0)) < 1e-9)
    }

    @Test func theSameStepGivesTheSameBubblesAndMotes() {
        for step in [0, 1, 37, 600, 3_599] {
            for reduceMotion in [false, true] {
                let vents = habitats[1].vents
                #expect(WaterEffects.bubbles(step: step, vents: vents, reduceMotion: reduceMotion)
                        == WaterEffects.bubbles(step: step, vents: vents, reduceMotion: reduceMotion))
                #expect(WaterEffects.motes(step: step, reduceMotion: reduceMotion)
                        == WaterEffects.motes(step: step, reduceMotion: reduceMotion))
            }
        }
        #expect(WaterEffects.bubbles(step: 600, vents: [8], reduceMotion: false)
                != WaterEffects.bubbles(step: 660, vents: [8], reduceMotion: false))
    }

    @Test func reduceMotionHalvesTheRiseAndRemovesTheWobble() {
        let vent = 8.0
        for step in [100, 337, 1_000] {
            let full = WaterEffects.bubbles(step: step, vents: [vent], reduceMotion: false)
            let reduced = WaterEffects.bubbles(step: step, vents: [vent], reduceMotion: true)
            #expect(reduced.count >= full.count)
            for (a, b) in zip(full, reduced) {
                #expect(abs((b.y - WaterEffects.ventY) * 2 - (a.y - WaterEffects.ventY)) < 1e-9)
                #expect(b.x == vent)
            }
            #expect(full.contains { $0.x != vent })
        }
    }

    @Test func noVentsOrANegativeStepGiveNoBubbles() {
        #expect(WaterEffects.bubbles(step: 500, vents: [], reduceMotion: false).isEmpty)
        #expect(WaterEffects.bubbles(step: -1, vents: [4, 12], reduceMotion: false).isEmpty)
        #expect(WaterEffects.bubbles(step: -1, vents: [4, 12], reduceMotion: true).isEmpty)
    }

    @Test func twentyFourMotesStayInsideTheWaterForOneMinute() {
        for reduceMotion in [false, true] {
            var outside = 0
            for step in stride(from: 0, through: 3_600, by: 3) {
                let motes = WaterEffects.motes(step: step, reduceMotion: reduceMotion)
                if motes.count != WaterEffects.moteCount { outside += 1 }
                outside += motes.filter { !($0.x >= 0 && $0.x < 16 && $0.y >= 1.5 && $0.y <= 8.5) }.count
            }
            #expect(outside == 0)
        }
        let start = WaterEffects.motes(step: 0, reduceMotion: false)
        #expect(Set(start.map(\.x)).count == WaterEffects.moteCount)
        #expect(start.allSatisfy { $0.y >= 1.5 && $0.y <= 8.5 })
    }

    @Test func motesDriftAndWrapAfterCrossingTheEdge() throws {
        let start = WaterEffects.motes(step: 0, reduceMotion: false)
        // One second later every mote has drifted 0.05 to the right (mod 16).
        let second = WaterEffects.motes(step: 60, reduceMotion: false)
        for (a, b) in zip(start, second) {
            let dx = (b.x - a.x + 16).truncatingRemainder(dividingBy: 16)
            #expect(abs(dx - 0.05) < 1e-9)
        }
        // The rightmost mote crosses x 16 and reappears near 0.
        let index = try #require(start.indices.max { start[$0].x < start[$1].x })
        let steps = Int(((16 - start[index].x) / 0.05 * 60).rounded(.up)) + 60
        let wrapped = WaterEffects.motes(step: steps, reduceMotion: false)[index]
        #expect(wrapped.x < start[index].x)
        #expect(wrapped.x >= 0 && wrapped.x < 0.1)
        // Reduce Motion drifts a tenth as fast.
        let slow = WaterEffects.motes(step: 600, reduceMotion: true)
        for (a, b) in zip(start, slow) {
            let dx = (b.x - a.x + 16).truncatingRemainder(dividingBy: 16)
            #expect(abs(dx - 0.05) < 1e-9)
        }
    }

    @Test func layersScalesAndTintsFollowTheIndex() {
        #expect((0..<9).map { WaterEffects.layer(index: $0) } == [0, 1, 2, 0, 1, 2, 0, 1, 2])
        #expect(WaterEffects.layer(index: -1) == 2)
        #expect(WaterEffects.layer(index: -3) == 0)
        #expect([0, 1, 2].map { WaterEffects.scale(layer: $0) } == [0.75, 0.875, 1.0])
        #expect([0, 1, 2].map { WaterEffects.tint(layer: $0) } == [0.35, 0.15, 0.0])
        #expect(WaterEffects.scale(layer: 0) < WaterEffects.scale(layer: 1))
        #expect(WaterEffects.tint(layer: 0) > WaterEffects.tint(layer: 1))
    }

    @Test func tintedMixesTowardTheWaterAndKeepsAlpha() {
        let fish = RGBA(1, 0.5, 0, 0.8), water = RGBA(0, 0.5, 1)
        let mixed = WaterEffects.tinted(fish, toward: water, amount: 0.35)
        #expect(abs(mixed.r - 0.65) < 1e-12 && abs(mixed.g - 0.5) < 1e-12 && abs(mixed.b - 0.35) < 1e-12)
        #expect(mixed.a == 0.8)
        #expect(WaterEffects.tinted(fish, toward: water, amount: 0) == fish)
        #expect(WaterEffects.tinted(fish, toward: water, amount: -2) == fish)
        #expect(WaterEffects.tinted(fish, toward: water, amount: 5) == RGBA(0, 0.5, 1, 0.8))
        #expect(WaterEffects.tinted(fish, toward: water, amount: .nan) == fish)
    }
}
