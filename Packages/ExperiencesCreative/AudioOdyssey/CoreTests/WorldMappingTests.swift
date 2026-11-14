// WorldMappingTests — feature 056 (A07-P03) T-A07-302 (FR-A07-302, FR-A07-311, FR-A07-312; clarifications 3 and 4;
// data-model "WorldMapping"). The mapping of each world, host-free and short: the defaults, the sensitivity gains and
// target clamping, the easing factors, the digest form and the JSON round trip with refusal of unknown raw values.
import Foundation
import Testing
import AudioOdysseyCore

@Suite struct WorldMappingTests {
    /// An envelope that settled on the given band energies, flux and onset.
    private func envelope(bands: [Float], flux: Float = 0, onset: Bool = false) -> AudioEnvelope {
        var envelope = AudioEnvelope()
        for i in 0..<120 {
            envelope.update(bandEnergies: bands, flux: flux, onset: onset, time: Double(i) / 60, elapsed: 1.0 / 60)
        }
        return envelope
    }

    @Test func theDefaultsMatchTheDataModel() {
        let tunnel = WorldMapping.defaults(for: .tunnel)
        #expect(tunnel.primary == ChannelMapping(channel: .low, sensitivity: .medium))
        #expect(tunnel.light == ChannelMapping(channel: .overall, sensitivity: .medium))
        #expect(WorldMapping.defaults(for: .landscape).primary.channel == .mid)
        #expect(WorldMapping.defaults(for: .starCorridor).primary.channel == .transient)
        #expect(WorldMapping.allDefaults.allSatisfy { $0.light.channel == .overall })
        #expect(WorldMapping.allDefaults.allSatisfy { $0.primary.sensitivity == .medium && $0.light.sensitivity == .medium })
        #expect(WorldMapping.allDefaults.count == JourneyWorld.allCases.count)
    }

    @Test func gainsAndEasingFactorsMatchTheClarification() {
        #expect(Sensitivity.allCases.map(\.gain) == [0.6, 1.0, 1.6])
        #expect(Sensitivity.allCases.map(\.rawValue) == [0, 1, 2])
        #expect(Easing.allCases.map(\.accelerationFactor) == [0.33, 0.66, 1.0])
        #expect(Easing.allCases.map(\.displayName) == ["Gentle", "Standard", "Brisk"])
        #expect(Easing.allCases.allSatisfy { $0.accelerationFactor <= 1 })
        #expect(Easing.gentle.accelerationFactor * 3 <= Easing.brisk.accelerationFactor)
    }

    @Test func targetsAreTheChannelTimesTheGainClampedToOne() {
        var bands = [Float](repeating: 0, count: 16)
        bands[0] = 1
        let settled = envelope(bands: bands)
        let low = settled.low
        #expect(low > 0.999)
        let overall = settled.overall
        for sensitivity in Sensitivity.allCases {
            let mapping = WorldMapping(primary: ChannelMapping(channel: .low, sensitivity: sensitivity),
                                       light: ChannelMapping(channel: .overall, sensitivity: sensitivity))
            let target = mapping.target(from: settled)
            #expect(abs(target.primary - min(low * sensitivity.gain, 1)) < 1e-12)
            #expect(abs(target.light - min(overall * sensitivity.gain, 1)) < 1e-12)
            #expect((0...1).contains(target.primary) && (0...1).contains(target.light))
        }
        let unmapped = WorldMapping.defaults(for: .landscape).target(from: settled)
        #expect(unmapped.primary == 0)
        #expect(WorldMapping.defaults(for: .tunnel).target(from: AudioEnvelope()) == (primary: 0, light: 0))
    }

    @Test func aBeatDrivesOnlyTheStarCorridorDefault() {
        let beat = envelope(bands: [Float](repeating: 0, count: 16), onset: true)
        #expect(WorldMapping.defaults(for: .starCorridor).target(from: beat).primary > 0.79)
        #expect(WorldMapping.defaults(for: .tunnel).target(from: beat).primary == 0)
        #expect(WorldMapping.defaults(for: .landscape).target(from: beat).primary == 0)
        #expect(WorldMapping.defaults(for: .starCorridor).target(from: beat).light == 0)
    }

    @Test func theDigestFormAndTheJSONRoundTrip() throws {
        let mapping = WorldMapping(primary: ChannelMapping(channel: .transient, sensitivity: .high),
                                   light: ChannelMapping(channel: .mid, sensitivity: .low))
        #expect(mapping.digestText == "3.2.1.0")
        #expect(WorldMapping.defaults(for: .tunnel).digestText == "0.1.4.1")
        let back = try JSONDecoder().decode(WorldMapping.self, from: JSONEncoder().encode(mapping))
        #expect(back == mapping)
        let bad = #"{"primary":{"channel":5,"sensitivity":1},"light":{"channel":4,"sensitivity":1}}"#
        #expect(throws: (any Error).self) { try JSONDecoder().decode(WorldMapping.self, from: Data(bad.utf8)) }
        #expect(EnvelopeChannel.allCases.map(\.displayName).count == Set(EnvelopeChannel.allCases.map(\.displayName)).count)
    }
}
