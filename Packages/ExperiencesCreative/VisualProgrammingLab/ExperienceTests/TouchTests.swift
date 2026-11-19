// TouchTests — feature 167 (A23-P02) T-A23-207 (FR-A23-202, FR-A23-203, FR-A23-204, FR-A23-205; SC-A23-201,
// SC-A23-202, SC-A23-203, SC-A23-204; clarification Q3; edge cases "A drag that ends away from any port", "A drag
// between two inputs or two outputs", "Small screens", "An interrupted touch"). The presenter's touch mapping, with
// simulated pointer events on a shell without a render host, in a view where a canvas point equals a view point:
// the journey graph built by touch gives the same fingerprint and digest as by actions; a drag between two ports of
// the same direction sends nothing and says "Connect an output to an input."; a drag ending away from a port does
// nothing; taps select and clear; pinches and pans change only the view, with the zoom held within 0.5…2; the
// starter graph's port targets are at least 44 × 44 points at the default zoom; an interrupted touch is dropped with
// the graph as of its last move and no rubber wire. Short runs only.
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreScenes
@testable import VisualProgrammingLabExperience
import VisualProgrammingLabCore

@MainActor
@Suite(.serialized) struct TouchTests {
    /// SC-A23-201: the journey graph built by touch equals the one built by actions.
    @Test func theJourneyGraphByTouchEqualsTheJourneyByActions() async throws {
        let byActions = try await LabTest.shell()
        for action in LabCore.journeyActions { LabTest.accept(byActions, action.control, action.values) }

        let byTouch = try await LabTest.shell()
        LabTest.accept(byTouch, "node.add", [3, 40, 400])           // Gradient 3, then dragged into place
        LabTest.drag(byTouch, from: Vec2(100, 420), to: Vec2(100, 260))
        #expect(try LabTest.core(byTouch).graph.node(NodeID(3))?.position == CanvasPoint(x: 40, y: 240))
        LabTest.accept(byTouch, "node.add", [4, 320, 240])          // Mix 4
        LabTest.accept(byTouch, "node.add", [5, 600, 240])          // Blur 5
        LabTest.accept(byTouch, "edge.disconnect", [2, 0])          // the list form's "None"
        try LabTest.wire(byTouch, from: 1, output: 0, to: 4, input: 0)
        try LabTest.wire(byTouch, from: 3, output: 0, to: 4, input: 1)
        try LabTest.wire(byTouch, from: 4, output: 0, to: 5, input: 0)
        try LabTest.wire(byTouch, from: 5, output: 0, to: 2, input: 0)
        #expect(byTouch.presenter.feedback == nil)
        #expect(byTouch.presenter.mirror.rubber == nil)
        #expect(try LabTest.fingerprint(byTouch) == LabTest.fingerprint(byActions))
        #expect(try LabTest.digest(byTouch) == LabTest.digest(byActions))
        #expect(try LabTest.core(byTouch).outcome?.code == "graph-ready")
        #expect(byTouch.presenter.mirror.status == "Ready")
    }

    /// The list form's choices send the same actions as the drags.
    @Test func theListFormSendsTheSameConnections() async throws {
        let shell = try await LabTest.shell()
        LabTest.accept(shell, "node.add", [4, 320, 240])            // Mix 3
        let graph = try LabTest.core(shell).graph
        let options = LabControls.sourceOptions(for: NodeID(3), in: graph)
        #expect(options.map(\.title) == ["Noise 1 image"])
        let choice = try #require(LabControls.action(choosing: options[0].tag, for: NodeID(3), input: 0))
        #expect(choice.0 == "edge.connect" && choice.1 == [1, 0, 3, 0])
        LabTest.accept(shell, choice.0, choice.1)
        let mix = try #require(try LabTest.core(shell).graph.node(NodeID(3)))
        #expect(LabControls.currentTag(of: mix, input: 0, in: try LabTest.core(shell).graph) == "1-0")
        let lines = LabControls.connectionLines(try LabTest.core(shell).graph)
        #expect(lines.map(\.text) == ["Noise 1 image → Output 2 image", "Noise 1 image → Mix 3 a"])
        #expect(lines.map(\.name) == ["connection-2-0", "connection-3-0"])
        let none = try #require(LabControls.action(choosing: LabControls.noneTag, for: NodeID(3), input: 0))
        #expect(none.0 == "edge.disconnect" && none.1 == [3, 0])
    }

