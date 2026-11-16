// ViewStateTests — feature 125 (A17-P02) T-A17-203 (FR-A17-205, FR-A17-210; clarification Q5), updated for schema 2
// by feature 126 (A17-P03) T-A17-305 (FR-A17-307; SC-A17-305; clarification Q4). The saved view: a round trip keeps
// every field, the isolate included; keys are sorted and nil optionals left out; schema 1 migrates with no isolate;
// damaged, newer, short-layered, out-of-range and badly shaped isolate data are refused with their reasons; unknown
// selection, framed and isolate ids are dropped with a reason (the compatibility decode still refuses them as
// missing references); a selection on a hidden layer is cleared unless an isolate is active.
import Foundation
import Testing
@testable import InteractiveAnatomyCore

@Suite struct ViewStateTests {
    /// The 14 part ids of the bundled knee.
    private static func viewStateParts() throws -> [String] {
        try AnatomyContent.bundledRightKnee().structures.filter { $0.parent != nil }.map(\.id)
    }

    /// The reporting decode of `text`.
    private static func viewStateDecoded(_ text: String, _ parts: [String])
        -> (Result<AnatomyViewState, ContentRefusal>, dropped: [String]) {
        AnatomyViewState.decode(Data(text.utf8), parts: parts)
    }

    /// The refusal reason of decoding `text`, or nil when it decoded.
    private static func viewStateReason(_ text: String, _ parts: [String]) -> ContentRefusal.Reason? {
        if case let .failure(refusal) = viewStateDecoded(text, parts).0 { return refusal.reason }
        return nil
    }

    @Test func aRoundTripKeepsEveryField() throws {
        let parts = try Self.viewStateParts()
        let state = AnatomyViewState(camera: AnatomyCameraState(turn: 7, tilt: -3, zoom: 5),
                                     visibleLayers: [true, false, true], selection: "knee.acl", framed: "knee.acl",
                                     isolate: AnatomyIsolate(target: .part(4), mode: .hide))
        let (result, dropped) = Self.viewStateDecoded(String(decoding: state.encoded(), as: UTF8.self), parts)
        #expect(try result.get() == state)
        #expect(dropped.isEmpty)
        let opening = AnatomyViewState.opening
        #expect(try AnatomyViewState.decode(opening.encoded(), parts: parts).get() == opening)
        #expect(opening.schema == 2)
        #expect(AnatomyViewState.schemaVersion == 2)
        #expect(opening.isolate == nil)
        #expect(opening.visibleLayerSet == Set(AnatomyLayer.allCases))
    }

    @Test func keysAreSortedAndNilOptionalsLeftOut() {
        let text = String(decoding: AnatomyViewState.opening.encoded(), as: UTF8.self)
        #expect(text == #"{"camera":{"tilt":1,"turn":2,"zoom":0},"schema":2,"visibleLayers":[true,true,true]}"#)
        let framed = AnatomyViewState(camera: .opening, visibleLayers: [true, true, true], selection: nil,
                                      framed: "knee.mcl", isolate: AnatomyIsolate(target: .layer(.bones), mode: .hide))
        let framedText = String(decoding: framed.encoded(), as: UTF8.self)
        #expect(framedText.contains(#""framed":"knee.mcl""#))
        #expect(framedText.contains(#""isolate":{"id":"bones","kind":"layer","mode":"hide"}"#))
        #expect(!framedText.contains("selection"))
    }

