# Contract: A06-P05 framework additions (VisualCoreAudioDSP)

```swift
public enum AnalysisQuality {
  public static let levels: ClosedRange<Int>                                   // 0...2
  public static func configuration(level: Int) -> (size: Int, bandCount: Int)  // clamped
  public static func makeExtractor(level: Int, sampleRate: Double) -> FeatureExtractor?
}
```
