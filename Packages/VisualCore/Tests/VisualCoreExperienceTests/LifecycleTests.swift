// LifecycleTests — feature 188 T-U02-010 (FR-U02-001 to FR-U02-006, SC-U02-001; US1). The two tables of
// data-model.md sections 1 and 2 are written out here a second time, so the test does not take its expectation
// from the code under test.
import Foundation
import Testing
import VisualCoreExperience

@Suite struct LifecycleTests {
    private typealias State = ExperienceLifecycleState
    private typealias Operation = ExperienceOperation

    /// data-model.md section 1: the legal targets of each state.
    private static let legalTargets: [(from: State, to: [State])] = [
        (.registered, [.preparing, .failed]),
        (.preparing, [.ready, .deactivating, .failed]),
        (.ready, [.active, .deactivating, .failed]),
        (.active, [.suspended, .deactivating, .failed]),
        (.suspended, [.active, .deactivating, .failed]),
        (.deactivating, [.inactive, .failed]),
        (.inactive, [.preparing, .failed]),
        (.failed, [.preparing, .deactivating]),
    ]

    /// data-model.md section 2: the states in which each operation is legal.
    private static let legalStates: [(operation: Operation, states: [State])] = [
        (.prepare, [.registered, .inactive, .failed]),
        (.activate, [.ready]),
        (.update, [.active]),
        (.action, [.active]),
        (.snapshot, [.ready, .active, .suspended]),
        (.restore, [.ready, .active, .suspended]),
        (.reset, [.ready, .active, .suspended]),
        (.setQualityTier, [.ready, .active, .suspended]),
        (.shedCaches, [.ready, .active, .suspended]),
        (.suspend, [.active]),
        (.resume, [.suspended]),
        (.deactivate, [.preparing, .ready, .active, .suspended, .failed]),
    ]

    private static func expectsTransition(from: State, to: State) -> Bool {
        legalTargets.contains { $0.from == from && $0.to.contains(to) }
    }

    private static func expectsOperation(_ operation: Operation, in state: State) -> Bool {
        legalStates.contains { $0.operation == operation && $0.states.contains(state) }
    }

    /// The accepted transitions that lead a new lifecycle to each state without a stored error.
    private static func path(to state: State) -> [State] {
        switch state {
        case .registered: []
        case .preparing: [.preparing]
        case .ready: [.preparing, .ready]
        case .active: [.preparing, .ready, .active]
        case .suspended: [.preparing, .ready, .active, .suspended]
        case .deactivating: [.preparing, .deactivating]
        case .inactive: [.preparing, .deactivating, .inactive]
        case .failed: [.failed]
        }
    }

    private static func lifecycle(in state: State, historyLimit: Int = 64) -> ExperienceLifecycle {
        var lifecycle = ExperienceLifecycle(historyLimit: historyLimit)
        for next in path(to: state) { lifecycle.transition(to: next) }
        return lifecycle
    }

    private static func refusal(_ lifecycle: inout ExperienceLifecycle, _ operation: Operation) -> ExperienceError? {
        do {
            try lifecycle.permit(operation)
            return nil
        } catch {
            return error
        }
    }

    private static let sampleFailure = ExperienceFailure(code: "sample.broken", message: "the sample broke")
    private static let unspecified = ExperienceFailure(code: "experience.unspecified", message: "")

    @Test func newLifecycleIsRegistered() {
        let lifecycle = ExperienceLifecycle()
        #expect(lifecycle.state == .registered)
        #expect(lifecycle.lastError == nil)
        #expect(lifecycle.history.isEmpty)
        #expect(lifecycle.rejectedTransitions == 0)
        #expect(lifecycle.rejectedOperations == 0)
        #expect(lifecycle.historyLimit == 64)
        #expect(lifecycle == ExperienceLifecycle(historyLimit: 64))
    }

    @Test func helperPathsReachEveryState() {
        #expect(State.allCases.count == 8)
        for state in State.allCases {
            let lifecycle = Self.lifecycle(in: state)
            #expect(lifecycle.state == state)
            #expect(lifecycle.rejectedTransitions == 0)
            #expect(lifecycle.history.count == Self.path(to: state).count)
            let allAccepted1 = lifecycle.history.allSatisfy { $0.accepted }
            #expect(allAccepted1)
        }
    }

