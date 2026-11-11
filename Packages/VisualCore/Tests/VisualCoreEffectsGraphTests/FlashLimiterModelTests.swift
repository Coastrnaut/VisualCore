// FlashLimiterModelTests — feature 005 T-F404 (FR-F409, SC-F403).
import Testing
@testable import VisualCoreEffectsGraph

@Test func strobeAtThirtyHertzChangesAtMostLimitPerSecond() {
    var model = FlashLimiterModel(limitPerSecond: 0.3)
    var displayed: [Double] = []
    for frame in 0..<60 {                                   // 2 s of a black/white strobe at 30 Hz
        let measured = frame % 2 == 0 ? 0.0 : 1.0
        displayed.append(model.step(measured: measured, dt: 1.0 / 30).displayed)
    }
    for i in 1..<displayed.count {
        #expect(abs(displayed[i] - displayed[i - 1]) <= 0.3 / 30 + 1e-9)
    }
    let firstSecond = displayed.prefix(30)
    #expect(firstSecond.max()! - firstSecond.min()! <= 0.3 + 1e-9)
}

@Test func outputMeanEqualsTheAdaptedValue() {
    var model = FlashLimiterModel(limitPerSecond: 0.3)
    _ = model.step(measured: 0.5, dt: 1.0 / 60)             // adapts instantly on the first frame
    let bright = model.step(measured: 1.0, dt: 1.0 / 60)      // must darken: gain < 1, no bias
    #expect(bright.gain < 1 && bright.bias == 0)
    #expect(abs(1.0 * bright.gain + bright.bias - bright.displayed) < 1e-12)
    let dark = model.step(measured: 0.0, dt: 1.0 / 60)       // must lift: bias > 0
    #expect(dark.bias > 0 && dark.gain == 1)
    #expect(abs(0.0 * dark.gain + dark.bias - dark.displayed) < 1e-12)
}

@Test func steadyInputConvergesAndPassesThrough() {
    var model = FlashLimiterModel(limitPerSecond: 0.3)
    _ = model.step(measured: 0.2, dt: 1.0 / 60)
    var last = (displayed: 0.0, gain: 0.0, bias: 0.0)
    for _ in 0..<600 { last = model.step(measured: 0.8, dt: 1.0 / 60) }   // 10 s
    #expect(abs(last.displayed - 0.8) < 1e-9)
    #expect(abs(last.gain - 1) < 1e-9 && last.bias == 0)
}

@Test func deltaIsClampedAndResetForgetsHistory() {
    var model = FlashLimiterModel(limitPerSecond: 0.3)
    _ = model.step(measured: 0, dt: 1.0 / 60)
    let afterPause = model.step(measured: 1, dt: 10)          // a 10 s pause still moves at most 0.3 × 0.1 s
    #expect(abs(afterPause.displayed - 0.03) < 1e-9)
    model.reset()
    #expect(model.step(measured: 1, dt: 1.0 / 60).displayed == 1)
}
