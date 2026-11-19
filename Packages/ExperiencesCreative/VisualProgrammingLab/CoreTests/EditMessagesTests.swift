// EditMessagesTests — feature 167 (A23-P02) T-A23-203 (SC-A23-202; FR-A23-203, FR-A23-205; clarifications Q1, Q4;
// User Stories 2 and 4). The words of the editor, exactly: one sentence per refusal (colour into scalar names both
// types; a taken input names its node by kind and the port; the loop, the node limit, the second output), the
// wrong-direction feedback, the refusal sentence of each refused edit fixture, one status line per checker result
// (Ready, No output, Output not connected, an empty required input, More than one output, a loop, any other refusal by
// its code), the seven kind titles and the spoken labels of nodes, ports and connections. Synthetic data only.
import Testing
import VisualProgrammingLabCore

@Suite struct EditMessagesTests {
    typealias F = GraphFixtures

    // MARK: Refusal sentences

    @Test func everyRefusalHasItsSentence() {
        let graph = VisualGraph(nodes: [F.node(3, .mix)])
        let sentences: [(GraphEditRefusal, String)] = [
            (.notWhole, "Use a whole number."),
            (.unknownNode(NodeID(9)), "That node is not in the graph."),
            (.unknownPort, "That port does not exist."),
            (.typeMismatch(from: .colour, to: .scalar), "A colour output cannot feed a scalar input."),
            (.inputTaken(node: NodeID(3), port: "b"), "Mix 3: input b is already connected."),
            (.cycle([F.edge(1, "image", 2, "image"), F.edge(2, "image", 1, "image")]),
             "That connection would make a loop."),
            (.tooManyNodes, "A graph holds at most 32 nodes."),
            (.tooManyEdges, "A graph holds at most 64 connections."),
            (.oneOutput, "A graph has one Output."),
        ]
        for (refusal, sentence) in sentences {
            #expect(EditMessages.sentence(for: refusal, in: graph) == sentence, "\(refusal)")
        }
    }