    /// SC-A23-202: a drag between two inputs or two outputs sends nothing and explains the direction.
    @Test func aWrongDirectionSendsNothingAndSaysSo() async throws {
        let shell = try await LabTest.shell()
        LabTest.accept(shell, "node.add", [3, 40, 400])             // Gradient 3
        let before = try LabTest.digest(shell)
        let graph = try LabTest.core(shell).graph
        let noise = try #require(graph.node(NodeID(1)))
        let output = try #require(graph.node(NodeID(2)))
        let gradient = try #require(graph.node(NodeID(3)))
        LabTest.drag(shell, from: LabTest.screen(shell, CanvasLayout.inputPoint(of: output, index: 0)),
                     to: LabTest.screen(shell, CanvasLayout.inputPoint(of: noise, index: 1)))
        #expect(shell.presenter.feedback == EditMessages.wrongDirection)
        #expect(shell.presenter.feedback == "Connect an output to an input.")
        #expect(try LabTest.digest(shell) == before)
        LabTest.accept(shell, "node.select", [0])
        #expect(shell.presenter.feedback == nil)
        LabTest.drag(shell, from: LabTest.screen(shell, CanvasLayout.outputPoint(of: noise, index: 0)),
                     to: LabTest.screen(shell, CanvasLayout.outputPoint(of: gradient, index: 0)))
        #expect(shell.presenter.feedback == EditMessages.wrongDirection)
        #expect(try LabTest.digest(shell) == before)
        #expect(shell.presenter.mirror.rubber == nil)
    }

    /// SC-A23-202 by touch: a colour output dragged to a scalar input is refused with its sentence.
    @Test func aTypeMismatchByTouchIsRefusedWithItsSentence() async throws {
        let shell = try await LabTest.shell()
        LabTest.accept(shell, "node.add", [1, 40, 400])             // Constant 3
        let before = try LabTest.digest(shell)
        let graph = try LabTest.core(shell).graph
        let constant = try #require(graph.node(NodeID(3)))
        let noise = try #require(graph.node(NodeID(1)))
        LabTest.drag(shell, from: LabTest.screen(shell, CanvasLayout.outputPoint(of: constant, index: 1)),
                     to: LabTest.screen(shell, CanvasLayout.inputPoint(of: noise, index: 1)))
        #expect(try LabTest.digest(shell) == before)
        #expect(shell.presenter.feedback == "A colour output cannot feed a scalar input.")
    }

    /// A drag that ends away from any port does nothing and says nothing.
    @Test func aDragEndingAwayFromAPortDoesNothing() async throws {
        let shell = try await LabTest.shell()
        let before = try LabTest.digest(shell)
        let noise = try #require(try LabTest.core(shell).graph.node(NodeID(1)))
        let start = LabTest.screen(shell, CanvasLayout.outputPoint(of: noise, index: 0))
        LabTest.touch(shell, 1, .began, start)
        LabTest.touch(shell, 1, .moved, Vec2(700, 600))
        #expect(shell.presenter.mirror.rubber?.end == CanvasPoint(x: 700, y: 600), "the rubber wire follows")
        LabTest.touch(shell, 1, .ended, Vec2(700, 600))
        #expect(shell.presenter.mirror.rubber == nil)
        #expect(shell.presenter.feedback == nil)
        #expect(try LabTest.digest(shell) == before)
    }

    /// A tap on a node selects it; a tap on empty canvas clears the selection.
    @Test func tapsSelectAndClear() async throws {
        let shell = try await LabTest.shell()
        LabTest.tap(shell, Vec2(400, 100))                          // Output 2's title
        #expect(try LabTest.core(shell).selection == NodeID(2))
        #expect(shell.presenter.mirror.selection == NodeID(2))
        LabTest.drag(shell, from: Vec2(100, 100), to: Vec2(105, 103), steps: 2)   // under 10 points: a tap
        #expect(try LabTest.core(shell).selection == NodeID(1))
        #expect(try LabTest.core(shell).graph.node(NodeID(1))?.position == CanvasPoint(x: 40, y: 80), "not moved")
        LabTest.tap(shell, Vec2(800, 700))
        #expect(try LabTest.core(shell).selection == nil)
        #expect(LabPresenter.clamp(5_000) == 4_096 && LabPresenter.clamp(-5_000) == -4_096)
        #expect(LabPresenter.clamp(.nan) == 0)
    }

    /// SC-A23-203: pinches and pans change only the view; the zoom stays within 0.5…2.
    @Test func zoomAndPanNeverChangeTheGraph() async throws {
        let shell = try await LabTest.shell()
        let presenter = shell.presenter
        let digest = try LabTest.digest(shell)
        let fingerprint = try LabTest.fingerprint(shell)
        LabTest.pinch(shell, centre: Vec2(700, 600), from: 100, to: 1_000)
        #expect(abs(presenter.view.zoom - CanvasView.maxZoom) < 1e-9, "held at 2: \(presenter.view.zoom)")
        LabTest.pinch(shell, centre: Vec2(700, 600), from: 1_000, to: 20)
        #expect(abs(presenter.view.zoom - CanvasView.minZoom) < 1e-9, "held at 0.5: \(presenter.view.zoom)")
        let centre = presenter.view.centre
        LabTest.drag(shell, from: Vec2(900, 700), to: Vec2(800, 650))
        #expect(presenter.view.centre != centre, "the pan moved the view")
        #expect(presenter.view.zoom >= CanvasView.minZoom && presenter.view.zoom <= CanvasView.maxZoom)
        #expect(presenter.mirror.view == presenter.view)
        #expect(try LabTest.digest(shell) == digest)
        #expect(try LabTest.fingerprint(shell) == fingerprint)
        #expect(try LabTest.core(shell).selection == nil)
    }

