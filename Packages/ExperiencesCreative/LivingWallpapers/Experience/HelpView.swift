// HelpView — feature 140 (A19-P03) T-A19-307 (FR-A19-304; clarification Q4; contracts/editor.md "Help"). The help of
// Living Wallpapers, titled "How to use it": the three sections of `WallpaperHelp.sections`, each a header and its
// body, in a scroll view that wraps every line at any Dynamic Type size, and a Done button. The editor opens it from
// its help button and from the "How to use it" button after a written export (`EditorModel.openHelp(from:)`).
// Text only: no Photos, Settings or system-wallpaper call.
import LivingWallpapersCore
import SwiftUI

/// The help sheet: the sections of `WallpaperHelp` (see the file header).
struct HelpView: View {
    /// The sections shown, in order (by default `WallpaperHelp.sections`).
    var sections: [WallpaperHelp.Section] = WallpaperHelp.sections
    /// Called by the Done button.
    var done: () -> Void = {}

    /// The help.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(verbatim: EditorModel.helpTitle).font(.title2).accessibilityAddTraits(.isHeader)
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: section.title).font(.headline).accessibilityAddTraits(.isHeader)
                        Text(verbatim: section.body).font(.body).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button(action: done) {
                    Text(verbatim: "Done").frame(minHeight: 44)
                }
                .accessibilityLabel(Text(verbatim: "Done, closes the help"))
                .accessibilityIdentifier("experience.a19.living-wallpapers.help-done")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}