    @Test func schemaOneMigratesWithNoIsolate() throws {
        let parts = try Self.viewStateParts()
        let text = #"{"camera":{"tilt":1,"turn":2,"zoom":0},"framed":"knee.mcl","schema":1,"selection":"knee.mcl","visibleLayers":[true,true,false]}"#
        let (result, dropped) = Self.viewStateDecoded(text, parts)
        let state = try result.get()
        #expect(state == AnatomyViewState(camera: .opening, visibleLayers: [true, true, false], selection: "knee.mcl",
                                          framed: "knee.mcl"))
        #expect(dropped.isEmpty)
        #expect(AnatomyViewState.migrations.currentVersion == 2)
        let migrated = try AnatomyViewState.migrations.migrate(["schema": 1], from: 1)
        #expect(migrated["schema"] as? Int == 2)
        #expect(migrated["isolate"] == nil)
    }

    @Test func badDataIsRefusedWithItsReason() throws {
        let parts = try Self.viewStateParts()
        let camera = #""camera":{"tilt":1,"turn":2,"zoom":0}"#
        #expect(Self.viewStateReason("not json", parts) == .damaged)
        #expect(Self.viewStateReason("[1, 2]", parts) == .damaged)
        #expect(Self.viewStateReason(#"{\#(camera),"visibleLayers":[true,true,true]}"#, parts) == .damaged)
        #expect(Self.viewStateReason(#"{\#(camera),"schema":3,"visibleLayers":[true,true,true]}"#, parts)
                == .newerVersion)
        #expect(Self.viewStateReason(#"{\#(camera),"schema":2,"visibleLayers":[true,true,true]}"#, parts) == nil)
        #expect(Self.viewStateReason(#"{\#(camera),"schema":0,"visibleLayers":[true,true,true]}"#, parts) == .damaged)
        #expect(Self.viewStateReason(#"{\#(camera),"schema":true,"visibleLayers":[true,true,true]}"#, parts)
                == .damaged)
        #expect(Self.viewStateReason(#"{"schema":2,"visibleLayers":[true,true,true]}"#, parts) == .damaged)
        #expect(Self.viewStateReason(#"{\#(camera),"schema":2,"visibleLayers":[true,true]}"#, parts) == .damaged)
        #expect(Self.viewStateReason(#"{"camera":{"tilt":7,"turn":2,"zoom":0},"schema":2,"visibleLayers":[true,true,true]}"#,
                                     parts) == .damaged)
        #expect(Self.viewStateReason(#"{"camera":{"tilt":0,"turn":24,"zoom":0},"schema":1,"visibleLayers":[true,true,true]}"#,
                                     parts) == .damaged)
        #expect(Self.viewStateReason(#"{"camera":{"tilt":0,"turn":0,"zoom":-5},"schema":2,"visibleLayers":[true,true,true]}"#,
                                     parts) == .damaged)
        #expect(Self.viewStateReason(#"{\#(camera),"isolate":{"id":"bones","kind":"joint","mode":"hide"},"schema":2,"visibleLayers":[true,true,true]}"#,
                                     parts) == .damaged)
        #expect(Self.viewStateReason(#"{\#(camera),"isolate":{"id":"bones","kind":"layer","mode":"fade"},"schema":2,"visibleLayers":[true,true,true]}"#,
                                     parts) == .damaged)
        #expect(Self.viewStateReason(#"{\#(camera),"isolate":[1],"schema":2,"visibleLayers":[true,true,true]}"#,
                                     parts) == .damaged)
    }

    @Test func unknownIdsAreDroppedWithAReason() throws {
        let parts = try Self.viewStateParts()
        let camera = #""camera":{"tilt":1,"turn":2,"zoom":0}"#
        let text = #"{\#(camera),"framed":"knee.joint","isolate":{"id":"skin","kind":"layer","mode":"ghost"},"schema":2,"selection":"knee.elbow","visibleLayers":[true,true,true]}"#
        let (result, dropped) = Self.viewStateDecoded(text, parts)
        #expect(try result.get() == AnatomyViewState.opening)
        #expect(dropped.count == 3)
        #expect(dropped.contains { $0.contains("knee.elbow") })
        #expect(dropped.contains { $0.contains("knee.joint") })
        #expect(dropped.contains { $0.contains("skin") })
        let strict: Result<AnatomyViewState, ContentRefusal> = AnatomyViewState.decode(Data(text.utf8), parts: parts)
        if case let .failure(refusal) = strict {
            #expect(refusal.reason == .missingReference)
        } else {
            Issue.record("the compatibility decode refuses an unknown id")
        }
        let kept = #"{\#(camera),"schema":2,"selection":"knee.pcl","visibleLayers":[true,true,true]}"#
        #expect(Self.viewStateDecoded(kept, parts).dropped.isEmpty)
        #expect(Self.viewStateReason(kept, parts) == nil)
    }

    @Test func aSelectionOnAHiddenLayerIsClearedUnlessIsolated() throws {
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
        let isolated = AnatomyViewState(camera: .opening, visibleLayers: [true, true, false], selection: "knee.acl",
                                        framed: nil, isolate: AnatomyIsolate(target: .layer(.bones)))
        #expect(isolated.normalized(layers: layers) == isolated)
    }
}
