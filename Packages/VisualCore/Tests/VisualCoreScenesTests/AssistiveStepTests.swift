// AssistiveStepTests — feature 222 (R02-F22) T-R02F22-006 (FR-R02F22-005, 007; SC-R02F22-005; clarification Q5).
import Foundation
import Testing
@testable import VisualCoreScenes

/// A small deterministic generator (SplitMix64) for seeded steps and ranges.
fileprivate struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z: UInt64 = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    /// A double in lower ..< upper.
    mutating func double(_ lower: Double, _ upper: Double) -> Double {
        let unit: Double = Double(next() >> 11) / Double(UInt64(1) << 53)
        return lower + (upper - lower) * unit
    }
}

/// One seeded control and a step count that stays inside its range.
fileprivate struct SeededCase {
    let control: AssistiveStep
    let steps: Int
}

fileprivate func seededCases() throws -> [SeededCase] {
    var random: SplitMix64 = SplitMix64(seed: 2_022)
    var cases: [SeededCase] = []
    for number in 0..<100 {
        let step: Double = random.double(0.001, 5)
        let width: Double = step * random.double(50, 500)
        let lower: Double = random.double(-1_000, 1_000)
        let upper: Double = lower + width
        // The start sits in the lower half, so at least 24 steps up and none down are known to stay in range.
        let start: Double = lower + width * random.double(0.25, 0.5)
        let steps: Int = 1 + Int(random.next() % 20)
        let control: AssistiveStep = try AssistiveStep(
            name: "Case \(number)", start: start, step: step, range: lower...upper)
        cases.append(SeededCase(control: control, steps: steps))
    }
    return cases
}

fileprivate func refusal(
    name: String = "Value", start: Double = 0, step: Double = 1, range: ClosedRange<Double> = -10...10
) -> SpatialControlError? {
    do {
        _ = try AssistiveStep(name: name, start: start, step: step, range: range)
        return nil
    } catch {
        return error
    }
}

@Suite("AssistiveStep")
struct AssistiveStepTests {
    @Test("100 seeded cases: n up then n down return exactly, pairs chain")
    func seededRoundTrip() throws {
        let cases: [SeededCase] = try seededCases()
        #expect(cases.count == 100)
        for seeded in cases {
            var control: AssistiveStep = seeded.control
            var previousAfter: Double = control.value
            #expect(control.value.bitPattern == control.start.bitPattern)
            for _ in 0..<seeded.steps {
                let pair: (before: Double, after: Double)? = control.increment()
                #expect(pair != nil)
                if let pair {
                    #expect(pair.before == previousAfter)
                    #expect(pair.after > pair.before)
                    #expect(pair.after == control.value)
                    #expect(control.range.contains(pair.after))
                    previousAfter = pair.after
                }
                #expect(!control.description.isEmpty)
            }
            #expect(control.index == seeded.steps)
            for _ in 0..<seeded.steps {
                let pair: (before: Double, after: Double)? = control.decrement()
                #expect(pair != nil)
                if let pair {
                    #expect(pair.before == previousAfter)
                    #expect(pair.after < pair.before)
                    #expect(pair.after == control.value)
                    previousAfter = pair.after
                }
                #expect(!control.description.isEmpty)
            }
            #expect(control.index == 0)
            #expect(control.value.bitPattern == seeded.control.start.bitPattern)
            #expect(control == seeded.control)
        }
    }

