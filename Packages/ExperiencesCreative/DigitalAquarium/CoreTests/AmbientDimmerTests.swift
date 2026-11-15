// AmbientDimmerTests — feature 072 (A09-P05) T-A09-502 (FR-A09-511; clarification 3; research D3). The dimmer stays at
// full brightness for 60 s of active frame time, fades linearly to 0.6 over 2 s, holds 0.6, restores at once on a
// touch, counts only active, finite, positive time and resets while ambient drawing is off.
import Testing
import DigitalAquariumCore

@Suite struct AmbientDimmerTests {
    private func dimmer(after seconds: Double) -> AmbientDimmer {
        var dimmer = AmbientDimmer()
        dimmer.advance(by: seconds, active: true)
        return dimmer
    }

    @Test func theTuningFollowsResearchD3() {
        #expect(AmbientDimmer.idleInterval == 60)
        #expect(AmbientDimmer.fadeDuration == 2)
        #expect(AmbientDimmer.dimLevel == 0.6)
        #expect(AmbientDimmer().idle == 0)
        #expect(AmbientDimmer().brightness == 1)
    }

    @Test func theBrightnessFadesAfterSixtySecondsOverTwoSeconds() {
        #expect(dimmer(after: 59.9).brightness == 1)
        #expect(dimmer(after: 60).brightness == 1)
        #expect(abs(dimmer(after: 61).brightness - 0.8) < 1e-12)
        #expect(abs(dimmer(after: 62).brightness - 0.6) < 1e-12)
        #expect(abs(dimmer(after: 600).brightness - 0.6) < 1e-12)
    }

    @Test func frameStepsAddUpLikeOneLongStep() {
        var dimmer = AmbientDimmer()
        for _ in 0..<(61 * 60) { dimmer.advance(by: 1.0 / 60, active: true) }
        #expect(abs(dimmer.idle - 61) < 1e-9)
        #expect(abs(dimmer.brightness - 0.8) < 1e-9)
    }

    @Test func aTouchRestoresFullBrightnessAtOnce() {
        var dimmer = dimmer(after: 120)
        #expect(dimmer.brightness < 1)
        dimmer.touch()
        #expect(dimmer.idle == 0)
        #expect(dimmer.brightness == 1)
        dimmer.advance(by: 59, active: true)
        #expect(dimmer.brightness == 1)
    }

    @Test func inactiveTimeResetsTheClock() {
        var dimmer = dimmer(after: 120)
        dimmer.advance(by: 1, active: false)
        #expect(dimmer.idle == 0)
        #expect(dimmer.brightness == 1)
        dimmer.advance(by: 0, active: false)
        #expect(dimmer.idle == 0)
    }

    @Test func nonFiniteAndNonPositiveTimeIsIgnored() {
        var dimmer = dimmer(after: 30)
        for bad in [0, -5, Double.nan, Double.infinity, -Double.infinity] {
            dimmer.advance(by: bad, active: true)
            #expect(dimmer.idle == 30)
        }
    }
}
