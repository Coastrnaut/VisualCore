// QualityGovernorTests — feature 192 T-U06-005 (UA-F06; FR-U06-010 to FR-U06-012, FR-U06-014; SC-U06-003).
import Testing
@testable import VisualCoreDiagnostics

private typealias GovernorStep = (conditions: DeviceConditions, time: Double, level: Int)

private let hot = DeviceConditions(thermal: .serious, lowPower: false)
private let critical = DeviceConditions(thermal: .critical, lowPower: false)
private let fair = DeviceConditions(thermal: .fair, lowPower: false)
private let calm = DeviceConditions.nominal
private let saver = DeviceConditions(thermal: .nominal, lowPower: true)

/// 4 levels, automatic mode. Policy: Low Power ceiling 1, decision interval 2 s, calm period 10 s. Every step is at
/// least 1 s after the one before, so the governor passes every step to the policy. "change" is the time of the
/// last level change, "calm" the start of the unbroken calm.
private let governorScript: [GovernorStep] = [
    (calm, 0, 0),       //  1 start: level 0; calm starts at 0
    (hot, 1, 1),        //  2 serious, no change yet: down to 1; change = 1
    (hot, 2, 1),        //  3 2 − 1 = 1 s < 2 s: stays
    (hot, 3, 2),        //  4 3 − 1 = 2 s: down to 2; change = 3
    (critical, 4, 2),   //  5 4 − 3 = 1 s < 2 s: stays (never more than one level per interval)
    (critical, 5, 3),   //  6 5 − 3 = 2 s: down to 3; change = 5
    (hot, 7, 3),        //  7 last level: stays
    (hot, 9, 3),        //  8 last level: stays
    (calm, 10, 3),      //  9 calm starts at 10
    (fair, 19, 3),      // 10 9 s of calm < 10 s: stays
    (calm, 20, 2),      // 11 10 s of calm: up to 2; change = 20, calm = 20
    (calm, 29, 2),      // 12 9 s of calm: stays
    (calm, 30, 1),      // 13 10 s of calm: up to 1; change = 30, calm = 30
    (hot, 31, 1),       // 14 serious but 31 − 30 = 1 s < 2 s: stays; calm broken
    (calm, 32, 1),      // 15 calm starts at 32
    (hot, 33, 2),       // 16 33 − 30 = 3 s: down to 2; change = 33; calm broken
    (calm, 38, 2),      // 17 calm starts at 38
    (hot, 39, 3),       // 18 39 − 33 = 6 s: down to 3; change = 39; calm broken after 1 s
    (calm, 44, 3),      // 19 calm starts at 44
    (hot, 49, 3),       // 20 last level: stays; calm broken after 5 s
    (calm, 50, 3),      // 21 calm starts at 50
    (hot, 59, 3),       // 22 calm broken after 9 s: no step up under oscillation
    (calm, 60, 3),      // 23 calm starts at 60
    (calm, 70, 2),      // 24 10 s of calm: up to 2; change = 70, calm = 70
    (calm, 80, 1),      // 25 10 s of calm: up to 1; change = 80, calm = 80
    (calm, 90, 0),      // 26 10 s of calm: up to 0; change = 90, calm = 90
    (saver, 91, 0),     // 27 Low Power at level 0 wants level 1, but 91 − 90 = 1 s < 2 s: stays
    (saver, 92, 1),     // 28 92 − 90 = 2 s: down to the Low Power level 1; change = 92
    (saver, 110, 1),    // 29 Low Power at its ceiling: stays, no calm counted
    (saver, 130, 1),    // 30 still Low Power: no recovery
    (calm, 131, 1),     // 31 Low Power off: calm starts at 131
    (calm, 141, 0),     // 32 10 s of calm: up to 0
]

@Test func governorScriptInAutomaticMode() {
    #expect(governorScript.count >= 20)
    var g = QualityGovernor(levelCount: 4)
    #expect(g.levelInForce == 0 && g.pin == nil)
    for (index, step) in governorScript.enumerated() {
        let level = g.decide(conditions: step.conditions, now: step.time)
        #expect(level == step.level, "step \(index + 1) at \(step.time) s")
        #expect(g.levelInForce == level)
    }
    #expect(g.stepsDown == 6, "steps 2, 4, 6, 16, 18, 28")
    #expect(g.stepsUp == 6, "steps 11, 13, 24, 25, 26, 32")
}

@Test func governorScriptWithAPin() {
    var g = QualityGovernor(levelCount: 4, pin: 2)
    for (index, step) in governorScript.enumerated() {
        let level = g.decide(conditions: step.conditions, now: step.time)
        #expect(level == 2, "step \(index + 1): the pin holds")
    }
    #expect(g.levelInForce == 2)
    #expect(g.stepsDown == 0 && g.stepsUp == 0)
}

@Test func governorStepCountersEqualTheNumberOfChanges() {
    var g = QualityGovernor(levelCount: 4)
    var down = 0, up = 0, last = g.levelInForce
    for step in governorScript {
        let level = g.decide(conditions: step.conditions, now: step.time)
        if level > last { down += 1 }
        if level < last { up += 1 }
        last = level
    }
    #expect(g.stepsDown == down)
    #expect(g.stepsUp == up)
}

