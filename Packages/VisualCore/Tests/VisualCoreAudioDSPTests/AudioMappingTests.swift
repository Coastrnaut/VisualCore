// AudioMappingTests — feature 049 (A06-P03) T-A06-302 (FR-A06-301–303; SC-A06-301, SC-A06-302): each feature kind
// normalises to 0 / 0.5 / 1 at its window ends and midpoint; action indices round-trip; the failable initialiser and
// decoding refuse unknown features, non-finite numbers, gain 5, attack 0, clampLow ≥ clampHigh, schema version 2 and
// missing fields; a valid mapping round-trips exactly.
import Foundation
import Testing
@testable import VisualCoreAudioDSP

/// A feature set with the given level and peak in dBFS, beat energy and 16 bands of the given linear energy each.
func audioMappingFeatures(rmsDB: Float = -120, peakDB: Float = -120, beat: Float = 0, bandEnergy: Float = 0)
    -> AudioFeatures {
    AudioFeatures(timestamp: 0, rms: pow(10, rmsDB / 20), peak: pow(10, peakDB / 20),
                  bandEnergies: [Float](repeating: bandEnergy, count: 16), flux: 0, onset: false, beatEnergy: beat)
}

@Test func audioMappingLevelAndPeakNormaliseOverMinus60To0() {
    let cases: [(Float, Float)] = [(-60, 0), (-30, 0.5), (0, 1), (-90, 0), (6, 1)]
    for (db, expected) in cases {
        let f = audioMappingFeatures(rmsDB: db, peakDB: db)
        #expect(abs(AudioFeatureKind.level.normalized(f) - expected) <= 1e-5)
        #expect(abs(AudioFeatureKind.peak.normalized(f) - expected) <= 1e-5)
    }
}

@Test func audioMappingBeatNormalisesAsIsClamped() {
    let cases: [(Float, Float)] = [(0, 0), (0.5, 0.5), (1, 1), (-0.5, 0), (2, 1), (.nan, 0)]
    for (beat, expected) in cases {
        #expect(AudioFeatureKind.beat.normalized(audioMappingFeatures(beat: beat)) == expected)
    }
}

@Test func audioMappingRegionsNormaliseSummedBandsOverMinus80To0() {
    // Four bands per region: per-band energy e gives a region sum of 4e.
    let regions: [AudioFeatureKind] = [.low, .lowMid, .highMid, .high]
    let cases: [(Float, Float)] = [(-80, 0), (-40, 0.5), (0, 1), (-100, 0)]
    for (sumDB, expected) in cases {
        let perBand = pow(10, sumDB / 10) / 4
        let f = audioMappingFeatures(bandEnergy: perBand)
        for kind in regions {
            #expect(abs(kind.normalized(f) - expected) <= 1e-5, "\(kind) at \(sumDB) dB")
        }
    }
    #expect(AudioFeatureKind.low.normalized(audioMappingFeatures()) == 0)
}

@Test func audioMappingRegionsReadOnlyTheirOwnBands() {
    var f = audioMappingFeatures()
    for band in 4..<8 { f.bandEnergies[band] = 0.25 }
    #expect(abs(AudioFeatureKind.lowMid.normalized(f) - 1) <= 1e-6)
    #expect(AudioFeatureKind.low.normalized(f) == 0)
    #expect(AudioFeatureKind.highMid.normalized(f) == 0)
    #expect(AudioFeatureKind.high.normalized(f) == 0)
    // Bands beyond the count read 0.
    let short = AudioFeatures(timestamp: 0, rms: 0, peak: 0, bandEnergies: [1, 1, 1, 1], flux: 0, onset: false,
                              beatEnergy: 0)
    #expect(AudioFeatureKind.low.normalized(short) == 1)
    #expect(AudioFeatureKind.high.normalized(short) == 0)
}

@Test func audioMappingKindIndicesFollowCaseOrder() {
    let expected: [AudioFeatureKind] = [.level, .peak, .beat, .low, .lowMid, .highMid, .high]
    #expect(AudioFeatureKind.allCases == expected)
    for (i, kind) in expected.enumerated() {
        #expect(kind.index == i)
        #expect(AudioFeatureKind.from(index: i) == kind)
    }
    #expect(AudioFeatureKind.from(index: -1) == nil)
    #expect(AudioFeatureKind.from(index: 7) == nil)
}

