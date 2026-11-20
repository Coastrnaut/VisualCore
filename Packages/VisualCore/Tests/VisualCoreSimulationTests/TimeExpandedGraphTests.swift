// TimeExpandedGraphTests — feature 216 (R02-F16) T-R02F16-004 (FR-R02F16-003; SC-R02F16-002; clarification Q3;
// research R6). 200 seeded schedules on small grids, with waiting allowed and forbidden, against a step-by-step reference
// simulation of the set of reachable cells; every route state is open and every step a move or an allowed wait; an
// unreachable proof holds the start state, no goal state and is closed. Mismatched schedules, closed starts, bad start
// times and nodes outside the graph are refused.
// Test data uses explicit types and plain loops (CI type-check rule).
import Testing
@testable import VisualCoreSimulation

@Suite struct TimeExpandedGraphTests {
    /// The reachable cells at each time from `startTime`, advanced one step at a time; index 0 is `startTime`.
    private func referenceLayers(graph: RouteGraph, schedule: RouteSchedule, from: Int, startTime: Int,
                                 allowWaiting: Bool) -> [Set<Int>] {
        var layers: [Set<Int>] = [[from]]
        var t = startTime
        while t + 1 < schedule.steps {
            var next = Set<Int>()
            for v in layers[layers.count - 1] {
                for edge in graph.edges(from: v) where schedule.isOpen(edge.to, at: t + 1) { next.insert(edge.to) }
                if allowWaiting && schedule.isOpen(v, at: t + 1) { next.insert(v) }
            }
            layers.append(next)
            t += 1
        }
        return layers
    }