    @Test("A step past either limit returns nil and changes nothing")
    func limits() throws {
        let cases: [SeededCase] = try seededCases()
        for seeded in cases.prefix(20) {
            var control: AssistiveStep = seeded.control
            var guardCount: Int = 0
            while control.increment() != nil, guardCount < 1_000 { guardCount += 1 }
            #expect(guardCount < 1_000)
            let atTop: AssistiveStep = control
            #expect(control.increment() == nil)
            #expect(control == atTop)
            #expect(control.range.contains(control.value))
            #expect(control.value + control.step > control.range.upperBound)
            guardCount = 0
            while control.decrement() != nil, guardCount < 2_000 { guardCount += 1 }
            #expect(guardCount < 2_000)
            let atBottom: AssistiveStep = control
            #expect(control.decrement() == nil)
            #expect(control == atBottom)
            #expect(control.index < 0)
            #expect(control.range.contains(control.value))
            #expect(control.value - control.step < control.range.lowerBound)
        }
        // A start on the limit cannot step past it.
        var pinned: AssistiveStep = try AssistiveStep(name: "Pinned", start: 5, step: 1, range: 5...5)
        #expect(pinned.increment() == nil)
        #expect(pinned.decrement() == nil)
        #expect(pinned.index == 0)
        #expect(pinned.value == 5)
    }

    @Test("Descriptions match the examples")
    func descriptionExamples() throws {
        let height: AssistiveStep = try AssistiveStep(name: "Height", start: 1.25, step: 0.25, range: 0...5)
        #expect(height.description == "Height, 1.25")
        let angle: AssistiveStep = try AssistiveStep(name: "Angle", start: 90, step: 1, range: 0...360)
        #expect(angle.description == "Angle, 90")
        var size: AssistiveStep = try AssistiveStep(name: "Size", start: 0, step: 0.1, range: 0...1)
        for _ in 0..<3 { _ = size.increment() }
        #expect(size.value == 0.30000000000000004)
        #expect(size.description == "Size, 0.3")
        let half: AssistiveStep = try AssistiveStep(name: "Half", start: 2, step: 0.5, range: 0...5)
        #expect(half.description == "Half, 2.0")
        let tiny: AssistiveStep = try AssistiveStep(name: "Tiny", start: 0.000_123_4, step: 1e-7, range: 0...1)
        #expect(tiny.description == "Tiny, 0.000123")
        let large: AssistiveStep = try AssistiveStep(name: "Far", start: 1e20, step: 1e12, range: 1e20...2e20)
        #expect(large.description == "Far, 100000000000000000000")
    }

    @Test("Negative values print with a minus, never negative zero, locale-independent")
    func signsAndLocale() throws {
        var down: AssistiveStep = try AssistiveStep(name: "Depth", start: -1.5, step: 0.5, range: -3...3)
        #expect(down.description == "Depth, -1.5")
        _ = down.decrement()
        #expect(down.description == "Depth, -2.0")
        let negativeZero: AssistiveStep = try AssistiveStep(name: "Zero", start: -0.0, step: 1, range: -1...1)
        #expect(negativeZero.value.bitPattern == (-0.0 as Double).bitPattern)
        #expect(negativeZero.description == "Zero, 0")
        let roundsToZero: AssistiveStep = try AssistiveStep(name: "Near", start: -0.001, step: 0.5, range: -1...1)
        #expect(roundsToZero.description == "Near, 0.0")
        let cases: [SeededCase] = try seededCases()
        for seeded in cases {
            let text: String = seeded.control.description
            #expect(text.hasPrefix(seeded.control.name + ", "))
            let number: Substring = text.dropFirst(seeded.control.name.count + 2)
            #expect(!number.contains(","))
            var hasNonZeroDigit: Bool = false
            for character in number where character >= "1" && character <= "9" { hasNonZeroDigit = true }
            let isNegative: Bool = seeded.control.value < 0 && hasNonZeroDigit
            #expect(number.hasPrefix("-") == isNegative)
        }
    }

