# Contract: A06-P04 framework additions (VisualCoreAudio)

```swift
public enum AudioSourceState: Equatable, Sendable { case idle, running, interrupted, failed(String) }   // + interrupted
public enum AudioSessionEvent: Equatable, Sendable {
  case interruptionBegan, interruptionEnded(shouldResume: Bool), routeLost, mediaServicesReset
  public init?(name: Notification.Name, userInfo: [AnyHashable: Any]?)
}
@MainActor public final class AudioSessionEventMonitor {
  public init(center: NotificationCenter = .default, handler: @escaping @MainActor (AudioSessionEvent) -> Void)
  public func stop()
}
public protocol ResumableAudioSource: AudioSource {   // analyze U1: the presenter resumes through this protocol
  func resume()
}
extension MicrophoneAudioSource: ResumableAudioSource {
  public func handle(_ event: AudioSessionEvent)      // reactions per research D4
  public func resume()                                 // restart after an interruption ended without resume permission
}
```