    @Test func aMismatchNamesBothTypes() {
        #expect(EditMessages.sentence(for: .typeMismatch(from: .texture, to: .time))
                    == "A texture output cannot feed a time input.")
        #expect(EditMessages.sentence(for: .typeMismatch(from: .scalar, to: .colour))
                    == "A scalar output cannot feed a colour input.")
        for from in ValueType.allCases {
            for to in ValueType.allCases where from != to {
                let sentence = EditMessages.sentence(for: .typeMismatch(from: from, to: to))
                #expect(sentence.contains(" \(from.rawValue) output") && sentence.contains(" \(to.rawValue) input"))
            }
        }
    }

    @Test func aTakenInputWithoutTheGraphNamesTheNodeByIdentity() {
        #expect(EditMessages.sentence(for: .inputTaken(node: NodeID(2), port: "image"))
                    == "Node 2: input image is already connected.")
        #expect(EditMessages.sentence(for: .inputTaken(node: NodeID(2), port: "image"), in: F.noiseToOutput)
                    == "Output 2: input image is already connected.")
    }

    @Test func theRefusedEditFixturesSayWhy() throws {
        let typed = VisualGraph(nodes: [F.node(1, .constant), F.node(2, .noise)])
        let looped = VisualGraph(nodes: [F.node(1, .noise), F.node(2, .mix), F.node(3, .blur)],
                                 edges: [F.edge(1, "image", 2, "a"), F.edge(2, "image", 3, "image")])
        var found: [String] = []
        do throws(GraphEditRefusal) {
            _ = try GraphEditor.connect(source: NodeID(1), outputIndex: 1, target: NodeID(2), inputIndex: 1, in: typed)
        } catch {
            found.append(EditMessages.sentence(for: error, in: typed))
        }
        do throws(GraphEditRefusal) {
            _ = try GraphEditor.connect(source: NodeID(1), outputIndex: 0, target: NodeID(2), inputIndex: 0,
                                        in: F.noiseToOutput)
        } catch {
            found.append(EditMessages.sentence(for: error, in: F.noiseToOutput))
        }
        do throws(GraphEditRefusal) {
            _ = try GraphEditor.connect(source: NodeID(3), outputIndex: 0, target: NodeID(2), inputIndex: 1, in: looped)
        } catch {
            found.append(EditMessages.sentence(for: error, in: looped))
        }
        do throws(GraphEditRefusal) {
            _ = try GraphEditor.add(.noise, at: CanvasPoint(x: 0, y: 0), to: F.atLimits)
        } catch {
            found.append(EditMessages.sentence(for: error, in: F.atLimits))
        }
        do throws(GraphEditRefusal) {
            _ = try GraphEditor.add(.output, at: CanvasPoint(x: 0, y: 0), to: F.noiseToOutput)
        } catch {
            found.append(EditMessages.sentence(for: error, in: F.noiseToOutput))
        }
        #expect(found == ["A colour output cannot feed a scalar input.", "Output 2: input image is already connected.",
                          "That connection would make a loop.", "A graph holds at most 32 nodes.",
                          "A graph has one Output."])
    }

    @Test func theWrongDirectionFeedback() {
        #expect(EditMessages.wrongDirection == "Connect an output to an input.")
    }

    // MARK: Status

    @Test func everyCheckResultHasItsStatus() {
        let cases: [(VisualGraph, String)] = [
            (F.noiseToOutput, "Ready"),
            (F.empty, "No output"),
            (F.noOutputNode, "No output"),
            (F.disconnectedOutput, "Output not connected"),
            (F.mixMissingB, "Mix 2: input b is empty"),
            (F.mixMissingA, "Mix 2: input a is empty"),
            (F.twoOutputs, "More than one output"),
            (F.loopOfTwo, "The graph has a loop"),
            (F.undeclaredParameter, "The graph has a problem: unknown-parameter"),
            (F.inputFedTwice, "The graph has a problem: input-already-connected"),
            (F.oneNodePastLimit, "The graph has a problem: too-many-nodes"),
        ]
        for (graph, status) in cases {
            #expect(EditMessages.status(for: GraphChecker.check(graph), in: graph) == status, "\(status)")
        }
    }

    @Test func theStatusNamesTheEmptyInputsNode() {
        let graph = VisualGraph(nodes: [F.node(1, .noise), F.node(3, .mix), F.node(5, .output)],
                                edges: [F.edge(1, "image", 3, "a"), F.edge(3, "image", 5, "image")])
        #expect(EditMessages.status(for: GraphChecker.check(graph), in: graph) == "Mix 3: input b is empty")
    }

    // MARK: Titles and labels

    @Test func everyKindHasItsTitle() {
        #expect(NodeKind.allCases.map(EditMessages.title(of:))
                    == ["Time", "Constant", "Noise", "Gradient", "Mix", "Blur", "Output"])
    }

    @Test func nodesAreLabelledByTitleAndIdentity() {
        #expect(EditMessages.label(node: F.node(2, .noise)) == "Noise 2")
        #expect(EditMessages.label(node: F.node(1, .output)) == "Output 1")
        #expect(EditMessages.label(node: F.node(17, .constant)) == "Constant 17")
    }

    @Test func portsAreLabelledWithDirectionTypeAndOptional() throws {
        let noise = F.node(2, .noise)
        let mix = F.node(3, .mix)
        let image = try #require(noise.kind.output("image"))
        let amount = try #require(mix.kind.input("amount"))
        let a = try #require(mix.kind.input("a"))
        #expect(EditMessages.label(port: image, of: noise) == "Noise 2, output image, texture")
        #expect(EditMessages.label(port: amount, of: mix) == "Mix 3, input amount, scalar, optional")
        #expect(EditMessages.label(port: a, of: mix) == "Mix 3, input a, texture")
        let constant = F.node(4, .constant)
        #expect(constant.kind.outputs.map { EditMessages.label(port: $0, of: constant) }
                    == ["Constant 4, output value, scalar", "Constant 4, output colour, colour"])
        #expect(noise.kind.inputs.map { EditMessages.label(port: $0, of: noise) }
                    == ["Noise 2, input time, time, optional", "Noise 2, input scale, scalar, optional"])
    }

    @Test func connectionsAreLabelledFromSourceToTarget() {
        let graph = VisualGraph(nodes: [F.node(1, .output), F.node(2, .noise)], edges: [F.edge(2, "image", 1, "image")])
        #expect(graph.edges.map { EditMessages.label(edge: $0, in: graph) } == ["Noise 2 image → Output 1 image"])
        #expect(F.journeyMix.edges.map { EditMessages.label(edge: $0, in: F.journeyMix) }
                    == ["Noise 1 image → Mix 3 a", "Gradient 2 image → Mix 3 b", "Mix 3 image → Blur 4 image",
                        "Blur 4 image → Output 5 image"])
        #expect(EditMessages.label(edge: F.edge(9, "image", 1, "image"), in: graph) == "Node 9 image → Output 1 image")
    }
}
