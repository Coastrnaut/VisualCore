// SavedViewTests — feature 106 (A14-P04) T-A14-404 (FR-A14-421; SC-A14-405; clarification Q5). The saved view, host-
// free and short: a round trip through JSON; the exact sorted-key text of one view; each refusal (oversized 5,000
// bytes, newer schema 2, damaged JSON and a missing key, out-of-range per field); `view.apply` values round trip and
// refuse a wrong count or a fraction.
import Foundation
import SolarSystemExplorerCore
import Testing

@Suite struct SavedViewTests {
    /// The refusal of decoding `text`, or nil when accepted.
    private func refusal(_ text: String) -> SavedViewRefusal? {
        refusal(Data(text.utf8))
    }

    /// The refusal of decoding `data`, or nil when accepted.
    private func refusal(_ data: Data) -> SavedViewRefusal? {
        switch SavedView.decode(data) {
        case .success: return nil
        case .failure(let reason): return reason
        }
    }

    /// A schema-1 document with every field given.
    private func document(schema: Int = 1, selection: String = "3", dayOffset: String = "1.5", rateIndex: String = "2",
                          yawSteps: String = "-4", pitchDegrees: String = "45", zoomSteps: String = "2",
                          scaleMode: String = "1") -> String {
        "{\"dayOffset\":\(dayOffset),\"pitchDegrees\":\(pitchDegrees),\"rateIndex\":\(rateIndex),"
            + "\"scaleMode\":\(scaleMode),\"schema\":\(schema),\"selection\":\(selection),\"yawSteps\":\(yawSteps),"
            + "\"zoomSteps\":\(zoomSteps)}"
    }

    @Test func constants() {
        #expect(SavedView.fileName == "view.json")
        #expect(SavedView.maxBytes == 4_096)
        #expect(SavedView.schemaVersion == 1)
        #expect(SavedViewRefusal.allCases.map(\.rawValue) == ["damaged", "newer-version", "out-of-range", "oversized"])
    }

    @Test func roundTripAndSortedKeyText() throws {
        let view: SavedView = try #require(SavedView(selection: 3, dayOffset: 1.5, rateIndex: 2, yawSteps: -4,
                                                     pitchDegrees: 45, zoomSteps: 2, scaleMode: 1))
        let text = String(decoding: view.encoded(), as: UTF8.self)
        #expect(text == document())
        switch SavedView.decode(view.encoded()) {
        case .success(let decoded): #expect(decoded == view)
        case .failure(let reason): Issue.record("refused \(reason)")
        }
        let edge: SavedView = try #require(SavedView(selection: 8, dayOffset: SimulatedDate.range.upperBound,
                                                     rateIndex: 0, yawSteps: 1_000, pitchDegrees: 85,
                                                     zoomSteps: -1, scaleMode: 0))
        switch SavedView.decode(edge.encoded()) {
        case .success(let decoded): #expect(decoded == edge)
        case .failure(let reason): Issue.record("refused \(reason)")
        }
    }

    @Test func oversizedIsRefusedFirst() {
        let padded = document() + String(repeating: " ", count: 5_000 - document().utf8.count)
        #expect(padded.utf8.count == 5_000)
        #expect(refusal(padded) == .oversized)
        #expect(refusal(Data(repeating: 0xFF, count: 5_000)) == .oversized)
        let atLimit = document() + String(repeating: " ", count: 4_096 - document().utf8.count)
        #expect(refusal(atLimit) == nil)
    }

    @Test func newerSchemaIsRefused() {
        #expect(refusal(document(schema: 2)) == .newerVersion)
        #expect(refusal("{\"schema\":2}") == .newerVersion)
    }

    @Test func damagedDocumentsAreRefused() {
        let damaged: [String] = [
            "", "not json", "{\"schema\":1", "{}", "{\"schema\":0}", "{\"schema\":\"1\"}",
            "{\"dayOffset\":1.5,\"pitchDegrees\":45,\"rateIndex\":2,\"scaleMode\":1,\"schema\":1,\"selection\":3,"
                + "\"yawSteps\":-4}",
            document(selection: "\"3\""),
            document(rateIndex: "1.5"),
        ]
        for text in damaged {
            #expect(refusal(text) == .damaged, "\(text)")
        }
    }

    @Test func eachFieldOutOfRangeIsRefused() {
        let outOfRange: [String] = [
            document(selection: "9"), document(selection: "-1"),
            document(dayOffset: "18628"), document(dayOffset: "-18263"),
            document(rateIndex: "4"), document(rateIndex: "-1"),
            document(pitchDegrees: "40"), document(pitchDegrees: "95"), document(pitchDegrees: "-5"),
            document(zoomSteps: "13"), document(zoomSteps: "-2"),
            document(scaleMode: "2"), document(scaleMode: "-1"),
        ]
        for text in outOfRange {
            #expect(refusal(text) == .outOfRange, "\(text)")
        }
    }

    @Test func valuesRoundTripInApplyOrder() throws {
        let view: SavedView = try #require(SavedView(selection: 5, dayOffset: -100.25, rateIndex: 3, yawSteps: 7,
                                                     pitchDegrees: 15, zoomSteps: 12, scaleMode: 1))
        #expect(view.values == [5, -100.25, 3, 7, 15, 12, 1])
        #expect(SavedView(values: view.values) == view)
        #expect(SavedView(values: [5, -100.25, 3, 7, 15, 12]) == nil)
        #expect(SavedView(values: [5.5, 0, 0, 0, 35, 0, 0]) == nil)
        #expect(SavedView(values: [5, 0, 0, 0.5, 35, 0, 0]) == nil)
        #expect(SavedView(values: [5, Double.nan, 0, 0, 35, 0, 0]) == nil)
        #expect(SavedView(values: [5, 0, 0, Double.infinity, 35, 0, 0]) == nil)
        #expect(SavedView(values: [5, 0, 0, 0, 35, 0, 2]) == nil)
        #expect(SavedView(values: [0, 0.5, 0, 0, 35, 0, 0]) != nil)
    }
}
