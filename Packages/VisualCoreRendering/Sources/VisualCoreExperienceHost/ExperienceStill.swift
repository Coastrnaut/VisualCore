// ExperienceStill — feature 193 (UA-F07) T-U07-009 (FR-U07-020). A still picture of the open experience for its
// own export: the session renders its current state off screen on the session's render host (no second context),
// and the host view hands that renderer to the experience's controls through the SwiftUI environment. The
// experience decides where the picture goes: the system's share interface or its own storage.
import SwiftUI
import VisualCoreRendering

/// Renders the open experience's current picture off screen at a size in pixels. Main thread only.
public struct ExperienceStillRenderer: Sendable {
    private let render: @MainActor @Sendable (Int, Int) throws(OffscreenRenderError) -> StillImage

    /// A renderer that calls `render` with the width and the height in pixels.
    public init(_ render: @escaping @MainActor @Sendable (Int, Int) throws(OffscreenRenderError) -> StillImage) {
        self.render = render
    }

    /// The picture at `width` × `height` pixels; throws when there is no picture to render or the size is not
    /// possible on this device.
    @MainActor
    public func callAsFunction(width: Int, height: Int) throws(OffscreenRenderError) -> StillImage {
        try render(width, height)
    }
}

extension EnvironmentValues {
    /// The still renderer of the open experience; set by `ExperienceHostView` on the controls, nil elsewhere.
    @Entry public var experienceStillRenderer: ExperienceStillRenderer? = nil
}

extension ExperienceSession {
    /// The current picture of the open experience at `width` × `height` pixels, drawn off screen on the session's
    /// render host. Throws `.unavailable` while no experience is running or suspended.
    public func renderStill(width: Int, height: Int) throws(OffscreenRenderError) -> StillImage {
        guard state == .running || state == .suspended, let host = renderHost else {
            throw .unavailable("No experience is open.")
        }
        return try host.renderOffscreen(width: width, height: height, time: 0)
    }
}
