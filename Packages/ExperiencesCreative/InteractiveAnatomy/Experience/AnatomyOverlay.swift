// AnatomyOverlay — feature 127 (A17-P04) T-A17-405 (FR-A17-402; clarification Q2; edge cases "Many parts crowded in
// one corner", "Labels at the canvas edge", "The canvas is smaller than one label box"; contracts/accessibility-pack.md).
// The view Interactive Anatomy draws over its canvas through the host's overlay slot
// (`ExperiencePresenter.makeCanvasOverlay(_:)`), modelled on Molecular Explorer's `MoleculeOverlay`: the English names of
// the labels `AnchoredLabelLayout` placed for the last drawn frame, each as small caption text in white on a dark,
// partly opaque backing filling its placed box (7 points per character plus 8, by 18). It reads the presenter's mirror
// only and sends nothing; it is drawn with hit testing off and hidden from assistive technology (the structure list,
// the panel and the canvas description name the parts instead). The labels are laid out in the mirror's canvas size in
// points; the overlay reports its own size to the mirror (the presenter then lays the next frame out in exactly that
// size) and scales the boxes by its size over the mirror's, so a label stays on its part even in the frame before the
// sizes agree. Nothing moves except with the drawn model; nothing flashes; the names are text, not colour.
import SwiftUI
import VisualCoreMath

/// The part labels drawn over the canvas.
struct AnatomyOverlay: View {
    /// What the overlay shows.
    let mirror: AnatomyMirror

    /// The overlay.
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let canvas = mirror.canvasSize
            let sx = canvas.x > 0 ? Double(size.width) / canvas.x : 1
            let sy = canvas.y > 0 ? Double(size.height) / canvas.y : 1
            ZStack(alignment: .topLeading) {
                ForEach(mirror.labels, id: \.index) { label in
                    Text(verbatim: label.text)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(Color.white)
                        .frame(width: label.width * sx, height: label.height * sy)
                        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 3))
                        .position(x: (label.minX + label.width / 2) * sx, y: (label.minY + label.height / 2) * sy)
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
