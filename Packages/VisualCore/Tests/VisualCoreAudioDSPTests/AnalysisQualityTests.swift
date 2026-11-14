// AnalysisQualityTests — feature 051 (A06-P05) T-A06-502 (FR-A06-501; SC-A06-501): each quality level maps to its
// configuration (1,024/16, 512/16, 256/8); −1 clamps to level 0 and 5 to level 2; every level builds a valid extractor
// at 48 kHz and 44.1 kHz whose size and band count match the configuration.
import Foundation
import Testing
@testable import VisualCoreAudioDSP

@Test func analysisQualityLevelsAreZeroToTwo() {
    #expect(AnalysisQuality.levels == 0...2)
}

@Test func analysisQualityConfigurationPerLevel() {
    let expected: [(size: Int, bandCount: Int)] = [(1_024, 16), (512, 16), (256, 8)]
    for level in AnalysisQuality.levels {
        let config = AnalysisQuality.configuration(level: level)
        #expect(config.size == expected[level].size, "level \(level)")
        #expect(config.bandCount == expected[level].bandCount, "level \(level)")
    }
}

@Test func analysisQualityClampsOutOfRangeLevels() {
    let low = AnalysisQuality.configuration(level: -1)
    let zero = AnalysisQuality.configuration(level: 0)
    #expect(low.size == zero.size && low.bandCount == zero.bandCount)
    let high = AnalysisQuality.configuration(level: 5)
    let two = AnalysisQuality.configuration(level: 2)
    #expect(high.size == two.size && high.bandCount == two.bandCount)
}

@Test(arguments: [48_000.0, 44_100.0])
func analysisQualityExtractorForEachLevel(sampleRate: Double) throws {
    for level in AnalysisQuality.levels {
        let config = AnalysisQuality.configuration(level: level)
        let extractor = try #require(AnalysisQuality.makeExtractor(level: level, sampleRate: sampleRate),
                                     "level \(level) at \(sampleRate) Hz")
        #expect(extractor.size == config.size)
        #expect(extractor.layout.bandCount == config.bandCount)
        #expect(extractor.sampleRate == sampleRate)
    }
}

@Test func analysisQualityExtractorClampsLevel() throws {
    let extractor = try #require(AnalysisQuality.makeExtractor(level: 5, sampleRate: 48_000))
    #expect(extractor.size == 256)
    #expect(extractor.layout.bandCount == 8)
}