    @Test func tablesOfTheDataModelHaveTheStatedSizes() {
        #expect(Self.legalTargets.count == 8)
        #expect(Set(Self.legalTargets.map(\.from)) == Set(State.allCases))
        #expect(Self.legalTargets.reduce(0) { $0 + $1.to.count } == 20)
        #expect(Self.legalStates.count == 12)
        #expect(Set(Self.legalStates.map(\.operation)) == Set(Operation.allCases))
        #expect(Self.legalStates.reduce(0) { $0 + $1.states.count } == 28)
    }

    @Test func all64OrderedPairsFollowTheTransitionTable() {
        var accepted = 0
        var rejected = 0
        for from in State.allCases {
            for to in State.allCases {
                let expected = Self.expectsTransition(from: from, to: to)
                #expect(ExperienceLifecycle.isAllowed(from: from, to: to) == expected, "\(from) -> \(to)")

                var lifecycle = Self.lifecycle(in: from)
                let before = lifecycle
                let result = lifecycle.transition(to: to)
                #expect(result == expected, "\(from) -> \(to)")
                #expect(lifecycle.history.count == before.history.count + 1)
                #expect(lifecycle.history.last == ExperienceLifecycleEvent(from: from, to: to, accepted: expected))
                #expect(lifecycle.rejectedOperations == 0)
                if expected {
                    accepted += 1
                    #expect(lifecycle.state == to)
                    #expect(lifecycle.rejectedTransitions == 0)
                } else {
                    rejected += 1
                    #expect(lifecycle.state == from)
                    #expect(lifecycle.rejectedTransitions == 1)
                    #expect(lifecycle.lastError == before.lastError)
                }
            }
        }
        #expect(accepted == 20)
        #expect(rejected == 44)
    }

    @Test func aStateToItselfIsNeverAllowed() {
        for state in State.allCases {
            #expect(!ExperienceLifecycle.isAllowed(from: state, to: state))
        }
    }

