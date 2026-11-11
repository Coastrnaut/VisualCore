// ExplorerView.swift — the explorer screen (feature 026 T-A03-104; FR-A03-101, FR-A03-106): an accessible mode picker,
// the mode explanation, and the CPU-reference preview of the current view with its spoken description. No render host
// and no GPU resources in Phase 01; Phase 02 replaces the preview with the VisualCore-hosted GPU render and keeps this
// model.
import CoreGraphics
import FractalExplorerCore
import SwiftUI
import VisualCoreMath
import VisualCoreUI

/// The explorer's state and its preview; the preview is computed off the main actor and stale results are dropped.
@MainActor
@Observable
final class ExplorerModel {
    /// The fractal state (mode, viewport, seed, cap, radius).
    var state: FractalState { didSet { if state != oldValue { refresh() } } }
    /// The latest preview for the current request, if computed.
    private(set) var preview: FractalPreview?
    /// The identifier of the latest request.
    private(set) var requestID = 0
    /// Results that arrived for an older request and were discarded (tests).
    private(set) var droppedResults = 0
    private var task: Task<Void, Never>?

    init(size: Vec2 = Vec2(390, 844)) {
        state = FractalState(size: size)
        refresh()
    }

    /// The current mode's explanation.
    var explanation: String { FractalExplanations.text(for: state.mode) }

    /// Starts a preview for the current state; a newer request supersedes it.
    func refresh() {
        requestID += 1
        let id = requestID, snapshot = state
        task = Task.detached(priority: .userInitiated) { [weak self] in
            let p = FractalPreview.render(snapshot, requestID: id)
            await self?.deliver(p)
        }
    }

    /// Accepts a preview only for the current request.
    func deliver(_ p: FractalPreview) {
        guard p.requestID == requestID else {
            droppedResults += 1
            return
        }
        preview = p
    }

    /// Waits for the latest preview (tests).
    func waitForPreview() async {
        while preview?.requestID != requestID { await Task.yield(); try? await Task.sleep(nanoseconds: 5_000_000) }
    }

    /// The preview as an image.
    var image: CGImage? {
        guard let p = preview else { return nil }
        let data = Data(p.rgba) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(width: p.width, height: p.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: p.width * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}

struct ExplorerView: View {
    @State private var model = ExplorerModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Fractal", selection: $model.state.mode) {
                    ForEach(FractalMode.allCases, id: \.self) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("fe.mode")
                Text(model.explanation)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("fe.mode.explanation")
                canvas
                if model.state.mode == .julia {
                    Text("Seed: \(FractalState.complex(model.state.juliaSeed))")
                        .accessibilityIdentifier("fe.seed")
                }
            }
            .padding()
        }
        .navigationTitle("Explorer")
        .navigationBarTitleDisplayMode(.inline)
        .tint(AccessibleColors.accent)
    }

    private var canvas: some View {
        Group {
            if let image = model.image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.black.aspectRatio(390.0 / 844.0, contentMode: .fit)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel(model.state.spokenDescription)
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("fe.canvas")
    }
}
