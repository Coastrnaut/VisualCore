// MoleculeSettingsTests — feature 113 (A15-P04) T-A15-402 (contracts/library.md; data-model "LabelMode",
// "MoleculeSettings"; clarification Q2). The settings document, host-free and short: the default is all labels; each
// mode round-trips byte-exactly with sorted keys; one fixture per refusal (damaged, oversized, newer-version, and
// out-of-range for an unknown label mode and schema 0).
import Foundation
import Testing
@testable import MolecularExplorerCore

@Suite struct MoleculeSettingsTests {
    /// The refusal of `json`, or nil when it decodes.
    private func refusal(_ json: String) -> DocumentRefusal? {
        if case .failure(let reason) = MoleculeSettings.decode(Data(json.utf8)) { return reason }
        return nil
    }

    @Test func theDefaultShowsAllLabels() {
        #expect(MoleculeSettings().labels == .all)
        #expect(MoleculeSettings.schemaVersion == 1 && MoleculeSettings.maxBytes == 1_024)
        #expect(MoleculeSettings.fileName == "settings.json")
        #expect(LabelMode.allCases == [.all, .selected, .none])
        #expect(DocumentRefusal.newerVersion.rawValue == "newer-version")
        #expect(DocumentRefusal.outOfRange.rawValue == "out-of-range")
    }

    @Test func everyModeRoundTripsByteExactly() {
        for mode in LabelMode.allCases {
            let settings = MoleculeSettings(labels: mode)
            let text = String(decoding: settings.encoded(), as: UTF8.self)
            #expect(text == "{\"labels\":\"\(mode.rawValue)\",\"schemaVersion\":1}")
            let decoded = try? MoleculeSettings.decode(settings.encoded()).get()
            #expect(decoded == settings)
        }
    }

    @Test func everyRefusalHasAFixture() {
        #expect(refusal("{") == .damaged)
        #expect(refusal(#"{"labels":3,"schemaVersion":1}"#) == .damaged)
        #expect(refusal(#"{"labels":"all"}"#) == .damaged)
        let oversized = #"{"labels":"all","schemaVersion":1}"# + String(repeating: " ", count: 1_025 - 34)
        #expect(oversized.utf8.count == 1_025)
        #expect(refusal(oversized) == .oversized)
        #expect(refusal(#"{"labels":"all","schemaVersion":2}"#) == .newerVersion)
        #expect(refusal(#"{"labels":"some","schemaVersion":1}"#) == .outOfRange)
        #expect(refusal(#"{"labels":"all","schemaVersion":0}"#) == .outOfRange)
        #expect(refusal(#"{"labels":"none","schemaVersion":1}"#) == nil)
    }
}