    @Test func seededSchedulesMatchReferenceSimulation() throws {
        var random = SeededRandom(seed: 2_016)
        var arrivedCount = 0
        var unreachableCount = 0
        for round in 0..<200 {
            let width = random.int(1...8)
            let height = random.int(1...8)
            let neighbourhood: GridNeighbourhood = random.int(0...1) == 0 ? .four : .eight
            let grid = try GridGraph(width: width, height: height, neighbourhood: neighbourhood)
            let graph = grid.graph()
            let n = graph.nodeCount
            let steps = random.int(1...40)
            let from = random.int(0...(n - 1))
            let to = random.int(0...(n - 1))
            let startTime = random.int(0...(steps - 1))
            let allowWaiting = round % 2 == 0
            var openBits: [Bool] = []
            for _ in 0..<(n * steps) { openBits.append(random.double() < 0.7) }
            openBits[startTime * n + from] = true
            let bits = openBits
            let schedule = try RouteSchedule(cellCount: n, steps: steps) { cell, time in bits[time * n + cell] }

            let layers = referenceLayers(graph: graph, schedule: schedule, from: from, startTime: startTime,
                                         allowWaiting: allowWaiting)
            var expectedArrival: Int? = nil
            for (offset, layer) in layers.enumerated() where layer.contains(to) {
                expectedArrival = startTime + offset
                break
            }

            let outcome = try TimeExpandedGraph.earliestArrival(in: graph, schedule: schedule, from: from, to: to,
                                                                startTime: startTime, allowWaiting: allowWaiting)
            switch outcome {
            case let .arrived(states, certificate):
                arrivedCount += 1
                #expect(certificate == .timedRoute(states: states, allowWaiting: allowWaiting))
                #expect(states.first == TimedState(node: from, time: startTime))
                #expect(states.last?.node == to)
                #expect(states.last?.time == expectedArrival)
                for state in states { #expect(schedule.isOpen(state.node, at: state.time)) }
                for i in 1..<max(1, states.count) {
                    let a = states[i - 1]
                    let b = states[i]
                    #expect(b.time == a.time + 1)
                    let isMove = graph.hasEdge(from: a.node, to: b.node)
                    let isWait = allowWaiting && a.node == b.node
                    #expect(isMove || isWait)
                }
            case let .unreachable(certificate):
                unreachableCount += 1
                #expect(expectedArrival == nil)
                guard case let .timedUnreachable(start, goal, certStart, certWaiting, reachable) = certificate else {
                    Issue.record("wrong certificate kind \(certificate.kind)")
                    continue
                }
                #expect(start == from && goal == to && certStart == startTime && certWaiting == allowWaiting)
                let sorted = reachable.sorted { ($0.time, $0.node) < ($1.time, $1.node) }
                #expect(reachable == sorted)
                let members = Set<TimedState>(reachable)
                #expect(members.count == reachable.count)
                #expect(members.contains(TimedState(node: from, time: startTime)))
                var referenceCount = 0
                for layer in layers { referenceCount += layer.count }
                #expect(members.count == referenceCount)
                for state in reachable {
                    #expect(state.node != to)
                    #expect(schedule.isOpen(state.node, at: state.time))
                    let next = state.time + 1
                    guard next < steps else { continue }
                    var successors: [Int] = graph.edges(from: state.node).map(\.to)
                    if allowWaiting { successors.append(state.node) }
                    for w in successors where schedule.isOpen(w, at: next) {
                        #expect(members.contains(TimedState(node: w, time: next)))
                    }
                }
            }
        }
        #expect(arrivedCount > 20)
        #expect(unreachableCount > 20)
    }

    @Test func waitingMattersAndStartEqualsGoal() throws {
        // A line 0 – 1 – 2; cell 1 is closed at t = 1 only. With waiting the route waits at 0 and arrives at t = 3.
        let graph = try GridGraph(width: 3, height: 1).graph()
        let schedule = try RouteSchedule(cellCount: 3, steps: 5) { cell, time in !(cell == 1 && time == 1) }
        let waited = try TimeExpandedGraph.earliestArrival(in: graph, schedule: schedule, from: 0, to: 2)
        let expected: [TimedState] = [TimedState(node: 0, time: 0), TimedState(node: 0, time: 1),
                                      TimedState(node: 1, time: 2), TimedState(node: 2, time: 3)]
        #expect(waited == .arrived(states: expected, certificate: .timedRoute(states: expected, allowWaiting: true)))
        let forbidden = try TimeExpandedGraph.earliestArrival(in: graph, schedule: schedule, from: 0, to: 2,
                                                              allowWaiting: false)
        // Without waiting: 0@0 → 1@1 is closed, so the walk can never leave 0 and the goal is unreachable.
        guard case let .unreachable(certificate) = forbidden else {
            Issue.record("expected unreachable")
            return
        }
        #expect(certificate == .timedUnreachable(start: 0, goal: 2, startTime: 0, allowWaiting: false,
                                                 reachable: [TimedState(node: 0, time: 0)]))
        let same = try TimeExpandedGraph.earliestArrival(in: graph, schedule: schedule, from: 1, to: 1, startTime: 2)
        let one: [TimedState] = [TimedState(node: 1, time: 2)]
        #expect(same == .arrived(states: one, certificate: .timedRoute(states: one, allowWaiting: true)))
    }

    @Test func refusals() throws {
        let graph = try GridGraph(width: 2, height: 2).graph()
        let mismatched = try RouteSchedule(cellCount: 3, steps: 4) { _, _ in true }
        #expect(throws: RouteError.scheduleLimit) {
            try TimeExpandedGraph.earliestArrival(in: graph, schedule: mismatched, from: 0, to: 3)
        }
        let schedule = try RouteSchedule(cellCount: 4, steps: 4) { cell, time in !(cell == 0 && time == 0) }
        #expect(throws: RouteError.blockedEndpoint(0)) {
            try TimeExpandedGraph.earliestArrival(in: graph, schedule: schedule, from: 0, to: 3)
        }
        #expect(throws: RouteError.scheduleLimit) {
            try TimeExpandedGraph.earliestArrival(in: graph, schedule: schedule, from: 1, to: 3, startTime: 4)
        }
        #expect(throws: RouteError.scheduleLimit) {
            try TimeExpandedGraph.earliestArrival(in: graph, schedule: schedule, from: 1, to: 3, startTime: -1)
        }
        #expect(throws: RouteError.nodeRange(4)) {
            try TimeExpandedGraph.earliestArrival(in: graph, schedule: schedule, from: 4, to: 3)
        }
        #expect(throws: RouteError.nodeRange(-1)) {
            try TimeExpandedGraph.earliestArrival(in: graph, schedule: schedule, from: 1, to: -1)
        }
        #expect(RouteError.scheduleLimit.reasonCode == "r2-f16.schedule-limit")
    }
}
