// ViewDocumentTests — feature 126 (A17-P03) T-A17-305 (FR-A17-307; SC-A17-305; clarification Q4). The saved view
// file `view.json`: a `DocumentEnvelope` of kind "a17.view" round-trips exactly with its isolate; a schema-1 file
// migrates with no isolate; too large, damaged, wrong-kind and newer files are refused with their reasons; unknown
// selection, framing and isolate ids are dropped with a reason each and the rest is kept.
import Foundation
import Testing
import VisualCorePersistence
@testable import InteractiveAnatomyCore

@Suite struct ViewDocumentTests {
    /// The 14 part ids of the bundled knee.
    private static func documentParts() throws -> [String] {
        try AnatomyContent.bundledRightKnee().structures.filter { $0.parent != nil }.map(\.id)
    }

    /// The envelope text around `payload` with `kind` and `version`.
    private static func documentText(_ payload: String, kind: String = "a17.view", version: Int = 2) -> String {
        #"{"kind":"\#(kind)","payload":\#(payload),"savedAt":"2026-11-16T00:00:00Z","schemaVersion":\#(version)}"#
    }

    /// The decoded file of `text`.
    private static func documentDecoded(_ text: String, _ parts: [String])
        -> (Result<AnatomyViewState, ContentRefusal>, dropped: [String]) {
        AnatomyViewDocument.decode(Data(text.utf8), parts: parts)
    }

    /// The refusal reason of `text`, or nil when it decoded.
    private static func documentReason(_ text: String, _ parts: [String]) -> ContentRefusal.Reason? {
        if case let .failure(refusal) = documentDecoded(text, parts).0 { return refusal.reason }
        return nil
    }

    @Test func aViewRoundTripsExactly() throws {
        let parts = try Self.documentParts()
        #expect(AnatomyViewDocument.fileName == "view.json")
        #expect(AnatomyViewDocument.kind == "a17.view")
        #expect(AnatomyViewDocument.maxBytes == 65_536)
        let view = AnatomyViewState(camera: AnatomyCameraState(turn: 5, tilt: -2, zoom: 3),
                                    visibleLayers: [true, false, true], selection: "knee.mcl", framed: "knee.mcl",
                                    isolate: AnatomyIsolate(target: .layer(.ligaments), mode: .hide))
        let saved = Date(timeIntervalSince1970: 1_800_000_000)
        let data = AnatomyViewDocument.encode(view, savedAt: saved)
        let envelope = try #require(AnatomyViewDocument.envelope(data))
        #expect(envelope == DocumentEnvelope(kind: "a17.view", schemaVersion: 2, savedAt: saved))
        let (result, dropped) = AnatomyViewDocument.decode(data, parts: parts)
        #expect(try result.get() == view)
        #expect(dropped.isEmpty)
        let part = AnatomyViewState(camera: .opening, visibleLayers: [true, true, true], selection: nil, framed: nil,
                                    isolate: AnatomyIsolate(target: .part(3)))
        #expect(try AnatomyViewDocument.decode(AnatomyViewDocument.encode(part), parts: parts).0.get() == part)
    }

    @Test func aSchemaOneFileMigratesWithNoIsolate() throws {
        let parts = try Self.documentParts()
        let payload = #"{"camera":{"tilt":1,"turn":4,"zoom":2},"schema":1,"selection":"knee.acl","visibleLayers":[true,true,false]}"#
        let (result, dropped) = Self.documentDecoded(Self.documentText(payload, version: 1), parts)
        let view = try result.get()
        #expect(view.schema == 2)
        #expect(view.isolate == nil)
        #expect(view.selection == "knee.acl")
        #expect(view.camera == AnatomyCameraState(turn: 4, tilt: 1, zoom: 2))
        #expect(dropped.isEmpty)
    }

    @Test func badFilesAreRefusedWithTheirReasons() throws {
        let parts = try Self.documentParts()
        let payload = String(decoding: AnatomyViewState.opening.encoded(), as: UTF8.self)
        #expect(Self.documentReason(Self.documentText(payload), parts) == nil)
        let large = Self.documentText(payload) + String(repeating: " ", count: AnatomyViewDocument.maxBytes)
        #expect(Self.documentReason(large, parts) == .tooLarge)
        #expect(Self.documentReason("not json", parts) == .damaged)
        #expect(Self.documentReason(#"{"kind":"a17.view","schemaVersion":2}"#, parts) == .damaged)
        #expect(Self.documentReason(Self.documentText(payload, kind: "a14.view"), parts) == .damaged)
        #expect(Self.documentReason(Self.documentText(payload, version: 3), parts) == .newerVersion)
        #expect(Self.documentReason(Self.documentText(payload, version: 0), parts) == .damaged)
        #expect(Self.documentReason(Self.documentText(payload, version: 1), parts) == .damaged)
        let newerPayload = payload.replacingOccurrences(of: #""schema":2"#, with: #""schema":3"#)
        #expect(Self.documentReason(Self.documentText(newerPayload, version: 3), parts) == .newerVersion)
    }

    @Test func unknownIdsAreDroppedWithAReason() throws {
        let parts = try Self.documentParts()
        let payload = #"{"camera":{"tilt":1,"turn":2,"zoom":0},"framed":"knee.pcl","isolate":{"id":"knee.elbow","kind":"part","mode":"ghost"},"schema":2,"selection":"knee.elbow","visibleLayers":[true,true,true]}"#
        let (result, dropped) = Self.documentDecoded(Self.documentText(payload), parts)
        let view = try result.get()
        #expect(view.selection == nil)
        #expect(view.isolate == nil)
        #expect(view.framed == "knee.pcl")
        #expect(dropped.count == 2)
        #expect(dropped.allSatisfy { $0.contains("knee.elbow") && $0.hasSuffix(".") })
    }
}
