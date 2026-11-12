// SessionLifecycleTests — feature 189 T-U03-002 (FR-U03-001, FR-U03-080, FR-U03-081, FR-U03-100). The table of
// data-model.md section 1 and the orders of section 2 are written out here a second time, so the test does not
// take its expectation from the code under test.
import Foundation
import Testing
import VisualCoreExperience

@Suite struct SessionLifecycleTests {
    private typealias State = SessionState

    /// data-model.md section 1: the legal targets of each state.
    private static let legalTargets: [(from: State, to: [State])] = [
        (.idle, [.preparing]),
        (.preparing, [.running, .suspended, .failed, .closing]),
        (.running, [.suspended, .failed, .closing]),
        (.suspended, [.running, .failed, .closing]),
        (.failed, [.preparing, .idle]),
        (.message, [.idle, .preparing]),
        (.closing, [.idle, .message]),
    ]

    private static func expectsTransition(from: State, to: State) -> Bool {
        legalTargets.contains { $0.from == from && $0.to.contains(to) }
    }

    /// The accepted transitions that lead a new lifecycle to each state.
    private static func path(to state: State) -> [State] {
        switch state {
        case .idle: []
        case .preparing: [.preparing]
        case .running: [.preparing, .running]
        case .suspended: [.preparing, .suspended]
        case .failed: [.preparing, .failed]
        case .closing: [.preparing, .running, .closing]
        case .message: [.preparing, .running, .closing, .message]
        }
    }

    private static func lifecycle(in state: State) -> SessionLifecycle {
        var lifecycle = SessionLifecycle()
        for step in path(to: state) { lifecycle.transition(to: step) }
        return lifecycle
    }

    private static func sampleDiagnostics() throws -> SessionDiagnostics {
        let id = try ExperienceID("a05.infinite-geometry")
        var timings = SessionStageTimings()
        timings.prepare = 0.25
        timings.createHost = 0.5
        timings.activate = 0.125
        timings.firstFrame = 0.0625
        let inner = ExperienceDiagnostics(
            experience: id, state: .active, seed: 18_446_744_073_709_551_615, stepIndex: 7, qualityTier: 1,
            gpu: GPUResourceCounts(objects: 3, bytes: 4_096, leaked: 0), lastError: nil, digest: nil,
            rejectedTransitions: 0, rejectedOperations: 1, acceptedActions: 2, rejectedActions: 3, droppedTime: 0.5,
            invalidFrames: 4)
        let failure = SessionFailure(ExperienceFailure(code: "experience.gpu-leak", message: "1 object left"),
                                     stage: .close)
        return SessionDiagnostics(
            state: .running, experience: id, experienceDiagnostics: inner, timings: timings,
            lastCloseCounts: GPUResourceCounts(objects: 0, bytes: 0, leaked: 0), opens: 5, closes: 4, failures: 1,
            cancelledPreparations: 2, supersededOpens: 3, memoryClosures: 1, contextRecreations: 6, sinkFailures: 7,
            rejectedTransitions: 8, lastFailure: failure, lastCloseSteps: SessionCloseStep.order)
    }

    private static func idleDiagnostics() -> SessionDiagnostics {
        SessionDiagnostics(
            state: .idle, experience: nil, experienceDiagnostics: nil, timings: SessionStageTimings(),
            lastCloseCounts: nil, opens: 0, closes: 0, failures: 0, cancelledPreparations: 0, supersededOpens: 0,
            memoryClosures: 0, contextRecreations: 0, sinkFailures: 0, rejectedTransitions: 0, lastFailure: nil,
            lastCloseSteps: [])
    }

    // MARK: Lifecycle

    @Test func aNewLifecycleIsIdle() {
        let lifecycle = SessionLifecycle()
        #expect(lifecycle.state == .idle)
        #expect(lifecycle.rejectedTransitions == 0)
        #expect(lifecycle == SessionLifecycle())
    }

    @Test func theTableHasSeventeenLegalPairsOfFortyNine() {
        #expect(State.allCases.count == 7)
        #expect(Self.legalTargets.count == 7)
        #expect(Self.legalTargets.reduce(0) { $0 + $1.to.count } == 17)
        var accepted = 0, rejected = 0
        for from in State.allCases {
            for to in State.allCases {
                let expected = Self.expectsTransition(from: from, to: to)
                #expect(SessionLifecycle.isAllowed(from: from, to: to) == expected, "\(from) -> \(to)")
                if SessionLifecycle.isAllowed(from: from, to: to) { accepted += 1 } else { rejected += 1 }
            }
        }
        #expect(accepted == 17)
        #expect(rejected == 32)
    }

