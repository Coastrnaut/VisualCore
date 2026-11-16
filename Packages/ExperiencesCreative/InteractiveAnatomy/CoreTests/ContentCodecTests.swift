// ContentCodecTests — feature 124 (A17-P01) T-A17-109 (SC-A17-103). Content that is safe to store and evolve,
// host-free and short: encoding then decoding gives an equal region and identical bytes; damaged JSON, schema 2 and
// 262,145 bytes are refused with damaged, newer-version and too-large; a valid edited region still round-trips.
import Foundation
import Testing
import VisualCoreMath
@testable import InteractiveAnatomyCore

/// `data` as a JSON object changed by `change`, written back with sorted keys.
private func codecMutatedJSON(_ data: Data, _ change: (inout [String: Any]) -> Void) -> Data {
    var object = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
    change(&object)
    return (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
}

/// The refusal reason of decoding `data`, or nil when it decodes.
private func codecRefusalReason(_ data: Data) -> ContentRefusal.Reason? {
    if case .failure(let refusal) = AnatomyContent.decode(data) { return refusal.reason }
    return nil
}

@Suite struct ContentCodecTests {
    @Test func encodeThenDecodeGivesAnEqualRegionAndEqualBytes() throws {
        let region = try AnatomyContent.bundledRightKnee()
        let data = AnatomyContent.encoded(region)
        let decoded = AnatomyContent.decode(data)
        #expect(decoded == .success(region))
        if case .success(let back) = decoded {
            let again = AnatomyContent.encoded(back)
            #expect(again == data)
        }
    }

    @Test func damagedJSONIsRefused() {
        #expect(codecRefusalReason(Data("{".utf8)) == .damaged)
        #expect(codecRefusalReason(Data()) == .damaged)
        #expect(codecRefusalReason(Data("[1, 2]".utf8)) == .damaged)
    }

    @Test func aMissingSchemaIsDamaged() throws {
        let data = AnatomyContent.encoded(try AnatomyContent.bundledRightKnee())
        let changed = codecMutatedJSON(data) { $0.removeValue(forKey: "schema") }
        #expect(codecRefusalReason(changed) == .damaged)
    }

    @Test func schemaTwoIsANewerVersion() throws {
        let data = AnatomyContent.encoded(try AnatomyContent.bundledRightKnee())
        let changed = codecMutatedJSON(data) { $0["schema"] = 2 }
        let reason = codecRefusalReason(changed)
        #expect(reason == .newerVersion)
    }

    @Test func oneByteOverTheLimitIsTooLarge() throws {
        #expect(AnatomyContent.maxBytes == 262_144)
        var data = AnatomyContent.encoded(try AnatomyContent.bundledRightKnee())
        let padding = AnatomyContent.maxBytes + 1 - data.count
        data.append(Data(repeating: 0x20, count: max(padding, 0)))
        #expect(data.count == AnatomyContent.maxBytes + 1)
        #expect(codecRefusalReason(data) == .tooLarge)
        let raw = Data(repeating: 0x7B, count: AnatomyContent.maxBytes + 1)
        #expect(codecRefusalReason(raw) == .tooLarge)
    }

    @Test func anEditedValidRegionStillRoundTrips() throws {
        var region = try AnatomyContent.bundledRightKnee()
        let index = try #require(region.structures.firstIndex { $0.id == "knee.femur" })
        let text = "The femur is the long bone of the thigh. It meets the tibia at the knee."
        region.structures[index].description = text
        #expect(AnatomyContent.validate(region) == nil)
        let data = AnatomyContent.encoded(region)
        let decoded = AnatomyContent.decode(data)
        #expect(decoded == .success(region))
        if case .success(let back) = decoded {
            #expect(back.structure("knee.femur")?.description == text)
            let again = AnatomyContent.encoded(back)
            #expect(again == data)
        }
    }
}