    /// SC-A23-204: every port target of the starter graph is at least 44 × 44 points at the default zoom, and a
    /// touch 20 points beside or 15 points above or below a port's centre still takes the port (Noise's two inputs
    /// are 36 points apart, so the nearer centre wins between them).
    @Test func starterPortTargetsAreAtLeast44Points() async throws {
        let shell = try await LabTest.shell()
        let zoom = LabPresenter().view.zoom
        #expect(zoom == 1)
        let graph = try LabTest.core(shell).graph
        for node in graph.nodes {
            for (input, count) in [(true, node.kind.inputs.count), (false, node.kind.outputs.count)] {
                for index in 0..<count {
                    let rect = CanvasLayout.portTargetRect(of: node, input: input, index: index)
                    #expect(rect.width * zoom >= 44 && rect.height * zoom >= 44)
                    let centre = rect.centre
                    let expected: CanvasHit = input ? .input(node.id, index) : .output(node.id, index)
                    for (dx, dy) in [(-20.0, 0.0), (20.0, 0.0), (0.0, -15.0), (0.0, 15.0)] {
                        let hit = CanvasLayout.hit(CanvasPoint(x: centre.x + dx, y: centre.y + dy), in: graph,
                                                   zoom: zoom)
                        #expect(hit == expected, "\(node.id) \(input) \(index) \(dx) \(dy)")
                    }
                }
            }
        }
        let noise = try #require(graph.node(NodeID(1)))
        let out = LabTest.screen(shell, CanvasLayout.outputPoint(of: noise, index: 0))
        LabTest.touch(shell, 1, .began, out + Vec2(0, 20))
        #expect(shell.presenter.mirror.rubber?.node == NodeID(1))
        #expect(shell.presenter.mirror.rubber?.isInput == false)
        shell.presenter.cancelPointers()
    }

    /// An interrupted touch: the drag is dropped, the graph stays as of the last move and no rubber wire remains.
    @Test func cancelPointersMidDragDropsTheGesture() async throws {
        let shell = try await LabTest.shell()
        LabTest.touch(shell, 1, .began, Vec2(100, 100))             // Noise 1's title
        LabTest.touch(shell, 1, .moved, Vec2(150, 100))
        LabTest.touch(shell, 1, .moved, Vec2(200, 100))
        #expect(try LabTest.core(shell).graph.node(NodeID(1))?.position == CanvasPoint(x: 140, y: 80))
        shell.presenter.cancelPointers()
        LabTest.touch(shell, 1, .moved, Vec2(300, 100))
        LabTest.touch(shell, 1, .ended, Vec2(300, 100))
        #expect(try LabTest.core(shell).graph.node(NodeID(1))?.position == CanvasPoint(x: 140, y: 80))
        #expect(try LabTest.core(shell).selection == nil)

        let before = try LabTest.digest(shell)
        let noise = try #require(try LabTest.core(shell).graph.node(NodeID(1)))
        LabTest.touch(shell, 2, .began, LabTest.screen(shell, CanvasLayout.outputPoint(of: noise, index: 0)))
        LabTest.touch(shell, 2, .moved, Vec2(600, 500))
        #expect(shell.presenter.mirror.rubber != nil)
        LabTest.touch(shell, 2, .cancelled, Vec2(600, 500))
        #expect(shell.presenter.mirror.rubber == nil)
        LabTest.touch(shell, 2, .ended, Vec2(600, 500))
        #expect(try LabTest.digest(shell) == before)

        LabTest.touch(shell, 3, .began, LabTest.screen(shell, CanvasLayout.outputPoint(of: noise, index: 0)))
        #expect(shell.presenter.mirror.rubber != nil)
        LabTest.touch(shell, 4, .began, Vec2(700, 600))             // a second finger: a pinch, the wire dropped
        #expect(shell.presenter.mirror.rubber == nil)
        shell.presenter.cancelPointers()
        #expect(try LabTest.digest(shell) == before)
    }

    /// The presenter's contract: 30 frames per second, one tier, the gesture actions among the native ones.
    @Test func thePresenterDeclaresItsCapAndActions() async throws {
        let shell = try await LabTest.shell()
        #expect(shell.maxFramesPerSecond == 30)
        #expect(shell.qualityProfile.names == ["level-0"])
        #expect(shell.presenter.gestureActions.isSubset(of: shell.presenter.nativeActions))
        #expect(shell.presenter.nativeActions == Set(LabCore.actionIDs))
        #expect(shell.accessibilitySummary == "Visual Programming Lab, 2 nodes, 1 connection, Ready")
        #expect(shell.canvasOverlay != nil)
    }
}