    @Test func rejectionsAddExactlyOneEach() {
        var lifecycle = ExperienceLifecycle()
        let applied1 = lifecycle.transition(to: .active)
        #expect(!applied1)
        let applied2 = lifecycle.transition(to: .registered)
        #expect(!applied2)
        let applied3 = lifecycle.transition(to: .inactive)
        #expect(!applied3)
        #expect(lifecycle.state == .registered)
        #expect(lifecycle.rejectedTransitions == 3)
        #expect(lifecycle.history == [
            ExperienceLifecycleEvent(from: .registered, to: .active, accepted: false),
            ExperienceLifecycleEvent(from: .registered, to: .registered, accepted: false),
            ExperienceLifecycleEvent(from: .registered, to: .inactive, accepted: false),
        ])
        let applied4 = lifecycle.transition(to: .preparing)
        #expect(applied4)
        #expect(lifecycle.rejectedTransitions == 3)
    }

    @Test func all96OperationCellsFollowTheOperationTable() {
        var legal = 0
        var illegal = 0
        for state in State.allCases {
            for operation in Operation.allCases {
                let expected = Self.expectsOperation(operation, in: state)
                #expect(ExperienceLifecycle.isLegal(operation, in: state) == expected, "\(operation) in \(state)")

                var lifecycle = Self.lifecycle(in: state)
                let before = lifecycle
                let error = Self.refusal(&lifecycle, operation)
                #expect(lifecycle.state == state)
                #expect(lifecycle.history == before.history)
                #expect(lifecycle.lastError == before.lastError)
                #expect(lifecycle.rejectedTransitions == 0)
                if expected {
                    legal += 1
                    #expect(error == nil, "\(operation) in \(state)")
                    #expect(lifecycle.rejectedOperations == 0)
                    #expect(lifecycle == before)
                } else {
                    illegal += 1
                    #expect(error == .illegalOperation(operation, in: state), "\(operation) in \(state)")
                    #expect(lifecycle.rejectedOperations == 1)
                }
            }
        }
        #expect(Operation.allCases.count == 12)
        #expect(legal == 28)
        #expect(illegal == 68)
    }

    @Test func refusedOperationsAreCountedOneByOne() {
        var lifecycle = Self.lifecycle(in: .suspended)
        #expect(Self.refusal(&lifecycle, .action) == .illegalOperation(.action, in: .suspended))
        #expect(Self.refusal(&lifecycle, .update) == .illegalOperation(.update, in: .suspended))
        #expect(Self.refusal(&lifecycle, .resume) == nil)
        #expect(Self.refusal(&lifecycle, .prepare) == .illegalOperation(.prepare, in: .suspended))
        #expect(lifecycle.rejectedOperations == 3)
        #expect(lifecycle.rejectedTransitions == 0)
        #expect(lifecycle.state == .suspended)
    }

    @Test func sevenTransitionWalkOfScenarioOne() {
        let walk: [State] = [.preparing, .ready, .active, .suspended, .active, .deactivating, .inactive]
        var lifecycle = ExperienceLifecycle()
        var previous = State.registered
        var expectedHistory: [ExperienceLifecycleEvent] = []
        for next in walk {
            let applied5 = lifecycle.transition(to: next)
            #expect(applied5)
            #expect(lifecycle.state == next)
            expectedHistory.append(ExperienceLifecycleEvent(from: previous, to: next, accepted: true))
            previous = next
        }
        #expect(lifecycle.state == .inactive)
        #expect(lifecycle.rejectedTransitions == 0)
        #expect(lifecycle.rejectedOperations == 0)
        #expect(lifecycle.lastError == nil)
        #expect(lifecycle.history.count == 7)
        #expect(lifecycle.history == expectedHistory)
        // Re-entry (scenario 4).
        let applied6 = lifecycle.transition(to: .preparing)
        #expect(applied6)
        #expect(lifecycle.state == .preparing)
    }

    @Test func failStoresTheFailureInEveryStateButFailed() {
        for state in State.allCases where state != .failed {
            var lifecycle = Self.lifecycle(in: state)
            let events = lifecycle.history.count
            let applied7 = lifecycle.fail(Self.sampleFailure)
            #expect(applied7)
            #expect(lifecycle.state == .failed)
            #expect(lifecycle.lastError == Self.sampleFailure)
            #expect(lifecycle.rejectedTransitions == 0)
            #expect(lifecycle.history.count == events + 1)
            #expect(lifecycle.history.last == ExperienceLifecycleEvent(from: state, to: .failed, accepted: true))
            // Scenario 3: it can be prepared again, and the error stays readable.
            let applied8 = lifecycle.transition(to: .preparing)
            #expect(applied8)
            #expect(lifecycle.state == .preparing)
            #expect(lifecycle.lastError == Self.sampleFailure)
        }
    }

    @Test func failIsRejectedInFailedAndKeepsTheStoredError() {
        var lifecycle = ExperienceLifecycle()
        let applied9 = lifecycle.fail(Self.sampleFailure)
        #expect(applied9)
        let other = ExperienceFailure(code: "sample.other", message: "another one")
        let applied10 = lifecycle.fail(other)
        #expect(!applied10)
        #expect(lifecycle.state == .failed)
        #expect(lifecycle.lastError == Self.sampleFailure)
        #expect(lifecycle.rejectedTransitions == 1)
        #expect(lifecycle.history.last == ExperienceLifecycleEvent(from: .failed, to: .failed, accepted: false))
        let applied11 = lifecycle.transition(to: .failed)
        #expect(!applied11)
        #expect(lifecycle.lastError == Self.sampleFailure)
        #expect(lifecycle.rejectedTransitions == 2)
        #expect(lifecycle.history.count == 3)
    }

    @Test func transitionToFailedStoresTheUnspecifiedFailure() {
        for state in State.allCases where state != .failed {
            var lifecycle = Self.lifecycle(in: state)
            let applied12 = lifecycle.transition(to: .failed)
            #expect(applied12)
            #expect(lifecycle.state == .failed)
            #expect(lifecycle.lastError == Self.unspecified)
            #expect(lifecycle.lastError?.code == "experience.unspecified")
            #expect(lifecycle.lastError?.message == "")
        }
        // A later unspecified failure replaces a given one.
        var lifecycle = ExperienceLifecycle()
        lifecycle.fail(Self.sampleFailure)
        lifecycle.transition(to: .preparing)
        let applied13 = lifecycle.transition(to: .failed)
        #expect(applied13)
        #expect(lifecycle.lastError == Self.unspecified)
    }

    @Test func onlyPreparingToReadyClearsTheLastError() {
        // The states that can hold a stored error: failed and what is reachable from it without passing ready.
        let pathsWithError: [(state: State, path: [State])] = [
            (.failed, []),
            (.preparing, [.preparing]),
            (.deactivating, [.deactivating]),
            (.inactive, [.deactivating, .inactive]),
        ]
        var checked = 0
        var cleared = 0
        for entry in pathsWithError {
            for target in State.allCases where Self.expectsTransition(from: entry.state, to: target) {
                var lifecycle = ExperienceLifecycle()
                lifecycle.fail(Self.sampleFailure)
                for next in entry.path { lifecycle.transition(to: next) }
                #expect(lifecycle.state == entry.state)
                #expect(lifecycle.lastError == Self.sampleFailure)
                let applied14 = lifecycle.transition(to: target)
                #expect(applied14)
                checked += 1
                if entry.state == .preparing, target == .ready {
                    cleared += 1
                    #expect(lifecycle.lastError == nil)
                } else if target == .failed {
                    #expect(lifecycle.lastError == Self.unspecified)
                } else {
                    #expect(lifecycle.lastError == Self.sampleFailure, "\(entry.state) -> \(target)")
                }
            }
        }
        #expect(checked == 9)
        #expect(cleared == 1)

        // Without a stored error, no transition other than one into failed creates one.
        for from in State.allCases where from != .failed {
            for target in State.allCases where target != .failed && Self.expectsTransition(from: from, to: target) {
                var lifecycle = Self.lifecycle(in: from)
                #expect(lifecycle.lastError == nil)
                let applied15 = lifecycle.transition(to: target)
                #expect(applied15)
                #expect(lifecycle.lastError == nil, "\(from) -> \(target)")
            }
        }
    }

    @Test func lastErrorStaysReadableUntilThePreparationSucceeds() {
        var lifecycle = ExperienceLifecycle()
        lifecycle.transition(to: .preparing)
        lifecycle.fail(Self.sampleFailure)
        #expect(lifecycle.lastError == Self.sampleFailure)
        lifecycle.transition(to: .preparing)
        #expect(lifecycle.lastError == Self.sampleFailure)
        let applied16 = lifecycle.transition(to: .active)
        #expect(!applied16)
        #expect(lifecycle.lastError == Self.sampleFailure)
        let applied17 = lifecycle.transition(to: .ready)
        #expect(applied17)
        #expect(lifecycle.lastError == nil)
        let applied18 = lifecycle.transition(to: .active)
        #expect(applied18)
        #expect(lifecycle.lastError == nil)
    }

    @Test func historyLimitDefaultsTo64AndIsClampedToOne() {
        #expect(ExperienceLifecycle().historyLimit == 64)
        #expect(ExperienceLifecycle(historyLimit: 5).historyLimit == 5)
        #expect(ExperienceLifecycle(historyLimit: 1).historyLimit == 1)
        #expect(ExperienceLifecycle(historyLimit: 0).historyLimit == 1)
        #expect(ExperienceLifecycle(historyLimit: -7).historyLimit == 1)
        #expect(ExperienceLifecycle(historyLimit: Int.min).historyLimit == 1)
    }

    @Test func historyKeepsAtMostTheLimitAndDropsTheOldestFirst() {
        // Default limit: 70 attempts (suspend and resume in turn) leave the last 64.
        var lifecycle = Self.lifecycle(in: .active)
        #expect(lifecycle.history.count == 3)
        var all = lifecycle.history
        for index in 0..<70 {
            let from = lifecycle.state
            let next: State = index.isMultiple(of: 2) ? .suspended : .active
            let applied19 = lifecycle.transition(to: next)
            #expect(applied19)
            all.append(ExperienceLifecycleEvent(from: from, to: next, accepted: true))
            #expect(lifecycle.history.count == min(64, all.count))
        }
        #expect(all.count == 73)
        #expect(lifecycle.history == Array(all.suffix(64)))

        // A small limit, with rejected attempts in the history.
        var small = ExperienceLifecycle(historyLimit: 3)
        small.transition(to: .preparing)
        small.transition(to: .active)
        small.transition(to: .ready)
        small.transition(to: .active)
        small.transition(to: .registered)
        #expect(small.history == [
            ExperienceLifecycleEvent(from: .preparing, to: .ready, accepted: true),
            ExperienceLifecycleEvent(from: .ready, to: .active, accepted: true),
            ExperienceLifecycleEvent(from: .active, to: .registered, accepted: false),
        ])
        #expect(small.rejectedTransitions == 2)

        // A limit below 1 becomes 1: only the latest attempt is kept.
        var one = ExperienceLifecycle(historyLimit: 0)
        one.transition(to: .preparing)
        one.transition(to: .ready)
        #expect(one.history == [ExperienceLifecycleEvent(from: .preparing, to: .ready, accepted: true)])
        let applied20 = one.transition(to: .ready)
        #expect(!applied20)
        #expect(one.history == [ExperienceLifecycleEvent(from: .ready, to: .ready, accepted: false)])
        #expect(one.rejectedTransitions == 1)
    }
}
