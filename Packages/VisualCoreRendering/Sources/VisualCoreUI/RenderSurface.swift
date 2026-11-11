// RenderSurface.swift — SwiftUI host for a caller-owned RenderHost (feature 012 T-A01-105; FR-A01-108; research R7).
// The surface never creates or destroys hosts: the screen that owns the host destroys it when it goes away.
import SwiftUI
import UIKit
import VisualCoreRendering

/// Embeds `host.view` in SwiftUI, filling the available space, and describes the canvas to VoiceOver as one element.
public struct RenderSurface: UIViewRepresentable {
    /// The render host whose view is shown.
    public let host: RenderHost
    /// What the canvas shows, read by VoiceOver.
    public let accessibilityLabel: String
    /// How to interact with the canvas, if anything.
    public let accessibilityHint: String?

    /// Shows `host.view` with an accessibility label (and optional hint) on the canvas.
    public init(host: RenderHost, accessibilityLabel: String, accessibilityHint: String? = nil) {
        self.host = host
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    /// Creates the container and embeds the host view with edge constraints.
    public func makeUIView(context: Context) -> UIView {
        let container = RenderSurfaceContainer()
        container.backgroundColor = .black
        container.embed(host.view)
        apply(to: container)
        return container
    }

    /// Re-embeds a changed host and refreshes the accessibility text.
    public func updateUIView(_ uiView: UIView, context: Context) {
        guard let container = uiView as? RenderSurfaceContainer else { return }
        if host.view.superview !== container { container.embed(host.view) }
        apply(to: container)
    }

    private func apply(to container: RenderSurfaceContainer) {
        container.isAccessibilityElement = true
        container.accessibilityLabel = accessibilityLabel
        container.accessibilityHint = accessibilityHint
        container.accessibilityTraits = [.image]
    }
}

final class RenderSurfaceContainer: UIView {
    func embed(_ view: UIView) {
        subviews.forEach { $0.removeFromSuperview() }
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor), view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor), view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
