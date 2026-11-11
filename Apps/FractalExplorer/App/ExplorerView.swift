// ExplorerView.swift — the explorer screen (feature 026 T-A03-104; feature 027 T-A03-204): an accessible mode picker,
// the mode explanation, and the GPU picture on VisualCore's render host (RenderSurface), with the CPU-reference preview
// as the fallback when the shader cannot run. The app owns no EGL context.
import CoreGraphics
import FractalExplorerCore
import SwiftUI
import VisualCoreMath
import VisualCoreRendering
import VisualCoreUI

/// The explorer's state, its GPU scene on VisualCore's render host, and the CPU-reference preview used as the fallback
/// picture when the shader cannot run (feature 027 T-A03-204; clarification 5).
@MainActor
@Observable
final class ExplorerModel {
    /// The fractal state (mode, viewport, seed, cap, radius); every change reaches the next frame.
    var state: FractalState {
        didSet {
            guard state != oldValue else { return }
            scene.snapshot.state = state
            if usingFallback { refresh() }
        }
    }
    /// The GPU scene (VisualCore FullScreenShaderScene inside).
    let scene: FractalScene
    /// The one render host (VisualCore's audited EGL host); nil if it could not start.
    private(set) var host: RenderHost?
    /// The latest CPU preview for the current request (fallback only).
    private(set) var preview: FractalPreview?
    /// The identifier of the latest preview request.
    private(set) var requestID = 0
    /// Preview results that arrived for an older request and were discarded (tests).
    private(set) var droppedResults = 0
    private var task: Task<Void, Never>?

    /// `fragment` is a test seam (an invalid source exercises the fallback).
    init(size: Vec2 = Vec2(390, 844), fragment: String = FractalShaders.fragment) {
        let initial = FractalState(size: size)
        state = initial
        scene = FractalScene(snapshot: .init(state: initial), fragment: fragment)
        host = try? RenderHost(scene: scene)
        if usingFallback { refresh() }
    }

    /// True when the GPU picture is unavailable (no host, or the shader failed); the CPU preview is shown instead.
    var usingFallback: Bool { host == nil || scene.errorMessage != nil }

    /// The current mode's explanation.
    var explanation: String { FractalExplanations.text(for: state.mode) }

    /// The view's size changed (layout, rotation, split view): the viewport keeps its center and the plane width across
    /// the shorter side, so the zoom and the visible content stay the same (square pixels via PlaneViewport).
    func resize(to size: Vec2) {
        let old = state.viewport
        guard size.isFinite, size.x > 0, size.y > 0, size != old.size else { return }
        let width = old.unitsPerPoint * min(old.size.x, old.size.y)
        state.viewport = PlaneViewport(center: old.center, unitsPerPoint: width / min(size.x, size.y), size: size)
    }

    /// Starts a CPU preview for the current state; a newer request supersedes it.
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

    /// Destroys the host (the screen went away).
    func close() {
        task?.cancel()
        host?.destroy()
        host = nil
    }

    /// The CPU preview as an image.
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
                if model.usingFallback, let error = model.scene.errorMessage {
                    Text("The graphics shader could not run, so a simpler preview is shown. (\(error))")
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("fe.fallback")
                }
                if model.state.mode == .julia {
                    Text("Seed: \(FractalState.complex(model.state.juliaSeed))")
                        .accessibilityIdentifier("fe.seed")
                }
            }
            .padding()
        }
        .onDisappear { model.close() }
        .navigationTitle("Explorer")
        .navigationBarTitleDisplayMode(.inline)
        .tint(AccessibleColors.accent)
    }

    private var canvas: some View {
        GeometryReader { geo in
            Group {
                if let host = model.host, !model.usingFallback {
                    RenderSurface(host: host, accessibilityLabel: model.state.spokenDescription,
                                  accessibilityHint: "Fractal picture. Pinch to zoom and drag to move; the zoom buttons do the same.")
                } else if let image = model.image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .accessibilityElement()
                        .accessibilityLabel(model.state.spokenDescription)
                        .accessibilityAddTraits(.isImage)
                } else {
                    Color.black
                }
            }
            .onAppear { model.resize(to: Vec2(Double(geo.size.width), Double(geo.size.height))) }
            .onChange(of: geo.size) { _, size in model.resize(to: Vec2(Double(size.width), Double(size.height))) }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("fe.canvas")
    }
}
