// RepeatabilityTests — feature 177 (A24-P05) T-A24-503 (FR-A24-503; SC-A24-502; clarification Q3; User Story 2).
// Three comparable trials give their values by save order and the spread (largest minus smallest) of the interval
// p50, p95 and GPU p50; each not-comparable reason (another case, device, OS, build or tier, a missing report, an
// invalid trial) is listed with its code; a single trial has no spread; a set where one comparable trial has no GPU
// distribution has interval spreads but no GPU spread. Synthetic values only.
import Testing
@testable import GraphicsBenchmarkLabCore

@Suite struct RepeatabilityTests {
    /// A completed quads run with the given interval p50 and p95, GPU p50 and report.
    private static func run(p50: Double, p95: Double?, gpuP50: Double?,
                            report: RunReport? = QualificationFixture.report()) throws -> BenchmarkRun {
        try QualificationFixture.run(summary: QualificationFixture.summary(p50: p50, p95: p95, gpuP50: gpuP50),
                                     report: report)
    }

    @Test func threeComparableTrialsAndTheirSpread() throws {
        let opened = OrderedRun(order: 2, run: try Self.run(p50: 16.5, p95: 17.25, gpuP50: 4.5))
        let first = OrderedRun(order: 1, run: try Self.run(p50: 16.75, p95: 18.0, gpuP50: 4.25))
        let third = OrderedRun(order: 3, run: try Self.run(p50: 16.25, p95: 17.5, gpuP50: 5.0))
        let summary = Repeatability.summarise(opened: opened, among: [third, opened, first])
        #expect(summary.comparable == [
            Trial(order: 1, intervalP50: 16.75, intervalP95: 18.0, gpuP50: 4.25),
            Trial(order: 2, intervalP50: 16.5, intervalP95: 17.25, gpuP50: 4.5),
            Trial(order: 3, intervalP50: 16.25, intervalP95: 17.5, gpuP50: 5.0),
        ])
        #expect(summary.notComparable.isEmpty)
        #expect(summary.spreadP50Ms == 0.5)
        #expect(summary.spreadP95Ms == 0.75)
        #expect(summary.spreadGPUP50Ms == 0.75)
    }

    @Test func theOpenedRunIsIncludedWhenNotListed() throws {
        let opened = OrderedRun(order: 5, run: try Self.run(p50: 16.0, p95: 17.0, gpuP50: nil))
        let other = OrderedRun(order: 4, run: try Self.run(p50: 17.0, p95: 18.5, gpuP50: nil))
        let summary = Repeatability.summarise(opened: opened, among: [other])
        var orders: [Int] = []
        for trial in summary.comparable { orders.append(trial.order) }
        #expect(orders == [4, 5])
        #expect(summary.spreadP50Ms == 1.0 && summary.spreadP95Ms == 1.5)
        #expect(summary.spreadGPUP50Ms == nil)
    }

    @Test func eachNotComparableReason() throws {
        let opened = OrderedRun(order: 1, run: try Self.run(p50: 16.5, p95: 17.0, gpuP50: 4.5))
        let particles = try QualificationFixture.run(benchmarkCase: .particles)
        let stopped = try QualificationFixture.run(state: .stopped)
        let others: [BenchmarkRun] = [
            particles,
            try Self.run(p50: 16.5, p95: 17.0, gpuP50: 4.5,
                         report: QualificationFixture.report(deviceModel: "iPad99,1")),
            try Self.run(p50: 16.5, p95: 17.0, gpuP50: 4.5, report: QualificationFixture.report(osVersion: "26.5")),
            try Self.run(p50: 16.5, p95: 17.0, gpuP50: 4.5, report: QualificationFixture.report(appBuild: "2")),
            try Self.run(p50: 16.5, p95: 17.0, gpuP50: 4.5,
                         report: QualificationFixture.report(qualityTier: "level-1")),
            try Self.run(p50: 16.5, p95: 17.0, gpuP50: 4.5, report: nil),
            stopped,
        ]
        var among: [OrderedRun] = []
        for (index, run) in others.enumerated() { among.append(OrderedRun(order: index + 2, run: run)) }
        let summary = Repeatability.summarise(opened: opened, among: among)
        #expect(summary.notComparable == [
            NotComparableTrial(order: 2, reason: .differentCase),
            NotComparableTrial(order: 3, reason: .differentDevice),
            NotComparableTrial(order: 4, reason: .differentOS),
            NotComparableTrial(order: 5, reason: .differentBuild),
            NotComparableTrial(order: 6, reason: .differentTier),
            NotComparableTrial(order: 7, reason: .differentDevice),
            NotComparableTrial(order: 8, reason: .invalid),
        ])
        let comparableCount = summary.comparable.count
        #expect(comparableCount == 1)
        #expect(summary.spreadP50Ms == nil && summary.spreadP95Ms == nil && summary.spreadGPUP50Ms == nil)
        var codes: [String] = []
        for reason in [NotComparableReason.differentCase, .differentDevice, .differentOS, .differentBuild,
                       .differentTier, .invalid] { codes.append(reason.rawValue) }
        #expect(codes == ["different-case", "different-device", "different-os", "different-build", "different-tier",
                          "invalid"])
    }

    @Test func theFirstDifferenceInTheFixedOrderIsGiven() throws {
        let opened = try Self.run(p50: 16.5, p95: 17.0, gpuP50: 4.5)
        let report = QualificationFixture.report(osVersion: "26.5", appBuild: "2", qualityTier: "level-1")
        let differsLater = try Self.run(p50: 16.5, p95: 17.0, gpuP50: 4.5, report: report)
        let osFirst = Repeatability.reason(differsLater, against: opened)
        #expect(osFirst == .differentOS)
        let withoutReport = try Self.run(p50: 16.5, p95: 17.0, gpuP50: 4.5, report: nil)
        let openedWithoutReport = Repeatability.reason(opened, against: withoutReport)
        #expect(openedWithoutReport == .differentDevice)
        let qualified = try Self.run(p50: 16.5, p95: 17.0, gpuP50: 4.5,
                                     report: QualificationFixture.report(thermalEnd: "fair"))
        let comparable = Repeatability.reason(qualified, against: opened)
        #expect(comparable == nil)
    }

    @Test func oneTrialHasNoSpread() throws {
        let opened = OrderedRun(order: 1, run: try Self.run(p50: 16.5, p95: 17.0, gpuP50: 4.5))
        let summary = Repeatability.summarise(opened: opened, among: [opened])
        #expect(summary.comparable == [Trial(order: 1, intervalP50: 16.5, intervalP95: 17.0, gpuP50: 4.5)])
        #expect(summary.spreadP50Ms == nil && summary.spreadP95Ms == nil && summary.spreadGPUP50Ms == nil)
    }

    @Test func aMixedGPUSetHasNoGPUSpread() throws {
        let opened = OrderedRun(order: 1, run: try Self.run(p50: 16.5, p95: 17.0, gpuP50: 4.5))
        let withoutGPU = OrderedRun(order: 2, run: try Self.run(p50: 17.5, p95: 18.0, gpuP50: nil))
        let withGPU = OrderedRun(order: 3, run: try Self.run(p50: 16.0, p95: 17.5, gpuP50: 5.5))
        let summary = Repeatability.summarise(opened: opened, among: [withoutGPU, withGPU])
        let comparableCount = summary.comparable.count
        #expect(comparableCount == 3)
        #expect(summary.spreadP50Ms == 1.5 && summary.spreadP95Ms == 1.0)
        #expect(summary.spreadGPUP50Ms == nil)
    }

    @Test func aMissingP95IsLeftOutOfItsSpread() throws {
        let opened = OrderedRun(order: 1, run: try Self.run(p50: 16.5, p95: nil, gpuP50: nil))
        let other = OrderedRun(order: 2, run: try Self.run(p50: 16.75, p95: 17.0, gpuP50: nil))
        let summary = Repeatability.summarise(opened: opened, among: [other])
        #expect(summary.spreadP50Ms == 0.25)
        #expect(summary.spreadP95Ms == nil)
    }
}
