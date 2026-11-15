# Contract: canvas overlay (VisualCoreExperienceHost, feature 106)

```swift
public protocol ExperiencePresenter: AnyObject {
    // … existing requirements …
    /// An optional view drawn over the canvas; it never takes touches and its elements are hidden from accessibility.
    func makeCanvasOverlay(_ port: ExperienceActionPort) -> AnyView?
}
extension ExperiencePresenter { public func makeCanvasOverlay(_ port: ExperienceActionPort) -> AnyView? { nil } }
public protocol Experience: AnyObject { /* … */ var canvasOverlay: AnyView? { get } }
extension Experience { public var canvasOverlay: AnyView? { nil } }
// ExperienceShell: public var canvasOverlay: AnyView? { presenter.makeCanvasOverlay(port) }
// ExperienceHostView.running: RenderSurface … .overlay { if let overlay = experience.canvasOverlay {
//     overlay.allowsHitTesting(false).accessibilityHidden(true) } }
```

Tests (`CanvasOverlayTests`): a presenter without an overlay gives nil; a presenter's overlay reaches the shell; the
host view builds with and without an overlay; existing host tests unchanged.