@Test func audioMappingInitRefusesInvalidValues() {
    #expect(AudioMapping(feature: .level, gain: 1) != nil)
    #expect(AudioMapping(feature: .level, gain: .nan) == nil)
    #expect(AudioMapping(feature: .level, gain: .infinity) == nil)
    #expect(AudioMapping(feature: .level, gain: 5) == nil)
    #expect(AudioMapping(feature: .level, gain: -0.1) == nil)
    #expect(AudioMapping(feature: .level, gain: 1, attack: 0) == nil)
    #expect(AudioMapping(feature: .level, gain: 1, attack: .nan) == nil)
    #expect(AudioMapping(feature: .level, gain: 1, release: 6) == nil)
    #expect(AudioMapping(feature: .level, gain: 1, clampLow: 0.5, clampHigh: 0.5) == nil)
    #expect(AudioMapping(feature: .level, gain: 1, clampLow: -0.1) == nil)
    #expect(AudioMapping(feature: .level, gain: 1, clampHigh: 1.1) == nil)
    #expect(AudioMapping(feature: .level, gain: 1, clampHigh: .infinity) == nil)
    #expect(AudioMapping(feature: .high, gain: 4, attack: 0.001, release: 5, clampLow: 0, clampHigh: 1) != nil)
}

@Test func audioMappingRoundTripsExactly() throws {
    let mapping = try #require(AudioMapping(feature: .highMid, gain: 1.234_567_890_123, attack: 0.037_1,
                                            release: 0.412_9, clampLow: 0.1, clampHigh: 0.9))
    let data = try JSONEncoder().encode(mapping)
    let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["schemaVersion"] as? Int == 1)
    #expect(object["feature"] as? String == "highMid")
    #expect(try JSONDecoder().decode(AudioMapping.self, from: data) == mapping)
}

/// A JSON mapping payload with one field replaced (or removed when `value` is nil).
private func audioMappingPayload(replacing key: String? = nil, with value: String? = nil) -> Data {
    var fields: [(String, String)] = [("schemaVersion", "1"), ("feature", "\"level\""), ("gain", "1"),
                                      ("attack", "0.02"), ("release", "0.25"), ("clampLow", "0"), ("clampHigh", "1")]
    if let key {
        if let value {
            fields = fields.map { $0.0 == key ? (key, value) : $0 }
        } else {
            fields.removeAll { $0.0 == key }
        }
    }
    return Data(("{" + fields.map { "\"\($0.0)\": \($0.1)" }.joined(separator: ", ") + "}").utf8)
}

@Test func audioMappingDecodesTheValidPayload() throws {
    let mapping = try JSONDecoder().decode(AudioMapping.self, from: audioMappingPayload())
    #expect(mapping == AudioMapping(feature: .level, gain: 1))
}

@Test func audioMappingDecodingRefusesInvalidPayloads() {
    let corrupted: [(String, String)] = [
        ("feature", "\"loudness\""), ("gain", "5"), ("gain", "-1"), ("attack", "0"), ("release", "5.5"),
        ("clampLow", "1"), ("clampHigh", "0"), ("schemaVersion", "2"),
    ]
    for (key, value) in corrupted {
        do {
            _ = try JSONDecoder().decode(AudioMapping.self, from: audioMappingPayload(replacing: key, with: value))
            Issue.record("\(key) = \(value) decoded, expected dataCorrupted")
        } catch DecodingError.dataCorrupted(_) {
            // expected
        } catch {
            Issue.record("\(key) = \(value) threw \(error), expected dataCorrupted")
        }
    }
    // Non-finite numbers are not valid JSON numbers; a string in their place and a missing field are refused too.
    for (key, value) in [("gain", "\"nan\""), ("gain", "1e309"), ("attack", "\"inf\"")] {
        #expect(throws: (any Error).self, "\(key) = \(value)") {
            try JSONDecoder().decode(AudioMapping.self, from: audioMappingPayload(replacing: key, with: value))
        }
    }
    for key in ["schemaVersion", "feature", "gain", "attack", "release", "clampLow", "clampHigh"] {
        #expect(throws: DecodingError.self, "missing \(key)") {
            try JSONDecoder().decode(AudioMapping.self, from: audioMappingPayload(replacing: key))
        }
    }
}