    @Test func aStateWithItselfIsNeverLegal() {
        for state in State.allCases { #expect(!SessionLifecycle.isAllowed(from: state, to: state), "\(state)") }
    }

    @Test func everyStateIsReachedWithoutARefusal() {
        for state in State.allCases {
            let lifecycle = Self.lifecycle(in: state)
            #expect(lifecycle.state == state)
            #expect(lifecycle.rejectedTransitions == 0, "path to \(state)")
        }
    }

    @Test func everyPairIsAppliedOrRefusedAsTheTableSays() {
        var accepted = 0, rejected = 0
        for from in State.allCases {
            for to in State.allCases {
                var lifecycle = Self.lifecycle(in: from)
                let before = lifecycle
                let result = lifecycle.transition(to: to)
                let expected = Self.expectsTransition(from: from, to: to)
                #expect(result == expected, "\(from) -> \(to)")
                if result {
                    accepted += 1
                    #expect(lifecycle.state == to, "\(from) -> \(to)")
                    #expect(lifecycle.rejectedTransitions == before.rejectedTransitions, "\(from) -> \(to)")
                } else {
                    rejected += 1
                    #expect(lifecycle.state == from, "\(from) -> \(to) keeps the state")
                    #expect(lifecycle.rejectedTransitions == before.rejectedTransitions + 1, "\(from) -> \(to)")
                }
            }
        }
        #expect(accepted == 17)
        #expect(rejected == 32)
        #expect(accepted + rejected == 49)
    }

    @Test func refusalsAddUp() {
        var lifecycle = SessionLifecycle()
        let first = lifecycle.transition(to: .running)
        let second = lifecycle.transition(to: .idle)
        let third = lifecycle.transition(to: .message)
        #expect(!first && !second && !third)
        #expect(lifecycle.state == .idle)
        #expect(lifecycle.rejectedTransitions == 3)
        let fourth = lifecycle.transition(to: .preparing)
        #expect(fourth)
        #expect(lifecycle.state == .preparing)
        #expect(lifecycle.rejectedTransitions == 3)
    }

    @Test func aFullSessionRunsThroughTheTable() {
        var lifecycle = SessionLifecycle()
        let steps: [State] = [
            .preparing, .suspended, .running, .suspended, .running, .closing, .message, .preparing, .failed,
            .preparing, .running, .failed, .idle, .preparing, .closing, .idle,
        ]
        for step in steps {
            let moved = lifecycle.transition(to: step)
            #expect(moved, "to \(step)")
        }
        #expect(lifecycle.state == .idle)
        #expect(lifecycle.rejectedTransitions == 0)
    }

    // MARK: Close order

    @Test func theCloseOrderIsTheSevenStepsOfTheDataModel() {
        let expected: [SessionCloseStep] = [
            .stopClock, .handOutSnapshot, .beginDeactivation, .destroyHost, .readCounts, .finishDeactivation,
            .becomeIdle,
        ]
        #expect(SessionCloseStep.order == expected)
        #expect(SessionCloseStep.order.map(\.rawValue) == [
            "stopClock", "handOutSnapshot", "beginDeactivation", "destroyHost", "readCounts", "finishDeactivation",
            "becomeIdle",
        ])
        #expect(SessionCloseStep.order.count == 7)
        #expect(Set(SessionCloseStep.order).count == 7)
        #expect(!SessionCloseStep.order.contains(.cancelPreparation))
    }

    @Test func theCancelOrderIsTheTwoStepsOfACancelledPreparation() {
        #expect(SessionCloseStep.cancelOrder == [.cancelPreparation, .becomeIdle])
        #expect(SessionCloseStep.cancelOrder.map(\.rawValue) == ["cancelPreparation", "becomeIdle"])
        #expect(SessionCloseStep.allCases.count == 8)
    }

    @Test func theOtherEnumerationsHaveTheCasesOfTheContract() {
        #expect(State.allCases.map(\.rawValue)
            == ["idle", "preparing", "running", "suspended", "failed", "message", "closing"])
        #expect(ScenePhaseInput.allCases.map(\.rawValue) == ["active", "inactive", "background"])
        #expect(SessionStage.allCases.map(\.rawValue)
            == ["prepare", "restore", "createHost", "setup", "draw", "context", "close"])
    }

    // MARK: Memory pressure

    @Test func theLimitIsTheRequestedValueElseHalfOfTheTotal() {
        #expect(MemoryPressureRule.limit(requested: 1_000, budgetTotal: 64) == 1_000)
        #expect(MemoryPressureRule.limit(requested: 1, budgetTotal: 1_000_000) == 1)
        #expect(MemoryPressureRule.limit(requested: nil, budgetTotal: 1_000) == 500)
        #expect(MemoryPressureRule.limit(requested: nil, budgetTotal: 268_435_456) == 134_217_728)
        #expect(MemoryPressureRule.limit(requested: nil, budgetTotal: 7) == 3)
    }

    @Test func theLimitIsNeverBelowOne() {
        #expect(MemoryPressureRule.limit(requested: 0, budgetTotal: 1_000) == 1)
        #expect(MemoryPressureRule.limit(requested: -5, budgetTotal: 1_000) == 1)
        #expect(MemoryPressureRule.limit(requested: nil, budgetTotal: 1) == 1)
        #expect(MemoryPressureRule.limit(requested: nil, budgetTotal: 0) == 1)
        #expect(MemoryPressureRule.limit(requested: nil, budgetTotal: -10) == 1)
        #expect(MemoryPressureRule.limit(requested: nil, budgetTotal: 2) == 1)
    }

    @Test func theSessionClosesOnlyAboveTheLimit() {
        #expect(!MemoryPressureRule.shouldClose(liveBytes: 0, limit: 500))
        #expect(!MemoryPressureRule.shouldClose(liveBytes: 499, limit: 500))
        #expect(!MemoryPressureRule.shouldClose(liveBytes: 500, limit: 500))
        #expect(MemoryPressureRule.shouldClose(liveBytes: 501, limit: 500))
        #expect(!MemoryPressureRule.shouldClose(liveBytes: 1, limit: 1))
        #expect(MemoryPressureRule.shouldClose(liveBytes: 2, limit: 1))
    }

    // MARK: Failure and timings

    @Test func theSessionCodesAreTheTextsOfTheContract() {
        #expect(SessionFailure.hostFailedCode == "session.host-failed")
        #expect(SessionFailure.contextLostCode == "session.context-lost")
        #expect(SessionFailure.sinkFailedCode == "session.sink-failed")
        for code in [SessionFailure.hostFailedCode, SessionFailure.contextLostCode, SessionFailure.sinkFailedCode] {
            #expect(ExperienceFailure.isValidCode(code), "\(code)")
            #expect(ExperienceFailure(code: code, message: "").code == code)
        }
    }

    @Test func aFailureKeepsCodeMessageAndStage() {
        let inner = ExperienceFailure(code: SessionFailure.hostFailedCode, message: "no render host")
        let failure = SessionFailure(inner, stage: .createHost)
        #expect(failure.failure == inner)
        #expect(failure.stage == .createHost)
        #expect(failure.code == "session.host-failed")
        #expect(failure.message == "no render host")
        #expect(failure != SessionFailure(inner, stage: .setup))
        let passed = SessionFailure(ExperienceError.preparationTimedOut.failure, stage: .prepare)
        #expect(passed.code == "experience.preparation-timeout")
    }

    @Test func aFailureSurvivesAJSONRoundTrip() throws {
        for stage in SessionStage.allCases {
            let failure = SessionFailure(ExperienceFailure(code: "test.failed", message: "failed at \(stage)"),
                                         stage: stage)
            let data = try JSONEncoder().encode(failure)
            let decoded = try JSONDecoder().decode(SessionFailure.self, from: data)
            #expect(decoded == failure, "\(stage)")
            #expect(decoded.stage == stage)
        }
    }

    @Test func timingsSurviveAJSONRoundTrip() throws {
        let empty = SessionStageTimings()
        #expect(empty.prepare == nil && empty.createHost == nil && empty.activate == nil && empty.firstFrame == nil)
        let emptyData = try JSONEncoder().encode(empty)
        #expect(String(data: emptyData, encoding: .utf8) == "{}")
        #expect(try JSONDecoder().decode(SessionStageTimings.self, from: emptyData) == empty)

        var partial = SessionStageTimings()
        partial.prepare = 0.25
        partial.createHost = 1.5
        let partialData = try JSONEncoder().encode(partial)
        let partialText = try #require(String(data: partialData, encoding: .utf8))
        #expect(!partialText.contains("activate") && !partialText.contains("firstFrame"))
        #expect(!partialText.contains("null"))
        #expect(try JSONDecoder().decode(SessionStageTimings.self, from: partialData) == partial)

        var full = partial
        full.activate = 0.125
        full.firstFrame = 0.0625
        let fullData = try JSONEncoder().encode(full)
        let decoded = try JSONDecoder().decode(SessionStageTimings.self, from: fullData)
        #expect(decoded == full)
        #expect(decoded != partial)
    }

    @Test func openResultsCompare() {
        let failure = SessionFailure(ExperienceFailure(code: "test.failed", message: "x"), stage: .draw)
        #expect(SessionOpenResult.failed(failure) == .failed(failure))
        #expect(SessionOpenResult.failed(failure) != .failed(SessionFailure(failure.failure, stage: .setup)))
        let all: [SessionOpenResult] = [.running, .suspended, .failed(failure), .cancelled, .superseded]
        for (i, a) in all.enumerated() {
            for (j, b) in all.enumerated() { #expect((a == b) == (i == j)) }
        }
    }

    // MARK: Diagnostics

    @Test func encodedDiagnosticsHaveSortedKeys() throws {
        let text = try #require(String(data: try Self.sampleDiagnostics().encoded(), encoding: .utf8))
        let keys = [
            "cancelledPreparations", "closes", "contextRecreations", "experience", "experienceDiagnostics",
            "failures", "lastCloseCounts", "lastCloseSteps", "lastFailure", "memoryClosures", "opens",
            "rejectedTransitions", "sinkFailures", "state", "supersededOpens", "timings",
        ]
        #expect(keys == keys.sorted())
        #expect(keys.count == 16)
        let object = try #require(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        #expect(object.keys.sorted() == keys)
        // Top-level keys stand in sorted order in the text. `"rejectedTransitions":8` is the session's own count
        // (the experience's count is 0), and the other keys occur once as a top-level key followed by a colon.
        var position = text.startIndex
        for key in keys {
            let needle = key == "rejectedTransitions" ? "\"rejectedTransitions\":8" : "\"\(key)\":"
            let topLevelID = "\"experience\":\"a05.infinite-geometry\",\"experienceDiagnostics\""
            let search = key == "experience" ? topLevelID : needle
            let range = try #require(text.range(of: search, range: position..<text.endIndex), "\(key) out of order")
            position = range.lowerBound
        }
        #expect(text.hasPrefix("{\"cancelledPreparations\":2,\"closes\":4,\"contextRecreations\":6,"))
        #expect(text.contains("\"seed\":\"18446744073709551615\""))
        #expect(!text.contains("\\/"))
    }

    @Test func encodedDiagnosticsDecodeToAnEqualValue() throws {
        let diagnostics = try Self.sampleDiagnostics()
        let data = try diagnostics.encoded()
        let decoded = try JSONDecoder().decode(SessionDiagnostics.self, from: data)
        #expect(decoded == diagnostics)
        #expect(try decoded.encoded() == data)
        #expect(decoded.lastCloseSteps == SessionCloseStep.order)
        #expect(decoded.lastFailure?.code == "experience.gpu-leak")
        #expect(decoded.lastFailure?.stage == .close)
        #expect(decoded.experienceDiagnostics?.seed == UInt64.max)
        #expect(decoded.timings.firstFrame == 0.0625)
    }

    @Test func absentItemsAreLeftOut() throws {
        let idle = Self.idleDiagnostics()
        let data = try idle.encoded()
        let text = try #require(String(data: data, encoding: .utf8))
        for key in ["experience", "experienceDiagnostics", "lastCloseCounts", "lastFailure"] {
            #expect(!text.contains("\"\(key)\""), "\(key) is written")
        }
        for key in ["prepare", "createHost", "activate", "firstFrame"] {
            #expect(!text.contains("\"\(key)\""), "\(key) is written")
        }
        #expect(!text.contains("null"))
        #expect(text.contains("\"timings\":{}"))
        #expect(text.contains("\"lastCloseSteps\":[]"))
        #expect(text.contains("\"state\":\"idle\""))
        let decoded = try JSONDecoder().decode(SessionDiagnostics.self, from: data)
        #expect(decoded == idle)
        #expect(decoded.experience == nil && decoded.experienceDiagnostics == nil)
        #expect(decoded.lastCloseCounts == nil && decoded.lastFailure == nil)
    }

    @Test func diagnosticsCompareByEveryField() throws {
        let base = try Self.sampleDiagnostics()
        var changed = base
        changed.sinkFailures += 1
        #expect(changed != base)
        changed = base
        changed.lastCloseSteps = SessionCloseStep.cancelOrder
        #expect(changed != base)
        changed = base
        changed.state = .suspended
        #expect(changed != base)
        #expect(try Self.sampleDiagnostics() == base)
    }
}