    @Test("Refusals carry reason codes")
    func refusals() {
        #expect(refusal(name: "") == .parameter("name"))
        #expect(refusal(step: 0) == .parameter("step"))
        #expect(refusal(step: -1) == .parameter("step"))
        #expect(refusal(step: .nan) == .parameter("step"))
        #expect(refusal(step: .infinity) == .parameter("step"))
        #expect(refusal(range: -Double.infinity...0) == .parameter("range"))
        #expect(refusal(range: 0...Double.infinity) == .parameter("range"))
        #expect(refusal(start: 0, step: 1, range: 0...1e10) == .parameter("range"))
        #expect(refusal(start: 0, step: 1, range: 0...1e9) == nil)
        #expect(refusal(start: 11) == .parameter("start"))
        #expect(refusal(start: -11) == .parameter("start"))
        #expect(refusal(start: .nan) == .parameter("start"))
        #expect(refusal(start: .infinity) == .parameter("start"))
        #expect(refusal(name: "")?.reasonCode == "r2-f22.parameter")
    }

    @Test("Reset returns to start")
    func reset() throws {
        var control: AssistiveStep = try AssistiveStep(name: "Turn", start: 0.7, step: 0.3, range: -5...5)
        for _ in 0..<5 { _ = control.increment() }
        #expect(control.index == 5)
        control.reset()
        #expect(control.index == 0)
        #expect(control.value.bitPattern == (0.7 as Double).bitPattern)
        for _ in 0..<4 { _ = control.decrement() }
        control.reset()
        #expect(control.value == 0.7)
    }

    @Test("Codable round trip; rule-breaking forms are refused")
    func codable() throws {
        var control: AssistiveStep = try AssistiveStep(name: "Height", start: 1.25, step: 0.25, range: 0...5)
        for _ in 0..<3 { _ = control.increment() }
        let data: Data = try JSONEncoder().encode(control)
        let decoded: AssistiveStep = try JSONDecoder().decode(AssistiveStep.self, from: data)
        #expect(decoded == control)
        #expect(decoded.value == 2)

        let broken: [String] = [
            #"{"name":"","start":0,"step":1,"lower":0,"upper":1,"index":0}"#,
            #"{"name":"A","start":0,"step":0,"lower":0,"upper":1,"index":0}"#,
            #"{"name":"A","start":0,"step":1,"lower":0,"upper":1e12,"index":0}"#,
            #"{"name":"A","start":2,"step":1,"lower":0,"upper":1,"index":0}"#,
            #"{"name":"A","start":0,"step":1,"lower":1,"upper":0,"index":0}"#,
            #"{"name":"A","start":0,"step":1,"lower":0,"upper":1,"index":2}"#,
            #"{"name":"A","start":0,"step":1,"lower":0,"upper":1,"index":-1}"#,
        ]
        for json in broken {
            var reason: String = ""
            do {
                _ = try JSONDecoder().decode(AssistiveStep.self, from: Data(json.utf8))
            } catch DecodingError.dataCorrupted(let context) {
                reason = context.debugDescription
            } catch {
                reason = "other: \(error)"
            }
            #expect(reason.hasPrefix("r2-f22.parameter"), "\(json) → \(reason)")
        }
        let indexBreak: String = broken[broken.count - 2]
        do {
            _ = try JSONDecoder().decode(AssistiveStep.self, from: Data(indexBreak.utf8))
        } catch DecodingError.dataCorrupted(let context) {
            #expect(context.debugDescription == "r2-f22.parameter (index)")
        }
    }
    /// Assistive steps are ordinary edits: recorded in a `ControlHistory`, undone and redone exactly.
    @Test func stepsAreRecordedAsHistoryEdits() throws {
        var step = try AssistiveStep(name: "Height", start: 1, step: 0.25, range: 0...3)
        var history = try ControlHistory<Double>()
        for _ in 0..<3 {
            let next: (before: Double, after: Double)? = step.increment()
            let pair = try #require(next)
            history.record(step.description, before: pair.before, after: pair.after)
        }
        #expect(step.value == 1.75 && history.undoCount == 3 && history.undoLabel == "Height, 1.75")
        var restored: Double = step.value
        while let value = history.undo() { restored = value }
        #expect(restored == 1)
        var replayed: Double = restored
        while let value = history.redo() { replayed = value }
        #expect(replayed == 1.75)
    }
}
