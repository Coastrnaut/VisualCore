// FramePacingTests — feature 003 T-F203 (FR-F206): the reference QualityGovernor table
// (60 nominal/fair; 30 serious; 30 + scale 0.75 critical; 30 in Low Power Mode; never below 30).
import Testing
@testable import VisualCoreDiagnostics

@Test func nominalAndFairKeepTheRequestedCap() {
    #expect(FramePacing(thermal: .nominal, lowPower: false, requestedMaxFPS: 60).maxFPS == 60)
    #expect(FramePacing(thermal: .fair, lowPower: false, requestedMaxFPS: 120).maxFPS == 120)
    #expect(FramePacing(thermal: .fair, lowPower: false, requestedMaxFPS: 60).renderScale == 1.0)
}

@Test func seriousCapsAtThirty() {
    let p = FramePacing(thermal: .serious, lowPower: false, requestedMaxFPS: 60)
    #expect(p.maxFPS == 30)
    #expect(p.renderScale == 1.0)
}

@Test func criticalCapsAtThirtyAndLowersScale() {
    let p = FramePacing(thermal: .critical, lowPower: false, requestedMaxFPS: 60)
    #expect(p.maxFPS == 30)
    #expect(p.renderScale == 0.75)
}

@Test func lowPowerCapsAtThirty() {
    #expect(FramePacing(thermal: .nominal, lowPower: true, requestedMaxFPS: 60).maxFPS == 30)
}

@Test func neverBelowThirtyAndRangeIsConsistent() {
    let p = FramePacing(thermal: .nominal, lowPower: false, requestedMaxFPS: 10)
    #expect(p.maxFPS == 30)
    #expect(p.range == FramePacing.Range(minimum: 30, maximum: 30, preferred: 30))
    #expect(FramePacing(thermal: .nominal, lowPower: false, requestedMaxFPS: 60).range == .init(minimum: 30, maximum: 60, preferred: 60))
}

@Test func deltaIsClamped() {
    #expect(FramePacing.clampedDelta(5.0) == 0.1)
    #expect(FramePacing.clampedDelta(-1) == 0)
    #expect(FramePacing.clampedDelta(1.0 / 60) == 1.0 / 60)
}