@Test func governorPinBeyondTheLastLevelGivesTheLastLevel() {
    var g = QualityGovernor(levelCount: 3, pin: 9)
    #expect(g.levelInForce == 2)
    let level = g.decide(conditions: hot, now: 0)
    #expect(level == 2)
    let negative = QualityGovernor(levelCount: 3, pin: -4)
    #expect(negative.levelInForce == 0)
}

@Test func governorDecisionsCloserThanOneSecondChangeNothing() {
    var g = QualityGovernor(levelCount: 4)
    let first = g.decide(conditions: calm, now: 0)
    #expect(first == 0)
    let tooSoon = g.decide(conditions: hot, now: 0.5)
    #expect(tooSoon == 0, "0.5 s after the last decision")
    let stillTooSoon = g.decide(conditions: hot, now: 0.99)
    #expect(stillTooSoon == 0)
    #expect(g.stepsDown == 0)
    let onTime = g.decide(conditions: hot, now: 1)
    #expect(onTime == 1, "1 s after the last decision")
    let backwards = g.decide(conditions: hot, now: 0.2)
    #expect(backwards == 1, "a time before the last decision changes nothing")
    let ignored = g.decide(conditions: hot, now: 1.9)
    #expect(ignored == 1)
    let next = g.decide(conditions: hot, now: 3.5)
    #expect(next == 2, "the skipped calls did not move the last decision time: 3.5 − 1 ≥ 2 s")
    #expect(g.stepsDown == 2)
}

@Test func governorNonFiniteTimeChangesNothing() {
    var g = QualityGovernor(levelCount: 4)
    let before = g
    let nan = g.decide(conditions: critical, now: .nan)
    #expect(nan == 0)
    let infinite = g.decide(conditions: critical, now: .infinity)
    #expect(infinite == 0)
    let negativeInfinite = g.decide(conditions: critical, now: -.infinity)
    #expect(negativeInfinite == 0)
    #expect(g == before)
    let real = g.decide(conditions: critical, now: 0)
    #expect(real == 1, "no decision time was remembered")
}

@Test func governorSetPinNilStartsFromLevelZero() {
    var g = QualityGovernor(levelCount: 4)
    let down = g.decide(conditions: hot, now: 0)
    #expect(down == 1)
    g.setPin(3)
    #expect(g.pin == 3 && g.levelInForce == 3)
    let pinned = g.decide(conditions: hot, now: 5)
    #expect(pinned == 3)
    #expect(g.stepsDown == 1, "no policy decision with a pin")
    let same = g
    g.setPin(3)
    #expect(g == same, "the same pin changes nothing")
    g.setPin(nil)
    #expect(g.pin == nil && g.levelInForce == 0)
    let again = g.decide(conditions: hot, now: 5.1)
    #expect(again == 1, "the timing was forgotten: a decision is possible at once")
    let automatic = g
    g.setPin(nil)
    #expect(g == automatic, "nil in automatic mode changes nothing")
}

@Test func governorWithOneLevelNeverSteps() {
    var g = QualityGovernor(levelCount: 1)
    for i in 0..<12 {
        let conditions = DeviceConditions(thermal: .critical, lowPower: i % 2 == 0)
        let level = g.decide(conditions: conditions, now: Double(i) * 3)
        #expect(level == 0)
    }
    #expect(g.stepsDown == 0 && g.stepsUp == 0)
}

@Test func governorLevelCountIsClamped() {
    #expect(QualityGovernor(levelCount: 0).levelCount == 1)
    #expect(QualityGovernor(levelCount: -3).levelCount == 1)
    #expect(QualityGovernor(levelCount: 99).levelCount == 8)
    #expect(QualityGovernor(levelCount: 5).levelCount == 5)
    #expect(QualityGovernor.minimumInterval == 1)
    #expect(QualityGovernor(levelCount: 99, pin: 99).levelInForce == 7)
}

@Test func governorResumeRestartsTheCalmPeriod() {
    var g = QualityGovernor(levelCount: 3)
    let down = g.decide(conditions: hot, now: 0)
    #expect(down == 1)
    let calmStart = g.decide(conditions: calm, now: 1)
    #expect(calmStart == 1, "calm starts at 1")
    let nineSeconds = g.decide(conditions: calm, now: 10)
    #expect(nineSeconds == 1, "9 s of calm")
    g.resume()
    #expect(g.levelInForce == 1, "a resume keeps the level")
    let afterResume = g.decide(conditions: calm, now: 11)
    #expect(afterResume == 1, "without the resume this would be 10 s of calm; calm starts again at 11")
    let nineMore = g.decide(conditions: calm, now: 20)
    #expect(nineMore == 1, "9 s after the first decision after the resume")
    let tenAfter = g.decide(conditions: calm, now: 21)
    #expect(tenAfter == 0, "10 s after the first decision after the resume")
    #expect(g.stepsDown == 1 && g.stepsUp == 1)
}

@Test func governorResumeAllowsADecisionAtOnce() {
    var g = QualityGovernor(levelCount: 3)
    let first = g.decide(conditions: hot, now: 0)
    #expect(first == 1)
    g.resume()
    let second = g.decide(conditions: hot, now: 0.5)
    #expect(second == 2, "the decision time and the last-change time were forgotten")
}
