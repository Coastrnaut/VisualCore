// ViewStateTests — feature 125 (A17-P02) T-A17-203 (FR-A17-205, FR-A17-210; clarification Q5). The saved view, schema
// 1: a round trip keeps every field; keys are sorted and nil optionals left out; damaged, newer, short-layered,
// out-of-range and unknown-id data are refused with their reasons; a selection on a hidden layer is cleared.
import Foundation
import Testing
@testable import InteractiveAnatomyCore

@Suite struct ViewStateTests {
    /// The 14 part ids of the bundled knee.
    private static func viewStateParts() throws -> [String] {
        try AnatomyContent.bundledRightKnee().structures.filter { $0.parent != nil }.map(\.id)
    }

    /// The refusal reason of decoding `text`, or nil when it decoded.
    private static func viewStateReason(_ text: String, _ parts: [String]) -> ContentRefusal.Reason? {
        if case let .failure(refusal) = AnatomyViewState.decode(Data(text.utf8), parts: parts) { return refusal.reason }
        return nil
    }

    @Test func aRoundTripKeepsEveryField() throws {
        let parts = try Self.viewStateParts()
        let state = AnatomyViewState(camera: AnatomyCameraState(turn: 7, tilt: -3, zoom: 5),
                                     visibleLayers: [true, false, true], selection: "knee.acl", framed: "knee.acl")
        let data = state.encoded()
        #expect(try AnatomyViewState.decode(data, parts: parts).get() == state)
        let opening = AnatomyViewState.opening
        #expect(try AnatomyViewState.decode(opening.encoded(), parts: parts).get() == opening)
        #expect(opening.schema == 1)
        #expect(opening.visibleLayerSet == Set(AnatomyLayer.allCases))
    }

    @Test func keysAreSortedAndNilOptionalsLeftOut() {
        let text = String(decoding: AnatomyViewState.opening.encoded(), as: UTF8.self)
        #expect(text == #"{"camera":{"tilt":1,"turn":2,"zoom":0},"schema":1,"visibleLayers":[true,true,true]}"#)
        let framed = AnatomyViewState(camera: .opening, visibleLayers: [true, true, true], selection: nil,
                                      framed: "knee.mcl")
        let framedText = String(decoding: framed.encoded(), as: UTF8.self)
        #expect(framedText.contains(#""framed":"knee.mcl""#))
        #expect(!framedText.contains("selection"))
    }

    @Test func badDataIsRefusedWithItsReason() throws {
        let parts = try Self.viewStateParts()
        let camera = #""camera":{"tilt":1,"turn":2,"zoom":0}"#
        #expect(Self.viewStateReason("not json", parts) == .damaged)
        #expect(Self.viewStateReason("[1, 2]", parts) == .damaged)
        #expect(Self.viewStateReason(#"{\#(camera),"visibleLayers":[true,true,true]}"#, parts) == .damaged)
        #expect(Self.viewStateReason(#"{\#(camera),"schema":2,"visibleLayers":[true,true,true]}"#, parts)
                == .newerVersion)
        #expect(Self.viewStateReason(#"{\#(camera),"schema":0,"visibleLayers":[true,true,true]}"#, parts) == .damaged)
        #expect(Self.viewStateReason(#"{\#(camera),"schema":true,"visibleLayers":[true,true,true]}"#, parts)
                == .damaged)
        #expect(Self.viewStateReason(#"{"schema":1,"visibleLayers":[true,true,true]}"#, parts) == .damaged)
        #expect(Self.viewStateReason(#"{\#(camera),"schema":1,"visibleLayers":[true,true]}"#, parts) == .damaged)
        #expect(Self.viewStateReason(#"{"camera":{"tilt":7,"turn":2,"zoom":0},"schema":1,"visibleLayers":[true,true,true]}"#,
                                     parts) == .damaged)
        #expect(Self.viewStateReason(#"{"camera":{"tilt":0,"turn":24,"zoom":0},"schema":1,"visibleLayers":[true,true,true]}"#,
                                     parts) == .damaged)
        #expect(Self.viewStateReason(#"{"camera":{"tilt":0,"turn":0,"zoom":-5},"schema":1,"visibleLayers":[true,true,true]}"#,
                                     parts) == .damaged)
        #expect(Self.viewStateReason(#"{\#(camera),"schema":1,"selection":"knee.elbow","visibleLayers":[true,true,true]}"#,
                                     parts) == .missingReference)
        #expect(Self.viewStateReason(#"{\#(camera),"framed":"knee.joint","schema":1,"visibleLayers":[true,true,true]}"#,
                                     parts) == .missingReference)
        #expect(Self.viewStateReason(#"{\#(camera),"schema":1,"selection":"knee.pcl","visibleLayers":[true,true,true]}"#,
                                     parts) == nil)
    }

    @Test func aSelectionOnAHiddenLayerIsCleared() throws {
        let region = try AnatomyContent.bundledRightKnee()
        var layers: [String: AnatomyLayer] = [:]
        for part in region.structures { if let layer = part.layer { layers[part.id] = layer } }
        let hidden = AnatomyViewState(camera: .opening, visibleLayers: [true, true, false], selection: "knee.acl",
                                      framed: "knee.acl")
        let cleared = hidden.normalized(layers: layers)
        #expect(cleared.selection == nil)
        #expect(cleared.framed == "knee.acl")
        #expect(cleared.visibleLayerSet == [.bones, .cartilage])
        let shown = AnatomyViewState(camera: .opening, visibleLayers: [true, true, false], selection: "knee.femur",
                                     framed: nil)
        #expect(shown.normalized(layers: layers) == shown)
    }
}
