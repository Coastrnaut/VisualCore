// SolarOverlay — feature 106 (A14-P04) T-A14-408 (FR-A14-420; clarifications Q3, Q4; contracts/canvas-overlay.md).
// The view Solar System Explorer draws over its canvas through the host's overlay slot
// (`ExperiencePresenter.makeCanvasOverlay(_:)`): the body name labels at the points `LabelLayout` placed for the last
// drawn frame (small caption text on a dark, partly opaque background, each in its 90 × 20 pt box) and, while a tour
// runs, the tour caption at the canvas's bottom edge. It reads the presenter's mirror only and sends nothing: the host
// draws it with hit testing off and its elements hidden from assistive technology (the canvas description already
// speaks the state and the tour words). The labels are laid out in the mirror's canvas size in points; the overlay
// reports its own size to the mirror (the presenter then lays the next frame out in exactly that size) and scales
// the points by its size over the mirror's, so a label stays on its body even in the frame before the sizes agree.
// Nothing moves except with the drawn bodies; nothing flashes.
import SwiftUI
import VisualCoreMath

/// The labels and the tour caption drawn over the canvas.
struct SolarOverlay: View {
    /// What the overlay shows.
    let mirror: SolarMirror

    /// The overlay.
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let canvas = mirror.canvasSize
            let sx = canvas.x > 0 ? Double(size.width) / canvas.x : 1
            let sy = canvas.y > 0 ? Double(size.height) / canvas.y : 1
            ZStack(alignment: .topLeading) {
                ForEach(mirror.labels, id: \.index) { label in
                    Text(verbatim: label.name)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 3)
                        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 3))
                        .frame(width: LabelLayout.boxWidth, height: LabelLayout.boxHeight, alignment: .leading)
                        .position(x: label.point.x * sx + LabelLayout.boxWidth / 2,
                                  y: label.point.y * sy - LabelLayout.boxHeight / 2)
                }
                if !mirror.tourCaption.isEmpty {
                    VStack {
                        Spacer(minLength: 0)
                        Text(verbatim: mirror.tourCaption)
                            .font(.footnote)
                            .foregroundStyle(Color.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(6)
                            .frame(maxWidth: .infinity)
                            .background(Color.black.opacity(0.6))
                    }
                    .frame(width: size.width, height: size.height)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .onAppear { report(size) }
            .onChange(of: size) { _, newSize in report(newSize) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Tells the mirror the overlay's size in points (only when it changed).
    private func report(_ size: CGSize) {
        let points = Vec2(Double(size.width), Double(size.height))
        if mirror.overlaySize != points { mirror.overlaySize = points }
    }
}
