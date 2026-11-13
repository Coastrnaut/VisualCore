// ControlsSheet.swift — time, preset, palette, seed and parameter controls for the open scene (feature 013 T-A01-207;
// FR-A01-201, FR-A01-203, FR-A01-204, FR-A01-207). Edits go to SceneModel, which applies them to the live scene by the
// next frame; the parameter rows are VisualCore's ParameterPanel.
import GenerativeArtStudioCore
import SwiftUI
import VisualCoreParameters
import VisualCoreSimulation
import VisualCoreUI

struct ControlsSheet: View {
    @Bindable var model: SceneModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Time") {
                    HStack(spacing: 12) {
                        Button { model.togglePlay() } label: {
                            Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                                .frame(minWidth: 44, minHeight: 44)   // 44 pt hit area (feature 016 audit)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(model.isPlaying ? "Pause" : "Play")
                        .accessibilityIdentifier("gas.time.playPause")
                        Slider(value: Binding(get: { model.time }, set: { model.scrub(to: $0) }), in: 0...SceneClock().duration)
                            .accessibilityLabel("Time")
                            .accessibilityValue(String(format: "%.1f seconds", model.time))
                            .accessibilityIdentifier("gas.time.scrub")
                        Text(String(format: "%.1f s", model.time))
                            .font(.subheadline.monospacedDigit())
                            .frame(minWidth: 56, alignment: .trailing)
                            .accessibilityIdentifier("gas.time.value")
                    }
                }
                Section("Preset") {
                    ForEach(model.family.presets) { preset in
                        Button { model.editor.choosePreset(preset.id) } label: {
                            HStack {
                                Text(preset.title)
                                Spacer()
                                if model.editor.presetID == preset.id { Image(systemName: "checkmark").accessibilityHidden(true) }
                            }
                        }
                        .accessibilityAddTraits(model.editor.presetID == preset.id ? .isSelected : [])
                        .accessibilityIdentifier("gas.preset.\(preset.id)")
                    }
                }
                Section("Palette") {
                    ForEach(FamilyCatalog.palettes) { palette in
                        Button { model.editor.choosePalette(palette.id) } label: {
                            HStack {
                                PaletteSwatch(palette: palette).frame(width: 28, height: 20).accessibilityHidden(true)
                                Text(palette.name)
                                Spacer()
                                if model.document.paletteID == palette.id { Image(systemName: "checkmark").accessibilityHidden(true) }
                            }
                        }
                        .accessibilityAddTraits(model.document.paletteID == palette.id ? .isSelected : [])
                        .accessibilityIdentifier("gas.palette.\(palette.id)")
                    }
                }
                Section("Seed") {
                    HStack {
                        Text(String(model.document.seed))
                            .font(.footnote.monospacedDigit())
                            .textSelection(.enabled)
                            .accessibilityLabel(Text(verbatim: "Seed " + String(model.document.seed)))
                            .accessibilityIdentifier("gas.seed.value")
                        Spacer()
                        Button("Shuffle") {
                            var generator = SystemRandomNumberGenerator()
                            model.editor.shuffleSeed(using: &generator)
                        }
                        .accessibilityHint("Picks a new random seed")
                        .accessibilityIdentifier("gas.seed.shuffle")
                    }
                }
                ParameterPanel(editor: Binding(get: { model.editor.editor }, set: { model.editor.updateEditor($0) }))
            }
            .scrollEdgeEffectHidden(true, for: .bottom)   // rows near the edge keep full contrast (feature 016 audit)
            .headerProminence(.increased)   // prominent primary-color headers (feature 016 audit)
            .navigationTitle("Controls")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("gas.controls.sheet")
    }
}

// PaletteSwatch moved here from the retired GalleryView.swift (feature 193 T-U07-043).
/// A rounded gradient of a palette's sRGB stops (decorative; the family title carries the meaning).
struct PaletteSwatch: View {
    let palette: Palette
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(LinearGradient(colors: palette.stops.map { Color(.sRGB, red: $0.x, green: $0.y, blue: $0.z) },
                                 startPoint: .bottomLeading, endPoint: .topTrailing))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.4)))
    }
}
