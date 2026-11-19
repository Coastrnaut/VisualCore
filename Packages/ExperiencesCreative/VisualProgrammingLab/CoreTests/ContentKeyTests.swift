// ContentKeyTests — feature 168 (A23-P03) T-A23-302 (FR-A23-305; SC-A23-304; clarification Q3; User Story 4). Content
// keys are 64 hexadecimal digits, the same across runs and whatever the order of nodes and connections, and leave
// positions out; editing Gradient's angle in the journey graph marks Gradient, Mix, Blur and Output but not Noise; a
// node added or removed is marked; a new connection marks its target and everything downstream; a move marks nothing;
// every pass carries its node's key. Synthetic data only.
import Testing
import VisualProgrammingLabCore

@Suite struct ContentKeyTests {
    typealias F = GraphFixtures
    typealias C = CompilerFixtures

    @Test func keysAreHexDigestsStableAcrossRunsAndInputOrder() {
        let keys = GraphCompiler.keys(of: F.journeyMix)
        #expect(keys.count == 5)
        #expect(keys.values.allSatisfy { $0.count == 64 && $0.allSatisfy(\.isHexDigit) })
        #expect(GraphCompiler.keys(of: F.journeyMix) == keys)
        let shuffled = VisualGraph(nodes: F.journeyMix.nodes.reversed(), edges: F.journeyMix.edges.reversed())
        #expect(GraphCompiler.keys(of: shuffled) == keys)
        #expect(GraphCompiler.changed(from: F.journeyMix, to: shuffled).isEmpty)
    }

    @Test func keysDifferByContent() {
        let keys = GraphCompiler.keys(of: F.journeyMix)
        #expect(Set(keys.values).count == 5)
        let edited = GraphCompiler.keys(of: C.setting(F.journeyMix, 1, ["scale": 8]))
        #expect(edited[NodeID(1)] != keys[NodeID(1)])
        // A stored default and a missing parameter are the same content.
        let stored = GraphCompiler.keys(of: C.setting(F.journeyMix, 2, ["angle": 90]))
        #expect(stored == keys)
    }

    @Test func positionsAreNotPartOfTheKey() {
        var moved = F.journeyMix
        moved.nodes = moved.nodes.map { node in
            var node = node
            node.position = CanvasPoint(x: node.position.x + 300, y: node.position.y - 120)
            return node
        }
        #expect(GraphCompiler.keys(of: moved) == GraphCompiler.keys(of: F.journeyMix))
        #expect(GraphCompiler.changed(from: F.journeyMix, to: moved).isEmpty)
    }

    @Test func editingGradientsAngleMarksItAndEverythingDownstream() {
        let edited = C.setting(F.journeyMix, 2, ["angle": 30])
        #expect(GraphCompiler.changed(from: F.journeyMix, to: edited) == Set(F.ids([2, 3, 4, 5])))
        let noise = C.setting(F.journeyMix, 1, ["octaves": 2])
        #expect(GraphCompiler.changed(from: F.journeyMix, to: noise) == Set(F.ids([1, 3, 4, 5])))
        let blur = C.setting(F.journeyMix, 4, ["radius": 9])
        #expect(GraphCompiler.changed(from: F.journeyMix, to: blur) == Set(F.ids([4, 5])))
    }

    @Test func aNodeAddedOrRemovedIsMarked() {
        var added = F.journeyMix
        added.nodes.append(F.node(6, .constant))
        #expect(GraphCompiler.changed(from: F.journeyMix, to: added) == Set(F.ids([6])))
        #expect(GraphCompiler.changed(from: added, to: F.journeyMix) == Set(F.ids([6])))
        var removed = F.unreachedBranch
        removed.nodes.removeAll { $0.id == NodeID(4) }
        removed.edges.removeAll { $0.targetNode == NodeID(4) }
        #expect(GraphCompiler.changed(from: F.unreachedBranch, to: removed) == Set(F.ids([4])))
    }

    @Test func aNewConnectionMarksItsTargetAndDownstream() {
        var connected = F.journeyMix
        connected.nodes.append(F.node(6, .constant))
        connected.edges.append(F.edge(6, "value", 3, "amount"))
        #expect(GraphCompiler.changed(from: F.journeyMix, to: connected) == Set(F.ids([3, 4, 5, 6])))
    }

    @Test func everyPassCarriesItsNodesKey() {
        guard let schedule = C.compiled(F.journeyMix) else {
            Issue.record("the journey graph was refused")
            return
        }
        #expect(schedule.keys == GraphCompiler.keys(of: F.journeyMix))
        for pass in schedule.passes { #expect(pass.key == schedule.keys[pass.node], "\(pass.node) \(pass.operator)") }
        let blurKeys = schedule.passes.filter { $0.node == NodeID(4) }.map(\.key)
        #expect(blurKeys.count == 2 && Set(blurKeys).count == 1)
    }

    @Test func keysOfAGraphWithALoopAreStillGiven() {
        #expect(GraphCompiler.keys(of: F.loopOfTwo).count == 3)
        #expect(GraphCompiler.keys(of: F.loopOfEight) == GraphCompiler.keys(of: F.loopOfEight))
    }
}
